import 'dart:math' as math;

import 'region.dart';

String _across(double centerX, double width) {
  final f = centerX / width;
  return f < 0.4 ? 'on the left' : (f > 0.6 ? 'on the right' : 'in the centre');
}

/// The whole picture as a spoken map, in three horizontal bands.
/// "Top: cloud on the left, sun on the right. Middle: mountain in the centre. Bottom: sea."
/// Deterministic and free: it is computed from the region boxes, never the model.
String mapInWords(List<Region> regions, double width, double height) {
  if (regions.isEmpty) return '';
  const bandNames = ['Top', 'Middle', 'Bottom'];
  final bands = <int, List<Region>>{};
  for (final r in regions) {
    final band = (r.centerY / height * 3).floor().clamp(0, 2);
    (bands[band] ??= []).add(r);
  }
  final parts = <String>[];
  for (var b = 0; b < 3; b++) {
    final rs = bands[b];
    if (rs == null || rs.isEmpty) continue;
    rs.sort((a, c) => a.centerX.compareTo(c.centerX));
    parts.add('${bandNames[b]}: ${rs.map((r) => '${r.label} ${_across(r.centerX, width)}').join(', ')}.');
  }
  return parts.join(' ');
}

/// What sits around [r]: the nearest part in each direction, by dominant axis.
/// " Around it: cloud to the left, mountain below." Empty when there is nothing around.
String aroundWords(Region r, List<Region> regions) {
  final best = <String, (Region, double)>{};
  for (final o in regions) {
    if (o.id == r.id) continue;
    final dx = o.centerX - r.centerX;
    final dy = o.centerY - r.centerY;
    if (dx == 0 && dy == 0) continue;
    final dir = dx.abs() > dy.abs() ? (dx < 0 ? 'to the left' : 'to the right') : (dy < 0 ? 'above' : 'below');
    final dist = math.sqrt(dx * dx + dy * dy);
    if (best[dir] == null || dist < best[dir]!.$2) best[dir] = (o, dist);
  }
  if (best.isEmpty) return '';
  const order = ['above', 'to the left', 'to the right', 'below'];
  final named = [
    for (final d in order)
      if (best[d] != null) '${best[d]!.$1.label} $d',
  ];
  return ' Around it: ${named.join(', ')}.';
}

/// How far a point is from a region, in words a student can act on.
String distanceWords(double dist, double pictureWidth) {
  final f = dist / pictureWidth;
  return f < 0.12 ? 'very close' : (f < 0.3 ? 'close' : 'far');
}
