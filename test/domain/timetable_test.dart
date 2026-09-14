import 'package:flutter_test/flutter_test.dart';
import 'package:pku_manager/domain/course.dart';
import 'package:pku_manager/domain/timetable.dart';
import 'package:pku_manager/domain/week_frequency.dart';

Course meeting(
  String id, {
  int day = 1,
  int first = 1,
  int last = 2,
  WeekFrequency frequency = WeekFrequency.every,
  String room = '理教 101',
  String note = '',
  String exam = '',
  String text = '',
}) => Course(
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

  test(
    'conflicts require overlapping periods in a week both classes can meet',
    () {
      final overlapping = Timetable([
        meeting('every', first: 1, last: 2),
        meeting('odd', first: 2, last: 3, frequency: WeekFrequency.odd),
        meeting('even', first: 2, last: 3, frequency: WeekFrequency.even),
        meeting('later', first: 4, last: 4),
        meeting('other-day', day: 2, first: 1, last: 2),
      ]);
      expect(overlapping.conflictingSourceIds, {'every', 'odd', 'even'});

      final alternating = Timetable([
        meeting('odd', frequency: WeekFrequency.odd),
        meeting('even', frequency: WeekFrequency.even),
      ]);
      expect(alternating.conflictingSourceIds, isEmpty);
      expect(
        () => alternating.conflictingSourceIds.clear(),
        throwsUnsupportedError,
      );
    },
  );

  test('invalid coordinates, empty identities, duplicate identities and bounds reject', () {
    for (final day in [0, 6, 7, 8]) {
      expect(() => meeting('a', day: day), throwsRangeError);
      expect(() => Timetable([]).forDay(day), throwsRangeError);
    }
    expect(() => meeting(''), throwsArgumentError);
    expect(() => meeting('a', first: 0), throwsArgumentError);
    expect(() => meeting('a', first: 3, last: 2), throwsArgumentError);
    expect(
      () => Course(
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

  test('source cells remain separate and immutable', () {
    final table = Timetable([
      meeting('a'),
      meeting('b', first: 3, last: 4),
      meeting('gap', first: 6, last: 6),
      meeting('different-room', first: 7, last: 7, room: '二教'),
    ]);
    final cells = table.forDay(1);
    expect(cells.map((meeting) => meeting.sourceId), [
      'a',
      'b',
      'gap',
      'different-room',
    ]);
    expect(() => cells.clear(), throwsUnsupportedError);
  });
}
