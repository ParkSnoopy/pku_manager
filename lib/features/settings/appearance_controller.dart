import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import '../../l10n/app_strings.dart';
import '../../domain/application_close_action.dart';
import '../timetable/timetable_color.dart';

enum AppFontFamily {
  serif('serif'),
  sans('sans');

  const AppFontFamily(this.code);
  final String code;

  static AppFontFamily parse(String value) =>
      values.firstWhere((family) => family.code == value, orElse: () => serif);
}

final class AppearanceSettings {
  const AppearanceSettings({
    this.accent = const Color(0xffff5722),
    this.paletteSeed = 0,
    this.rollPalette = 0,
    this.language = AppLanguage.defaultLanguage,
    this.showRollInNavbar = true,
    this.applicationCloseAction = ApplicationCloseAction.closeApp,
    this.fontFamily = AppFontFamily.serif,
    this.fontScale = 1,
    this.fontWeightValue = 400,
    this.timetableFontScale = 1,
    this.timetableIndexColor = const Color(0xffe8e0d2),
    this.autoTextColor = false,
    this.darkMode = false,
    this.blendAccentIntoTheme = false,
    this.customPalette = defaultCustomPalette,
  });

  final Color accent;
  final int paletteSeed;
  final int rollPalette;
  final AppLanguage language;
  final bool showRollInNavbar;
  final ApplicationCloseAction applicationCloseAction;
  final AppFontFamily fontFamily;
  final double fontScale;
  final int fontWeightValue;
  final double timetableFontScale;
  final Color timetableIndexColor;
  final bool autoTextColor;
  final bool darkMode;
  final bool blendAccentIntoTheme;
  final List<Color> customPalette;

  AppearanceSettings copyWith({
    Color? accent,
    int? paletteSeed,
    int? rollPalette,
    AppLanguage? language,
    bool? showRollInNavbar,
    ApplicationCloseAction? applicationCloseAction,
    AppFontFamily? fontFamily,
    double? fontScale,
    int? fontWeightValue,
    double? timetableFontScale,
    Color? timetableIndexColor,
    bool? autoTextColor,
    bool? darkMode,
    bool? blendAccentIntoTheme,
    List<Color>? customPalette,
  }) => AppearanceSettings(
    accent: accent ?? this.accent,
    paletteSeed: paletteSeed ?? this.paletteSeed,
    rollPalette: rollPalette ?? this.rollPalette,
    language: language ?? this.language,
    showRollInNavbar: showRollInNavbar ?? this.showRollInNavbar,
    applicationCloseAction:
        applicationCloseAction ?? this.applicationCloseAction,
    fontFamily: fontFamily ?? this.fontFamily,
    fontScale: fontScale ?? this.fontScale,
    fontWeightValue: fontWeightValue ?? this.fontWeightValue,
    timetableFontScale: timetableFontScale ?? this.timetableFontScale,
    timetableIndexColor: timetableIndexColor ?? this.timetableIndexColor,
    autoTextColor: autoTextColor ?? this.autoTextColor,
    darkMode: darkMode ?? this.darkMode,
    blendAccentIntoTheme: blendAccentIntoTheme ?? this.blendAccentIntoTheme,
    customPalette: customPalette ?? this.customPalette,
  );
}

abstract interface class AppearanceStore {
  AppearanceSettings load();
  Map<String, CourseAppearance> loadCourseAppearances();
  void save(
    AppearanceSettings settings,
    Map<String, CourseAppearance> courseAppearances,
  );
}

final class MemoryAppearanceStore implements AppearanceStore {
  AppearanceSettings _settings = const AppearanceSettings();
  Map<String, CourseAppearance> _courseAppearances = const {};
  @override
  AppearanceSettings load() => _settings;
  @override
  Map<String, CourseAppearance> loadCourseAppearances() =>
      Map.unmodifiable(_courseAppearances);
  @override
  void save(
    AppearanceSettings settings,
    Map<String, CourseAppearance> courseAppearances,
  ) {
    _settings = settings;
    _courseAppearances = Map.unmodifiable(courseAppearances);
  }
}

final class AppearanceController extends ChangeNotifier {
  AppearanceController(this.store)
    : _settings = store.load(),
      _courseAppearances = store.loadCourseAppearances();

  final AppearanceStore store;
  AppearanceSettings _settings;
  Map<String, CourseAppearance> _courseAppearances;

