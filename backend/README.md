# Resonant backend

Muse Spark names the parts of a picture and places a box around each one. The Meta key stays here.

```bash
npm install
cp .env.example .env     # add MODEL_API_KEY
npm run check:api        # confirms the model answers
npm start                # http://localhost:3000
npm test
```

- `POST /api/analyze` `{ image: "data:image/jpeg;base64,..." }` returns the title, overview and parts the chat announces. Identical pictures are served from an in-memory cache (one Spark call per picture).
- `POST /api/chat` `{ image?, question, title, regionLabel, history: [{q, a}] }` returns `{ answer }` — the multi-turn voice tutor; history is capped to the last 6 turns. Without an image it is a text-only tutor.
- `GET /sample/sample.json` is the hand-authored sample (not model output).
- If `../build/web` exists (after `flutter build web`), the server serves it too, so one URL gives judges both the app and the API.
- Requests are rate-limited per address so a public demo cannot drain credits.
