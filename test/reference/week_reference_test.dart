import 'package:flutter_test/flutter_test.dart';
import 'package:pku_manager/data/week_config_parser.dart';
import 'package:pku_manager/domain/semester.dart';
import 'package:pku_manager/domain/week_frequency.dart';

// Independently authored semantic cases; see docs/REFERENCE_CASES.md.
void main() {
  final start = DateTime.utc(2032, 2, 23);
  final calendar = SemesterCalendar(starts: [start]);
  for (final c in [
    (0, 1, true),
    (7, 2, false),
    (13, 2, false),
    (14, 3, true),
  ]) {
    test('W01-W04 offset ${c.$1} has week ${c.$2} and expected parity', () {
      final week = calendar.weekAt(start.add(Duration(days: c.$1)))!;
      expect(week.weekNumber, c.$2);
      expect(week.isOdd, c.$3);
      expect(week.parity, c.$3 ? WeekParity.odd : WeekParity.even);
    });
  }
  test('W05 before all configured starts has no current semester', () {
    expect(calendar.weekAt(start.subtract(const Duration(days: 2))), isNull);
  });
  test(
    'W06 latest applicable semester wins over earlier and future starts',
    () {
      final middle = DateTime.utc(2032, 7, 5);
      final value = SemesterCalendar(
        starts: [start, middle, DateTime.utc(2032, 9, 6)],
      ).weekAt(DateTime.utc(2032, 7, 20))!;
      expect(value.start, middle);
      expect(value.weekNumber, 3);
    },
  );
  final parser = WeekConfigParser(SemesterConfig());
  test('W07 valid date list and supported timezone reach calendar', () {
    final value = parser.parse(
      'base_date = ["2032-02-23", "2032-09-06"]\n'
      'timezone = "Asia/Shanghai"',
    );
    expect(value.starts, [start, DateTime.utc(2032, 9, 6)]);
  });
  test('W08 base date is mandatory', () {
    expect(
      () => parser.parse('timezone = "Asia/Shanghai"'),
      throwsFormatException,
    );
  });
  test('W09 timezone is mandatory', () {
    expect(
      () => parser.parse('base_date = ["2032-02-23"]'),
      throwsFormatException,
    );
  });
  for (final dates in [
    '[]',
    '["2032-02-30"]',
    '["2032-2-23"]',
    '["2032-02-23", "2032-02-23"]',
    '["2032-09-06", "2032-02-23"]',
  ]) {
    test('W10 reject invalid or unordered dates: $dates', () {
      expect(
        () => parser.parse('base_date = $dates\ntimezone = "Asia/Shanghai"'),
        throwsFormatException,
      );
    });
  }
  test('W11 comments and trailing comma are accepted', () {
    expect(
      parser
          .parse(
            '# calendar\nbase_date = ["2032-02-23",] # starts\n'
            'timezone = "Asia/Shanghai" # fixed zone',
          )
          .starts,
      [start],
    );
  });
  test('W12 Beijing midnight changes parity, not UTC midnight', () {
    expect(
      calendar.weekAt(DateTime.utc(2032, 2, 29, 15, 59, 59))!.weekNumber,
      1,
    );
    expect(calendar.weekAt(DateTime.utc(2032, 2, 29, 16))!.weekNumber, 2);
  });
  test('W13 configured semester end is exclusive', () {
    final short = SemesterCalendar(
      starts: [start],
      config: SemesterConfig(weekCount: 2),
    );
    expect(short.weekAt(start.add(const Duration(days: 13)))!.weekNumber, 2);
    expect(short.weekAt(start.add(const Duration(days: 14))), isNull);
  });
  test('W14 new start truncates earlier semester', () {
    final next = start.add(const Duration(days: 10));
    final value = SemesterCalendar(starts: [start, next]);
    expect(value.weekAt(next)!.weekNumber, 1);
    expect(value.weekAt(next)!.start, next);
  });
  test('W15 build week bounds are validated', () {
    expect(SemesterConfig().weekCount, 16);
    expect(SemesterConfig(weekCount: 1).weekCount, 1);
    expect(SemesterConfig(weekCount: 53).weekCount, 53);
    for (final n in [0, -1, 54]) {
      expect(() => SemesterConfig(weekCount: n), throwsRangeError);
    }
  });
}
