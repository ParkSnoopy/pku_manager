import 'package:flutter_test/flutter_test.dart';
import 'package:pku_manager/domain/week_frequency.dart';

void main() {
  test('only exact supported tokens are recognized', () {
    expect(WeekFrequency.parse('每周'), WeekFrequency.every);
    expect(WeekFrequency.parse('单周'), WeekFrequency.odd);
    expect(WeekFrequency.parse('双周'), WeekFrequency.even);
    for (final text in ['', ' 单周', '双周 ', '1-8周', 'odd']) {
      expect(WeekFrequency.parse(text), WeekFrequency.unknown);
    }
  });

  for (final frequency in WeekFrequency.values) {
    for (final mode in PreviewMode.values) {
      for (final parity in <WeekParity?>[null, ...WeekParity.values]) {
        test('$frequency / $mode / $parity visibility', () {
          final expected = switch (mode) {
            PreviewMode.all => true,
            PreviewMode.odd => frequency != WeekFrequency.even,
            PreviewMode.even => frequency != WeekFrequency.odd,
            PreviewMode.current => switch (parity) {
              null => true,
              WeekParity.odd => frequency != WeekFrequency.even,
              WeekParity.even => frequency != WeekFrequency.odd,
            },
          };
          expect(
            frequency.isVisible(mode: mode, currentParity: parity),
            expected,
          );
        });
      }
    }
  }
}
