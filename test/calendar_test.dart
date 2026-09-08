import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pku_manager/domain/course.dart';
import 'package:pku_manager/domain/timetable.dart';
import 'package:pku_manager/features/calendar/calendar_schedule_controller.dart';
import 'package:pku_manager/features/calendar/calendar_page.dart';
import 'package:pku_manager/l10n/app_strings.dart';

void main() {
  testWidgets('user schedules can be added, edited, and removed', (
    tester,
  ) async {
    final controller = CalendarScheduleController(
      MemoryCalendarScheduleStore(),
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        supportedLocales: AppStrings.supportedLocales,
        localizationsDelegates: AppStrings.localizationsDelegates,
        home: CalendarPage(
          now: DateTime.utc(2026, 9, 7),
          controller: controller,
          timetable: Timetable([
            Course(
              sourceId: 'original-class',
              name: 'Displayed class',
              sourceName: 'Original class',
              weekday: 1,
              firstPeriod: 1,
              lastPeriod: 2,
            ),
          ], periodCount: 2),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('calendar-page')), findsOneWidget);
    expect(find.byKey(const ValueKey('calendar-month-grid')), findsOneWidget);
    expect(find.byKey(const ValueKey('calendar-day-2026-9-7')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('calendar-add-2026-9-7')));
    await tester.pumpAndSettle();
    expect(controller.schedules.single.allDay, isTrue);
    expect(find.byKey(const ValueKey('schedule-time')), findsNothing);
    await tester.enterText(
      find.byKey(const ValueKey('schedule-title')),
      'Homework deadline',
    );
    await tester.pump();
    expect(controller.schedules.single.title, 'Homework deadline');
    await tester.tap(find.byKey(const ValueKey('schedule-all-day')));
    await tester.pumpAndSettle();
    expect(controller.schedules.single.allDay, isFalse);
    expect(find.byKey(const ValueKey('schedule-time')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('schedule-related-class')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Original class').last);
    await tester.pumpAndSettle();
    expect(controller.schedules.single.relatedClassSourceId, 'original-class');
    expect(find.byKey(const ValueKey('save-schedule')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('close-schedule-editor')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Homework deadline'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('calendar-schedule-1')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('schedule-title')),
      'Meeting info',
    );
    await tester.pump();
    expect(controller.schedules.single.title, 'Meeting info');
    await tester.tap(find.byKey(const ValueKey('close-schedule-editor')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('calendar-schedule-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('remove-schedule')));
    await tester.pumpAndSettle();
    expect(controller.schedules, isEmpty);
  });
}
