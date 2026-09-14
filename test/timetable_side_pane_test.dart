import 'package:flutter_test/flutter_test.dart';
import 'package:pku_manager/domain/course.dart';
import 'package:pku_manager/domain/semester.dart';
import 'package:pku_manager/domain/timetable.dart';

import 'package:pku_manager/features/timetable/upcoming_course.dart';

void main() {
  test('tomorrow list includes every source cell in start order', () {
    final timetable = Timetable([
      Course(
        sourceId: 'first',
        name: 'First',
        weekday: 1,
        firstPeriod: 1,
        lastPeriod: 1,
      ),
      Course(
        sourceId: 'second',
        name: 'First',
        weekday: 1,
        firstPeriod: 2,
        lastPeriod: 2,
      ),
      Course(
        sourceId: 'later',
        name: 'Third',
        weekday: 1,
        firstPeriod: 3,
        lastPeriod: 3,
      ),
      Course(
        sourceId: 'another-day',
        name: 'Later',
        weekday: 2,
        firstPeriod: 1,
        lastPeriod: 1,
      ),
    ], periodCount: 3);
    final now = DateTime.utc(2026, 9, 6);
    final upcoming = tomorrowCourses(
      timetable,
      now,
      calendar: SemesterCalendar(starts: [DateTime.utc(2026, 9, 7)]),
    );
    expect(upcoming.map((item) => item.meeting.sourceId), [
      'first',
      'second',
      'later',
    ]);
    expect(upcoming.first.startsAt, DateTime.utc(2026, 9, 7));
    expect(upcoming.last.startsAt, DateTime.utc(2026, 9, 7, 2, 10));
  });
}
