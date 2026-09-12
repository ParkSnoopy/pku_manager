import 'week_frequency.dart';

/// Validated build policy, independent of the remotely supplied start dates.
final class SemesterConfig {
  SemesterConfig({this.weekCount = 16}) {
    RangeError.checkValueInInterval(weekCount, 1, 53, 'weekCount');
  }

  factory SemesterConfig.fromEnvironment() {
    const raw = String.fromEnvironment('SEMESTER_WEEKS', defaultValue: '16');
    final value = int.tryParse(raw);
    if (value == null) {
      throw FormatException('SEMESTER_WEEKS must be an integer', raw);
    }
    return SemesterConfig(weekCount: value);
  }

  final int weekCount;
}

/// UTC midnight is used as a date-only carrier, not as the Beijing instant.
DateTime beijingDate(DateTime instant) {
  final shifted = instant.toUtc().add(const Duration(hours: 8));
  return DateTime.utc(shifted.year, shifted.month, shifted.day);
}

final class SemesterWeek {
  const SemesterWeek._(this.start, this.date, this.weekNumber);

  final DateTime start;
  final DateTime date;
  final int weekNumber;
  bool get isOdd => weekNumber.isOdd;
  WeekParity get parity => isOdd ? WeekParity.odd : WeekParity.even;
}

final class SemesterCalendar {
  /// Starts must be unique, ascending UTC-midnight calendar dates.
  SemesterCalendar({required Iterable<DateTime> starts, SemesterConfig? config})
    : starts = List.unmodifiable(starts),
      config = config ?? SemesterConfig() {
    if (this.starts.isEmpty) {
      throw ArgumentError.value(starts, 'starts', 'Must not be empty');
    }
    DateTime? previous;
    for (final start in this.starts) {
      if (!start.isUtc ||
          start != DateTime.utc(start.year, start.month, start.day) ||
          (previous != null && !start.isAfter(previous))) {
        throw ArgumentError.value(
          starts,
          'starts',
          'Expected ascending unique UTC-midnight dates',
        );
      }
      previous = start;
    }
  }

  final List<DateTime> starts;
  final SemesterConfig config;

  SemesterWeek? weekAt(DateTime instant) {
    final date = beijingDate(instant);
    for (final start in starts.reversed) {
      if (date.isBefore(start)) continue;
      final week = date.difference(start).inDays ~/ 7 + 1;
      return week <= config.weekCount
          ? SemesterWeek._(start, date, week)
          : null;
    }
    return null;
  }
}
