import 'package:flutter_test/flutter_test.dart';
import 'package:pku_manager/domain/course_meeting.dart';
import 'package:pku_manager/domain/semester.dart';
import 'package:pku_manager/domain/timetable.dart';
import 'package:pku_manager/domain/week_frequency.dart';
import 'package:pku_manager/features/timetable/timetable_side_pane.dart';

void main() {
  test(
    'upcoming list includes each next grouped occurrence in start order',
    () {
      final timetable = Timetable([
        CourseMeeting(
          sourceId: 'first',
          name: 'First',
          weekday: 1,
          firstPeriod: 1,
          lastPeriod: 1,
        ),
        CourseMeeting(
          sourceId: 'second',
          name: 'First',
          weekday: 1,
          firstPeriod: 2,
          lastPeriod: 2,
        ),
        CourseMeeting(
          sourceId: 'later',
          name: 'Later',
          weekday: 2,
          firstPeriod: 3,
          lastPeriod: 3,
          frequency: WeekFrequency.even,
          frequencyText: '双周',
        ),
      ], periodCount: 3);
      final now = DateTime.utc(2026, 9, 6, 23);
      final upcoming = upcomingCourses(
        timetable,
        now,
        calendar: SemesterCalendar(starts: [DateTime.utc(2026, 9, 7)]),
      );
      expect(upcoming.map((item) => item.group.primary.sourceId), [
        'first',
        'later',
      ]);
      expect(upcoming.first.group.meetings, hasLength(2));
      expect(upcoming.first.startsAt, DateTime.utc(2026, 9, 7));
      expect(upcoming.last.startsAt.isAfter(upcoming.first.startsAt), isTrue);
    },
  );
}
