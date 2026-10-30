// Pure helpers shared by the browser and the tests: no DOM, no network.

export function decodeMaskB64(b64) {
  const bin = atob(b64);
  const out = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) out[i] = bin.charCodeAt(i);
  return out;
}

/** Decode every mask once and remember how much of the picture each region covers. */
export function prepareRegions(regions, width, height) {
  return regions.map((r) => ({ ...r, bits: decodeMaskB64(r.mask.b64), areaFrac: r.area / (width * height) }));
}

function maskAt(r, x, y) {
  const [l, t, rt, b] = r.box;
  if (x < l || x >= rt || y < t || y >= b) return false;
  const u = Math.min(r.mask.w - 1, Math.floor(((x - l) / (rt - l)) * r.mask.w));
  const v = Math.min(r.mask.h - 1, Math.floor(((y - t) / (b - t)) * r.mask.h));
  return r.bits[v * r.mask.w + u] === 1;
}

/** The region under (x, y) in picture pixels. Where regions overlap the smallest one wins. */
export function hitRegion(regions, x, y, tolerance = 0) {
  const probes = [[0, 0]];
  if (tolerance > 0) {
    for (let k = 0; k < 8; k++) {
      const a = (k * Math.PI) / 4;
      probes.push([Math.cos(a) * tolerance, Math.sin(a) * tolerance]);
    }
  }
  for (const [dx, dy] of probes) {
    let best = null;
    for (const r of regions) {
      if (maskAt(r, x + dx, y + dy) && (!best || r.area < best.area)) best = r;
    }
    if (best) return best;
  }
  return null;
}

/** Closest region to a point that is not on any region, with the direction to walk. */
export function nearestRegion(regions, x, y) {
  let best = null;
  for (const r of regions) {
    const [l, t, rt, b] = r.box;
    const cx = Math.min(Math.max(x, l), rt);
    const cy = Math.min(Math.max(y, t), b);
    const dist = Math.hypot(cx - x, cy - y);
    if (!best || dist < best.distance) {
      best = { region: r, distance: dist, dx: (l + rt) / 2 - x, dy: (t + b) / 2 - y };
    }
  }
  return best && { ...best, words: directionWords(best.dx, best.dy) };
}

export function directionWords(dx, dy) {
  const angle = (Math.atan2(-dy, dx) * 180) / Math.PI; // 0 = right, 90 = up
  const sectors = ["to the right", "up and to the right", "up", "up and to the left", "to the left", "down and to the left", "down", "down and to the right"];
  return sectors[Math.round(((angle + 360) % 360) / 45) % 8];
}

/** Vibration length in ms: bigger parts buzz longer, so size can be felt. */
export function hapticMs(region) {
  return Math.round(25 + 70 * Math.sqrt(Math.min(1, region.areaFrac ?? 0.1)));
}

export function readingOrder(regions) {
  return [...regions].sort((a, b) => a.order - b.order || a.box[0] - b.box[0]);
}
