import 'package:flutter/material.dart';

/// One complete colour theme. Every screen is drawn from these colours, exactly as in Resonant's
/// Kotlin ThemePalette: [ink] is text and icons, [onInk] is what sits on an ink fill, [bar] is the
/// top pill, [button] the buttons, and the outlines exist only in the high-contrast themes.
/// The palettes below carry Resonant's twelve themes over with their colours unchanged
/// (the last eight were added when the gallery was completed for this build).
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

  static const handsfree = ResonantPalette(
    id: 'handsfree',
    label: 'Handsfree, screen reader',
    background: Color(0xFF000000),
    card: Color(0xFF000000),
    ink: Color(0xFFFFFFFF),
    onInk: Color(0xFF000000),
    dim: Color(0xFFC9C9C9),
    bar: Color(0xFF000000),
    onBar: Color(0xFFFFFFFF),
    button: Color(0xFFFFFFFF),
    onButton: Color(0xFF000000),
    signal: Color(0xFFFFFFFF),
    outline: Color(0xFFFFFFFF),
    outlineWidth: 3,
    cardRadius: 8,
    controlRadius: 8,
  );

  static const photophobia = ResonantPalette(
    id: 'photophobia',
    label: 'Photophobia, low glare',
    background: Color(0xFF211812),
    card: Color(0xFF2E211A),
    ink: Color(0xFFF0DFC2),
    onInk: Color(0xFF211812),
    dim: Color(0xFFC4AB8A),
    bar: Color(0xFF171008),
    onBar: Color(0xFFF0DFC2),
    button: Color(0xFFF0DFC2),
    onButton: Color(0xFF211812),
    signal: Color(0xFFE8A33D),
    cardRadius: 36,
  );

  static const warm = ResonantPalette(
    id: 'warm',
    label: 'Warm ambiance',
    background: Color(0xFF2E1B10),
    card: Color(0xFF402613),
    ink: Color(0xFFFFD9A3),
    onInk: Color(0xFF2E1B10),
    dim: Color(0xFFD8B285),
    bar: Color(0xFF1C0F06),
    onBar: Color(0xFFFFD9A3),
    button: Color(0xFFFFB35C),
    onButton: Color(0xFF2E1B10),
    signal: Color(0xFFFF9E45),
    cardRadius: 24,
  );

  static const nightRed = ResonantPalette(
    id: 'night_red',
    label: 'Night red',
    background: Color(0xFF000000),
    card: Color(0xFF160505),
    ink: Color(0xFFFF7A6E),
    onInk: Color(0xFF000000),
    dim: Color(0xFFD84A41),
    bar: Color(0xFF000000),
    onBar: Color(0xFFFF7A6E),
    button: Color(0xFFFF7A6E),
    onButton: Color(0xFF000000),
    signal: Color(0xFFFF7A6E),
    outline: Color(0xFF7A1F1A),
    outlineWidth: 2,
  );

  static const blueOnYellow = ResonantPalette(
    id: 'blue_on_yellow',
    label: 'Blue on yellow',
    background: Color(0xFFFFD500),
    card: Color(0xFFFFE14D),
    ink: Color(0xFF002FA7),
    onInk: Color(0xFFFFD500),
    dim: Color(0xFF3D5AA8),
    bar: Color(0xFF002FA7),
    onBar: Color(0xFFFFFFFF),
    button: Color(0xFF002FA7),
    onButton: Color(0xFFFFFFFF),
    signal: Color(0xFF002FA7),
  );

  static const softCream = ResonantPalette(
    id: 'soft_cream',
    label: 'Soft cream',
    background: Color(0xFFFFF4E0),
    card: Color(0xFFFFFFFF),
    ink: Color(0xFF3E2723),
    onInk: Color(0xFFFFF4E0),
    dim: Color(0xFF6D4C41),
    bar: Color(0xFF3E2723),
    onBar: Color(0xFFFFF4E0),
    button: Color(0xFF6D3B2A),
    onButton: Color(0xFFFFF4E0),
    signal: Color(0xFFB3541E),
  );

  static const paperGray = ResonantPalette(
    id: 'paper_gray',
    label: 'Paper gray',
    background: Color(0xFFECECEC),
    card: Color(0xFFFFFFFF),
    ink: Color(0xFF16181D),
    onInk: Color(0xFFFFFFFF),
    dim: Color(0xFF4A4A4A),
    bar: Color(0xFF16181D),
    onBar: Color(0xFFFFFFFF),
    button: Color(0xFF16181D),
    onButton: Color(0xFFFFFFFF),
    signal: Color(0xFF005FCC),
    outline: Color(0xFF6E6E6E),
    outlineWidth: 2,
    cardRadius: 16,
    controlRadius: 24,
  );

  static const whiteOnBlue = ResonantPalette(
    id: 'white_on_blue',
    label: 'White on blue',
    background: Color(0xFF0B3D91),
    card: Color(0xFF0E4CA8),
    ink: Color(0xFFFFFFFF),
    onInk: Color(0xFF0B3D91),
    dim: Color(0xFFC7D8F5),
    bar: Color(0xFF06275F),
    onBar: Color(0xFFFFFFFF),
    button: Color(0xFFFFFFFF),
    onButton: Color(0xFF0B3D91),
    signal: Color(0xFFFFD500),
  );

  static const all = [
    standard,
    lowVision,
    cataracts,
    handsfree,
    monochrome,
    photophobia,
    warm,
    nightRed,
    blueOnYellow,
    softCream,
    paperGray,
    whiteOnBlue,
  ];
}
