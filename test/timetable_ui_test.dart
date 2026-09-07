import 'dart:typed_data';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pku_manager/app/app.dart';
import 'package:pku_manager/domain/course_meeting.dart';
import 'package:pku_manager/domain/schedule_import.dart';
import 'package:pku_manager/domain/semester.dart';
import 'package:pku_manager/domain/timetable.dart';
import 'package:pku_manager/domain/week_frequency.dart';
import 'package:pku_manager/domain/week_source.dart';
import 'package:pku_manager/features/timetable/timetable_controller.dart';
import 'package:pku_manager/features/settings/appearance_controller.dart';

final class _Store implements ScheduleStore {
  _Store(this.value);
  Timetable value;
  @override
  Timetable? load() => value;
  @override
  Timetable publish(
    ScheduleCandidate candidate,
    Map<String, CourseMeeting> completions,
  ) => value;
}

final class _Picker implements SchedulePicker {
  @override
  Future<Uint8List?> pick() async => null;
}

final class _Decoder implements ScheduleDecoder {
  @override
  ScheduleCandidate parse(Uint8List bytes) => throw UnimplementedError();
}

final class _Weeks implements WeekSource {
  _Weeks(this.status);
  final WeekStatus status;
  int refreshes = 0;
  @override
  WeekStatus cached() => status;
  @override
  Future<WeekStatus> refresh() async {
    refreshes++;
    return status;
  }
}

CourseMeeting _meeting(String id, int period, WeekFrequency frequency) =>
    CourseMeeting(
      sourceId: id,
      name: id == 'even' ? 'Physics' : 'Algebra',
      weekday: 1,
      firstPeriod: period,
      lastPeriod: period,
      room: 'Room 1',
      frequency: frequency,
      frequencyText: switch (frequency) {
        WeekFrequency.every => '每周',
        WeekFrequency.odd => '单周',
        WeekFrequency.even => '双周',
      },
      note: 'Bring notes',
      exam: 'Exam later',
    );

void main() {
  testWidgets(
    'rail, show-all opacity, full cells, hover details and foreground refresh',
    (tester) async {
      tester.view.physicalSize = const Size(800, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final weeks = _Weeks(
        WeekStatus(
          SemesterCalendar(starts: [DateTime.utc(2026, 9, 7)]),
          WeekFreshness.cached,
        ),
      );
      final table = Timetable([
        _meeting('first', 1, WeekFrequency.every),
        _meeting('second', 2, WeekFrequency.every),
        _meeting('even', 3, WeekFrequency.even),
      ], periodCount: 3);
      final controller = TimetableController(
        schedules: _Store(table),
        decoder: _Decoder(),
        picker: _Picker(),
        weeks: weeks,
        clock: () => DateTime.utc(2026, 9, 7),
      )..start();
      final appearance = AppearanceController(MemoryAppearanceStore());
      await tester.pumpWidget(
        PkuManagerApp(controller: controller, appearance: appearance),
      );
      await tester.pump();
      expect(find.byType(NavigationRail), findsOneWidget);
      expect(find.text('Show all'), findsNothing);
      expect(find.text('Refresh'), findsNothing);
      expect(find.text('Current'), findsNothing);
      expect(find.text('Algebra'), findsNWidgets(2));
      expect(find.textContaining('continued'), findsNothing);
      expect(find.text('Physics'), findsOneWidget);
      expect(
        tester.getSize(find.byKey(const ValueKey('meeting-cell-first'))).height,
        60,
      );

      final opacity = tester.widget<Opacity>(
        find.ancestor(
          of: find.byKey(const ValueKey('meeting-cell-even')),
          matching: find.byType(Opacity),
        ),
      );
      expect(opacity.opacity, .5);
      expect(find.byTooltip('Roll colors'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);
      final firstColor = tester
          .widget<Material>(find.byKey(const ValueKey('meeting-color-first')))
          .color;
      await tester.tap(find.byTooltip('Roll colors'));
      await tester.pump();
      final secondColor = tester
          .widget<Material>(find.byKey(const ValueKey('meeting-color-first')))
          .color;
      await tester.tap(find.byTooltip('Roll colors'));
      await tester.pump();
      final thirdColor = tester
          .widget<Material>(find.byKey(const ValueKey('meeting-color-first')))
          .color;
      expect({firstColor, secondColor, thirdColor}, hasLength(3));

      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(
        location: tester.getCenter(
          find.byKey(const ValueKey('meeting-cell-first')),
        ),
      );
      await tester.pump(const Duration(milliseconds: 999));
      expect(find.byKey(const ValueKey('meeting-hover-first')), findsNothing);
      await tester.pump(const Duration(milliseconds: 1));
      final hover = find.byKey(const ValueKey('meeting-hover-first'));
      expect(hover, findsOneWidget);
      final before = tester.getTopLeft(hover);
      await mouse.moveBy(const Offset(30, 20));
      await tester.pump();
      expect(tester.getTopLeft(hover), isNot(before));
      await mouse.removePointer();

      final initialRefreshes = weeks.refreshes;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(weeks.refreshes, initialRefreshes + 1);
      await tester.tap(find.text('Settings'));
      await tester.pump();
      expect(find.text('Theme'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
    },
  );
}
