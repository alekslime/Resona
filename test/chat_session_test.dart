import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:resonant/features/learn/domain/library.dart';
import 'package:resonant/features/learn/domain/sentences.dart';
import 'package:resonant/features/touch/application/chat_session.dart';
import 'package:resonant/features/touch/application/recents.dart';
import 'package:resonant/features/touch/data/touch_repository.dart';
import 'package:resonant/features/touch/domain/guide_match.dart';
import 'package:resonant/features/touch/domain/region.dart';
import 'package:resonant/features/touch/gestures/gesture_types.dart';

import 'fakes.dart';

Region makeRegion(String id, String label, int order) => Region(
      id: id,
      order: order,
      label: label,
      spoken: label,
      detail: '',
      left: 0,
      top: 0,
      right: 10,
      bottom: 10,
      maskW: 1,
      maskH: 1,
      bits: Uint8List.fromList([1]),
      area: 1,
      areaFrac: 0.01,
    );

Analysis lungsAnalysis() => Analysis(
      width: 100,
      height: 100,
      title: 'Lungs',
      kind: 'diagram',
      overview: '',
      regions: [makeRegion('a', 'left lung', 0), makeRegion('b', 'right lung', 1)],
    );

RecentPicture lungsRecent() => RecentPicture(
      analysis: lungsAnalysis(),
      picture: tinyPicture,
      openedAt: DateTime(2026),
    );

RecentPicture sunRecent() => RecentPicture(
      analysis: loadSample(),
      picture: tinyPicture,
      openedAt: DateTime(2026),
    );

/// A tutor that answers only when the test says so.
class GatedRepo extends FakeRepository {
  GatedRepo(super.log);
  Completer<String> gate = Completer<String>();

  @override
  Future<String> chat(
    PictureBytes picture, {
    required String question,
    required String title,
    String regionLabel = '',
    List<({String q, String a})> history = const [],
  }) async {
    log.events.add('ask:$question|$regionLabel|past:${history.length}');
    return gate.future;
  }
}

class Rig {
  Rig(this.log, this.session, this.input, this.guided, this.backs);
  final Log log;
  final ChatSession session;
  final FakeInput input;
  final List<Region> guided;
  final List<bool> backs;
}

Rig rig({
  TouchRepository? repo,
  String heard = 'what is this?',
  bool micAvailable = true,
  RecentPicture? recent,
  List<ChatExchange> previous = const [],
  Duration tick = const Duration(seconds: 2),
  Duration spokenFor = const Duration(seconds: 10),
}) {
  final log = Log();
  final guided = <Region>[];
  final backs = <bool>[];
  final input = FakeInput(log, heard: heard, available: micAvailable);
  final session = ChatSession(
    repository: repo ?? FakeRepository(log),
    speech: FakeSpeech(log),
    haptics: FakeHaptics(log),
    cues: FakeCues(log),
    input: input,
    recent: recent,
    previous: previous,
    onGuide: guided.add,
    onBack: () => backs.add(true),
    thinkingTick: tick,
    thinkingSpokenEvery: spokenFor,
  );
  addTearDown(session.dispose);
  return Rig(log, session, input, guided, backs);
}

/// Let an unawaited ask run until it parks (on the mic or the model).
Future<void> flushAsk() => Future<void>.delayed(Duration.zero);

