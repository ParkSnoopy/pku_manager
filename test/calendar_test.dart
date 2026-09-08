import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('calendar-page')), findsOneWidget);
    expect(find.byKey(const ValueKey('calendar-month-grid')), findsOneWidget);
    expect(find.byKey(const ValueKey('calendar-day-2026-9-7')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('calendar-add-2026-9-7')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('schedule-title')),
      'Homework deadline',
    );
    await tester.tap(find.byKey(const ValueKey('save-schedule')));
    await tester.pumpAndSettle();
    expect(controller.schedules.single.title, 'Homework deadline');
    expect(find.textContaining('Homework deadline'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('calendar-schedule-1')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('schedule-title')),
      'Meeting info',
    );
    await tester.tap(find.byKey(const ValueKey('save-schedule')));
    await tester.pumpAndSettle();
    expect(controller.schedules.single.title, 'Meeting info');

    await tester.tap(find.byKey(const ValueKey('calendar-schedule-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('remove-schedule')));
    await tester.pumpAndSettle();
    expect(controller.schedules, isEmpty);
  });
}
