import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../data/app_database.dart';
import '../data/schedule_picker.dart';
import '../data/schedule_repository.dart';
import '../data/schedule_xls_parser.dart';
import '../data/sqlite_appearance_store.dart';
import '../data/week_config_parser.dart';
import '../data/week_config_repository.dart';
import '../domain/semester.dart';
import '../features/timetable/timetable_controller.dart';
import '../features/timetable/timetable_page.dart';
import '../features/settings/appearance_controller.dart';

class PkuManagerApp extends StatefulWidget {
  const PkuManagerApp({super.key, this.controller, this.appearance});
  final TimetableController? controller;
  final AppearanceController? appearance;
  @override
  State<PkuManagerApp> createState() => _PkuManagerAppState();
}

class _PkuManagerAppState extends State<PkuManagerApp> {
  AppDatabase? _database;
  TimetableController? _controller;
  late AppearanceController _appearance;
  String? _failure;
  @override
  void initState() {
    super.initState();
    _appearance =
        widget.appearance ?? AppearanceController(MemoryAppearanceStore());
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
      _appearance = AppearanceController(SqliteAppearanceStore(database));
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
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _appearance,
    builder: (context, _) => MaterialApp(
      title: 'PKU Manager',
      debugShowCheckedModeBanner: false,
      themeMode: _appearance.dark ? ThemeMode.dark : ThemeMode.light,
      theme: _theme(Brightness.light),
      darkTheme: _theme(Brightness.dark),
      home: _controller != null
          ? TimetablePage(controller: _controller!, appearance: _appearance)
          : Scaffold(
              body: Center(
                child: _failure == null
                    ? const CircularProgressIndicator()
                    : Text(_failure!),
              ),
            ),
    ),
  );

  ThemeData _theme(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: _appearance.accent,
      brightness: brightness,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      appBarTheme: AppBarTheme(backgroundColor: scheme.surface, elevation: 0),
    );
  }
}