void main() {
  group('sentences', () {
    test('splits on terminators followed by space, keeps punctuation', () {
      expect(splitSentences('First. Second? Third!'), [
        'First.',
        'Second?',
        'Third!',
      ]);
    });

    test('keeps decimals, abbreviations and list numbers whole', () {
      expect(splitSentences('It is 3.5 degrees. Really.'), [
        'It is 3.5 degrees.',
        'Really.',
      ]);
      expect(splitSentences('See Dr. Smith today. Please.'), [
        'See Dr. Smith today.',
        'Please.',
      ]);
      expect(splitSentences('1. First step. 2. Second step.'), [
        '1. First step.',
        '2. Second step.',
      ]);
    });

    test('a closing quote belongs to the sentence it closes', () {
      expect(splitSentences('He said "no." Then he left.'), [
        'He said "no."',
        'Then he left.',
      ]);
    });

    test('strips markdown and collapses whitespace', () {
      expect(splitSentences('  **Bold**   answer.  Next.'),
          ['Bold answer.', 'Next.']);
    });
  });

  group('chat session', () {
    test('greets a fresh chat', () {
      final r = rig();
      r.session.greet();
      expect(
        r.log.events,
        contains(
            'say: Ask Resonant. Tap the center of the screen to ask a question.'),
      );
      expect(r.session.view.hero, isTrue);
    });

    test('greets a returning chat with its history', () {
      final r = rig(previous: const [
        ChatExchange('q1', ['a1.']),
        ChatExchange('q2', ['a2.']),
      ]);
      r.session.greet();
      expect(
        r.log.events,
        contains(
          'say: Ask Resonant. You have 2 previous exchanges from before. '
          'Swipe up or down to review them, or tap center to ask something new.',
        ),
      );
      expect(r.session.view.exchanges, hasLength(2));
    });

    test('trims loaded history to the recent past', () {
      final r = rig(previous: [
        for (var i = 0; i < 25; i++) ChatExchange('q$i', ['a$i.']),
      ]);
      r.session.greet();
      expect(r.session.view.exchanges, hasLength(20));
      expect(r.session.view.exchanges.first.userText, 'q5');
    });

    test('a typed question asks the tutor and speaks the answer', () async {
      final r = rig(recent: sunRecent());
      await r.session.askTyped('what is this?');
      expect(r.log.events, contains('haptic:confirm'));
      expect(r.log.events, contains('say: Thinking.'));
      expect(r.log.events, contains('ask:what is this?||past:0'));
      expect(r.log.events, contains('say: It is the sun.'));
      expect(r.session.view.exchanges, hasLength(1));
      expect(r.session.view.thinking, isFalse);
    });

    test('later sentences queue behind the first', () async {
      final log = Log();
      final repo = FakeRepository(log, answer: 'First. Second. Third.');
      final r = rig(repo: repo, recent: sunRecent());
      await r.session.askTyped('go');
      expect(r.log.events, contains('say: First.'));
      expect(r.log.events, contains('say+: Second.'));
      expect(r.log.events, contains('say+: Third.'));
    });

    test('every question carries the conversation so far', () async {
      final r = rig(recent: sunRecent());
      await r.session.askTyped('one');
      await r.session.askTyped('two');
      expect(r.log.events, contains('ask:two||past:1'));
    });

    test('a barge-in drops the stale answer', () async {
      final log = Log();
      final repo = GatedRepo(log);
      final r = rig(repo: repo, recent: sunRecent());
      unawaited(r.session.askTyped('first'));
      await flushAsk();
      unawaited(r.session.askTyped('second'));
      await flushAsk();
      repo.gate.complete('Late answer.');
      await flushAsk();
      expect(r.session.view.exchanges, hasLength(1));
      expect(r.session.view.exchanges.single.userText, 'second');
    });

    test('tapping while thinking cancels the wait', () async {
      final log = Log();
      final repo = GatedRepo(log);
      final r = rig(repo: repo, recent: sunRecent());
      unawaited(r.session.askTyped('go'));
      await flushAsk();
      await r.session.askTapped();
      expect(
        r.log.events,
        contains('say: Cancelled. Tap the center to ask again.'),
      );
      repo.gate.complete('Late answer.');
      await Future<void>.delayed(Duration.zero);
      expect(r.session.view.exchanges, isEmpty);
      expect(
        r.log.events.where((e) => e.contains('Late answer.')),
        isEmpty,
      );
    });

    test('a slow answer pulses, then says so', () async {
      final log = Log();
      final repo = GatedRepo(log);
      final r = rig(
        repo: repo,
        recent: sunRecent(),
        tick: const Duration(milliseconds: 10),
        spokenFor: const Duration(milliseconds: 30),
      );
      unawaited(r.session.askTyped('go'));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(r.log.events, contains('haptic:thinking'));
      expect(
        r.log.events,
        contains('say: Still thinking. Tap the center to cancel.'),
      );
      repo.gate.complete('Done.');
      await Future<void>.delayed(Duration.zero);
    });

    test('without a picture, the text tutor answers', () async {
      final r = rig();
      await r.session.askTyped('what is the capital of France?');
      expect(
        r.log.events,
        contains('ask:what is the capital of France?||past:0'),
      );
      expect(r.log.events, contains('say: It is the sun.'));
      expect(r.session.view.exchanges, hasLength(1));
      expect(r.session.view.offline, isFalse);
    });

    test('without a picture and no server, the lessons step in', () async {
      final log = Log();
      final repo = FakeRepository(log)..fail = TouchApiException('Down.');
      final r = rig(repo: repo);
      await r.session.askTyped('matters');
      expect(r.session.view.offline, isTrue);
      expect(
        r.log.events,
        contains(
            "say: I can't reach the AI server, so this is from the lesson."),
      );
    });

    test('the first answer without a picture points at Pictures, once',
        () async {
      final r = rig();
      await r.session.askTyped('matters');
      await r.session.askTyped('matters');
      expect(
        r.log.events.where((e) =>
            e == 'say+: Open a picture in Pictures, and I can answer about that too.'),
        hasLength(1),
      );
    });

    test('when the server fails, the lessons step in', () async {
      final log = Log();
      final repo = FakeRepository(log)..fail = TouchApiException('Down.');
      final r = rig(repo: repo, recent: sunRecent());
      await r.session.askTyped('matters');
      expect(
        r.log.events,
        contains(
            "say: I can't reach the AI server, so this is from the lesson."),
      );
    });

    test('a failed answer marks the chat offline', () async {
      final log = Log();
      final repo = FakeRepository(log)..fail = TouchApiException('Down.');
      final r = rig(repo: repo, recent: sunRecent());
      expect(r.session.view.offline, isFalse);
      await r.session.askTyped('matters');
      expect(r.session.view.offline, isTrue);
    });

    test('a text answer without a picture is not offline', () async {
      final r = rig();
      await r.session.askTyped('matters');
      expect(r.session.view.offline, isFalse);
    });

    test('a fresh answer after a failure says the server is back', () async {
      final log = Log();
      final repo = FakeRepository(log,
          answer: 'It is the sun.',)..fail = TouchApiException('Down.');
      final r = rig(repo: repo, recent: sunRecent());
      await r.session.askTyped('matters');
      expect(r.session.view.offline, isTrue);
      repo.fail = null;
      await r.session.askTyped('what is this?');
      expect(r.session.view.offline, isFalse);
      final events = r.log.events;
      expect(events, contains('say: The AI server is back.'));
      // The news cuts in first; the answer queues behind it.
      expect(
        events.indexOf('say: The AI server is back.'),
        lessThan(events.indexOf('say+: It is the sun.')),
      );
      // Spoken, not stored: the exchange keeps the model's own answer.
      expect(r.session.view.exchanges.last.sentences, ['It is the sun.']);
    });

    test('xyzzy is answered locally and never reaches the server', () async {
      final repoLog = Log();
      final repo = FakeRepository(repoLog);
      final r = rig(repo: repo, recent: sunRecent());
      await r.session.askTyped(' Xyzzy ');
      expect(repoLog.events, isEmpty);
      expect(r.session.view.exchanges.last.sentences, ['Nothing happens.']);
      expect(r.log.events, contains('say: Nothing happens.'));
    });

    test('tapping twice asks by voice', () async {
      final r = rig(recent: sunRecent());
      await r.session.askTapped();
      expect(r.log.events, contains('haptic:listening'));
      expect(r.log.events, contains('say: Listening.'));
      expect(r.log.events, contains('mic:start'));
      expect(r.session.view.listening, isTrue);
      await r.session.askTapped();
      expect(r.log.events, contains('mic:stop'));
      expect(
        r.log.events,
        contains('say: You said: what is this?. Thinking.'),
      );
      expect(r.log.events, contains('ask:what is this?||past:0'));
    });

    test('a missing microphone says so', () async {
      final r = rig(micAvailable: false);
      await r.session.askTapped();
      expect(
        r.log.events,
        contains('say: Microphone permission is needed to ask a question.'),
      );
      expect(r.log.events, contains('haptic:error'));
      expect(r.session.view.listening, isFalse);
    });

    test('silence is admitted, not asked about', () async {
      final r = rig(heard: '  ', recent: sunRecent());
      await r.session.askTapped();
      await r.session.askTapped();
      expect(r.log.events, contains('say: I did not catch that.'));
      expect(
        r.log.events.where((e) => e.startsWith('ask:')),
        isEmpty,
      );
    });

    test('swipes walk the sentences', () async {
      final log = Log();
      final repo = FakeRepository(log, answer: 'First. Second. Third.');
      final r = rig(repo: repo, recent: sunRecent());
      await r.session.askTyped('go');
      log.events.clear();
      r.session.handle(const Swipe(Zone.center, SwipeDirection.up));
      expect(r.log.events, contains('say: Second.'));
      expect(r.log.events, contains('haptic:next'));
      r.session.handle(const Swipe(Zone.center, SwipeDirection.up));
      expect(r.log.events, contains('say: Third.'));
      r.session.handle(const Swipe(Zone.center, SwipeDirection.up));
      expect(r.log.events, contains('haptic:edge'));
      r.session.handle(const Swipe(Zone.center, SwipeDirection.down));
      expect(r.log.events, contains('say: Second.'));
      expect(r.log.events, contains('haptic:previous'));
    });

    test('the edges stop, repeat and go back', () async {
      final log = Log();
      final repo = FakeRepository(log, answer: 'First. Second.');
      final r = rig(repo: repo, recent: sunRecent());
      await r.session.askTyped('go');
      log.events.clear();
      r.session.handle(const Tap(Zone.leftEdge));
      expect(r.log.events, contains('stop'));
      expect(r.log.events, contains('haptic:confirm'));
      r.session.handle(const DoubleTap(Zone.leftEdge));
      expect(r.log.events, contains('say: First.'));
      r.session.handle(const LongPress(Zone.rightEdge));
      expect(r.log.events, contains('say: Back to Home.'));
      expect(r.backs, hasLength(1));
    });

    test('repeating an empty chat stays silent', () {
      final r = rig();
      r.session.handle(const ThreeFingerTap());
      expect(r.log.events, isEmpty);
    });

    test('three fingers describe the chat', () async {
      final r = rig(recent: sunRecent());
      r.session.handle(const ThreeFingerHold());
      expect(
        r.log.events,
        contains(
            'say: AI Chat. Tap the center of the screen to ask a question.'),
      );
      await r.session.askTyped('go');
      r.session.handle(const ThreeFingerHold());
      expect(
        r.log.events,
        contains(
            'say: AI Chat, exchange 1 of 1. Tap center to ask another question.'),
      );
    });

    test('the hold drag retunes the voice', () {
      final r = rig();
      r.session.handle(const HoldSpeedUp());
      expect(r.log.events, contains('say: Faster.'));
      expect(r.log.events, contains('haptic:speedUp'));
      r.session.handle(const HoldSpeedDown());
      r.session.handle(const HoldSpeedDown());
      expect(r.log.events, contains('say: Slower.'));
    });

    test('unused gestures are ignored', () {
      final r = rig();
      r.session.handle(const ExploreMove(1, 2));
      r.session.handle(const Tap(Zone.rightEdge));
      expect(r.log.events, isEmpty);
    });

    test('where-is hands the hunt to the picture', () async {
      final r = rig(heard: 'where is the sun', recent: sunRecent());
      await r.session.askTapped();
      await r.session.askTapped();
      expect(
        r.log.events,
        contains('say: Opening the picture to guide you to the sun.'),
      );
      expect(r.guided.map((g) => g.label), ['sun']);
      expect(
        r.log.events.where((e) => e.startsWith('ask:')),
        isEmpty,
      );
    });

    test('a close pair asks, then takes the first', () async {
      final r = rig(heard: 'where is the lung?', recent: lungsRecent());
      await r.session.askTapped();
      await r.session.askTapped();
      expect(
        r.log.events,
        contains('say: Did you mean left lung or right lung?'),
      );
      r.input.heard = 'the first one';
      await r.session.askTapped();
      await r.session.askTapped();
      expect(r.guided.map((g) => g.label), ['left lung']);
    });

    test('an open did-you-mean lasts exactly one answer', () async {
      final r = rig(heard: 'where is the lung?', recent: lungsRecent());
      await r.session.askTapped();
      await r.session.askTapped();
      r.input.heard = 'what is this?';
      await r.session.askTapped();
      await r.session.askTapped();
      expect(r.guided, isEmpty);
      expect(r.log.events, contains('ask:what is this?||past:0'));
    });

    test('disposing silences the ticker', () async {
      final log = Log();
      final repo = GatedRepo(log);
      final r = rig(
        repo: repo,
        recent: sunRecent(),
        tick: const Duration(milliseconds: 10),
        spokenFor: const Duration(milliseconds: 30),
      );
      unawaited(r.session.askTyped('go'));
      await flushAsk();
      r.session.dispose();
      r.log.events.clear();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(r.log.events, isEmpty);
      repo.gate.complete('Late.');
      await Future<void>.delayed(Duration.zero);
    });
  });

  group('guide pick', () {
    test('first, second, letters and names resolve', () {
      final first = makeRegion('a', 'left lung', 0);
      final second = makeRegion('b', 'right lung', 1);
      expect(resolveGuidePick(first, second, 'the first one'), 0);
      expect(resolveGuidePick(first, second, 'second'), 1);
      expect(resolveGuidePick(first, second, 'A'), 0);
      expect(resolveGuidePick(first, second, 'option b'), 1);
      expect(resolveGuidePick(first, second, 'the right lung'), 1);
      expect(resolveGuidePick(first, second, 'the lung'), isNull);
      expect(resolveGuidePick(first, second, 'left lung right lung'), isNull);
    });
  });
}
