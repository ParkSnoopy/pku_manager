import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import '../data/app_data_transfer.dart';
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
import '../ui/app_window_controller.dart';
import '../ui/super_otc_font.dart';

class PkuManagerApp extends StatefulWidget {
  const PkuManagerApp({
    super.key,
    this.controller,
    this.appearance,
    this.exporter,
    this.browserLauncher,
    this.calendar,
    this.windowController,
    this.requireLanguageSelection = false,
  });
  final TimetableController? controller;
  final AppearanceController? appearance;
  final TimetableExporter? exporter;
  final BrowserLauncher? browserLauncher;
  final CalendarScheduleController? calendar;
  final AppWindowController? windowController;
  final bool requireLanguageSelection;
  @override
  State<PkuManagerApp> createState() => _PkuManagerAppState();
}

class _PkuManagerAppState extends State<PkuManagerApp> {
  AppDatabase? _database;
  TimetableController? _controller;
  CalendarScheduleController? _calendar;
  AppDataTransfer? _dataTransfer;
  late AppearanceController _appearance;
  late final TimetableExporter _exporter;
  late final AppWindowController _windowController;
  String? _failure;
  late bool _requiresLanguageSelection;
  @override
  void initState() {
    super.initState();
    _requiresLanguageSelection = widget.requireLanguageSelection;
    _appearance =
        widget.appearance ?? AppearanceController(MemoryAppearanceStore());
    _exporter = widget.exporter ?? TimetableExporter(NativeExportFileWriter());
    _windowController =
        widget.windowController ?? UnsupportedWindowController();
    _appearance.addListener(_syncWindowCloseAction);
    _syncWindowCloseAction();
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
      final databasePath = '${directory.path}/pku_manager.sqlite3';
      final isFirstLaunch = !await File(databasePath).exists();
      final database = AppDatabase(databasePath);
      _database = database;
      _dataTransfer = AppDataTransfer(
        database,
        const NativeAppDataFileAccess(),
      );
      _appearance.removeListener(_syncWindowCloseAction);
      _appearance = AppearanceController(SqliteAppearanceStore(database));
      _appearance.addListener(_syncWindowCloseAction);
      _syncWindowCloseAction();
      _calendar = CalendarScheduleController(
        CalendarScheduleRepository(database),
      );
      final controller = TimetableController(
        schedules: ScheduleRepository(database),
        decoder: ScheduleXlsParser(),
        picker: NativeSchedulePicker(),
        weeks: WeekConfigRepository(database, WeekConfigParser(config)),
        finalExamTitle: () =>
            AppStrings(_appearance.language.locale).text(AppText.finalExam),
        onPublished: _calendar!.reload,
      );
      setState(() {
        _controller = controller;
        _requiresLanguageSelection = isFirstLaunch;
      });
      if (!isFirstLaunch) controller.start();
    } catch (_) {
      if (mounted) {
        setState(() => _failure = 'Application data could not be opened.');
      }
    }
  }

  @override
  void dispose() {
    _appearance.removeListener(_syncWindowCloseAction);
    if (widget.controller == null) _controller?.dispose();
    if (widget.calendar == null) _calendar?.dispose();
    if (widget.windowController == null) _windowController.dispose();
    _database?.close();
    super.dispose();
  }

  void _syncWindowCloseAction() {
    final strings = AppStrings(_appearance.language.locale);
    unawaited(_configureWindowCloseAction(strings));
  }

  Future<void> _configureWindowCloseAction(AppStrings strings) async {
    try {
      await _windowController.configureCloseAction(
        _appearance.applicationCloseAction,
        showLabel: strings.text(AppText.showApplication),
        exitLabel: strings.text(AppText.closeTheApp),
      );
    } catch (error, stackTrace) {
      debugPrint('$error\n$stackTrace');
    }
  }

  Future<bool> _exportAppData() async {
    final transfer = _dataTransfer;
    return transfer == null ? false : transfer.exportData();
  }

  Future<bool> _importAppData() async {
    final transfer = _dataTransfer;
    if (transfer == null ||
        !await transfer.importData(
          validateReplacement: _validateAndReloadAppData,
        )) {
      return false;
    }
    return true;
  }

  void _validateAndReloadAppData() {
    final database = _database;
    if (database == null) throw StateError('Application data is not open');
    SqliteAppearanceStore(database)
      ..load()
      ..loadCourseAppearances();
    CalendarScheduleRepository(database).load();
    ScheduleRepository(database).load();
    _appearance.reload();
    _calendar?.reload();
    _controller?.reload();
  }

  void _selectLanguage(AppLanguage language) {
    _appearance.setLanguage(language);
    setState(() => _requiresLanguageSelection = false);
    if (widget.controller == null) _controller?.start();
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
      theme: _theme(Brightness.light),
      darkTheme: _theme(Brightness.dark),
      themeMode: _appearance.darkMode ? ThemeMode.dark : ThemeMode.light,
      builder: (context, child) {
        final media = MediaQuery.of(context);
        final platformScale = media.textScaler.scale(14) / 14;
        return MediaQuery(
          data: media.copyWith(
            textScaler: TextScaler.linear(
              platformScale * _appearance.fontScale,
            ),
          ),
          child: CallbackShortcuts(
            bindings: _windowController.supported
                ? {
                    const SingleActivator(LogicalKeyboardKey.f11): () =>
                        unawaited(_windowController.toggleFullScreen()),
                  }
                : const {},
            child: Focus(autofocus: true, child: child!),
          ),
        );
      },
      home: _requiresLanguageSelection
          ? _LanguageSelectionPage(onSelected: _selectLanguage)
          : _controller != null && _calendar != null
          ? TimetablePage(
              controller: _controller!,
              calendar: _calendar!,
              appearance: _appearance,
              exporter: _exporter,
              browserLauncher: widget.browserLauncher ?? launchInDefaultBrowser,
              windowController: _windowController,
              exportAppData: _exportAppData,
              importAppData: _importAppData,
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

  ThemeData _theme(Brightness brightness) {
    final accent = _appearance.accent;
    final generatedAccentScheme = ColorScheme.fromSeed(
      seedColor: accent,
      brightness: brightness,
    );
    final accentScheme = generatedAccentScheme.copyWith(
      primary: accent,
      onPrimary: ThemeData.estimateBrightnessForColor(accent) == Brightness.dark
          ? Colors.white
          : Colors.black,
    );
    final neutralScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xff808080),
      brightness: brightness,
    );
    final scheme = _appearance.blendAccentIntoTheme
        ? accentScheme
        : neutralScheme.copyWith(
            primary: accentScheme.primary,
            onPrimary: accentScheme.onPrimary,
            primaryContainer: accentScheme.primaryContainer,
            onPrimaryContainer: accentScheme.onPrimaryContainer,
            inversePrimary: accentScheme.inversePrimary,
          );
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: switch ((_appearance.fontFamily, _appearance.language)) {
        (AppFontFamily.serif, AppLanguage.ko) => pkuNotoSerifKrFamily,
        (AppFontFamily.serif, _) => pkuNotoSerifScFamily,
        (AppFontFamily.sans, AppLanguage.ko) => pkuNotoSansKrFamily,
        (AppFontFamily.sans, _) => pkuNotoSansScFamily,
      },
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

final class _LanguageSelectionPage extends StatelessWidget {
  const _LanguageSelectionPage({required this.onSelected});

  final ValueChanged<AppLanguage> onSelected;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.language, size: 48),
              const SizedBox(height: 24),
              Column(
                children: [
                  for (final label in const [
                    '언어 선택',
                    'Choose language',
                    '选择语言',
                  ])
                    Text(label, style: Theme.of(context).textTheme.titleLarge),
                ],
              ),
              const SizedBox(height: 32),
              for (final language in AppLanguage.values) ...[
                OutlinedButton(
                  key: ValueKey('language-${language.code}'),
                  onPressed: () => onSelected(language),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(56),
                    foregroundColor: Theme.of(context).colorScheme.onSurface,
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  child: Text(switch (language) {
                    AppLanguage.ko => '한국어',
                    AppLanguage.en => 'English',
                    AppLanguage.zhHans => '简体中文',
                  }),
                ),
                if (language != AppLanguage.values.last)
                  const SizedBox(height: 12),
              ],
            ],
          ),
        ),
      ),
    ),
  );
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
