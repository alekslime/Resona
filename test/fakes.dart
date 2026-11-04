import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resonant/core/providers.dart';
import 'package:resonant/core/services/haptics.dart';
import 'package:resonant/core/services/sound.dart';
import 'package:resonant/core/services/speech.dart';
import 'package:resonant/features/touch/data/touch_repository.dart';
import 'package:resonant/features/touch/domain/region.dart';
import 'package:resonant/features/learn/domain/library.dart';
import 'package:resonant/features/touch/application/chat_quizzes.dart';
import 'package:resonant/features/touch/presentation/gesture_guide.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Records everything the session does, in order.
class Log {
  final events = <String>[];
  List<String> where(String prefix) =>
      events.where((e) => e.startsWith(prefix)).toList();
}

class FakeSpeech implements SpeechOutput {
  FakeSpeech(this.log);
  final Log log;
  bool speaking = false;
  @override
  double rate = 1.0;
  @override
  bool get isSpeaking => speaking;
  @override
  Future<void> speak(String text, {bool queue = false}) async {
    speaking = true;
    log.events.add('say${queue ? '+' : ''}: $text');
  }

  @override
  Future<void> stop() async {
    speaking = false;
    log.events.add('stop');
  }
}

class FakeHaptics implements Haptics {
  FakeHaptics(this.log);
  final Log log;
  @override
  Future<void> play(HapticPattern pattern) async =>
      log.events.add('haptic:${pattern.name}');
  @override
  Future<void> pulse(int ms) async => log.events.add('pulse:$ms');
}

class FakeCues implements Cues {
  @override
  bool enabled = true;

  FakeCues(this.log);
  final Log log;
  @override
  Future<void> play(HapticPattern pattern) async {
    if (!enabled) return;
    log.events.add('cue:${pattern.name}');
  }
  @override
  Future<void> position({required double x01, required double y01}) async {
    if (!enabled) return;
    log.events.add('tone:${x01.toStringAsFixed(2)},${y01.toStringAsFixed(2)}');
  }
  @override
  Future<void> proximity({required double closeness}) async {
    if (!enabled) return;
    log.events.add('prox:${closeness.toStringAsFixed(2)}');
  }

  @override
  Future<void> splash() async {
    if (!enabled) return;
    log.events.add('splash');
  }
}

class FakeInput implements SpeechInput {
  FakeInput(this.log, {this.heard = 'what is this?', this.available = true});
  final Log log;
  String heard;
  bool available;
  @override
  Future<bool> start() async {
    log.events.add('mic:start');
    return available;
  }

  @override
  Future<String> stop() async {
    log.events.add('mic:stop');
    return heard;
  }
}

class FakeRepository implements TouchRepository {
  FakeRepository(this.log, {this.answer = 'It is the sun.', this.fail});
  final Log log;
  String answer;
  Object? fail;
  @override
  Future<Analysis> analyze(
    PictureBytes picture, {
    void Function(AnalyzeProgress progress)? onProgress,
    void Function()? onSlow,
  }) =>
      throw UnimplementedError();
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
    if (fail != null) throw fail!;
    return answer;
  }

  @override
  Future<String> chatText({
    required String question,
    List<({String q, String a})> history = const [],
    void Function()? onSlow,
  }) async {
    log.events.add('ask:$question||past:${history.length}');
    if (fail != null) throw fail!;
    return answer;
  }

  @override
  Future<GeneratedQuiz> quiz({
    required String topic,
    List<({String q, String a})> history = const [],
    void Function()? onSlow,
  }) async {
    log.events.add('quiz:$topic|past:${history.length}');
    if (fail != null) throw fail!;
    return cannedQuiz(topic);
  }

  @override
  Future<LiveVoiceConnection> liveVoice({
    required String title,
    String overview = '',
    String regionLabel = '',
    String regionSpoken = '',
    String regionDetail = '',
  }) async {
    log.events.add('live:$title|$regionLabel');
    return const LiveVoiceConnection(
        url: 'wss://fake', token: 'fake-token', room: 'resonant-fake');
  }

  @override
  Future<(Analysis, PictureBytes)> sample({String id = 'sample'}) =>
      throw UnimplementedError();

  @override
  Future<List<GallerySample>> gallery() async => bundledSamples;

  @override
  Future<(Analysis, PictureBytes)> openGallery(GallerySample entry) =>
      throw UnimplementedError();

  @override
  Future<ServerHealth> health() async =>
      const ServerHealth(reachable: true, metaConfigured: true);
}

