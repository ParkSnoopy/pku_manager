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
import 'package:pku_manager/features/calendar/calendar_schedule_controller.dart';
import 'package:pku_manager/features/timetable/timetable_controller.dart';
import 'package:pku_manager/features/timetable/timetable_color.dart';
import 'package:pku_manager/features/timetable/timetable_export.dart';
import 'package:pku_manager/features/timetable/timetable_page.dart';
import 'package:pku_manager/features/settings/appearance_controller.dart';
import 'package:pku_manager/l10n/app_strings.dart';

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
  @override
  Timetable saveMeeting(CourseMeeting meeting) => value = Timetable([
    ...value.meetings.where((item) => item.sourceId != meeting.sourceId),
    meeting,
  ], periodCount: value.periodCount);
  @override
  Timetable saveMeetings(Iterable<CourseMeeting> meetings) {
    for (final meeting in meetings) {
      saveMeeting(meeting);
    }
    return value;
  }

  @override
  Timetable removeUserMeeting(String sourceId) => value = Timetable(
    value.meetings.where((meeting) => meeting.sourceId != sourceId),
    periodCount: value.periodCount,
  );
  @override
  Timetable removeUserMeetings(Iterable<String> sourceIds) {
    for (final sourceId in sourceIds) {
      removeUserMeeting(sourceId);
    }
    return value;
  }
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

final class _ExportWriter implements ExportFileWriter {
  ExportFile? file;
  bool fail = false;

  @override
  Future<void> save(ExportFile value) async {
    if (fail) throw StateError('save failed');
    file = value;
  }
}

