import test from "node:test";
import assert from "node:assert/strict";
import { createApp } from "../server/index.js";

async function withServer(meta, fn) {
  const server = createApp(meta).listen(0);
  const base = `http://127.0.0.1:${server.address().port}`;
  try {
    await fn(base);
  } finally {
    server.close();
  }
}

// /api/grade with no Meta key answers 503 before touching the body, so it
// exercises the limiter deterministically with no model and no fixtures.
const grade = (base, ip) =>
  fetch(`${base}/api/grade`, {
    method: "POST",
    headers: { "Content-Type": "application/json", "X-Forwarded-For": ip },
    body: "{}",
  });

async function withTrustProxy(value, fn) {
  const prev = process.env.TRUST_PROXY;
  if (value === undefined) delete process.env.TRUST_PROXY;
  else process.env.TRUST_PROXY = value;
  try {
    await fn();
  } finally {
    if (prev === undefined) delete process.env.TRUST_PROXY;
    else process.env.TRUST_PROXY = prev;
  }
}

test("responses hide the framework and carry basic security headers", async () => {
  await withServer(null, async (base) => {
    const res = await fetch(`${base}/api/health`);
    assert.equal(res.status, 200);
    assert.equal(res.headers.get("x-powered-by"), null);
    assert.equal(res.headers.get("x-content-type-options"), "nosniff");
    assert.equal(res.headers.get("referrer-policy"), "no-referrer");
  });
});

test("unknown API routes answer JSON; other pages keep the default", async () => {
  await withServer(null, async (base) => {
    const api = await fetch(`${base}/api/nope`);
    assert.equal(api.status, 404);
    assert.match(api.headers.get("content-type"), /json/);
    assert.deepEqual(await api.json(), { error: "No such API route." });
    const page = await fetch(`${base}/nope`);
    assert.equal(page.status, 404);
    assert.match(page.headers.get("content-type"), /html/);
  });
});

test("behind a proxy each client gets its own bucket", async () => {
  await withTrustProxy("1", async () => {
    await withServer(null, async (base) => {
      for (let i = 0; i < 20; i++) assert.equal((await grade(base, "10.9.9.9")).status, 503);
      assert.equal((await grade(base, "10.9.9.9")).status, 429);
      assert.equal((await grade(base, "10.9.9.8")).status, 503);
    });
  });
});

test("by default a forwarded header cannot escape the shared bucket", async () => {
  await withTrustProxy(undefined, async () => {
    await withServer(null, async (base) => {
      for (let i = 0; i < 20; i++) assert.equal((await grade(base, "10.9.9.9")).status, 503);
      assert.equal((await grade(base, "10.9.9.9")).status, 429);
      assert.equal((await grade(base, "10.9.9.8")).status, 429);
    });
  });
});
