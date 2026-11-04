import "dotenv/config";
import express from "express";
import crypto from "node:crypto";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";
import { imageSize } from "image-size";
import { createMeta } from "./meta.js";
import { createLimiter } from "./limit.js";
import { buildRegions, dedupeRegions } from "./regions.js";
import { orientedSize } from "./orient.js";
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

export function createApp(meta) {
  const app = express();
  app.disable("x-powered-by");
  // Behind Fly.io/Railway the client IP arrives in X-Forwarded-For; without
  // this the limiter would put every visitor in one bucket. Off unless the
  // deploy says otherwise, so a directly exposed server never trusts a
  // client-spoofed header.
  app.set("trust proxy", Number(process.env.TRUST_PROXY ?? 0) || 0);
  // One analyze is one Spark call. Cache by picture so lesson, quiz and chat
  // demos re-opening the same picture never pay for it twice.
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
  app.use(express.json({ limit: "12mb" }));
  app.use((_req, res, next) => {
    res.set({
      "X-Content-Type-Options": "nosniff",
      "Referrer-Policy": "no-referrer",
    });
    next();
  });
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
    res.json({ ok: true, metaConfigured: Boolean(meta), liveKitConfigured: Boolean(liveKitConfig()) });
  });

  // Instant demo pictures: every *.json in sample/ with a matching *.png beside it.
  // Works with no API key, so judges can always try the touch interface.
  app.get("/api/samples", (_req, res) => {
    const samples = [];
    let files = [];
    try {
      files = fs.readdirSync(sampleDir);
    } catch {
      return res.json({ samples });
    }
    for (const f of files) {
      if (!f.endsWith(".json")) continue;
      try {
        const j = JSON.parse(fs.readFileSync(path.join(sampleDir, f), "utf8"));
        const id = path.basename(f, ".json");
        samples.push({
          id,
          title: String(j.title ?? id),
          kind: String(j.kind ?? "other"),
          regions: Array.isArray(j.regions) ? j.regions.length : 0,
          json: `/sample/${id}.json`,
          image: fs.existsSync(path.join(sampleDir, `${id}.png`)) ? `/sample/${id}.png` : null,
        });
      } catch {
        // skip unreadable entries; one bad file must not hide the rest
      }
    }
    samples.sort((a, b) => a.id.localeCompare(b.id));
    res.json({ samples });
  });

  // The full pipeline: one Spark call names the parts and places a tight box
  // around each one. onPart fires per part, so callers can stream progress.
  const analyzeImage = async (dataUrl, width, height, onPart) => {
    const described = await meta.describeParts(dataUrl);
    const perPart = described.parts.map((part, partIndex) => {
      const regions = buildRegions({ part, partIndex, imgW: width, imgH: height });
      onPart?.({ done: partIndex + 1, total: described.parts.length, label: part.label });
      return { part, regions };
    });
    const regions = dedupeRegions(perPart.flatMap((p) => p.regions));
    if (!regions.length) {
      throw httpError(422, "No parts could be placed in this picture. Try a clearer picture with distinct shapes.");
    }
    return {
      width,
      height,
      title: described.title,
      kind: described.kind,
      overview: described.overview,
      regions,
      skipped: perPart.filter((p) => !p.regions.length).map((p) => p.part.label),
    };
  };

  app.post("/api/analyze", createLimiter({ max: 6, windowMs: 60_000 }), async (req, res, next) => {
    try {
      if (!meta) throw httpError(503, "This server has no Meta API key. Add MODEL_API_KEY to .env, or try the sample picture.");
      const { width, height } = parseImage(req.body?.image);
      const dataUrl = req.body.image;
      const cached = cacheGet(dataUrl);
      if (cached) return res.json(cached);
      const payload = await analyzeImage(dataUrl, width, height);
      cachePut(dataUrl, payload);
      res.json(payload);
    } catch (err) {
      next(err);
    }
  });

  // Same pipeline as /api/analyze, as server-sent events: one "progress" event
  // per part ({done, total, label}), then "done" with the full payload
  // or "error" with {error}. The phone speaks the progress instead of sitting silent.
  app.post("/api/analyze-stream", createLimiter({ max: 6, windowMs: 60_000 }), async (req, res, next) => {
    try {
      if (!meta) throw httpError(503, "This server has no Meta API key. Add MODEL_API_KEY to .env, or try the sample picture.");
      const { width, height } = parseImage(req.body?.image);
      const dataUrl = req.body.image;
      const cached = cacheGet(dataUrl);
      res.set({ "Content-Type": "text/event-stream", "Cache-Control": "no-cache", Connection: "keep-alive" });
      res.flushHeaders?.();
      // A phone that locks mid-analysis drops the stream: stop writing
      // instead of throwing into finished work. The analysis is still
      // cached below, so the paid work is never wasted.
      let alive = true;
      let finished = false;
      res.on("close", () => {
        if (!finished) alive = false;
      });
      const send = (event, obj) => {
        if (!alive || res.writableEnded) return;
        try {
          res.write(`event: ${event}\ndata: ${JSON.stringify(obj)}\n\n`);
        } catch {
          alive = false;
        }
      };
      if (cached) {
        send("done", cached);
        finished = true;
        return res.end();
      }
      try {
        const payload = await analyzeImage(dataUrl, width, height, (p) => send("progress", p));
        cachePut(dataUrl, payload);
        send("done", payload);
      } catch (err) {
        send("error", { error: err?.expose ? err.message : "The Meta model request failed. Try again in a moment." });
        if (!err?.expose) console.error(err);
      }
      finished = true;
      res.end();
    } catch (err) {
      next(err);
    }
  });

  app.post("/api/chat", createLimiter({ max: 20, windowMs: 60_000 }), async (req, res, next) => {
    try {
      requireMeta();
      // The image is optional: with one the tutor sees the picture, without
      // one it answers from the question and history alone. A present but
      // malformed image is still a 400 — never answer blind by accident.
      const rawImage = req.body?.image;
      const image = typeof rawImage === "string" && rawImage ? rawImage : null;
      if (image) parseImage(image);
      const question = String(req.body?.question ?? "").trim().slice(0, 500);
      if (!question) throw httpError(400, "Say or type a question first.");
      const history = (Array.isArray(req.body?.history) ? req.body.history : [])
        .filter((h) => h && typeof h.q === "string" && typeof h.a === "string")
        .slice(-6)
        .map((h) => ({ q: h.q.slice(0, 500), a: h.a.slice(0, 1000) }));
      const answer = await meta.chat(image, question, {
        title: String(req.body?.title ?? "").slice(0, 200),
        regionLabel: String(req.body?.regionLabel ?? "").slice(0, 200),
        history,
      });
      res.json({ answer });
    } catch (err) {
      next(err);
    }
  });

  app.post("/api/livekit-token", createLimiter({ max: 10, windowMs: 60_000 }), async (req, res, next) => {
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

  // Unknown API routes answer JSON like the rest of the API; anything else
  // keeps Express's default page for browsers.
  app.use("/api", (_req, res) => res.status(404).json({ error: "No such API route." }));
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
