import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:resonant/core/services/haptics.dart';
import 'package:resonant/core/services/sound.dart';
import 'package:resonant/core/services/speech.dart';
import 'package:resonant/features/learn/domain/learn.dart';
import 'package:resonant/features/touch/data/touch_repository.dart';
import 'package:resonant/features/touch/domain/region.dart';

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
  FakeCues(this.log);
  final Log log;
  @override
  Future<void> play(HapticPattern pattern) async =>
      log.events.add('cue:${pattern.name}');
  @override
  Future<void> position({required double x01, required double y01}) async =>
      log.events
          .add('tone:${x01.toStringAsFixed(2)},${y01.toStringAsFixed(2)}');
  @override
  Future<void> proximity({required double closeness}) async =>
      log.events.add('prox:${closeness.toStringAsFixed(2)}');
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
  }) =>
      throw UnimplementedError();
  @override
  Future<String> ask(
    PictureBytes picture, {
    required String question,
    required String title,
    String regionLabel = '',
  }) async =>
      chat(picture, question: question, title: title, regionLabel: regionLabel);

  @override
  Future<String> chat(
    PictureBytes picture, {
    required String question,
    required String title,
    String regionLabel = '',
    List<({String q, String a})> history = const [],
  }) async {
    log.events.add('ask:$question|$regionLabel|past:${history.length}');
    if (fail != null) throw fail!;
    return answer;
  }

  @override
  Future<Lesson> lesson(Analysis analysis) async {
    log.events.add('lesson');
    final order = [...analysis.regions]
      ..sort((a, b) => a.order.compareTo(b.order));
    return Lesson([
      const LessonStep(say: 'Welcome to the lesson.'),
      for (final r in order)
        LessonStep(regionId: r.id, say: '${r.label}. ${r.detail}'),
      const LessonStep(say: 'That is the whole picture.'),
    ]);
  }

  @override
  Future<Quiz> quiz(Analysis analysis) async {
    log.events.add('quiz');
    final order = [...analysis.regions]
      ..sort((a, b) => a.order.compareTo(b.order));
    return Quiz([
      QuizQuestion(
          kind: QuizKind.find,
          regionId: order.first.id,
          question: 'Find the ${order.first.label}.'),
      QuizQuestion(
        kind: QuizKind.say,
        regionId: order.last.id,
        question: 'What does the ${order.last.label} hold?',
        expected: 'water',
      ),
    ]);
  }

  @override
  Future<Grade> grade(
      {required String question,
      required String expected,
      required String answer}) async {
    log.events.add('grade:$answer');
    final ok = answer.toLowerCase().contains(expected.toLowerCase());
    return Grade(
        ok, ok ? 'Correct. Well done.' : 'Not quite. The answer is $expected.');
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
