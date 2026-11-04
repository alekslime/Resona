import test from "node:test";
import assert from "node:assert/strict";
import { createApp } from "../server/index.js";
import { quizPayload } from "../server/meta.js";

const canned = (i) => ({
  prompt: `Question ${i}?`,
  options: [`Right ${i}`, `Wrong ${i}a`, `Wrong ${i}b`],
  correctIndex: 0,
  explanation: `Because ${i} is right.`,
});

// A stand-in for the Meta API so the whole quiz flow runs offline.
const fakeMeta = {
  sparkModel: "fake-spark",
  seen: null,
  async quiz(topic, { history }) {
    this.seen = { topic, history };
    return { topic, questions: [1, 2, 3, 4, 5].map(canned) };
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

test("quiz returns 5 valid multiple-choice questions", async () => {
  fakeMeta.seen = null;
  await withServer(fakeMeta, async (base) => {
    const res = await post(base, "/api/quiz", {
      topic: "The water cycle",
      history: [{ q: "What is this?", a: "The water cycle." }],
    });
    assert.equal(res.status, 200);
    const data = await res.json();
    assert.equal(data.topic, "The water cycle");
    assert.equal(data.questions.length, 5);
    for (const q of data.questions) {
      assert.ok(q.prompt.length > 0);
      assert.ok(q.options.length >= 3 && q.options.length <= 4);
      assert.ok(q.options.every((o) => typeof o === "string" && o.length > 0));
      assert.ok(Number.isInteger(q.correctIndex) && q.correctIndex >= 0 && q.correctIndex < q.options.length);
      assert.ok(q.explanation.length > 0);
    }
    assert.deepEqual(fakeMeta.seen.history, [{ q: "What is this?", a: "The water cycle." }]);
  });
});

test("quiz caps history at 6 and truncates like chat", async () => {
  fakeMeta.seen = null;
  await withServer(fakeMeta, async (base) => {
    const history = Array.from({ length: 8 }, (_, i) => ({
      q: `q${i} ${"x".repeat(600)}`,
      a: `a${i} ${"y".repeat(1200)}`,
    }));
    history.push({ q: 42, a: null }, "junk");
    const res = await post(base, "/api/quiz", { topic: "t", history });
    assert.equal(res.status, 200);
    const seen = fakeMeta.seen.history;
    assert.equal(seen.length, 6);
    assert.ok(seen[0].q.startsWith("q2 "));
    assert.ok(seen.every((h) => h.q.length <= 500 && h.a.length <= 1000));
  });
});

test("quiz needs a topic", async () => {
  await withServer(fakeMeta, async (base) => {
    for (const body of [{}, { topic: "   " }, { history: [] }]) {
      const res = await post(base, "/api/quiz", body);
      assert.equal(res.status, 400);
      assert.match((await res.json()).error, /topic/);
    }
  });
});

test("without a key the quiz says so plainly", async () => {
  await withServer(null, async (base) => {
    const res = await post(base, "/api/quiz", { topic: "t" });
    assert.equal(res.status, 503);
    assert.match((await res.json()).error, /MODEL_API_KEY/);
  });
});

test("a failing model is a clear error, never an empty quiz", async () => {
  const broken = { ...fakeMeta, quiz: async () => { throw new Error("secret-internal-detail"); } };
  const quiet = console.error;
  console.error = () => {};
  try {
    await withServer(broken, async (base) => {
      const res = await post(base, "/api/quiz", { topic: "t" });
      assert.equal(res.status, 502);
      const body = await res.json();
      assert.match(body.error, /Try again/);
      assert.doesNotMatch(JSON.stringify(body), /secret-internal-detail/);
      assert.equal(body.questions, undefined);
    });
  } finally {
    console.error = quiet;
  }
});

test("anything short of 5 valid questions is an error, never a half-empty quiz", () => {
  const good = [1, 2, 3, 4, 5].map((i) => ({
    prompt: `Q${i}?`,
    options: ["a", "b", "c"],
    correct: 1,
    explanation: `Because ${i}.`,
  }));
  assert.equal(quizPayload("t", { questions: good }).questions.length, 5);
  assert.throws(() => quizPayload("t", { questions: good.slice(0, 4) }), /full quiz/);
  assert.throws(() => quizPayload("t", {}), /full quiz/);
  assert.throws(
    () =>
      quizPayload("t", {
        questions: good.map((q, i) => (i === 0 ? { ...q, options: ["only", "two"] } : q)),
      }),
    /full quiz/,
  );
  assert.throws(
    () =>
      quizPayload("t", {
        questions: good.map((q, i) => (i === 0 ? { ...q, correct: 9 } : q)),
      }),
    /full quiz/,
  );
  assert.throws(
    () =>
      quizPayload("t", {
        questions: good.map((q, i) => (i === 0 ? { ...q, explanation: " " } : q)),
      }),
    /full quiz/,
  );
});

test("quiz is rate limited", async () => {
  await withServer(fakeMeta, async (base) => {
    for (let i = 0; i < 6; i++) {
      assert.equal((await post(base, "/api/quiz", { topic: "t" })).status, 200);
    }
    const limited = await post(base, "/api/quiz", { topic: "t" });
    assert.equal(limited.status, 429);
    assert.match((await limited.json()).error, /Too many requests/);
  });
});
