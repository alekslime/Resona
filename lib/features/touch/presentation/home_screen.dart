/// The menu home screen, ported from Resonant's HomeScreen.
///
/// A fixed brand surface — flat theme background, matching the splash it
/// visually continues from. Eight big lines; the focused one draws in ink and
/// the rest in dim. A tap opens the item; a two-finger swipe moves focus and
/// speaks it, while one finger only scrolls.
///
/// The old menu (Chat, Lessons, Quiz, Profile, Settings, Quit) plus our two
/// picture children: Pictures, where a finger explores, and Notes, the study
/// notes it leaves behind. Chat and Notes hang off the last explored
/// picture, like old Chat answering from the material opened last; Chat
/// without a picture still talks, while Notes sends you to Pictures first.
///
/// Menu words are huge already, so the text size stops at 1.2x here.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/nav/menu_focus.dart';
import '../../../core/nav/resonant_nav.dart';
import '../../../core/providers.dart';
import '../../../core/services/haptics.dart';
import '../../../core/theme/motion.dart';
import '../../../core/ui/capped_text.dart';
import '../../../core/ui/enter.dart';
import '../../../core/ui/focus_fade.dart';
import '../../../core/ui/system_bars.dart';
import '../application/touch_controller.dart';
import '../gestures/gesture_types.dart';
import 'chat_screen.dart';
import 'gesture_surface.dart';
import 'lessons_screen.dart';
import 'pictures_screen.dart';
import 'profile_screen.dart';
import 'quiz_browser_screen.dart';
import 'settings_screen.dart';
import 'study_notes_screen.dart';

class _HomeItem {
  const _HomeItem(this.label, this.route);

  final String label;
  final String route;
}

