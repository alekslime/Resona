import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/nav/resonant_nav.dart';
import '../../../core/providers.dart';
import '../../../core/ui/enter.dart';
import '../../../core/ui/resonant_dots.dart';
import '../../../core/ui/system_bars.dart';
import '../../../core/ui/top_bar.dart';
import '../application/chat_session.dart';
import '../application/touch_controller.dart';
import '../domain/region.dart';
import 'ask_pill.dart';
import 'gesture_surface.dart';
import 'home_screen.dart';
import 'pictures_screen.dart';
import 'settings_screen.dart';

/// The voice tutor's chat, ported from Resonant's ChatScreen.
///
/// [recent] is the picture it answers from — the old active material —
/// or null before the first explore, when the shipped lessons answer
/// instead. Empty chat is the hero (dots, greeting, prompt); once there
/// is a conversation the exchange takes the space. "Where is the X?"
/// opens the picture and starts the hunt there.
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key, this.recent});

  final RecentPicture? recent;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  late final ChatSession _session;
  late final ChatHistoryNotifier _history;

  @override
  void initState() {
    super.initState();
    _history = ref.read(chatHistoryProvider.notifier);
    _session = ChatSession(
      repository: ref.read(repositoryProvider),
      speech: ref.read(speechProvider),
      haptics: ref.read(hapticsProvider),
      cues: ref.read(cuesProvider),
      input: ref.read(speechInputProvider),
      recent: widget.recent,
      previous: ref.read(chatHistoryProvider),
      onGuide: _guideTo,
      onBack: () {
        if (mounted) {
          unawaited(goBack(context, home: const HomeScreen()));
        }
      },
      // Every change persists, like the old history store: the
      // conversation survives navigation no matter how the screen dies.
      onChanged: (view) {
        _history.set(view.exchanges);
        if (mounted) setState(() {});
      },
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _session.greet();
    });
  }

  @override
  void dispose() {
    _session.dispose();
    super.dispose();
  }

  void _guideTo(Region region) {
    final recent = widget.recent;
    if (recent == null || !mounted) return;
    final controller = ref.read(touchControllerProvider.notifier);
    controller.openRecent(recent);
    controller.guideTo(region);
    Navigator.of(context).push(resonantRoute(
      const PicturesScreen(),
      reduce: MediaQuery.of(context).disableAnimations,
    ));
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
    final view = _session.view;
    paintSystemBars(palette.background);
    return Container(
      color: palette.background,
      child: SafeArea(
        child: Column(
          children: [
            LessonsTopBar(
              title: 'Chat',
              onBack: () {
                unawaited(goBack(context, home: const HomeScreen()));
              },
              onSettings: () => _openSettings(context),
            ),
            Expanded(
              child: GestureSurface(
                exploreEnabled: false,
                onGesture: _session.handle,
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: view.hero
                      ? _Hero(
                          view: view,
                          fontFamily: font.family,
                          ink: palette.ink,
                        )
                      : _Answer(
                          view: view,
                          fontFamily: font.family,
                          ink: palette.ink,
                        ),
                ),
              ),
            ),
            AskPill(
              listening: view.listening,
              onSubmit: (q) => unawaited(_session.askTyped(q)),
              onMic: () => unawaited(_session.askTapped()),
            ),
          ],
        ),
      ),
    );
  }
}

/// Empty chat: the hero from the design — dots, greeting, prompt. The
/// prompt slot only shows Listening… / Thinking…, and is reserved so the
/// layout doesn't jump.
class _Hero extends StatelessWidget {
  const _Hero({required this.view, required this.fontFamily, required this.ink});

  final ChatView view;
  final String fontFamily;
  final Color ink;

  @override
  Widget build(BuildContext context) {
    final dots = view.listening
        ? DotsState.listening
        : view.thinking
            ? DotsState.thinking
            : DotsState.idle;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: DotsPing(
            state: dots,
            child: ResonantDots(state: dots, size: 240, color: ink),
          ),
        ),
        EnterStagger(
          index: 1,
          child: Text(
            'Hi there!',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: fontFamily,
              fontWeight: FontWeight.w600,
              fontSize: 40,
              height: 48 / 40,
              color: ink,
            ),
          ),
        ),
        SizedBox(
          height: 32,
          child: Center(
            child: view.statusText.isEmpty
                ? null
                : Text(
                    view.statusText,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: fontFamily,
                      fontWeight: FontWeight.w600,
                      fontSize: 17,
                      color: ink,
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}

/// A conversation: your question small and right-aligned, the whole answer
/// big, then the next thing you said (or Listening… / Thinking…) below.
class _Answer extends StatelessWidget {
  const _Answer(
      {required this.view, required this.fontFamily, required this.ink});

  final ChatView view;
  final String fontFamily;
  final Color ink;

  @override
  Widget build(BuildContext context) {
    final index = view.currentExchange;
    final exchange = view.exchanges[index];
    final nextUser = index + 1 < view.exchanges.length
        ? view.exchanges[index + 1].userText
        : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        _UserLine(text: exchange.userText, fontFamily: fontFamily, ink: ink),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: SingleChildScrollView(
              child: Text(
                exchange.sentences.join(' '),
                style: TextStyle(
                  fontFamily: fontFamily,
                  fontWeight: FontWeight.w900,
                  fontSize: 31,
                  height: 35 / 31,
                  color: ink,
                ),
              ),
            ),
          ),
        ),
        _UserLine(
          text:
              view.statusText.isEmpty ? (nextUser ?? '') : view.statusText,
          fontFamily: fontFamily,
          ink: ink,
        ),
      ],
    );
  }
}

/// Small right-aligned line: the user's side of the conversation.
class _UserLine extends StatelessWidget {
  const _UserLine(
      {required this.text, required this.fontFamily, required this.ink});

  final String text;
  final String fontFamily;
  final Color ink;

  @override
  Widget build(BuildContext context) {
    if (text.isEmpty) return const SizedBox.shrink();
    return Align(
      alignment: Alignment.centerRight,
      child: SizedBox(
        width: MediaQuery.of(context).size.width * 0.55,
        child: Text(
          text,
          textAlign: TextAlign.end,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontFamily: fontFamily,
            fontWeight: FontWeight.w600,
            fontSize: 19,
            height: 22 / 19,
            color: ink,
          ),
        ),
      ),
    );
  }
}
