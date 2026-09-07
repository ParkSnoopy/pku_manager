import 'package:flutter/material.dart';

import '../features/settings/appearance_controller.dart';
import '../l10n/app_strings.dart';
import 'app_database.dart';

final class SqliteAppearanceStore implements AppearanceStore {
  SqliteAppearanceStore(this.database);

  final AppDatabase database;

  @override
  AppearanceSettings load() {
    final rows = database.database.select(
      'SELECT accent, palette_seed, language FROM appearance WHERE id = 1',
    );
    if (rows.isEmpty) return const AppearanceSettings();
    final row = rows.single;
    return AppearanceSettings(
      accent: Color(row['accent'] as int),
      paletteSeed: row['palette_seed'] as int,
      language: AppLanguage.parse(row['language'] as String),
    );
  }

  @override
  void save(AppearanceSettings settings) {
    database.transaction(
      () => database.database.execute(
        '''INSERT INTO appearance VALUES (1, ?, ?, ?)
ON CONFLICT(id) DO UPDATE SET accent=excluded.accent,
palette_seed=excluded.palette_seed, language=excluded.language''',
        [
          settings.accent.toARGB32(),
          settings.paletteSeed,
          settings.language.code,
        ],
      ),
    );
  }
}