  Color get accent => _settings.accent;
  int get paletteSeed => _settings.paletteSeed;
  int get rollPaletteIndex => _settings.rollPalette;
  AppLanguage get language => _settings.language;
  bool get showRollInNavbar => _settings.showRollInNavbar;
  ApplicationCloseAction get applicationCloseAction =>
      _settings.applicationCloseAction;
  AppFontFamily get fontFamily => _settings.fontFamily;
  double get fontScale => _settings.fontScale;
  int get fontWeightValue => _settings.fontWeightValue;
  FontWeight get fontWeight => FontWeight.values[fontWeightValue ~/ 100 - 1];
  double get timetableFontScale => _settings.timetableFontScale;
  Color get timetableIndexColor => _settings.timetableIndexColor;
  bool get autoTextColor => _settings.autoTextColor;
  bool get darkMode => _settings.darkMode;
  bool get blendAccentIntoTheme => _settings.blendAccentIntoTheme;
  List<Color> get customPalette => List.unmodifiable(_settings.customPalette);
  List<Color> get paletteColors => rollPaletteIndex == 0
      ? customPalette
      : rollPalettes[rollPaletteIndex].colors;
  Map<String, CourseAppearance> get courseAppearances =>
      Map.unmodifiable(_courseAppearances);

  CourseAppearance? courseAppearanceFor(String sourceId) =>
      _courseAppearances[sourceId];

  void setAccent(Color value) => _set(_settings.copyWith(accent: value));
  void setLanguage(AppLanguage value) =>
      _set(_settings.copyWith(language: value));
  void cycleLanguage() => setLanguage(switch (language) {
    AppLanguage.ko => AppLanguage.en,
    AppLanguage.en => AppLanguage.zhHans,
    AppLanguage.zhHans => AppLanguage.ko,
  });
  void setShowRollInNavbar(bool value) =>
      _set(_settings.copyWith(showRollInNavbar: value));
  void setApplicationCloseAction(ApplicationCloseAction value) =>
      _set(_settings.copyWith(applicationCloseAction: value));
  void cycleFontFamily() => _set(
    _settings.copyWith(
      fontFamily: fontFamily == AppFontFamily.serif
          ? AppFontFamily.sans
          : AppFontFamily.serif,
    ),
  );
  void setFontScale(double value) {
    if (value < .8 || value > 1.5) throw RangeError.value(value);
    _set(_settings.copyWith(fontScale: value));
  }

  void setTimetableFontScale(double value) {
    if (value < 1 || value > 2) throw RangeError.range(value, 1, 2);
    _set(_settings.copyWith(timetableFontScale: value));
  }

  void setFontWeight(int value) {
    if (value < 100 || value > 900 || value % 100 != 0) {
      throw RangeError.range(value, 100, 900);
    }
    _set(_settings.copyWith(fontWeightValue: value));
  }

  void setTimetableIndexColor(Color value) =>
      _set(_settings.copyWith(timetableIndexColor: value));

  void setAutoTextColor(bool value) =>
      _set(_settings.copyWith(autoTextColor: value));

  void setDarkMode(bool value) => _set(_settings.copyWith(darkMode: value));

  void setBlendAccentIntoTheme(bool value) =>
      _set(_settings.copyWith(blendAccentIntoTheme: value));

  void setRollPalette(int value) {
    RangeError.checkValueInInterval(value, 0, rollPalettes.length - 1);
    _set(_settings.copyWith(rollPalette: value));
  }

  void setCustomPaletteColor(int index, Color color) {
    RangeError.checkValidIndex(index, _settings.customPalette);
    final colors = List<Color>.of(_settings.customPalette)..[index] = color;
    _set(_settings.copyWith(customPalette: List.unmodifiable(colors)));
  }

  void setCourseAppearance(
    Iterable<String> sourceIds,
    CourseAppearance appearance,
  ) {
    final updated = Map<String, CourseAppearance>.of(_courseAppearances);
    for (final sourceId in sourceIds) {
      if (appearance.isEmpty) {
        updated.remove(sourceId);
      } else {
        updated[sourceId] = appearance;
      }
    }
    _set(_settings, courseAppearances: updated);
  }

  void reloadCourseAppearances() {
    final loaded = store.loadCourseAppearances();
    if (mapEquals(loaded, _courseAppearances)) return;
    _courseAppearances = loaded;
    notifyListeners();
  }

  void reload() {
    _settings = store.load();
    _courseAppearances = Map.unmodifiable(store.loadCourseAppearances());
    notifyListeners();
  }

  void rollPalette() {
    final updated = <String, CourseAppearance>{};
    for (final entry in _courseAppearances.entries) {
      final appearance = entry.value;
      final next = appearance.color != null && !appearance.lockColor
          ? appearance.withoutUnlockedColor()
          : appearance;
      if (!next.isEmpty) updated[entry.key] = next;
    }
    _set(
      _settings.copyWith(paletteSeed: (_settings.paletteSeed + 1) & 0x7fffffff),
      courseAppearances: updated,
    );
  }

  void _set(
    AppearanceSettings value, {
    Map<String, CourseAppearance>? courseAppearances,
  }) {
    final styles = courseAppearances ?? _courseAppearances;
    store.save(value, styles);
    _settings = value;
    _courseAppearances = Map.unmodifiable(styles);
    notifyListeners();
  }
}
