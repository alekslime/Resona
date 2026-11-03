import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/nav/resonant_nav.dart';
import '../../../core/providers.dart';
import '../../../core/services/haptics.dart';
import '../../../core/theme/resonant_theme.dart';
import '../../../core/theme/shapes.dart';
import '../../../core/ui/celebration.dart';
import '../../../core/ui/enter.dart';
import '../../../core/ui/system_bars.dart';
import '../../../core/ui/top_bar.dart';
import '../../learn/domain/quiz_data.dart';
import '../gestures/gesture_types.dart';
import 'gesture_surface.dart';
import 'settings_screen.dart';

/// The score after a quiz, ported from Resonant's QuizResultsScreen: the
/// big score in a white card, the verdict under it, and a retry button
/// when anything was missed. Real buttons sit outside the gesture
/// detector on purpose (it consumes touches); the taps do the same.
class QuizResultsScreen extends ConsumerStatefulWidget {
  const QuizResultsScreen({
    super.key,
    required this.correct,
    required this.total,
    required this.missedCount,
    required this.onRetryMissed,
    required this.onDone,
  });

  final int correct;
  final int total;

  /// Empty on a perfect score or a retry round: nothing left to retry.
  final int missedCount;
  final VoidCallback onRetryMissed;
  final VoidCallback onDone;

  @override
  ConsumerState<QuizResultsScreen> createState() =>
      _QuizResultsScreenState();
}

class _QuizResultsScreenState extends ConsumerState<QuizResultsScreen> {
  bool get _canRetry => widget.missedCount > 0;
  bool _cheering = false;
  Timer? _cheerWait;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _buzz(HapticPattern.confirm);
      ref.read(speechProvider).speak(quizResultsSpoken(
          widget.correct, widget.total, widget.missedCount,
          name: ref.read(userNameProvider)));
      // A perfect score gets a fanfare and a burst of dots just after
      // the first tap. Nothing else changes, and the spoken result
      // is never delayed.
      if (widget.total > 0 &&
          quizPercent(widget.correct, widget.total) == 100) {
        _cheerWait = Timer(const Duration(milliseconds: 650), () {
          if (!mounted) return;
          _buzz(HapticPattern.celebration);
          setState(() => _cheering = true);
        });
      }
    });
  }

  @override
  void dispose() {
    _cheerWait?.cancel();
    super.dispose();
  }

  void _buzz(HapticPattern pattern) {
    ref.read(hapticsProvider).play(pattern);
    ref.read(cuesProvider).play(pattern);
  }

  void _retry() {
    _buzz(HapticPattern.select);
    ref
        .read(speechProvider)
        .speak(quizRetryAnnouncement(widget.missedCount));
    widget.onRetryMissed();
  }

  void _done() {
    _buzz(HapticPattern.confirm);
    widget.onDone();
  }

  void _repeat() => ref.read(speechProvider).speak(quizResultsSpoken(
      widget.correct, widget.total, widget.missedCount,
      name: ref.read(userNameProvider)));

  void _speed(double delta) {
    final speech = ref.read(speechProvider);
    speech.rate = (speech.rate + delta).clamp(0.5, 2.0);
    speech.speak(delta > 0 ? 'Faster.' : 'Slower.');
  }

  void _onGesture(Gesture gesture) {
    switch (gesture) {
      case Tap(zone: Zone.center):
        _done();
      case Tap(zone: Zone.leftEdge):
        ref.read(speechProvider).stop();
        _buzz(HapticPattern.confirm);
      case Tap(zone: Zone.rightEdge):
        if (_canRetry) _retry();
      case DoubleTap(zone: Zone.leftEdge):
        _repeat();
      case LongPress(zone: Zone.rightEdge):
        _buzz(HapticPattern.back);
        ref.read(speechProvider).speak('Back to Home.');
        widget.onDone();
      case ThreeFingerTap():
        _repeat();
      case ThreeFingerHold():
        ref.read(speechProvider).speak(quizResultsHoldSummary(
            widget.correct, widget.total, widget.missedCount));
      case HoldSpeedUp():
        _speed(0.1);
        _buzz(HapticPattern.speedUp);
      case HoldSpeedDown():
        _speed(-0.1);
        _buzz(HapticPattern.speedDown);
      default:
        break;
    }
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
    paintSystemBars(palette.background);
    return Stack(
      children: [
        Container(
          color: palette.background,
          child: SafeArea(
            child: Column(
              children: [
                LessonsTopBar(
                  title: 'Results',
                  onBack: widget.onDone,
                  backAnnouncement: 'Back to quizzes.',
                  onSettings: () => _openSettings(context),
                ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                quizResultsSubtitle(widget.correct, widget.total),
                style: TextStyle(
                  fontFamily: font.family,
                  fontWeight: FontWeight.w600,
                  fontSize: 18,
                  color: palette.ink,
                ),
              ),
            ),
            Expanded(
              child: GestureSurface(
                exploreEnabled: false,
                onGesture: _onGesture,
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      EnterStagger(
                        index: 0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 32),
                          decoration: BoxDecoration(
                            color: palette.card,
                            borderRadius: cardShape(palette),
                            border: cardBorder(palette),
                          ),
                          child: Column(
                            children: [
                              Text(
                                '${widget.correct} / ${widget.total}',
                                style: TextStyle(
                                  fontFamily: font.family,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 72,
                                  height: 78 / 72,
                                  color: palette.ink,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                quizResultLabel(
                                    widget.correct, widget.total),
                                style: TextStyle(
                                  fontFamily: font.family,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 26,
                                  color: palette.ink,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ),
                      EnterStagger(
                        index: 2,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 24),
                          child: Text(
                            quizResultsHint(widget.missedCount),
                            style: TextStyle(
                              fontFamily: font.family,
                              fontWeight: FontWeight.w600,
                              fontSize: 18,
                              height: 24 / 18,
                              color: palette.ink,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_canRetry) ...[
                    _ResultsButton(
                      label: quizRetryLabel(widget.missedCount),
                      filled: true,
                      onTap: _retry,
                    ),
                    const SizedBox(height: 12),
                  ],
                  _ResultsButton(
                    label: 'Back to quizzes',
                    filled: !_canRetry,
                    onTap: _done,
                  ),
                ],
              ),
            ),
          ],
        ),
        ),
        ),
        if (_cheering)
          CelebrationOverlay(
            color: palette.ink,
            onDone: () {
              if (mounted) setState(() => _cheering = false);
            },
          ),
      ],
    );
  }
}

/// A full-width results button. The primary action is filled; the other
/// is the plain card, like the old ResonantButton pair.
class _ResultsButton extends ConsumerWidget {
  const _ResultsButton({
    required this.label,
    required this.filled,
    required this.onTap,
  });

  final String label;
  final bool filled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(paletteProvider);
    final font = ref.watch(fontProvider);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        constraints:
            const BoxConstraints(minHeight: minTouchTarget),
        decoration: BoxDecoration(
          color: filled ? palette.button : palette.card,
          borderRadius: controlShape(palette),
          border: controlBorder(palette),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontFamily: font.family,
            fontWeight: FontWeight.w600,
            fontSize: 22,
            color: filled ? palette.onButton : palette.ink,
          ),
        ),
      ),
    );
  }
}
