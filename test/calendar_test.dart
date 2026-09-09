import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pku_manager/domain/course.dart';
import 'package:pku_manager/domain/timetable.dart';
import 'package:pku_manager/features/calendar/calendar_schedule_controller.dart';
import 'package:pku_manager/features/calendar/calendar_page.dart';
import 'package:pku_manager/l10n/app_strings.dart';

void main() {
  testWidgets('schedule editor saves or cancels a blank colorable draft', (
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
          colorPicker: (context, {required color, required title}) async =>
              const Color(0xff123456),
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
    expect(
      (tester
                  .widget<DecoratedBox>(
                    find.byKey(const ValueKey('calendar-day-2026-8-31')),
                  )
                  .decoration
              as BoxDecoration)
          .color,
      const Color(0xffd3d3d3),
    );
    expect(
      (tester
                  .widget<DecoratedBox>(
                    find.byKey(const ValueKey('calendar-day-2026-9-7')),
                  )
                  .decoration
              as BoxDecoration)
          .color,
      Colors.transparent,
    );

    await tester.tap(find.byKey(const ValueKey('calendar-add-2026-9-7')));
    await tester.pumpAndSettle();
    expect(controller.schedules, isEmpty);
    expect(find.text('New schedule'), findsNothing);
    expect(find.byKey(const ValueKey('remove-schedule')), findsNothing);
    expect(find.byKey(const ValueKey('close-schedule-editor')), findsNothing);
    expect(
      find.byKey(const ValueKey('cancel-schedule-editor')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('save-schedule-editor')), findsOneWidget);
    expect(find.byKey(const ValueKey('schedule-color')), findsOneWidget);
    expect(find.byKey(const ValueKey('schedule-color-unfix')), findsNothing);
    expect(find.byKey(const ValueKey('schedule-note')), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const ValueKey('schedule-editor'))).width,
      greaterThan(500),
    );
    expect(find.byKey(const ValueKey('schedule-time')), findsNothing);
    await tester.enterText(
      find.byKey(const ValueKey('schedule-title')),
      'Homework deadline',
    );
    await tester.tap(find.byKey(const ValueKey('schedule-all-day')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('schedule-time')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('schedule-related-class')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Original class').last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('schedule-note')),
      'Bring notes',
    );
    await tester.ensureVisible(find.byKey(const ValueKey('schedule-color')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('schedule-color')));
    await tester.pump();
    expect(find.byKey(const ValueKey('schedule-color-unfix')), findsOneWidget);
    expect(controller.schedules, isEmpty);
    await tester.tap(find.byKey(const ValueKey('save-schedule-editor')));
    await tester.pumpAndSettle();
    expect(controller.schedules.single.title, 'Homework deadline');
    expect(controller.schedules.single.note, 'Bring notes');
    expect(controller.schedules.single.colorValue, 0xff123456);
    expect(controller.schedules.single.allDay, isFalse);
    expect(controller.schedules.single.relatedClassSourceId, 'original-class');
    expect(find.textContaining('Homework deadline'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('calendar-schedule-1')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('schedule-title')),
      'Meeting info',
    );
    await tester.tap(find.byKey(const ValueKey('cancel-schedule-editor')));
    await tester.pumpAndSettle();
    expect(controller.schedules.single.title, 'Homework deadline');

    await tester.tap(find.byKey(const ValueKey('calendar-schedule-1')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('schedule-title')),
      'Meeting info',
    );
    await tester.ensureVisible(
      find.byKey(const ValueKey('schedule-color-unfix')),
    );
    await tester.tap(find.byKey(const ValueKey('schedule-color-unfix')));
    await tester.pump();
    expect(find.byKey(const ValueKey('schedule-color-unfix')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('save-schedule-editor')));
    await tester.pumpAndSettle();
    expect(controller.schedules.single.title, 'Meeting info');
    expect(controller.schedules.single.colorValue, isNull);
    expect(
      tester
          .widget<Material>(
            find.byKey(const ValueKey('calendar-schedule-color-1')),
          )
          .color,
      Theme.of(
        tester.element(find.byKey(const ValueKey('calendar-schedule-color-1'))),
      ).colorScheme.primary,
    );
  });
}
