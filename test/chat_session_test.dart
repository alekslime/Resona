import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:resonant/features/learn/domain/library.dart';
import 'package:resonant/features/learn/domain/sentences.dart';
import 'package:resonant/features/touch/application/chat_session.dart';
import 'package:resonant/features/touch/application/recents.dart';
import 'package:resonant/features/touch/data/touch_repository.dart';

import 'package:resonant/features/touch/gestures/gesture_types.dart';

import 'fakes.dart';

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
    void Function()? onSlow,
  }) async {
    log.events.add('ask:$question|$regionLabel|past:${history.length}');
    return gate.future;
  }
}

/// A tutor that reports a slow server, then answers.
class SlowRepo extends FakeRepository {
  SlowRepo(super.log);

  @override
  Future<String> chatText({
    required String question,
    List<({String q, String a})> history = const [],
    void Function()? onSlow,
  }) async {
    onSlow?.call();
    return super.chatText(question: question, history: history);
  }
}

/// A quiz maker that reports a slow server, then generates.
class SlowQuizRepo extends FakeRepository {
  SlowQuizRepo(super.log);

  @override
  Future<GeneratedQuiz> quiz({
    required String topic,
    List<({String q, String a})> history = const [],
    void Function()? onSlow,
  }) async {
    onSlow?.call();
    return super.quiz(topic: topic, history: history);
  }
}

class Rig {
  Rig(this.log, this.session, this.input, this.backs, this.store,
      this.offerStates);
  final Log log;
  final ChatSession session;
  final FakeInput input;
  final List<bool> backs;
  final FakeChatQuizStore store;
  final List<(bool, bool)> offerStates;
}

