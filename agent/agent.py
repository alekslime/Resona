# Resonant live tutor: interruptible voice conversation about a picture.
#   ears  : Silero VAD + local faster-whisper (free, on this laptop)
#   brain : Muse Spark via the Meta Responses API (Meta credits)
#   voice : local Piper TTS (free)
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

    def __init__(self, model="base.en"):
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
        tts=PiperTTS(),
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
