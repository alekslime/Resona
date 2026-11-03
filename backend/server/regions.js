// Turns Muse Spark's boxes into compact "regions" the phone can hit-test with a finger.
// Each part gets one region: Spark's tight box, filled as a solid 0/1 grid mask.
// Boxes and the hand-drawn sample outlines share one protocol, so the phone treats them alike.

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

function boxIoU(a, b) {
  const l = Math.max(a[0], b[0]), t = Math.max(a[1], b[1]);
  const r = Math.min(a[2], b[2]), bot = Math.min(a[3], b[3]);
  if (r <= l || bot <= t) return 0;
  const inter = (r - l) * (bot - t);
  const union = (a[2] - a[0]) * (a[3] - a[1]) + (b[2] - b[0]) * (b[3] - b[1]) - inter;
  return union > 0 ? inter / union : 0;
}

/** Drop near-identical regions (two labels boxing the very same part). First one wins. */
export function dedupeRegions(regions, threshold = 0.6) {
  const kept = [];
  for (const r of regions) {
    if (!kept.some((k) => boxIoU(k.box, r.box) >= threshold)) kept.push(r);
  }
  return kept;
}

/**
 * One touchable region from Spark's box ([left, top, right, bottom] as fractions
 * of the picture). Empty when Spark gave no usable box: the part lands in
 * `skipped` instead of becoming a silently missing part.
 */
export function buildRegions({ part, partIndex, imgW, imgH, maskSide = 96 }) {
  if (!part.where) return [];
  const [l, t, r, b] = part.where;
  const left = Math.max(0, Math.round(l * imgW)), top = Math.max(0, Math.round(t * imgH));
  const right = Math.min(imgW, Math.round(r * imgW)), bottom = Math.min(imgH, Math.round(b * imgH));
  if (right <= left || bottom <= top) return [];
  const full = new Uint8Array((right - left) * (bottom - top)).fill(1);
  const small = downsample(full, right - left, bottom - top, maskSide);
  return [
    {
      id: `${slug(part.label)}-1`,
      order: partIndex,
      label: part.label,
      spoken: part.spoken,
      detail: part.detail,
      box: [left, top, right, bottom], // source pixels, right/bottom exclusive
      mask: { w: small.w, h: small.h, b64: Buffer.from(small.bits).toString("base64") },
      area: (right - left) * (bottom - top),
      confidence: null,
      approximate: true,
    },
  ];
}
