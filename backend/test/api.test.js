import test from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { createApp } from "../server/index.js";
import { DOCS_LINE, parseLine } from "./helpers.js";

const here = path.dirname(fileURLToPath(import.meta.url));
const png = fs.readFileSync(path.join(here, "..", "sample", "sample.png"));
const image = `data:image/png;base64,${png.toString("base64")}`;

// A stand-in for the Meta API so the whole server flow runs offline.
const fakeMeta = {
  sparkModel: "fake-spark",
  samModel: "fake-sam",
  async describeParts() {
    return {
      title: "Test picture",
      kind: "diagram",
      overview: "Two buttons.",
      parts: [
        { label: "button", spoken: "A button.", detail: "A round button." },
        { label: "missing thing", spoken: "Nothing.", detail: "Nothing." },
      ],
    };
  },
  async segment(_img, concept) {
    return parseLine(concept === "button" ? DOCS_LINE : "");
  },
  async ask(_img, question, ctx) {
    return `You asked "${question}" near ${ctx.regionLabel || "nothing"}.`;
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

test("analyze returns regions and reports parts SAM could not find", async () => {
  await withServer(fakeMeta, async (base) => {
    const res = await post(base, "/api/analyze", { image });
    assert.equal(res.status, 200);
    const data = await res.json();
    assert.equal(data.title, "Test picture");
    assert.equal(data.regions.length, 2);
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

test("ask passes the touched part as context", async () => {
  await withServer(fakeMeta, async (base) => {
    const res = await post(base, "/api/ask", { image, question: "What is this?", regionLabel: "sun" });
    assert.equal((await res.json()).answer, 'You asked "What is this?" near sun.');
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
