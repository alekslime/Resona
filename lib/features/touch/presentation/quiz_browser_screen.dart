import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/nav/menu_focus.dart';
import '../../../core/nav/resonant_nav.dart';
import '../../../core/providers.dart';
import '../../../core/services/haptics.dart';
import '../../../core/theme/motion.dart';
import '../../../core/theme/resonant_theme.dart';
import '../../../core/theme/shapes.dart';
import '../../../core/ui/enter.dart';
import '../../../core/ui/focus_fade.dart';
import '../../../core/ui/icons.dart';
import '../../../core/ui/press.dart';
import '../../../core/ui/system_bars.dart';
import '../../../core/ui/top_bar.dart';
import '../../learn/domain/library.dart';
import '../../learn/domain/progress.dart';
import '../../learn/domain/quiz_data.dart';
import '../gestures/gesture_types.dart';
import 'gesture_surface.dart';
import 'home_screen.dart';
import 'quiz_reader_screen.dart';
import 'quiz_results_screen.dart';
import 'settings_screen.dart';

/// The quiz shelf, ported from Resonant's QuizBrowserScreen: the headline,
/// then one card per set with a title-cased Start/Continue/Review button.
/// Two fingers swipe between sets; a tap opens the focused one.
class QuizBrowserScreen extends ConsumerStatefulWidget {
  const QuizBrowserScreen({super.key});

  @override
  ConsumerState<QuizBrowserScreen> createState() => _QuizBrowserScreenState();
}

class _QuizBrowserScreenState extends ConsumerState<QuizBrowserScreen> {
  late final MenuFocus _focus;
  final _scroll = ScrollController();
  late final List<GlobalKey> _keys;

  /// The last round's missed questions, kept for the retry round.
  List<LibraryQuizQuestion> _lastMissed = const [];

