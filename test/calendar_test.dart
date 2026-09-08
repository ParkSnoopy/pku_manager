import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pku_manager/features/calendar/calendar_page.dart';
import 'package:pku_manager/l10n/app_strings.dart';

void main() {
  testWidgets('calendar renders an independent empty month', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        supportedLocales: AppStrings.supportedLocales,
        localizationsDelegates: AppStrings.localizationsDelegates,
        home: CalendarPage(now: DateTime.utc(2026, 9, 7)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('calendar-page')), findsOneWidget);
    expect(find.byKey(const ValueKey('calendar-month-grid')), findsOneWidget);
    expect(find.byKey(const ValueKey('calendar-day-2026-9-7')), findsOneWidget);
  });
}
