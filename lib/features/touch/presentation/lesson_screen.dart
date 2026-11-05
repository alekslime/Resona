import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/nav/resonant_nav.dart';
import '../../../core/providers.dart';
import '../../../core/theme/shapes.dart';
import '../../../core/theme/text_scale.dart';
import '../../../core/ui/enter.dart';
import '../../../core/ui/system_bars.dart';
import '../../../core/ui/top_bar.dart';
import '../../learn/domain/library.dart';
import '../application/lesson_session.dart';
import '../gestures/gesture_phrases.dart';
import 'gesture_guide.dart';
import 'gesture_surface.dart';
import 'settings_screen.dart';

/// One lesson being read, ported from Resonant's LessonScreen: the title
/// card, the current section fading in over the old one, and the finished
/// card rising at the end. Auto plays on its own; manual taps per
/// sentence; sideways swipes jump sections.
class LessonScreen extends ConsumerStatefulWidget {
  const LessonScreen({
    super.key,
    required this.lesson,
    required this.autoAdvance,
  });

  final LibraryLesson lesson;
  final bool autoAdvance;

  @override
  ConsumerState<LessonScreen> createState() => _LessonScreenState();
}

class _LessonScreenState extends ConsumerState<LessonScreen> {
  late final LessonSession _session;
  final _scroll = ScrollController();
  bool _scrolledEnd = false;

