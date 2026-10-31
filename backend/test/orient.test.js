import test from "node:test";
import assert from "node:assert/strict";
import { orientedSize } from "../server/orient.js";

test("upright pictures keep their size", () => {
  assert.deepEqual(orientedSize({ width: 1280, height: 960 }), { width: 1280, height: 960 });
  assert.deepEqual(orientedSize({ width: 1280, height: 960, orientation: 1 }), { width: 1280, height: 960 });
});

test("orientations 5 to 8 swap width and height", () => {
  for (const orientation of [5, 6, 7, 8]) {
    assert.deepEqual(orientedSize({ width: 1280, height: 960, orientation }), { width: 960, height: 1280 });
  }
});

test("orientations 2 to 4 only mirror or flip, so the size stays", () => {
  for (const orientation of [2, 3, 4]) {
    assert.deepEqual(orientedSize({ width: 1280, height: 960, orientation }), { width: 1280, height: 960 });
  }
});