import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/env.dart';
import '../../../core/nav/resonant_nav.dart';
import '../../../core/providers.dart';
import '../../../core/ui/enter.dart';
import '../../../core/ui/resonant_controls.dart';
import '../../../core/ui/resonant_dots.dart';
import '../../../core/ui/system_bars.dart';
import '../../../core/ui/top_bar.dart';
import '../application/chat_session.dart';
import '../application/recents.dart';
import '../data/touch_repository.dart';
import 'ask_pill.dart';
import 'camera_sheet.dart';
import 'gesture_guide.dart';
import 'gesture_surface.dart';
import 'home_screen.dart';
import 'live_talk_screen.dart';
import 'settings_screen.dart';

/// The strip under the top bar while the AI server is known to be down:
/// lesson answers, honestly labelled. The transitions are already spoken
/// (the fallback preface on failure, "The AI server is back." on
/// recovery), so this is plain text with no live region — announcing it
/// again would double-speak.
const offlineBanner = 'Offline — answers come from the lessons.';

/// The voice tutor's chat, ported from Resonant's ChatScreen.
///
/// [recent] is the picture it answers from — the old active material —
/// or null before the first explore, when the text tutor answers
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
      quizStore: ref.read(chatQuizStoreProvider),
      quizOffered: ref.read(quizOfferProvider).offered,
      quizDeclined: ref.read(quizOfferProvider).declined,
      onQuizOfferChanged: (offered, declined) {
        ref.read(quizOfferProvider.notifier).set(offered, declined);
      },
      recent: widget.recent,
      previous: ref.read(chatHistoryProvider),

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

  void _openSettings(BuildContext context) {
    Navigator.of(context).push(resonantRoute(
      const SettingsScreen(),
      reduce: MediaQuery.of(context).disableAnimations,
    ));
  }

  Future<void> _openCamera() async {
    final recent = await showCameraSheet(context);
    if (recent == null || !mounted) return;
    _session.attachPicture(recent);
  }

  Future<void> _talkLive() async {
    final recent = _session.recent;
    if (recent == null) return;
    await ref.read(speechProvider).stop();
    try {
      final connection = await ref.read(repositoryProvider).liveVoice(
            title: recent.analysis.title,
            overview: recent.analysis.overview,
          );
      if (!mounted) return;
      Navigator.of(context).push(resonantRoute(
        LiveTalkScreen(connection: connection, title: recent.analysis.title),
        reduce: MediaQuery.of(context).disableAnimations,
      ));
    } on TouchApiException catch (e) {
      ref.read(speechProvider).speak(e.message);
    } catch (_) {
      ref.read(speechProvider).speak('Something went wrong. Try again.');
    }
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
            const FirstVisitGuide(screen: GuideScreen.chat),
            if (view.offline)
              Container(
                width: double.infinity,
                color: palette.bar,
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 10),
                child: Text(
                  offlineBanner,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: font.family,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    color: palette.onBar,
                  ),
                ),
              ),
            Expanded(
              child: GestureSurface(
                onGesture: _session.handle,
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: view.hero
                      ? _Hero(
                          view: view,
                          fontFamily: font.family,
                          ink: palette.ink,
                          name: ref.watch(userNameProvider),
                        )
                      : _Answer(
                          view: view,
                          fontFamily: font.family,
                          ink: palette.ink,
                        ),
                ),
              ),
            ),
            if (Env.liveVoiceEnabled && _session.recent != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
                child: ResonantButton(
                  text: 'Talk live',
                  filled: false,
                  onPressed: _talkLive,
                ),
              ),
            if (view.quizOfferPending ||
                view.quizGenerating ||
                view.quizError.isNotEmpty)
              _QuizOfferBar(
                view: view,
                onYes: () => _session.answerQuizOffer(true),
                onNo: () => _session.answerQuizOffer(false),
                onDismiss: () => _session.dismissQuizError(),
              ),
            AskPill(
              listening: view.listening,
              onSubmit: (q) => unawaited(_session.askTyped(q)),
              onMic: () => unawaited(_session.askTapped()),
              onCamera: _openCamera,
            ),
          ],
        ),
      ),
    );
  }
}

/// The hero greeting, with the daypart: "Good evening, Ana!".
/// Blank names get the generic "there".
String chatGreeting(String? name, {DateTime? now}) {
  final hour = (now ?? DateTime.now()).hour;
  final String daypart;
  if (hour >= 5 && hour < 12) {
    daypart = 'Good morning';
  } else if (hour >= 12 && hour < 18) {
    daypart = 'Good afternoon';
  } else if (hour >= 18 && hour < 23) {
    daypart = 'Good evening';
  } else {
    daypart = 'Good night';
  }
  final who = (name ?? '').trim();
  return '$daypart, ${who.isEmpty ? 'there' : who}!';
}

/// Empty chat: the hero from the design — dots, greeting, prompt. The
/// prompt slot only shows Listening… / Thinking…, and is reserved so the
/// layout doesn't jump.
class _Hero extends StatelessWidget {
  const _Hero(
      {required this.view,
      required this.fontFamily,
      required this.ink,
      required this.name});

  final ChatView view;
  final String fontFamily;
  final Color ink;
  final String? name;

  @override
  Widget build(BuildContext context) {
    final dots = view.listening
        ? DotsState.listening
        : view.thinking
            ? DotsState.thinking
            : DotsState.idle;
    // Centered while it fits, scrollable once the largest text outgrows
    // the screen: the greeting must never clip. One finger already
    // scrolls past the gesture surface, so this stays reachable.
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Column(
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
                  chatGreeting(name),
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
          ),
        ),
      ),
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

/// The quiz offer under the answer: Yes/No buttons while pending, a
/// thinking face while generating, the error with a Dismiss when
/// generation fails. Real buttons outside the gesture surface, like the
/// ask pill, so screen readers reach them.
class _QuizOfferBar extends ConsumerWidget {
  const _QuizOfferBar({
    required this.view,
    required this.onYes,
    required this.onNo,
    required this.onDismiss,
  });

  final ChatView view;
  final VoidCallback onYes;
  final VoidCallback onNo;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(paletteProvider);
    final font = ref.watch(fontProvider);
    final textStyle = TextStyle(
      fontFamily: font.family,
      fontWeight: FontWeight.w600,
      fontSize: 19,
      height: 24 / 19,
      color: palette.ink,
    );
    if (view.quizError.isNotEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              liveRegion: true,
              child: Text(view.quizError, style: textStyle),
            ),
            const SizedBox(height: 8),
            ResonantButton(text: 'Dismiss', onPressed: onDismiss),
          ],
        ),
      );
    }
    if (view.quizGenerating) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
        child: Semantics(
          label: view.statusText.isEmpty
              ? 'Making your quiz'
              : view.statusText,
          child: ExcludeSemantics(
            child: Row(
              children: [
                ResonantDots(
                    state: DotsState.thinking, size: 44, color: palette.ink),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    view.statusText.isEmpty
                        ? 'Making your quiz…'
                        : view.statusText,
                    style: textStyle,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(quizOfferQuestion(view.quizTopic), style: textStyle),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Semantics(
                  label: 'Yes, make the quiz',
                  button: true,
                  child: ResonantButton(text: 'Yes', onPressed: onYes),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Semantics(
                  label: 'No thanks',
                  button: true,
                  child: ResonantButton(
                      text: 'No', filled: false, onPressed: onNo),
                ),
              ),
            ],
          ),
        ],
      ),
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
