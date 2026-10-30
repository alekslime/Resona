// Turns SAM 3.1 records into compact "regions" the browser can hit-test with a finger.
import { decodeMaskToRaster, recordsOfKind } from "@meta-sam/parser";

/** Nearest-neighbour shrink of a 0/1 raster so it fits in maxSide x maxSide. */
export function downsample(raster, w, h, maxSide = 96) {
  const scale = Math.min(1, maxSide / Math.max(w, h));
  const nw = Math.max(1, Math.round(w * scale));
  const nh = Math.max(1, Math.round(h * scale));
  if (nw === w && nh === h) return { w, h, bits: Uint8Array.from(raster) };
  const bits = new Uint8Array(nw * nh);
  for (let y = 0; y < nh; y++) {
    const sy = Math.min(h - 1, Math.floor(((y + 0.5) * h) / nh));
    for (let x = 0; x < nw; x++) {
      const sx = Math.min(w - 1, Math.floor(((x + 0.5) * w) / nw));
      bits[y * nw + x] = raster[sy * w + sx];
    }
  }
  return { w: nw, h: nh, bits };
}

function slug(text) {
  return text.toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-|-$/g, "") || "part";
}

/**
 * @param part      { label, spoken, detail } from Muse Spark
 * @param records   parsed SAM records for that label (see @meta-sam/parser)
 * @param imgW,imgH size of the image that was sent to SAM
 */
export function buildRegions({ part, partIndex, records, imgW, imgH, maxInstances = 3, minAreaFrac = 0.0004, maskSide = 96 }) {
  const found = [];
  for (const rec of recordsOfKind(records, "mask")) {
    const raster = decodeMaskToRaster(rec.mask);
    let area = 0;
    for (let i = 0; i < raster.length; i++) area += raster[i];
    if (area / (imgW * imgH) < minAreaFrac) continue; // specks are noise, not parts
    found.push({ rec, raster, area });
  }
  // Most confident (or largest) first, keep a few, then number them left to right.
  found.sort((a, b) => (b.rec.confidence ?? 0) - (a.rec.confidence ?? 0) || b.area - a.area);
  const kept = found.slice(0, maxInstances).sort((a, b) => a.rec.bounds.left - b.rec.bounds.left);

  return kept.map(({ rec, raster, area }, i) => {
    const small = downsample(raster, rec.mask.width, rec.mask.height, maskSide);
    const { left, top, right, bottom } = rec.bounds;
    const label = kept.length > 1 ? `${part.label}, ${i + 1} of ${kept.length}` : part.label;
    return {
      id: `${slug(part.label)}-${i + 1}`,
      order: partIndex,
      label,
      spoken: part.spoken,
      detail: part.detail,
      box: [left, top, right, bottom], // source pixels, right/bottom exclusive
      mask: { w: small.w, h: small.h, b64: Buffer.from(small.bits).toString("base64") },
      area,
      confidence: rec.confidence ?? null,
    };
  });
}
