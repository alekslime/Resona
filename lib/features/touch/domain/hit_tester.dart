import 'dart:math' as math;

import 'region.dart';

/// The region under picture pixel ([x], [y]). Where regions overlap the smallest one wins.
/// [tolerance] (picture pixels) lets a fingertip find a thin part such as an axis line.
Region? hitRegion(List<Region> regions, double x, double y, {double tolerance = 0}) {
  final probes = <(double, double)>[(0, 0)];
  if (tolerance > 0) {
    for (var k = 0; k < 8; k++) {
      final a = k * math.pi / 4;
      probes.add((math.cos(a) * tolerance, math.sin(a) * tolerance));
    }
  }
  for (final (dx, dy) in probes) {
    Region? best;
    for (final r in regions) {
      if (r.contains(x + dx, y + dy) && (best == null || r.area < best.area)) best = r;
    }
    if (best != null) return best;
  }
  return null;
}

class Nearest {
  Nearest(this.region, this.distance, this.words);
  final Region region;
  final double distance;
  final String words;
}

/// The closest region to a point that is not on any region, with the way to walk to it.
Nearest? nearestRegion(List<Region> regions, double x, double y) {
  Nearest? best;
  for (final r in regions) {
    final cx = x.clamp(r.left.toDouble(), r.right.toDouble());
    final cy = y.clamp(r.top.toDouble(), r.bottom.toDouble());
    final dist = math.sqrt(math.pow(cx - x, 2) + math.pow(cy - y, 2));
    if (best == null || dist < best.distance) {
      best = Nearest(r, dist, directionWords(r.centerX - x, r.centerY - y));
    }
  }
  return best;
}

/// Spoken direction for a move of ([dx], [dy]) in screen coordinates (y grows downward).
String directionWords(double dx, double dy) {
  final angle = math.atan2(-dy, dx) * 180 / math.pi; // 0 = right, 90 = up
  const sectors = [
    'to the right',
    'up and to the right',
    'up',
    'up and to the left',
    'to the left',
    'down and to the left',
    'down',
    'down and to the right',
  ];
  return sectors[(((angle + 360) % 360) / 45).round() % 8];
}

/// Vibration length in ms: bigger parts buzz longer, so size can be felt.
int hapticMsFor(Region r) => (25 + 70 * math.sqrt(math.min(1.0, r.areaFrac))).round();

List<Region> readingOrder(List<Region> regions) =>
    [...regions]
      ..sort((a, b) => a.order != b.order ? a.order.compareTo(b.order) : a.left.compareTo(b.left));
