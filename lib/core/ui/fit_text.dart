/// Shrinking text, ported from Resonant's FitText.kt.
///
/// Text that shrinks until it fits the height it is given (put it in a
/// bounded, e.g. weighted, slot). For content that must stay fully on
/// screen at any system font size. It only ever shrinks from [style], and
/// stops at [minSize]; text that still overflows there is clipped.
library;

import 'package:flutter/material.dart';

class FitText extends StatefulWidget {
  const FitText(
    this.text, {
    super.key,
    required this.style,
    required this.color,
    this.minSize = 16,
  });

  final String text;
  final TextStyle style;
  final Color color;
  final double minSize;

  @override
  State<FitText> createState() => _FitTextState();
}

class _FitTextState extends State<FitText> {
  double? _size;

  @override
  void didUpdateWidget(covariant FitText old) {
    super.didUpdateWidget(old);
    if (widget.text != old.text || widget.style != old.style) _size = null;
  }

  @override
  Widget build(BuildContext context) {
    final base = widget.style.fontSize ?? 14;
    final size = _size ?? base;
    final style = widget.style.copyWith(fontSize: size, color: widget.color);
    return LayoutBuilder(
      builder: (context, constraints) {
        // Flutter's height is already a factor of the font size, so unlike
        // the old absolute line heights it needs no rescaling as we shrink.
        if (constraints.maxHeight.isFinite) {
          final painter = TextPainter(
            text: TextSpan(text: widget.text, style: style),
            textDirection: Directionality.of(context),
          )..layout(maxWidth: constraints.maxWidth);
          final overflow = painter.height > constraints.maxHeight;
          painter.dispose();
          if (overflow && size > widget.minSize) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) setState(() => _size = size * 0.9);
            });
          }
        }
        return Text(widget.text, style: style);
      },
    );
  }
}
