/// The menu home screen, ported from Resonant's HomeScreen.
///
/// A fixed brand surface — flat theme background, matching the splash it
/// visually continues from. Seven big lines; the focused one draws in ink and
/// the rest in dim. A tap opens the item; a swipe moves focus and speaks it.
///
/// Our menu holds our features where the old one held its own (Talk first,
/// because the voice tutor is the point; Pictures second; no Profile, which
/// our backend has no data for). Talk, Lessons, Quiz and Notes hang off the
/// last explored picture, like old Chat answering from the material opened
/// last; with no picture yet they say so and send you to Pictures.
///
/// (The text-size cap and the full gesture grammar arrive with Settings.)
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
import '../../../core/ui/enter.dart';
import '../../../core/ui/focus_fade.dart';
import '../../../core/ui/system_bars.dart';
import '../application/touch_controller.dart';
import '../data/touch_repository.dart';
import '../domain/region.dart';
import 'live_talk_screen.dart';
import 'pictures_screen.dart';
import 'settings_screen.dart';
import 'study_notes_screen.dart';

/// Opens a live room about [analysis]: the Talk destination.
Future<LiveVoiceConnection> openTalkConnection(
  TouchRepository repo,
  Analysis analysis,
) =>
    repo.liveVoice(title: analysis.title, overview: analysis.overview);

class _HomeItem {
  const _HomeItem(this.label, this.route);

  final String label;
  final String route;
}

const _items = [
  _HomeItem('Talk', Routes.talk),
  _HomeItem('Pictures', Routes.pictures),
  _HomeItem('Lessons', Routes.lessons),
  _HomeItem('Quiz', Routes.quiz),
  _HomeItem('Notes', Routes.notes),
  _HomeItem('Settings', Routes.settings),
  _HomeItem('Quit', Routes.quit),
];

String _activityFor(String route) => switch (route) {
      Routes.talk => 'talk',
      Routes.lessons => 'study',
      Routes.quiz => 'quiz',
      _ => 'revise',
    };

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _focus = MenuFocus(count: _items.length);
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

  bool _needsContext(String route) =>
      route == Routes.talk ||
      route == Routes.lessons ||
      route == Routes.quiz ||
      route == Routes.notes;

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
          'Explore a picture first, then come back to ${_activityFor(item.route)}.');
      _push(const PicturesScreen());
      return;
    }
    ref.read(speechProvider).speak('Opening ${item.label}.');
    switch (item.route) {
      case Routes.pictures:
        _push(const PicturesScreen());
      case Routes.talk:
        final last = _last!;
        final connection = await openTalkConnection(
          ref.read(repositoryProvider),
          last.analysis,
        );
        if (mounted) {
          _push(LiveTalkScreen(
            connection: connection,
            title: last.analysis.title,
          ));
        }
      case Routes.lessons:
      case Routes.quiz:
        final last = _last!;
        final controller = ref.read(touchControllerProvider.notifier);
        controller.openRecent(last);
        if (item.route == Routes.lessons) {
          await controller.startLesson();
        } else {
          await controller.startQuiz();
        }
        if (mounted) _push(const PicturesScreen());
      case Routes.notes:
        _push(StudyNotesScreen(analysis: _last!.analysis));
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
        child: GestureDetector(
          onVerticalDragEnd: (details) {
            final velocity = details.primaryVelocity ?? 0;
            if (velocity == 0) return;
            _move(velocity < 0 ? 1 : -1);
          },
          child: Semantics(
            customSemanticsActions: {
              const CustomSemanticsAction(label: 'Next'): () => _move(1),
              const CustomSemanticsAction(label: 'Previous'): () => _move(-1),
            },
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
