# Resonant live tutor: interruptible voice conversation about a picture.
#   ears  : Silero VAD + local faster-whisper (free, on this laptop)
#   brain : Muse Spark via the Meta Responses API (Meta credits)
#   voice : local Kokoro TTS (free, natural; Piper if it cannot load)
#   room  : LiveKit Cloud free tier; the backend mints the student's token and
#           hides the picture context inside it as participant metadata.
# Interruptions are the point: when the student starts talking, the framework
# stops this agent mid-sentence and listens.
import asyncio
import io
import json
import os
import urllib.request
import uuid
import wave
from pathlib import Path

from dotenv import load_dotenv
from livekit import rtc
from livekit.agents import Agent, AgentSession, JobContext, WorkerOptions, cli, llm, stt, tts
from livekit.agents.types import APIConnectOptions
from livekit.plugins import silero
from openai import AsyncOpenAI

load_dotenv(Path(__file__).resolve().parent.parent / "backend" / ".env")

SPARK_MODEL = os.environ.get("SPARK_MODEL", "muse-spark-1.3")
BASE_URL = os.environ.get("MODEL_BASE_URL", "https://api.meta.ai/v1")
VOICE_DIR = Path(__file__).resolve().parent / "voices"
VOICE_NAME = "en_US-lessac-medium"
VOICE_BASE = "https://huggingface.co/rhasspy/piper-voices/resolve/main/en/en_US/lessac/medium"


# ---------------------------------------------------------------- Muse Spark
class SparkLLM(llm.LLM):
    """Muse Spark over the Responses API (chat-completions returns no usable
    text from this endpoint, so we speak the same API the backend uses)."""

    def __init__(self):
        super().__init__()
        self._client = AsyncOpenAI(api_key=os.environ["MODEL_API_KEY"], base_url=BASE_URL)

    @property
    def model(self):
        return SPARK_MODEL

    @property
    def provider(self):
        return "meta"

    def chat(self, *, chat_ctx, tools=None, conn_options=None, **kwargs):
        return _SparkStream(self, chat_ctx=chat_ctx, tools=tools or [], conn_options=conn_options)


class _SparkStream(llm.LLMStream):
    async def _run(self):
        messages = []
        for item in self.chat_ctx.items:
            if not hasattr(item, "role") or not hasattr(item, "content"):
                continue
            text = getattr(item, "text_content", None) or "".join(
                c for c in item.content if isinstance(c, str)
            )
            text = text.strip()
            if not text:
                continue
            role = getattr(item.role, "value", item.role)
            role = {"system": "system", "developer": "system", "user": "user", "assistant": "assistant"}.get(
                str(role), "user"
            )
            messages.append({"role": role, "content": text})
        stream = await self._llm._client.responses.create(
            model=SPARK_MODEL, input=messages, stream=True, max_output_tokens=400
        )
        async for event in stream:
            if getattr(event, "type", "") == "response.output_text.delta" and event.delta:
                self._event_ch.send_nowait(
                    llm.ChatChunk(
                        id="spark",
                        delta=llm.ChoiceDelta(content=event.delta, role="assistant"),
                    )
                )


# ------------------------------------------------------------------- Whisper
class WhisperSTT(stt.STT):
    """Local faster-whisper: no STT bill, audio never leaves the laptop
    except as LiveKit media between the phone and this room."""

    def __init__(self, model="small.en"):
        super().__init__(
            capabilities=stt.STTCapabilities(streaming=False, interim_results=False, aligned_transcript=False)
        )
        self._model_name = model
        self._model = None

    def _load(self):
        if self._model is None:
            from faster_whisper import WhisperModel

            self._model = WhisperModel(self._model_name, device="cpu", compute_type="int8")
        return self._model

    async def preload(self):
        await asyncio.get_running_loop().run_in_executor(None, self._load)

    async def _recognize_impl(self, buffer, *, language=None, conn_options=None):
        frame = rtc.combine_audio_frames(buffer) if isinstance(buffer, list) else buffer
        buf = io.BytesIO()
        with wave.open(buf, "wb") as w:
            w.setnchannels(frame.num_channels)
            w.setsampwidth(2)
            w.setframerate(frame.sample_rate)
            w.writeframes(bytes(frame.data))
        buf.seek(0)

        def transcribe():
            segments, _info = self._load().transcribe(buf, language="en", vad_filter=True)
            return "".join(s.text for s in segments).strip()

        text = await asyncio.get_running_loop().run_in_executor(None, transcribe)
        return stt.SpeechEvent(
            type=stt.SpeechEventType.FINAL_TRANSCRIPT,
            alternatives=[stt.SpeechData(text=text, language="en")],
        )


