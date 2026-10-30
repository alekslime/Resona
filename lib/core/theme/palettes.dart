import 'package:flutter/material.dart';

/// One complete colour theme. Every screen is drawn from these colours, exactly as in Resonant's
/// Kotlin ThemePalette: [ink] is text and icons, [onInk] is what sits on an ink fill, [bar] is the
/// top pill, [button] the buttons, and the outlines exist only in the high-contrast themes.
/// The four palettes below are carried over from Resonant with their colours unchanged.
class ResonantPalette {
  const ResonantPalette({
    required this.id,
    required this.label,
    required this.background,
    required this.card,
    required this.ink,
    required this.onInk,
    required this.dim,
    required this.bar,
    required this.onBar,
    required this.button,
    required this.onButton,
    required this.signal,
    this.outline,
    this.outlineWidth = 0,
    this.cardRadius = 28,
    this.controlRadius = 50,
  });

  final String id, label;
  final Color background, card, ink, onInk, dim, bar, onBar, button, onButton;

  /// Tint for the outlined part of a picture. New for the hackathon build.
  final Color signal;
  final Color? outline;
  final double outlineWidth;
  final double cardRadius, controlRadius;
}

abstract final class Palettes {
  static const standard = ResonantPalette(
    id: 'default',
    label: 'Resonant native',
    background: Color(0xFFFFAE00),
    card: Color(0xFFFFFFFF),
    ink: Color(0xFF0A0A0A),
    onInk: Color(0xFFFFFFFF),
    dim: Color(0xFFFFFFFF),
    bar: Color(0xFF0A0A0A),
    onBar: Color(0xFFFFFFFF),
    button: Color(0xFF0A0A0A),
    onButton: Color(0xFFFFFFFF),
    signal: Color(0xFFFF5A1F),
  );

  static const lowVision = ResonantPalette(
    id: 'low_vision',
    label: 'Low vision, enormous contrast',
    background: Color(0xFF090A0C),
    card: Color(0xFF191714),
    ink: Color(0xFFFFE100),
    onInk: Color(0xFF090A0C),
    dim: Color(0xFFD4BE00),
    bar: Color(0xFF191714),
    onBar: Color(0xFFFFFFFF),
    button: Color(0xFF000000),
    onButton: Color(0xFFFFFFFF),
    signal: Color(0xFFFFE100),
    outline: Color(0xFFFFE100),
    outlineWidth: 3,
    cardRadius: 12,
    controlRadius: 14,
  );

  static const cataracts = ResonantPalette(
    id: 'cataracts',
    label: 'Cataracts, high clarity',
    background: Color(0xFF22252C),
    card: Color(0xFF22211D),
    ink: Color(0xFFF8F7F6),
    onInk: Color(0xFF22211D),
    dim: Color(0xFFC5C8CF),
    bar: Color(0xFF484745),
    onBar: Color(0xFFFFFFFF),
    button: Color(0xFF16140E),
    onButton: Color(0xFFFFFFFF),
    signal: Color(0xFF6FB8F0),
    outline: Color(0xFFFFE100),
    outlineWidth: 4,
    cardRadius: 20,
    controlRadius: 20,
  );

  static const monochrome = ResonantPalette(
    id: 'monochrome',
    label: 'Monochrome, colorblind',
    background: Color(0xFFFFFFFF),
    card: Color(0xFFE5E5E5),
    ink: Color(0xFF000000),
    onInk: Color(0xFFFFFFFF),
    dim: Color(0xFF4D4D4D),
    bar: Color(0xFF000000),
    onBar: Color(0xFFFFFFFF),
    button: Color(0xFF000000),
    onButton: Color(0xFFFFFFFF),
    signal: Color(0xFF000000),
    outline: Color(0xFF000000),
    outlineWidth: 2,
    cardRadius: 4,
    controlRadius: 4,
  );

  static const all = [standard, lowVision, cataracts, monochrome];
}
