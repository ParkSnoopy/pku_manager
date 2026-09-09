import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:excel/excel.dart';
import 'package:flutter/material.dart' show Color;
import 'package:flutter_test/flutter_test.dart';
import 'package:pku_manager/domain/course.dart';
import 'package:pku_manager/domain/timetable.dart';
import 'package:pku_manager/features/timetable/timetable_export.dart';
import 'package:pku_manager/features/timetable/timetable_color.dart';
import 'package:pku_manager/l10n/app_strings.dart';

final class _Writer implements ExportFileWriter {
  ExportFile? file;

  @override
  Future<void> save(ExportFile value) async => file = value;
}

final class _PngEncoder implements TimetablePngEncoder {
  Timetable? timetable;
  Map<String, CourseAppearance>? courseAppearances;
  List<Color>? customPalette;
  double? fontScale;

  @override
  Future<Uint8List> encode(
    Timetable value,
    AppStrings strings,
    int paletteSeed, {
    Map<String, CourseAppearance> courseAppearances = const {},
    int paletteIndex = 0,
    List<Color> customPalette = defaultCustomPalette,
    double fontScale = 1,
  }) async {
    timetable = value;
    this.courseAppearances = courseAppearances;
    this.customPalette = customPalette;
    this.fontScale = fontScale;
    return Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10]);
  }
}

void main() {
  final timetable = Timetable([
    Course(
      sourceId: 'a',
      name: 'Algorithms',
      shortName: 'Algo',
      weekday: 1,
      firstPeriod: 1,
      lastPeriod: 2,
      room: 'Room 101',
    ),
    Course(
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
    'XLSX export contains five localized weekdays and grouped cells',
    () async {
      final writer = _Writer();
      await TimetableExporter(writer).export(
        TimetableExportFormat.xlsx,
        timetable,
        strings: strings,
        paletteSeed: 4,
        courseAppearances: const {
          'a': CourseAppearance(
            color: Color(0xff123456),
            outlined: true,
            outlineColor: Color(0xffabcdef),
            outlineWidth: 3.5,
          ),
        },
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
      expect(sheet.maxRows, 13);
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
        'Algo\n  Room 101',
      );
      expect(sheet.cell(CellIndex.indexByString('B3')).value, isNull);
      expect(sheet.cell(CellIndex.indexByString('B6')).value, isNull);
      final styled = sheet.cell(CellIndex.indexByString('B2')).cellStyle!;
      expect(styled.backgroundColor.colorHex, 'FF123456');
      expect(styled.leftBorder.borderStyle, BorderStyle.Thick);
      expect(styled.leftBorder.borderColorHex, 'FFABCDEF');
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
      customPalette: const [
        Color(0xff111111),
        Color(0xff222222),
        Color(0xff333333),
        Color(0xff444444),
        Color(0xff555555),
      ],
      timetableFontScale: 1.5,
      courseAppearances: const {
        'a': CourseAppearance(color: Color(0xff123456)),
      },
    );

    final file = writer.file!;
    expect(file.extension, 'png');
    expect(file.mimeType, 'image/png');
    expect(file.bytes.take(8), [137, 80, 78, 71, 13, 10, 26, 10]);
    expect(encoder.timetable, same(timetable));
    expect(encoder.courseAppearances!['a']!.color, const Color(0xff123456));
    expect(encoder.customPalette!.first, const Color(0xff111111));
    expect(encoder.fontScale, 1.5);
  });
}
