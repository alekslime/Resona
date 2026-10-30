import test from "node:test";
import assert from "node:assert/strict";
import { buildRegions, downsample } from "../server/regions.js";
import { prepareRegions, hitRegion } from "../public/hit.js";
import { DOCS_LINE, parseLine } from "./helpers.js";

const part = { label: "button", spoken: "A button.", detail: "A round button." };

test("SAM docs sample becomes two regions, numbered left to right", async () => {
  const result = await parseLine(DOCS_LINE);
  assert.equal(result.outcome.status, "completed");
  const regions = buildRegions({ part, partIndex: 0, records: result.records, imgW: 320, imgH: 334 });
  assert.equal(regions.length, 2);
  assert.deepEqual(regions.map((r) => r.label), ["button, 1 of 2", "button, 2 of 2"]);
  assert.deepEqual(regions[0].box, [155, 228, 203, 255]); // the left button; right/bottom are exclusive
  assert.deepEqual(regions[1].box, [211, 228, 271, 255]);
});

test("a finger on a decoded mask hits it, and misses outside it", async () => {
  const result = await parseLine(DOCS_LINE);
  const regions = prepareRegions(buildRegions({ part, partIndex: 0, records: result.records, imgW: 320, imgH: 334 }), 320, 334);
  assert.equal(hitRegion(regions, 240, 241)?.label, "button, 2 of 2");
  assert.equal(hitRegion(regions, 178, 241)?.label, "button, 1 of 2");
  assert.equal(hitRegion(regions, 10, 10), null);
});

test("zero matches is a normal result, not an error", async () => {
  const result = await parseLine("");
  assert.equal(result.records.length, 0);
  assert.deepEqual(buildRegions({ part, partIndex: 0, records: result.records, imgW: 320, imgH: 334 }), []);
});

test("specks below the minimum area are dropped", async () => {
  const result = await parseLine(DOCS_LINE);
  const regions = buildRegions({ part, partIndex: 0, records: result.records, imgW: 320, imgH: 334, minAreaFrac: 0.5 });
  assert.equal(regions.length, 0);
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

test("a stream with no output text at all counts as zero matches", async () => {
  // createMeta.segment() swallows the parser's lane error for this case; check the parser really raises it.
  const { parseImageStream } = await import("@meta-sam/parser");
  async function* empty() { yield { type: "response.completed" }; }
  await assert.rejects(parseImageStream(empty()).finalResult, (e) => e.code === "response_lane");
});
