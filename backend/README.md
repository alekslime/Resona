# Resonant backend

Muse Spark names the parts of a picture; SAM 3.1 outlines each one. The Meta key stays here.

```bash
npm install
cp .env.example .env     # add MODEL_API_KEY
npm run check:api        # confirms both models answer
npm start                # http://localhost:3000
npm test
```

- `POST /api/analyze` `{ image: "data:image/jpeg;base64,..." }` returns the regions the app makes touchable. Identical pictures are served from an in-memory cache (one Spark + SAM run per picture).
- `POST /api/ask` `{ image, question, title, regionLabel }` returns `{ answer }`.
- `POST /api/chat` `{ image, question, title, regionLabel, history: [{q, a}] }` returns `{ answer }` — the multi-turn voice tutor; history is capped to the last 6 turns.
- `POST /api/lesson` `{ title, overview, regions: [{id, label, spoken, detail}] }` returns `{ steps: [{regionId, say}] }`. Text-only Spark call (no image, no SAM); falls back to a template lesson built from the regions if the model output is unusable.
- `POST /api/quiz` (same body) returns `{ questions: [{kind: "find" | "say", regionId, question, expected?}] }`, with the same fallback guarantee.
- `POST /api/grade` `{ question, expected, answer }` returns `{ correct, say }` for spoken answers. Find-it answers never reach the server — the app grades them by hit-testing the finger.
- `GET /sample/sample.json` is the hand-authored sample (not model output).
- If `../build/web` exists (after `flutter build web`), the server serves it too, so one URL gives judges both the app and the API.
- Requests are rate-limited per address so a public demo cannot drain credits.
