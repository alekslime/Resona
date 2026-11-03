import 'dart:typed_data';

import '../../learn/domain/learn.dart';
import '../domain/region.dart';

/// The picture the user chose, already downscaled for upload.
class PictureBytes {
  const PictureBytes(this.bytes, this.mime);
  final Uint8List bytes;
  final String mime; // image/jpeg, image/png or image/webp
}

class TouchApiException implements Exception {
  TouchApiException(this.message);

  /// A plain sentence that is safe to speak aloud.
  final String message;
  @override
  String toString() => message;
}

/// Where and how to join the live-voice room (see agent/). The token is
/// short-lived and scoped to one room; the LiveKit secret never reaches the app.
class LiveVoiceConnection {
  const LiveVoiceConnection(
      {required this.url, required this.token, required this.room});
  final String url, token, room;
}

/// One entry in the samples gallery: a picture with ready-made outlines.
/// Bundled entries work offline; backend extras need the server.
class GallerySample {
  const GallerySample({
    required this.id,
    required this.title,
    required this.kind,
    required this.regions,
    this.remoteJson,
    this.remoteImage,
  });
  final String id;
  final String title;
  final String kind;
  final int regions;

  /// Backend paths from GET /api/samples; null when this entry is bundled.
  final String? remoteJson;
  final String? remoteImage;

  bool get bundled => remoteJson == null;
}

/// The pictures shipped with the app. Always available, even with no server.
const bundledSamples = [
  GallerySample(
      id: 'sample', title: 'The water cycle', kind: 'diagram', regions: 4),
  GallerySample(
      id: 'chart', title: 'Spring rainfall', kind: 'chart', regions: 5),
];

/// Progress while the backend outlines a picture: [done] of [total] parts.
class AnalyzeProgress {
  const AnalyzeProgress(
      {required this.done, required this.total, required this.label});
  final int done;
  final int total;
  final String label;
}

/// What GET /api/health says: is the server there, and can it analyze?
class ServerHealth {
  const ServerHealth({required this.reachable, required this.metaConfigured});
  final bool reachable;
  final bool metaConfigured;
}

abstract class TouchRepository {
  /// Muse Spark names the parts and places a box around each one (see backend/).
  /// [onProgress] fires after every part is placed, so the phone can speak
  /// the progress instead of sitting silent while it works.
  Future<Analysis> analyze(PictureBytes picture,
      {void Function(AnalyzeProgress progress)? onProgress});

  Future<String> ask(
    PictureBytes picture, {
    required String question,
    required String title,
    String regionLabel = '',
  });

  /// Multi-turn voice tutor: [history] is the conversation so far, oldest first.
  Future<String> chat(
    PictureBytes picture, {
    required String question,
    required String title,
    String regionLabel = '',
    List<({String q, String a})> history = const [],
  });

  /// A guided lesson over the parts of a picture that was already analyzed.
  Future<Lesson> lesson(Analysis analysis);

  /// Check-me questions (find-it by touch, say-it by voice) over the same parts.
  Future<Quiz> quiz(Analysis analysis);

  Future<Grade> grade(
      {required String question,
      required String expected,
      required String answer});

  /// Join details for a live, interruptible voice conversation about a picture.
  Future<LiveVoiceConnection> liveVoice({
    required String title,
    String overview = '',
    String regionLabel = '',
    String regionSpoken = '',
    String regionDetail = '',
  });

  /// One bundled sample, whose outlines are hand-authored, not model output.
  Future<(Analysis, PictureBytes)> sample({String id = 'sample'});

  /// Bundled samples (always available offline) plus backend extras when the
  /// server is reachable. Backend entries with a bundled id are skipped: the
  /// bundled copy wins because it works offline.
  Future<List<GallerySample>> gallery();

  /// Open one gallery entry: bundled entries load on the phone, backend
  /// extras download their outlines and picture.
  Future<(Analysis, PictureBytes)> openGallery(GallerySample entry);

  /// Is the backend reachable, and does it hold a Meta API key? Never throws:
  /// unreachable means the samples still work, so the answer is data, not an error.
  Future<ServerHealth> health();
}
