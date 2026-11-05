import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/nav/resonant_nav.dart';
import '../../../core/providers.dart';
import '../../../core/services/haptics.dart';
import '../../../core/theme/shapes.dart';
import '../../../core/ui/icons.dart';
import '../../../core/ui/key_shortcuts.dart';
import '../../../core/ui/system_bars.dart';
import '../../../core/ui/top_bar.dart';
import '../../learn/domain/library.dart';
import '../../learn/domain/quiz_data.dart';
import '../application/quiz_session.dart';
import '../gestures/gesture_phrases.dart';
import '../gestures/gesture_types.dart';
import 'gesture_guide.dart';
import 'gesture_surface.dart';
import 'settings_screen.dart';

/// One quiz being taken, ported from Resonant's QuizScreen: the prompt,
/// one option card to browse, tap to choose, swipe right to submit. The
/// screen takes the theme's correct or incorrect colors after an answer,
/// and the check or cross says it too, so the result never depends on
/// telling colors apart.
class QuizReaderScreen extends ConsumerStatefulWidget {
  const QuizReaderScreen({
    super.key,
    required this.quiz,
    required this.onFinished,
  });

  final LibraryQuizSet quiz;

  /// Called with the correct count, the total, and the missed question ids.
  final void Function(int correct, int total, List<String> missed) onFinished;

  @override
  ConsumerState<QuizReaderScreen> createState() => _QuizReaderScreenState();
}

class _QuizReaderScreenState extends ConsumerState<QuizReaderScreen> {
  late final QuizSession _session;

  /// 0 is the prompt, 1..N the options.
  int _queueIndex = 0;

