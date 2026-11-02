import 'package:resonant/features/touch/domain/chart.dart';
import 'package:resonant/features/touch/domain/region.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

void main() {
  group('chartNumber', () {
    test('reads the value and its unit from the spoken line', () {
      final n = chartNumber('April: 80 millimetres of rain.')!;
      expect(n.value, 80);
      expect(n.unit, 'millimetres');
    });

    test('reads decimals and bare numbers', () {
      expect(chartNumber('2.5 cm of snow')!.value, 2.5);
      expect(chartNumber('population 12')!.value, 12);
    });

    test('is null when the words carry no number', () {
      expect(chartNumber('The sun, top right.'), isNull);
    });
  });

  group('bundled bar chart', () {
    test('parses: five bars, April tallest, January shortest', () {
      final a = loadChart();
      expect(isChart(a), isTrue);
      expect(isChart(loadSample()), isFalse);
      final bars = barsByHeight(a.regions);
      expect(bars.map((r) => r.label).toList(), [
        'April bar',
        'May bar',
        'February bar',
        'March bar',
        'January bar',
      ]);
    });

    test('summary names the tallest and shortest with their values', () {
      expect(
        chartSummary(loadChart()),
        '5 bars. Tallest: April bar, 80 millimetres. Shortest: January bar, 30 millimetres. '
        'Average 54 millimetres.',
      );
    });

    test('the average covers only the bars that carry numbers', () {
      final may = loadChart().regions.firstWhere((r) => r.label == 'May bar');
      final a = Analysis(
        width: 800,
        height: 600,
        title: 't',
        kind: 'chart',
        overview: '',
        regions: [loadSample().regions.first, may],
      );
      expect(
        chartSummary(a),
        '2 bars. Tallest: May bar, 65 millimetres. Shortest: sun. Average 65 millimetres.',
      );
    });

    test('no numbers anywhere means no average', () {
      final a = Analysis(
        width: 800,
        height: 600,
        title: 't',
        kind: 'chart',
        overview: '',
        regions: loadSample().regions,
      );
      expect(chartSummary(a), '4 bars. Tallest: mountain. Shortest: cloud.');
    });

    test('ranks place every bar against the tallest', () {
      final a = loadChart();
      Region bar(String label) => a.regions.firstWhere((r) => r.label == label);
      expect(barRankWords(bar('April bar'), a.regions), 'The tallest bar, 1 of 5.');
      expect(barRankWords(bar('May bar'), a.regions), 'Bar 2 of 5, about 80 percent of the tallest.');
      expect(
        barRankWords(bar('January bar'), a.regions),
        'Bar 5 of 5, about 40 percent of the tallest.',
      );
    });

    test('a stranger to the chart gets no rank', () {
      final a = loadChart();
      expect(barRankWords(loadSample().regions.first, a.regions), '');
    });

    test('sliding onto a bar says its label with its value', () {
      final a = loadChart();
      Region bar(String label) => a.regions.firstWhere((r) => r.label == label);
      expect(barSlideWords(bar('May bar')), 'May bar, 65 millimetres.');
      expect(barSlideWords(bar('January bar')), 'January bar, 30 millimetres.');
    });

    test('a bar with no number slides as its bare label', () {
      expect(barSlideWords(loadSample().regions.first), 'sun');
    });
  });
}
