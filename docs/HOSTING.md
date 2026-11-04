# Hosting the backend

The backend is a plain Node 20+ Express server (`backend/server/index.js`). It reads
everything from environment variables and listens on `PORT` (default 3000), so it
runs on any container host: Modal, Render, Fly.io, Railway, or a spare laptop.

## 1. Environment

Copy `backend/.env.example` to `.env`, or set these on the host:

| Variable | Required | What |
| --- | --- | --- |
| `MODEL_API_KEY` | yes for new pictures | Meta Model API key from <https://dev.meta.ai/platform> |
| `LIVEKIT_URL`, `LIVEKIT_API_KEY`, `LIVEKIT_API_SECRET` | only for Talk live | LiveKit Cloud free tier is enough |
| `MODEL_BASE_URL` | no | Defaults to `https://api.meta.ai/v1` |
| `SPARK_MODEL` | no | Defaults to `muse-spark-1.3` |
| `SPARK_REASONING_EFFORT` | no | `low` by default; raise for harder pictures |
| `PORT` | no | Defaults to 3000 |

Without `MODEL_API_KEY` the server still runs: `/api/health` reports
`metaConfigured: false`, the `/sample/...` gallery serves, and every model
endpoint answers 503 with a plain sentence. Judges can always try the samples.

## 2. Deploy

**Option A — Render API (fastest, free).** Dashboard → New → Blueprint, point it at
this repo (`render.yaml` at the root), add `MODEL_API_KEY` as a secret env var.
Health check is `GET /api/health`. Free instances sleep when idle: the first request
takes ~30 s to wake them, and the app's bundled samples work even while it wakes.

**Option B — one URL (Docker, for Fly.io / Railway / a VPS).** The image serves the
Flutter web build from `/` when it is baked in:

```bash
flutter build web --dart-define=API_BASE=https://<your-host>
docker build -f backend/Dockerfile -t resonant .
docker run -p 3000:3000 -e MODEL_API_KEY=... resonant
```

Any host that runs `npm start` also works without Docker:

```bash
cd backend && npm install --omit=dev && npm start
```

Then point the app at it:

```bash
flutter run --dart-define=API_BASE=https://<your-host>
```

## 2b. Bake gallery extras (do this before you deploy)

Judges tap gallery entries; entries with committed outlines open instantly and cost
nothing. With the backend running locally **with your key**:

```bash
cd backend
npm run sample:add -- ./lungs.png lungs
npm run sample:add -- ./transit-map.png transit-map
git add sample/ && git commit -m "samples: bake gallery extras" && git push
```

Backend extras need no app changes: `GET /api/samples` picks them up and the app
fetches their outlines and pictures on demand. (PNG only, under 8 MB.)

## 3. One-URL demo (recommended for judges)

The backend serves `build/web` from `/` when it exists, so one link can carry
both the app and the API:

```bash
flutter build web --dart-define=API_BASE=https://<your-host>
cd backend && npm start   # serves the web build + /api/* + /sample/*
```

iPhone Safari gets speech and sound this way (no vibration — Safari has none).
See `docs/IPHONE.md`.

## 4. Cost guards (already in the server)

- `POST /api/analyze` responses are cached by image hash (20 pictures), so
  re-opening a demo picture is free.
- Per-IP rate limits: 6 analyzes/minute, 20 chats/minute.
- `GET /api/health` shows what is configured without leaking keys.

## 5. Public demo: always-on server + self-updating APK

For a demo strangers can use without touching a terminal:

1. Deploy the backend with Option A above (Render Blueprint from
   `render.yaml`). Add `MODEL_API_KEY` as a secret env var. Render
   redeploys the backend on every push to `main` by itself.
2. Always-on or free: the free plan sleeps after ~15 minutes idle
   and the first request takes ~30 s to wake it (the app's samples
   still work while it wakes). A Starter instance (~$7/month) never
   sleeps. Pick on the service's Settings page.
3. Tell CI where the backend lives: repo Settings -> Secrets and
   variables -> Actions -> Variables tab -> New variable
   `PUBLIC_API_BASE=https://<your-render-host>` (no trailing slash).
4. Every push to `main` that touches the app then rebuilds the APK
   (after `flutter analyze` + `flutter test` pass) and republishes
   it on the rolling `latest` release. One stable link always serves
   the newest build:
   `https://github.com/alekslime/Resona/releases/download/latest/resonant.apk`

The CI APK is signed with debug keys: it sideloads fine, but it is
not a Play Store upload. See `.github/workflows/apk.yml`.
