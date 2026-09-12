import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pku_manager/data/app_database.dart';
import 'package:pku_manager/data/schedule_repository.dart';
import 'package:pku_manager/data/schedule_xls_parser.dart';
import 'package:pku_manager/data/week_config_parser.dart';
import 'package:pku_manager/data/week_config_repository.dart';
import 'package:pku_manager/domain/course.dart';
import 'package:pku_manager/domain/schedule_import.dart';
import 'package:pku_manager/domain/semester.dart';
import 'package:pku_manager/domain/week_frequency.dart';
import 'package:pku_manager/features/timetable/timetable_controller.dart';

class _Picker implements SchedulePicker {
  Future<Uint8List?> Function() next = () async => null;
  int calls = 0;
  @override
  Future<Uint8List?> pick() {
    calls++;
    return next();
  }
}

// Lifecycle tests substitute workbook decoding with synthetic cells, not a
// private BIFF fixture. The actual production cell parser and persistence run.
class _CellDecoder implements ScheduleDecoder {
  String cell = 'New course(Room B)每周';
  int calls = 0;
  @override
  ScheduleCandidate parse(Uint8List bytes) {
    calls++;
    return ScheduleXlsParser().parseCells(bytes, [
      ['节数', '星期一', '星期二', '星期三', '星期四', '星期五', '星期六', '星期日'],
      ['1', cell, '', '', '', '', '', ''],
      ['2', '', '', '', '', '', '', ''],
    ]);
  }
}

