import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pku_manager/app/app.dart';
import 'package:pku_manager/domain/course.dart';
import 'package:pku_manager/domain/schedule_import.dart';
import 'package:pku_manager/domain/semester.dart';
import 'package:pku_manager/domain/timetable.dart';
import 'package:pku_manager/domain/week_frequency.dart';
import 'package:pku_manager/domain/week_source.dart';
import 'package:pku_manager/features/calendar/calendar_schedule_controller.dart';
import 'package:pku_manager/features/calendar/schedule_color.dart';
import 'package:pku_manager/features/timetable/timetable_controller.dart';
import 'package:pku_manager/features/timetable/timetable_color.dart';
import 'package:pku_manager/features/timetable/timetable_export.dart';
import 'package:pku_manager/features/timetable/timetable_page.dart';
import 'package:pku_manager/features/timetable/timetable_style.dart';
import 'package:pku_manager/features/settings/appearance_controller.dart';
import 'package:pku_manager/l10n/app_strings.dart';
import 'package:pku_manager/ui/flashing_outline.dart';

Future<void> _doubleTap(WidgetTester tester, Finder target) async {
  await tester.tap(target);
  await tester.pump(const Duration(milliseconds: 100));
  await tester.tap(target);
}

Future<void> _singleTap(WidgetTester tester, Finder target) async {
  await tester.tap(target);
  await tester.pump(const Duration(milliseconds: 350));
  await tester.pumpAndSettle();
}

final class _Store implements ScheduleStore {
  _Store(this.value);
  Timetable value;
  @override
  Timetable? load() => value;
  @override
  Timetable publish(
    ScheduleCandidate candidate,
    Map<String, Course> completions, {
    String finalExamTitle = 'Final exam',
  }) => value;
  @override
  Timetable saveMeeting(Course meeting) => value = Timetable([
    ...value.meetings.where((item) => item.sourceId != meeting.sourceId),
    meeting,
  ], periodCount: value.periodCount);
  @override
  Timetable saveMeetings(Iterable<Course> meetings) {
    for (final meeting in meetings) {
      saveMeeting(meeting);
    }
    return value;
  }

  @override
  Timetable removeMeeting(String sourceId) => value = Timetable(
    value.meetings.where((meeting) => meeting.sourceId != sourceId),
    periodCount: value.periodCount,
  );
  @override
  Timetable removeMeetings(Iterable<String> sourceIds) {
    for (final sourceId in sourceIds) {
      removeMeeting(sourceId);
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
  double? fontScale;
  String? fontFamily;
  FontWeight? fontWeight;
  Color? indexColor;
  bool? autoTextColor;
  Brightness? brightness;
  Color? surfaceColor;

  @override
  Future<Uint8List> encode(
    Timetable timetable,
    AppStrings strings,
    int paletteSeed, {
    Map<String, CourseAppearance> courseAppearances = const {},
    int paletteIndex = 0,
    List<Color> customPalette = defaultCustomPalette,
    double fontScale = 1,
    String fontFamily = timetableSansFont,
    FontWeight fontWeight = FontWeight.w400,
    Color indexColor = timetableIndexSurface,
    bool autoTextColor = false,
    Brightness brightness = Brightness.light,
    Color surfaceColor = timetableCanvas,
  }) async {
    this.fontScale = fontScale;
    this.fontFamily = fontFamily;
    this.fontWeight = fontWeight;
    this.indexColor = indexColor;
    this.autoTextColor = autoTextColor;
    this.brightness = brightness;
    this.surfaceColor = surfaceColor;
    return Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10]);
  }
}

