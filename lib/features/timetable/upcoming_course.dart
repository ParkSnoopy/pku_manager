import '../../domain/semester.dart';
import '../../domain/timetable.dart';
import 'timetable_style.dart';

final class UpcomingCourse {
  const UpcomingCourse({required this.group, required this.startsAt});

  final CourseGroup group;
  final DateTime startsAt;
}

List<UpcomingCourse> upcomingCourses(
  Timetable timetable,
  DateTime now, {
  SemesterCalendar? calendar,
}) {
  final result = <UpcomingCourse>[];
  final beijingNow = now.toUtc().add(const Duration(hours: 8));
  for (var day = 1; day <= 5; day++) {
    for (final group in timetable.groupsForDay(day)) {
      final start = timetableClassStarts[group.firstPeriod];
      if (start == null) continue;
      final parts = start.split(':').map(int.parse).toList(growable: false);
      for (var offset = 0; offset <= 14; offset++) {
        final beijingDate = DateTime.utc(
          beijingNow.year,
          beijingNow.month,
          beijingNow.day + offset,
        );
        if (beijingDate.weekday != group.weekday) continue;
        final startsAt = DateTime.utc(
          beijingDate.year,
          beijingDate.month,
          beijingDate.day,
          parts[0],
          parts[1],
        ).subtract(const Duration(hours: 8));
        if (!startsAt.isAfter(now)) continue;
        final semesterWeek = calendar?.weekAt(startsAt);
        if (calendar != null && semesterWeek == null) continue;
        if (!group.primary.frequency.isCurrent(semesterWeek?.parity)) continue;
        result.add(UpcomingCourse(group: group, startsAt: startsAt));
        break;
      }
    }
  }
  result.sort((a, b) => a.startsAt.compareTo(b.startsAt));
  return List.unmodifiable(result);
}

List<UpcomingCourse> tomorrowCourses(
  Timetable timetable,
  DateTime now, {
  SemesterCalendar? calendar,
}) {
  final beijingNow = now.toUtc().add(const Duration(hours: 8));
  final tomorrow = DateTime.utc(
    beijingNow.year,
    beijingNow.month,
    beijingNow.day + 1,
  );
  return List.unmodifiable(
    upcomingCourses(timetable, now, calendar: calendar).where((course) {
      final date = course.startsAt.toUtc().add(const Duration(hours: 8));
      return date.year == tomorrow.year &&
          date.month == tomorrow.month &&
          date.day == tomorrow.day;
    }),
  );
}
