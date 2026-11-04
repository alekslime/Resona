import test from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { createApp } from "../server/index.js";

const here = path.dirname(fileURLToPath(import.meta.url));
const png = fs.readFileSync(path.join(here, "..", "sample", "sample.png"));
const image = `data:image/png;base64,${png.toString("base64")}`;

// A stand-in for the Meta API so the whole server flow runs offline.
const fakeMeta = {
  sparkModel: "fake-spark",
  async describeParts() {
    return {
      title: "Test picture",
      kind: "diagram",
      overview: "Two buttons.",
      parts: [
        { label: "button", spoken: "A button.", detail: "A round button.", where: [0.1, 0.2, 0.3, 0.4] },
        { label: "missing thing", spoken: "Nothing.", detail: "Nothing." },
      ],
    };
  },
  async chat(_img, question, ctx) {
    return `Chat (${ctx.history.length} past): "${question}" near ${ctx.regionLabel || "nothing"}.`;
  },
};

async function withServer(meta, fn) {
  const server = createApp(meta).listen(0);
  const base = `http://127.0.0.1:${server.address().port}`;
  try {
    await fn(base);
  } finally {
    server.close();
  }
}
const post = (base, url, body) =>
  fetch(base + url, { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify(body) });

test("analyze returns regions and reports parts without a usable box", async () => {
  await withServer(fakeMeta, async (base) => {
    const res = await post(base, "/api/analyze", { image });
    assert.equal(res.status, 200);
    const data = await res.json();
    assert.equal(data.title, "Test picture");
    assert.equal(data.regions.length, 1);
    assert.deepEqual(data.regions[0].box, [80, 120, 240, 240]);
    assert.equal(data.regions[0].approximate, true);
    assert.deepEqual(data.skipped, ["missing thing"]);
    assert.equal(data.width, 800);
  });
});

test("analyze rejects non-pictures", async () => {
  await withServer(fakeMeta, async (base) => {
    const res = await post(base, "/api/analyze", { image: "data:text/plain;base64,aGk=" });
    assert.equal(res.status, 400);
    assert.match((await res.json()).error, /PNG, JPEG or WebP/);
  });
});

test("without a key the server says so plainly and the sample still serves", async () => {
  await withServer(null, async (base) => {
    const res = await post(base, "/api/analyze", { image });
    assert.equal(res.status, 503);
    assert.match((await res.json()).error, /MODEL_API_KEY/);
    const sample = await fetch(base + "/sample/sample.json");
    assert.equal((await sample.json()).synthetic, true);
  });
});

test("chat carries history and the touched part", async () => {
  await withServer(fakeMeta, async (base) => {
    const res = await post(base, "/api/chat", {
      image,
      question: "And why?",
      regionLabel: "sun",
      history: [{ q: "What is this?", a: "The sun." }],
    });
    assert.equal((await res.json()).answer, 'Chat (1 past): "And why?" near sun.');
  });
});

test("chat answers without a picture (text only)", async () => {
  await withServer(fakeMeta, async (base) => {
    const res = await post(base, "/api/chat", { question: "What is the capital of France?" });
    assert.equal(res.status, 200);
    assert.equal((await res.json()).answer, 'Chat (0 past): "What is the capital of France?" near nothing.');
  });
});

test("chat rejects a malformed image instead of answering blind", async () => {
  await withServer(fakeMeta, async (base) => {
    const res = await post(base, "/api/chat", { image: "not-a-picture", question: "Hi?" });
    assert.equal(res.status, 400);
    assert.match((await res.json()).error, /PNG, JPEG or WebP/);
  });
});

test("analyze is cached: the same picture is described once", async () => {
  let describes = 0;
  const counting = { ...fakeMeta, describeParts: async (...a) => { describes++; return fakeMeta.describeParts(...a); } };
  await withServer(counting, async (base) => {
    await post(base, "/api/analyze", { image });
    await post(base, "/api/analyze", { image });
    // The second analyze is a cache hit and describes nothing at all.
    assert.equal(describes, 1);
  });
});

test("samples gallery lists the bundled pictures with their outlines", async () => {
  await withServer(fakeMeta, async (base) => {
    const res = await fetch(base + "/api/samples");
    assert.equal(res.status, 200);
    const ids = (await res.json()).samples.map((s) => s.id).sort();
    assert.deepEqual(ids, ["chart", "sample"]);
    const chart = (await (await fetch(base + "/api/samples")).json()).samples.find((s) => s.id === "chart");
    assert.equal(chart.kind, "chart");
    assert.equal(chart.regions, 5);
    const json = await (await fetch(base + chart.json)).json();
    assert.equal(json.synthetic, true);
    assert.equal(json.regions.length, 5);
    const png = await fetch(base + chart.image);
    assert.equal(png.status, 200);
  });
});

test("analyze-stream emits progress per part, then the full payload", async () => {
  await withServer(fakeMeta, async (base) => {
    const res = await post(base, "/api/analyze-stream", { image });
    assert.equal(res.status, 200);
    assert.match(res.headers.get("content-type"), /text\/event-stream/);
    const events = [];
    for (const chunk of (await res.text()).split("\n\n")) {
      const m = /event: (\w+)\ndata: (.*)/s.exec(chunk.trim());
      if (m) events.push([m[1], JSON.parse(m[2])]);
    }
    const progress = events.filter(([e]) => e === "progress");
    assert.equal(progress.length, 2);
    assert.deepEqual(progress[0][1].total, 2);
    assert.deepEqual(
      progress.map(([, p]) => p.done).sort(),
      [1, 2],
    );
    const done = events.find(([e]) => e === "done");
    assert.equal(done[1].title, "Test picture");
    assert.equal(done[1].regions.length, 1);
    assert.ok(!events.some(([e]) => e === "error"));
  });
});

test("a failing model never leaks details to the browser", async () => {
  const broken = { ...fakeMeta, describeParts: async () => { throw new Error("secret-internal-detail"); } };
  const quiet = console.error;
  console.error = () => {};
  try {
    await withServer(broken, async (base) => {
      const res = await post(base, "/api/analyze", { image });
      assert.equal(res.status, 502);
      assert.doesNotMatch(JSON.stringify(await res.json()), /secret-internal-detail/);
    });
  } finally {
    console.error = quiet;
  }
});
