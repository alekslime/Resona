import test from "node:test";
import assert from "node:assert/strict";
import crypto from "node:crypto";
import { createApp } from "../server/index.js";
import { liveKitConfig, mintLiveKitToken } from "../server/livekit.js";

const decode = (seg) => JSON.parse(Buffer.from(seg, "base64url").toString());

test("no LiveKit keys in the environment means live voice is off", () => {
  assert.equal(liveKitConfig({}), null);
  assert.ok(liveKitConfig({ LIVEKIT_URL: "wss://x", LIVEKIT_API_KEY: "k", LIVEKIT_API_SECRET: "s" }));
});

test("a minted token is a verifiable HS256 JWT with room grants", () => {
  const token = mintLiveKitToken(
    { apiKey: "APIKEY", apiSecret: "secret" },
    { identity: "student-1", room: "resonant-1", metadata: '{"title":"Sun"}' },
  );
  const [h, p, sig] = token.split(".");
  assert.equal(decode(h).alg, "HS256");
  const payload = decode(p);
  assert.equal(payload.iss, "APIKEY");
  assert.equal(payload.sub, "student-1");
  assert.equal(payload.video.room, "resonant-1");
  assert.equal(payload.video.roomJoin, true);
  assert.deepEqual(JSON.parse(payload.metadata), { title: "Sun" });
  const expected = crypto.createHmac("sha256", "secret").update(`${h}.${p}`).digest("base64url");
  assert.equal(sig, expected);
});

async function withServer(fn) {
  const server = createApp(null).listen(0);
  const base = `http://127.0.0.1:${server.address().port}`;
  try {
    await fn(base);
  } finally {
    server.close();
  }
}

test("token endpoint: 503 without keys, a room and token with keys", async () => {
  const saved = { ...process.env };
  delete process.env.LIVEKIT_URL;
  delete process.env.LIVEKIT_API_KEY;
  delete process.env.LIVEKIT_API_SECRET;
  try {
    await withServer(async (base) => {
      const res = await fetch(base + "/api/livekit-token", { method: "POST", headers: { "Content-Type": "application/json" }, body: "{}" });
      assert.equal(res.status, 503);
    });
    process.env.LIVEKIT_URL = "wss://example.livekit.cloud";
    process.env.LIVEKIT_API_KEY = "APIKEY";
    process.env.LIVEKIT_API_SECRET = "secret";
    await withServer(async (base) => {
      const res = await fetch(base + "/api/livekit-token", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ title: "Water cycle", regionLabel: "sun" }),
      });
      assert.equal(res.status, 200);
      const data = await res.json();
      assert.equal(data.url, "wss://example.livekit.cloud");
      assert.match(data.room, /^resonant-/);
      const payload = decode(data.token.split(".")[1]);
      assert.equal(JSON.parse(payload.metadata).regionLabel, "sun");
      const health = await (await fetch(base + "/api/health")).json();
      assert.equal(health.liveKitConfigured, true);
    });
  } finally {
    process.env = saved;
  }
});
