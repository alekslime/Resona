/// A cap on the settings text size, ported from Resonant's CappedTextScale.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';

/// Keeps the text inside from growing past [max] times normal, for the few
/// places whose words are already huge and would break their layout (the
/// Home menu, a score). Only the settings size is capped — the phone's own
/// text size still applies in full — and shrinking is never capped.
class CappedText extends ConsumerWidget {
  const CappedText({super.key, required this.max, required this.child});

  final double max;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final setting = ref.watch(textScaleProvider);
    if (setting <= max) return child;
    final media = MediaQuery.of(context);
    final phone = media.textScaler.scale(1.0) / setting;
    return MediaQuery(
      data: media.copyWith(textScaler: TextScaler.linear(phone * max)),
      child: child,
    );
  }
}
