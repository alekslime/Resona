import "dotenv/config";
import express from "express";
import crypto from "node:crypto";
import os from "node:os";
import path from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";
import { imageSize } from "image-size";
import { createMeta, mapLimit } from "./meta.js";
import { buildRegions, conceptVariants, dedupeRegions } from "./regions.js";
import { orientedSize } from "./orient.js";
import { cleanRegions } from "./learn.js";
import { liveKitConfig, liveKitSession } from "./livekit.js";

const here = path.dirname(fileURLToPath(import.meta.url));
const sampleDir = path.join(here, "..", "sample");
const webDir = path.join(here, "..", "..", "build", "web"); // optional: serve the Flutter web build from the same URL

const DATA_URL = /^data:image\/(png|jpeg|webp);base64,([A-Za-z0-9+/=]+)$/;
const MAX_BYTES = 8 * 1024 * 1024;

function parseImage(dataUrl) {
  const m = typeof dataUrl === "string" ? DATA_URL.exec(dataUrl) : null;
  if (!m) throw httpError(400, "Send a PNG, JPEG or WebP picture.");
  const buf = Buffer.from(m[2], "base64");
  if (buf.length > MAX_BYTES) throw httpError(413, "That picture is too large. Try one under 8 MB.");
  let size;
  try {
    size = imageSize(buf);
  } catch {
    throw httpError(400, "That file could not be read as a picture.");
  }
  if (!size.width || !size.height || size.width < 64 || size.height < 64 || Math.max(size.width, size.height) > 4096) {
    throw httpError(400, "The picture must be between 64 and 4096 pixels on its longest side.");
  }
  return orientedSize(size);
}

function httpError(status, message) {
  return Object.assign(new Error(message), { status, expose: true });
}

// Tiny in-memory limiter so a public demo can't burn through the API credits.
function limiter(max, windowMs) {
  const hits = new Map();
  return (req, res, next) => {
    const now = Date.now();
    const key = req.ip;
    const recent = (hits.get(key) ?? []).filter((t) => now - t < windowMs);
    if (recent.length >= max) {
      return res.status(429).json({ error: "Too many requests. Wait a minute and try again." });
    }
    recent.push(now);
    hits.set(key, recent);
    next();
  };
}

