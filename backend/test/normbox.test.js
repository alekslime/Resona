import test from "node:test";
import assert from "node:assert/strict";
import { normBox } from "../server/meta.js";

test("a valid box passes through", () => {
  assert.deepEqual(normBox([0.1, 0.2, 0.5, 0.6]), [0.1, 0.2, 0.5, 0.6]);
  assert.deepEqual(normBox(["0.1", "0.2", "0.5", "0.6"]), [0.1, 0.2, 0.5, 0.6]);
  assert.deepEqual(normBox([0, 0, 1, 1]), [0, 0, 1, 1]);
});
test("anything that is not a sane box is dropped", () => {
  assert.equal(normBox(undefined), null);
  assert.equal(normBox([0, 0, 1]), null);
  assert.equal(normBox([0, 0, 1, 2]), null);
  assert.equal(normBox(["a", 0, 1, 1]), null);
  assert.equal(normBox([0.5, 0.5, 0.4, 0.9]), null);
});