void main() {
  late Directory directory;
  late AppDatabase db;
  late ScheduleRepository schedules;
  late TimetableController controller;
  late _Picker picker;
  late _CellDecoder decoder;
  final original = Uint8List.fromList([0, 1, 2, 255]);
  final selected = Uint8List.fromList([255, 0, 128, 10, 13, 42]);

  setUp(() {
    directory = Directory.systemTemp.createTempSync('pku-import-lifecycle-');
    db = AppDatabase('${directory.path}/schedule.sqlite3');
    schedules = ScheduleRepository(db);
    decoder = _CellDecoder()..cell = 'Existing course(Room A)每周';
    schedules.publish(decoder.parse(original), {});
    decoder.cell = 'New course(Room B)每周';
    decoder.calls = 0;
    picker = _Picker()..next = () async => selected;
    controller = TimetableController(
      schedules: schedules,
      decoder: decoder,
      picker: picker,
      weeks: WeekConfigRepository(
        db,
        WeekConfigParser(SemesterConfig()),
        fetch: () async => 'invalid',
      ),
    )..timetable = schedules.load();
  });
  tearDown(() {
    controller.dispose();
    db.close();
    directory.deleteSync(recursive: true);
  });

  void unchanged() {
    expect(db.activeSource, original);
    expect(schedules.load()!.meetings.single.name, 'Existing course');
    expect(controller.timetable!.meetings.single.name, 'Existing course');
    expect(db.database.select('SELECT * FROM sources'), hasLength(1));
    expect(db.database.select('SELECT * FROM meetings'), hasLength(1));
    expect(db.database.select('SELECT * FROM completions'), isEmpty);
  }

  test('canceling native selection preserves the active timetable', () async {
    picker.next = () async => null;
    await controller.import();
    unchanged();
    expect(controller.importing, isFalse);
    expect(controller.candidate, isNull);
    expect(controller.error, isNull);
    expect(decoder.calls, 0);
  });

  test('picker failure clears busy state and permits retry', () async {
    picker.next = () async =>
        throw const FileSystemException('cannot read selection');
    await controller.import();
    unchanged();
    expect(controller.error, isNotEmpty);
    expect(controller.importing, isFalse);
    expect(controller.candidate, isNull);
    picker.next = () async => selected;
    await controller.import();
    expect(controller.error, isNull);
    expect(db.activeSource, selected);
    expect(controller.timetable!.meetings.single.name, 'New course');
  });

  test(
    'actual BIFF decoder rejects invalid bytes without touching publication',
    () async {
      controller.dispose();
      controller = TimetableController(
        schedules: schedules,
        decoder: ScheduleXlsParser(),
        picker: picker,
        weeks: WeekConfigRepository(
          db,
          WeekConfigParser(SemesterConfig()),
          fetch: () async => 'invalid',
        ),
      )..timetable = schedules.load();
      await controller.import();
      unchanged();
      expect(controller.error, isNotEmpty);
      expect(controller.candidate, isNull);
      expect(controller.importing, isFalse);
    },
  );

  test(
    'incomplete review never publishes and reject discards only candidate',
    () async {
      decoder.cell = 'Needs room';
      await controller.import();
      final candidate = controller.candidate!;
      expect(candidate.issues, hasLength(1));
      unchanged();
      controller.complete({});
      expect(controller.candidate, same(candidate));
      expect(controller.error, isNotEmpty);
      unchanged();
      controller.reject();
      expect(controller.candidate, isNull);
      expect(controller.error, isNull);
      unchanged();
      decoder.cell = 'New course(Room B)每周';
      await controller.import();
      expect(db.activeSource, selected);
    },
  );

  test('review completion persists exact bytes, raw text and all edits across reopen', () async {
    decoder.cell = 'Needs room';
    final input = Uint8List.fromList(selected);
    picker.next = () async => input;
    await controller.import();
    final candidate = controller.candidate!;
    final id = candidate.issues.single.meeting.sourceId;
    input.fillRange(0, input.length, 99);
    expect(candidate.bytes, selected);
    final completed = Course(
      sourceId: id,
      name: 'Completed course',
      weekday: 5,
      firstPeriod: 1,
      lastPeriod: 2,
      room: 'Room C',
      frequency: WeekFrequency.even,
      frequencyText: '双周',
      note: 'Reviewed note',
      exam: 'Reviewed exam',
    );
    controller.complete({id: completed});
    expect(controller.error, isNull);
    expect(controller.candidate, isNull);
    expect(controller.timetable!.meetings.single.name, 'Completed course');
    expect(db.activeSource, selected);
    db.close();
    db = AppDatabase('${directory.path}/schedule.sqlite3');
    schedules = ScheduleRepository(db);
    final stored = schedules.load()!.meetings.single;
    expect(db.activeSource, selected);
    expect(stored.sourceId, id);
    expect(stored.name, completed.name);
    expect(stored.room, completed.room);
    expect(stored.weekday, completed.weekday);
    expect(stored.firstPeriod, completed.firstPeriod);
    expect(stored.lastPeriod, completed.lastPeriod);
    expect(stored.frequency, completed.frequency);
    expect(stored.frequencyText, completed.frequencyText);
    expect(stored.note, completed.note);
    expect(stored.exam, completed.exam);
    final raw = db.database.select(
      'SELECT raw FROM meetings JOIN active_schedule a ON a.source = meetings.source',
    );
    expect(raw.single['raw'], 'Needs room');
    expect(db.database.select('SELECT * FROM sources'), hasLength(2));
    expect(db.database.select('SELECT * FROM issues'), hasLength(1));
    expect(db.database.select('SELECT * FROM completions'), hasLength(1));
  });

  test('publication abort rolls back inserted rows and retry uses retained candidate', () async {
    db.database.execute(
      "CREATE TRIGGER fail_publication BEFORE UPDATE ON active_schedule BEGIN SELECT RAISE(ABORT, 'test fault'); END;",
    );
    await controller.import();
    unchanged();
    expect(controller.error, isNotEmpty);
    expect(controller.candidate, isNotNull);
    expect(controller.importing, isFalse);
    db.database.execute('DROP TRIGGER fail_publication');
    controller.complete({});
    expect(controller.error, isNull);
    expect(controller.candidate, isNull);
    expect(db.activeSource, selected);
    expect(controller.timetable!.meetings.single.name, 'New course');
    expect(db.database.select('SELECT * FROM sources'), hasLength(2));
  });

  test('overlapping selections are single-flight; pending review blocks another picker', () async {
    decoder.cell = 'Needs room';
    final pending = Completer<Uint8List?>();
    picker.next = () => pending.future;
    final first = controller.import();
    expect(controller.importing, isTrue);
    await controller.import();
    expect(picker.calls, 1);
    expect(decoder.calls, 0);
    pending.complete(selected);
    await first;
    expect(decoder.calls, 1);
    expect(controller.importing, isFalse);
    expect(controller.candidate, isNotNull);
    await controller.import();
    expect(picker.calls, 1);
    unchanged();
    controller.reject();
    picker.next = () async => null;
    await controller.import();
    expect(picker.calls, 2);
    unchanged();
  });

  test('disposing during selection prevents decode and publication', () async {
    final pending = Completer<Uint8List?>();
    picker.next = () => pending.future;
    final operation = controller.import();
    controller.dispose();
    pending.complete(selected);
    await operation;
    expect(decoder.calls, 0);
    unchanged();
    // Replace the disposed controller so teardown owns one live instance.
    controller = TimetableController(
      schedules: schedules,
      decoder: decoder,
      picker: picker,
      weeks: WeekConfigRepository(
        db,
        WeekConfigParser(SemesterConfig()),
        fetch: () async => 'invalid',
      ),
    );
  });
}
