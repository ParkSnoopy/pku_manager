import 'week_frequency.dart';

/// One source occurrence. Human-readable values are retained without trimming.
final class Course {
  Course({
    required this.sourceId,
    required this.name,
    String? sourceName,
    required this.weekday,
    required this.firstPeriod,
    required this.lastPeriod,
    this.room = '',
    this.frequency = WeekFrequency.every,
    this.frequencyText = '每周',
    this.note = '',
    this.exam = '',
  }) : sourceName = sourceName ?? name {
    if (sourceId.trim().isEmpty || name.trim().isEmpty) {
      throw ArgumentError('Source identity and course name must be nonempty');
    }
    RangeError.checkValueInInterval(weekday, 1, 5, 'weekday');
    if (firstPeriod < 1 || lastPeriod < firstPeriod) {
      throw ArgumentError('Periods must be positive and ordered');
    }
  }

  final String sourceId;

  /// Immutable class name parsed from the source workbook.
  /// User-created classes use their initial name as their source name.
  final String sourceName;
  final String name;
  final int weekday;
  final int firstPeriod;
  final int lastPeriod;
  final String room;
  final WeekFrequency frequency;
  final String frequencyText;
  final String note;
  final String exam;
}