Rig rig({
  TouchRepository? repo,
  String heard = 'what is this?',
  bool micAvailable = true,
  RecentPicture? recent,
  List<ChatExchange> previous = const [],
  Duration tick = const Duration(seconds: 2),
  Duration spokenFor = const Duration(seconds: 10),
  bool quizOffered = false,
  bool quizDeclined = false,
}) {
  final log = Log();
  final backs = <bool>[];
  final input = FakeInput(log, heard: heard, available: micAvailable);
  final store = FakeChatQuizStore(log);
  final offerStates = <(bool, bool)>[];
  final session = ChatSession(
    repository: repo ?? FakeRepository(log),
    speech: FakeSpeech(log),
    haptics: FakeHaptics(log),
    cues: FakeCues(log),
    input: input,
    quizStore: store,
    quizOffered: quizOffered,
    quizDeclined: quizDeclined,
    onQuizOfferChanged: (o, d) => offerStates.add((o, d)),
    recent: recent,
    previous: previous,
    onBack: () => backs.add(true),
    thinkingTick: tick,
    thinkingSpokenEvery: spokenFor,
  );
  addTearDown(session.dispose);
  return Rig(log, session, input, backs, store, offerStates);
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

    test('the first answer without a picture points at the camera, once',
        () async {
      final r = rig();
      await r.session.askTyped('matters');
      await r.session.askTyped('matters');
      expect(
        r.log.events.where((e) =>
            e ==
            'say+: Tap the camera button below to add a picture, and I can answer about that too.'),
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
        contains('say: Thinking.'),
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
      r.session.handle(const HoldStart());
      r.session.handle(const Tap(Zone.rightEdge));
      expect(r.log.events, isEmpty);
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

  group('attach', () {
    test('attaching a picture announces it and starts fresh', () async {
      final r = rig();
      await r.session.askTyped('what is this?');
      expect(r.session.view.exchanges, hasLength(1));
      r.session.attachPicture(sunRecent());
      expect(r.session.recent, isNotNull);
      expect(r.session.view.exchanges, isEmpty);
      expect(
        r.log.events.firstWhere((e) => e.startsWith('say: The water cycle.')),
        startsWith('say: The water cycle. 4 parts: sun, cloud, mountain, sea.'),
      );
      await r.session.askTyped('and the sun?');
      expect(r.log.events, contains('ask:and the sun?||past:0'));
    });

    test('attaching clears a failed offline state', () async {
      final log = Log();
      final repo = FakeRepository(log)..fail = TouchApiException('Down.');
      final r = rig(repo: repo);
      await r.session.askTyped('matters');
      expect(r.session.view.offline, isTrue);
      repo.fail = null;
      r.session.attachPicture(sunRecent());
      expect(r.session.view.offline, isFalse);
      expect(r.session.recent, isNotNull);
    });

    test('a slow answer shows and speaks the waking message once', () async {
      final log = Log();
      final statuses = <String>[];
      final session = ChatSession(
        repository: SlowRepo(log),
        speech: FakeSpeech(log),
        haptics: FakeHaptics(log),
        cues: FakeCues(log),
        input: FakeInput(log),
        quizStore: FakeChatQuizStore(log),
        onChanged: (view) => statuses.add(view.statusText),
      );
      addTearDown(session.dispose);
      await session.askTyped('hi');
      expect(statuses, contains(serverWakingMessage));
      expect(log.where('say+: $serverWakingMessage'), hasLength(1));
    });

  });

  group('quiz offer', () {
    Future<Rig> askedTimes(int n,
        {TouchRepository? repo, RecentPicture? recent}) async {
      final r = rig(repo: repo, recent: recent);
      for (var i = 0; i < n; i++) {
        await r.session.askTyped('question $i');
      }
      return r;
    }

    Future<void> flushQuiz(Rig r) async {
      for (var i = 0; i < 20 && r.session.view.quizGenerating; i++) {
        await flushAsk();
      }
    }

    test('fires once at the 4th question, on the picture title', () async {
      final r = await askedTimes(3, recent: sunRecent());
      expect(r.session.view.quizOfferPending, isFalse);
      await r.session.askTyped('question 3');
      expect(r.session.view.quizOfferPending, isTrue);
      final topic = r.session.view.quizTopic;
      expect(topic, r.session.recent!.analysis.title);
      expect(r.log.events,
          contains('say+: ${quizOfferQuestion(topic)}'));
      await r.session.askTyped('question 4');
      expect(r.log.where('say+: Want a quiz'), hasLength(1));
      expect(r.offerStates.last, (true, false));
    });

    test('without a picture the topic trims the first question', () async {
      final r = rig();
      await r.session.askTyped(
          'why is the sky blue and what makes sunsets red and orange');
      await r.session.askTyped('and why 2');
      await r.session.askTyped('and why 3');
      await r.session.askTyped('and why 4');
      expect(r.session.view.quizOfferPending, isTrue);
      expect(r.session.view.quizTopic,
          'why is the sky blue and what makes\u2026');
    });

    test('no suppresses the offer for the conversation', () async {
      final r = await askedTimes(4);
      r.session.answerQuizOffer(false);
      expect(r.session.view.quizOfferPending, isFalse);
      expect(r.log.events, contains('say: No problem. Ask me anything.'));
      await r.session.askTyped('question 4');
      await r.session.askTyped('question 5');
      expect(r.log.where('say+: Want a quiz'), hasLength(1));
      expect(r.offerStates.last, (true, true));
    });

    test('yes generates, saves and announces the quiz', () async {
      final r = await askedTimes(4, recent: sunRecent());
      final topic = r.session.view.quizTopic;
      r.session.answerQuizOffer(true);
      await flushQuiz(r);
      expect(r.session.view.quizGenerating, isFalse);
      expect(r.session.view.quizOfferPending, isFalse);
      expect(r.log.events, contains('say: Making your quiz.'));
      expect(
        r.log.events,
        contains(
            'say: Your quiz on $topic is ready. '
            'Find it in Quizzes, under From your chats.'),
      );
      expect(r.log.events, contains('quiz:$topic|past:4'));
      expect(r.store.quizzes, hasLength(1));
      expect(r.store.quizzes.single.set.questions, hasLength(5));
    });

    test('voice yes and no answer the pending offer', () async {
      final r = await askedTimes(4);
      r.input.heard = 'yes please';
      await r.session.askTapped();
      await r.session.askTapped();
      await flushQuiz(r);
      expect(r.store.quizzes, hasLength(1));
      final r2 = await askedTimes(4);
      r2.input.heard = 'no thanks';
      await r2.session.askTapped();
      await r2.session.askTapped();
      expect(r2.session.view.quizOfferPending, isFalse);
      expect(r2.store.quizzes, isEmpty);
    });

    test('anything else stays a normal question with the offer still up',
        () async {
      final r = await askedTimes(4);
      r.input.heard = 'maybe later';
      await r.session.askTapped();
      await r.session.askTapped();
      expect(r.log.events, contains('ask:maybe later||past:4'));
      expect(r.session.view.quizOfferPending, isTrue);
      await r.session.askTyped('tell me more');
      expect(r.log.events, contains('ask:tell me more||past:5'));
      expect(r.session.view.quizOfferPending, isTrue);
    });

    test('typed yes skips the thinking preamble', () async {
      final r = await askedTimes(4);
      r.log.events.clear();
      await r.session.askTyped('yes');
      await flushQuiz(r);
      expect(r.log.events, contains('say: Making your quiz.'));
      expect(r.log.events, isNot(contains('say: Thinking.')));
      expect(r.store.quizzes, hasLength(1));
    });

    test('a failed generation speaks the error and saves nothing', () async {
      final log = Log();
      final repo = FakeRepository(log)..fail = TouchApiException('Down.');
      final r = rig(repo: repo);
      for (var i = 0; i < 4; i++) {
        await r.session.askTyped('q$i');
      }
      expect(r.session.view.quizOfferPending, isTrue);
      r.session.answerQuizOffer(true);
      await flushQuiz(r);
      expect(r.session.view.quizGenerating, isFalse);
      expect(r.session.view.quizError, 'Down.');
      expect(r.log.events, contains('say: Down.'));
      expect(r.store.quizzes, isEmpty);
      r.session.dismissQuizError();
      expect(r.session.view.quizError, isEmpty);
    });

    test('a slow generation reuses the waking-up announcement', () async {
      final log = Log();
      final statuses = <String>[];
      final session = ChatSession(
        repository: SlowQuizRepo(log),
        speech: FakeSpeech(log),
        haptics: FakeHaptics(log),
        cues: FakeCues(log),
        input: FakeInput(log),
        quizStore: FakeChatQuizStore(log),
        onChanged: (view) => statuses.add(view.statusText),
      );
      addTearDown(session.dispose);
      for (var i = 0; i < 4; i++) {
        await session.askTyped('q$i');
      }
      session.answerQuizOffer(true);
      for (var i = 0; i < 20 && session.view.quizGenerating; i++) {
        await flushAsk();
      }
      expect(statuses, contains(serverWakingMessage));
      expect(log.where('say+: $serverWakingMessage'), hasLength(1));
    });

    test('a new picture resets the offer for the fresh conversation',
        () async {
      final r = await askedTimes(4);
      r.session.answerQuizOffer(false);
      r.session.attachPicture(sunRecent());
      expect(r.offerStates.last, (false, false));
      for (var i = 0; i < 4; i++) {
        await r.session.askTyped('q$i');
      }
      expect(r.log.where('say+: Want a quiz'), hasLength(2));
    });

    test('an already-offered conversation stays quiet on return', () async {
      final r = rig(quizOffered: true);
      for (var i = 0; i < 5; i++) {
        await r.session.askTyped('q$i');
      }
      expect(r.log.where('say+: Want a quiz'), isEmpty);
      final r2 = rig(quizDeclined: true);
      for (var i = 0; i < 5; i++) {
        await r2.session.askTyped('q$i');
      }
      expect(r2.log.where('say+: Want a quiz'), isEmpty);
    });
  });
}
