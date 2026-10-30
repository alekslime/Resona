import test from "node:test";
import assert from "node:assert/strict";
import { extractJson } from "../server/json.js";

test("plain JSON", () => assert.deepEqual(extractJson('{"a":1}'), { a: 1 }));
test("fenced JSON with chatter", () => {
  assert.deepEqual(extractJson('Sure! Here you go:\n```json\n{"parts":[{"label":"sun"}]}\n```\nAnything else?'), { parts: [{ label: "sun" }] });
});
test("no JSON throws a plain error", () => assert.throws(() => extractJson("no braces here"), /did not return JSON/));
