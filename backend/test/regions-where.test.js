import test from "node:test";
import assert from "node:assert/strict";
import { insideWhere } from "../server/regions.js";

const W = 1000, H = 2000;
const where = [0.2, 0.2, 0.4, 0.3];
const box = (left, top, right, bottom) => ({ left, top, right, bottom });

test("no box means no filter", () => {
  assert.equal(insideWhere(box(0, 0, 10, 10), null, W, H), true);
  assert.equal(insideWhere(box(0, 0, 10, 10), undefined, W, H), true);
});
test("a match centred inside the box is kept", () => {
  assert.equal(insideWhere(box(250, 450, 350, 550), where, W, H), true);
});
test("below the box there is more slack than above it", () => {
  assert.equal(insideWhere(box(250, 700, 350, 740), where, W, H), true);
  assert.equal(insideWhere(box(250, 780, 350, 820), where, W, H), false);
  assert.equal(insideWhere(box(250, 360, 350, 400), where, W, H), true);
  assert.equal(insideWhere(box(250, 300, 350, 340), where, W, H), false);
});
test("sideways slack is 0.05 of the picture width", () => {
  assert.equal(insideWhere(box(410, 450, 450, 550), where, W, H), true);
  assert.equal(insideWhere(box(460, 450, 500, 550), where, W, H), false);
  assert.equal(insideWhere(box(150, 450, 190, 550), where, W, H), true);
  assert.equal(insideWhere(box(100, 450, 140, 550), where, W, H), false);
});
test("a match far from the box is dropped", () => {
  assert.equal(insideWhere(box(100, 1900, 200, 1990), where, W, H), false);
});