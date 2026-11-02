import test from "node:test";
import assert from "node:assert/strict";
import express from "express";
import { createLimiter } from "../server/limit.js";

async function withApp(middleware, fn) {
  const app = express();
  app.set("trust proxy", 1); // X-Forwarded-For drives req.ip, like behind Fly.io
  app.get("/ping", middleware, (_req, res) => res.json({ ok: true }));
  const server = app.listen(0);
  const base = `http://127.0.0.1:${server.address().port}`;
  try {
    await fn(base);
  } finally {
    server.close();
  }
}

test("the limiter allows max requests, then answers 429 with Retry-After", async () => {
  const limit = createLimiter({ max: 2, windowMs: 60_000 });
  await withApp(limit, async (base) => {
    assert.equal((await fetch(`${base}/ping`)).status, 200);
    assert.equal((await fetch(`${base}/ping`)).status, 200);
    const res = await fetch(`${base}/ping`);
    assert.equal(res.status, 429);
    assert.equal(res.headers.get("retry-after"), "60");
    assert.match((await res.json()).error, /Too many requests/);
  });
});

test("the window expiring lets the same client back in", async () => {
  let at = 1_000_000;
  const limit = createLimiter({ max: 1, windowMs: 60_000, now: () => at });
  await withApp(limit, async (base) => {
    assert.equal((await fetch(`${base}/ping`)).status, 200);
    assert.equal((await fetch(`${base}/ping`)).status, 429);
    at += 60_000;
    assert.equal((await fetch(`${base}/ping`)).status, 200);
  });
});

test("stale entries are swept instead of piling up", async () => {
  let at = 1_000_000;
  const limit = createLimiter({ max: 100, windowMs: 60_000, now: () => at });
  await withApp(limit, async (base) => {
    await fetch(`${base}/ping`, { headers: { "X-Forwarded-For": "10.0.0.1" } });
    assert.equal(limit.size(), 1);
    at += 61_000;
    await fetch(`${base}/ping`, { headers: { "X-Forwarded-For": "10.0.0.2" } });
    assert.equal(limit.size(), 1);
  });
});

test("the table never exceeds maxKeys, oldest first", async () => {
  const limit = createLimiter({ max: 100, windowMs: 60_000, maxKeys: 2 });
  await withApp(limit, async (base) => {
    for (const ip of ["10.0.0.1", "10.0.0.2", "10.0.0.3"]) {
      await fetch(`${base}/ping`, { headers: { "X-Forwarded-For": ip } });
    }
    assert.equal(limit.size(), 2);
  });
});
