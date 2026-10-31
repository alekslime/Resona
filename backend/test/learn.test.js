import test from "node:test";
import assert from "node:assert/strict";
import { cleanRegions, fallbackLesson, fallbackQuiz, parseGrade, parseLesson, parseQuiz } from "../server/learn.js";

const regions = cleanRegions([
  { id: "sun-1", label: "sun", spoken: "The sun.", detail: "The sun heats the sea." },
  { id: "sea-1", label: "sea", spoken: "The sea.", detail: "The sea holds water." },
  { id: "", label: "ghost", spoken: "x", detail: "x" },
  "junk",
]);

test("cleanRegions drops junk and caps the list", () => {
  assert.equal(regions.length, 2);
  assert.equal(regions[0].label, "sun");
});

test("fallback lesson visits every part in order", () => {
  const lesson = fallbackLesson({ title: "T", overview: "O.", regions });
  assert.equal(lesson.steps.length, regions.length + 2);
  assert.equal(lesson.steps[1].regionId, "sun-1");
  assert.match(lesson.steps.at(-1).say, /whole picture/);
});

test("fallback quiz is find-it first, spoken recall last", () => {
  const quiz = fallbackQuiz({ regions });
  assert.equal(quiz.questions[0].kind, "find");
  assert.equal(quiz.questions.at(-1).kind, "say");
  assert.ok(quiz.questions.every((q) => regions.some((r) => r.id === q.regionId)));
});

test("parseLesson keeps known region ids and drops unknown ones", () => {
  const lesson = parseLesson(
    JSON.stringify({ steps: [{ regionId: "sun-1", say: "The sun heats the sea and starts everything." }, { regionId: "nope", say: "A made up part that is not real." }] }),
    regions,
  );
  assert.equal(lesson.steps[0].regionId, "sun-1");
  assert.equal(lesson.steps[1].regionId, null);
});

test("parseQuiz rejects questions about parts that do not exist", () => {
  assert.throws(() =>
    parseQuiz(JSON.stringify({ questions: [{ kind: "find", regionId: "nope", question: "Find the nothing at all?" }] }), regions),
  );
  const quiz = parseQuiz(
    JSON.stringify({ questions: [{ kind: "say", regionId: "sea-1", question: "What does the sea hold in it?", expected: "water" }] }),
    regions,
  );
  assert.equal(quiz.questions[0].expected, "water");
});

test("parseGrade defaults the spoken line", () => {
  assert.deepEqual(parseGrade('{"correct": true}'), { correct: true, say: "Correct." });
  assert.equal(parseGrade('{"correct": false, "say": "Not quite. It holds water."}').correct, false);
});
