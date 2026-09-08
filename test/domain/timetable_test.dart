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
        meeting('late', first: 3, last: 4),
        meeting('z'),
        meeting('a'),
        meeting('short', last: 1),
      ]);
      expect(table.meetings.map((m) => m.sourceId), [
        'short',
        'z',
        'a',
        'late',
      ]);

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
      table
          .visible(showAll: false, currentParity: WeekParity.odd)
          .map((m) => m.sourceId),
      ['every', 'odd'],
    );
    expect(
      table.visible(showAll: true, currentParity: WeekParity.odd),
      hasLength(3),
    );
    expect(
      table
          .forDay(1, showAll: false, currentParity: WeekParity.even)
          .map((m) => m.sourceId),
      ['every', 'even'],
    );
    expect(table.atPeriod(1, 1, showAll: true), hasLength(3));
    expect(table.atPeriod(1, 2, showAll: true), hasLength(3));
    expect(table.atPeriod(1, 3), isEmpty);
    expect(table.visible(), hasLength(3));
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
    for (final day in [0, 6, 7, 8]) {
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

  test('source identity and human text are preserved exactly', () {
    final value = meeting(
      'sheet:0/row:4/col:2',
      frequency: WeekFrequency.every,
      text: ' 第3至8周 ',
      note: '备注\n原文',
      exam: '待定',
    );
    expect(value.sourceId, 'sheet:0/row:4/col:2');
    expect(value.name, ' 高等数学 ');
    expect(value.frequencyText, ' 第3至8周 ');
    expect(value.note, '备注\n原文');
    expect(value.exam, '待定');
  });

  test(
    'consecutive display grouping keeps source identities and immutable lists',
    () {
      final table = Timetable([
        meeting('a'),
        meeting('b', first: 3, last: 4),
        meeting('gap', first: 6, last: 6),
        meeting('different-room', first: 7, last: 7, room: '二教'),
      ]);
      final groups = table.consecutiveGroups();
      expect(groups.map((g) => g.map((m) => m.sourceId).toList()), [
        ['a', 'b'],
        ['gap'],
        ['different-room'],
      ]);
      expect(table.meetings, hasLength(4));
      expect(() => groups.clear(), throwsUnsupportedError);
      expect(() => groups.first.clear(), throwsUnsupportedError);
    },
  );

  test('frequency text, notes and exams prevent incorrect grouping', () {
    for (final next in [
      meeting('b', first: 3, last: 4, frequency: WeekFrequency.odd),
      meeting('b', first: 3, last: 4, text: '保留'),
      meeting('b', first: 3, last: 4, note: '备注'),
      meeting('b', first: 3, last: 4, exam: '考试'),
    ]) {
      expect(Timetable([meeting('a'), next]).consecutiveGroups(), hasLength(2));
    }
  });

  test(
    'same-day touching courses form one editable source-preserving group',
    () {
      final table = Timetable([
        meeting('first', first: 1, last: 2),
        meeting('second', first: 3, last: 4),
        meeting('after-break', first: 5, last: 6),
      ]);
      final groups = table.groupsForDay(1, breakAfter: const {4, 9});
      expect(groups, hasLength(2));
      expect(groups.first.firstPeriod, 1);
      expect(groups.first.lastPeriod, 4);
      expect(groups.first.meetings.map((value) => value.sourceId), [
        'first',
        'second',
      ]);
      expect(groups.last.meetings.single.sourceId, 'after-break');
      expect(() => groups.first.meetings.clear(), throwsUnsupportedError);
    },
  );
}
