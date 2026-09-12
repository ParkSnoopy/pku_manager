import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';

import '../domain/schedule_import.dart';
import 'schedule_xls_parser.dart';

class NativeSchedulePicker implements SchedulePicker {
  @override
  Future<Uint8List?> pick() async {
    final file = await openFile();
    if (file == null) return null;
    if (await file.length() > maxScheduleBytes) {
      throw const FormatException('Workbook exceeds 8 MiB');
    }
    final builder = BytesBuilder(copy: false);
    await for (final chunk in file.openRead()) {
      if (builder.length + chunk.length > maxScheduleBytes) {
        throw const FormatException('Workbook exceeds 8 MiB');
      }
      builder.add(chunk);
    }
    return builder.takeBytes();
  }
}
