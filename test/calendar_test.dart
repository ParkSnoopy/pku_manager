import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
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
    expect(find.byType(PageView), findsOneWidget);
    expect(
      tester.widget<PageView>(find.byType(PageView)).scrollDirection,
      Axis.vertical,
    );
    expect(
      tester
          .widget<PageView>(find.byType(PageView))
          .controller!
          .viewportFraction,
      .2,
    );
    expect(find.byKey(const ValueKey('calendar-previous-month')), findsNothing);
    expect(find.byKey(const ValueKey('calendar-next-month')), findsNothing);
    expect(find.byKey(const ValueKey('calendar-day-2026-9-7')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('calendar-day-2026-9-7')),
        matching: find.byKey(const ValueKey('calendar-today-label')),
      ),
      findsOneWidget,
    );
    expect(find.text('TODAY'), findsOneWidget);
    expect(
      (tester
                  .widget<DecoratedBox>(
                    find.byKey(const ValueKey('calendar-day-2026-8-31')),
                  )
                  .decoration
              as BoxDecoration)
          .color,
      Colors.transparent,
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
    final septemberFirstBorder =
        (tester
                        .widget<DecoratedBox>(
                          find.byKey(const ValueKey('calendar-day-2026-9-1')),
                        )
                        .decoration
                    as BoxDecoration)
                .border!
            as Border;
    expect(septemberFirstBorder.left.width, 2);
    expect(septemberFirstBorder.top.width, .5);
    expect(
      find.byKey(const ValueKey('calendar-add-2026-8-31')),
      findsOneWidget,
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
    final dayRect = tester.getRect(
      find.byKey(const ValueKey('calendar-day-2026-9-7')),
    );
    final scheduleRect = tester.getRect(
      find.byKey(const ValueKey('calendar-schedule-color-1')),
    );
    expect(scheduleRect.left, dayRect.left);
    expect(scheduleRect.right, dayRect.right);

    await tester.longPress(find.byKey(const ValueKey('calendar-schedule-1')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('schedule-title')),
      'Meeting info',
    );
    await tester.tap(find.byKey(const ValueKey('cancel-schedule-editor')));
    await tester.pumpAndSettle();
    expect(controller.schedules.single.title, 'Homework deadline');

    await tester.longPress(find.byKey(const ValueKey('calendar-schedule-1')));
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

  testWidgets('calendar wheel input accumulates before scrolling a week', (
    tester,
  ) async {
    final controller = CalendarScheduleController(
      MemoryCalendarScheduleStore(),
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        supportedLocales: AppStrings.supportedLocales,
        localizationsDelegates: AppStrings.localizationsDelegates,
        home: CalendarPage(
          now: DateTime.utc(2026, 9, 7),
          controller: controller,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final grid = find.byKey(const ValueKey('calendar-month-grid'));
    final pageController = tester.widget<PageView>(grid).controller!;
    final initialPage = pageController.page;
    await tester.sendEventToBinding(
      PointerScrollEvent(
        position: tester.getCenter(grid),
        scrollDelta: const Offset(0, 100),
      ),
    );
    await tester.pumpAndSettle();
    expect(pageController.page, initialPage);
    expect(find.text('September 2026'), findsOneWidget);

    for (var event = 0; event < 2; event++) {
      await tester.sendEventToBinding(
        PointerScrollEvent(
          position: tester.getCenter(grid),
          scrollDelta: const Offset(0, 100),
        ),
      );
      await tester.pumpAndSettle();
    }
    expect(pageController.page, initialPage! + 2);
    expect(find.text('October 2026'), findsOneWidget);
  });
}