  @override
  void initState() {
    super.initState();
    _session = LessonSession(
      lesson: widget.lesson,
      speech: ref.read(speechProvider),
      haptics: ref.read(hapticsProvider),
      cues: ref.read(cuesProvider),
      autoAdvance: widget.autoAdvance,
      onLessonFinished: (id) {
        ref.read(activityProvider.notifier).lessonFinished(id);
      },
      onExit: () {
        if (mounted) Navigator.of(context).pop();
      },
      onChanged: (_) {
        if (mounted) setState(() {});
      },
      textScalePercent: () =>
          TextScale.percent(ref.read(textScaleProvider)),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _session.open();
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    _session.dispose();
    super.dispose();
  }

  void _openSettings(BuildContext context) {
    Navigator.of(context).push(resonantRoute(
      const SettingsScreen(),
      reduce: MediaQuery.of(context).disableAnimations,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final palette = ref.watch(paletteProvider);
    final font = ref.watch(fontProvider);
    final spacing = ref.watch(textSpacingProvider);
    final view = _session.view;
    final reduce = MediaQuery.of(context).disableAnimations;
    if (view.finished && !_scrolledEnd) {
      _scrolledEnd = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_scroll.hasClients) return;
        if (reduce) {
          _scroll.jumpTo(_scroll.position.maxScrollExtent);
        } else {
          unawaited(_scroll.animateTo(
            _scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 450),
            curve: Curves.fastOutSlowIn,
          ));
        }
      });
    }
    paintSystemBars(palette.background);
    return Container(
      color: palette.background,
      child: SafeArea(
        child: Column(
          children: [
            LessonsTopBar(
              backAnnouncement: 'Back to Lessons.',
              onBack: () => Navigator.of(context).pop(),
              onSettings: () => _openSettings(context),
            ),
            const FirstVisitGuide(screen: GuideScreen.lessonReader),
            Expanded(
              child: GestureSurface(
                twoFingerSwipe: true,
                onGesture: _session.handle,
                child: SingleChildScrollView(
                  controller: _scroll,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: palette.card,
                          borderRadius: cardShape(palette),
                          border: cardBorder(palette),
                        ),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 18),
                        child: FittedTitle(
                          widget.lesson.title,
                          maxSp: 50,
                          lineRatio: 1.2,
                          color: palette.ink,
                        ),
                      ),
                      AnimatedSwitcher(
                        duration: reduce
                            ? Duration.zero
                            : const Duration(milliseconds: 150),
                        child: _Section(
                          // Keyed on the section, not its text: the fade
                          // follows section jumps, not sentences.
                          key: ValueKey(view.sectionIndex),
                          lesson: widget.lesson,
                          sectionIndex: view.sectionIndex,
                          fontFamily: font.family,
                          ink: palette.ink,
                          button: palette.button,
                          onButton: palette.onButton,
                          lineHeightScale: spacing.lineHeightScale,
                          letterSpacingEm: spacing.letterSpacingEm,
                          textScale: ref.read(textScaleProvider),
                        ),
                      ),
                      if (view.finished) ...[
                        const SizedBox(height: 8),
                        EnterStagger(
                          index: 0,
                          child: Container(
                            decoration: BoxDecoration(
                              color: palette.card,
                              borderRadius: cardShape(palette),
                              border: cardBorder(palette),
                            ),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 24),
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  'Lesson finished',
                                  style: TextStyle(
                                    fontFamily: font.family,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 32,
                                    height: 40 / 32 *
                                        spacing.lineHeightScale,
                                    letterSpacing:
                                        spacing.letterSpacingEm * 32,
                                    color: palette.ink,
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Text(
                                    GesturePhrases.longPressRightEdgeBack,
                                    style: TextStyle(
                                      fontFamily: font.family,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 20,
                                      height: 28 / 20 *
                                          spacing.lineHeightScale,
                                      letterSpacing:
                                          spacing.letterSpacingEm * 20,
                                      color: palette.ink,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 32),
                    ],
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

/// The current section: a lead line, then step rows for step sections or
/// the remaining units as body text. For step sections the lead is the
/// section title; otherwise it is the first unit.
class _Section extends StatelessWidget {
  const _Section({
    super.key,
    required this.lesson,
    required this.sectionIndex,
    required this.fontFamily,
    required this.ink,
    required this.button,
    required this.onButton,
    required this.lineHeightScale,
    required this.letterSpacingEm,
    required this.textScale,
  });

  final LibraryLesson lesson;
  final int sectionIndex;
  final String fontFamily;
  final Color ink;
  final Color button;
  final Color onButton;
  final double lineHeightScale;
  final double letterSpacingEm;
  final double textScale;

  @override
  Widget build(BuildContext context) {
    final section = lesson.sections[sectionIndex];
    final hasSteps = section.units.any((u) => u.stepTitle != null);
    final lead = hasSteps
        ? section.title
        : section.units.isEmpty
            ? section.title
            : section.units.first.text;
    final rest =
        hasSteps ? section.units : section.units.skip(1).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 36),
          child: Text(
            lead,
            style: TextStyle(
              fontFamily: fontFamily,
              fontWeight: FontWeight.w900,
              fontSize: 32,
              height: 42 / 32 * lineHeightScale,
              letterSpacing: letterSpacingEm * 32,
              color: ink,
            ),
          ),
        ),
        const SizedBox(height: 28),
        if (hasSteps)
          for (var i = 0; i < rest.length; i++) ...[
            if (i > 0) const SizedBox(height: 36),
            _StepRow(
              number: i + 1,
              title: rest[i].stepTitle ?? rest[i].text,
              fontFamily: fontFamily,
              ink: ink,
              button: button,
              onButton: onButton,
              lineHeightScale: lineHeightScale,
              letterSpacingEm: letterSpacingEm,
              textScale: textScale,
            ),
          ]
        else
          for (final unit in rest)
            Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Text(
                unit.text,
                style: TextStyle(
                  fontFamily: fontFamily,
                  fontWeight: FontWeight.w600,
                  fontSize: 24,
                  height: 32 / 24 * lineHeightScale,
                  letterSpacing: letterSpacingEm * 24,
                  color: ink,
                ),
              ),
            ),
      ],
    );
  }
}

/// One numbered step: the circle, then the uppercase title.
class _StepRow extends StatelessWidget {
  const _StepRow({
    required this.number,
    required this.title,
    required this.fontFamily,
    required this.ink,
    required this.button,
    required this.onButton,
    required this.lineHeightScale,
    required this.letterSpacingEm,
    required this.textScale,
  });

  final int number;
  final String title;
  final String fontFamily;
  final Color ink;
  final Color button;
  final Color onButton;
  final double lineHeightScale;
  final double letterSpacingEm;
  final double textScale;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(top: 6 * textScale),
          child: Container(
            width: 24 * textScale,
            height: 24 * textScale,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: button,
            ),
            alignment: Alignment.center,
            child: Text(
              number.toString(),
              style: TextStyle(
                fontFamily: fontFamily,
                fontWeight: FontWeight.w900,
                fontSize: 14,
                color: onButton,
              ),
            ),
          ),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: Text(
            title.toUpperCase(),
            style: TextStyle(
              fontFamily: fontFamily,
              fontWeight: FontWeight.w600,
              fontSize: 28,
              height: 36 / 28 * lineHeightScale,
              letterSpacing: letterSpacingEm * 28,
              color: ink,
            ),
          ),
        ),
      ],
    );
  }
}
