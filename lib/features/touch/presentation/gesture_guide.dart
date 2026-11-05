import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/providers.dart';
import '../../../core/theme/shapes.dart';
import '../gestures/gesture_phrases.dart';

/// Screens with a first-visit gesture guide. The splash shows no guide (it
/// has no interaction) and the tutorial IS the guide, so both are absent.
enum GuideScreen {
  home,
  chat,
  camera,
  lessons,
  lessonMode,
  lessonReader,
  quizBrowser,
  quizReader,
  quizResults,
  settings,
  liveTalk,
  nameSetup,
}

/// The per-screen "seen" flag, following the [seenTourKey] pattern.
String guideSeenKey(GuideScreen screen) => 'seen_guide_${screen.name}';

/// Clears every guide flag so each guide shows again on its next visit.
Future<void> resetGuideSeen(SharedPreferences prefs) async {
  for (final screen in GuideScreen.values) {
    await prefs.remove(guideSeenKey(screen));
  }
}

/// True when the global [position] lands inside [key]'s box. Screens whose
/// guide sits inside their GestureSurface add this to their
/// ignoreChildGestureAt, so the Got-it tap does not echo as a center tap.
bool guideContains(GlobalKey key, Offset position) {
  final box = key.currentContext?.findRenderObject() as RenderBox?;
  if (box == null || !box.attached) return false;
  return Rect.fromPoints(
    box.localToGlobal(Offset.zero),
    box.localToGlobal(box.size.bottomRight(Offset.zero)),
  ).contains(position);
}

/// The shared grammar line: the edges, back and orientation work the same
/// on every gesture screen, so every guide ends with it.
const _edges =
    'Left edge taps control speech, holding the right edge goes back, '
    'and three fingers tell you where you are.';

/// The gestures [screen] actually handles, in short lines built from
/// [GesturePhrases] — never hardcoded directions. Button-only screens get
/// button words instead of gestures.
List<String> guideLines(GuideScreen screen,
    [GesturePhrases phrases = const GesturePhrases()]) {
  final next = phrases.swipeNext();
  final prevWord = phrases.previousWord;
  final next2 = phrases.swipeNext(twoFinger: true);
  switch (screen) {
    case GuideScreen.home:
      return [
        '$next2 to move to the next line, swipe $prevWord to go back. '
            'One finger only scrolls.',
        'Tap the center to open the focused line.',
        _edges,
      ];
    case GuideScreen.chat:
      return [
        '$next to hear the next sentence, swipe $prevWord to go back.',
        'Tap the center to ask by voice, or type below.',
        'The camera button below adds a picture.',
        _edges,
      ];
    case GuideScreen.camera:
      return [
        'Take a photo, choose from the gallery, or try a sample. '
            'Tap one to attach it.',
      ];
    case GuideScreen.lessons:
      return [
        '$next2 to move to the next lesson, swipe $prevWord to go back.',
        'Tap the center to open the focused lesson.',
        _edges,
      ];
    case GuideScreen.lessonMode:
      return [
        '$next to move between Manual and Auto, swipe $prevWord to go back.',
        'Tap the center to choose.',
        _edges,
      ];
    case GuideScreen.lessonReader:
      return [
        '$next2 to hear the next sentence, swipe $prevWord to go back.',
        'Swipe ${phrases.rightWord} to jump to the next section, '
            '${phrases.leftWord} to go back.',
        'In Manual, tap the center for the next sentence.',
        _edges,
      ];
    case GuideScreen.quizBrowser:
      return [
        '$next2 to move to the next quiz, swipe $prevWord to go back.',
        'Tap the center to open the focused quiz.',
        _edges,
      ];
    case GuideScreen.quizReader:
      return [
        '$next to see the next option, swipe $prevWord to go back.',
        'Tap the center to choose, swipe ${phrases.submitWord} to submit.',
        _edges,
      ];
    case GuideScreen.quizResults:
      return [
        'Tap the center to go back.',
        'The buttons retry the missed questions or copy your score.',
        _edges,
      ];
    case GuideScreen.settings:
      return [
        '$next2 to move to the next row, swipe $prevWord to go back.',
        'Tap the center to change the focused row.',
        'Hold a theme, font or size row, swipe ${phrases.leftWord} or '
            '${phrases.rightWord} to preview, tap to keep.',
        _edges,
      ];
    case GuideScreen.liveTalk:
      return [
        'Just talk. Starting to speak interrupts the tutor.',
        'Mute and End talk are buttons below.',
      ];
    case GuideScreen.nameSetup:
      return [
        'Type your first name, then Save.',
      ];
  }
}

/// The guide as one spoken line.
String guideSpoken(GuideScreen screen,
        [GesturePhrases phrases = const GesturePhrases()]) =>
    guideLines(screen, phrases).join(' ');

/// The first-visit banner for [screen]: spoken AND shown, once per device.
///
/// An inline card, never a dialog, so screen-reader focus cannot trap: the
/// text is already spoken aloud, so screen readers skip it, and a real
/// Got-it button dismisses. Shown flags live in shared preferences next to
/// [seenTourKey]; Settings replays every guide.
class FirstVisitGuide extends ConsumerStatefulWidget {
  const FirstVisitGuide({super.key, required this.screen});

  final GuideScreen screen;

  @override
  ConsumerState<FirstVisitGuide> createState() => _FirstVisitGuideState();
}

class _FirstVisitGuideState extends ConsumerState<FirstVisitGuide> {
  bool _show = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final prefs = ref.read(sharedPreferencesProvider);
      if (prefs.getBool(guideSeenKey(widget.screen)) ?? false) return;
      // Marked shown as it appears, like the tutorial: a dismissed guide
      // must not re-trigger, and Settings replays guides any time.
      await prefs.setBool(guideSeenKey(widget.screen), true);
      if (!mounted) return;
      ref.read(speechProvider).speak(guideSpoken(widget.screen), queue: true);
      setState(() => _show = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_show) return const SizedBox.shrink();
    final palette = ref.watch(paletteProvider);
    final font = ref.watch(fontProvider);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Container(
        decoration: BoxDecoration(
          color: palette.card,
          borderRadius: cardShape(palette),
          border: cardBorder(palette),
        ),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ExcludeSemantics(
              // Already spoken, so TalkBack skips it (see the quiz reader).
              child: Text(
                guideLines(widget.screen).join('\n'),
                style: TextStyle(
                  fontFamily: font.family,
                  fontWeight: FontWeight.w600,
                  fontSize: 17,
                  height: 23 / 17,
                  color: palette.ink,
                ),
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => setState(() => _show = false),
                child: Text(
                  'Got it',
                  style: TextStyle(
                    fontFamily: font.family,
                    fontWeight: FontWeight.w600,
                    fontSize: 17,
                    color: palette.ink,
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
