import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:resonant/features/touch/application/touch_session.dart';
import 'package:resonant/features/touch/domain/region.dart';
import 'package:resonant/features/touch/gestures/gesture_types.dart';

import 'fakes.dart';

Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 20));

Region part(String id, String label, int order) => Region(
  id: id,
  order: order,
  label: label,
  spoken: 'The $label.',
  detail: 'Detail about the $label.',
  left: order * 100,
  top: 10,
  right: order * 100 + 80,
  bottom: 90,
  maskW: 2,
  maskH: 2,
  bits: Uint8List.fromList([1, 1, 1, 1]),
  area: 6400,
  areaFrac: 0.01,
);

class PickRig {
  PickRig() {
    session =
        TouchSession(
            speech: FakeSpeech(log),
            haptics: FakeHaptics(log),
            cues: FakeCues(log),
            input: FakeInput(log, heard: 'where is the lung?'),
            repository: FakeRepository(log),
            labelDelay: const Duration(milliseconds: 5),
          )
          ..layout = const PictureLayout(left: 0, top: 0, scale: 1)
          ..load(
            Analysis(
              width: 800,
              height: 600,
              title: 'Test picture',
              kind: 'diagram',
              overview: 'Overview.',
              regions: [
                part('a', 'left lung', 0),
                part('b', 'right lung', 1),
                part('c', 'heart', 2),
              ],
            ),
            tinyPicture,
          );
    log.events.clear();
  }
  final log = Log();
  late final TouchSession session;

  FakeInput get input => session.input as FakeInput;

  Future<void> ask(String heard) async {
    input.heard = heard;
    session.handle(const LongPress(Zone.center));
    await settle();
    session.handle(const LongPressEnd(Zone.center));
    await settle();
  }
}

void main() {
  group('answering did-you-mean', () {
    test('"the first one" guides to the first part', () async {
      final r = PickRig();
      r.session.handle(const ExploreStart(400, 300));
      await r.ask('where is the lung?');
      expect(r.log.where('say').last.toLowerCase().contains('did you mean'), isTrue);
      await r.ask('the first one');
      expect(r.log.where('ask').isEmpty, isTrue);
      expect(r.log.where('say').last.contains('Guide mode.'), isTrue);
      expect(r.log.where('say').last.contains('left lung'), isTrue);
      r.session.handle(const ExploreRest(400, 300));
      expect(r.log.where('say').last.contains('The left lung is'), isTrue);
    });

    test('"second" guides to the second part', () async {
      final r = PickRig();
      r.session.handle(const ExploreStart(400, 300));
      await r.ask('where is the lung?');
      await r.ask('second');
      expect(r.log.where('ask').isEmpty, isTrue);
      expect(r.log.where('say').last.contains('right lung'), isTrue);
    });

    test('saying a part name picks it, even without "where is"', () async {
      final r = PickRig();
      r.session.handle(const ExploreStart(400, 300));
      await r.ask('where is the lung?');
      await r.ask('left lung');
      expect(r.log.where('ask').isEmpty, isTrue);
      expect(r.log.where('say').last.contains('Guide mode.'), isTrue);
      expect(r.log.where('say').last.contains('left lung'), isTrue);
    });

    test('"option a" and bare "b" pick by letter', () async {
      final r = PickRig();
      r.session.handle(const ExploreStart(400, 300));
      await r.ask('where is the lung?');
      await r.ask('option a');
      expect(r.log.where('say').last.contains('left lung'), isTrue);
      await r.ask('where is the lung?');
      await r.ask('b');
      expect(r.log.where('say').last.contains('right lung'), isTrue);
    });

    test('anything else answers nothing and clears the question', () async {
      final r = PickRig();
      r.session.handle(const ExploreStart(400, 300));
      await r.ask('where is the lung?');
      await r.ask('what is this?');
      expect(r.log.where('ask').isNotEmpty, isTrue); // went to the tutor
      await r.ask('the first one'); // too late: the question is gone
      expect(r.log.where('say').last.contains('Guide mode.'), isFalse);
      expect(r.log.where('ask').length, 2);
    });

    test('a picked hunt completes with arrival teaching', () async {
      final r = PickRig();
      r.session.handle(const ExploreStart(400, 300));
      await r.ask('where is the lung?');
      await r.ask('first');
      r.log.events.clear();
      r.session.handle(const ExploreMove(40, 50)); // onto the left lung
      await settle();
      expect(r.log.where('say').single.startsWith('say: You found the left lung.'), isTrue);
    });
  });
}