final class _PngEncoder implements TimetablePngEncoder {
  @override
  Future<Uint8List> encode(
    Timetable timetable,
    AppStrings strings,
    int paletteSeed, {
    Map<String, CourseAppearance> courseAppearances = const {},
  }) async => Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10]);
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
      ], periodCount: 4);
      final controller = TimetableController(
        schedules: _Store(table),
        decoder: _Decoder(),
        picker: _Picker(),
        weeks: weeks,
        clock: () => DateTime.utc(2026, 9, 7),
      )..start();
      final appearance = AppearanceController(MemoryAppearanceStore());
      appearance.setLanguage(AppLanguage.en);
      final writer = _ExportWriter();
      await tester.pumpWidget(
        PkuManagerApp(
          controller: controller,
          appearance: appearance,
          exporter: TimetableExporter(writer, pngEncoder: _PngEncoder()),
        ),
      );
      await tester.pump();
      expect(find.byType(NavigationRail), findsOneWidget);
      expect(find.text('Calendar'), findsOneWidget);
      expect(find.text('Show all'), findsNothing);
      expect(find.text('Refresh'), findsNothing);
      expect(find.text('Current'), findsNothing);
      expect(find.text('Algebra'), findsOneWidget);
      expect(find.textContaining('continued'), findsNothing);
      expect(find.text('Physics'), findsOneWidget);
      final courseName = tester.widget<Text>(
        find.descendant(
          of: find.byKey(const ValueKey('meeting-cell-first')),
          matching: find.text('Algebra'),
        ),
      );
      expect(courseName.style?.fontSize, 22.5);
      expect(courseName.overflow, TextOverflow.ellipsis);
      final content = tester.widget<Padding>(
        find.byKey(const ValueKey('meeting-content-first')),
      );
      expect(content.padding, const EdgeInsets.fromLTRB(10, 8, 10, 8));
      expect(
        tester.getSize(find.byKey(const ValueKey('meeting-cell-first'))).height,
        200,
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

      await tester.tap(find.byTooltip('Export'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Export XLSX'));
      await tester.pumpAndSettle();
      expect(writer.file?.extension, 'xlsx');

      writer.fail = true;
      await tester.tap(find.byTooltip('Export'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Export PNG'));
      await tester.pumpAndSettle();
      expect(find.text('Export failed'), findsOneWidget);

      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(
        location: tester.getCenter(
          find.byKey(const ValueKey('meeting-cell-first')),
        ),
      );
      await tester.pump(const Duration(milliseconds: 99));
      expect(find.byKey(const ValueKey('meeting-hover-first')), findsNothing);
      await tester.pump(const Duration(milliseconds: 1));
      final hover = find.byKey(const ValueKey('meeting-hover-first'));
      expect(hover, findsOneWidget);
      final before = tester.getTopLeft(hover);
      await mouse.moveBy(const Offset(30, 20));
      await tester.pump();
      expect(tester.getTopLeft(hover), isNot(before));
      await mouse.removePointer();

      await tester.tap(find.byKey(const ValueKey('timetable-cell-1-4')));
      await tester.pumpAndSettle();
      expect(find.text('Add course'), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('course-name')),
        'New course',
      );
      await tester.enterText(
        find.byKey(const ValueKey('course-room')),
        'New room',
      );
      await tester.drag(find.byType(ListView).last, const Offset(0, -700));
      await tester.pump();
      await tester.ensureVisible(find.text('Save'));
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(controller.timetable!.atPeriod(1, 4).single.name, 'New course');

      final initialRefreshes = weeks.refreshes;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(weeks.refreshes, initialRefreshes + 1);
      await tester.tap(find.text('Settings'));
      await tester.pump();
      expect(find.text('Theme'), findsOneWidget);
      await tester.ensureVisible(
        find.byKey(const ValueKey('show-roll-navbar')),
      );
      await tester.tap(find.byKey(const ValueKey('show-roll-navbar')));
      await tester.pump();
      await tester.tap(find.text('Timetable'));
      await tester.pump();
      expect(find.byTooltip('Roll colors'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
    },
  );

  testWidgets(
    'landscape uses the timetable pane and keeps calendar independent',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final table = Timetable([
        _meeting('first', 1, WeekFrequency.every),
        _meeting('second', 2, WeekFrequency.every),
        _meeting('even', 3, WeekFrequency.even),
      ], periodCount: 4);
      final controller = TimetableController(
        schedules: _Store(table),
        decoder: _Decoder(),
        picker: _Picker(),
        weeks: _Weeks(
          WeekStatus(
            SemesterCalendar(starts: [DateTime.utc(2026, 9, 7)]),
            WeekFreshness.cached,
          ),
        ),
        clock: () => DateTime.utc(2026, 9, 7),
      )..start();
      final appearance = AppearanceController(MemoryAppearanceStore())
        ..setLanguage(AppLanguage.en);
      final calendar = CalendarScheduleController(MemoryCalendarScheduleStore())
        ..create(
          title: 'Homework deadline',
          startsAt: DateTime.utc(2026, 9, 7, 1),
        );
      addTearDown(calendar.dispose);
      appearance.setCourseAppearance(
        const ['first', 'second'],
        const CourseAppearance(
          color: Color(0xff123456),
          lockColor: true,
          outlined: true,
          outlineColor: Color(0xfffedcba),
          outlineWidth: 3.5,
        ),
      );
      Uri? launched;
      await tester.pumpWidget(
        PkuManagerApp(
          controller: controller,
          calendar: calendar,
          appearance: appearance,
          exporter: TimetableExporter(
            _ExportWriter(),
            pngEncoder: _PngEncoder(),
          ),
          browserLauncher: (uri) async {
            launched = uri;
            return true;
          },
        ),
      );
      await tester.pump();
      expect(
        find.byKey(const ValueKey('upcoming-schedule-pane')),
        findsOneWidget,
      );
      expect(find.text('Upcoming schedule'), findsOneWidget);
      expect(find.text('Homework deadline'), findsOneWidget);
      expect(find.text('Algebra'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('upcoming-schedule-pane')),
          matching: find.text('Algebra'),
        ),
        findsNothing,
      );
      expect(find.textContaining('in '), findsWidgets);
      expect(
        tester
            .widget<Material>(find.byKey(const ValueKey('meeting-color-first')))
            .color,
        const Color(0xff123456),
      );
      expect(find.byKey(const ValueKey('manual-color-first')), findsOneWidget);
      final decoration = tester.widget<DecoratedBox>(
        find.byKey(const ValueKey('meeting-outline-first')),
      );
      final border = (decoration.decoration as BoxDecoration).border! as Border;
      expect(border.top.color, const Color(0xfffedcba));
      expect(border.top.width, 3.5);

      await tester.tap(find.text('Calendar'));
      await tester.pump();
      expect(find.byKey(const ValueKey('calendar-page')), findsOneWidget);
      expect(find.text('September 2026'), findsOneWidget);
      expect(find.textContaining('Homework deadline'), findsOneWidget);
      expect(find.byKey(const ValueKey('upcoming-class-pane')), findsOneWidget);
      expect(find.text('Upcoming class'), findsOneWidget);
      expect(find.text('Algebra'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('upcoming-class-pane')),
          matching: find.textContaining('Homework deadline'),
        ),
        findsNothing,
      );
      expect(find.text('Upcoming schedule'), findsNothing);
      await tester.tap(find.text('Timetable'));
      await tester.pump();

      await tester.tap(find.byKey(const ValueKey('meeting-cell-first')));
      await tester.pump();
      expect(find.byKey(const ValueKey('course-editor-pane')), findsOneWidget);
      expect(find.byType(Dialog), findsNothing);
      await tester.enterText(
        find.byKey(const ValueKey('course-name')),
        'Grouped course',
      );
      await tester.drag(find.byType(ListView).last, const Offset(0, -700));
      await tester.pump();
      await tester.ensureVisible(find.text('Save'));
      await tester.tap(find.text('Save'));
      await tester.pump();
      expect(
        controller.timetable!.meetings
            .where(
              (meeting) => const {'first', 'second'}.contains(meeting.sourceId),
            )
            .map((meeting) => meeting.name),
        everyElement('Grouped course'),
      );
      expect(
        find.byKey(const ValueKey('upcoming-schedule-pane')),
        findsOneWidget,
      );

      await tester.tap(find.text('教学网'));
      await tester.pump();
      expect(launched.toString(), teachingPortalUrl);
      expect(find.text('教学网'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
    },
  );
}
