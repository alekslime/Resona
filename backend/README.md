# Resonant backend

Muse Spark names the parts of a picture; SAM 3.1 outlines each one. The Meta key stays here.

```bash
npm install
cp .env.example .env     # add MODEL_API_KEY
npm run check:api        # confirms both models answer
npm start                # http://localhost:3000
npm test
```

- `POST /api/analyze` `{ image: "data:image/jpeg;base64,..." }` returns the regions the app makes touchable.
- `POST /api/ask` `{ image, question, title, regionLabel }` returns `{ answer }`.
- `GET /sample/sample.json` is the hand-authored sample (not model output).
- If `../build/web` exists (after `flutter build web`), the server serves it too, so one URL gives judges both the app and the API.
- Requests are rate-limited per address so a public demo cannot drain credits.
