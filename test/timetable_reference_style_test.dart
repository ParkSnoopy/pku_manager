import 'package:flutter_test/flutter_test.dart';
import 'package:pku_manager/domain/course_meeting.dart';
import 'package:pku_manager/domain/timetable.dart';
import 'package:pku_manager/features/timetable/timetable_style.dart';

void main() {
  test('12-period geometry matches the pages reference', () {
    const geometry = TimetableGeometry(12);

    expect(geometry.height, 1304);
    expect(geometry.courseWidth, 276);
    expect(geometry.width, 1500);
    expect(geometry.exportWidth, 6096);
    expect(geometry.exportHeight, 5312);
  });

  test('class times and 50-minute endings match the reference', () {
    expect(timetableClassStarts[1], '08:00');
    expect(timetableClassEnd(timetableClassStarts[1]!), '08:50');
    expect(timetableClassStarts[12], '20:40');
    expect(timetableClassEnd(timetableClassStarts[12]!), '21:30');
  });

  test('course names fit eight CJK characters and scale longer names down', () {
    expect(timetableCourseNameFontSize('八个汉字课程名称', 232), 28);
    expect(timetableCourseNameFontSize('十六个汉字课程名称需要缩小字号啊', 232), 14);
    expect(timetableCourseNameFontSize('A', 232), 28);
  });

  test('screen and PNG share grouped span and collision-lane geometry', () {
    final timetable = Timetable([
      CourseMeeting(
        sourceId: 'first',
        name: 'Grouped',
        weekday: 1,
        firstPeriod: 1,
        lastPeriod: 1,
      ),
      CourseMeeting(
        sourceId: 'second',
        name: 'Grouped',
        weekday: 1,
        firstPeriod: 2,
        lastPeriod: 2,
      ),
      CourseMeeting(
        sourceId: 'collision',
        name: 'Collision',
        weekday: 1,
        firstPeriod: 2,
        lastPeriod: 3,
      ),
    ], periodCount: 3);
    final layout = TimetableDayLayout.from(timetable, 1);
    expect(layout.laneCount, 2);
    expect(layout.spans, hasLength(2));
    expect(layout.spans.first.firstPeriod, 1);
    expect(layout.spans.first.lastPeriod, 2);
    expect(layout.spans.first.group.meetings, hasLength(2));
    expect(layout.spans.last.lane, 1);
  });
}
