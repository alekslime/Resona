import 'dart:math' as math;

import 'region.dart';

/// Live guide measurements against the part's outline.
///
/// Thin parts (an artery, a river) have box centres that sit off the part, so
/// guiding to the centre points the finger at empty space. Instead the session
/// precomputes each region's [boundaryPoints] once per picture and each move
/// scans only those points for the nearest one. Pure Dart, no model calls.

/// Cap per region so a busy mask cannot slow down per-move code.
const int maxBoundaryPoints = 400;

/// Centres (picture pixels) of the mask cells on the part's edge: an on-cell
/// touching an off-cell or the mask border. Sampled down to [maxPoints].
List<(double, double)> boundaryPoints(Region r, {int maxPoints = maxBoundaryPoints}) {
  final pts = <(double, double)>[];
  bool on(int u, int v) => r.bits[v * r.maskW + u] == 1;
  for (var v = 0; v < r.maskH; v++) {
    for (var u = 0; u < r.maskW; u++) {
      if (!on(u, v)) continue;
      final edge =
          u == 0 ||
          v == 0 ||
          u == r.maskW - 1 ||
          v == r.maskH - 1 ||
          !on(u - 1, v) ||
          !on(u + 1, v) ||
          !on(u, v - 1) ||
          !on(u, v + 1);
      if (!edge) continue;
      pts.add((
        r.left + (u + 0.5) / r.maskW * (r.right - r.left),
        r.top + (v + 0.5) / r.maskH * (r.bottom - r.top),
      ));
    }
  }
  if (pts.isEmpty) return [(r.centerX, r.centerY)];
  if (pts.length <= maxPoints) return pts;
  final step = pts.length / maxPoints;
  return [for (var i = 0; i < maxPoints; i++) pts[(i * step).floor()]];
}

/// Precompute every region's boundary once per picture (see [boundaryPoints]).
Map<String, List<(double, double)>> buildGuideCache(List<Region> regions) => {
  for (final r in regions) r.id: boundaryPoints(r),
};

/// The nearest cached boundary point to ([x], [y]): (nx, ny, distance).
(double, double, double) nearestGuidePoint(List<(double, double)> pts, double x, double y) {
  var bestX = pts.first.$1;
  var bestY = pts.first.$2;
  var best2 = double.infinity;
  for (final p in pts) {
    final dx = p.$1 - x;
    final dy = p.$2 - y;
    final d2 = dx * dx + dy * dy;
    if (d2 < best2) {
      best2 = d2;
      bestX = p.$1;
      bestY = p.$2;
    }
  }
  return (bestX, bestY, math.sqrt(best2));
}

/// Compass angle 0..360 for a move (0 = right, 90 = up; screen coordinates).
double guideAngle(double dx, double dy) {
  final angle = math.atan2(-dy, dx) * 180 / math.pi;
  return (angle % 360 + 360) % 360;
}

/// Sixteen short direction sectors for live cues (screen coordinates).
int guideSector(double dx, double dy) => guideSectorForAngle(guideAngle(dx, dy));

int guideSectorForAngle(double n) => (((n + 11.25) % 360) / 22.5).floor();

const double _sectorWidth = 22.5;

/// [guideSector] with hysteresis: within [marginDeg] of the boundary shared
/// with [lastSector], the finger is still on its way, so hold the old sector
/// instead of flip-flopping speech. Decisive jumps switch immediately.
int guideSectorStable(double dx, double dy, int? lastSector, {double marginDeg = 3}) {
  final sector = guideSector(dx, dy);
  if (lastSector == null) return sector;
  final last = lastSector % 16;
  if (sector == last) return sector;
  final forward = (sector - last) % 16 == 1;
  final back = (last - sector) % 16 == 1;
  if (!forward && !back) return sector;
  final boundary = (last * _sectorWidth + (forward ? 11.25 : -11.25)) % 360;
  final n = guideAngle(dx, dy);
  var d = (n - boundary).abs() % 360;
  if (d > 180) d = 360 - d;
  return d < marginDeg ? last : sector;
}

const _sectorWords = [
  'right', // 0
  'right and a little up',
  'up and right',
  'up and a little right',
  'up', // 4
  'up and a little left',
  'up and left',
  'left and a little up',
  'left', // 8
  'left and a little down',
  'down and left',
  'down and a little left',
  'down', // 12
  'down and a little right',
  'down and right',
  'right and a little down',
];

String guideSectorWords(int sector) => _sectorWords[sector % 16];

/// Distance buckets using the same fractions as [distanceWords]'s
/// very-close/close/far bands: 0 = almost there, 1 = close, 2 = far.
int guideBucket(double dist, double pictureWidth) {
  final f = dist / pictureWidth;
  return f < 0.12 ? 0 : (f < 0.3 ? 1 : 2);
}

/// The short live cue: "almost there" when very close, else the direction.
String guideCue(int sector, int bucket) => bucket == 0 ? 'almost there' : guideSectorWords(sector);

/// 0 (far) to 1 (on the part) for the proximity tone.
double guideCloseness(double dist, double pictureWidth) =>
    (1 - dist / (pictureWidth * 0.5)).clamp(0.0, 1.0);
