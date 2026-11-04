import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/nav/menu_focus.dart';
import '../../../core/nav/resonant_nav.dart';
import '../../../core/providers.dart';
import '../../../core/services/haptics.dart';
import '../../../core/theme/motion.dart';
import '../../../core/theme/shapes.dart';
import '../../../core/ui/capped_text.dart';
import '../../../core/ui/enter.dart';
import '../../../core/ui/focus_fade.dart';
import '../../../core/ui/press.dart';
import '../../../core/ui/system_bars.dart';
import '../../../core/ui/top_bar.dart';
import '../../learn/domain/library.dart';
import '../gestures/gesture_types.dart';
import 'gesture_surface.dart';
import 'lesson_screen.dart';
import 'settings_screen.dart';

class _Mode {
  const _Mode(this.label, this.auto, this.spoken);
  final String label;
  final bool auto;
  final String spoken;
}

const _modes = [
  _Mode('MANUAL', false,
      'Manual. You tap the center of the screen to hear each sentence.'),
  _Mode('AUTO', true, 'Auto. The lesson plays straight through on its own.'),
];

/// Manual or auto: after picking a lesson, choose how to go through it.
/// Ported from Resonant's LessonModeScreen. Same gestures as home: swipe
/// up or down to move between the two, tap the center to choose; tapping
/// a card chooses it directly.
class LessonModeScreen extends ConsumerStatefulWidget {
  const LessonModeScreen({super.key, required this.lesson});

  final LibraryLesson lesson;

  @override
  ConsumerState<LessonModeScreen> createState() => _LessonModeScreenState();
}

class _LessonModeScreenState extends ConsumerState<LessonModeScreen> {
  final _focus = MenuFocus(count: _modes.length);
  final _keys = [GlobalKey(), GlobalKey()];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(speechProvider).speak(
          'How do you want to go through this lesson? Swipe up or down to choose, then tap the center.');
      ref.read(speechProvider).speak(_modes[0].spoken, queue: true);
    });
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

  void _pick(int i) {
    _buzz(HapticPattern.select);
    Navigator.of(context).pushReplacement(resonantRoute(
      LessonScreen(lesson: widget.lesson, autoAdvance: _modes[i].auto),
      reduce: MediaQuery.of(context).disableAnimations,
    ));
  }

  void _move(int delta) {
    final moved = delta > 0 ? _focus.next() : _focus.previous();
    if (!moved) {
      _buzz(HapticPattern.edge);
      return;
    }
    setState(() {});
    ref.read(speechProvider).speak(_modes[_focus.index].spoken);
    _buzz(delta > 0 ? HapticPattern.next : HapticPattern.previous);
  }

  void _repeat() {
    ref.read(speechProvider).speak(_modes[_focus.index].spoken);
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
    switch (gesture) {
      case Swipe(zone: Zone.center, direction: SwipeDirection.up):
        _move(1);
      case Swipe(zone: Zone.center, direction: SwipeDirection.down):
        _move(-1);
      case Tap(zone: Zone.center):
        _pick(_focus.index);
      case Tap(zone: Zone.leftEdge):
        ref.read(speechProvider).stop();
        _buzz(HapticPattern.confirm);
      case DoubleTap(zone: Zone.leftEdge):
        _repeat();
      case LongPress(zone: Zone.rightEdge):
        _buzz(HapticPattern.back);
        ref.read(speechProvider).speak('Back to Lessons.');
        Navigator.of(context).pop();
      case ThreeFingerTap():
        _repeat();
      case ThreeFingerHold():
        ref.read(speechProvider).speak(
            'Choose Manual or Auto. Currently focused: ${_modes[_focus.index].label.toLowerCase()}.');
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

  void _back() {
    Navigator.of(context).pop();
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
    paintSystemBars(palette.background);
    return Container(
      color: palette.background,
      child: SafeArea(
        child: Column(
          children: [
            LessonsTopBar(
              backAnnouncement: 'Back to Lessons.',
              onBack: _back,
              onSettings: () => _openSettings(context),
            ),
            Expanded(
              child: GestureSurface(
                ignoreChildGestureAt: _onCard,
                onGesture: _onGesture,
                child: Padding(
                  padding:
                      const EdgeInsets.fromLTRB(22, 12, 22, 24),
                  child: CappedText(
                    max: 1.3,
                    child: Column(
                      children: [
                        for (var i = 0; i < _modes.length; i++) ...[
                          if (i > 0) const SizedBox(height: 32),
                          Expanded(
                            child: _ModeCard(
                              key: _keys[i],
                              mode: _modes[i],
                              focused: i == _focus.index,
                              index: i,
                              onTap: () {
                                setState(() => _focus.jumpTo(i));
                                _pick(i);
                              },
                            ),
                          ),
                        ],
                      ],
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

class _ModeCard extends ConsumerWidget {
  const _ModeCard({
    super.key,
    required this.mode,
    required this.focused,
    required this.index,
    required this.onTap,
  });

  final _Mode mode;
  final bool focused;
  final int index;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(paletteProvider);
    final font = ref.watch(fontProvider);
    return Semantics(
      label: mode.spoken + (focused ? ' Focused.' : ''),
      child: EnterStagger(
        index: index,
        child: FocusLift(
          focused: focused,
          themeFloor:
              MotionProfiles.forTheme(palette.id).minDamping,
          child: PressScale(
            themeFloor:
                MotionProfiles.forTheme(palette.id).minDamping,
            child: GestureDetector(
              // Inside the press reply, like the old clickable: the tap
              // wins the arena over the press visual. Long presses do
              // nothing here, but claiming them keeps the tap from
              // firing on release.
              onLongPress: () {},
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
                  alignment: Alignment.center,
                  child: Text(
                    mode.label,
                    style: TextStyle(
                      fontFamily: font.family,
                      fontWeight: FontWeight.w900,
                      fontSize: 54,
                      color: focused ? palette.onInk : palette.ink,
                    ),
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