const _items = [
  _HomeItem('Chat', Routes.chat),
  _HomeItem('Lessons', Routes.lessons),
  _HomeItem('Quiz', Routes.quiz),
  _HomeItem('Pictures', Routes.pictures),
  _HomeItem('Notes', Routes.notes),
  _HomeItem('Profile', Routes.profile),
  _HomeItem('Settings', Routes.settings),
  _HomeItem('Quit', Routes.quit),
];

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _focus = MenuFocus(count: _items.length);
  final _scroll = ScrollController();
  late final List<GlobalKey> _keys = [
    for (var i = 0; i < _items.length; i++) GlobalKey()
  ];
  Timer? _exitTimer;

  @override
  void dispose() {
    _exitTimer?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  /// A tap the menu lines took themselves: the surface drops its echo.
  bool _onItem(Offset position) => _keys.any((k) {
        final box = k.currentContext?.findRenderObject() as RenderBox?;
        if (box == null || !box.attached) return false;
        return Rect.fromPoints(
          box.localToGlobal(Offset.zero),
          box.localToGlobal(box.size.bottomRight(Offset.zero)),
        ).contains(position);
      });

  bool get _reduce => MediaQuery.of(context).disableAnimations;

  void _push(Widget screen) {
    Navigator.of(context).push(resonantRoute(screen, reduce: _reduce));
  }

  /// The picture everything hangs off, or null before the first explore.
  RecentPicture? get _last {
    final recents = ref.read(touchControllerProvider).recents;
    return recents.isEmpty ? null : recents.first;
  }

  bool _needsContext(String route) => route == Routes.notes;

  Future<void> _open(int i) async {
    final item = _items[i];
    ref.read(hapticsProvider).play(HapticPattern.select);
    if (item.route == Routes.quit) {
      ref.read(speechProvider).speak('Exiting Resonant.');
      // The spoken confirmation is already playing, so the finish waits a
      // beat to let it land.
      _exitTimer?.cancel();
      _exitTimer = Timer(const Duration(milliseconds: 900), () {
        SystemNavigator.pop();
      });
      return;
    }
    if (_needsContext(item.route) && _last == null) {
      ref.read(speechProvider).speak(
          'Explore a picture first, then come back to revise.');
      _push(const PicturesScreen());
      return;
    }
    ref.read(speechProvider).speak('Opening ${item.label}.');
    switch (item.route) {
      case Routes.chat:
        _push(ChatScreen(recent: _last));
      case Routes.lessons:
        _push(const LessonsScreen());
      case Routes.quiz:
        _push(const QuizBrowserScreen());
      case Routes.pictures:
        _push(const PicturesScreen());
      case Routes.notes:
        _push(StudyNotesScreen(analysis: _last!.analysis));
      case Routes.profile:
        _push(const ProfileScreen());
      case Routes.settings:
        _push(const SettingsScreen());
    }
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
    ref.read(speechProvider).speak(_items[_focus.index].label);
    _buzz(delta > 0 ? HapticPattern.next : HapticPattern.previous);
  }

  void _buzz(HapticPattern pattern) {
    ref.read(hapticsProvider).play(pattern);
    ref.read(cuesProvider).play(pattern);
  }

  void _repeat() {
    ref.read(speechProvider).speak(_items[_focus.index].label);
  }

  /// A hold that started on a menu line: the surface drops holds on
  /// rows, so the row reports it. A right-edge hold says you are
  /// already home; anywhere else the hold just swallows the tap.
  void _rowHold(Offset position) {
    final width = MediaQuery.of(context).size.width;
    if (position.dx > width - 64) {
      _buzz(HapticPattern.back);
      ref
          .read(speechProvider)
          .speak('You are already on the Home screen.');
    }
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
        ref
            .read(speechProvider)
            .speak('You are already on the Home screen.');
      case ThreeFingerTap():
        _repeat();
      case ThreeFingerHold():
        ref.read(speechProvider).speak(
            'You are on the Home screen. Currently focused: ${_items[_focus.index].label}.');
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

  @override
  Widget build(BuildContext context) {
    final palette = ref.watch(paletteProvider);
    paintSystemBars(palette.background);
    return Container(
      color: palette.background,
      child: SafeArea(
        child: GestureSurface(
          exploreEnabled: false,
          twoFingerSwipe: true,
          ignoreChildGestureAt: _onItem,
          onGesture: _onGesture,
          child: Semantics(
            customSemanticsActions: {
              const CustomSemanticsAction(label: 'Next'): () => _move(1),
              const CustomSemanticsAction(label: 'Previous'): () => _move(-1),
            },
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                controller: _scroll,
                // Eight lines at this size do not fit every phone: one finger
                // scrolls when they overflow, and a two-finger swipe moves
                // focus whether they fit or not.
                child: ConstrainedBox(
                  constraints:
                      BoxConstraints(minHeight: constraints.maxHeight),
                  child: CappedText(
                    max: 1.2,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (var i = 0; i < _items.length; i++)
                          _MenuItem(
                            key: _keys[i],
                            label: _items[i].label,
                            focused: i == _focus.index,
                            index: i,
                            onTap: () {
                              setState(() => _focus.jumpTo(i));
                              _open(i);
                            },
                            onHold: _rowHold,
                          ),
                      ],
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

class _MenuItem extends ConsumerWidget {
  const _MenuItem({
    super.key,
    required this.label,
    required this.focused,
    required this.index,
    required this.onTap,
    required this.onHold,
  });

  final String label;
  final bool focused;
  final int index;
  final VoidCallback onTap;
  final void Function(Offset position) onHold;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(paletteProvider);
    final font = ref.watch(fontProvider);
    return EnterStagger(
      index: index,
      child: FocusLift(
        focused: focused,
        amount: 1.06,
        themeFloor: MotionProfiles.forTheme(palette.id).minDamping,
        child: FocusColor(
          target: focused ? palette.ink : palette.dim,
          builder: (context, color) => Semantics(
            label: focused ? '$label, focused' : label,
            button: true,
            onTap: onTap,
            child: ExcludeSemantics(
              child: GestureDetector(
                onTap: onTap,
                onLongPressStart: (d) => onHold(d.globalPosition),
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: font.family,
                    fontWeight: FontWeight.w900,
                    fontSize: 60,
                    height: 83 / 60,
                  ).copyWith(color: color),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
