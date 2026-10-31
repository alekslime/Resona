import test from "node:test";
import assert from "node:assert/strict";
import { buildRegions, conceptVariants, dedupeRegions, downsample } from "../server/regions.js";
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

test("masks reach the app as base64 0/1 grids that follow the box", async () => {
  const result = await parseLine(DOCS_LINE);
  const [left] = buildRegions({ part, partIndex: 0, records: result.records, imgW: 320, imgH: 334 });
  const bits = Buffer.from(left.mask.b64, "base64");
  assert.equal(bits.length, left.mask.w * left.mask.h);
  assert.ok(bits.every((b) => b === 0 || b === 1));
  // The docs sample masks are almost fully filled: the centre cell must be on.
  const centre = bits[Math.floor(left.mask.h / 2) * left.mask.w + Math.floor(left.mask.w / 2)];
  assert.equal(centre, 1);
  assert.ok(left.area > 1000);
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

test("many small matches in one photo merge into a single region", async () => {
  const result = await parseLine(DOCS_LINE);
  const masks = result.records.filter((r) => r.kind === "mask");
  // Five tooth-sized matches spread across one clinical photo.
  const records = Array.from({ length: 5 }, (_, i) => ({
    ...masks[i % masks.length],
    bounds: { left: 10 + i * 50, top: 10, right: 40 + i * 50, bottom: 40 },
    confidence: 0.9,
  }));
  const regions = buildRegions({
    part: { ...part, label: "decayed teeth", where: [0, 0, 1, 1] },
    partIndex: 0,
    records,
    imgW: 320,
    imgH: 334,
  });
  assert.equal(regions.length, 1);
  assert.equal(regions[0].label, "decayed teeth"); // one study part, not "1 of 5"
  assert.equal(regions[0].merged, 5);
  assert.deepEqual(regions[0].box, [10, 10, 240, 40]);
  assert.equal(regions[0].approximate, false);
});

test("no SAM match but a Spark box still gives a touchable approximate region", () => {
  const regions = buildRegions({
    part: { ...part, where: [0.25, 0.25, 0.75, 0.75] },
    partIndex: 0,
    records: [],
    imgW: 800,
    imgH: 600,
  });
  assert.equal(regions.length, 1);
  assert.equal(regions[0].approximate, true);
  assert.equal(regions[0].confidence, null);
  assert.deepEqual(regions[0].box, [200, 150, 600, 450]);
});

test("concept variants simplify labels SAM cannot ground", () => {
  assert.deepEqual(conceptVariants("orthodontic braces row"), [
    "orthodontic braces row",
    "orthodontic braces",
    "orthodontic",
    "braces",
  ]);
  assert.deepEqual(conceptVariants("gumline teeth pair"), [
    "gumline teeth pair",
    "gumline teeth",
    "gumline",
    "teeth",
  ]);
  assert.deepEqual(conceptVariants("button"), ["button"]);
});

test("dedupe drops near-identical boxes and keeps distinct parts", () => {
  const regions = [
    { label: "a", box: [0, 0, 100, 100] },
    { label: "b", box: [10, 10, 110, 110] }, // same teeth, second label
    { label: "c", box: [200, 200, 260, 260] },
  ];
  assert.deepEqual(dedupeRegions(regions).map((r) => r.label), ["a", "c"]);
});

test("a stream with no output text at all counts as zero matches", async () => {
  // createMeta.segment() swallows the parser's lane error for this case; check the parser really raises it.
  const { parseImageStream } = await import("@meta-sam/parser");
  async function* empty() { yield { type: "response.completed" }; }
  await assert.rejects(parseImageStream(empty()).finalResult, (e) => e.code === "response_lane");
});
