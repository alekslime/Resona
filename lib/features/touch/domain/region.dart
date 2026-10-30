import 'dart:convert';
import 'dart:typed_data';

/// One touchable part of a picture: a label, what to say about it, and its exact outline.
///
/// The outline is a small 0/1 grid ([maskW] x [maskH]) stretched over the box. It comes from
/// SAM 3.1 via the backend, so a finger can land on a river or a lung, not just a rectangle.
class Region {
  Region({
    required this.id,
    required this.order,
    required this.label,
    required this.spoken,
    required this.detail,
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
    required this.maskW,
    required this.maskH,
    required this.bits,
    required this.area,
    required this.areaFrac,
    this.confidence,
  });

  final String id;
  final int order;
  final String label;
  final String spoken;
  final String detail;

  /// Picture pixels. [right] and [bottom] are exclusive.
  final int left, top, right, bottom;
  final int maskW, maskH;
  final Uint8List bits;

  /// Pixels the part covers in the original picture, and as a share of the whole picture.
  final int area;
  final double areaFrac;
  final double? confidence;

  factory Region.fromJson(
    Map<String, dynamic> j, {
    required int imageWidth,
    required int imageHeight,
  }) {
    final box = (j['box'] as List).cast<num>();
    final mask = j['mask'] as Map<String, dynamic>;
    final area = (j['area'] as num).toInt();
    return Region(
      id: j['id'] as String,
      order: (j['order'] as num).toInt(),
      label: j['label'] as String,
      spoken: j['spoken'] as String,
      detail: j['detail'] as String,
      left: box[0].toInt(),
      top: box[1].toInt(),
      right: box[2].toInt(),
      bottom: box[3].toInt(),
      maskW: (mask['w'] as num).toInt(),
      maskH: (mask['h'] as num).toInt(),
      bits: base64Decode(mask['b64'] as String),
      area: area,
      areaFrac: area / (imageWidth * imageHeight),
      confidence: (j['confidence'] as num?)?.toDouble(),
    );
  }

  /// Is the picture pixel ([x], [y]) inside this part's outline?
  bool contains(num x, num y) {
    if (x < left || x >= right || y < top || y >= bottom) return false;
    final u = (((x - left) / (right - left)) * maskW).floor().clamp(0, maskW - 1);
    final v = (((y - top) / (bottom - top)) * maskH).floor().clamp(0, maskH - 1);
    return bits[v * maskW + u] == 1;
  }

  double get centerX => (left + right) / 2;
  double get centerY => (top + bottom) / 2;
}

/// What the backend returns for one picture.
class Analysis {
  Analysis({
    required this.width,
    required this.height,
    required this.title,
    required this.kind,
    required this.overview,
    required this.regions,
    this.skipped = const [],
    this.synthetic = false,
  });

  final int width, height;
  final String title, kind, overview;
  final List<Region> regions;

  /// Labels Muse Spark proposed that SAM could not find in the picture.
  final List<String> skipped;

  /// True only for the bundled sample, whose outlines are hand-authored, not model output.
  final bool synthetic;

  factory Analysis.fromJson(Map<String, dynamic> j) {
    final w = (j['width'] as num).toInt();
    final h = (j['height'] as num).toInt();
    return Analysis(
      width: w,
      height: h,
      title: j['title'] as String,
      kind: (j['kind'] as String?) ?? 'other',
      overview: (j['overview'] as String?) ?? '',
      regions: [
        for (final r in (j['regions'] as List))
          Region.fromJson(r as Map<String, dynamic>, imageWidth: w, imageHeight: h),
      ],
      skipped: [for (final s in (j['skipped'] as List? ?? const [])) s as String],
      synthetic: (j['synthetic'] as bool?) ?? false,
    );
  }
}
