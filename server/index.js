import "dotenv/config";
import express from "express";
import os from "node:os";
import path from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";
import { imageSize } from "image-size";
import { createMeta, mapLimit } from "./meta.js";
import { buildRegions } from "./regions.js";

const here = path.dirname(fileURLToPath(import.meta.url));
const publicDir = path.join(here, "..", "public");

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
  return { width: size.width, height: size.height };
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
  app.use(express.json({ limit: "12mb" }));
  app.use(express.static(publicDir));

  app.get("/api/health", (_req, res) => {
    res.json({ ok: true, metaConfigured: Boolean(meta), sparkModel: meta?.sparkModel ?? null, samModel: meta?.samModel ?? null });
  });

  app.post("/api/analyze", limiter(6, 60_000), async (req, res, next) => {
    try {
      if (!meta) throw httpError(503, "This server has no Meta API key. Add MODEL_API_KEY to .env, or try the sample picture.");
      const { width, height } = parseImage(req.body?.image);
      const dataUrl = req.body.image;

      // 1. Muse Spark reads the picture and names its parts.
      const described = await meta.describeParts(dataUrl);

      // 2. SAM 3.1 finds the exact pixels of each part (one request per concept).
      const results = await mapLimit(described.parts, 3, async (part) => {
        try {
          return { part, records: (await meta.segment(dataUrl, part.label)).records };
        } catch (err) {
          console.error(`segment "${part.label}" failed:`, err?.message ?? err);
          return { part, records: [] };
        }
      });

      const regions = results.flatMap(({ part, records }, partIndex) =>
        buildRegions({ part, partIndex, records, imgW: width, imgH: height }),
      );
      if (!regions.length) {
        throw httpError(422, "No parts could be outlined in this picture. Try a clearer picture with distinct shapes.");
      }
      res.json({
        width,
        height,
        title: described.title,
        kind: described.kind,
        overview: described.overview,
        regions,
        skipped: results.filter((r) => !r.records.length).map((r) => r.part.label),
      });
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
    console.log(`Touch Atlas on http://localhost:${port}`);
    for (const ip of lanAddresses()) console.log(`  on your network: http://${ip}:${port}`);
    if (!meta) console.log("No MODEL_API_KEY set: only the sample picture will work.");
  });
}