  @override
  void initState() {
    super.initState();
    _session = QuizSession(widget.quiz);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(speechProvider).speak(_session.question.prompt);
    });
  }

  int? get _visibleOption => _queueIndex >= 1 ? _queueIndex - 1 : null;

  String _unit(int queueIndex) {
    if (queueIndex == 0) return _session.question.prompt;
    final opt = _session.question.options[queueIndex - 1];
    return quizOptionUnit(opt.letter, opt.text);
  }

  void _speak(String text) => ref.read(speechProvider).speak(text);

  void _buzz(HapticPattern pattern) {
    ref.read(hapticsProvider).play(pattern);
    ref.read(cuesProvider).play(pattern);
  }

  void _land(int queueIndex) {
    _queueIndex = queueIndex;
    setState(() {});
    _speak(_unit(queueIndex));
    if (queueIndex >= 1) _buzz(optionPattern(queueIndex - 1));
  }

  void _next() {
    if (_queueIndex + 1 > _session.question.options.length) {
      _buzz(HapticPattern.edge);
      return;
    }
    _land(_queueIndex + 1);
  }

  void _previous() {
    if (_queueIndex - 1 < 0) {
      _buzz(HapticPattern.edge);
      return;
    }
    _land(_queueIndex - 1);
    if (_queueIndex == 0) _buzz(HapticPattern.previous);
  }

  void _select() {
    final optIndex = _visibleOption;
    if (_session.submitted || optIndex == null) return;
    _session.selectOption(optIndex);
    setState(() {});
    _buzz(HapticPattern.select);
    _speak(quizSelectSpoken(_session.question.options[optIndex].letter));
  }

  void _submit() {
    if (_session.submitted) return;
    final verdict = _session.submit();
    if (verdict == null) {
      _speak(quizNoSelectionSpoken());
      _buzz(HapticPattern.error);
      return;
    }
    setState(() {});
    _buzz(verdict.correct ? HapticPattern.correct : HapticPattern.incorrect);
    _speak(quizSubmitSpoken(verdict.correct, verdict.explanation));
  }

  void _advance() {
    _buzz(HapticPattern.next);
    if (_session.advance()) {
      widget.onFinished(
        _session.correctCount,
        widget.quiz.questions.length,
        _session.missedQuestions().map((q) => q.id).toList(),
      );
      return;
    }
    _queueIndex = 0;
    setState(() {});
    _speak(_session.question.prompt);
  }

  /// Screen-reader "Next": browse on, or advance once submitted.
  void _srNext() {
    if (_session.submitted) {
      _advance();
    } else {
      _next();
    }
  }

  /// Screen-reader "Previous": step back while browsing.
  void _srPrevious() {
    if (!_session.submitted) _previous();
  }

  void _repeat() => _speak(_unit(_queueIndex));

  void _hold() {
    final selected = _session.selectedOption;
    _speak(quizHoldSummary(
      questionIndex: _session.questionIndex,
      total: widget.quiz.questions.length,
      submitted: _session.submitted,
      correct: _session.lastCorrect,
      selectedLetter: selected == null
          ? null
          : _session.question.options[selected].letter,
    ));
  }

  void _speed(double delta) {
    final speech = ref.read(speechProvider);
    speech.rate = (speech.rate + delta).clamp(0.5, 2.0);
    speech.speak(delta > 0 ? 'Faster.' : 'Slower.');
  }

  void _leave() {
    _buzz(HapticPattern.back);
    _speak('Leaving the quiz. Back to Quizzes.');
    Navigator.of(context).pop();
  }

  void _onGesture(Gesture gesture) {
    switch (gesture) {
      case Swipe(zone: Zone.center, direction: SwipeDirection.up):
        if (_session.submitted) {
          _advance();
        } else {
          _next();
        }
      case Swipe(zone: Zone.center, direction: SwipeDirection.down):
        if (!_session.submitted) _previous();
      case Swipe(zone: Zone.center, direction: SwipeDirection.right):
        if (!_session.submitted) _submit();
      case Tap(zone: Zone.center):
        _select();
      case Tap(zone: Zone.leftEdge):
        ref.read(speechProvider).stop();
        _buzz(HapticPattern.confirm);
      case DoubleTap(zone: Zone.leftEdge):
        _repeat();
      case LongPress(zone: Zone.rightEdge):
        _leave();
      case ThreeFingerTap():
        _repeat();
      case ThreeFingerHold():
        _hold();
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
    final reduce = MediaQuery.of(context).disableAnimations;
    final submitted = _session.submitted;
    final correct = _session.lastCorrect == true;
    final background = submitted
        ? (correct ? palette.correct : palette.incorrect)
        : palette.background;
    final textColor = submitted
        ? (correct ? palette.onCorrect : palette.onIncorrect)
        : palette.ink;
    paintSystemBars(background);
    final visible = _visibleOption;
    final showUp = !submitted && _queueIndex > 1;
    final showDown = !submitted &&
        visible != null &&
        visible < _session.question.options.length - 1;
    return AnimatedContainer(
      duration: reduce ? Duration.zero : const Duration(milliseconds: 250),
      curve: Curves.fastOutSlowIn,
      color: background,
      child: SafeArea(
        child: Column(
          children: [
            LessonsTopBar(
              onBack: _leave,
              title: 'Quizzes',
              backAnnouncement: 'Leaving the quiz. Back to Quizzes.',
              onSettings: () => _openSettings(context),
            ),
            const FirstVisitGuide(screen: GuideScreen.quizReader),
            Expanded(
              child: ListShortcuts(
                onMove: (d) {
                  if (d > 0) {
                    if (_session.submitted) {
                      _advance();
                    } else {
                      _next();
                    }
                  } else if (!_session.submitted) {
                    _previous();
                  }
                },
                onActivate: _select,
                onRight: () {
                  if (!_session.submitted) _submit();
                },
                onBack: _leave,
                child: GestureSurface(
                  onGesture: _onGesture,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      // The prompt takes what it needs up to a third of
                      // the screen, then scrolls inside its box: at the
                      // largest text an unbounded prompt would crush the
                      // option card below it. One finger already scrolls
                      // past the gesture surface.
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxHeight:
                              MediaQuery.sizeOf(context).height * 0.35,
                        ),
                        child: SingleChildScrollView(
                          child: Text(
                            _session.question.prompt,
                            style: TextStyle(
                              fontFamily: font.family,
                              fontWeight: FontWeight.w900,
                              fontSize: 35,
                              height: 48 / 35,
                              color: textColor,
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (submitted)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 12),
                        child: ExcludeSemantics(
                          // Already spoken, so TalkBack skips it.
                          child: Row(
                            children: [
                              _ResultMark(
                                  correct: correct, tint: textColor),
                              const SizedBox(width: 12),
                              Text(
                                correct ? 'Correct' : 'Incorrect',
                                style: TextStyle(
                                  fontFamily: font.family,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 36,
                                  color: textColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                        child: Column(
                          children: [
                            SizedBox(
                              height: 76,
                              child: Center(
                                child: showUp
                                    ? VerticalArrow(
                                        up: true,
                                        tint: textColor.withValues(alpha: 0.8))
                                    : null,
                              ),
                            ),
                            Expanded(
                              child: Semantics(
                                label: visible != null
                                    ? quizOptionUnit(
                                        _session.question.options[visible].letter,
                                        _session.question.options[visible].text)
                                    : const GesturePhrases().seeOptions,
                                onTap: visible != null && !submitted ? _select : null,
                                customSemanticsActions: {
                                  const CustomSemanticsAction(label: 'Next'): _srNext,
                                  const CustomSemanticsAction(label: 'Previous'): _srPrevious,
                                  if (!submitted)
                                    const CustomSemanticsAction(label: 'Submit'): _submit,
                                },
                                child: ExcludeSemantics(
                                  child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 28, vertical: 20),
                                decoration: BoxDecoration(
                                  color: visible != null
                                      ? palette.card
                                      : palette.card.withValues(alpha: 0.3),
                                  borderRadius: cardShape(palette),
                                  border: visible != null
                                      ? cardBorder(palette)
                                      : null,
                                ),
                                alignment: Alignment.center,
                                child: visible != null
                                    ? FittedTitle(
                                        _session.question
                                            .options[visible].text,
                                        maxSp: 36,
                                        lineRatio: 41 / 36,
                                        minSp: 20,
                                      )
                                    : Text(
                                        const GesturePhrases().seeOptions,
                                        style: TextStyle(
                                          fontFamily: font.family,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 24,
                                          color: textColor.withValues(
                                              alpha: 0.6),
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                              ),
                                ),
                              ),
                            ),
                            SizedBox(
                              height: 76,
                              child: Center(
                                child: showDown
                                    ? VerticalArrow(
                                        up: false,
                                        tint: textColor.withValues(alpha: 0.8))
                                    : null,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
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

/// A check or a cross, drawn with lines so it needs no icon file and
/// scales cleanly. It grows from 80% and fades in once when the result
/// appears; shown at once with Reduce motion.
class _ResultMark extends StatefulWidget {
  const _ResultMark({required this.correct, required this.tint});

  final bool correct;
  final Color tint;

  @override
  State<_ResultMark> createState() => _ResultMarkState();
}

class _ResultMarkState extends State<_ResultMark>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  bool _started = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (MediaQuery.of(context).disableAnimations) {
      _controller.value = 1;
    } else {
      unawaited(_controller.forward());
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 48,
      height: 48,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final p = CurvedAnimation(
            parent: _controller,
            curve: Curves.fastOutSlowIn,
          ).value;
          return Opacity(
            opacity: p,
            child: Transform.scale(
              scale: 0.8 + 0.2 * p,
              child: CustomPaint(
                painter: _MarkPainter(
                    correct: widget.correct, tint: widget.tint),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _MarkPainter extends CustomPainter {
  const _MarkPainter({required this.correct, required this.tint});

  final bool correct;
  final Color tint;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final paint = Paint()
      ..color = tint
      ..strokeWidth = w * 0.14
      ..strokeCap = StrokeCap.round;
    if (correct) {
      canvas.drawLine(Offset(w * 0.18, h * 0.54), Offset(w * 0.40, h * 0.76), paint);
      canvas.drawLine(Offset(w * 0.40, h * 0.76), Offset(w * 0.84, h * 0.26), paint);
    } else {
      canvas.drawLine(Offset(w * 0.22, h * 0.22), Offset(w * 0.78, h * 0.78), paint);
      canvas.drawLine(Offset(w * 0.78, h * 0.22), Offset(w * 0.22, h * 0.78), paint);
    }
  }

  @override
  bool shouldRepaint(_MarkPainter old) =>
      old.correct != correct || old.tint != tint;
}
