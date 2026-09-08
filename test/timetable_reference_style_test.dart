import 'package:flutter_test/flutter_test.dart';
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
}