# --------------------------------------------------------------------- Piper
def ensure_voice():
    VOICE_DIR.mkdir(exist_ok=True)
    for ext in (".onnx", ".onnx.json"):
        target = VOICE_DIR / f"{VOICE_NAME}{ext}"
        if not target.exists():
            print(f"Downloading Piper voice {target.name} (first run only)…")
            urllib.request.urlretrieve(f"{VOICE_BASE}/{VOICE_NAME}{ext}", target)
    return VOICE_DIR / f"{VOICE_NAME}.onnx"


class PiperTTS(tts.TTS):
    def __init__(self):
        super().__init__(
            capabilities=tts.TTSCapabilities(streaming=False, aligned_transcript=False),
            sample_rate=22050,
            num_channels=1,
        )
        from piper import PiperVoice

        self._voice = PiperVoice.load(str(ensure_voice()))

    def synthesize(self, text, *, conn_options=APIConnectOptions()):
        return _PiperStream(tts=self, input_text=text, conn_options=conn_options, voice=self._voice)


class _PiperStream(tts.ChunkedStream):
    def __init__(self, *, tts, input_text, conn_options, voice):
        super().__init__(tts=tts, input_text=input_text, conn_options=conn_options)
        self._voice = voice

    async def _run(self, output_emitter):
        def synth():
            out = io.BytesIO()
            if hasattr(self._voice, "synthesize_wav"):
                with wave.open(out, "wb") as w:
                    self._voice.synthesize_wav(self._input_text, w)
            else:  # piper-tts >= 1.3 streams AudioChunks
                chunks = list(self._voice.synthesize(self._input_text))
                if not chunks:
                    return b"", 22050
                with wave.open(out, "wb") as w:
                    w.setnchannels(chunks[0].num_channels)
                    w.setsampwidth(chunks[0].sample_width)
                    w.setframerate(chunks[0].sample_rate)
                    for c in chunks:
                        w.writeframes(c.audio_int16_bytes)
            out.seek(0)
            with wave.open(out, "rb") as w:
                return w.readframes(w.getnframes()), w.getframerate()

        pcm, rate = await asyncio.get_running_loop().run_in_executor(None, synth)
        output_emitter.initialize(
            request_id=uuid.uuid4().hex, sample_rate=rate, num_channels=1, mime_type="audio/pcm"
        )
        output_emitter.push(pcm)
        output_emitter.flush()


# -------------------------------------------------------------------- Kokoro
KOKORO_BASE = "https://github.com/thewh1teagle/kokoro-onnx/releases/download/model-files-v1.0"
KOKORO_VOICE = os.environ.get("KOKORO_VOICE", "af_heart")
KOKORO_SPEED = float(os.environ.get("KOKORO_SPEED", "1.0"))


def ensure_kokoro():
    VOICE_DIR.mkdir(exist_ok=True)
    for name in ("kokoro-v1.0.onnx", "voices-v1.0.bin"):
        target = VOICE_DIR / name
        if not target.exists():
            print(f"Downloading Kokoro {name} (first run only)…")
            urllib.request.urlretrieve(f"{KOKORO_BASE}/{name}", target)
    return VOICE_DIR / "kokoro-v1.0.onnx", VOICE_DIR / "voices-v1.0.bin"


