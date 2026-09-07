import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pku_manager/data/app_database.dart';
import 'package:pku_manager/data/schedule_repository.dart';
import 'package:pku_manager/data/schedule_xls_parser.dart';
import 'package:pku_manager/domain/course_meeting.dart';
import 'package:pku_manager/domain/week_frequency.dart';

void main() {
  test('source edits and empty-cell additions persist without changing source bytes', () {
    final database = AppDatabase(':memory:');
    addTearDown(database.close);
    final repository = ScheduleRepository(database);
    final candidate = ScheduleXlsParser().parseCells(
      Uint8List.fromList([1, 2, 3]),
      [
        ['节数', '星期一', '星期二', '星期三', '星期四', '星期五', '星期六', '星期日'],
        ['1', 'Course(Room)每周', '', '', '', '', '', ''],
        ['2', '', '', '', '', '', '', ''],
      ],
    );
    repository.publish(candidate, {});
    final sourceId = repository.load()!.meetings.single.sourceId;
    repository.saveMeeting(
      CourseMeeting(
        sourceId: sourceId,
        name: 'Edited',
        weekday: 1,
        firstPeriod: 1,
        lastPeriod: 1,
        room: 'New room',
        frequency: WeekFrequency.odd,
        frequencyText: '单周',
        note: 'Note',
        exam: 'Exam',
      ),
    );
    repository.saveMeeting(
      CourseMeeting(
        sourceId: 'user:fixed',
        name: 'Added',
        weekday: 2,
        firstPeriod: 2,
        lastPeriod: 2,
        room: 'Room 2',
      ),
    );

    final restored = repository.load()!;
    expect(restored.meetings.map((meeting) => meeting.name), [
      'Edited',
      'Added',
    ]);
    expect(database.activeSource, [1, 2, 3]);
    repository.removeUserMeeting('user:fixed');
    expect(repository.load()!.meetings.map((meeting) => meeting.name), [
      'Edited',
    ]);
    expect(database.activeSource, [1, 2, 3]);
  });
}
