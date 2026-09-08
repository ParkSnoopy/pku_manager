import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../data/app_database.dart';
import '../data/calendar_schedule_repository.dart';
import '../data/schedule_picker.dart';
import '../data/schedule_repository.dart';
import '../data/schedule_xls_parser.dart';
import '../data/sqlite_appearance_store.dart';
import '../data/week_config_parser.dart';
import '../data/week_config_repository.dart';
import '../domain/semester.dart';
import '../features/calendar/calendar_schedule_controller.dart';
import '../features/timetable/timetable_controller.dart';
import '../features/timetable/timetable_export.dart';
import '../features/timetable/timetable_page.dart';
import '../features/settings/appearance_controller.dart';
import '../l10n/app_strings.dart';
import '../ui/super_otc_font.dart';

class PkuManagerApp extends StatefulWidget {
  const PkuManagerApp({
    super.key,
    this.controller,
    this.appearance,
    this.exporter,
    this.browserLauncher,
    this.calendar,
  });
  final TimetableController? controller;
  final AppearanceController? appearance;
  final TimetableExporter? exporter;
  final BrowserLauncher? browserLauncher;
  final CalendarScheduleController? calendar;
  @override
  State<PkuManagerApp> createState() => _PkuManagerAppState();
}

class _PkuManagerAppState extends State<PkuManagerApp> {
  AppDatabase? _database;
  TimetableController? _controller;
  CalendarScheduleController? _calendar;
  late AppearanceController _appearance;
  late final TimetableExporter _exporter;
  String? _failure;
  @override
  void initState() {
    super.initState();
    _appearance =
        widget.appearance ?? AppearanceController(MemoryAppearanceStore());
    _exporter = widget.exporter ?? TimetableExporter(NativeExportFileWriter());
    if (widget.controller != null) {
      _controller = widget.controller;
      _calendar =
          widget.calendar ??
          CalendarScheduleController(MemoryCalendarScheduleStore());
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
      _calendar = CalendarScheduleController(
        CalendarScheduleRepository(database),
      );
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
        setState(() => _failure = 'Application data could not be opened.');
      }
    }
  }

  @override
  void dispose() {
    if (widget.controller == null) _controller?.dispose();
    if (widget.calendar == null) _calendar?.dispose();
    _database?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _appearance,
    builder: (context, _) => MaterialApp(
      title: 'PKU Manager',
      debugShowCheckedModeBanner: false,
      locale: _appearance.language.locale,
      supportedLocales: AppStrings.supportedLocales,
      localizationsDelegates: AppStrings.localizationsDelegates,
      theme: _theme(),
      builder: (context, child) {
        final media = MediaQuery.of(context);
        final platformScale = media.textScaler.scale(14) / 14;
        return MediaQuery(
          data: media.copyWith(
            textScaler: TextScaler.linear(
              platformScale * _appearance.fontScale,
            ),
          ),
          child: child!,
        );
      },
      home: _controller != null && _calendar != null
          ? TimetablePage(
              controller: _controller!,
              calendar: _calendar!,
              appearance: _appearance,
              exporter: _exporter,
              browserLauncher: widget.browserLauncher ?? launchInDefaultBrowser,
            )
          : Scaffold(
              body: Center(
                child: _failure == null
                    ? const CircularProgressIndicator()
                    : Text(_failure!),
              ),
            ),
    ),
  );

  ThemeData _theme() {
    final scheme = ColorScheme.fromSeed(
      seedColor: _appearance.accent,
      brightness: Brightness.light,
    );
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: _appearance.language == AppLanguage.ko
          ? pkuNotoSansKrFamily
          : pkuNotoSansScFamily,
      scaffoldBackgroundColor: scheme.surface,
      appBarTheme: AppBarTheme(backgroundColor: scheme.surface, elevation: 0),
    );
    return base.copyWith(
      textTheme: _weightedTextTheme(base.textTheme, _appearance.fontWeight),
      primaryTextTheme: _weightedTextTheme(
        base.primaryTextTheme,
        _appearance.fontWeight,
      ),
    );
  }
}

TextTheme _weightedTextTheme(TextTheme theme, FontWeight weight) =>
    theme.copyWith(
      displayLarge: theme.displayLarge?.copyWith(fontWeight: weight),
      displayMedium: theme.displayMedium?.copyWith(fontWeight: weight),
      displaySmall: theme.displaySmall?.copyWith(fontWeight: weight),
      headlineLarge: theme.headlineLarge?.copyWith(fontWeight: weight),
      headlineMedium: theme.headlineMedium?.copyWith(fontWeight: weight),
      headlineSmall: theme.headlineSmall?.copyWith(fontWeight: weight),
      titleLarge: theme.titleLarge?.copyWith(fontWeight: weight),
      titleMedium: theme.titleMedium?.copyWith(fontWeight: weight),
      titleSmall: theme.titleSmall?.copyWith(fontWeight: weight),
      bodyLarge: theme.bodyLarge?.copyWith(fontWeight: weight),
      bodyMedium: theme.bodyMedium?.copyWith(fontWeight: weight),
      bodySmall: theme.bodySmall?.copyWith(fontWeight: weight),
      labelLarge: theme.labelLarge?.copyWith(fontWeight: weight),
      labelMedium: theme.labelMedium?.copyWith(fontWeight: weight),
      labelSmall: theme.labelSmall?.copyWith(fontWeight: weight),
    );