export function createApp(meta) {
  const app = express();
  // One analyze costs 1 Spark + up to 8 SAM calls. Cache by picture so lesson,
  // quiz and chat demos re-opening the same picture never pay for it twice.
  const analyzeCache = new Map();
  const cacheGet = (image) => analyzeCache.get(crypto.createHash("sha256").update(image).digest("hex"));
  const cachePut = (image, value) => {
    const key = crypto.createHash("sha256").update(image).digest("hex");
    if (analyzeCache.size >= 20) analyzeCache.delete(analyzeCache.keys().next().value);
    analyzeCache.set(key, value);
  };
  const requireMeta = () => {
    if (!meta) throw httpError(503, "This server has no Meta API key. Add MODEL_API_KEY to .env.");
  };
  const learnCtx = (body) => {
    const regions = cleanRegions(body?.regions);
    if (!regions.length) throw httpError(400, "Explore a picture first, then start this.");
    return {
      title: String(body?.title ?? "Picture").slice(0, 200),
      overview: String(body?.overview ?? "").slice(0, 1000),
      regions,
    };
  };
  app.use(express.json({ limit: "12mb" }));
  // The mobile app and a separately hosted web build call this API from other origins.
  app.use((req, res, next) => {
    res.set({
      "Access-Control-Allow-Origin": "*",
      "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
      "Access-Control-Allow-Headers": "Content-Type",
    });
    if (req.method === "OPTIONS") return res.sendStatus(204);
    next();
  });
  app.use("/sample", express.static(sampleDir));
  app.use(express.static(webDir)); // no-op until `flutter build web` has been run

  app.get("/api/health", (_req, res) => {
    res.json({ ok: true, metaConfigured: Boolean(meta), sparkModel: meta?.sparkModel ?? null, samModel: meta?.samModel ?? null, liveKitConfigured: Boolean(liveKitConfig()) });
  });

  app.post("/api/analyze", limiter(6, 60_000), async (req, res, next) => {
    try {
      if (!meta) throw httpError(503, "This server has no Meta API key. Add MODEL_API_KEY to .env, or try the sample picture.");
      const { width, height } = parseImage(req.body?.image);
      const dataUrl = req.body.image;
      const cached = cacheGet(dataUrl);
      if (cached) return res.json(cached);

      // 1. Muse Spark reads the picture and names its parts.
      const described = await meta.describeParts(dataUrl);

      // 2. SAM 3.1 finds the exact pixels of each part (one request per concept).
      //    Labels SAM cannot ground ("orthodontic braces row") get retried with
      //    simpler concepts ("braces") before we give up on the mask.
      const segmentPart = async (part) => {
        for (const variant of conceptVariants(part.label)) {
          try {
            const records = (await meta.segment(dataUrl, variant)).records;
            if (records.length) return records;
          } catch (err) {
            console.error(`segment "${variant}" failed:`, err?.message ?? err);
          }
        }
        return [];
      };
      const results = await mapLimit(described.parts, 3, async (part) => ({
        part,
        records: await segmentPart(part),
      }));

      const perPart = results.map(({ part, records }, partIndex) => ({
        part,
        regions: buildRegions({ part, partIndex, records, imgW: width, imgH: height }),
      }));
      const regions = dedupeRegions(perPart.flatMap((p) => p.regions));
      if (!regions.length) {
        throw httpError(422, "No parts could be outlined in this picture. Try a clearer picture with distinct shapes.");
      }
      const payload = {
        width,
        height,
        title: described.title,
        kind: described.kind,
        overview: described.overview,
        regions,
        skipped: perPart.filter((p) => !p.regions.length).map((p) => p.part.label),
      };
      cachePut(dataUrl, payload);
      res.json(payload);
    } catch (err) {
      next(err);
    }
  });

  app.post("/api/ask", limiter(20, 60_000), async (req, res, next) => {
    try {
      if (!meta) throw httpError(503, "This server has no Meta API key. Add MODEL_API_KEY to .env.");
      parseImage(req.body?.image);
      const question = String(req.body?.question ?? "").trim().slice(0, 500);
      if (!question) throw httpError(400, "Say or type a question first.");
      const answer = await meta.ask(req.body.image, question, {
        title: String(req.body?.title ?? "").slice(0, 200),
        regionLabel: String(req.body?.regionLabel ?? "").slice(0, 200),
      });
      res.json({ answer });
    } catch (err) {
      next(err);
    }
  });

  app.post("/api/lesson", limiter(10, 60_000), async (req, res, next) => {
    try {
      requireMeta();
      res.json(await meta.lesson(learnCtx(req.body)));
    } catch (err) {
      next(err);
    }
  });

  app.post("/api/quiz", limiter(10, 60_000), async (req, res, next) => {
    try {
      requireMeta();
      res.json(await meta.quiz(learnCtx(req.body)));
    } catch (err) {
      next(err);
    }
  });

  app.post("/api/grade", limiter(20, 60_000), async (req, res, next) => {
    try {
      requireMeta();
      const question = String(req.body?.question ?? "").trim().slice(0, 500);
      const expected = String(req.body?.expected ?? "").trim().slice(0, 900);
      const answer = String(req.body?.answer ?? "").trim().slice(0, 500);
      if (!question || !expected || !answer) throw httpError(400, "Say your answer first.");
      res.json(await meta.grade({ question, expected, answer }));
    } catch (err) {
      next(err);
    }
  });

  app.post("/api/chat", limiter(20, 60_000), async (req, res, next) => {
    try {
      requireMeta();
      parseImage(req.body?.image);
      const question = String(req.body?.question ?? "").trim().slice(0, 500);
      if (!question) throw httpError(400, "Say or type a question first.");
      const history = (Array.isArray(req.body?.history) ? req.body.history : [])
        .filter((h) => h && typeof h.q === "string" && typeof h.a === "string")
        .slice(-6)
        .map((h) => ({ q: h.q.slice(0, 500), a: h.a.slice(0, 1000) }));
      const answer = await meta.chat(req.body.image, question, {
        title: String(req.body?.title ?? "").slice(0, 200),
        regionLabel: String(req.body?.regionLabel ?? "").slice(0, 200),
        history,
      });
      res.json({ answer });
    } catch (err) {
      next(err);
    }
  });

  app.post("/api/livekit-token", limiter(10, 60_000), async (req, res, next) => {
    try {
      const cfg = liveKitConfig();
      if (!cfg) {
        throw httpError(503, "Live voice is not set up on this server. Add LIVEKIT_URL, LIVEKIT_API_KEY and LIVEKIT_API_SECRET to .env.");
      }
      res.json(liveKitSession(cfg, req.body ?? {}));
    } catch (err) {
      next(err);
    }
  });

  // eslint-disable-next-line no-unused-vars
  app.use((err, _req, res, _next) => {
    if (err?.type === "entity.too.large") return res.status(413).json({ error: "That picture is too large. Try one under 8 MB." });
    if (err?.expose) return res.status(err.status ?? 400).json({ error: err.message });
    console.error(err); // details stay in the server log, never in the response
    res.status(502).json({ error: "The Meta model request failed. Try again in a moment." });
  });

  return app;
}

function lanAddresses() {
  return Object.values(os.networkInterfaces())
    .flat()
    .filter((i) => i && i.family === "IPv4" && !i.internal)
    .map((i) => i.address);
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  const apiKey = process.env.MODEL_API_KEY;
  const meta = apiKey
    ? createMeta({
        apiKey,
        baseURL: process.env.MODEL_BASE_URL || undefined,
        sparkModel: process.env.SPARK_MODEL || undefined,
        samModel: process.env.SAM_MODEL || undefined,
        effort: process.env.SPARK_REASONING_EFFORT || undefined,
      })
    : null;
  const port = Number(process.env.PORT) || 3000;
  createApp(meta).listen(port, "0.0.0.0", () => {
    console.log(`Resonant backend on http://localhost:${port}`);
    for (const ip of lanAddresses()) console.log(`  on your network: http://${ip}:${port}`);
    if (!meta) console.log("No MODEL_API_KEY set: only the sample picture will work.");
  });
}
