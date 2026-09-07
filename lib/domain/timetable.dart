import 'course_meeting.dart';
import 'week_frequency.dart';

final class Timetable {
  /// Input order is source order and breaks coordinate ties deterministically.
  Timetable(Iterable<CourseMeeting> meetings, {int? periodCount})
    : meetings = _ordered(meetings),
      _periodCount = periodCount {
    if (periodCount != null && periodCount < 1) {
      throw ArgumentError.value(periodCount, 'periodCount', 'Must be positive');
    }
    final ids = <String>{};
    for (final meeting in this.meetings) {
      if (!ids.add(meeting.sourceId)) {
        throw ArgumentError('Duplicate source identity: ${meeting.sourceId}');
      }
      if (periodCount != null && meeting.lastPeriod > periodCount) {
        throw ArgumentError('Meeting exceeds the timetable period bounds');
      }
    }
  }

  final List<CourseMeeting> meetings;
  final int? _periodCount;

  int get periodCount =>
      _periodCount ??
      meetings.fold(0, (max, m) => m.lastPeriod > max ? m.lastPeriod : max);

  List<CourseMeeting> visible({
    bool showAll = true,
    WeekParity? currentParity,
  }) => List.unmodifiable(
    meetings.where((m) => showAll || m.frequency.isCurrent(currentParity)),
  );

  List<CourseMeeting> forDay(
    int weekday, {
    bool showAll = true,
    WeekParity? currentParity,
  }) {
    RangeError.checkValueInInterval(weekday, 1, 5, 'weekday');
    return List.unmodifiable(
      visible(
        showAll: showAll,
        currentParity: currentParity,
      ).where((m) => m.weekday == weekday),
    );
  }

  List<CourseMeeting> atPeriod(
    int weekday,
    int period, {
    bool showAll = true,
    WeekParity? currentParity,
  }) {
    if (period < 1) throw ArgumentError.value(period, 'period');
    return List.unmodifiable(
      forDay(
        weekday,
        showAll: showAll,
        currentParity: currentParity,
      ).where((m) => m.firstPeriod <= period && period <= m.lastPeriod),
    );
  }

  /// Presentation-only adjacency grouping; every original identity is retained.
  /// Matching labels never imply that source records are the same record.
  List<List<CourseMeeting>> consecutiveGroups({
    bool showAll = true,
    WeekParity? currentParity,
  }) {
    final groups = <List<CourseMeeting>>[];
    for (final meeting in visible(
      showAll: showAll,
      currentParity: currentParity,
    )) {
      final previous = groups.isEmpty ? null : groups.last.last;
      if (previous != null &&
          previous.weekday == meeting.weekday &&
          previous.lastPeriod + 1 == meeting.firstPeriod &&
          previous.name == meeting.name &&
          previous.room == meeting.room &&
          previous.frequency == meeting.frequency &&
          previous.frequencyText == meeting.frequencyText &&
          previous.note == meeting.note &&
          previous.exam == meeting.exam) {
        groups.last.add(meeting);
      } else {
        groups.add([meeting]);
      }
    }
    return List.unmodifiable(
      groups.map((g) => List<CourseMeeting>.unmodifiable(g)),
    );
  }

  static List<CourseMeeting> _ordered(Iterable<CourseMeeting> input) {
    final indexed = input.indexed.toList();
    indexed.sort((a, b) {
      for (final compare in [
        a.$2.weekday.compareTo(b.$2.weekday),
        a.$2.firstPeriod.compareTo(b.$2.firstPeriod),
        a.$2.lastPeriod.compareTo(b.$2.lastPeriod),
        a.$1.compareTo(b.$1),
      ]) {
        if (compare != 0) return compare;
      }
      return 0;
    });
    return List.unmodifiable(indexed.map((entry) => entry.$2));
  }
}