class KokoroTTS(tts.TTS):
    """Kokoro: a small local model that sounds like a person reading aloud,
    not a robot spelling. Warmed up at construction so any load problem
    (missing espeak, bad download) is found before the call starts."""

    def __init__(self):
        super().__init__(
            capabilities=tts.TTSCapabilities(streaming=False, aligned_transcript=False),
            sample_rate=24000,
            num_channels=1,
        )
        from kokoro_onnx import Kokoro

        model, voices = ensure_kokoro()
        self._kokoro = Kokoro(str(model), str(voices))
        self._kokoro.create("Hello.", voice=KOKORO_VOICE, speed=KOKORO_SPEED, lang="en-us")

    def synthesize(self, text, *, conn_options=APIConnectOptions()):
        return _KokoroStream(tts=self, input_text=text, conn_options=conn_options, kokoro=self._kokoro)


class _KokoroStream(tts.ChunkedStream):
    def __init__(self, *, tts, input_text, conn_options, kokoro):
        super().__init__(tts=tts, input_text=input_text, conn_options=conn_options)
        self._kokoro = kokoro

    async def _run(self, output_emitter):
        def synth():
            import numpy as np

            samples, rate = self._kokoro.create(
                self._input_text, voice=KOKORO_VOICE, speed=KOKORO_SPEED, lang="en-us"
            )
            return (np.clip(samples, -1.0, 1.0) * 32767).astype(np.int16).tobytes(), rate

        pcm, rate = await asyncio.get_running_loop().run_in_executor(None, synth)
        output_emitter.initialize(
            request_id=uuid.uuid4().hex, sample_rate=rate, num_channels=1, mime_type="audio/pcm"
        )
        output_emitter.push(pcm)
        output_emitter.flush()


def make_tts():
    """Kokoro first; Piper if Kokoro cannot load. AGENT_TTS=piper forces Piper."""
    if os.environ.get("AGENT_TTS", "kokoro").lower() != "piper":
        try:
            tts_impl = KokoroTTS()
            print(f"Voice: Kokoro ({KOKORO_VOICE})")
            return tts_impl
        except Exception as e:  # noqa: BLE001 - any load failure must not kill the call
            print(f"Kokoro unavailable ({e}); falling back to Piper.")
    print("Voice: Piper")
    return PiperTTS()


# --------------------------------------------------------------------- Agent
def instructions_for(meta):
    lines = [
        "You are Resonant's live tutor, talking with a blind student who is exploring a picture by touch. "
        "Speak in plain words, one to three short sentences per answer. No lists, no markdown. "
        "The student may interrupt you at any time; if they do, stop graciously and answer the new thing. "
        "If the picture does not show the answer, say so honestly.",
    ]
    if meta.get("title"):
        lines.append(f'The picture is titled "{meta["title"]}".')
    if meta.get("overview"):
        lines.append(f"Overview: {meta['overview']}")
    if meta.get("regionLabel"):
        lines.append(
            f'Their finger was most recently on "{meta["regionLabel"]}". '
            f"{meta.get('regionSpoken', '')} {meta.get('regionDetail', '')}".strip()
        )
    return "\n".join(lines)


async def entrypoint(ctx: JobContext):
    # Start loading the voice at once: it takes seconds, and it can warm up
    # while the room connects instead of after the student is already waiting.
    voice_task = asyncio.get_running_loop().run_in_executor(None, make_tts)
    await ctx.connect()
    student = await ctx.wait_for_participant()
    raw_meta = student.metadata
    try:
        meta = json.loads(raw_meta) if isinstance(raw_meta, str) and raw_meta else {}
    except json.JSONDecodeError:
        meta = {}
    if not isinstance(meta, dict):
        meta = {}

    ears = WhisperSTT()
    await ears.preload()  # first join should not pay the model-load cost

    session = AgentSession(
        vad=silero.VAD.load(),
        stt=ears,
        llm=SparkLLM(),
        tts=await voice_task,
        allow_interruptions=True,
        min_interruption_duration=0.35,
        preemptive_generation=True,
    )
    await session.start(Agent(instructions=instructions_for(meta)), room=ctx.room)
    session.generate_reply(
        instructions=(
            "Greet the student in one short warm sentence, name the picture, and invite them to "
            "ask anything about it — and to interrupt you whenever they like."
        )
    )


if __name__ == "__main__":
    cli.run_app(WorkerOptions(entrypoint_fnc=entrypoint))
