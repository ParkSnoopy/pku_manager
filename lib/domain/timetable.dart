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

  /// Courses with identical displayed details that touch vertically on one day.
  /// Source identities remain separate so a group edit can update each record.
  List<CourseMeetingGroup> groupsForDay(
    int weekday, {
    Set<int> breakAfter = const {},
    bool showAll = true,
    WeekParity? currentParity,
  }) {
    final groups = <CourseMeetingGroup>[];
    for (final meeting in forDay(
      weekday,
      showAll: showAll,
      currentParity: currentParity,
    )) {
      final matchingIndex = groups.lastIndexWhere(
        (group) =>
            group.matches(meeting) &&
            meeting.firstPeriod <= group.lastPeriod + 1 &&
            !_crossesBreak(group.lastPeriod, meeting.firstPeriod, breakAfter),
      );
      if (matchingIndex < 0) {
        groups.add(CourseMeetingGroup._([meeting]));
      } else {
        final previous = groups[matchingIndex];
        groups[matchingIndex] = CourseMeetingGroup._([
          ...previous.meetings,
          meeting,
        ]);
      }
    }
    return List.unmodifiable(groups);
  }

  /// Presentation-only adjacency grouping; every original identity is retained.
  /// Matching labels never imply that source records are the same record.
  List<List<CourseMeeting>> consecutiveGroups({
    bool showAll = true,
    WeekParity? currentParity,
  }) {
    final result = <List<CourseMeeting>>[];
    for (var day = 1; day <= 5; day++) {
      for (final group in groupsForDay(
        day,
        showAll: showAll,
        currentParity: currentParity,
      )) {
        result.add(group.meetings);
      }
    }
    return List.unmodifiable(result);
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

final class CourseMeetingGroup {
  CourseMeetingGroup._(Iterable<CourseMeeting> meetings)
    : meetings = List.unmodifiable(meetings);

  final List<CourseMeeting> meetings;

  CourseMeeting get primary => meetings.first;
  int get weekday => primary.weekday;
  int get firstPeriod => meetings.fold(
    primary.firstPeriod,
    (value, meeting) =>
        meeting.firstPeriod < value ? meeting.firstPeriod : value,
  );
  int get lastPeriod => meetings.fold(
    primary.lastPeriod,
    (value, meeting) => meeting.lastPeriod > value ? meeting.lastPeriod : value,
  );
  String get key => meetings.map((meeting) => meeting.sourceId).join('|');

  bool matches(CourseMeeting meeting) =>
      weekday == meeting.weekday &&
      primary.name == meeting.name &&
      primary.room == meeting.room &&
      primary.frequency == meeting.frequency &&
      primary.frequencyText == meeting.frequencyText &&
      primary.note == meeting.note &&
      primary.exam == meeting.exam;
}

bool _crossesBreak(int previousLast, int nextFirst, Set<int> breakAfter) {
  for (var period = previousLast; period < nextFirst; period++) {
    if (breakAfter.contains(period)) return true;
  }
  return false;
}
