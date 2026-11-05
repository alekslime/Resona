import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resonant/core/services/flutter_tts_speech.dart';

/// The phone speaks through one shared flutter_tts engine: queue-mode flips
/// and stop() calls must reach it in call order, or sentences eat each
/// other. ChatSession fires speaks without awaiting them, so these tests do
/// the same and record what the platform actually received.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('flutter_tts');

  List<MethodCall> record(Future<dynamic> Function(MethodCall call) handler) {
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return handler(call);
    });
    return calls;
  }

  String textOf(MethodCall call) => call.arguments is Map
      ? '${(call.arguments as Map)['text']}'
      : '${call.arguments}';

  test('a flush plus queued sentences speak in call order', () async {
    final calls = record((call) async => call.method == 'getVoices' ? [] : 1);

    final speech = FlutterTtsSpeech();
    final done = Future.wait([
      speech.speak('one'),
      speech.speak('two', queue: true),
      speech.speak('three', queue: true),
    ]);
    await done;

    final flow = calls
        .where((c) => c.method == 'speak' || c.method == 'stop')
        .toList();
    // One flush first; a stop landing between speaks would kill a sentence.
    expect(flow.map((c) => c.method), ['stop', 'speak', 'speak', 'speak']);
    expect(
      flow.where((c) => c.method == 'speak').map(textOf),
      ['one', 'two', 'three'],
    );
  });

  test('back-to-back interrupts keep their order', () async {
    final calls = record((call) async => call.method == 'getVoices' ? [] : 1);

    final speech = FlutterTtsSpeech();
    await Future.wait([speech.speak('one'), speech.speak('two')]);

    final spoken = calls.where((c) => c.method == 'speak').map(textOf);
    expect(spoken, ['one', 'two']);
  });

  test('stop drops a sentence still waiting behind voice setup', () async {
    final gate = Completer<List>();
    final calls = record((call) async => call.method == 'getVoices' ? gate.future : 1);

    final speech = FlutterTtsSpeech();
    final late = speech.speak('late');
    await speech.stop();
    gate.complete([]);
    await late;

    expect(calls.where((c) => c.method == 'speak'), isEmpty);
  });
}
