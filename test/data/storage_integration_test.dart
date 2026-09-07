import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pku_manager/data/app_database.dart';
import 'package:pku_manager/data/schedule_repository.dart';
import 'package:pku_manager/data/schedule_xls_parser.dart';
import 'package:pku_manager/data/week_config_parser.dart';
import 'package:pku_manager/data/week_config_repository.dart';
import 'package:pku_manager/domain/semester.dart';
import 'package:pku_manager/domain/course_meeting.dart';
import 'package:pku_manager/domain/week_source.dart';

void main() {
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
        r.meeting.sourceId: CourseMeeting(
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
