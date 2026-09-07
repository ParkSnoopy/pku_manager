import 'package:flutter_test/flutter_test.dart';
import 'package:pku_manager/domain/course_meeting.dart';
import 'package:pku_manager/domain/timetable.dart';
import 'package:pku_manager/domain/week_frequency.dart';

CourseMeeting meeting(
  String id, {
  int day = 1,
  int first = 1,
  int last = 2,
  WeekFrequency frequency = WeekFrequency.every,
  String room = '理教 101',
  String note = '',
  String exam = '',
  String text = '',
}) => CourseMeeting(
  sourceId: id,
  name: ' 高等数学 ',
  weekday: day,
  firstPeriod: first,
  lastPeriod: last,
  room: room,
  frequency: frequency,
  frequencyText: text,
  note: note,
  exam: exam,
);

void main() {
  test(
    'coordinate sort is deterministic with input source order as final key',
    () {
      final table = Timetable([
        meeting('sun', day: 7),
        meeting('late', first: 3, last: 4),
        meeting('z'),
        meeting('a'),
        meeting('short', last: 1),
        meeting('sat', day: 6),
      ]);
      expect(table.meetings.map((m) => m.sourceId), [
        'short',
        'z',
        'a',
        'late',
        'sat',
        'sun',
      ]);
      expect(table.forDay(6).single.sourceId, 'sat');
      expect(table.forDay(7).single.sourceId, 'sun');
      expect(table.periodCount, 4);
    },
  );

  test('visibility and inclusive period projections never mutate source', () {
    final input = [
      for (final frequency in WeekFrequency.values)
        meeting(frequency.name, frequency: frequency),
    ];
    final table = Timetable(input);
    input.clear();
    expect(
      table.visible(currentParity: WeekParity.odd).map((m) => m.sourceId),
      ['every', 'odd', 'unknown'],
    );
    expect(table.forDay(1, mode: PreviewMode.even).map((m) => m.sourceId), [
      'every',
      'even',
      'unknown',
    ]);
    expect(table.atPeriod(1, 1), hasLength(4));
    expect(table.atPeriod(1, 2), hasLength(4));
    expect(table.atPeriod(1, 3), isEmpty);
    expect(table.visible(), hasLength(4));
    for (final list in [
      table.meetings,
      table.visible(),
      table.forDay(1),
      table.atPeriod(1, 1),
    ]) {
      expect(() => list.clear(), throwsUnsupportedError);
    }
  });

  test('invalid coordinates, empty identities, duplicate identities and bounds reject', () {
    for (final day in [0, 8]) {
      expect(() => meeting('a', day: day), throwsRangeError);
      expect(() => Timetable([]).forDay(day), throwsRangeError);
    }
    expect(() => meeting(''), throwsArgumentError);
    expect(() => meeting('a', first: 0), throwsArgumentError);
    expect(() => meeting('a', first: 3, last: 2), throwsArgumentError);
    expect(
      () => CourseMeeting(
        sourceId: 'a',
        name: ' ',
        weekday: 1,
        firstPeriod: 1,
        lastPeriod: 1,
      ),
      throwsArgumentError,
    );
    expect(() => Timetable([meeting('a'), meeting('a')]), throwsArgumentError);
    expect(
      () => Timetable([meeting('a')], periodCount: 1),
      throwsArgumentError,
    );
    expect(() => Timetable([], periodCount: 0), throwsArgumentError);
    expect(() => Timetable([]).atPeriod(1, 0), throwsArgumentError);
    expect(Timetable([]).periodCount, 0);
    expect(Timetable([], periodCount: 12).periodCount, 12);
  });

  test('source identity and unknown human text are preserved exactly', () {
    final value = meeting(
      'sheet:0/row:4/col:2',
      frequency: WeekFrequency.unknown,
      text: ' 第3至8周 ',
      note: '备注\n原文',
      exam: '待定',
    );
    expect(value.sourceId, 'sheet:0/row:4/col:2');
    expect(value.name, ' 高等数学 ');
    expect(value.frequencyText, ' 第3至8周 ');
    expect(value.note, '备注\n原文');
    expect(value.exam, '待定');
    expect(value.hasUnknownFrequency, isTrue);
  });

  test(
    'consecutive display grouping keeps source identities and immutable lists',
    () {
      final table = Timetable([
        meeting('a'),
        meeting('b', first: 3, last: 4),
        meeting('gap', first: 6, last: 6),
        meeting('different-room', first: 7, last: 7, room: '二教'),
        meeting('weekend', day: 7),
      ]);
      final groups = table.consecutiveGroups();
      expect(groups.map((g) => g.map((m) => m.sourceId).toList()), [
        ['a', 'b'],
        ['gap'],
        ['different-room'],
        ['weekend'],
      ]);
      expect(table.meetings, hasLength(5));
      expect(() => groups.clear(), throwsUnsupportedError);
      expect(() => groups.first.clear(), throwsUnsupportedError);
    },
  );

  test(
    'frequency, unknown text, notes and exams prevent incorrect grouping',
    () {
      for (final next in [
        meeting('b', first: 3, last: 4, frequency: WeekFrequency.odd),
        meeting('b', first: 3, last: 4, text: '保留'),
        meeting('b', first: 3, last: 4, note: '备注'),
        meeting('b', first: 3, last: 4, exam: '考试'),
      ]) {
        expect(
          Timetable([meeting('a'), next]).consecutiveGroups(),
          hasLength(2),
        );
      }
    },
  );
}
