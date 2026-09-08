import 'package:flutter_test/flutter_test.dart';
import 'package:pku_manager/domain/course_meeting.dart';
import 'package:pku_manager/domain/semester.dart';
import 'package:pku_manager/domain/timetable.dart';
import 'package:pku_manager/domain/week_frequency.dart';
import 'package:pku_manager/features/calendar/calendar_page.dart';

void main() {
  test('calendar occurrences follow semester parity and omit weekends', () {
    final timetable = Timetable([
      CourseMeeting(
        sourceId: 'odd',
        name: 'Odd class',
        weekday: DateTime.monday,
        firstPeriod: 1,
        lastPeriod: 1,
        frequency: WeekFrequency.odd,
        frequencyText: '单周',
      ),
      CourseMeeting(
        sourceId: 'even',
        name: 'Even class',
        weekday: DateTime.monday,
        firstPeriod: 2,
        lastPeriod: 2,
        frequency: WeekFrequency.even,
        frequencyText: '双周',
      ),
    ], periodCount: 2);
    final calendar = SemesterCalendar(starts: [DateTime.utc(2026, 9, 7)]);

    expect(
      calendarCoursesOn(
        timetable,
        DateTime.utc(2026, 9, 7),
        calendar: calendar,
      ).single.primary.sourceId,
      'odd',
    );
    expect(
      calendarCoursesOn(
        timetable,
        DateTime.utc(2026, 9, 14),
        calendar: calendar,
      ).single.primary.sourceId,
      'even',
    );
    expect(
      calendarCoursesOn(
        timetable,
        DateTime.utc(2026, 9, 12),
        calendar: calendar,
      ),
      isEmpty,
    );
  });
}
