/// The shared button and text field, ported from Resonant's ResonantControls.
///
/// (Fonts hardcode Metropolis for now; the chosen font arrives with Settings.)
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import '../theme/motion.dart';
import '../theme/resonant_theme.dart';
import '../theme/shapes.dart';
import 'press.dart';

/// The pill button from the Figma "Continue lesson" card: the theme's button
/// fill with its text, or (for the less important choice on a screen) a card
/// fill with ink text. Used by every screen that has real buttons.
class ResonantButton extends ConsumerWidget {
  const ResonantButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.filled = true,
    this.enabled = true,
  });

  final String text;
  final VoidCallback onPressed;
  final bool filled;
  final bool enabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(paletteProvider);
    final font = ref.watch(fontProvider);
    final shape = controlShape(palette);
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: PressScale(
        themeFloor: MotionProfiles.forTheme(palette.id).minDamping,
        child: ClipRRect(
          borderRadius: shape,
          child: Container(
            width: double.infinity,
            constraints: const BoxConstraints(minHeight: minTouchTarget),
            decoration: BoxDecoration(
              color: filled ? palette.button : palette.card,
              border: filled
                  ? controlBorder(palette)
                  : cardBorder(palette),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: enabled ? onPressed : null,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 14,
                  ),
                  child: Text(
                    text,
                    style: TextStyle(
                      fontFamily: font.family,
                      fontWeight: FontWeight.w600,
                      fontSize: 22,
                      color: filled ? palette.onButton : palette.ink,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A text field drawn as one of the cards used everywhere else: a small label
/// on top, the typed text big and heavy underneath. The label is also the
/// spoken description.
class ResonantTextField extends ConsumerStatefulWidget {
  const ResonantTextField({
    super.key,
    required this.value,
    required this.onChanged,
    required this.label,
    this.placeholder,
    this.keyboardType = TextInputType.text,
    this.onSubmitted,
    this.autoFocus = false,
  });

  final String value;
  final ValueChanged<String> onChanged;
  final String label;
  final String? placeholder;
  final TextInputType keyboardType;
  final ValueChanged<String>? onSubmitted;

  /// Focus the field and open the keyboard as soon as it appears, so nobody
  /// has to find it by touch.
  final bool autoFocus;

  @override
  ConsumerState<ResonantTextField> createState() =>
      _ResonantTextFieldState();
}

class _ResonantTextFieldState extends ConsumerState<ResonantTextField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant ResonantTextField old) {
    super.didUpdateWidget(old);
    if (widget.value != _controller.text) {
      _controller.value = TextEditingValue(
        text: widget.value,
        selection: TextSelection.collapsed(offset: widget.value.length),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = ref.watch(paletteProvider);
    final font = ref.watch(fontProvider);
    final valueStyle = TextStyle(
      fontFamily: font.family,
      fontWeight: FontWeight.w600,
      fontSize: 26,
      color: palette.ink,
    );
    return ClipRRect(
      borderRadius: cardShape(palette),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: palette.card,
          border: cardBorder(palette),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.label,
              style: TextStyle(
                fontFamily: font.family,
                fontWeight: FontWeight.w600,
                fontSize: 16,
                color: palette.ink,
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Semantics(
                label: widget.label,
                textField: true,
                child: TextField(
                  controller: _controller,
                  onChanged: widget.onChanged,
                  onSubmitted: widget.onSubmitted,
                  autofocus: widget.autoFocus,
                  keyboardType: widget.keyboardType,
                  style: valueStyle,
                  cursorColor: palette.ink,
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                    hintText: widget.placeholder,
                    hintMaxLines: 1,
                    hintStyle: valueStyle.copyWith(
                      color: palette.ink.withValues(alpha: 0.6),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
