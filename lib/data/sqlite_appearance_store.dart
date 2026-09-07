import 'package:flutter/material.dart';

import '../features/settings/appearance_controller.dart';
import 'app_database.dart';

final class SqliteAppearanceStore implements AppearanceStore {
  SqliteAppearanceStore(this.database);

  final AppDatabase database;

  @override
  AppearanceSettings load() {
    final rows = database.database.select(
      'SELECT dark, accent, palette_seed FROM appearance WHERE id = 1',
    );
    if (rows.isEmpty) return const AppearanceSettings();
    final row = rows.single;
    return AppearanceSettings(
      dark: row['dark'] == 1,
      accent: Color(row['accent'] as int),
      paletteSeed: row['palette_seed'] as int,
    );
  }

  @override
  void save(AppearanceSettings settings) {
    database.transaction(
      () => database.database.execute(
        '''INSERT INTO appearance VALUES (1, ?, ?, ?)
ON CONFLICT(id) DO UPDATE SET dark=excluded.dark,
accent=excluded.accent, palette_seed=excluded.palette_seed''',
        [
          settings.dark ? 1 : 0,
          settings.accent.toARGB32(),
          settings.paletteSeed,
        ],
      ),
    );
  }
}
