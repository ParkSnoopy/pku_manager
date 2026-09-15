import 'dart:io';
import 'dart:typed_data';

import 'package:excel2003/excel2003.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pku_manager/data/schedule_xls_parser.dart';
import 'package:pku_manager/domain/schedule_import.dart';
import 'package:pku_manager/domain/week_frequency.dart';

const header = ['节数', '星期一', '星期二', '星期三', '星期四', '星期五', '星期六', '星期日'];
List<String> row(String period, [String value = '', int day = 1]) => [
  period,
  for (var d = 1; d <= 7; d++) d == day ? value : '',
];

void main() {
  final parser = ScheduleXlsParser();
  final bytes = Uint8List.fromList([4, 5, 6]);

  test('optional ASCII-colon remark and nested note retain metadata', () {
    const raw =
        'Synthetic Lab(甲)(Room A)(备注: bring notes (draft))隔三周考试: later(extra)';
    final r = parser.parseRecord('source', raw, 1, 1);
    expect(r.issue, isNull);
    expect(r.raw, raw);
    expect(r.meeting.name, 'Synthetic Lab(甲)');
    expect(r.meeting.room, 'Room A');
    expect(r.meeting.note, 'bring notes (draft)；extra');
    expect(r.meeting.frequencyText, '每周');
    expect(r.meeting.frequency, WeekFrequency.every);
    expect(r.meeting.exam, '考试: later');
  });

  test('unbalanced notes remain reviewable', () {
    final r = parser.parseRecord(
      'source',
      'Synthetic Lab(Room A)(备注: unfinished',
      1,
      1,
    );
    expect(r.issue, isNotNull);
    expect(r.failedFields, {ImportField.note});
    expect(r.raw, contains('unfinished'));
  });

  test(
    'paired detail rows preserve raw cells and physical source identity',
    () {
      const upper = 'Synthetic Lab(Room A)单周';
      const lower = '备注：bring notes；考试：later';
      final c = parser.parseCells(bytes, [
        header,
        row('1', upper),
        row('', lower),
        row('2', upper),
      ]);
      expect(c.records, hasLength(2));
      expect(c.records.first.issue, isNull);
      expect(c.records.first.raw, '$upper\n$lower');
      expect(c.records.first.meeting.note, 'bring notes');
      expect(c.records.first.meeting.exam, '考试：later');
      expect(c.records.first.meeting.frequency, WeekFrequency.odd);
      expect(c.records.last.meeting.sourceId, 'sheet:0/row:3/column:1');
      expect(c.periodCount, 2);
    },
  );

  test('formatted two-line heading and paired details are imported', () {
    final c = parser.parseCells(bytes, [
      header,
      row('1', 'Synthetic Lab\nRoom A 每周'),
      row('', 'bring notes\n考试：later'),
      row('2'),
    ]);
    final r = c.records.single;
    expect(r.issue, isNull);
    expect(r.meeting.name, 'Synthetic Lab');
    expect(r.meeting.room, 'Room A');
    expect(r.meeting.note, 'bring notes');
    expect(r.meeting.exam, '考试：later');
    expect(r.meeting.frequency, WeekFrequency.every);
  });

  test(
    'original formatted subtitle maps unsupported frequency to every week',
    () {
      const upper = ' Synthetic Lab\n（Room A，隔三周）';
      final c = parser.parseCells(bytes, [
        ['', '周一', '周二', '周三', '周四', '周五', '周六', '周日'],
        row('第 1 节\n08:00-08:50', upper),
        row('', 'bring notes\n考试：later'),
        row('第 2 节\n09:00-09:50'),
      ]);
      final r = c.records.single;
      expect(r.issue, isNull);
      expect(r.meeting.name, 'Synthetic Lab');
      expect(r.meeting.room, 'Room A');
      expect(r.meeting.frequencyText, '每周');
      expect(r.meeting.frequency, WeekFrequency.every);
      expect(r.meeting.note, 'bring notes');
      expect(r.raw, '$upper\nbring notes\n考试：later');
      expect(c.periodCount, 2);
    },
  );

  test('unrecognized or orphan detail cells fail closed', () {
    for (final detail in [row('', 'unrecognized'), row('', '备注：orphan', 2)]) {
      expect(
        () => parser.parseCells(bytes, [
          header,
          row('1', 'Synthetic Lab(Room A)每周'),
          detail,
        ]),
        throwsFormatException,
      );
    }
  });

  test('exported timetable without a Sunday column is imported', () {
    final c = parser.parseCells(bytes, [
      ['节数', '星期一', '星期二', '星期三', '星期四', '星期五', '星期六'],
      row('第一节', 'Synthetic Lab(Room A)每周').take(7).toList(),
    ]);
    expect(c.records.single.meeting.name, 'Synthetic Lab');
  });

  for (final note in [
    '习题课上课时间：每周四8-9，上课教室：Room B',
    '习题课双周四8-9节，教室：Room B',
    '习题课每周日8-9节，教室：Room B',
  ]) {
    test('tutorial expands deterministically without overwriting: $note', () {
      final raw = 'Synthetic Lab(Room A)(备注：$note)单周';
      final matrix = [
        header,
        row('1', raw),
        row('2', raw),
        for (var p = 3; p <= 12; p++)
          row('$p', p == 8 ? 'Other Lab(Room B)每周' : '', 4),
      ];
      final c = parser.parseCells(bytes, matrix);
      final again = parser.parseCells(bytes, matrix);
      expect(c.issues, note.contains('周日') ? hasLength(1) : isEmpty);
      expect(c.records, hasLength(4));
      expect(c.records.where((r) => r.raw == raw), hasLength(2));
      final tutorials = c.records
          .where((r) => r.meeting.sourceId.endsWith('/tutorial'))
          .toList();
      expect(tutorials, hasLength(1));
      for (final t in tutorials) {
        expect(t.raw, note);
        expect(t.meeting.name, 'Synthetic Lab 习题课');
        expect(t.meeting.room, 'Room B');
        expect(t.meeting.firstPeriod, 8);
        expect(t.meeting.lastPeriod, 9);
        expect(t.meeting.weekday, note.contains('周日') ? 1 : 4);
        expect(
          t.meeting.frequency,
          note.contains('双周') ? WeekFrequency.even : WeekFrequency.every,
        );
        expect(t.meeting.note, isEmpty);
      }
      expect(
        c.records.where((r) => r.raw == raw).map((r) => r.meeting.note),
        everyElement(isEmpty),
      );
      expect(c.records.map((r) => r.meeting.sourceId).toSet(), hasLength(4));
      expect(
        c.records.map((r) => r.meeting.sourceId),
        again.records.map((r) => r.meeting.sourceId),
      );
    });
  }

  for (final entry in [
    (
      '习题课时间地点待定',
      {
        ImportField.frequency,
        ImportField.weekday,
        ImportField.firstPeriod,
        ImportField.lastPeriod,
        ImportField.room,
      },
    ),
    ('习题课每周四8-9节，教室：Room B、Room C', {ImportField.room}),
    (
      '习题课每周四54-55节，教室：Room B',
      {ImportField.firstPeriod, ImportField.lastPeriod},
    ),
    ('习题课每周四9-8节，教室：Room B', {ImportField.lastPeriod}),
    ('习题课隔三周四8-9节，教室：Room B', {ImportField.frequency}),
  ]) {
    test('ambiguous tutorial identifies only failed fields: ${entry.$1}', () {
      final note = entry.$1;
      final raw = 'Synthetic Lab(Room A)(备注：$note)单周';
      final c = parser.parseCells(bytes, [
        header,
        row('1', raw),
        for (var p = 2; p <= 12; p++) row('$p'),
      ]);
      expect(c.records, hasLength(2));
      expect(c.records.first.raw, raw);
      expect(c.records.first.issue, isNull);
      final issue = c.issues.single;
      expect(issue.raw, note);
      expect(issue.meeting.note, isEmpty);
      expect(issue.meeting.name, 'Synthetic Lab 习题课');
      expect(issue.meeting.sourceId, 'sheet:0/row:1/column:1/tutorial');
      expect(issue.failedFields, entry.$2);
    });
  }

  // Opt-in local verification: no private workbook contents or bytes become fixtures.
  final samplePath = Platform.environment['SCHEDULE_SAMPLE_PATH'];
  if (samplePath != null) {
    test('approved local BIFF8 workbook parses without mutating source bytes', () {
      final original = File(samplePath).readAsBytesSync();
      final snapshot = Uint8List.fromList(original);
      final sheet = XlsReader.fromBytes(original).sheet(0);
      final c = parser.parse(original);
      expect(c.records, isNotEmpty);
      expect(c.periodCount, greaterThan(0));
      expect(c.bytes, snapshot);
      expect(original, snapshot);
      expect(File(samplePath).readAsBytesSync(), snapshot);
      // ignore: avoid_print -- explicit opt-in local verification summary.
      print(
        'Local BIFF8: ${sheet.rowCount} rows, ${sheet.colCount} columns; ${c.periodCount} periods, ${c.records.length} records, ${c.issues.length} review issues.',
      );
    });
  }
}