/// The bundled sample: 800x600, with sun, cloud, mountain and sea.
/// Serves the real bundled sample picture for widget tests.
class SeedRepo extends FakeRepository {
  SeedRepo(super.log);

  @override
  Future<(Analysis, PictureBytes)> openGallery(GallerySample entry) async => (
        loadSample(),
        PictureBytes(
          File('assets/sample/sample.png').readAsBytesSync(),
          'image/png',
        ),
      );
}

Analysis loadSample() {
  final json = jsonDecode(File('assets/sample/sample.json').readAsStringSync())
      as Map<String, dynamic>;
  return Analysis.fromJson(json);
}

/// The bundled bar chart: 800x600, five rainfall bars, January to May.
Analysis loadChart() {
  final json = jsonDecode(File('assets/sample/chart.json').readAsStringSync())
      as Map<String, dynamic>;
  return Analysis.fromJson(json);
}

final tinyPicture = PictureBytes(Uint8List.fromList([1, 2, 3]), 'image/png');

/// An in-memory clipboard for widget tests: the test binding leaves
/// Clipboard.setData hanging with no reply, so any test that taps a copy
/// button must install this first. Returns the stored text.
String? Function() mockClipboard() {
  String? stored;
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(SystemChannels.platform,
          (MethodCall call) async {
    if (call.method == 'Clipboard.setData') {
      stored = (call.arguments as Map)['text'] as String?;
      return null;
    }
    if (call.method == 'Clipboard.getData') {
      return <String, dynamic>{'text': stored};
    }
    return null;
  });
  return () => stored;
}

/// Prefs for widget tests of other behavior: a returning device whose
/// guides were all seen, so no guide banner appears. Guide tests seed
/// their own flags instead.
Future<SharedPreferences> guidesSeenPrefs() async {
  SharedPreferences.setMockInitialValues({
    seenTourKey: true,
    for (final s in GuideScreen.values) guideSeenKey(s): true,
  });
  return SharedPreferences.getInstance();
}

/// A 5-question generated quiz for tests.
GeneratedQuiz cannedQuiz([String topic = 'The water cycle']) => GeneratedQuiz(
      topic: topic,
      questions: [
        for (var i = 0; i < 5; i++)
          LibraryQuizQuestion(
            id: 'cq',
            prompt: 'Canned question ',
            options: [
              for (var o = 0; o < 4; o++)
                LibraryQuizOption(
                  letter: String.fromCharCode(65 + o),
                  text: 'Answer ',
                ),
            ],
            correctIndex: 0,
            explanation: 'Because .',
          ),
      ],
    );

/// An in-memory generated-quiz store for tests.
class FakeChatQuizStore implements ChatQuizStore {
  FakeChatQuizStore(this.log);
  final Log log;
  final _quizzes = <StoredQuiz>[];

  @override
  List<StoredQuiz> get quizzes => List.unmodifiable(_quizzes);

  @override
  Future<StoredQuiz> saveQuiz({
    required String title,
    required List<LibraryQuizQuestion> questions,
  }) async {
    log.events.add('quiz-saved:$title');
    final stored = StoredQuiz(
      set: LibraryQuizSet(
        id: 'fake-quiz-${_quizzes.length}',
        title: title,
        category: 'From your chats',
        questions: questions,
      ),
      createdAt: DateTime(2026, 11, 5),
    );
    _quizzes.insert(0, stored);
    return stored;
  }
}
