import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import '../domain/region.dart';

/// Where a [w] x [h] picture sits when fitted ("contain") inside [box], and its scale.
({Rect rect, double scale}) fitPicture(Size box, int w, int h) {
  final scale = (box.width / w) < (box.height / h) ? box.width / w : box.height / h;
  final size = Size(w * scale, h * scale);
  return (
    rect: Rect.fromLTWH(
      (box.width - size.width) / 2,
      (box.height - size.height) / 2,
      size.width,
      size.height,
    ),
    scale: scale,
  );
}

/// The outline of a region as one path in picture pixels: a rectangle for every run of "on" cells.
Path regionPath(Region r) {
  final path = Path();
  final cw = (r.right - r.left) / r.maskW;
  final ch = (r.bottom - r.top) / r.maskH;
  for (var v = 0; v < r.maskH; v++) {
    var u = 0;
    while (u < r.maskW) {
      if (r.bits[v * r.maskW + u] != 1) {
        u++;
        continue;
      }
      final start = u;
      while (u < r.maskW && r.bits[v * r.maskW + u] == 1) {
        u++;
      }
      path.addRect(
        Rect.fromLTRB(
          r.left + start * cw,
          r.top + v * ch,
          r.left + u * cw,
          r.top + (v + 1) * ch + 0.5,
        ),
      );
    }
  }
  return path;
}

class PicturePainter extends CustomPainter {
  PicturePainter({
    required this.image,
    required this.width,
    required this.height,
    this.highlight,
    this.highlightPath,
    required this.tint,
  });

  final ui.Image image;
  final int width, height;
  final Region? highlight;
  final Path? highlightPath;
  final Color tint;

  @override
  void paint(Canvas canvas, Size size) {
    final fit = fitPicture(size, width, height);
    paintImage(
      canvas: canvas,
      rect: fit.rect,
      image: image,
      fit: BoxFit.fill,
      filterQuality: FilterQuality.medium,
    );
    final path = highlightPath;
    if (highlight == null || path == null) return;
    canvas
      ..save()
      ..translate(fit.rect.left, fit.rect.top)
      ..scale(fit.scale);
    final s = fit.scale;
    // Two-tone halo (dark, then white) so the outline reads on any picture, then a tint inside.
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 14 / s
        ..strokeJoin = StrokeJoin.round
        ..color = const Color(0xFF0A0A0A),
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8 / s
        ..strokeJoin = StrokeJoin.round
        ..color = const Color(0xFFFFFFFF),
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.fill
        ..color = tint.withValues(alpha: 0.5),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(PicturePainter old) =>
      old.highlight?.id != highlight?.id || old.image != image || old.tint != tint;
}
