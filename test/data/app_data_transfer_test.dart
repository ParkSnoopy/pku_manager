import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pku_manager/data/app_data_transfer.dart';
import 'package:pku_manager/data/app_database.dart';
import 'package:pku_manager/data/calendar_schedule_repository.dart';
import 'package:pku_manager/data/sqlite_appearance_store.dart';
import 'package:pku_manager/features/settings/appearance_controller.dart';
import 'package:pku_manager/l10n/app_strings.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'app data round trip replaces source, settings, and schedules',
    () async {
      final directory = Directory.systemTemp.createTempSync(
        'pku-app-data-test-',
      );
      addTearDown(() => directory.deleteSync(recursive: true));
      final source = AppDatabase('${directory.path}/source.sqlite3');
      final destination = AppDatabase('${directory.path}/destination.sqlite3');
      addTearDown(source.close);
      addTearDown(destination.close);
      _seed(
        source,
        marker: 7,
        title: 'Transferred',
        language: AppLanguage.zhHans,
      );
      _seed(destination, marker: 2, title: 'Old', language: AppLanguage.en);
      final files = _MemoryAppDataFileAccess();
      Future<Directory> temporaryDirectory() async => directory;

      expect(
        await AppDataTransfer(
          source,
          files,
          temporaryDirectory: temporaryDirectory,
        ).exportData(),
        isTrue,
      );
      expect(
        String.fromCharCodes(files.saved!.sublist(0, 15)),
        'SQLite format 3',
      );

      files.selected = await File(
        '${directory.path}/selected.$appDataFileExtension',
      ).writeAsBytes(files.saved!, flush: true);
      expect(
        await AppDataTransfer(
          destination,
          files,
          temporaryDirectory: temporaryDirectory,
        ).importData(),
        isTrue,
      );

      expect(destination.database.userVersion, appDatabaseSchemaVersion);
      expect(destination.activeSource, Uint8List.fromList([7]));
      expect(
        CalendarScheduleRepository(destination).load().single.title,
        'Transferred',
      );
      expect(
        SqliteAppearanceStore(destination).load().language,
        AppLanguage.zhHans,
      );
      expect(
        directory.listSync().where(
          (entry) => entry.path
              .split(Platform.pathSeparator)
              .last
              .startsWith('pku-manager-'),
        ),
        isEmpty,
      );
    },
  );

  test('invalid app data leaves the current database unchanged', () async {
    final directory = Directory.systemTemp.createTempSync('pku-app-data-test-');
    addTearDown(() => directory.deleteSync(recursive: true));
    final destination = AppDatabase('${directory.path}/destination.sqlite3');
    addTearDown(destination.close);
    _seed(destination, marker: 4, title: 'Keep', language: AppLanguage.ko);
    final invalid = await File(
      '${directory.path}/invalid.$appDataFileExtension',
    ).writeAsBytes([1, 2, 3], flush: true);
    final files = _MemoryAppDataFileAccess()..selected = invalid;

    await expectLater(
      AppDataTransfer(
        destination,
        files,
        temporaryDirectory: () async => directory,
      ).importData(),
      throwsA(anything),
    );

    expect(destination.activeSource, Uint8List.fromList([4]));
    expect(CalendarScheduleRepository(destination).load().single.title, 'Keep');
  });

  test('purge removes every persisted row while preserving the schema', () {
    final database = AppDatabase(':memory:');
    addTearDown(database.close);
    _seed(database, marker: 6, title: 'Delete', language: AppLanguage.en);

    database.purgeData();

    database.validate();
    expect(database.activeSource, isNull);
    for (final table in [
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
    ]) {
      expect(
        database.database
            .select('SELECT COUNT(*) AS count FROM $table')
            .single['count'],
        0,
        reason: table,
      );
    }
  });

  test('application decode failure restores the previous database', () async {
    final directory = Directory.systemTemp.createTempSync('pku-app-data-test-');
    addTearDown(() => directory.deleteSync(recursive: true));
    final candidatePath = '${directory.path}/candidate.sqlite3';
    var candidate = AppDatabase(candidatePath);
    _seed(candidate, marker: 8, title: 'Invalid', language: AppLanguage.en);
    candidate.database.execute("UPDATE appearance SET accent = 'invalid'");
    candidate.close();
    final destination = AppDatabase('${directory.path}/destination.sqlite3');
    addTearDown(destination.close);
    _seed(destination, marker: 5, title: 'Keep', language: AppLanguage.ko);
    final files = _MemoryAppDataFileAccess()..selected = File(candidatePath);

    await expectLater(
      AppDataTransfer(
        destination,
        files,
        temporaryDirectory: () async => directory,
      ).importData(
        validateReplacement: () => SqliteAppearanceStore(destination).load(),
      ),
      throwsA(anything),
    );

    expect(destination.activeSource, Uint8List.fromList([5]));
    expect(CalendarScheduleRepository(destination).load().single.title, 'Keep');
    expect(SqliteAppearanceStore(destination).load().language, AppLanguage.ko);
  });

  test('legacy schema-zero app data migrates during import', () async {
    final directory = Directory.systemTemp.createTempSync('pku-app-data-test-');
    addTearDown(() => directory.deleteSync(recursive: true));
    final legacyPath = '${directory.path}/legacy.sqlite3';
    var legacy = AppDatabase(legacyPath);
    _seed(legacy, marker: 9, title: 'Legacy', language: AppLanguage.en);
    legacy.database.userVersion = 0;
    legacy.close();
    final destination = AppDatabase('${directory.path}/destination.sqlite3');
    addTearDown(destination.close);
    final files = _MemoryAppDataFileAccess()..selected = File(legacyPath);

    expect(
      await AppDataTransfer(
        destination,
        files,
        temporaryDirectory: () async => directory,
      ).importData(),
      isTrue,
    );

    expect(destination.database.userVersion, appDatabaseSchemaVersion);
    expect(destination.activeSource, Uint8List.fromList([9]));
  });

  test(
    'Android app data selection uses the unrestricted native bridge',
    () async {
      final directory = Directory.systemTemp.createTempSync(
        'pku-app-data-test-',
      );
      addTearDown(() => directory.deleteSync(recursive: true));
      final selected = await File(
        '${directory.path}/selected.$appDataFileExtension',
      ).writeAsBytes([8, 9], flush: true);
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      addTearDown(() {
        debugDefaultTargetPlatformOverride = null;
        messenger.setMockMethodCallHandler(
          const MethodChannel(appDataMethodChannel),
          null,
        );
      });
      MethodCall? received;
      messenger.setMockMethodCallHandler(
        const MethodChannel(appDataMethodChannel),
        (call) async {
          received = call;
          return selected.path;
        },
      );

      final input = await const NativeAppDataFileAccess().pick();
      expect(await input!.file.readAsBytes(), [8, 9]);
      expect(input.deleteAfterUse, isTrue);
      expect(received?.method, 'pickAppData');
      expect(received?.arguments, isNull);
    },
  );
}

void _seed(
  AppDatabase database, {
  required int marker,
  required String title,
  required AppLanguage language,
}) {
  database.database.execute(
    'INSERT INTO sources(bytes, period_count) VALUES (?, 1)',
    [
      Uint8List.fromList([marker]),
    ],
  );
  final source = database.database.lastInsertRowId;
  database.database.execute(
    'INSERT INTO active_schedule(id, source) VALUES (1, ?)',
    [source],
  );
  CalendarScheduleRepository(database)
      .create(title: title, startsAt: DateTime.utc(2026, 9, marker));
  SqliteAppearanceStore(database)
      .save(AppearanceSettings(language: language), const {});
}

final class _MemoryAppDataFileAccess implements AppDataFileAccess {
  File? selected;
  Uint8List? saved;

  @override
  Future<AppDataInput?> pick() async {
    final file = selected;
    return file == null ? null : AppDataInput(file);
  }

  @override
  Future<bool> save(File file) async {
    saved = await file.readAsBytes();
    return true;
  }
}
