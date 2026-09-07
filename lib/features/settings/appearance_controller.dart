import 'package:flutter/material.dart';

import '../../l10n/app_strings.dart';

final class AppearanceSettings {
  const AppearanceSettings({
    this.accent = const Color(0xff171717),
    this.paletteSeed = 0,
    this.language = AppLanguage.defaultLanguage,
  });

  final Color accent;
  final int paletteSeed;
  final AppLanguage language;

  AppearanceSettings copyWith({
    Color? accent,
    int? paletteSeed,
    AppLanguage? language,
  }) => AppearanceSettings(
    accent: accent ?? this.accent,
    paletteSeed: paletteSeed ?? this.paletteSeed,
    language: language ?? this.language,
  );
}

abstract interface class AppearanceStore {
  AppearanceSettings load();
  void save(AppearanceSettings settings);
}

final class MemoryAppearanceStore implements AppearanceStore {
  AppearanceSettings _settings = const AppearanceSettings();
  @override
  AppearanceSettings load() => _settings;
  @override
  void save(AppearanceSettings settings) => _settings = settings;
}

final class AppearanceController extends ChangeNotifier {
  AppearanceController(this.store) : _settings = store.load();

  final AppearanceStore store;
  AppearanceSettings _settings;

  Color get accent => _settings.accent;
  int get paletteSeed => _settings.paletteSeed;
  AppLanguage get language => _settings.language;

  void setAccent(Color value) => _set(_settings.copyWith(accent: value));
  void setLanguage(AppLanguage value) =>
      _set(_settings.copyWith(language: value));
  void rollPalette() => _set(
    _settings.copyWith(paletteSeed: (_settings.paletteSeed + 1) & 0x7fffffff),
  );

  void _set(AppearanceSettings value) {
    store.save(value);
    _settings = value;
    notifyListeners();
  }
}
