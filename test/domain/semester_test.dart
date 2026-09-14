import 'package:flutter_test/flutter_test.dart';
import 'package:pku_manager/domain/semester.dart';
import 'package:pku_manager/domain/week_frequency.dart';

void main() {
  final start = DateTime.utc(2026, 9, 7);
  final calendar = SemesterCalendar(starts: [start]);

  test('Beijing midnight, Sunday end and Monday parity transition', () {
    expect(calendar.weekAt(DateTime.parse('2026-09-06T15:59:59Z')), isNull);
    final first = calendar.weekAt(DateTime.parse('2026-09-06T16:00:00Z'))!;
    expect(first.start, start);
    expect(first.date, start);
    expect(first.weekNumber, 1);
    expect(first.parity, WeekParity.odd);
    expect(
      calendar.weekAt(DateTime.parse('2026-09-13T15:59:59Z'))!.weekNumber,
      1,
    );
    final second = calendar.weekAt(DateTime.parse('2026-09-13T16:00:00Z'))!;
    expect(second.weekNumber, 2);
    expect(second.isOdd, isFalse);
    expect(second.parity, WeekParity.even);
    expect(calendar.weekAt(DateTime.utc(2026, 9, 21))!.weekNumber, 3);
  });

  test(
    'equivalent instants and year/leap-day boundaries use Beijing dates',
    () {
      expect(beijingDate(DateTime.parse('2026-09-07T00:00:00+08:00')), start);
      expect(beijingDate(DateTime.parse('2026-09-06T09:00:00-07:00')), start);
      expect(
        beijingDate(DateTime.parse('2026-12-31T16:00:00Z')),
        DateTime.utc(2027),
      );
      expect(
        beijingDate(DateTime.parse('2024-02-28T16:00:00Z')),
        DateTime.utc(2024, 2, 29),
      );
      final instant = DateTime.parse('2026-09-06T16:00:00Z');
      expect(beijingDate(instant.toLocal()), beijingDate(instant));
    },
  );

  test('weeks are start-relative even for a non-Monday start', () {
    final midweek = SemesterCalendar(starts: [DateTime.utc(2026, 9, 9)]);
    expect(midweek.weekAt(DateTime.utc(2026, 9, 14))!.weekNumber, 1);
    expect(midweek.weekAt(DateTime.utc(2026, 9, 16))!.weekNumber, 2);
  });

  test('length defaults to 16 and validates both inclusive limits', () {
    expect(SemesterConfig().weekCount, 16);
    for (final count in [1, 16, 53]) {
      final bounded = SemesterCalendar(
        starts: [start],
        config: SemesterConfig(weekCount: count),
      );
      final end = start
          .add(Duration(days: count * 7))
          .subtract(const Duration(hours: 8));
      expect(
        bounded
            .weekAt(end.subtract(const Duration(microseconds: 1)))!
            .weekNumber,
        count,
      );
      expect(bounded.weekAt(end), isNull);
    }
    for (final invalid in [-1, 0, 54]) {
      expect(() => SemesterConfig(weekCount: invalid), throwsRangeError);
    }
  });

  test(
    'next start supersedes prior semester and expired gaps stay unavailable',
    () {
      final next = DateTime.utc(2026, 9, 10);
      final overlapping = SemesterCalendar(starts: [start, next]);
      expect(overlapping.weekAt(next)!.start, next);
      expect(overlapping.weekAt(next)!.weekNumber, 1);
      final gapped = SemesterCalendar(
        starts: [start, DateTime.utc(2027, 2, 1)],
      );
      expect(gapped.weekAt(DateTime.utc(2027, 1, 20)), isNull);
    },
  );

  test('start contract is strict and defensively copied', () {
    for (final dates in <List<DateTime>>[
      [],
      [start, start],
      [start, start.subtract(const Duration(days: 1))],
      [DateTime(2026, 9, 7)],
      [start.add(const Duration(hours: 1))],
    ]) {
      expect(() => SemesterCalendar(starts: dates), throwsArgumentError);
    }
    final dates = [start];
    final value = SemesterCalendar(starts: dates);
    dates.clear();
    expect(value.starts, [start]);
    expect(() => value.starts.clear(), throwsUnsupportedError);
  });
}
