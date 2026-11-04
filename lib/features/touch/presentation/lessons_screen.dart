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
import '../../../core/ui/key_shortcuts.dart';
import '../../../core/ui/press.dart';
import '../../../core/ui/system_bars.dart';
import '../../../core/ui/top_bar.dart';
import '../../learn/domain/lesson_data.dart';
import '../gestures/gesture_types.dart';
import 'gesture_surface.dart';
import 'home_screen.dart';
import 'lesson_mode_screen.dart';
import 'settings_screen.dart';

/// The lesson library, ported from Resonant's LessonsScreen: the built-in
/// lessons as cards, the focused one inverted. Two fingers swipe between
/// them (one finger scrolls); a tap opens; a hold on your own material
/// deletes it — everything here is built in, so a hold says so instead.
class LessonsScreen extends ConsumerStatefulWidget {
  const LessonsScreen({super.key});

  @override
  ConsumerState<LessonsScreen> createState() => _LessonsScreenState();
}

class _LessonsScreenState extends ConsumerState<LessonsScreen> {
  late final MenuFocus _focus;
  final _scroll = ScrollController();
  late final List<GlobalKey> _keys;

  @override
  void initState() {
    super.initState();
    _focus = MenuFocus(count: builtInLessons.length);
    _keys = [for (var i = 0; i < builtInLessons.length; i++) GlobalKey()];
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

  void _open(int i) {
    final lesson = builtInLessons[i];
    _buzz(HapticPattern.select);
    ref.read(speechProvider).speak('Opening ${lesson.title}.');
    Navigator.of(context).push(resonantRoute(
      LessonModeScreen(lesson: lesson),
      reduce: MediaQuery.of(context).disableAnimations,
    ));
  }

  void _move(int delta) {
    final moved = delta > 0 ? _focus.next() : _focus.previous();
    if (!moved) return;
    setState(() {});
    // The list scrolls to keep the focused card in view.
    final target = _keys[_focus.index].currentContext;
    if (target != null) {
      unawaited(Scrollable.ensureVisible(
        target,
        duration: MediaQuery.of(context).disableAnimations
            ? Duration.zero
            : const Duration(milliseconds: 250),
      ));
    }
    ref.read(speechProvider).speak(builtInLessons[_focus.index].title);
    _buzz(delta > 0 ? HapticPattern.next : HapticPattern.previous);
  }

  void _repeat() {
    ref.read(speechProvider).speak(builtInLessons[_focus.index].title);
  }

  void _holdDelete(int i) {
    final lesson = builtInLessons[i];
    _buzz(HapticPattern.error);
    ref
        .read(speechProvider)
        .speak('${lesson.title} is built in and cannot be deleted.');
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
        _open(_focus.index);
      case Tap(zone: Zone.leftEdge):
        ref.read(speechProvider).stop();
        _buzz(HapticPattern.confirm);
      case DoubleTap(zone: Zone.leftEdge):
        _repeat();
      case LongPress(zone: Zone.rightEdge):
        _buzz(HapticPattern.back);
        ref.read(speechProvider).speak('Back to Home.');
        unawaited(goBack(context, home: const HomeScreen()));
      case LongPress(zone: Zone.center):
        _holdDelete(_focus.index);
      case ThreeFingerTap():
        _repeat();
      case ThreeFingerHold():
        ref.read(speechProvider).speak(
            'Lessons list. Currently focused: ${builtInLessons[_focus.index].title}.');
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
    paintSystemBars(palette.background);
    return Container(
      color: palette.background,
      child: SafeArea(
        child: Column(
          children: [
            LessonsTopBar(
              onBack: () {
                unawaited(goBack(context, home: const HomeScreen()));
              },
              onSettings: () => _openSettings(context),
            ),
            Expanded(
              child: ListShortcuts(
                onMove: _move,
                onActivate: () => _open(_focus.index),
                onBack: () =>
                    unawaited(goBack(context, home: const HomeScreen())),
                child: GestureSurface(
                  twoFingerSwipe: true,
                  ignoreChildGestureAt: _onCard,
                  onGesture: _onGesture,
                  child: SingleChildScrollView(
                    controller: _scroll,
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  child: Column(
                    children: [
                      for (var i = 0; i < builtInLessons.length; i++) ...[
                        if (i > 0) const SizedBox(height: 20),
                        _LessonCard(
                          key: _keys[i],
                          title: builtInLessons[i].title,
                          focused: i == _focus.index,
                          index: i,
                          onTap: () {
                            setState(() => _focus.jumpTo(i));
                            _open(i);
                          },
                          onLongPress: () {
                            setState(() => _focus.jumpTo(i));
                            _holdDelete(i);
                          },
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

/// One lesson: the fitted title, then a full-width "Continue lesson"
/// button. The focused card is the inverted one, as on Settings.
class _LessonCard extends ConsumerWidget {
  const _LessonCard({
    super.key,
    required this.title,
    required this.focused,
    required this.index,
    required this.onTap,
    required this.onLongPress,
  });

  final String title;
  final bool focused;
  final int index;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(paletteProvider);
    final font = ref.watch(fontProvider);
    return Semantics(
      label: focused ? '$title, focused' : title,
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
              // wins the arena over the press visual.
              onTap: onTap,
              onLongPress: onLongPress,
              child: FocusColor(
              target: focused ? palette.ink : palette.card,
              builder: (context, card) => Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: card,
                  borderRadius: cardShape(palette),
                  border: cardBorder(palette),
                ),
                padding:
                    const EdgeInsets.fromLTRB(20, 16, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    FittedTitle(
                      title,
                      color: focused ? palette.onInk : palette.ink,
                    ),
                    const SizedBox(height: 24),
                    Container(
                      constraints: const BoxConstraints(
                          minHeight: minTouchTarget),
                      decoration: BoxDecoration(
                        color:
                            focused ? palette.onInk : palette.button,
                        borderRadius: controlShape(palette),
                        border: controlBorder(palette),
                      ),
                      padding:
                          const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        mainAxisAlignment:
                            MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Text(
                              'Continue lesson',
                              style: TextStyle(
                                fontFamily: font.family,
                                fontWeight: FontWeight.w600,
                                fontSize: 22,
                                color: focused
                                    ? palette.ink
                                    : palette.onButton,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
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
