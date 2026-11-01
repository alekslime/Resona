# Resonant live voice agent

The "Talk live" tutor: a LiveKit Agents worker that joins the same room as the
phone, listens with local Whisper, thinks with Muse Spark, and speaks with a
local Kokoro voice (Piper if Kokoro cannot load). The student can interrupt
mid-sentence — when they start talking, the agent stops speaking and listens
(that is the whole point).

Free on purpose: LiveKit Cloud's free tier carries the audio, speech-to-text
and text-to-speech run on this laptop, and Muse Spark runs on Meta API
credits. Nothing here needs a paid LiveKit plan.

## Run it

From the repo root, with the backend already running:

```bash
cd agent
pip install -r requirements.txt
python agent.py download-files   # Silero VAD (first run only)
python agent.py dev              # joins rooms the backend creates
```

Voice: Kokoro by default (`KOKORO_VOICE` picks the voice, `af_heart` unless
set; `AGENT_TTS=piper` forces the Piper fallback). Kokoro's model (~340 MB)
and the Piper voice download into `voices/` on first use — run one
`python agent.py console` session before filming so the first real call
does not pay that download. Both voices are gitignored; never commit them.

Keys come from `../backend/.env` (`MODEL_API_KEY`, `LIVEKIT_URL`,
`LIVEKIT_API_KEY`, `LIVEKIT_API_SECRET`) — this folder has no keys of its own.
Never commit real keys anywhere in this repo.

Test without a phone: `python agent.py console` talks to the agent through
this computer's microphone and speakers, barge-in included.
