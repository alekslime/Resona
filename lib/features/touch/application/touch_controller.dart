import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../core/services/haptics.dart';
import '../data/touch_repository.dart';
import '../domain/region.dart';
import '../gestures/gesture_types.dart';
import 'touch_session.dart';

enum Phase { start, busy, explore }

class TouchState {
  const TouchState({
    this.phase = Phase.start,
    this.view = const TouchView(),
    this.analysis,
    this.picture,
    this.message = '',
  });
  final Phase phase;
  final TouchView view;
  final Analysis? analysis;
  final PictureBytes? picture;

  /// A sentence for the start screen, such as why the last picture failed.
  final String message;

  TouchState copyWith({Phase? phase, TouchView? view, String? message}) => TouchState(
    phase: phase ?? this.phase,
    view: view ?? this.view,
    analysis: analysis,
    picture: picture,
    message: message ?? this.message,
  );
}

/// Owns the current picture and its [TouchSession]. The widgets only read [TouchState] and feed gestures in.
class TouchController extends Notifier<TouchState> {
  TouchSession? _session;
  Timer? _keepAlive;

  @override
  TouchState build() {
    ref.onDispose(() {
      _keepAlive?.cancel();
      _session?.dispose();
    });
    return const TouchState();
  }

  Future<void> analyze(PictureBytes picture) async {
    final speech = ref.read(speechProvider);
    state = const TouchState(phase: Phase.busy);
    speech.speak('Reading the picture. This takes about half a minute.');
    // Silence feels like a freeze to someone who cannot see a spinner.
    _keepAlive = Timer.periodic(const Duration(seconds: 12), (_) {
      ref.read(hapticsProvider).pulse(30);
      speech.speak('Still working.', queue: true);
    });
    try {
      final analysis = await ref.read(repositoryProvider).analyze(picture);
      _open(analysis, picture);
    } on TouchApiException catch (e) {
      _fail(e.message);
    } catch (_) {
      _fail('Something went wrong. Try again.');
    } finally {
      _keepAlive?.cancel();
    }
  }

  Future<void> openSample() async {
    try {
      final (analysis, picture) = await ref.read(repositoryProvider).sample();
      _open(analysis, picture);
    } catch (_) {
      _fail('The sample picture could not be loaded.');
    }
  }

  void _fail(String message) {
    ref.read(hapticsProvider).play(HapticPattern.error);
    ref.read(speechProvider).speak(message);
    state = TouchState(message: message);
  }

  void _open(Analysis analysis, PictureBytes picture) {
    _session?.dispose();
    late final TouchSession session;
    session = TouchSession(
      speech: ref.read(speechProvider),
      haptics: ref.read(hapticsProvider),
      cues: ref.read(cuesProvider),
      input: ref.read(speechInputProvider),
      repository: ref.read(repositoryProvider),
      onChanged: (v) {
        if (identical(session, _session)) state = state.copyWith(view: v);
      },
      onBack: leave,
    );
    _session = session;
    state = TouchState(phase: Phase.explore, analysis: analysis, picture: picture);
    session.load(analysis, picture);
  }

  void setLayout(PictureLayout layout) => _session?.layout = layout;
  void onGesture(Gesture g) => _session?.handle(g);

  void leave() {
    ref.read(speechProvider).stop();
    _session?.dispose();
    _session = null;
    state = const TouchState();
  }
}

final touchControllerProvider = NotifierProvider<TouchController, TouchState>(TouchController.new);
