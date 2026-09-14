import 'course.dart';
import 'week_frequency.dart';

final class Timetable {
  /// Input order is source order and breaks coordinate ties deterministically.
  Timetable(Iterable<Course> meetings, {int? periodCount})
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

  final List<Course> meetings;
  final int? _periodCount;

  int get periodCount =>
      _periodCount ??
      meetings.fold(0, (max, m) => m.lastPeriod > max ? m.lastPeriod : max);

  Set<String> get conflictingSourceIds {
    final result = <String>{};
    for (var leftIndex = 0; leftIndex < meetings.length; leftIndex++) {
      final left = meetings[leftIndex];
      for (
        var rightIndex = leftIndex + 1;
        rightIndex < meetings.length;
        rightIndex++
      ) {
        final right = meetings[rightIndex];
        if (left.weekday == right.weekday &&
            left.firstPeriod <= right.lastPeriod &&
            right.firstPeriod <= left.lastPeriod &&
            _frequenciesCanCoincide(left.frequency, right.frequency)) {
          result
            ..add(left.sourceId)
            ..add(right.sourceId);
        }
      }
    }
    return Set.unmodifiable(result);
  }

  List<Course> visible({bool showAll = true, WeekParity? currentParity}) =>
      List.unmodifiable(
        meetings.where((m) => showAll || m.frequency.isCurrent(currentParity)),
      );

  List<Course> forDay(
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

  List<Course> atPeriod(
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

  List<CourseGroup> groupsForDay(
    int weekday, {
    Set<int> breakAfter = const {},
    bool showAll = true,
    WeekParity? currentParity,
  }) {
    final groups = <CourseGroup>[];
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
        groups.add(CourseGroup._([meeting]));
      } else {
        groups[matchingIndex] = CourseGroup._([
          ...groups[matchingIndex].meetings,
          meeting,
        ]);
      }
    }
    return List.unmodifiable(groups);
  }

  static List<Course> _ordered(Iterable<Course> input) {
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

final class CourseGroup {
  CourseGroup._(Iterable<Course> meetings)
    : meetings = List.unmodifiable(meetings);

  final List<Course> meetings;

  Course get primary => meetings.first;
  int get weekday => primary.weekday;
  int get firstPeriod => meetings.first.firstPeriod;
  int get lastPeriod => meetings.fold(
    primary.lastPeriod,
    (value, meeting) => meeting.lastPeriod > value ? meeting.lastPeriod : value,
  );

  bool matches(Course meeting) =>
      weekday == meeting.weekday && primary.sourceName == meeting.sourceName;
}

bool _crossesBreak(int previousLast, int nextFirst, Set<int> breakAfter) {
  for (var period = previousLast; period < nextFirst; period++) {
    if (breakAfter.contains(period)) return true;
  }
  return false;
}

bool _frequenciesCanCoincide(WeekFrequency left, WeekFrequency right) =>
    left == WeekFrequency.every ||
    right == WeekFrequency.every ||
    left == right;
