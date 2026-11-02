/// The Figma icons, ported from Resonant's vector drawables and Icons.kt.
///
/// Coordinates are transcribed 1:1 from res/drawable (ic_back, ic_settings,
/// ic_mic, ic_arrow_up/down); [tint] recolors them, so one asset serves
/// every background. Decorative: the buttons that hold them carry their
/// own spoken labels.
library;

import 'package:flutter/material.dart';

/// Figma back arrow; mirrored for the forward arrow.
class ArrowIcon extends StatelessWidget {
  const ArrowIcon({
    super.key,
    required this.pointRight,
    required this.tint,
    this.size = 22,
  });

  final bool pointRight;
  final Color tint;
  final double size;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
        child: SizedBox.square(
          dimension: size,
          child: CustomPaint(
            painter: _VectorPainter(
              path: _backPath(),
              viewport: 16,
              tint: tint,
              flip: pointRight,
            ),
          ),
        ),
      );
}

class SettingsIcon extends StatelessWidget {
  const SettingsIcon({super.key, required this.tint, this.size = 24});

  final Color tint;
  final double size;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
        child: SizedBox.square(
          dimension: size,
          child: CustomPaint(
            painter: _VectorPainter(
              path: _settingsPath(),
              viewport: 24,
              tint: tint,
            ),
          ),
        ),
      );
}

class MicIcon extends StatelessWidget {
  const MicIcon({super.key, required this.tint, this.size = 26});

  final Color tint;
  final double size;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
        child: SizedBox.square(
          dimension: size,
          child: CustomPaint(
            painter: _VectorPainter(
              path: _micPath(),
              viewport: 29,
              tint: tint,
              strokeWidth: 3.5,
            ),
          ),
        ),
      );
}

/// Big arrow from the Figma quiz frame.
class VerticalArrow extends StatelessWidget {
  const VerticalArrow({
    super.key,
    required this.up,
    required this.tint,
    this.size = 114,
  });

  final bool up;
  final Color tint;
  final double size;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
        child: SizedBox.square(
          dimension: size,
          child: CustomPaint(
            painter: _VectorPainter(
              path: up ? _arrowUpPath() : _arrowDownPath(),
              viewport: 117,
              tint: tint,
            ),
          ),
        ),
      );
}

class _VectorPainter extends CustomPainter {
  _VectorPainter({
    required this.path,
    required this.viewport,
    required this.tint,
    this.flip = false,
    this.strokeWidth = 0,
  });

  final Path path;
  final double viewport;
  final Color tint;
  final bool flip;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / viewport);
    if (flip) {
      canvas.translate(viewport, 0);
      canvas.scale(-1, 1);
    }
    final paint = Paint()..color = tint;
    if (strokeWidth > 0) {
      paint.style = PaintingStyle.stroke;
      paint.strokeWidth = strokeWidth;
      paint.strokeCap = StrokeCap.round;
      paint.strokeJoin = StrokeJoin.round;
    }
    canvas.drawPath(path, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_VectorPainter old) =>
      old.viewport != viewport ||
      old.tint != tint ||
      old.flip != flip ||
      old.strokeWidth != strokeWidth;
}

Path _backPath() => Path()
  ..moveTo(3.825, 9)
  ..lineTo(9.425, 14.6)
  ..lineTo(8, 16)
  ..lineTo(0, 8)
  ..lineTo(8, 0)
  ..lineTo(9.425, 1.4)
  ..lineTo(3.825, 7)
  ..lineTo(16, 7)
  ..lineTo(16, 9)
  ..lineTo(3.825, 9)
  ..close();

