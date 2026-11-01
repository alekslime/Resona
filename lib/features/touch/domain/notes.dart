import 'hit_tester.dart';
import 'region.dart';
import 'spatial.dart';

/// The study notes as one plain-text document: what the Study notes screen shows,
/// flattened so it can be copied, pasted into homework, sent to a teacher, or read
/// by any screen reader outside the app. Same words, same order, no model calls.
String studyNotesText(Analysis a) {
  final parts = readingOrder(a.regions);
  final w = a.width.toDouble();
  final h = a.height.toDouble();
  final b = StringBuffer()
    ..writeln(a.title)
    ..writeln()
    ..writeln(a.overview)
    ..writeln()
    ..writeln('The map in words')
    ..writeln(mapInWords(parts, w, h))
    ..writeln()
    ..writeln('The parts, in order');
  for (final r in parts) {
    b
      ..writeln()
      ..writeln(r.label)
      ..writeln(r.spoken)
      ..writeln(r.detail)
      ..writeln(
        'Covers about ${(r.areaFrac * 100).round()} percent of the picture, '
        '${clockWords(r, w, h)}.${aroundWords(r, parts)}',
      );
    if (r.approximate) {
      b.writeln(
        'Approximate outline: the model could not trace this part, so it is a rough rectangle.',
      );
    }
  }
  if (a.skipped.isNotEmpty) {
    b
      ..writeln()
      ..writeln(
        'Not outlined: ${a.skipped.join(', ')}. The model named these but could not '
        'outline them, so they are not touchable.',
      );
  }
  return b.toString().trimRight();
}
