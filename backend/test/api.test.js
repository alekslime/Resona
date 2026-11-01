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
  async lesson(ctx) {
    return { steps: [{ regionId: null, say: `Lesson: ${ctx.title}` }, { regionId: ctx.regions[0].id, say: "First part." }] };
  },
  async quiz(ctx) {
    return { questions: [{ kind: "find", regionId: ctx.regions[0].id, question: "Find the button." }] };
  },
  async grade({ answer }) {
    return { correct: answer.includes("round"), say: answer.includes("round") ? "Correct." : "Not quite." };
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

const learnBody = {
  title: "Test picture",
  overview: "Two buttons.",
  regions: [{ id: "button-1", label: "button", spoken: "A button.", detail: "A round button." }],
};

test("lesson, quiz and grade work from region text alone (no image, no SAM)", async () => {
  await withServer(fakeMeta, async (base) => {
    const lesson = await post(base, "/api/lesson", learnBody);
    assert.equal(lesson.status, 200);
    assert.equal((await lesson.json()).steps.length, 2);
    const quiz = await post(base, "/api/quiz", learnBody);
    assert.equal((await quiz.json()).questions[0].kind, "find");
    const grade = await post(base, "/api/grade", { question: "What shape?", expected: "round", answer: "It is round." });
    assert.equal((await grade.json()).correct, true);
  });
});

test("lesson without regions is a plain 400, and without a key a plain 503", async () => {
  await withServer(fakeMeta, async (base) => {
    const res = await post(base, "/api/lesson", { title: "x", regions: [] });
    assert.equal(res.status, 400);
  });
  await withServer(null, async (base) => {
    const res = await post(base, "/api/quiz", learnBody);
    assert.equal(res.status, 503);
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

test("analyze is cached: the same picture is only segmented once", async () => {
  let segments = 0;
  const counting = { ...fakeMeta, segment: async (...a) => { segments++; return fakeMeta.segment(...a); } };
  await withServer(counting, async (base) => {
    await post(base, "/api/analyze", { image });
    await post(base, "/api/analyze", { image });
    // "button" once + "missing thing" retried with simpler concepts; the second
    // analyze is a cache hit and segments nothing at all.
    assert.equal(segments, 4);
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
    assert.equal(done[1].regions.length, 2);
    assert.ok(!events.some(([e]) => e === "error"));
  });
});

test("parts are segmented in parallel, not one by one", async () => {
  let active = 0;
  let maxActive = 0;
  const slow = {
    ...fakeMeta,
    segment: async (...a) => {
      active++;
      maxActive = Math.max(maxActive, active);
      await new Promise((r) => setTimeout(r, 20));
      active--;
      return fakeMeta.segment(...a);
    },
  };
  await withServer(slow, async (base) => {
    const res = await post(base, "/api/analyze", { image });
    assert.equal(res.status, 200);
    assert.ok(maxActive >= 2, `expected parallel SAM calls, saw max ${maxActive} at once`);
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
