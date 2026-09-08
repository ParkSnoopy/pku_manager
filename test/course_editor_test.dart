import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pku_manager/domain/course_meeting.dart';
import 'package:pku_manager/features/timetable/course_editor_dialog.dart';

import 'package:pku_manager/l10n/app_strings.dart';

void main() {
  testWidgets('group editor returns one manual style for every source record', (
    tester,
  ) async {
    CourseEditResult? result;
    final meetings = [
      CourseMeeting(
        sourceId: 'first',
        name: '八个汉字课程名称',
        weekday: 1,
        firstPeriod: 1,
        lastPeriod: 1,
      ),
      CourseMeeting(
        sourceId: 'second',
        name: '八个汉字课程名称',
        weekday: 1,
        firstPeriod: 2,
        lastPeriod: 2,
      ),
    ];
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        supportedLocales: AppStrings.supportedLocales,
        localizationsDelegates: AppStrings.localizationsDelegates,
        home: Scaffold(
          body: CourseEditorDialog(
            weekday: 1,
            period: 1,
            periodCount: 12,
            meetings: meetings,
            embedded: true,
            suggestedColor: const Color(0xffabcdef),
            colorPicker: (context, {required color, required title}) async =>
                title == 'Outline color'
                ? const Color(0xff246813)
                : const Color(0xff135724),
            onCancel: () {},
            onResult: (value) => result = value,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Rolled color'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('course-custom-color')));
    await tester.pump();
    expect(find.text('Custom color'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const ValueKey('course-color-lock')));
    await tester.tap(find.byKey(const ValueKey('course-color-lock')));
    await tester.drag(find.byType(ListView), const Offset(0, -300));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('course-important-outline')));
    await tester.pump();
    final initialSlider = tester.widget<Slider>(
      find.byKey(const ValueKey('course-outline-thickness')),
    );
    expect(initialSlider.value, 1.5);
    await tester.tap(find.byKey(const ValueKey('course-outline-color')));
    await tester.pump();
    initialSlider.onChanged!(3.5);
    await tester.pump();
    await tester.ensureVisible(find.text('Save'));
    await tester.tap(find.text('Save'));
    await tester.pump();
    expect(result, isNotNull);
    expect(result!.meetings.map((meeting) => meeting.sourceId), [
      'first',
      'second',
    ]);
    expect(result!.appearance.color, const Color(0xff135724));
    expect(result!.appearance.lockColor, isFalse);
    expect(result!.appearance.outlined, isTrue);
    expect(result!.appearance.outlineColor, const Color(0xff246813));
    expect(result!.appearance.outlineWidth, 3.5);
  });
}
