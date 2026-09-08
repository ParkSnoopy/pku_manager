import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pku_manager/data/app_database.dart';
import 'package:pku_manager/data/sqlite_appearance_store.dart';
import 'package:pku_manager/features/settings/appearance_controller.dart';
import 'package:pku_manager/features/settings/settings_page.dart';
import 'package:pku_manager/features/timetable/timetable_color.dart';
import 'package:pku_manager/l10n/app_strings.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  test('0.0.x keeps its development database schema at version zero', () {
    final directory = Directory.systemTemp.createTempSync('pku-schema-test-');
    addTearDown(() => directory.deleteSync(recursive: true));
    final path = '${directory.path}/legacy.sqlite3';
    final legacy = sqlite3.open(path);
    legacy.execute('PRAGMA user_version = 6');
    legacy.close();
    expect(() => AppDatabase(path), throwsFormatException);

    final current = AppDatabase(':memory:');
    addTearDown(current.close);
    expect(
      current.database.select('PRAGMA user_version').single.values.single,
      0,
    );
  });

  test('theme and repeated palette rolls persist as typed SQLite values', () {
    final database = AppDatabase(':memory:');
    addTearDown(database.close);
    final store = SqliteAppearanceStore(database);
    database.database.execute(
      'INSERT INTO sources(bytes, period_count) VALUES (?, ?)',
      [
        Uint8List.fromList([1]),
        1,
      ],
    );
    database.database.execute('INSERT INTO active_schedule VALUES (1, 1)');
    for (final identity in ['locked', 'unlocked']) {
      database.database.execute(
        'INSERT INTO user_meetings VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        [1, identity, identity, 1, 1, 1, '', '每周', '', ''],
      );
    }
    final controller = AppearanceController(store);
    expect(controller.language, AppLanguage.ko);
    expect(controller.paletteSeed, 0);
    expect(controller.rollPaletteIndex, 0);
    expect(controller.fontScale, 1.2);
    expect(controller.fontWeightValue, 400);
    for (var weight = 100; weight <= 900; weight += 100) {
      controller.setFontWeight(weight);
      expect(controller.fontWeight.value, weight);
    }
    controller.setFontWeight(400);
    expect(rollPalettes.first.name, 'default Colorful');
    expect(rollPalettes.first.colors, const [
      Color(0xff79adac),
      Color(0xffbeadf2),
      Color(0xffa0c8f2),
      Color(0xffadf7b6),
      Color(0xffffea99),
    ]);

    controller.setLanguage(AppLanguage.zhHans);
    controller.setAccent(const Color(0xff00695c));
    controller.setShowRollInNavbar(false);
    controller.setRollPalette(3);
    controller.setFontScale(1.6);
    controller.setFontWeight(900);
    controller.setCourseAppearance(
      const ['locked'],
      const CourseAppearance(
        color: Color(0xff123456),
        lockColor: true,
        outlined: true,
        outlineColor: Color(0xfffedcba),
        outlineWidth: 3.5,
      ),
    );
    controller.setCourseAppearance(
      const ['unlocked'],
      const CourseAppearance(
        color: Color(0xff654321),
        lockColor: false,
        outlined: true,
      ),
    );
    controller.rollPalette();
    controller.rollPalette();

    final restored = AppearanceController(store);
    expect(restored.language, AppLanguage.zhHans);
    expect(restored.accent, const Color(0xff00695c));
    expect(restored.paletteSeed, 2);
    expect(restored.rollPaletteIndex, 3);
    expect(restored.fontScale, 1.6);
    expect(restored.fontWeightValue, 900);
    expect(restored.showRollInNavbar, isFalse);
    expect(
      restored.courseAppearanceFor('locked'),
      const CourseAppearance(
        color: Color(0xff123456),
        lockColor: true,
        outlined: true,
        outlineColor: Color(0xfffedcba),
        outlineWidth: 3.5,
      ),
    );
    expect(
      restored.courseAppearanceFor('unlocked'),
      const CourseAppearance(lockColor: false, outlined: true),
    );
    database.database.execute(
      'INSERT INTO sources(bytes, period_count) VALUES (?, ?)',
      [
        Uint8List.fromList([2]),
        1,
      ],
    );
    database.database.execute('UPDATE active_schedule SET source = 2');
    restored.reloadCourseAppearances();
    expect(restored.courseAppearances, isEmpty);
  });

  testWidgets('settings page edits theme without a dropdown', (tester) async {
    final database = AppDatabase(':memory:');
    addTearDown(database.close);
    final controller = AppearanceController(SqliteAppearanceStore(database));
    controller.setLanguage(AppLanguage.en);
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        supportedLocales: AppStrings.supportedLocales,
        localizationsDelegates: AppStrings.localizationsDelegates,
        home: SettingsPage(
          controller: controller,
          colorPicker: (context, {required color, required title}) async =>
              const Color(0xff234567),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Theme'), findsOneWidget);
    expect(find.byType(DropdownButton<dynamic>), findsNothing);
    expect(find.text('Dark'), findsNothing);
    expect(find.text('Language'), findsOneWidget);
    expect(find.byType(SegmentedButton<AppLanguage>), findsNothing);
    expect(find.text('English'), findsOneWidget);
    expect(find.text('한국어'), findsNothing);
    expect(find.text('简体中文'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('language-cycle')));
    await tester.pumpAndSettle();
    expect(controller.language, AppLanguage.zhHans);
    expect(find.text('简体中文'), findsOneWidget);
    expect(find.text('English'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('language-cycle')));
    await tester.pumpAndSettle();
    expect(controller.language, AppLanguage.ko);
    expect(find.text('한국어'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('language-cycle')));
    await tester.pumpAndSettle();
    expect(controller.language, AppLanguage.en);
    expect(find.text('English'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('accent-ff00695c')));
    await tester.pump();
    expect(controller.accent, const Color(0xff00695c));
    await tester.tap(find.byKey(const ValueKey('custom-accent-color')));
    await tester.pump();
    expect(controller.accent, const Color(0xff234567));
    expect(find.text('default Colorful'), findsOneWidget);
    expect(find.text('1'), findsNothing);
    await tester.ensureVisible(find.byKey(const ValueKey('roll-palette-menu')));
    await tester.tap(find.byKey(const ValueKey('roll-palette-menu')));
    await tester.pumpAndSettle();
    expect(find.text('Golden Summer Fields'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('roll-palette-2')));
    await tester.pumpAndSettle();
    expect(controller.rollPaletteIndex, 2);
    expect(find.text('Golden Summer Fields'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const ValueKey('font-scale')));
    await tester.drag(
      find.byKey(const ValueKey('font-scale')),
      const Offset(80, 0),
    );
    await tester.pump();
    expect(controller.fontScale, greaterThan(1.2));
    await tester.ensureVisible(find.byKey(const ValueKey('font-weight')));
    await tester.drag(
      find.byKey(const ValueKey('font-weight')),
      const Offset(500, 0),
    );
    await tester.pump();
    expect(controller.fontWeightValue, 900);
    await tester.ensureVisible(find.byKey(const ValueKey('show-roll-navbar')));
    await tester.tap(find.byKey(const ValueKey('show-roll-navbar')));
    await tester.pump();
    expect(controller.showRollInNavbar, isFalse);
  });
}
