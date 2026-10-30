import 'dart:typed_data';

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

  /// The bundled sample, whose outlines are hand-authored, not model output.
  Future<(Analysis, PictureBytes)> sample();
}
