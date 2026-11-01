import 'region.dart';

/// Value readout for bar charts: bars ranked tallest-first, numbers spoken.
///
/// Everything is computed on the phone from the boxes and the words Muse Spark
/// already wrote — no extra model calls. Numbers come from the part's own
/// spoken line ("April: 80 millimetres of rain."), so a chart whose values the
/// model did not write still gets ranks, just without numbers.
bool isChart(Analysis a) => a.kind.toLowerCase() == 'chart';

/// The first number in [text], with the word after it as its unit.
/// "April: 80 millimetres of rain." -> (80, "millimetres"). Null when the
/// words carry no number.
({double value, String unit})? chartNumber(String text) {
  final m = RegExp(r'(\d+(?:\.\d+)?)\s*([A-Za-z%]+)?').firstMatch(text);
  if (m == null) return null;
  return (value: double.parse(m.group(1)!), unit: (m.group(2) ?? '').toLowerCase());
}

/// Regions ordered tallest bar first, by box height.
List<Region> barsByHeight(List<Region> regions) =>
    [...regions]..sort((a, b) => (b.bottom - b.top).compareTo(a.bottom - a.top));

String _valueWords(Region r) {
  final n = chartNumber(r.spoken) ?? chartNumber(r.detail);
  if (n == null) return '';
  final v = n.value == n.value.roundToDouble() ? '${n.value.toInt()}' : '${n.value}';
  return n.unit.isEmpty ? v : '$v ${n.unit}';
}

/// "5 bars. Tallest: April bar, 80 millimetres. Shortest: January bar, 30 millimetres."
/// Empty when there are no bars.
String chartSummary(Analysis a) {
  final bars = barsByHeight(a.regions);
  if (bars.isEmpty) return '';
  if (bars.length == 1) {
    final v = _valueWords(bars.single);
    return v.isEmpty ? '1 bar: ${bars.single.label}.' : '1 bar: ${bars.single.label}, $v.';
  }
  final tallest = bars.first, shortest = bars.last;
  final hi = _valueWords(tallest), lo = _valueWords(shortest);
  final hiWords = hi.isEmpty ? tallest.label : '${tallest.label}, $hi';
  final loWords = lo.isEmpty ? shortest.label : '${shortest.label}, $lo';
  return '${bars.length} bars. Tallest: $hiWords. Shortest: $loWords.';
}

/// Where one bar stands: "The tallest bar, 1 of 5." or
/// "Bar 2 of 5, about 70 percent of the tallest."
String barRankWords(Region r, List<Region> regions) {
  final bars = barsByHeight(regions);
  final rank = bars.indexWhere((b) => b.id == r.id) + 1;
  if (rank <= 0) return '';
  if (rank == 1) return 'The tallest bar, 1 of ${bars.length}.';
  final tallestH = bars.first.bottom - bars.first.top;
  final h = r.bottom - r.top;
  final percent = tallestH <= 0 ? 100 : ((h / tallestH * 100) / 10).round() * 10;
  return 'Bar $rank of ${bars.length}, about $percent percent of the tallest.';
}
