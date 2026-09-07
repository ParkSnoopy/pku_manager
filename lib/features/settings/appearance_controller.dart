import 'package:flutter/material.dart';

final class AppearanceSettings {
  const AppearanceSettings({
    this.dark = false,
    this.accent = const Color(0xff171717),
    this.paletteSeed = 0,
  });

  final bool dark;
  final Color accent;
  final int paletteSeed;

  AppearanceSettings copyWith({bool? dark, Color? accent, int? paletteSeed}) =>
      AppearanceSettings(
        dark: dark ?? this.dark,
        accent: accent ?? this.accent,
        paletteSeed: paletteSeed ?? this.paletteSeed,
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

  bool get dark => _settings.dark;
  Color get accent => _settings.accent;
  int get paletteSeed => _settings.paletteSeed;

  void setDark(bool value) => _set(_settings.copyWith(dark: value));
  void setAccent(Color value) => _set(_settings.copyWith(accent: value));
  void rollPalette() => _set(
    _settings.copyWith(paletteSeed: (_settings.paletteSeed + 1) & 0x7fffffff),
  );

  void _set(AppearanceSettings value) {
    store.save(value);
    _settings = value;
    notifyListeners();
  }
}
