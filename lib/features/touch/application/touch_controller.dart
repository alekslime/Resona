import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../core/services/haptics.dart';
import '../../learn/application/learn_session.dart';
import '../../learn/domain/learn.dart';
import '../data/touch_repository.dart';
import '../domain/region.dart';
import '../gestures/gesture_types.dart';
import 'recents.dart';
import 'touch_session.dart';

export 'recents.dart' show RecentPicture;

enum Phase { start, busy, explore }

enum ExploreMode { explore, lesson, quiz }

class TouchState {
  const TouchState({
    this.phase = Phase.start,
    this.view = const TouchView(),
    this.analysis,
    this.picture,
    this.message = '',
    this.mode = ExploreMode.explore,
    this.recents = const [],
    this.progress = '',
  });
  final Phase phase;
  final TouchView view;
  final Analysis? analysis;
  final PictureBytes? picture;

  /// A sentence for the start screen, such as why the last picture failed.
  final String message;
  final ExploreMode mode;

  /// Pictures opened before, newest first — reopening one is instant.
  final List<RecentPicture> recents;

  /// While busy: which part is being outlined ("Outlining part 2 of 6: sun.").
  final String progress;

  TouchState copyWith({
    Phase? phase,
    TouchView? view,
    String? message,
    ExploreMode? mode,
    String? progress,
  }) =>
      TouchState(
        phase: phase ?? this.phase,
        view: view ?? this.view,
        analysis: analysis,
        picture: picture,
        message: message ?? this.message,
        mode: mode ?? this.mode,
        recents: recents,
        progress: progress ?? this.progress,
      );
}

/// Owns the current picture and its [TouchSession]. The widgets only read [TouchState] and feed gestures in.
class TouchController extends Notifier<TouchState> {
  TouchSession? _session;
  LearnSession? _learn;
  Lesson? _pendingLesson;
  Quiz? _pendingQuiz;
  bool _learnBusy = false;
  Timer? _keepAlive;
  final _recents = RecentsStore();

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
      final analysis = await ref.read(repositoryProvider).analyze(
        picture,
        onProgress: (p) {
          if (state.phase != Phase.busy) return;
          state = state.copyWith(
              progress: 'Outlining part ${p.done} of ${p.total}: ${p.label}.');
          ref.read(hapticsProvider).pulse(20);
          if (p.done == 1 || p.done == p.total || p.done % 3 == 0) {
            speech.speak('${p.done} of ${p.total}.', queue: true);
          }
        },
      );
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

  Future<void> openGallery(GallerySample entry) async {
    try {
      final (analysis, picture) =
          await ref.read(repositoryProvider).openGallery(entry);
      _open(analysis, picture);
    } catch (_) {
      _fail('The sample picture could not be loaded.');
    }
  }

  void _fail(String message) {
    ref.read(hapticsProvider).play(HapticPattern.error);
    ref.read(speechProvider).speak(message);
    state = TouchState(message: message, recents: _recents.items);
  }

  /// Reopen a picture from the recents shelf: instant, no model calls.
  void openRecent(RecentPicture recent) =>
      _open(recent.analysis, recent.picture);

  void _open(Analysis analysis, PictureBytes picture) {
    _session?.dispose();
    _learn = null;
    _pendingLesson = null;
    _pendingQuiz = null;
    _recents.add(analysis, picture);
    late final TouchSession session;
    session = TouchSession(
      speech: ref.read(speechProvider),
      haptics: ref.read(hapticsProvider),
      cues: ref.read(cuesProvider),
      input: ref.read(speechInputProvider),
      repository: ref.read(repositoryProvider),
      onChanged: (v) {
        if (identical(session, _session) && state.mode == ExploreMode.explore) {
          state = state.copyWith(view: v);
        }
      },
      onBack: leave,
    );
    _session = session;
    state = TouchState(
      phase: Phase.explore,
      analysis: analysis,
      picture: picture,
      recents: _recents.items,
    );
    session.load(analysis, picture);
  }

  // ---- lesson & quiz ----

  LearnSession _learnSession() {
    late final LearnSession learn;
    learn = LearnSession(
      speech: ref.read(speechProvider),
      haptics: ref.read(hapticsProvider),
      cues: ref.read(cuesProvider),
      input: ref.read(speechInputProvider),
      repository: ref.read(repositoryProvider),
      onChanged: (v) {
        if (identical(learn, _learn)) state = state.copyWith(view: v);
      },
      onExit: exitLearn,
    );
    _learn = learn;
    learn.layout = _session?.layout;
    return learn;
  }

  Future<void> startLesson() async {
    final analysis = state.analysis;
    if (analysis == null || _learnBusy) return;
    _learnBusy = true;
    final repo = ref.read(repositoryProvider);
    ref.read(speechProvider).speak('Preparing your lesson.');
    try {
      // Reuse the lesson while this picture stays open: one model call per picture.
      final lesson = _pendingLesson ??= await repo.lesson(analysis);
      final learn = _learnSession();
      state = state.copyWith(mode: ExploreMode.lesson);
      learn.startLesson(analysis, lesson);
    } on TouchApiException catch (e) {
      ref.read(speechProvider).speak(e.message);
    } catch (_) {
      ref.read(speechProvider).speak('Something went wrong. Try again.');
    } finally {
      _learnBusy = false;
    }
  }

  Future<void> startQuiz() async {
    final analysis = state.analysis;
    if (analysis == null || _learnBusy) return;
    _learnBusy = true;
    final repo = ref.read(repositoryProvider);
    ref.read(speechProvider).speak('Preparing your quiz.');
    try {
      _pendingQuiz ??= await repo.quiz(analysis);
      final quiz = _pendingQuiz!;
      final learn = _learnSession();
      state = state.copyWith(mode: ExploreMode.quiz);
      learn.startQuiz(analysis, quiz);
    } on TouchApiException catch (e) {
      ref.read(speechProvider).speak(e.message);
    } catch (_) {
      ref.read(speechProvider).speak('Something went wrong. Try again.');
    } finally {
      _learnBusy = false;
    }
  }

  void exitLearn() {
    _learn = null;
    ref.read(speechProvider).stop();
    state = state.copyWith(mode: ExploreMode.explore);
    ref
        .read(speechProvider)
        .speak('Back to exploring. Drag a finger over the picture.');
  }

  /// The on-screen Answer button for say-it questions (hold-to-talk does the same job).
  void toggleAnswer() => _learn?.toggleAnswer();

  /// The on-screen Practise-missed button at the end of a quiz.
  void retryMissed() => _learn?.retryMissed();

  bool get _inLearn => state.mode != ExploreMode.explore && _learn != null;

  void setLayout(PictureLayout layout) {
    _session?.layout = layout;
    _learn?.layout = layout;
  }

  void onGesture(Gesture g) {
    if (_inLearn) {
      _learn!.layout ??= _session?.layout;
      _learn!.handle(g);
    } else {
      _session?.handle(g);
    }
  }

  void leave() {
    ref.read(speechProvider).stop();
    _session?.dispose();
    _session = null;
    _learn = null;
    _pendingLesson = null;
    _pendingQuiz = null;
    state = TouchState(recents: _recents.items);
  }
}

final touchControllerProvider =
    NotifierProvider<TouchController, TouchState>(TouchController.new);
