import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pku_manager/app/app.dart';
import 'package:pku_manager/data/app_database.dart';
import 'package:pku_manager/data/schedule_repository.dart';
import 'package:pku_manager/data/schedule_xls_parser.dart';
import 'package:pku_manager/data/week_config_parser.dart';
import 'package:pku_manager/data/week_config_repository.dart';
import 'package:pku_manager/domain/schedule_import.dart';
import 'package:pku_manager/domain/semester.dart';
import 'package:pku_manager/features/timetable/timetable_controller.dart';
import 'package:pku_manager/features/timetable/timetable_grid.dart';

class Picker implements SchedulePicker {
  @override
  Future<Uint8List?> pick() async => null;
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
      await tester.pumpWidget(PkuManagerApp(controller: controller));
      expect(find.textContaining('Import your exported'), findsOneWidget);
      await tester.tap(find.text('Import'));
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
      expect(tester.getTopLeft(find.text('1')), indexPosition);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
    },
  );
}
