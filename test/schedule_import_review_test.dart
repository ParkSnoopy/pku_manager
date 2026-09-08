import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pku_manager/domain/course.dart';
import 'package:pku_manager/domain/schedule_import.dart';
import 'package:pku_manager/domain/timetable.dart';
import 'package:pku_manager/domain/week_source.dart';
import 'package:pku_manager/features/schedule_import/schedule_import_review.dart';
import 'package:pku_manager/features/timetable/timetable_controller.dart';
import 'package:pku_manager/l10n/app_strings.dart';

final class _Store implements ScheduleStore {
  Map<String, Course> completions = const {};

  @override
  Timetable? load() => null;

  @override
  Timetable publish(
    ScheduleCandidate candidate,
    Map<String, Course> completions,
  ) {
    this.completions = Map.unmodifiable(completions);
    return Timetable(
      candidate.records.map(
        (record) => completions[record.meeting.sourceId] ?? record.meeting,
      ),
      periodCount: candidate.periodCount,
    );
  }

  @override
  Timetable removeUserMeeting(String sourceId) => throw UnimplementedError();

  @override
  Timetable removeUserMeetings(Iterable<String> sourceIds) =>
      throw UnimplementedError();

  @override
  Timetable saveMeeting(Course meeting) => throw UnimplementedError();

  @override
  Timetable saveMeetings(Iterable<Course> meetings) =>
      throw UnimplementedError();
}

final class _Decoder implements ScheduleDecoder {
  @override
  ScheduleCandidate parse(Uint8List bytes) => throw UnimplementedError();
}

final class _Picker implements SchedulePicker {
  @override
  Future<Uint8List?> pick() async => null;
}

final class _Weeks implements WeekSource {
  @override
  WeekStatus cached() => const WeekStatus(null, WeekFreshness.unavailable);

  @override
  Future<WeekStatus> refresh() async => cached();
}

void main() {
  late _Store store;
  late TimetableController controller;

  setUp(() {
    store = _Store();
    controller = TimetableController(
      schedules: store,
      decoder: _Decoder(),
      picker: _Picker(),
      weeks: _Weeks(),
    );
  });

  tearDown(() => controller.dispose());

  Future<void> pumpReview(
    WidgetTester tester,
    ScheduleCandidate candidate,
  ) async {
    controller.candidate = candidate;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        supportedLocales: AppStrings.supportedLocales,
        localizationsDelegates: AppStrings.localizationsDelegates,
        home: ScheduleImportReview(
          candidate: candidate,
          controller: controller,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('review shows only fields whose parsing failed', (tester) async {
    final candidate = ScheduleCandidate(Uint8List.fromList([1]), [
      ImportRecord(
        meeting: Course(
          sourceId: 'source',
          name: 'Advanced Mathmatics',
          weekday: 1,
          firstPeriod: 1,
          lastPeriod: 1,
        ),
        raw: 'Advanced Mathmatics',
        issue: 'Complete the highlighted fields.',
        failedFields: const {ImportField.room},
      ),
    ], 12);
    await pumpReview(tester, candidate);

    expect(find.byKey(const ValueKey('import-room')), findsOneWidget);
    expect(find.byKey(const ValueKey('import-name')), findsNothing);
    expect(find.byKey(const ValueKey('import-weekday')), findsNothing);
    expect(find.byKey(const ValueKey('import-firstPeriod')), findsNothing);
    expect(find.byKey(const ValueKey('import-lastPeriod')), findsNothing);
    expect(find.byKey(const ValueKey('import-frequency')), findsNothing);

    await tester.enterText(find.byKey(const ValueKey('import-room')), 'Room A');
    await tester.tap(find.text('Import'));
    await tester.pump();

    expect(store.completions.values.single.room, 'Room A');
    expect(store.completions.values.single.sourceName, 'Advanced Mathmatics');
  });

  testWidgets('exercise classroom prompt follows the pages branch', (
    tester,
  ) async {
    final candidate = ScheduleCandidate(Uint8List.fromList([1]), [
      ImportRecord(
        meeting: Course(
          sourceId: 'source/tutorial',
          name: 'Advanced Mathmatics Exercise',
          weekday: 4,
          firstPeriod: 8,
          lastPeriod: 9,
          room: 'Room B、Room C',
        ),
        raw: 'Room B、Room C',
        issue: 'Complete the highlighted fields.',
        failedFields: const {ImportField.room},
      ),
    ], 12);
    await pumpReview(tester, candidate);

    expect(find.text('Select classroom'), findsOneWidget);
    expect(
      find.text('Advanced Mathmatics Exercise · Thursday · Periods 8–9'),
      findsOneWidget,
    );
    expect(find.text('Room B'), findsOneWidget);
    expect(find.text('Room C'), findsOneWidget);
    expect(find.text('Not available'), findsOneWidget);
    expect(find.byType(TextFormField), findsNothing);

    await tester.tap(find.byKey(const ValueKey('tutorial-room-Room B')));
    await tester.pump();

    expect(store.completions.values.single.room, 'Room B');
    expect(controller.candidate, isNull);
  });
}
