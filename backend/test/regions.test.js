import test from "node:test";
import assert from "node:assert/strict";
import { buildRegions, dedupeRegions, downsample } from "../server/regions.js";

const part = { label: "Red bar", spoken: "A red bar.", detail: "A tall red bar.", where: [0.25, 0.25, 0.75, 0.75] };

test("a Spark box becomes one touchable approximate region", () => {
  const regions = buildRegions({ part, partIndex: 0, imgW: 800, imgH: 600 });
  assert.equal(regions.length, 1);
  const [r] = regions;
  assert.equal(r.id, "red-bar-1");
  assert.equal(r.order, 0);
  assert.equal(r.label, "Red bar");
  assert.equal(r.spoken, "A red bar.");
  assert.deepEqual(r.box, [200, 150, 600, 450]);
  assert.equal(r.area, 400 * 300);
  assert.equal(r.confidence, null);
  assert.equal(r.approximate, true);
});

test("the mask is a solid filled grid inside the box", () => {
  const [r] = buildRegions({ part, partIndex: 0, imgW: 800, imgH: 600 });
  const bits = Buffer.from(r.mask.b64, "base64");
  assert.equal(bits.length, r.mask.w * r.mask.h);
  assert.ok(bits.every((b) => b === 1));
  assert.ok(Math.max(r.mask.w, r.mask.h) <= 96);
});

test("no box means no region, and degenerate boxes are dropped", () => {
  assert.deepEqual(buildRegions({ part: { ...part, where: undefined }, partIndex: 0, imgW: 800, imgH: 600 }), []);
  assert.deepEqual(buildRegions({ part: { ...part, where: [0.5, 0.5, 0.5, 0.5] }, partIndex: 0, imgW: 800, imgH: 600 }), []);
});

test("downsample keeps shape and caps the size", () => {
  const w = 200, h = 100;
  const raster = new Uint8Array(w * h).fill(0);
  for (let y = 0; y < h; y++) for (let x = 0; x < 100; x++) raster[y * w + x] = 1; // left half on
  const small = downsample(raster, w, h, 50);
  assert.deepEqual([small.w, small.h], [50, 25]);
  assert.equal(small.bits[0], 1);
  assert.equal(small.bits[49], 0);
});

test("dedupe drops near-identical boxes and keeps distinct parts", () => {
  const regions = [
    { label: "a", box: [0, 0, 100, 100] },
    { label: "b", box: [10, 10, 110, 110] }, // same part, second label
    { label: "c", box: [200, 200, 260, 260] },
  ];
  assert.deepEqual(dedupeRegions(regions).map((r) => r.label), ["a", "c"]);
});
