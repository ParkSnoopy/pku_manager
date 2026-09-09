import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pku_manager/data/app_database.dart';
import 'package:pku_manager/data/calendar_schedule_repository.dart';
import 'package:pku_manager/data/schedule_repository.dart';
import 'package:pku_manager/data/schedule_xls_parser.dart';
import 'package:pku_manager/data/week_config_parser.dart';
import 'package:pku_manager/data/week_config_repository.dart';
import 'package:pku_manager/domain/semester.dart';
import 'package:pku_manager/domain/course.dart';
import 'package:pku_manager/domain/week_source.dart';

void main() {
  test('calendar schedules persist independently in start order', () {
    final directory = Directory.systemTemp.createTempSync('pku-calendar-');
    addTearDown(() => directory.deleteSync(recursive: true));
    final path = '${directory.path}/calendar.sqlite3';
    var db = AppDatabase(path);
    var repository = CalendarScheduleRepository(db);
    final later = repository.create(
      title: '  Homework deadline  ',
      startsAt: DateTime.utc(2026, 9, 8, 2),
      allDay: true,
      relatedClassSourceId: 'source-class',
      note: 'Bring notes',
      colorValue: 0xff123456,
    );
    final earlier = repository.create(
      title: 'Meeting info',
      startsAt: DateTime.utc(2026, 9, 7, 1),
    );

    expect(repository.load().map((schedule) => schedule.id), [
      earlier.id,
      later.id,
    ]);
    expect(repository.load().first.colorValue, isNull);
    expect(
      db.database.select('SELECT color FROM calendar_schedules WHERE id = ?', [
        earlier.id,
      ]).single['color'],
      0,
    );
    expect(earlier.startsAt, DateTime.utc(2026, 9, 7, 15, 59));
    expect(repository.load().last.title, 'Homework deadline');
    expect(repository.load().last.allDay, isTrue);
    expect(repository.load().last.relatedClassSourceId, 'source-class');
    expect(repository.load().last.note, 'Bring notes');
    expect(repository.load().last.colorValue, 0xff123456);
    expect(later.startsAt, DateTime.utc(2026, 9, 8, 15, 59));

    repository.update(later.copyWith(colorValue: null));
    expect(repository.load().last.colorValue, isNull);
    expect(
      db.database.select('SELECT color FROM calendar_schedules WHERE id = ?', [
        later.id,
      ]).single['color'],
      0,
    );

    repository.update(
      later.copyWith(
        title: 'Revised deadline',
        startsAt: DateTime.utc(2026, 9, 9, 3),
        allDay: false,
        relatedClassSourceId: null,
        note: 'Revised note',
        colorValue: 0xff654321,
      ),
    );
    repository.remove(earlier.id);
    db.close();

    db = AppDatabase(path);
    repository = CalendarScheduleRepository(db);
    expect(repository.load().single.title, 'Revised deadline');
    expect(repository.load().single.allDay, isFalse);
    expect(repository.load().single.relatedClassSourceId, isNull);
    expect(repository.load().single.note, 'Revised note');
    expect(repository.load().single.colorValue, 0xff654321);
    expect(repository.load().single.id, later.id);
    db.close();
  });

  test(
    'SQLite publication is transactional and source bytes are immutable',
    () {
      final db = AppDatabase(':memory:');
      addTearDown(db.close);
      final repository = ScheduleRepository(db);
      final parser = ScheduleXlsParser();
      final candidate = parser.parseCells(Uint8List.fromList([1, 2, 3]), [
        ['节数', '星期一', '星期二', '星期三', '星期四', '星期五', '星期六', '星期日'],
        ['第一节', 'Course(Room)(备注：) 每周考试方式：论文', '', '', '', '', '', ''],
      ]);
      repository.publish(candidate, {});
      expect(repository.load()!.meetings.single.name, 'Course');
      expect(db.activeSource, [1, 2, 3]);
      expect(
        () =>
            db.database.execute('UPDATE sources SET bytes = ?', [Uint8List(1)]),
        throwsException,
      );
      expect(
        () => db.transaction(() {
          db.database.execute('DELETE FROM active_schedule');
          throw StateError('interrupted');
        }),
        throwsStateError,
      );
      expect(db.activeSource, [1, 2, 3]);
    },
  );

  test('publication creates localized final-exam schedules once', () {
    final db = AppDatabase(':memory:');
    addTearDown(db.close);
    final repository = ScheduleRepository(db);
    final candidate = ScheduleXlsParser().parseCells(
      Uint8List.fromList([4, 5, 6]),
      [
        ['节数', '星期一', '星期二', '星期三', '星期四', '星期五', '星期六', '星期日'],
        [
          '第一节',
          'Course(Room)每周考试：2027年1月10日上午',
          'Lab(Room)每周考试：2027年1月10日下午',
          'Seminar(Room)每周考试：2027年1月10日晚上',
          '',
          '',
          '',
          '',
        ],
        ['第二节', 'Course(Room)每周考试：2027年1月10日上午', '', '', '', '', '', ''],
      ],
    );

    repository.publish(candidate, {}, finalExamTitle: '期末考试');
    repository.publish(candidate, {}, finalExamTitle: '期末考试');
    final exams = CalendarScheduleRepository(db).load();
    expect(exams, hasLength(3));
    expect(exams.map((exam) => exam.title).toSet(), {'期末考试'});
    expect(exams.map((exam) => exam.startsAt), [
      DateTime.utc(2027, 1, 10),
      DateTime.utc(2027, 1, 10, 5),
      DateTime.utc(2027, 1, 10, 10, 40),
    ]);
    expect(exams.every((exam) => !exam.allDay), isTrue);
    expect(exams.every((exam) => exam.relatedClassSourceId != null), isTrue);
    expect(exams.first.note, '考试：2027年1月10日上午');
  });

  test(
    'week configuration validates dates and keeps last valid cache',
    () async {
      final db = AppDatabase(':memory:');
      addTearDown(db.close);
      const valid = 'base_date = ["2026-09-07"]\ntimezone = "Asia/Shanghai"';
      final parser = WeekConfigParser(SemesterConfig());
      expect(
        () => parser.parse(valid.replaceFirst('09-07', '02-30')),
        throwsFormatException,
      );
      var body = valid;
      final repository = WeekConfigRepository(
        db,
        parser,
        fetch: () async => body,
      );
      expect((await repository.refresh()).freshness, WeekFreshness.fresh);
      body = 'invalid';
      expect((await repository.refresh()).freshness, WeekFreshness.stale);
      expect(
        repository.cached().calendar!.starts.single,
        DateTime.utc(2026, 9, 7),
      );
    },
  );

  test('private local workbook round-trips without source modification', () {
    const path = String.fromEnvironment('SCHEDULE_FIXTURE');
    if (path.isEmpty) return;
    final bytes = File(path).readAsBytesSync();
    final candidate = ScheduleXlsParser().parse(bytes);
    expect(candidate.records, isNotEmpty);
    // Incomplete rooms/tutorial alternatives require explicit user completion;
    // synthetic corrections here test persistence, not the user's real choices.
    final completions = {
      for (final r in candidate.issues)
        r.meeting.sourceId: Course(
          sourceId: r.meeting.sourceId,
          name: r.meeting.name,
          room: 'Synthetic user completion',
          weekday: r.meeting.weekday,
          firstPeriod: r.meeting.firstPeriod,
          lastPeriod: r.meeting.lastPeriod,
          frequency: r.meeting.frequency,
          frequencyText: r.meeting.frequencyText,
          note: r.meeting.note,
          exam: r.meeting.exam,
        ),
    };
    final directory = Directory.systemTemp.createTempSync('pku-database-');
    addTearDown(() => directory.deleteSync(recursive: true));
    final databasePath = '${directory.path}/test.sqlite3';
    var db = AppDatabase(databasePath);
    ScheduleRepository(db).publish(candidate, completions);
    expect(db.activeSource, bytes);
    db.close();
    db = AppDatabase(databasePath);
    expect(
      ScheduleRepository(db).load()!.meetings.length,
      candidate.records.length,
    );
    expect(db.activeSource, bytes);
    expect(File(path).readAsBytesSync(), bytes);
    db.close();
  });
}
