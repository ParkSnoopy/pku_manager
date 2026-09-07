import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pku_manager/data/schedule_xls_parser.dart';
import 'package:pku_manager/domain/schedule_import.dart';
import 'package:pku_manager/domain/timetable.dart';
import 'package:pku_manager/domain/week_frequency.dart';

const _header = ['节数', '星期一', '星期二', '星期三', '星期四', '星期五', '星期六', '星期日'];
const _plain = '示例课程(实验楼A)(备注：携带纸笔)每周考试：另行通知';
List<String> _row(String period, {int day = 1, String value = ''}) => [
  period,
  for (var d = 1; d <= 7; d++) d == day ? value : '',
];

void main() {
  final parser = ScheduleXlsParser();
  ImportRecord record(String text) =>
      parser.parseRecord('synthetic:one', text, 3, 4);
  ScheduleCandidate cells(List<List<String>> rows) =>
      parser.parseCells(Uint8List.fromList([11, 22, 33]), rows);

  for (final c in [
    ('每周', WeekFrequency.every),
    ('单周', WeekFrequency.odd),
    ('双周', WeekFrequency.even),
  ]) {
    test('E01 known frequency ${c.$1} and five source fields', () {
      final r = record('示例课程(实验楼A)(备注：携带纸笔)${c.$1}考试：另行通知');
      expect(r.issue, isNull);
      expect(r.meeting.name, '示例课程');
      expect(r.meeting.room, '实验楼A');
      expect(r.meeting.note, '携带纸笔');
      expect(r.meeting.frequencyText, c.$1);
      expect(r.meeting.frequency, c.$2);
      expect(r.meeting.exam, '考试：另行通知');
      expect(
        (r.meeting.weekday, r.meeting.firstPeriod, r.meeting.lastPeriod),
        (3, 4, 4),
      );
    });
  }
  test('E02 fullwidth structural parentheses are supported', () {
    final r = record('示例课程（实验楼A）（备注：携带纸笔）单周考试：另行通知');
    expect(r.issue, isNull);
    expect(r.meeting.name, '示例课程');
    expect(r.meeting.room, '实验楼A');
    expect(r.meeting.note, '携带纸笔');
  });
  test('E03 one-character title qualifiers remain part of the title', () {
    final r = record('示例课程(甲)(乙)(实验楼A)(备注：携带纸笔)每周考试：另行通知');
    expect(r.meeting.name, contains('(甲)'));
    expect(r.meeting.name, contains('(乙)'));
    expect(r.meeting.room, '实验楼A');
  });
  test('E04 spacing in human text and exact raw record survive', () {
    const raw = 'Synthetic Seminar(实验楼 A)(备注：bring a pen)每周考试：to be arranged';
    final r = record(raw);
    expect(r.raw, raw);
    expect(r.meeting.name, 'Synthetic Seminar');
    expect(r.meeting.room, '实验楼 A');
    expect(r.meeting.note, 'bring a pen');
  });
  test('E05 empty remark is valid', () {
    final r = record('示例课程(实验楼A)(备注：)每周考试：另行通知');
    expect(r.meeting.note, isEmpty);
    expect(r.issue, isNull);
  });
  test('E06 malformed nonempty cell is retained and flagged', () {
    final r = record('尚待补充的课程信息');
    expect(r.raw, '尚待补充的课程信息');
    expect(r.issue, isNotNull);
    expect(r.meeting.hasUnknownFrequency, isTrue);
  });
  test('E07 missing remark does not swallow room and title', () {
    final r = record('示例课程(实验楼A)每周考试：另行通知');
    expect(r.meeting.name, '示例课程');
    expect(r.meeting.room, '实验楼A');
    expect(r.meeting.note, isEmpty);
  });
  test('E08 trailing parenthesized note cannot consume frequency or exam', () {
    final r = record('示例课程(实验楼A)(备注：携带纸笔)每周考试：另行通知(附加说明)');
    expect(r.meeting.frequency, WeekFrequency.every);
    expect(r.meeting.note, contains('携带纸笔'));
    expect(r.meeting.note, isNot(contains('每周')));
    expect(r.meeting.note, contains('附加说明'));
  });
  test('E09 unrecognized frequency survives as visible unknown', () {
    final r = record('示例课程(实验楼A)(备注：携带纸笔)隔三周考试：另行通知');
    expect(r.meeting.frequency, WeekFrequency.unknown);
    expect(r.meeting.frequencyText, '隔三周');
    expect(
      r.meeting.frequency.isVisible(currentParity: WeekParity.odd),
      isTrue,
    );
    expect(
      r.meeting.frequency.isVisible(currentParity: WeekParity.even),
      isTrue,
    );
  });
  for (final note in [
    '习题课上课时间：每周四8-9，上课教室：实验楼B、实验楼C',
    '习题课双周四8-9节，教室：实验楼B、实验楼C',
    '习题课时间与地点稍后公布',
  ]) {
    test('E10 tutorial must expand or request review: $note', () {
      final candidate = cells([
        _header,
        _row('1', value: '示例课程(实验楼A)(备注：$note)单周考试：另行通知'),
        for (var p = 2; p <= 12; p++) _row('$p'),
      ]);
      final expanded = candidate.records.any(
        (r) =>
            r.meeting.weekday == 4 &&
            r.meeting.firstPeriod <= 8 &&
            r.meeting.lastPeriod >= 8,
      );
      expect(
        expanded || candidate.issues.isNotEmpty,
        isTrue,
        reason: 'A source tutorial must not silently remain unscheduled without review.',
      );
      expect(candidate.records.first.raw, contains(note));
    });
  }
  test('E11 note frequency must not override main occurrence frequency', () {
    final r = record('示例课程(实验楼A)(备注：习题课每周四8-9节，教室：实验楼B)双周考试：另行通知');
    expect(r.meeting.frequency, WeekFrequency.even);
  });
  test(
    'E12 first header row and period index are structural, not meetings',
    () {
      final c = cells([_header, _row('1', value: _plain), _row('2')]);
      expect(c.records, hasLength(1));
      expect(c.periodCount, 2);
      expect(c.records.single.meeting.sourceId, 'sheet:0/row:1/column:1');
    },
  );
  test('E13 all-empty cells and blank physical rows are ignored', () {
    final c = cells([
      _header,
      _row('1'),
      <String>[],
      _row('2', day: 5, value: _plain),
    ]);
    expect(c.records, hasLength(1));
    expect(c.periodCount, 2);
  });
  test(
    'E14 Saturday and Sunday remain present despite upstream weekend omission',
    () {
      final saturday = _row('1', day: 6, value: _plain)..[7] = _plain;
      final c = cells([_header, saturday]);
      expect(c.records.map((r) => r.meeting.weekday), [6, 7]);
    },
  );
  test('E15 all twelve teaching periods are retained including evening', () {
    final c = cells([
      _header,
      for (var p = 1; p <= 12; p++) _row('$p', value: _plain),
    ]);
    expect(c.periodCount, 12);
    expect(
      c.records.map((r) => r.meeting.firstPeriod),
      List.generate(12, (i) => i + 1),
    );
  });
  test('E16 Chinese period labels are recognized', () {
    final c = cells([
      _header,
      _row('第一节', value: _plain),
      _row('第十二节', value: _plain),
    ]);
    expect(c.records.map((r) => r.meeting.firstPeriod), [1, 12]);
  });
  test(
    'E17 repeated records retain identities and group only for presentation',
    () {
      final c = cells([
        _header,
        _row('1', value: _plain),
        _row('2', value: _plain),
      ]);
      final t = Timetable(
        c.records.map((r) => r.meeting),
        periodCount: c.periodCount,
      );
      expect(t.meetings.map((m) => m.sourceId).toSet(), hasLength(2));
      expect(t.consecutiveGroups().single, hasLength(2));
      expect(t.atPeriod(1, 1).single.firstPeriod, 1);
      expect(t.atPeriod(1, 2).single.firstPeriod, 2);
    },
  );
  test('E18 separate rooms do not collapse merely because names match', () {
    final c = cells([
      _header,
      _row('1', value: _plain),
      _row('2', value: _plain.replaceAll('实验楼A', '实验楼B')),
    ]);
    expect(
      Timetable(c.records.map((r) => r.meeting)).consecutiveGroups(),
      hasLength(2),
    );
  });
  test('E19 odd and even occurrences coexist at the same coordinate', () {
    final c = cells([
      _header,
      _row('1', value: _plain.replaceAll('每周', '单周')),
      _row('1', value: _plain.replaceAll('每周', '双周')),
    ]);
    final t = Timetable(c.records.map((r) => r.meeting));
    expect(t.atPeriod(1, 1, mode: PreviewMode.all), hasLength(2));
    expect(
      t.atPeriod(1, 1, mode: PreviewMode.odd).single.frequency,
      WeekFrequency.odd,
    );
    expect(
      t.atPeriod(1, 1, mode: PreviewMode.even).single.frequency,
      WeekFrequency.even,
    );
    expect(t.meetings, hasLength(2));
  });
  test('E20 header-driven coordinates tolerate column reordering', () {
    final h = [..._header];
    h[1] = '星期日';
    h[7] = '星期一';
    final c = cells([h, _row('1', day: 1, value: _plain)]);
    expect(c.records.single.meeting.weekday, 7);
    expect(c.records.single.meeting.sourceId, 'sheet:0/row:1/column:1');
  });
  test(
    'E21 paired detail rows must combine or explicitly reject, not lose data',
    () {
      final rows = [
        _header,
        _row('1', value: '示例课程(实验楼A)每周'),
        _row('', value: '备注：携带纸笔；考试：另行通知'),
      ];
      // Unknown paired layouts may fail closed pending a dedicated recognizer.
      try {
        final c = cells(rows);
        expect(
          c.issues.isNotEmpty ||
              c.records.any((r) => r.meeting.note.contains('携带纸笔')),
          isTrue,
        );
      } on FormatException {
        // Explicit rejection preserves the previously published timetable.
      }
    },
  );
  test('E22 unsupported extra populated column fails closed', () {
    expect(
      () => cells([
        _header,
        [..._row('1'), 'unmapped content'],
      ]),
      throwsFormatException,
    );
  });
  test('E23 candidate keeps a defensive immutable byte snapshot', () {
    final bytes = Uint8List.fromList([11, 22, 33]);
    final c = parser.parseCells(bytes, [_header, _row('1', value: _plain)]);
    bytes[0] = 99;
    expect(c.bytes, [11, 22, 33]);
    expect(() => c.bytes[0] = 88, throwsUnsupportedError);
  });
  for (final entry in [
    ('single room', '习题课每周四8-9节，教室：实验楼B', false),
    ('occupied destination', '习题课每周四8-9节，教室：实验楼B', true),
    ('out-of-bounds period', '习题课每周四54-55节，教室：实验楼B', false),
    ('weekend destination', '习题课每周日8-9节，教室：实验楼B', false),
  ]) {
    test('E25 tutorial ${entry.$1} is reviewable without losing originals', () {
      final main = '示例课程(实验楼A)(备注：${entry.$2})单周考试：另行通知';
      final candidate = cells([
        _header,
        _row('1', value: main),
        _row('2', value: main),
        for (var p = 3; p <= 12; p++)
          _row('$p', day: 4, value: entry.$3 && p == 8 ? _plain : ''),
      ]);
      expect(candidate.records.where((r) => r.raw == main), hasLength(2));
      expect(
        candidate.records.map((r) => r.meeting.sourceId).toSet().length,
        candidate.records.length,
      );
      expect(
        candidate.issues.isNotEmpty ||
            candidate.records.any(
              (r) => r.meeting.name.contains('习题课') && r.raw != main,
            ),
        isTrue,
        reason: 'Tutorial inference must either be explicit or require review.',
      );
      if (entry.$3) {
        expect(candidate.records.where((r) => r.raw == _plain), hasLength(1));
      }
    });
  }
  test('E26 parity previews retain every and unknown occurrences', () {
    for (final mode in PreviewMode.values) {
      for (final parity in WeekParity.values) {
        expect(
          WeekFrequency.every.isVisible(mode: mode, currentParity: parity),
          isTrue,
        );
        expect(
          WeekFrequency.unknown.isVisible(mode: mode, currentParity: parity),
          isTrue,
        );
      }
    }
    for (final frequency in WeekFrequency.values) {
      expect(frequency.isVisible(mode: PreviewMode.all), isTrue);
      expect(frequency.isVisible(), isTrue);
    }
  });
  for (final bytes in [
    Uint8List(0),
    Uint8List.fromList([80, 75, 3, 4]),
    Uint8List(9),
  ]) {
    test('E24 non-BIFF input ${bytes.length} bytes is rejected', () {
      expect(() => parser.parse(bytes), throwsFormatException);
    });
  }
}
