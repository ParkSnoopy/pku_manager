import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pku_manager/domain/course_meeting.dart';
import 'package:pku_manager/domain/timetable.dart';
import 'package:pku_manager/features/timetable/timetable_export.dart';
import 'package:pku_manager/l10n/app_strings.dart';

final class _Writer implements ExportFileWriter {
  ExportFile? file;

  @override
  Future<void> save(ExportFile value) async => file = value;
}

final class _PngEncoder implements TimetablePngEncoder {
  Timetable? timetable;

  @override
  Future<Uint8List> encode(
    Timetable value,
    AppStrings strings,
    int paletteSeed,
  ) async {
    timetable = value;
    return Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10]);
  }
}

void main() {
  final timetable = Timetable([
    CourseMeeting(
      sourceId: 'a',
      name: 'Algorithms',
      weekday: 1,
      firstPeriod: 1,
      lastPeriod: 2,
      room: 'Room 101',
    ),
    CourseMeeting(
      sourceId: 'b',
      name: 'Physics',
      weekday: 5,
      firstPeriod: 2,
      lastPeriod: 2,
      room: 'Lab',
    ),
  ], periodCount: 3);
  const strings = AppStrings(ui.Locale('en'));

  test(
    'XLSX export contains five localized weekdays and repeated cells',
    () async {
      final writer = _Writer();
      await TimetableExporter(writer).export(
        TimetableExportFormat.xlsx,
        timetable,
        strings: strings,
        paletteSeed: 4,
      );

      final file = writer.file!;
      expect(file.name, 'pku-timetable');
      expect(file.extension, 'xlsx');
      expect(
        file.mimeType,
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      );
      final workbook = Excel.decodeBytes(file.bytes);
      final sheet = workbook['Timetable'];
      expect(sheet.maxColumns, 6);
      expect(sheet.maxRows, 4);
      expect(
        sheet.cell(CellIndex.indexByString('B1')).value.toString(),
        'Monday',
      );
      expect(
        sheet.cell(CellIndex.indexByString('F1')).value.toString(),
        'Friday',
      );
      expect(
        sheet.cell(CellIndex.indexByString('B2')).value.toString(),
        'Algorithms\n  Room 101',
      );
      expect(
        sheet.cell(CellIndex.indexByString('B3')).value.toString(),
        'Algorithms\n  Room 101',
      );
    },
  );

  test('PNG export uses the complete timetable encoder', () async {
    final writer = _Writer();
    final encoder = _PngEncoder();
    await TimetableExporter(writer, pngEncoder: encoder).export(
      TimetableExportFormat.png,
      timetable,
      strings: strings,
      paletteSeed: 4,
    );

    final file = writer.file!;
    expect(file.extension, 'png');
    expect(file.mimeType, 'image/png');
    expect(file.bytes.take(8), [137, 80, 78, 71, 13, 10, 26, 10]);
    expect(encoder.timetable, same(timetable));
  });
}
