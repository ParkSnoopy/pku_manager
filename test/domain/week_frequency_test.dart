import 'package:flutter_test/flutter_test.dart';
import 'package:pku_manager/domain/week_frequency.dart';

void main() {
  test('unsupported frequency tokens map to every week', () {
    expect(WeekFrequency.parse('每周'), WeekFrequency.every);
    expect(WeekFrequency.parse('单周'), WeekFrequency.odd);
    expect(WeekFrequency.parse('双周'), WeekFrequency.even);
    for (final text in ['', ' 单周', '双周 ', '1-8周', 'odd']) {
      expect(WeekFrequency.parse(text), WeekFrequency.every);
    }
  });

  for (final frequency in WeekFrequency.values) {
    for (final parity in <WeekParity?>[null, ...WeekParity.values]) {
      test('$frequency / $parity current-week membership', () {
        final expected =
            parity == null ||
            frequency == WeekFrequency.every ||
            (frequency == WeekFrequency.odd && parity == WeekParity.odd) ||
            (frequency == WeekFrequency.even && parity == WeekParity.even);
        expect(frequency.isCurrent(parity), expected);
      });
    }
  }
}
