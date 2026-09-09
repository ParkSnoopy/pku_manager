import 'package:flutter/material.dart';

import '../features/settings/appearance_controller.dart';
import '../features/timetable/timetable_color.dart';
import '../l10n/app_strings.dart';
import 'app_database.dart';

final class SqliteAppearanceStore implements AppearanceStore {
  SqliteAppearanceStore(this.database);

  final AppDatabase database;

  @override
  AppearanceSettings load() {
    final rows = database.database.select(
      '''SELECT accent, palette_seed, roll_palette, language, show_roll_nav,
font_family, font_scale, font_weight, timetable_font_scale,
timetable_index_color, auto_text_color, dark_mode, blend_accent_theme,
custom_palette_0, custom_palette_1, custom_palette_2, custom_palette_3,
custom_palette_4
FROM appearance WHERE id = 1''',
    );
    if (rows.isEmpty) return const AppearanceSettings();
    final row = rows.single;
    return AppearanceSettings(
      accent: Color(row['accent'] as int),
      paletteSeed: row['palette_seed'] as int,
      rollPalette: row['roll_palette'] as int,
      language: AppLanguage.parse(row['language'] as String),
      showRollInNavbar: (row['show_roll_nav'] as int) != 0,
      fontFamily: AppFontFamily.parse(row['font_family'] as String),
      fontScale: (row['font_scale'] as num).toDouble(),
      fontWeightValue: row['font_weight'] as int,
      timetableFontScale: (row['timetable_font_scale'] as num).toDouble(),
      timetableIndexColor: Color(row['timetable_index_color'] as int),
      autoTextColor: (row['auto_text_color'] as int) != 0,
      darkMode: (row['dark_mode'] as int) != 0,
      blendAccentIntoTheme: (row['blend_accent_theme'] as int) != 0,
      customPalette: List.unmodifiable([
        for (var index = 0; index < 5; index++)
          Color(row['custom_palette_$index'] as int),
      ]),
    );
  }

  @override
  Map<String, CourseAppearance> loadCourseAppearances() {
    final rows = database.database.select('''
SELECT identity, color, lock_color, outlined, outline_color, outline_width
FROM course_appearance
JOIN active_schedule ON course_appearance.source = active_schedule.source''');
    return Map.unmodifiable({
      for (final row in rows)
        row['identity'] as String: CourseAppearance(
          color: row['color'] == null ? null : Color(row['color'] as int),
          lockColor: (row['lock_color'] as int) != 0,
          outlined: (row['outlined'] as int) != 0,
          outlineColor: Color(row['outline_color'] as int),
          outlineWidth: (row['outline_width'] as num).toDouble(),
        ),
    });
  }

  @override
  void save(
    AppearanceSettings settings,
    Map<String, CourseAppearance> courseAppearances,
  ) {
    database.transaction(() {
      database.database.execute(
        '''INSERT INTO appearance (
id, accent, palette_seed, roll_palette, language, show_roll_nav, font_family,
font_scale, font_weight, timetable_font_scale, timetable_index_color,
auto_text_color, dark_mode, blend_accent_theme, custom_palette_0,
custom_palette_1, custom_palette_2, custom_palette_3, custom_palette_4)
VALUES (1, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
ON CONFLICT(id) DO UPDATE SET accent=excluded.accent,
palette_seed=excluded.palette_seed, roll_palette=excluded.roll_palette,
language=excluded.language, show_roll_nav=excluded.show_roll_nav,
font_family=excluded.font_family, font_scale=excluded.font_scale,
font_weight=excluded.font_weight,
timetable_font_scale=excluded.timetable_font_scale,
timetable_index_color=excluded.timetable_index_color,
auto_text_color=excluded.auto_text_color, dark_mode=excluded.dark_mode,
blend_accent_theme=excluded.blend_accent_theme,
custom_palette_0=excluded.custom_palette_0,
custom_palette_1=excluded.custom_palette_1,
custom_palette_2=excluded.custom_palette_2,
custom_palette_3=excluded.custom_palette_3,
custom_palette_4=excluded.custom_palette_4''',
        [
          settings.accent.toARGB32(),
          settings.paletteSeed,
          settings.rollPalette,
          settings.language.code,
          settings.showRollInNavbar ? 1 : 0,
          settings.fontFamily.code,
          settings.fontScale,
          settings.fontWeightValue,
          settings.timetableFontScale,
          settings.timetableIndexColor.toARGB32(),
          settings.autoTextColor ? 1 : 0,
          settings.darkMode ? 1 : 0,
          settings.blendAccentIntoTheme ? 1 : 0,
          ...settings.customPalette.map((color) => color.toARGB32()),
        ],
      );
      final active = database.database.select(
        'SELECT source FROM active_schedule WHERE id = 1',
      );
      if (active.isEmpty) return;
      final source = active.single['source'] as int;
      for (final sourceId in courseAppearances.keys) {
        final exists = database.database.select(
          '''SELECT identity FROM meetings WHERE source = ? AND identity = ?
UNION SELECT identity FROM user_meetings WHERE source = ? AND identity = ?''',
          [source, sourceId, source, sourceId],
        );
        if (exists.isEmpty) {
          throw ArgumentError(
            'Course appearance does not belong to active schedule',
          );
        }
      }
      database.database.execute(
        'DELETE FROM course_appearance WHERE source = ?',
        [source],
      );
      for (final entry in courseAppearances.entries) {
        final appearance = entry.value;
        database.database.execute(
          'INSERT INTO course_appearance VALUES (?, ?, ?, ?, ?, ?, ?)',
          [
            source,
            entry.key,
            appearance.color?.toARGB32(),
            appearance.lockColor ? 1 : 0,
            appearance.outlined ? 1 : 0,
            appearance.outlineColor.toARGB32(),
            appearance.outlineWidth,
          ],
        );
      }
    });
  }
}