Course _meeting(String id, int period, WeekFrequency frequency) => Course(
  sourceId: id,
  name: switch (id) {
    'even' => 'Physics',
    'chemistry' => 'Chemistry',
    _ => 'Algebra',
  },
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
        _meeting('chemistry', 1, WeekFrequency.every),
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
      final pngEncoder = _PngEncoder();
      await tester.pumpWidget(
        PkuManagerApp(
          controller: controller,
          appearance: appearance,
          exporter: TimetableExporter(writer, pngEncoder: pngEncoder),
        ),
      );
      await tester.pump();
      expect(find.byType(NavigationRail), findsOneWidget);
      final appTextContext = tester.element(find.text('Calendar'));
      expect(
        MediaQuery.sizeOf(appTextContext),
        const Size(800 / 1.5, 800 / 1.5),
      );
      appearance.setUiScale(1);
      await tester.pump();
      expect(MediaQuery.sizeOf(appTextContext), const Size(800, 800));
      appearance.setUiScale(1.5);
      await tester.pump();
      expect(
        MediaQuery.textScalerOf(appTextContext).scale(10),
        moreOrLessEquals(10),
      );
      expect(
        Theme.of(appTextContext).textTheme.bodyMedium?.fontFamily,
        'PKU Noto Serif CJK SC',
      );
      final meetingTextContext = tester.element(
        find.byKey(const ValueKey('meeting-content-first')),
      );
      expect(
        tester
            .widget<DefaultTextStyle>(
              find.byKey(const ValueKey('meeting-text-style-first')),
            )
            .style
            .fontFamily,
        'PKU Noto Serif CJK SC',
      );
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('timetable-weekday-1')))
            .style!
            .fontFamily,
        'PKU Noto Serif CJK SC',
      );
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('timetable-index-label-1')))
            .style!
            .fontFamily,
        'PKU Noto Serif CJK SC',
      );
      expect(
        MediaQuery.textScalerOf(meetingTextContext).scale(10),
        moreOrLessEquals(10),
      );
      appearance.setTimetableFontScale(2);
      await tester.pump();
      expect(
        MediaQuery.textScalerOf(
          tester.element(find.byKey(const ValueKey('meeting-content-first'))),
        ).scale(10),
        moreOrLessEquals(20),
      );
      expect(
        MediaQuery.textScalerOf(tester.element(find.text('Calendar')))
            .scale(10),
        moreOrLessEquals(10),
      );
      appearance.setTimetableFontScale(1);
      appearance.cycleFontFamily();
      await tester.pumpAndSettle();
      expect(
        Theme.of(tester.element(find.text('Calendar')))
            .textTheme
            .bodyMedium
            ?.fontFamily,
        'PKU Noto Sans CJK SC',
      );
      expect(
        tester
            .widget<DefaultTextStyle>(
              find.byKey(const ValueKey('meeting-text-style-first')),
            )
            .style
            .fontFamily,
        'PKU Noto Sans CJK SC',
      );
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('timetable-weekday-1')))
            .style!
            .fontFamily,
        'PKU Noto Sans CJK SC',
      );
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('timetable-index-label-1')))
            .style!
            .fontFamily,
        'PKU Noto Sans CJK SC',
      );
      appearance.cycleFontFamily();
      await tester.pumpAndSettle();
      expect(
        Theme.of(appTextContext).textTheme.bodyMedium?.fontWeight,
        FontWeight.w400,
      );
      expect(Theme.of(appTextContext).brightness, Brightness.light);
      final neutralSurface = Theme.of(appTextContext).colorScheme.surface;
      appearance.setBlendAccentIntoTheme(true);
      await tester.pumpAndSettle();
      expect(
        Theme.of(tester.element(find.text('Calendar'))).colorScheme.surface,
        isNot(neutralSurface),
      );
      appearance.setBlendAccentIntoTheme(false);
      await tester.pumpAndSettle();
      final lightCourseColor = tester
          .widget<Material>(find.byKey(const ValueKey('meeting-color-first')))
          .color!;
      final lightIndexColor = tester
          .widget<ColoredBox>(find.byKey(const ValueKey('timetable-index-1')))
          .color;
      appearance.setDarkMode(true);
      await tester.pumpAndSettle();
      expect(
        Theme.of(tester.element(find.text('Calendar'))).brightness,
        Brightness.dark,
      );
      final darkCourseColor = tester
          .widget<Material>(find.byKey(const ValueKey('meeting-color-first')))
          .color!;
      final darkIndexColor = tester
          .widget<ColoredBox>(find.byKey(const ValueKey('timetable-index-1')))
          .color;
      expect(
        darkCourseColor.computeLuminance(),
        lessThan(lightCourseColor.computeLuminance()),
      );
      expect(
        darkIndexColor.computeLuminance(),
        lessThan(lightIndexColor.computeLuminance()),
      );
      appearance.setDarkMode(false);
      await tester.pumpAndSettle();
      expect(find.text('Calendar'), findsOneWidget);
      expect(find.text('Show all'), findsNothing);
      expect(find.text('Refresh'), findsNothing);
      expect(find.text('Current'), findsNothing);
      expect(find.text('Algebra'), findsOneWidget);
      expect(find.textContaining('continued'), findsNothing);
      expect(find.text('Physics'), findsNothing);
      expect(
        (tester
                    .widget<DecoratedBox>(
                      find.byKey(const ValueKey('timetable-grid-background')),
                    )
                    .decoration
                as BoxDecoration)
            .color,
        isNull,
      );
      final courseName = tester.widget<Text>(
        find.descendant(
          of: find.byKey(const ValueKey('meeting-cell-first')),
          matching: find.text('Algebra'),
        ),
      );
      expect(courseName.style?.fontSize, 22.5);
      expect(courseName.style?.fontWeight, FontWeight.bold);
      expect(courseName.style?.height, 1.5);
      expect(courseName.overflow, TextOverflow.ellipsis);
      final content = tester.widget<Padding>(
        find.byKey(const ValueKey('meeting-content-first')),
      );
      expect(content.padding, const EdgeInsets.all(10));
      final note = tester.widget<Text>(
        find.descendant(
          of: find.byKey(const ValueKey('meeting-cell-first')),
          matching: find.text('Bring notes'),
        ),
      );
      expect(note.style?.fontSize, timetableCourseNoteFontSize);
      expect(note.style?.height, 1.5);
      expect(note.softWrap, isTrue);
      expect(note.maxLines, isNull);
      expect(
        tester
            .widgetList<SizedBox>(
              find.descendant(
                of: find.byKey(const ValueKey('meeting-cell-first')),
                matching: find.byType(SizedBox),
              ),
            )
            .any((box) => box.height == timetableClassroomFontSize * 1.5),
        isTrue,
      );
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
      expect(opacity.opacity, .25);
      expect(find.byKey(const ValueKey('meeting-content-even')), findsNothing);
      final conflictOutline =
          tester
                  .widget<DecoratedBox>(
                    find.byKey(const ValueKey('meeting-outline-first')),
                  )
                  .decoration
              as BoxDecoration;
      final conflictBorder = conflictOutline.border! as Border;
      expect(conflictBorder.top.color, timetableConflictColor);
      expect(conflictBorder.top.width, timetableConflictWidth);
      expect(
        (tester
                    .widget<DecoratedBox>(
                      find.byKey(const ValueKey('meeting-outline-chemistry')),
                    )
                    .decoration
                as BoxDecoration)
            .border,
        isNotNull,
      );
      expect(
        (tester
                    .widget<DecoratedBox>(
                      find.byKey(const ValueKey('meeting-outline-even')),
                    )
                    .decoration
                as BoxDecoration)
            .border,
        isNull,
      );
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

      final displayedSurface = Theme.of(
        tester.element(find.byKey(const ValueKey('timetable-grid-background'))),
      ).colorScheme.surface;
      await tester.tap(find.byTooltip('Export'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Export PNG'));
      await tester.pumpAndSettle();
      expect(writer.file?.extension, 'png');
      expect(pngEncoder.fontScale, 1);
      expect(pngEncoder.fontFamily, 'PKU Noto Serif CJK SC');
      expect(pngEncoder.fontWeight, FontWeight.w400);
      expect(pngEncoder.indexColor, timetableIndexSurface);
      expect(pngEncoder.autoTextColor, isFalse);
      expect(pngEncoder.brightness, Brightness.light);
      expect(pngEncoder.surfaceColor, displayedSurface);

      writer.fail = true;
      await tester.tap(find.byTooltip('Export'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Export PNG'));
      await tester.pumpAndSettle();
      expect(find.text('Export failed'), findsOneWidget);

      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      expect(
        tester
            .widget<MouseRegion>(
              find
                  .ancestor(
                    of: find.byKey(const ValueKey('meeting-cell-first')),
                    matching: find.byType(MouseRegion),
                  )
                  .first,
            )
            .cursor,
        SystemMouseCursors.click,
      );
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
      expect(find.text('08:00–09:50'), findsOneWidget);
      expect(
        find.descendant(of: hover, matching: find.byType(Divider)),
        findsNWidgets(5),
      );
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
      await tester.pump();
      expect(find.text('Save'), findsNothing);
      expect(controller.timetable!.atPeriod(1, 4).single.name, 'New course');
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();

      final initialRefreshes = weeks.refreshes;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(weeks.refreshes, initialRefreshes + 1);
      await tester.tap(find.text('Settings'));
      await tester.pump();
      expect(find.text('Theme'), findsOneWidget);
      appearance.setDarkMode(true);
      appearance.setAccent(const Color(0xffad1457));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('dark-mode')), findsOneWidget);
      expect(appearance.darkMode, isTrue);
      expect(appearance.accent, const Color(0xffad1457));
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('show-roll-navbar')),
        300,
        scrollable: find.byType(Scrollable).at(1),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('show-roll-navbar')));
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(find.text('Theme'), findsOneWidget);
      expect(appearance.showRollInNavbar, isFalse);
      await tester.tap(find.text('Timetable'));
      await tester.pump();
      expect(find.byTooltip('Roll colors'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('meeting-cell-first')));
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsNothing);
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
        _meeting('chemistry', 4, WeekFrequency.every),
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
        clock: () => DateTime.utc(2026, 9, 6, 15),
      )..start();
      final appearance = AppearanceController(MemoryAppearanceStore())
        ..setLanguage(AppLanguage.en)
        ..setUiScale(1)
        ..setTimetableIndexColor(const Color(0xffabcdef));
      final calendar = CalendarScheduleController(MemoryCalendarScheduleStore())
        ..create(
          title: 'Homework deadline',
          startsAt: DateTime.utc(2026, 9, 7, 1),
          allDay: false,
          relatedClassSourceId: 'first',
          note: 'Submit online',
        )
        ..create(
          title: 'All-day deadline',
          startsAt: DateTime.utc(2026, 9, 6, 16),
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
      final bottomSpacer = find.byKey(const ValueKey('app-bottom-spacer'));
      expect(tester.getSize(bottomSpacer).height, 8);
      expect(tester.getBottomRight(bottomSpacer).dy, 800);
      expect(
        find.byKey(const ValueKey('upcoming-schedule-pane')),
        findsOneWidget,
      );
      expect(find.text('Upcoming schedule'), findsOneWidget);
      expect(find.text('Homework deadline'), findsOneWidget);
      expect(find.text('All-day deadline'), findsOneWidget);
      expect(
        tester
            .widget<SizedBox>(
              find.byKey(const ValueKey('upcoming-schedule-gap-0')),
            )
            .height,
        12,
      );
      expect(find.textContaining('2026-09-07'), findsNWidgets(3));
      expect(find.textContaining('09:00'), findsOneWidget);
      expect(find.text('All day'), findsNothing);
      expect(
        tester
            .widget<Material>(
              find.byKey(const ValueKey('upcoming-schedule-color-1')),
            )
            .color,
        scheduleColor(
          tester.element(
            find.byKey(const ValueKey('upcoming-schedule-color-1')),
          ),
          calendar.schedules.first,
        ),
      );
      expect(
        find.byKey(const ValueKey('upcoming-related-class-1')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('upcoming-schedule-1')),
          matching: find.textContaining('Algebra'),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('upcoming-schedule-1')),
          matching: find.textContaining('DDL:'),
        ),
        findsOneWidget,
      );
      final scheduleInfo = find.byKey(
        const ValueKey('upcoming-schedule-info-1'),
      );
      expect(tester.widget<Text>(scheduleInfo).data, '2026-09-07 09:00');
      final deadlineText = tester.widget<Text>(
        find.byKey(const ValueKey('upcoming-schedule-deadline-1')),
      );
      final deadlineSpans = (deadlineText.textSpan! as TextSpan).children!;
      expect((deadlineSpans.first as TextSpan).text, 'DDL: ');
      expect((deadlineSpans.last as TextSpan).text, '10h 0m');
      expect(
        (deadlineSpans.last as TextSpan).style!.fontSize,
        (deadlineSpans.first as TextSpan).style!.fontSize! * 1.25,
      );
      expect(
        tester
            .getTopLeft(
              find.byKey(const ValueKey('upcoming-schedule-deadline-1')),
            )
            .dx,
        greaterThan(tester.getTopLeft(scheduleInfo).dx),
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('upcoming-related-class-1')),
          matching: find.textContaining('DDL:'),
        ),
        findsNothing,
      );
      final scheduleMouse = await tester.createGesture(
        kind: PointerDeviceKind.mouse,
      );
      await scheduleMouse.addPointer(
        location: tester.getCenter(
          find.byKey(const ValueKey('upcoming-schedule-1')),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      final scheduleHover = find.byKey(
        const ValueKey('upcoming-schedule-hover-card-1'),
      );
      expect(scheduleHover, findsOneWidget);
      expect(find.textContaining('Submit online'), findsOneWidget);
      final scheduleHoverBefore = tester.getTopLeft(scheduleHover);
      await scheduleMouse.moveBy(const Offset(24, 16));
      await tester.pump();
      expect(tester.getTopLeft(scheduleHover), isNot(scheduleHoverBefore));
      expect(
        tester
            .widget<MouseRegion>(
              find
                  .ancestor(
                    of: find.byKey(const ValueKey('upcoming-schedule-1')),
                    matching: find.byType(MouseRegion),
                  )
                  .first,
            )
            .cursor,
        SystemMouseCursors.click,
      );
      await scheduleMouse.removePointer();
      await tester.pump();
      final relatedMouse = await tester.createGesture(
        kind: PointerDeviceKind.mouse,
      );
      await relatedMouse.addPointer(
        location: tester.getCenter(
          find.byKey(const ValueKey('meeting-cell-first')),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('meeting-hover-first')),
          matching: find.textContaining('Homework deadline'),
        ),
        findsOneWidget,
      );
      await relatedMouse.removePointer();
      await tester.pump();
      await _singleTap(
        tester,
        find.byKey(const ValueKey('upcoming-schedule-1')),
      );
      expect(find.byKey(const ValueKey('schedule-editor')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('cancel-schedule-editor')));
      await tester.pumpAndSettle();
      await _singleTap(
        tester,
        find.byKey(const ValueKey('upcoming-related-class-1')),
      );
      expect(find.byKey(const ValueKey('course-editor-pane')), findsOneWidget);
      await tester.tap(find.text('Close'));
      await tester.pump();
      await _doubleTap(
        tester,
        find.byKey(const ValueKey('upcoming-related-class-1')),
      );
      await tester.pump();
      expect(find.byKey(const ValueKey('course-editor-pane')), findsNothing);
      expect(
        tester
            .widget<FlashingOutline>(
              find.byKey(const ValueKey('meeting-flash-first')),
            )
            .active,
        isTrue,
      );
      await tester.pump(const Duration(milliseconds: 1500));
      await _doubleTap(
        tester,
        find.byKey(const ValueKey('upcoming-schedule-1')),
      );
      await tester.pump();
      expect(find.byKey(const ValueKey('calendar-page')), findsOneWidget);
      expect(find.byKey(const ValueKey('schedule-editor')), findsNothing);
      expect(
        tester
            .widget<FlashingOutline>(
              find.byKey(const ValueKey('calendar-schedule-flash-1')),
            )
            .active,
        isTrue,
      );
      await tester.pump(const Duration(milliseconds: 1500));
      expect(
        tester
            .widget<FlashingOutline>(
              find.byKey(const ValueKey('calendar-schedule-flash-1')),
            )
            .active,
        isFalse,
      );
      await tester.tap(find.text('Timetable'));
      await tester.pump();
      final editMouse = await tester.createGesture(
        kind: PointerDeviceKind.mouse,
        buttons: kSecondaryMouseButton,
      );
      await editMouse.down(
        tester.getCenter(find.byKey(const ValueKey('upcoming-schedule-1'))),
      );
      await editMouse.up();
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('schedule-editor')), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('schedule-title')),
        'Updated deadline',
      );
      await tester.tap(find.byKey(const ValueKey('save-schedule-editor')));
      await tester.pumpAndSettle();
      expect(calendar.schedules.first.title, 'Updated deadline');
      expect(find.text('Schedule could not be updated'), findsNothing);
      await tester.longPress(find.byKey(const ValueKey('upcoming-schedule-1')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('schedule-editor')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('cancel-schedule-editor')));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('upcoming-schedule-pane')),
          matching: find.textContaining('Algebra'),
        ),
        findsOneWidget,
      );
      expect(
        tester
            .widget<Material>(find.byKey(const ValueKey('meeting-color-first')))
            .color,
        const Color(0xff123456),
      );
      expect(
        (tester
                    .widget<Container>(
                      find.byKey(const ValueKey('timetable-weekday-row')),
                    )
                    .decoration
                as BoxDecoration)
            .color,
        const Color(0xffabcdef),
      );
      expect(
        tester
            .widget<ColoredBox>(find.byKey(const ValueKey('timetable-index-1')))
            .color,
        const Color(0xffabcdef),
      );
      expect(
        tester
            .widget<DefaultTextStyle>(
              find.byKey(const ValueKey('meeting-text-style-first')),
            )
            .style
            .color,
        Colors.black,
      );
      appearance.setAutoTextColor(true);
      await tester.pump();
      expect(
        tester
            .widget<DefaultTextStyle>(
              find.byKey(const ValueKey('meeting-text-style-first')),
            )
            .style
            .color,
        Colors.white,
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
      expect(find.byKey(const ValueKey('calendar-next-month')), findsNothing);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('calendar-page')),
          matching: find.textContaining('Updated deadline'),
        ),
        findsOneWidget,
      );
      for (var week = 0; week < 4; week++) {
        await tester.drag(find.byType(PageView), const Offset(0, -180));
        await tester.pumpAndSettle();
      }
      expect(find.text('October 2026'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(find.text('September 2026'), findsOneWidget);
      await _singleTap(
        tester,
        find.byKey(const ValueKey('calendar-schedule-1')),
      );
      expect(find.byKey(const ValueKey('schedule-editor')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('cancel-schedule-editor')));
      await tester.pumpAndSettle();
      await _doubleTap(
        tester,
        find.byKey(const ValueKey('calendar-schedule-1')),
      );
      await tester.pump();
      expect(
        find.byKey(const ValueKey('upcoming-schedule-pane')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('schedule-editor')), findsNothing);
      expect(
        tester
            .widget<FlashingOutline>(
              find.byKey(const ValueKey('meeting-flash-first')),
            )
            .active,
        isTrue,
      );
      await tester.pump(const Duration(milliseconds: 1500));
      await tester.tap(find.text('Calendar'));
      await tester.pump();
      await tester.longPress(find.byKey(const ValueKey('calendar-schedule-1')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('schedule-editor')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('cancel-schedule-editor')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('upcoming-class-pane')), findsOneWidget);
      expect(find.text("Tomorrow's classes"), findsOneWidget);
      expect(find.text('Algebra'), findsOneWidget);
      expect(find.text('Chemistry'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('upcoming-class-first')),
          matching: find.textContaining('DDL:'),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('tomorrow-schedule-1')),
          matching: find.textContaining('DDL:'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('upcoming-class-pane')),
          matching: find.textContaining('Updated deadline'),
        ),
        findsOneWidget,
      );
      expect(find.text('Schedules without a related class'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('upcoming-class-pane')),
          matching: find.text('All-day deadline'),
        ),
        findsOneWidget,
      );
      expect(find.text('Upcoming schedule'), findsNothing);
      await _singleTap(
        tester,
        find.byKey(const ValueKey('tomorrow-schedule-1')),
      );
      expect(find.byKey(const ValueKey('schedule-editor')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('cancel-schedule-editor')));
      await tester.pumpAndSettle();
      await _doubleTap(
        tester,
        find.byKey(const ValueKey('tomorrow-schedule-1')),
      );
      await tester.pump();
      expect(find.byKey(const ValueKey('schedule-editor')), findsNothing);
      expect(
        tester
            .widget<FlashingOutline>(
              find.byKey(const ValueKey('calendar-schedule-flash-1')),
            )
            .active,
        isTrue,
      );
      await tester.pump(const Duration(milliseconds: 1500));
      await _singleTap(
        tester,
        find.byKey(const ValueKey('upcoming-class-first')),
      );
      expect(find.byKey(const ValueKey('course-editor-pane')), findsOneWidget);
      await tester.tap(find.text('Close'));
      await tester.pump();
      await tester.tap(find.text('Calendar'));
      await tester.pump();
      await _doubleTap(
        tester,
        find.byKey(const ValueKey('upcoming-class-first')),
      );
      await tester.pump();
      expect(find.byKey(const ValueKey('course-editor-pane')), findsNothing);
      expect(
        find.byKey(const ValueKey('upcoming-schedule-pane')),
        findsOneWidget,
      );
      expect(
        tester
            .widget<FlashingOutline>(
              find.byKey(const ValueKey('meeting-flash-first')),
            )
            .active,
        isTrue,
      );
      await tester.pump(const Duration(milliseconds: 1500));
      expect(
        tester
            .widget<FlashingOutline>(
              find.byKey(const ValueKey('meeting-flash-first')),
            )
            .active,
        isFalse,
      );

      await tester.tap(find.byKey(const ValueKey('meeting-cell-first')));
      await tester.pump();
      expect(find.byKey(const ValueKey('course-editor-pane')), findsOneWidget);
      expect(find.byType(Dialog), findsNothing);
      await tester.enterText(
        find.byKey(const ValueKey('course-name')),
        'Grouped course',
      );
      await tester.pump();
      expect(find.text('Save'), findsNothing);
      expect(
        controller.timetable!.meetings
            .where(
              (meeting) => const {'first', 'second'}.contains(meeting.sourceId),
            )
            .map((meeting) => meeting.name),
        everyElement('Grouped course'),
      );
      expect(find.byKey(const ValueKey('course-editor-pane')), findsOneWidget);
      await tester.tap(find.text('Close'));
      await tester.pump();
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
