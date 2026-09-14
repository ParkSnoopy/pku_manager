import 'dart:async';
import 'dart:io';

import 'package:file_saver/file_saver.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

import 'app_database.dart';

const appDataFileExtension = 'pkudata';
const appDataMimeType = 'application/vnd.parksnoopy.pku-manager-data';
const maxAppDataBytes = 256 * 1024 * 1024;
const appDataMethodChannel = 'com.parksnoopy.pku_manager/app_data';

abstract interface class AppDataFileAccess {
  Future<bool> save(File file);
  Future<AppDataInput?> pick();
}

final class AppDataInput {
  const AppDataInput(this.file, {this.deleteAfterUse = false});

  final File file;
  final bool deleteAfterUse;
}

final class NativeAppDataFileAccess implements AppDataFileAccess {
  const NativeAppDataFileAccess();

  @override
  Future<bool> save(File file) async {
    final length = await file.length();
    if (length == 0 || length > maxAppDataBytes) {
      throw const FormatException('App data has an invalid size');
    }
    if (defaultTargetPlatform
        case TargetPlatform.linux ||
            TargetPlatform.macOS ||
            TargetPlatform.windows) {
      final location = await getSaveLocation(
        suggestedName: 'pku-manager-data.$appDataFileExtension',
        acceptedTypeGroups: const [
          XTypeGroup(
            label: 'PKU Manager data',
            extensions: [appDataFileExtension],
            mimeTypes: [appDataMimeType],
          ),
        ],
      );
      if (location == null) return false;
      await XFile(
        file.path,
        mimeType: appDataMimeType,
        name: 'pku-manager-data.$appDataFileExtension',
      ).saveTo(location.path);
      return true;
    }
    final path = await FileSaver.instance.saveAs(
      name: 'pku-manager-data',
      filePath: file.path,
      fileExtension: appDataFileExtension,
      mimeType: MimeType.custom,
      customMimeType: appDataMimeType,
    );
    return path != null;
  }

  @override
  Future<AppDataInput?> pick() async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      final path = await const MethodChannel(appDataMethodChannel)
          .invokeMethod<String>('pickAppData');
      if (path == null) return null;
      return AppDataInput(File(path), deleteAfterUse: true);
    }
    final file = await openFile(
      acceptedTypeGroups: defaultTargetPlatform == TargetPlatform.iOS
          ? const []
          : const [
              XTypeGroup(
                label: 'PKU Manager data',
                extensions: [appDataFileExtension],
                mimeTypes: [appDataMimeType],
              ),
            ],
    );
    if (file == null) return null;
    return AppDataInput(File(file.path));
  }
}

final class AppDataTransfer {
  AppDataTransfer(
    this.database,
    this.files, {
    Future<Directory> Function()? temporaryDirectory,
  }) : temporaryDirectory = temporaryDirectory ?? getTemporaryDirectory;

  final AppDatabase database;
  final AppDataFileAccess files;
  final Future<Directory> Function() temporaryDirectory;

  Future<bool> exportData() async {
    final directory = await temporaryDirectory();
    await directory.create(recursive: true);
    final snapshot = File(_temporaryPath(directory, 'export'));
    try {
      await _backup(database.database, snapshot.path);
      final length = await snapshot.length();
      if (length == 0 || length > maxAppDataBytes) {
        throw const FormatException('App data has an invalid size');
      }
      return await files.save(snapshot);
    } finally {
      if (await snapshot.exists()) await snapshot.delete();
    }
  }

  Future<bool> importData({
    FutureOr<void> Function()? validateReplacement,
  }) async {
    final input = await files.pick();
    if (input == null) return false;

    final directory = await temporaryDirectory();
    await directory.create(recursive: true);
    final candidate = File(_temporaryPath(directory, 'candidate'));
    final rollback = File(_temporaryPath(directory, 'rollback'));
    AppDatabase? imported;
    Database? rollbackDatabase;
    var replacementStarted = false;
    var retainRollback = false;
    try {
      await _copyBounded(input.file, candidate);
      imported = AppDatabase(candidate.path);
      rollbackDatabase = sqlite3.open(rollback.path);
      await database.database
          .backup(rollbackDatabase, nPage: 128)
          .drain<void>();
      replacementStarted = true;
      await imported.database
          .backup(database.database, nPage: 128)
          .drain<void>();
      database.validate();
      if (validateReplacement != null) await validateReplacement();
      return true;
    } catch (_) {
      if (replacementStarted && rollbackDatabase != null) {
        try {
          await rollbackDatabase
              .backup(database.database, nPage: 128)
              .drain<void>();
          database.validate();
          if (validateReplacement != null) await validateReplacement();
        } catch (_) {
          retainRollback = true;
          rethrow;
        }
      }
      rethrow;
    } finally {
      imported?.close();
      rollbackDatabase?.close();
      if (await candidate.exists()) await candidate.delete();
      if (!retainRollback && await rollback.exists()) await rollback.delete();
      if (input.deleteAfterUse && await input.file.exists()) {
        await input.file.delete();
      }
    }
  }
}

Future<void> _copyBounded(File source, File destination) async {
  if (await source.length() > maxAppDataBytes) {
    throw const FormatException('App data exceeds the size limit');
  }
  final sink = destination.openWrite();
  var length = 0;
  try {
    await for (final chunk in source.openRead()) {
      length += chunk.length;
      if (length > maxAppDataBytes) {
        throw const FormatException('App data exceeds the size limit');
      }
      sink.add(chunk);
    }
  } finally {
    await sink.close();
  }
  if (length == 0) {
    throw const FormatException('App data has an invalid size');
  }
}

Future<void> _backup(Database source, String path) async {
  final destination = sqlite3.open(path);
  try {
    await source.backup(destination, nPage: 128).drain<void>();
  } finally {
    destination.close();
  }
}

String _temporaryPath(Directory directory, String role) =>
    '${directory.path}${Platform.pathSeparator}pku-manager-$role-$pid-'
    '${DateTime.now().microsecondsSinceEpoch}.sqlite3';
