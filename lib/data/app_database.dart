import 'dart:typed_data';

import 'package:sqlite3/sqlite3.dart';

/// Owns one connection. All publication changes share its transaction boundary.
class AppDatabase {
  AppDatabase(String path) : database = sqlite3.open(path) {
    database.execute('PRAGMA foreign_keys = ON');
    database.execute('PRAGMA busy_timeout = 5000');
    database.execute('PRAGMA synchronous = FULL');
    final version =
        database.select('PRAGMA user_version').first.values.first as int;
    if (version != 0) {
      database.close();
      throw const FormatException('Unsupported database version');
    }
    final initialized = database.select('''
SELECT 1 FROM sqlite_master
WHERE type = 'table' AND name NOT LIKE 'sqlite_%'
LIMIT 1''').isNotEmpty;
    if (!initialized) {
      transaction(() {
        database.execute('''
CREATE TABLE sources(id INTEGER PRIMARY KEY, bytes BLOB NOT NULL, period_count INTEGER NOT NULL CHECK(period_count > 0));
CREATE TRIGGER immutable_source BEFORE UPDATE OF bytes ON sources
BEGIN SELECT RAISE(ABORT, 'Source bytes are immutable'); END;
CREATE TABLE meetings(
 source INTEGER NOT NULL REFERENCES sources(id),
 identity TEXT NOT NULL, name TEXT NOT NULL, weekday INTEGER NOT NULL,
 first_period INTEGER NOT NULL, last_period INTEGER NOT NULL,
 room TEXT NOT NULL, frequency TEXT NOT NULL, note TEXT NOT NULL,
 exam TEXT NOT NULL, raw TEXT NOT NULL,
 PRIMARY KEY(source, identity),
 CHECK(weekday BETWEEN 1 AND 7),
 CHECK(first_period > 0 AND last_period >= first_period));
CREATE TABLE completions(
 source INTEGER NOT NULL, identity TEXT NOT NULL, name TEXT NOT NULL,
 room TEXT NOT NULL, frequency TEXT NOT NULL,
 weekday INTEGER NOT NULL CHECK(weekday BETWEEN 1 AND 5),
 first_period INTEGER NOT NULL CHECK(first_period > 0),
 last_period INTEGER NOT NULL CHECK(last_period >= first_period),
 note TEXT NOT NULL, exam TEXT NOT NULL,
 PRIMARY KEY(source, identity),
 FOREIGN KEY(source, identity) REFERENCES meetings(source, identity));
CREATE TABLE issues(source INTEGER NOT NULL, identity TEXT NOT NULL, message TEXT NOT NULL,
 PRIMARY KEY(source, identity), FOREIGN KEY(source, identity) REFERENCES meetings(source, identity));
CREATE TABLE active_schedule(id INTEGER PRIMARY KEY CHECK(id = 1),
 source INTEGER NOT NULL REFERENCES sources(id));
CREATE TABLE week_cache(id INTEGER PRIMARY KEY CHECK(id = 1),
 content TEXT NOT NULL, fetched_at TEXT NOT NULL);
CREATE TABLE appearance(
 id INTEGER PRIMARY KEY CHECK(id = 1),
 accent INTEGER NOT NULL,
 palette_seed INTEGER NOT NULL CHECK(palette_seed >= 0),
 language TEXT NOT NULL CHECK(language IN ('ko', 'en', 'zh')),
 show_roll_nav INTEGER NOT NULL CHECK(show_roll_nav IN (0, 1)));
CREATE TABLE user_meetings(
 source INTEGER NOT NULL REFERENCES sources(id),
 identity TEXT NOT NULL, name TEXT NOT NULL,
 weekday INTEGER NOT NULL CHECK(weekday BETWEEN 1 AND 5),
 first_period INTEGER NOT NULL CHECK(first_period > 0),
 last_period INTEGER NOT NULL CHECK(last_period >= first_period),
 room TEXT NOT NULL, frequency TEXT NOT NULL,
 note TEXT NOT NULL, exam TEXT NOT NULL,
 PRIMARY KEY(source, identity));
CREATE TABLE course_appearance(
 source INTEGER NOT NULL REFERENCES sources(id),
 identity TEXT NOT NULL,
 color INTEGER,
 lock_color INTEGER NOT NULL CHECK(lock_color IN (0, 1)),
 outlined INTEGER NOT NULL CHECK(outlined IN (0, 1)),
 outline_color INTEGER NOT NULL,
 outline_width REAL NOT NULL CHECK(outline_width BETWEEN 0.5 AND 6),
 PRIMARY KEY(source, identity));
CREATE TABLE calendar_schedules(
 id INTEGER PRIMARY KEY AUTOINCREMENT,
 title TEXT NOT NULL CHECK(length(trim(title)) > 0),
 starts_at INTEGER NOT NULL);
''');
      });
    }
    final requiredTables = {
      'sources',
      'meetings',
      'completions',
      'issues',
      'active_schedule',
      'week_cache',
      'appearance',
      'user_meetings',
      'course_appearance',
      'calendar_schedules',
    };
    final tables = database
        .select("SELECT name FROM sqlite_master WHERE type = 'table'")
        .map((row) => row['name'] as String)
        .toSet();
    if (!tables.containsAll(requiredTables)) {
      database.close();
      throw const FormatException('Unsupported database schema');
    }
    final integrity = database.select('PRAGMA quick_check').first.values.first;
    if (integrity != 'ok' ||
        database.select('PRAGMA foreign_key_check').isNotEmpty) {
      database.close();
      throw const FormatException('Database integrity check failed');
    }
  }

  final Database database;

  T transaction<T>(T Function() operation) {
    database.execute('BEGIN IMMEDIATE');
    try {
      final result = operation();
      database.execute('COMMIT');
      return result;
    } catch (_) {
      database.execute('ROLLBACK');
      rethrow;
    }
  }

  Uint8List? get activeSource {
    final rows = database.select(
      '''SELECT bytes FROM sources
JOIN active_schedule ON sources.id = active_schedule.source WHERE active_schedule.id = 1''',
    );
    return rows.isEmpty
        ? null
        : Uint8List.fromList(rows.first['bytes'] as List<int>);
  }

  void close() => database.close();
}
