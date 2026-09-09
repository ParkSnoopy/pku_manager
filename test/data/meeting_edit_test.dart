import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pku_manager/data/app_database.dart';
import 'package:pku_manager/data/calendar_schedule_repository.dart';
import 'package:pku_manager/data/schedule_repository.dart';
import 'package:pku_manager/data/schedule_xls_parser.dart';
import 'package:pku_manager/domain/course.dart';
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
      Course(
        sourceId: sourceId,
        name: 'Edited',
        shortName: 'Short',
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
      Course(
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
    expect(restored.meetings.first.sourceName, 'Course');
    expect(restored.meetings.first.shortName, 'Short');
    expect(restored.meetings.first.displayName, 'Short');
    expect(database.activeSource, [1, 2, 3]);
    repository.removeMeeting('user:fixed');
    expect(repository.load()!.meetings.map((meeting) => meeting.name), [
      'Edited',
    ]);
    expect(database.activeSource, [1, 2, 3]);

    final scheduleRepository = CalendarScheduleRepository(database);
    scheduleRepository.create(
      title: 'Related deadline',
      startsAt: DateTime.utc(2026, 9, 8),
      relatedClassSourceId: sourceId,
    );
    final source =
        database.database
                .select('SELECT source FROM active_schedule WHERE id = 1')
                .single['source']
            as int;
    database.database.execute(
      'INSERT INTO course_appearance VALUES (?, ?, NULL, 0, 1, ?, 1.5)',
      [source, sourceId, 0xff123456],
    );
    repository.removeMeeting(sourceId);
    expect(repository.load()!.meetings, isEmpty);
    expect(database.activeSource, [1, 2, 3]);
    expect(
      database.database.select(
        'SELECT 1 FROM completions WHERE source = ? AND identity = ?',
        [source, sourceId],
      ),
      isEmpty,
    );
    expect(
      database.database.select(
        'SELECT 1 FROM course_appearance WHERE source = ? AND identity = ?',
        [source, sourceId],
      ),
      isEmpty,
    );
    expect(scheduleRepository.load().single.relatedClassSourceId, isNull);
  });

  test('group edits commit atomically and preserve immutable source bytes', () {
    final database = AppDatabase(':memory:');
    addTearDown(database.close);
    final repository = ScheduleRepository(database);
    final candidate = ScheduleXlsParser().parseCells(
      Uint8List.fromList([7, 8, 9]),
      [
        ['节数', '星期一', '星期二', '星期三', '星期四', '星期五', '星期六', '星期日'],
        ['1', 'Course(Room)每周', '', '', '', '', '', ''],
        ['2', 'Course(Room)每周', '', '', '', '', '', ''],
      ],
    );
    final published = repository.publish(candidate, {});
    final group = published.groupsForDay(1).single;
    repository.saveMeetings([
      for (final meeting in group.meetings)
        Course(
          sourceId: meeting.sourceId,
          name: 'Edited together',
          weekday: 1,
          firstPeriod: meeting.firstPeriod,
          lastPeriod: meeting.lastPeriod,
          room: 'New room',
        ),
    ]);
    expect(
      repository.load()!.meetings.map((meeting) => meeting.name),
      everyElement('Edited together'),
    );
    expect(database.activeSource, [7, 8, 9]);

    expect(
      () => repository.saveMeetings([
        Course(
          sourceId: group.meetings.first.sourceId,
          name: 'Must roll back',
          weekday: 1,
          firstPeriod: 1,
          lastPeriod: 1,
        ),
        Course(
          sourceId: 'not-active',
          name: 'Invalid',
          weekday: 1,
          firstPeriod: 2,
          lastPeriod: 2,
        ),
      ]),
      throwsArgumentError,
    );
    expect(
      repository.load()!.meetings.map((meeting) => meeting.name),
      everyElement('Edited together'),
    );

    expect(
      () => repository.removeMeetings([
        group.meetings.first.sourceId,
        'not-active',
      ]),
      throwsArgumentError,
    );
    expect(repository.load()!.meetings, hasLength(2));
    repository.removeMeetings(
      group.meetings.map((meeting) => meeting.sourceId),
    );
    expect(repository.load()!.meetings, isEmpty);
    expect(database.activeSource, [7, 8, 9]);
  });
}
