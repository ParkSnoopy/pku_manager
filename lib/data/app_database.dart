import 'dart:typed_data';

import 'package:sqlite3/sqlite3.dart';

/// Owns one connection. All publication changes share its transaction boundary.
class AppDatabase {
  AppDatabase(String path) : database = sqlite3.open(path) {
    database.execute('PRAGMA foreign_keys = ON');
    database.execute('PRAGMA busy_timeout = 5000');
    database.execute('PRAGMA synchronous = FULL');
    final version = database.select('PRAGMA user_version').first.values.first;
    if (version != 0 && version != 1 && version != 2) {
      database.close();
      throw const FormatException('Unsupported database version');
    }
    if (version == 0) {
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
 PRIMARY KEY(source, identity),
 FOREIGN KEY(source, identity) REFERENCES meetings(source, identity));
CREATE TABLE issues(source INTEGER NOT NULL, identity TEXT NOT NULL, message TEXT NOT NULL,
 PRIMARY KEY(source, identity), FOREIGN KEY(source, identity) REFERENCES meetings(source, identity));
CREATE TABLE active_schedule(id INTEGER PRIMARY KEY CHECK(id = 1),
 source INTEGER NOT NULL REFERENCES sources(id));
CREATE TABLE week_cache(id INTEGER PRIMARY KEY CHECK(id = 1),
 content TEXT NOT NULL, fetched_at TEXT NOT NULL);
PRAGMA user_version = 1;
''');
      });
    }
    if (version == 0 || version == 1) {
      transaction(() {
        database.execute('''
ALTER TABLE completions ADD COLUMN weekday INTEGER CHECK(weekday BETWEEN 1 AND 7);
ALTER TABLE completions ADD COLUMN first_period INTEGER CHECK(first_period > 0);
ALTER TABLE completions ADD COLUMN last_period INTEGER CHECK(last_period >= first_period);
ALTER TABLE completions ADD COLUMN note TEXT;
ALTER TABLE completions ADD COLUMN exam TEXT;
PRAGMA user_version = 2;
''');
      });
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
