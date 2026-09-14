import 'package:flutter_test/flutter_test.dart';
import 'package:pku_manager/domain/course.dart';
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

  test('course and classroom typography use the same fixed base size', () {
    expect(timetableCourseNameFontSize, 22.5);
    expect(timetableClassroomFontSize, 22.5);
    expect(timetableCourseContentPadding, 10);
  });

  test('screen and PNG keep source cells separate in collision lanes', () {
    final timetable = Timetable([
      Course(
        sourceId: 'first',
        name: 'Grouped',
        weekday: 1,
        firstPeriod: 1,
        lastPeriod: 1,
      ),
      Course(
        sourceId: 'second',
        name: 'User-renamed display',
        sourceName: 'Grouped',
        weekday: 1,
        firstPeriod: 2,
        lastPeriod: 2,
      ),
      Course(
        sourceId: 'collision',
        name: 'Collision',
        weekday: 1,
        firstPeriod: 2,
        lastPeriod: 3,
      ),
    ], periodCount: 3);
    final layout = TimetableDayLayout.from(timetable, 1);
    expect(layout.laneCount, 2);
    expect(layout.spans, hasLength(3));
    expect(layout.spans.first.firstPeriod, 1);
    expect(layout.spans.first.lastPeriod, 1);
    expect(layout.spans.first.meeting.sourceId, 'first');
    expect(layout.spans[1].firstPeriod, 2);
    expect(layout.spans[1].lastPeriod, 2);
    expect(layout.spans.last.lane, 1);
  });
}
