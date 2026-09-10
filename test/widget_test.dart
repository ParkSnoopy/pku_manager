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
        ..setLanguage(AppLanguage.en);
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
      expect(desktopWindowOptions.size, desktopLaunchSize);
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
        scrollable: find.byType(Scrollable).first,
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
}
