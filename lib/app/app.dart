import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../data/app_database.dart';
import '../data/schedule_picker.dart';
import '../data/schedule_repository.dart';
import '../data/schedule_xls_parser.dart';
import '../data/week_config_parser.dart';
import '../data/week_config_repository.dart';
import '../domain/semester.dart';
import '../features/timetable/timetable_controller.dart';
import '../features/timetable/timetable_page.dart';

class PkuManagerApp extends StatefulWidget {
  const PkuManagerApp({super.key, this.controller});
  final TimetableController? controller;
  @override
  State<PkuManagerApp> createState() => _PkuManagerAppState();
}

class _PkuManagerAppState extends State<PkuManagerApp> {
  AppDatabase? _database;
  TimetableController? _controller;
  String? _failure;
  @override
  void initState() {
    super.initState();
    if (widget.controller != null) {
      _controller = widget.controller;
    } else {
      _open();
    }
  }

  Future<void> _open() async {
    try {
      final config = SemesterConfig.fromEnvironment();
      final directory = await getApplicationSupportDirectory();
      if (!mounted) return;
      await directory.create(recursive: true);
      if (!mounted) return;
      final database = AppDatabase('${directory.path}/pku_manager.sqlite3');
      _database = database;
      final controller = TimetableController(
        schedules: ScheduleRepository(database),
        decoder: ScheduleXlsParser(),
        picker: NativeSchedulePicker(),
        weeks: WeekConfigRepository(database, WeekConfigParser(config)),
      );
      setState(() => _controller = controller);
      controller.start();
    } catch (_) {
      if (mounted) {
        setState(
          () => _failure = 'Application data could not be opened. Existing data has not been removed.',
        );
      }
    }
  }

  @override
  void dispose() {
    if (widget.controller == null) _controller?.dispose();
    _database?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'PKU Manager',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff171717)),
      scaffoldBackgroundColor: const Color(0xfffafafa),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xfffafafa),
        elevation: 0,
      ),
    ),
    home: _controller != null
        ? TimetablePage(controller: _controller!)
        : Scaffold(
            body: Center(
              child: _failure == null
                  ? const CircularProgressIndicator()
                  : Text(_failure!),
            ),
          ),
  );
}
