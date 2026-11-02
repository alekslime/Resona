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
import 'chat_screen.dart';
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

/// The old focus gesture: one finger scrolls the menu, a two-finger
/// vertical swipe moves focus. Raw pointer tracking, so it never fights
/// the scrollable for the gesture the way a drag recognizer would.
class _TwoFingerSwipe {
  _TwoFingerSwipe(this.onSwipe);

  final void Function(int delta) onSwipe;
  final _dy = <int, double>{};
  bool _fired = false;

  void down(PointerDownEvent e) {
    _dy[e.pointer] = 0;
    if (_dy.length < 2) _fired = false;
  }

  void move(PointerMoveEvent e) {
    if (!_dy.containsKey(e.pointer) || _fired) return;
    _dy[e.pointer] = _dy[e.pointer]! + e.delta.dy;
    if (_dy.length < 2) return;
    if (_dy.values.where((dy) => dy < -64).length >= 2) {
      _fired = true;
      onSwipe(1);
    } else if (_dy.values.where((dy) => dy > 64).length >= 2) {
      _fired = true;
      onSwipe(-1);
    }
  }

  void up(PointerEvent e) {
    _dy.remove(e.pointer);
    if (_dy.length < 2) _fired = false;
  }
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _focus = MenuFocus(count: _items.length);
  late final _swipe = _TwoFingerSwipe(_move);
  Timer? _exitTimer;

  @override
  void dispose() {
    _exitTimer?.cancel();
    super.dispose();
  }

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
    ref.read(speechProvider).speak(_items[_focus.index].label);
    ref.read(hapticsProvider).play(
        delta > 0 ? HapticPattern.next : HapticPattern.previous);
  }

  @override
  Widget build(BuildContext context) {
    final palette = ref.watch(paletteProvider);
    paintSystemBars(palette.background);
    return Container(
      color: palette.background,
      child: SafeArea(
        child: Listener(
          onPointerDown: _swipe.down,
          onPointerMove: _swipe.move,
          onPointerUp: _swipe.up,
          onPointerCancel: _swipe.up,
          child: Semantics(
            customSemanticsActions: {
              const CustomSemanticsAction(label: 'Next'): () => _move(1),
              const CustomSemanticsAction(label: 'Previous'): () => _move(-1),
            },
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
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
                            label: _items[i].label,
                            focused: i == _focus.index,
                            index: i,
                            onTap: () {
                              setState(() => _focus.jumpTo(i));
                              _open(i);
                            },
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
    required this.label,
    required this.focused,
    required this.index,
    required this.onTap,
  });

  final String label;
  final bool focused;
  final int index;
  final VoidCallback onTap;

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