Path _settingsPath() => Path()
  ..fillType = PathFillType.evenOdd
  ..moveTo(9.25001, 22)
  ..lineTo(8.85001, 18.8)
  ..cubicTo(8.63335, 18.7167, 8.42918, 18.6167, 8.23751, 18.5)
  ..cubicTo(8.04585, 18.3833, 7.85835, 18.2583, 7.67501, 18.125)
  ..lineTo(4.70001, 19.375)
  ..lineTo(1.95001, 14.625)
  ..lineTo(4.52501, 12.675)
  ..cubicTo(4.50835, 12.5583, 4.50001, 12.4458, 4.50001, 12.3375)
  ..lineTo(4.50001, 11.6625)
  ..cubicTo(4.50001, 11.5542, 4.50835, 11.4417, 4.52501, 11.325)
  ..lineTo(1.95001, 9.375)
  ..lineTo(4.70001, 4.625)
  ..lineTo(7.67501, 5.875)
  ..cubicTo(7.85835, 5.74167, 8.05001, 5.61667, 8.25001, 5.5)
  ..cubicTo(8.45001, 5.38333, 8.65001, 5.28333, 8.85001, 5.2)
  ..lineTo(9.25001, 2)
  ..lineTo(14.75, 2)
  ..lineTo(15.15, 5.2)
  ..cubicTo(15.3667, 5.28333, 15.5708, 5.38333, 15.7625, 5.5)
  ..cubicTo(15.9542, 5.61667, 16.1417, 5.74167, 16.325, 5.875)
  ..lineTo(19.3, 4.625)
  ..lineTo(22.05, 9.375)
  ..lineTo(19.475, 11.325)
  ..cubicTo(19.4917, 11.4417, 19.5, 11.5542, 19.5, 11.6625)
  ..lineTo(19.5, 12.3375)
  ..cubicTo(19.5, 12.4458, 19.4833, 12.5583, 19.45, 12.675)
  ..lineTo(22.025, 14.625)
  ..lineTo(19.275, 19.375)
  ..lineTo(16.325, 18.125)
  ..cubicTo(16.1417, 18.2583, 15.95, 18.3833, 15.75, 18.5)
  ..cubicTo(15.55, 18.6167, 15.35, 18.7167, 15.15, 18.8)
  ..lineTo(14.75, 22)
  ..lineTo(9.25001, 22)
  ..close()
  ..moveTo(12.05, 15.5)
  ..cubicTo(13.0167, 15.5, 13.8417, 15.1583, 14.525, 14.475)
  ..cubicTo(15.2083, 13.7917, 15.55, 12.9667, 15.55, 12)
  ..cubicTo(15.55, 11.0333, 15.2083, 10.2083, 14.525, 9.525)
  ..cubicTo(13.8417, 8.84167, 13.0167, 8.5, 12.05, 8.5)
  ..cubicTo(11.0667, 8.5, 10.2375, 8.84167, 9.56251, 9.525)
  ..cubicTo(8.88751, 10.2083, 8.55001, 11.0333, 8.55001, 12)
  ..cubicTo(8.55001, 12.9667, 8.88751, 13.7917, 9.56251, 14.475)
  ..cubicTo(10.2375, 15.1583, 11.0667, 15.5, 12.05, 15.5)
  ..close();

Path _micPath() => Path()
  ..moveTo(5.96649, 11.933)
  ..lineTo(5.96649, 14.3195)
  ..cubicTo(5.96649, 16.5349, 6.84654, 18.6595, 8.41305, 20.2261)
  ..cubicTo(9.97955, 21.7926, 12.1042, 22.6726, 14.3196, 22.6726)
  ..cubicTo(16.5349, 22.6726, 18.6596, 21.7926, 20.2261, 20.2261)
  ..cubicTo(21.7926, 18.6595, 22.6726, 16.5349, 22.6726, 14.3195)
  ..lineTo(22.6726, 11.933)
  ..moveTo(14.3196, 22.6726)
  ..lineTo(14.3196, 27.4458)
  ..moveTo(9.54638, 27.4458)
  ..lineTo(19.0927, 27.4458)
  ..moveTo(14.3196, 1.1933)
  ..cubicTo(13.3701, 1.1933, 12.4596, 1.57046, 11.7882, 2.24182)
  ..cubicTo(11.1168, 2.91318, 10.7397, 3.82374, 10.7397, 4.77318)
  ..lineTo(10.7397, 14.3195)
  ..cubicTo(10.7397, 15.269, 11.1168, 16.1795, 11.7882, 16.8509)
  ..cubicTo(12.4596, 17.5223, 13.3701, 17.8994, 14.3196, 17.8994)
  ..cubicTo(15.269, 17.8994, 16.1796, 17.5223, 16.8509, 16.8509)
  ..cubicTo(17.5223, 16.1795, 17.8994, 15.269, 17.8994, 14.3195)
  ..lineTo(17.8994, 4.77318)
  ..cubicTo(17.8994, 3.82374, 17.5223, 2.91318, 16.8509, 2.24182)
  ..cubicTo(16.1796, 1.57046, 15.269, 1.1933, 14.3196, 1.1933)
  ..close();

Path _arrowUpPath() => Path()
  ..moveTo(53.625, 38.1469)
  ..lineTo(26.325, 65.4469)
  ..lineTo(19.5, 58.5)
  ..lineTo(58.5, 19.5)
  ..lineTo(97.5, 58.5)
  ..lineTo(90.675, 65.4469)
  ..lineTo(63.375, 38.1469)
  ..lineTo(63.375, 97.5)
  ..lineTo(53.625, 97.5)
  ..lineTo(53.625, 38.1469)
  ..close();

Path _arrowDownPath() => Path()
  ..moveTo(63.375, 78.8531)
  ..lineTo(90.675, 51.5531)
  ..lineTo(97.5, 58.5)
  ..lineTo(58.5, 97.5)
  ..lineTo(19.5, 58.5)
  ..lineTo(26.325, 51.5531)
  ..lineTo(53.625, 78.8531)
  ..lineTo(53.625, 19.5)
  ..lineTo(63.375, 19.5)
  ..lineTo(63.375, 78.8531)
  ..close();
