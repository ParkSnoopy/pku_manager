import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pku_manager/app/app.dart';
import 'package:pku_manager/data/app_database.dart';
import 'package:pku_manager/data/schedule_repository.dart';
import 'package:pku_manager/data/schedule_xls_parser.dart';
import 'package:pku_manager/data/week_config_parser.dart';
import 'package:pku_manager/data/week_config_repository.dart';
import 'package:pku_manager/domain/application_close_action.dart';
import 'package:pku_manager/domain/schedule_import.dart';
import 'package:pku_manager/domain/semester.dart';
import 'package:pku_manager/features/timetable/timetable_controller.dart';
import 'package:pku_manager/features/timetable/timetable_grid.dart';
import 'package:pku_manager/features/settings/appearance_controller.dart';
import 'package:pku_manager/l10n/app_strings.dart';
import 'package:pku_manager/ui/app_window_controller.dart';

class Picker implements SchedulePicker {
  @override
  Future<Uint8List?> pick() async => null;
}

class TestWindowController extends AppWindowController {
  @override
  bool get supported => true;

  @override
  bool isFullScreen = false;

  @override
  Future<void> toggleFullScreen() async {
    isFullScreen = !isFullScreen;
    notifyListeners();
  }

  ApplicationCloseAction? closeAction;
  String? showLabel;
  String? exitLabel;

  @override
  Future<void> configureCloseAction(
    ApplicationCloseAction action, {
    required String showLabel,
    required String exitLabel,
  }) async {
    closeAction = action;
    this.showLabel = showLabel;
    this.exitLabel = exitLabel;
  }
}

void main() {
  testWidgets(
    'empty timetable, cancellation, populated view and mobile swipe',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final db = AppDatabase(':memory:');
      final parser = ScheduleXlsParser();
      final store = ScheduleRepository(db);
      final controller = TimetableController(
        schedules: store,
        decoder: parser,
        picker: Picker(),
        weeks: WeekConfigRepository(
          db,
          WeekConfigParser(SemesterConfig()),
          fetch: () async => throw StateError('offline'),
        ),
        clock: () => DateTime.utc(2026, 9, 7),
      );
      addTearDown(() {
        db.close();
      });
      final appearance = AppearanceController(MemoryAppearanceStore())
        ..setLanguage(AppLanguage.en)
        ..setUiScale(1);
      final windowController = TestWindowController();
      addTearDown(windowController.dispose);
      await tester.pumpWidget(
        PkuManagerApp(
          controller: controller,
          appearance: appearance,
          windowController: windowController,
        ),
      );
      await tester.pump();
      const nearWhite = Color(0xfffefefe);
      appearance.setAccent(nearWhite);
      await tester.pumpAndSettle();
      final themedContext = tester.element(find.text('Calendar'));
      var theme = Theme.of(themedContext);
      expect(theme.colorScheme.primary, nearWhite);
      expect(theme.colorScheme.onPrimary, Colors.black);
      expect(
        theme.outlinedButtonTheme.style!.foregroundColor!.resolve({}),
        Colors.black,
      );
      expect(
        theme.textButtonTheme.style!.foregroundColor!.resolve({}),
        Colors.black,
      );
      expect(
        theme.filledButtonTheme.style!.foregroundColor!.resolve({}),
        Colors.black,
      );
      appearance.setDarkMode(true);
      await tester.pumpAndSettle();
      theme = Theme.of(tester.element(find.text('Calendar')));
      expect(theme.colorScheme.primary, nearWhite);
      expect(
        theme.outlinedButtonTheme.style!.foregroundColor!.resolve({}),
        Colors.white,
      );
      expect(
        theme.textButtonTheme.style!.foregroundColor!.resolve({}),
        Colors.white,
      );
      appearance.setAccent(const Color(0xff006b50));
      await tester.pumpAndSettle();
      theme = Theme.of(tester.element(find.text('Calendar')));
      expect(
        theme.filledButtonTheme.style!.foregroundColor!.resolve({}),
        Colors.white,
      );
      appearance.setDarkMode(false);
      await tester.pumpAndSettle();
      expect(
        desktopWindowOptions(const Size(800, 600), center: true).size,
        const Size(800, 600),
      );
      expect(windowController.closeAction, ApplicationCloseAction.closeApp);
      expect(windowController.showLabel, 'Show application');
      await tester.tap(find.byTooltip('Full screen'));
      await tester.pump();
      expect(windowController.isFullScreen, isTrue);
      expect(find.byTooltip('Exit full screen'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.f11);
      await tester.pump();
      expect(windowController.isFullScreen, isFalse);
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('on-application-close')),
        300,
        scrollable: find.byType(Scrollable).at(1),
      );
      await tester.tap(find.byKey(const ValueKey('on-application-close')));
      await tester.pump();
      expect(
        windowController.closeAction,
        ApplicationCloseAction.exitToSystemTray,
      );
      expect(windowController.exitLabel, 'Close the app');
      await tester.tap(find.text('Timetable'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Import your exported'), findsOneWidget);
      await tester.tap(find.byTooltip('Import'));
      await tester.pumpAndSettle();
      expect(controller.timetable, isNull);
      final candidate = parser.parseCells(Uint8List.fromList([1]), [
        ['节数', '星期一', '星期二', '星期三', '星期四', '星期五', '星期六', '星期日'],
        ['第一节', 'Algebra(Room)(备注：) 每周', '', '', '', '', '', ''],
      ]);
      store.publish(candidate, {});
      controller.start();
      await tester.pumpAndSettle();
      expect(find.text('Algebra'), findsOneWidget);
      expect(find.text('Monday'), findsOneWidget);
      final indexPosition = tester.getTopLeft(find.text('1'));
      await tester.drag(find.byType(TimetableGrid), const Offset(-600, 0));
      await tester.pumpAndSettle();
      expect(find.text('Tuesday'), findsOneWidget);
      expect(tester.getTopLeft(find.text('1')).dx, indexPosition.dx);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
    },
  );

  testWidgets('first launch requires a language before showing the app', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final database = AppDatabase(':memory:');
    addTearDown(database.close);
    final controller = TimetableController(
      schedules: ScheduleRepository(database),
      decoder: ScheduleXlsParser(),
      picker: Picker(),
      weeks: WeekConfigRepository(
        database,
        WeekConfigParser(SemesterConfig()),
        fetch: () async => throw StateError('offline'),
      ),
    );
    addTearDown(controller.dispose);
    final appearanceStore = MemoryAppearanceStore();
    final appearance = AppearanceController(appearanceStore)..setUiScale(1);

    await tester.pumpWidget(
      PkuManagerApp(
        controller: controller,
        appearance: appearance,
        requireLanguageSelection: true,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('language-en')), findsOneWidget);
    expect(find.text('언어 선택'), findsOneWidget);
    expect(find.text('Choose language'), findsOneWidget);
    expect(find.text('选择语言'), findsOneWidget);
    expect(find.text('Timetable'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('language-en')));
    await tester.pumpAndSettle();

    expect(appearance.language, AppLanguage.en);
    expect(AppearanceController(appearanceStore).language, AppLanguage.en);
    expect(find.text('Timetable'), findsOneWidget);
  });
}