  @override
  void initState() {
    super.initState();
    _focus = MenuFocus(count: allQuizSets.length);
    _keys = [for (var i = 0; i < allQuizSets.length; i++) GlobalKey()];
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// A tap the cards took themselves: the surface drops its echo.
  bool _onCard(Offset position) => _keys.any((k) {
        final box = k.currentContext?.findRenderObject() as RenderBox?;
        if (box == null || !box.attached) return false;
        return Rect.fromPoints(
          box.localToGlobal(Offset.zero),
          box.localToGlobal(box.size.bottomRight(Offset.zero)),
        ).contains(position);
      });

  QuizProgress _progressOf(String id) =>
      ref.read(quizBookProvider.notifier).of(id);

  String _unit(int i) {
    final quiz = allQuizSets[i];
    final p = _progressOf(quiz.id);
    return quizBrowserUnit(
      title: quiz.title,
      category: quiz.category,
      questions: quiz.questions.length,
      status: p.statusLabel,
      percent: p.percentComplete,
    );
  }

  void _open(int i) {
    final quiz = allQuizSets[i];
    _buzz(HapticPattern.select);
    ref.read(speechProvider).speak(quizOpenSpoken(quiz.title));
    ref
        .read(quizBookProvider.notifier)
        .markInProgress(quiz.id, quiz.questions.length);
    Navigator.of(context).push(resonantRoute(
      QuizReaderScreen(
        quiz: quiz,
        onFinished: (correct, total, missed) =>
            _onFinished(quiz.id, quiz.questions.length, correct, total, missed),
      ),
      reduce: MediaQuery.of(context).disableAnimations,
    ));
  }

  void _onFinished(
    String quizId,
    int totalQuestions,
    int correct,
    int total,
    List<String> missedIds,
  ) {
    List<LibraryQuizQuestion> pool = _lastMissed;
    if (quizId != 'quiz_review') {
      pool = sampleQuiz.questions;
      for (final q in allQuizSets) {
        if (q.id == quizId) pool = q.questions;
      }
    }
    _lastMissed = [
      for (final q in pool)
        if (missedIds.contains(q.id)) q,
    ];
    ref.read(activityProvider.notifier).quizFinished();
    if (quizId != 'quiz_review') {
      ref
          .read(quizBookProvider.notifier)
          .markCompleted(quizId, correct, totalQuestions);
    }
    if (!mounted) return;
    Navigator.of(context).pushReplacement(resonantRoute(
      QuizResultsScreen(
        correct: correct,
        total: total,
        missedCount: _lastMissed.length,
        onRetryMissed: _retry,
        onDone: _done,
      ),
      reduce: MediaQuery.of(context).disableAnimations,
    ));
  }

  void _retry() {
    if (_lastMissed.isEmpty || !mounted) return;
    Navigator.of(context).pushReplacement(resonantRoute(
      QuizReaderScreen(
        quiz: reviewSet(_lastMissed),
        onFinished: (correct, total, missed) => _onFinished(
            'quiz_review', _lastMissed.length, correct, total, missed),
      ),
      reduce: MediaQuery.of(context).disableAnimations,
    ));
  }

  void _done() {
    _lastMissed = const [];
    if (mounted) Navigator.of(context).pop();
  }

  void _move(int delta) {
    final moved = delta > 0 ? _focus.next() : _focus.previous();
    if (!moved) return;
    setState(() {});
    final target = _keys[_focus.index].currentContext;
    if (target != null) {
      unawaited(Scrollable.ensureVisible(
        target,
        duration: MediaQuery.of(context).disableAnimations
            ? Duration.zero
            : const Duration(milliseconds: 250),
      ));
    }
    ref.read(speechProvider).speak(_unit(_focus.index));
    _buzz(delta > 0 ? HapticPattern.next : HapticPattern.previous);
  }

  void _buzz(HapticPattern pattern) {
    ref.read(hapticsProvider).play(pattern);
    ref.read(cuesProvider).play(pattern);
  }

  void _speed(double delta) {
    final speech = ref.read(speechProvider);
    speech.rate = (speech.rate + delta).clamp(0.5, 2.0);
    speech.speak(delta > 0 ? 'Faster.' : 'Slower.');
  }

  void _onGesture(Gesture gesture) {
    final book = ref.read(quizBookProvider);
    switch (gesture) {
      case Swipe(zone: Zone.center, direction: SwipeDirection.up):
        _move(1);
      case Swipe(zone: Zone.center, direction: SwipeDirection.down):
        _move(-1);
      case Tap(zone: Zone.center):
        _open(_focus.index);
      case Tap(zone: Zone.leftEdge):
        ref.read(speechProvider).stop();
        _buzz(HapticPattern.confirm);
      case DoubleTap(zone: Zone.leftEdge):
        ref.read(speechProvider).speak(_unit(_focus.index));
      case LongPress(zone: Zone.rightEdge):
        _buzz(HapticPattern.back);
        ref.read(speechProvider).speak('Back to Home.');
        unawaited(goBack(context, home: const HomeScreen()));
      case ThreeFingerTap():
        ref.read(speechProvider).speak(_unit(_focus.index));
      case ThreeFingerHold():
        final quiz = allQuizSets[_focus.index];
        final done = book.values
            .where((p) => p.status == QuizStatus.completed)
            .length;
        ref.read(speechProvider).speak(quizBrowserHold(
              currentTitle: quiz.title,
              status: _progressOf(quiz.id).statusLabel,
              done: done,
              total: allQuizSets.length,
            ));
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
    ref.watch(quizBookProvider);
    paintSystemBars(palette.background);
    return Container(
      color: palette.background,
      child: SafeArea(
        child: Column(
          children: [
            LessonsTopBar(
              title: 'Quizzes',
              onBack: () {
                unawaited(goBack(context, home: const HomeScreen()));
              },
              onSettings: () => _openSettings(context),
            ),
            Expanded(
              child: GestureSurface(
                exploreEnabled: false,
                twoFingerSwipe: true,
                ignoreChildGestureAt: _onCard,
                onGesture: _onGesture,
                child: SingleChildScrollView(
                  controller: _scroll,
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Test what you know.',
                        style: TextStyle(
                          fontFamily: font.family,
                          fontWeight: FontWeight.w900,
                          fontSize: 44,
                          height: 52 / 44,
                          color: palette.ink,
                        ),
                      ),
                      const SizedBox(height: 24),
                      for (var i = 0; i < allQuizSets.length; i++) ...[
                        if (i > 0) const SizedBox(height: 20),
                        _QuizCard(
                          key: _keys[i],
                          quiz: allQuizSets[i],
                          progress: _progressOf(allQuizSets[i].id),
                          focused: i == _focus.index,
                          index: i,
                          onTap: () {
                            setState(() => _focus.jumpTo(i));
                            _open(i);
                          },
                        ),
                      ],
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

/// One quiz: the fitted title, then a full-width Start/Continue/Review
/// button. The focused card is the inverted one, as on Settings.
class _QuizCard extends ConsumerWidget {
  const _QuizCard({
    super.key,
    required this.quiz,
    required this.progress,
    required this.focused,
    required this.index,
    required this.onTap,
  });

  final LibraryQuizSet quiz;
  final QuizProgress progress;
  final bool focused;
  final int index;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(paletteProvider);
    final font = ref.watch(fontProvider);
    return Semantics(
      label:
          '${quiz.title}. ${quiz.category}. ${quiz.questions.length} questions. '
          '${progress.statusLabel}. ${progress.percentComplete} percent complete.'
          '${focused ? ' Focused.' : ''}',
      child: EnterStagger(
        index: index,
        child: FocusLift(
          focused: focused,
          themeFloor: MotionProfiles.forTheme(palette.id).minDamping,
          child: PressScale(
            themeFloor: MotionProfiles.forTheme(palette.id).minDamping,
            child: GestureDetector(
              // Inside the press reply, like the old clickable: the tap
              // wins the arena over the press visual.
              onTap: onTap,
              child: FocusColor(
                target: focused ? palette.ink : palette.card,
                builder: (context, card) => Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: card,
                    borderRadius: cardShape(palette),
                    border: cardBorder(palette),
                  ),
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      FittedTitle(
                        quiz.title,
                        color: focused ? palette.onInk : palette.ink,
                      ),
                      const SizedBox(height: 22),
                      Container(
                        constraints: const BoxConstraints(
                            minHeight: minTouchTarget),
                        decoration: BoxDecoration(
                          color: focused ? palette.onInk : palette.button,
                          borderRadius: controlShape(palette),
                          border: controlBorder(palette),
                        ),
                        padding:
                            const EdgeInsets.symmetric(horizontal: 20),
                        child: Row(
                          mainAxisAlignment:
                              MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              quizButtonTitle(progress.buttonLabel),
                              style: TextStyle(
                                fontFamily: font.family,
                                fontWeight: FontWeight.w600,
                                fontSize: 22,
                                color: focused
                                    ? palette.ink
                                    : palette.onButton,
                              ),
                            ),
                            ArrowIcon(
                              pointRight: true,
                              tint: focused
                                  ? palette.ink
                                  : palette.onButton,
                              size: 22,
                            ),
                          ],
                        ),
                      ),
                    ],
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
