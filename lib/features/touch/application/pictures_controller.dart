import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../core/services/haptics.dart';
import '../data/touch_repository.dart';
import '../domain/region.dart';
import 'recents.dart';

export 'recents.dart' show RecentPicture;

/// Picture intake for chat: analyzing photos, opening samples, and the
/// recents shelf. The widgets read the shelf; the camera sheet drives intake.
class PicturesState {
  const PicturesState({
    this.busy = false,
    this.message = '',
    this.progress = '',
    this.recents = const [],
  });

  final bool busy;

  /// A sentence for the sheet, such as why the last picture failed.
  final String message;

  /// While busy: which part is being read ("Reading part 2 of 6: sun.").
  final String progress;

  /// Pictures opened before, newest first — reopening one is instant.
  final List<RecentPicture> recents;

  PicturesState copyWith({
    bool? busy,
    String? message,
    String? progress,
    List<RecentPicture>? recents,
  }) =>
      PicturesState(
        busy: busy ?? this.busy,
        message: message ?? this.message,
        progress: progress ?? this.progress,
        recents: recents ?? this.recents,
      );
}

/// Owns picture intake and the recents shelf. Intake methods return the
/// [RecentPicture] so the caller can attach it; failures speak and return null.
class PicturesController extends Notifier<PicturesState> {
  Timer? _keepAlive;
  final _recents = RecentsStore();

  @override
  PicturesState build() {
    ref.onDispose(() => _keepAlive?.cancel());
    return const PicturesState();
  }

  Future<RecentPicture?> analyze(PictureBytes picture) async {
    final speech = ref.read(speechProvider);
    state = PicturesState(busy: true, recents: _recents.items);
    speech.speak('Reading the picture. This takes a few seconds.');
    // Silence feels like a freeze to someone who cannot see a spinner.
    _keepAlive?.cancel();
    _keepAlive = Timer.periodic(const Duration(seconds: 12), (_) {
      ref.read(hapticsProvider).pulse(30);
      speech.speak('Still working.', queue: true);
    });
    try {
      final analysis = await ref.read(repositoryProvider).analyze(
        picture,
        onSlow: () {
          // Before the first progress event only: never clobber real progress.
          if (!state.busy || state.progress.isNotEmpty) return;
          state = state.copyWith(progress: serverWakingMessage);
          speech.speak(serverWakingMessage, queue: true);
        },
        onProgress: (p) {
          if (!state.busy) return;
          state = state.copyWith(
              progress: 'Reading part ${p.done} of ${p.total}: ${p.label}.');
          ref.read(hapticsProvider).pulse(20);
          if (p.done == 1 || p.done == p.total || p.done % 3 == 0) {
            speech.speak('${p.done} of ${p.total}.', queue: true);
          }
        },
      );
      return _shelve(analysis, picture);
    } on TouchApiException catch (e) {
      _fail(e.message);
      return null;
    } catch (_) {
      _fail('Something went wrong. Try again.');
      return null;
    } finally {
      _keepAlive?.cancel();
    }
  }

  Future<RecentPicture?> openGallery(GallerySample entry) async {
    state = PicturesState(
        busy: true,
        progress: 'Loading ${entry.title}.',
        recents: _recents.items);
    ref.read(speechProvider).speak('Loading ${entry.title}.');
    try {
      final (analysis, picture) =
          await ref.read(repositoryProvider).openGallery(entry);
      return _shelve(analysis, picture);
    } catch (_) {
      _fail('The sample picture could not be loaded.');
      return null;
    }
  }

  /// Reopen a picture from the recents shelf: instant, no model calls.
  RecentPicture openRecent(RecentPicture recent) =>
      _shelve(recent.analysis, recent.picture);

  void _fail(String message) {
    ref.read(hapticsProvider).play(HapticPattern.error);
    ref.read(speechProvider).speak(message);
    state = PicturesState(message: message, recents: _recents.items);
  }

  RecentPicture _shelve(Analysis analysis, PictureBytes picture) {
    _recents.add(analysis, picture);
    final recent = _recents.items.first;
    state = PicturesState(recents: _recents.items);
    return recent;
  }
}

final picturesControllerProvider =
    NotifierProvider<PicturesController, PicturesState>(
        PicturesController.new);
