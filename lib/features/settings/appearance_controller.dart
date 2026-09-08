import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import '../../l10n/app_strings.dart';
import '../timetable/timetable_color.dart';

final class AppearanceSettings {
  const AppearanceSettings({
    this.accent = const Color(0xff171717),
    this.paletteSeed = 0,
    this.language = AppLanguage.defaultLanguage,
    this.showRollInNavbar = true,
  });

  final Color accent;
  final int paletteSeed;
  final AppLanguage language;
  final bool showRollInNavbar;

  AppearanceSettings copyWith({
    Color? accent,
    int? paletteSeed,
    AppLanguage? language,
    bool? showRollInNavbar,
  }) => AppearanceSettings(
    accent: accent ?? this.accent,
    paletteSeed: paletteSeed ?? this.paletteSeed,
    language: language ?? this.language,
    showRollInNavbar: showRollInNavbar ?? this.showRollInNavbar,
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
  AppLanguage get language => _settings.language;
  bool get showRollInNavbar => _settings.showRollInNavbar;
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
