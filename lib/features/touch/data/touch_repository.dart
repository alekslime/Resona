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

abstract class TouchRepository {
  /// Muse Spark names the parts, SAM 3.1 outlines them (see backend/).
  Future<Analysis> analyze(PictureBytes picture);

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

  Future<Grade> grade({required String question, required String expected, required String answer});

  /// The bundled sample, whose outlines are hand-authored, not model output.
  Future<(Analysis, PictureBytes)> sample();
}
