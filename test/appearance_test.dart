import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pku_manager/data/app_database.dart';
import 'package:pku_manager/data/file_device_settings_store.dart';
import 'package:pku_manager/data/sqlite_appearance_store.dart';
import 'package:pku_manager/domain/application_close_action.dart';
import 'package:pku_manager/domain/course.dart';
import 'package:pku_manager/features/settings/appearance_controller.dart';
import 'package:pku_manager/features/settings/settings_page.dart';
import 'package:pku_manager/features/timetable/timetable_color.dart';
import 'package:pku_manager/l10n/app_strings.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  test('schema zero migrates to version one without losing data', () {
    final directory = Directory.systemTemp.createTempSync('pku-schema-test-');
    addTearDown(() => directory.deleteSync(recursive: true));
    final path = '${directory.path}/legacy.sqlite3';
    var database = AppDatabase(path);
    database.database.execute(
      'INSERT INTO week_cache(id, content, fetched_at) VALUES (1, ?, ?)',
      ['legacy', '2026-09-12T00:00:00Z'],
    );
    database.database.userVersion = 0;
    database.close();

    database = AppDatabase(path);
    addTearDown(database.close);
    expect(database.database.userVersion, appDatabaseSchemaVersion);
    expect(
      database.database
          .select('SELECT content FROM week_cache')
          .single['content'],
      'legacy',
    );
  });

  test('future and malformed legacy schemas fail without mutation', () {
    final directory = Directory.systemTemp.createTempSync('pku-schema-test-');
    addTearDown(() => directory.deleteSync(recursive: true));
    final futurePath = '${directory.path}/future.sqlite3';
    var raw = sqlite3.open(futurePath);
    raw.userVersion = appDatabaseSchemaVersion + 1;
    raw.close();
    expect(() => AppDatabase(futurePath), throwsFormatException);

    final malformedPath = '${directory.path}/malformed.sqlite3';
    raw = sqlite3.open(malformedPath);
    raw.execute('CREATE TABLE sources(id INTEGER PRIMARY KEY)');
    raw.close();
    expect(() => AppDatabase(malformedPath), throwsFormatException);

    raw = sqlite3.open(malformedPath);
    expect(raw.userVersion, 0);
    raw.close();

    final triggerPath = '${directory.path}/missing-trigger.sqlite3';
    final database = AppDatabase(triggerPath);
    database.database.execute('DROP TRIGGER immutable_source');
    database.database.userVersion = 0;
    database.close();
    expect(() => AppDatabase(triggerPath), throwsFormatException);
    raw = sqlite3.open(triggerPath);
    expect(raw.userVersion, 0);
    raw.close();
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
        'INSERT INTO user_meetings VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        [1, identity, identity, '', 1, 1, 1, '', '每周', '', ''],
      );
    }
    final controller = AppearanceController(store);
    expect(controller.language, AppLanguage.ko);
    expect(controller.paletteSeed, 0);
    expect(controller.rollPaletteIndex, 0);
    expect(controller.accent, const Color(0xffff5722));
    expect(controller.fontFamily, AppFontFamily.serif);
    expect(controller.fontScale, 1);

    expect(controller.fontWeightValue, 400);
    expect(controller.timetableFontScale, 1);
    expect(controller.timetableIndexColor, const Color(0xffe8e0d2));
    expect(controller.autoTextColor, isFalse);
    expect(controller.darkMode, isFalse);
    expect(controller.blendAccentIntoTheme, isFalse);
    expect(controller.applicationCloseAction, ApplicationCloseAction.closeApp);
    expect(appearanceAccents, const [
      Color(0xffffb3ba),
      Color(0xffffd3b6),
      Color(0xfffffacd),
      Color(0xffbffcc6),
      Color(0xffbfd7ff),
      Color(0xffdcc6e0),
    ]);
    for (var weight = 100; weight <= 900; weight += 100) {
      controller.setFontWeight(weight);
      expect(controller.fontWeight.value, weight);
    }
    controller.setFontWeight(400);
    expect(rollPalettes.first.name, 'Custom');
    expect(controller.customPalette, const [
      Color(0xff79adac),
      Color(0xffbeadf2),
      Color(0xffa0c8f2),
      Color(0xffadf7b6),
      Color(0xffffea99),
    ]);

    controller.setLanguage(AppLanguage.zhHans);
    controller.setAccent(const Color(0xff00695c));
    controller.setShowRollInNavbar(false);
    controller.cycleFontFamily();
    controller.setRollPalette(3);
    controller.setFontScale(1.4);
    controller.setUiScale(1.75);
    controller.setFontWeight(900);
    controller.setTimetableFontScale(1.6);
    controller.setTimetableIndexColor(const Color(0xff112233));
    controller.setAutoTextColor(true);
    controller.setDarkMode(true);
    controller.setBlendAccentIntoTheme(true);
    controller.setApplicationCloseAction(
      ApplicationCloseAction.exitToSystemTray,
    );
    controller.setCustomPaletteColor(2, const Color(0xffabcdef));
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
    expect(restored.fontFamily, AppFontFamily.sans);
    expect(restored.fontScale, 1.4);

    expect(restored.fontWeightValue, 900);
    expect(restored.timetableFontScale, 1.6);
    expect(restored.timetableIndexColor, const Color(0xff112233));
    expect(restored.autoTextColor, isTrue);
    expect(restored.darkMode, isTrue);
    expect(restored.blendAccentIntoTheme, isTrue);
    expect(
      restored.applicationCloseAction,
      ApplicationCloseAction.exitToSystemTray,
    );
    expect(restored.customPalette[2], const Color(0xffabcdef));
    expect(
      timetableCourseColor(
        Course(
          sourceId: 'sample',
          name: 'Sample',
          weekday: 1,
          firstPeriod: 1,
          lastPeriod: 1,
        ),
        0,
        customPalette: restored.customPalette,
      ),
      isIn(restored.customPalette),
    );
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

  test('UI scale persists outside the transferable database', () {
    final directory = Directory.systemTemp.createTempSync('pku-ui-scale-test-');
    addTearDown(() => directory.deleteSync(recursive: true));
    final settingsFile = File('${directory.path}/device-settings.json')
      ..writeAsStringSync('{"uiScale":1.75}');
    final settings = FileDeviceSettingsStore(settingsFile);
    final database = AppDatabase('${directory.path}/app.sqlite3');
    addTearDown(database.close);

    expect(settings.loadUiScale(), 1);
    expect(jsonDecode(settingsFile.readAsStringSync()), {
      'formatVersion': 1,
      'uiScale': 1,
    });

    final controller = AppearanceController(
      SqliteAppearanceStore(database),
      deviceSettings: settings,
    );

    controller.setUiScale(1.75);
    expect(
      AppearanceController(
        SqliteAppearanceStore(database),
        deviceSettings: settings,
      ).uiScale,
      1.75,
    );
    controller.setUiScale(1.8);
    expect(settings.loadUiScale(), 1.8);
    expect(() => controller.setUiScale(.45), throwsRangeError);
    expect(() => controller.setUiScale(2.05), throwsRangeError);
    expect(() => controller.setUiScale(1.53), throwsArgumentError);

    settings.purge();
    expect(settingsFile.existsSync(), isFalse);
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
          showCloseAction: true,
          colorPicker: (context, {required color, required title}) async =>
              const Color(0xff234567),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Theme'), findsOneWidget);
    expect(find.byType(DropdownButton<dynamic>), findsNothing);
    expect(find.text('Dark mode'), findsOneWidget);
    expect(controller.darkMode, isFalse);
    await tester.tap(find.byKey(const ValueKey('dark-mode')));
    await tester.pump();
    expect(controller.darkMode, isTrue);
    await tester.tap(find.byKey(const ValueKey('blend-accent-theme')));
    await tester.pump();
    expect(controller.blendAccentIntoTheme, isTrue);
    await tester.ensureVisible(find.byKey(const ValueKey('ui-scale')));
    await tester.enterText(find.byKey(const ValueKey('ui-scale-input')), '175');
    await tester.pump();
    expect(controller.uiScale, 1.75);
    await tester.enterText(find.byKey(const ValueKey('ui-scale-input')), '173');
    await tester.pump();
    expect(controller.uiScale, 1.75);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('language-cycle')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
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
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('custom-accent-color')),
      -300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const ValueKey('accent-ffbffcc6')));
    await tester.pump();
    expect(controller.accent, const Color(0xffbffcc6));
    await tester.tap(find.byKey(const ValueKey('custom-accent-color')));
    await tester.pump();
    expect(controller.accent, const Color(0xff234567));
    expect(find.text('Custom'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('custom-palette-color-0')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('custom-palette-color-0')));
    await tester.pump();
    expect(controller.customPalette.first, const Color(0xff234567));
    expect(find.text('1'), findsNothing);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('roll-palette-menu')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const ValueKey('roll-palette-menu')));
    await tester.pumpAndSettle();
    expect(find.text('Golden Summer Fields'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('roll-palette-2')));
    await tester.pumpAndSettle();
    expect(controller.rollPaletteIndex, 2);
    expect(find.text('Golden Summer Fields'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('font-scale')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.drag(
      find.byKey(const ValueKey('font-scale')),
      const Offset(80, 0),
    );
    await tester.pump();
    expect(controller.fontScale, greaterThan(1));
    await tester.enterText(
      find.byKey(const ValueKey('font-scale-input')),
      '80',
    );
    await tester.pump();
    expect(controller.fontScale, .8);
    await tester.enterText(
      find.byKey(const ValueKey('font-scale-input')),
      '79',
    );
    await tester.pump();
    expect(controller.fontScale, .8);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('font-family-cycle')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const ValueKey('font-family-cycle')));
    await tester.pump();
    expect(controller.fontFamily, AppFontFamily.sans);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('font-weight')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.drag(
      find.byKey(const ValueKey('font-weight')),
      const Offset(500, 0),
    );
    await tester.pump();
    expect(controller.fontWeightValue, 900);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('timetable-font-scale')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.drag(
      find.byKey(const ValueKey('timetable-font-scale')),
      const Offset(250, 0),
    );
    await tester.pump();
    expect(controller.timetableFontScale, greaterThan(1));
    await tester.enterText(
      find.byKey(const ValueKey('timetable-font-scale-input')),
      '200',
    );
    await tester.pump();
    expect(controller.timetableFontScale, 2);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('auto-text-color')),
      -300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.byKey(const ValueKey('auto-text-color')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('auto-text-color')));
    await tester.pump();
    expect(controller.autoTextColor, isTrue);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('timetable-index-color')),
      -300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(
      find.byKey(const ValueKey('timetable-index-color')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('timetable-index-color')));
    await tester.pump();
    expect(controller.timetableIndexColor, const Color(0xff234567));
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('show-roll-navbar')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.byKey(const ValueKey('show-roll-navbar')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('show-roll-navbar')));
    await tester.pump();
    expect(controller.showRollInNavbar, isFalse);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('on-application-close')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('On application close'), findsOneWidget);
    expect(find.text('Close the app'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('on-application-close')));
    await tester.pump();
    expect(
      controller.applicationCloseAction,
      ApplicationCloseAction.exitToSystemTray,
    );
    expect(find.text('Exit to system tray'), findsOneWidget);
  });

  testWidgets(
    'settings exports and confirms replacement before app data import',
    (tester) async {
      tester.view.physicalSize = const Size(900, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = AppearanceController(MemoryAppearanceStore());
      var exports = 0;
      var imports = 0;
      var purges = 0;
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          supportedLocales: AppStrings.supportedLocales,
          localizationsDelegates: AppStrings.localizationsDelegates,
          home: Scaffold(
            body: SettingsPage(
              controller: controller,
              exportAppData: () async {
                exports++;
                return true;
              },
              importAppData: () async {
                imports++;
                return true;
              },
              purgeAppData: () async {
                purges++;
                return true;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.dragUntilVisible(
        find.byKey(const ValueKey('export-app-data')),
        find.byType(ListView),
        const Offset(0, -500),
      );
      await tester.tap(find.byKey(const ValueKey('export-app-data')));
      await tester.pumpAndSettle();
      expect(exports, 1);
      expect(find.text('App data exported'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('import-app-data')));
      await tester.pumpAndSettle();
      expect(imports, 0);
      expect(
        find.text('Replace current app data with the selected data.'),
        findsOneWidget,
      );
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.widgetWithText(FilledButton, 'Import app data'),
        ),
      );
      await tester.pumpAndSettle();
      expect(imports, 1);
      expect(find.text('App data imported'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('purge-app-data')));
      await tester.pumpAndSettle();
      expect(purges, 0);
      expect(
        find.text(
          'All timetables, schedules, and settings will be permanently deleted.',
        ),
        findsOneWidget,
      );
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.widgetWithText(FilledButton, 'Purge app data'),
        ),
      );
      await tester.pumpAndSettle();
      expect(purges, 1);
      expect(find.text('App data purged'), findsOneWidget);
    },
  );
}
