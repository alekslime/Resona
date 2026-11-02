/// Every non-home screen, ported from Resonant's ResonantScaffold.
///
/// Same flat background as the menu, so a screen change reads as the content
/// moving rather than the app repainting. The header uses the same type
/// scale as the rest of the app rather than its own bespoke sizes, and the
/// same solid text color as everything else — no separate faded caption tone.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import 'resonant_surface.dart';
import 'top_bar.dart';

class ResonantScaffold extends ConsumerWidget {
  const ResonantScaffold({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onBack,
    this.backAnnouncement = 'Back.',
    this.header,
    this.bottomBar,
    required this.child,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onBack;
  final String backAnnouncement;
  final Widget? header;
  final Widget? bottomBar;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(paletteProvider);
    final textTheme = Theme.of(context).textTheme;
    return ResonantSurface(
      child: SafeArea(
        child: Column(
          children: [
            if (header != null)
              header!
            else if (onBack != null) ...[
              // Same back pill as Lessons and Quizzes. No settings circle:
              // these screens are Settings or sit inside it, so a gear here
              // would only lead back to itself.
              LessonsTopBar(
                onBack: onBack!,
                title: title,
                backAnnouncement: backAnnouncement,
                showSettings: false,
              ),
              if (subtitle != null)
                Padding(
                  padding:
                      const EdgeInsets.fromLTRB(20, 0, 20, 16),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      subtitle!,
                      style: TextStyle(
                        fontFamily: 'Metropolis',
                        fontWeight: FontWeight.w600,
                        fontSize: 20,
                        color: palette.ink,
                      ),
                    ),
                  ),
                ),
            ] else
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Semantics(
                            header: true,
                            child: Text(
                              title,
                              style: textTheme.headlineMedium?.copyWith(
                                fontSize: 30,
                                height: 34 / 30,
                                fontWeight: FontWeight.w900,
                                color: palette.ink,
                              ),
                            ),
                          ),
                          if (subtitle != null)
                            Text(
                              subtitle!,
                              style: textTheme.bodyMedium?.copyWith(
                                fontSize: 15,
                                height: 18 / 15,
                                fontWeight: FontWeight.w600,
                                color: palette.ink,
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (trailing != null) trailing!,
                  ],
                ),
              ),
            Expanded(child: child),
            if (bottomBar != null) bottomBar!,
          ],
        ),
      ),
    );
  }
}
