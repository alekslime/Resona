import test from "node:test";
import assert from "node:assert/strict";
import { prepareRegions, hitRegion, nearestRegion, directionWords, hapticMs } from "../public/hit.js";

const b64 = (bits) => Buffer.from(Uint8Array.from(bits)).toString("base64");
// 4x4 box at (100,100)-(200,200); an L shape: left column and bottom row are on.
const L = [1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 1, 1, 1];
const big = { id: "big", order: 0, label: "big", box: [100, 100, 200, 200], mask: { w: 4, h: 4, b64: b64(L) }, area: 700 };
const small = { id: "small", order: 1, label: "small", box: [100, 100, 150, 150], mask: { w: 1, h: 1, b64: b64([1]) }, area: 100 };

test("hit-testing follows the mask, not just the box", () => {
  const regions = prepareRegions([big], 400, 400);
  assert.equal(hitRegion(regions, 110, 110)?.id, "big"); // left column
  assert.equal(hitRegion(regions, 190, 110), null); // inside the box, but a hole in the L
  assert.equal(hitRegion(regions, 190, 190)?.id, "big"); // bottom row
  assert.equal(hitRegion(regions, 50, 50), null);
});

test("where regions overlap, the smaller one wins", () => {
  const regions = prepareRegions([big, small], 400, 400);
  assert.equal(hitRegion(regions, 110, 110)?.id, "small");
});

test("tolerance lets a fingertip find a thin region", () => {
  const regions = prepareRegions([big], 400, 400);
  assert.equal(hitRegion(regions, 130, 110), null); // just right of the left column
  assert.equal(hitRegion(regions, 130, 110, 8)?.id, "big");
});

test("nearest region and spoken direction", () => {
  const regions = prepareRegions([big], 400, 400);
  const near = nearestRegion(regions, 300, 150);
  assert.equal(near.region.id, "big");
  assert.equal(near.words, "to the left");
  assert.equal(directionWords(0, -50), "up");
  assert.equal(directionWords(50, 50), "down and to the right");
});

test("bigger parts buzz longer, within sane bounds", () => {
  const a = hapticMs({ areaFrac: 0.01 });
  const b = hapticMs({ areaFrac: 0.5 });
  assert.ok(a < b);
  assert.ok(a >= 25 && b <= 95);
});
