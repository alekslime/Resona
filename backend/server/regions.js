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

/**
 * True when the centre of a SAM match lies inside the rough box Muse Spark gave for the part
 * ([left, top, right, bottom] as fractions of the picture), plus some slack. No box means no filter.
 * Spark's boxes drift a little low on tall pages, so there is more slack below than above.
 */
export function insideWhere(bounds, where, imgW, imgH, slack = {}) {
  if (!where) return true;
  const { x = 0.05, top = 0.03, bottom = 0.08 } = slack;
  const [l, t, r, b] = where;
  const cx = (bounds.left + bounds.right) / 2 / imgW;
  const cy = (bounds.top + bounds.bottom) / 2 / imgH;
  return cx >= l - x && cx <= r + x && cy >= t - top && cy <= b + bottom;
}
function slug(text) {
  return text.toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-|-$/g, "") || "part";
}

const TRAILING_NOISE = /\s+(row|rows|pair|group|set|photo|photograph|image|picture|view|close[-\s]?up)$/i;

/**
 * Simpler SAM concepts to try when the full label matches nothing.
 * "orthodontic braces row" -> ["orthodontic braces row", "orthodontic braces", "braces", "orthodontic"]
 */
export function conceptVariants(label) {
  const out = [];
  const add = (s) => {
    const v = String(s ?? "").trim().toLowerCase();
    if (v && !out.includes(v)) out.push(v);
  };
  add(label);
  let s = String(label ?? "").trim();
  while (TRAILING_NOISE.test(s)) {
    s = s.replace(TRAILING_NOISE, "").trim();
    add(s);
  }
  const words = s.split(/\s+/).filter(Boolean);
  if (words.length >= 2) add(words.slice(-2).join(" "));
  if (words.length >= 2) add(words[0]);
  if (words.length >= 1) add(words[words.length - 1]);
  return out.slice(0, 5);
}

function boxIoU(a, b) {
  const l = Math.max(a[0], b[0]), t = Math.max(a[1], b[1]);
  const r = Math.min(a[2], b[2]), bot = Math.min(a[3], b[3]);
  if (r <= l || bot <= t) return 0;
  const inter = (r - l) * (bot - t);
  const union = (a[2] - a[0]) * (a[3] - a[1]) + (b[2] - b[0]) * (b[3] - b[1]) - inter;
  return union > 0 ? inter / union : 0;
}

/** Drop near-identical regions (two labels segmenting the very same teeth). First one wins. */
export function dedupeRegions(regions, threshold = 0.6) {
  const kept = [];
  for (const r of regions) {
    if (!kept.some((k) => boxIoU(k.box, r.box) >= threshold)) kept.push(r);
  }
  return kept;
}

/** One region whose mask is the union of many small matches (e.g. every tooth in one photo). */
function mergedRegion({ part, partIndex, found, imgW, imgH, maskSide }) {
  const left = Math.min(...found.map((f) => f.rec.bounds.left));
  const top = Math.min(...found.map((f) => f.rec.bounds.top));
  const right = Math.max(...found.map((f) => f.rec.bounds.right));
  const bottom = Math.max(...found.map((f) => f.rec.bounds.bottom));
  const scale = Math.min(1, maskSide / Math.max(right - left, bottom - top));
  const gw = Math.max(1, Math.round((right - left) * scale));
  const gh = Math.max(1, Math.round((bottom - top) * scale));
  const bits = new Uint8Array(gw * gh);
  for (let y = 0; y < gh; y++) {
    const py = top + ((y + 0.5) * (bottom - top)) / gh;
    for (let x = 0; x < gw; x++) {
      const px = left + ((x + 0.5) * (right - left)) / gw;
      for (const { rec, raster } of found) {
        const b = rec.bounds;
        if (px < b.left || px >= b.right || py < b.top || py >= b.bottom) continue;
        const u = Math.min(rec.mask.width - 1, Math.floor(((px - b.left) / (b.right - b.left)) * rec.mask.width));
        const v = Math.min(rec.mask.height - 1, Math.floor(((py - b.top) / (b.bottom - b.top)) * rec.mask.height));
        if (raster[v * rec.mask.width + u] === 1) {
          bits[y * gw + x] = 1;
          break;
        }
      }
    }
  }
  return {
    id: `${slug(part.label)}-1`,
    order: partIndex,
    label: part.label,
    spoken: part.spoken,
    detail: part.detail,
    box: [left, top, right, bottom],
    mask: { w: gw, h: gh, b64: Buffer.from(bits).toString("base64") },
    area: found.reduce((sum, f) => sum + f.area, 0),
    confidence: Math.max(...found.map((f) => f.rec.confidence ?? 0)) || null,
    approximate: false,
    merged: found.length,
  };
}

/** Spark's rough box as a rectangle region: better a touchable photo panel than a missing part. */
function boxRegion({ part, partIndex, imgW, imgH, maskSide }) {
  const [l, t, r, b] = part.where;
  const left = Math.max(0, Math.round(l * imgW)), top = Math.max(0, Math.round(t * imgH));
  const right = Math.min(imgW, Math.round(r * imgW)), bottom = Math.min(imgH, Math.round(b * imgH));
  if (right <= left || bottom <= top) return null;
  const full = new Uint8Array((right - left) * (bottom - top)).fill(1);
  const small = downsample(full, right - left, bottom - top, maskSide);
  return {
    id: `${slug(part.label)}-1`,
    order: partIndex,
    label: part.label,
    spoken: part.spoken,
    detail: part.detail,
    box: [left, top, right, bottom],
    mask: { w: small.w, h: small.h, b64: Buffer.from(small.bits).toString("base64") },
    area: (right - left) * (bottom - top),
    confidence: null,
    approximate: true,
  };
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
    if (!insideWhere(rec.bounds, part.where, imgW, imgH)) continue; // not where Spark put this part
    found.push({ rec, raster, area });
  }
  if (!found.length) {
    // SAM could not ground this part. If Spark told us where it is, the student
    // still gets a touchable (rectangular) panel instead of a silently missing part.
    const fallback = part.where ? boxRegion({ part, partIndex, imgW, imgH, maskSide }) : null;
    return fallback ? [fallback] : [];
  }
  // Many small matches inside one photo (every tooth in a clinical close-up) are
  // one study part, not twelve fingertip specks: merge them into a single region.
  const areas = found.map((f) => f.area / (imgW * imgH)).sort((a, b) => a - b);
  const medianFrac = areas[Math.floor(areas.length / 2)];
  if (found.length >= 4 && medianFrac < 0.02) {
    return [mergedRegion({ part, partIndex, found: found.slice(0, 16), imgW, imgH, maskSide })];
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
      approximate: false,
    };
  });
}
