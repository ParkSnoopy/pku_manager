import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:excel/excel.dart';
import 'package:flutter/material.dart' show Color;
import 'package:flutter_test/flutter_test.dart';
import 'package:pku_manager/domain/course.dart';
import 'package:pku_manager/domain/timetable.dart';
import 'package:pku_manager/domain/week_frequency.dart';
import 'package:pku_manager/features/timetable/timetable_export.dart';
import 'package:pku_manager/features/timetable/timetable_color.dart';
import 'package:pku_manager/features/timetable/timetable_style.dart';
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
  String? fontFamily;
  ui.FontWeight? fontWeight;
  Color? indexColor;
  ui.Brightness? brightness;
  Color? surfaceColor;

  @override
  Future<Uint8List> encode(
    Timetable value,
    AppStrings strings,
    int paletteSeed, {
    Map<String, CourseAppearance> courseAppearances = const {},
    int paletteIndex = 0,
    List<Color> customPalette = defaultCustomPalette,
    double fontScale = 1,
    String fontFamily = 'Noto Sans CJK SC',
    ui.FontWeight fontWeight = ui.FontWeight.w400,
    Color indexColor = const Color(0xffe8e0d2),
    ui.Brightness brightness = ui.Brightness.light,
    Color surfaceColor = const Color(0xfffaf9f5),
  }) async {
    timetable = value;
    this.courseAppearances = courseAppearances;
    this.customPalette = customPalette;
    this.fontScale = fontScale;
    this.fontFamily = fontFamily;
    this.fontWeight = fontWeight;
    this.indexColor = indexColor;
    this.brightness = brightness;
    this.surfaceColor = surfaceColor;
    return Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10]);
  }
}

Future<Color> _pixel(Uint8List png, int x, int y) async {
  final codec = await ui.instantiateImageCodec(png);
  final frame = await codec.getNextFrame();
  final image = frame.image;
  try {
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    final offset = (y * image.width + x) * 4;
    return Color.fromARGB(
      data!.getUint8(offset + 3),
      data.getUint8(offset),
      data.getUint8(offset + 1),
      data.getUint8(offset + 2),
    );
  } finally {
    image.dispose();
    codec.dispose();
  }
}

Future<bool> _containsDarkPixel(
  Uint8List png, {
  required int left,
  required int top,
  required int right,
  required int bottom,
}) async {
  final codec = await ui.instantiateImageCodec(png);
  final frame = await codec.getNextFrame();
  final image = frame.image;
  try {
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    for (var y = top; y < bottom; y++) {
      for (var x = left; x < right; x++) {
        final offset = (y * image.width + x) * 4;
        if (data!.getUint8(offset) < 80 &&
            data.getUint8(offset + 1) < 80 &&
            data.getUint8(offset + 2) < 80) {
          return true;
        }
      }
    }
    return false;
  } finally {
    image.dispose();
    codec.dispose();
  }
}

void _expectColorNear(Color actual, Color expected) {
  expect(actual.a, closeTo(expected.a, .001));
  expect(actual.r, closeTo(expected.r, .01));
  expect(actual.g, closeTo(expected.g, .01));
  expect(actual.b, closeTo(expected.b, .01));
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
      note: 'Prepare report',
    ),
    Course(
      sourceId: 'b',
      name: 'Physics',
      weekday: 5,
      firstPeriod: 2,
      lastPeriod: 2,
      room: 'Lab',
      frequency: WeekFrequency.even,
      frequencyText: '双周',
    ),
  ], periodCount: 3);
  const strings = AppStrings(ui.Locale('en'));

  test(
    'XLSX export contains five localized weekdays and course spans',
    () async {
      final writer = _Writer();
      await TimetableExporter(writer).export(
        TimetableExportFormat.xlsx,
        timetable,
        strings: strings,
        paletteSeed: 4,
        fontFamily: 'PKU Noto Serif CJK SC',
        fontWeight: ui.FontWeight.w400,
        indexColor: const Color(0xfffff0e0),
        surfaceColor: const Color(0xfffafafa),
        courseAppearances: const {
          'a': CourseAppearance(
            color: Color(0xff123456),
            outlined: true,
            outlineColor: Color(0xffabcdef),
            outlineWidth: 3.5,
          ),
          'b': CourseAppearance(color: Color(0xff123456)),
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
        'Algo\n  Room 101\n\nPrepare report',
      );
      expect(sheet.cell(CellIndex.indexByString('B3')).value, isNull);
      expect(sheet.cell(CellIndex.indexByString('B6')).value, isNull);
      expect(
        sheet.cell(CellIndex.indexByString('F6')).value.toString(),
        'Physics\n  Lab',
      );
      expect(
        sheet
            .cell(CellIndex.indexByString('F6'))
            .cellStyle!
            .backgroundColor
            .colorHex,
        'FF123456',
      );
      final styled = sheet.cell(CellIndex.indexByString('B2')).cellStyle!;
      expect(styled.isBold, isTrue);
      expect(styled.backgroundColor.colorHex, 'FF123456');
      expect(styled.fontFamily, 'Noto Serif CJK SC');
      expect(
        sheet
            .cell(CellIndex.indexByString('B1'))
            .cellStyle!
            .backgroundColor
            .colorHex,
        'FFFFF0E0',
      );
      expect(styled.leftBorder.borderStyle, BorderStyle.Thick);
      expect(styled.leftBorder.borderColorHex, 'FFABCDEF');
    },
  );

  test(
    'XLSX keeps adjacent source cells separate with one class color',
    () async {
      final writer = _Writer();
      await TimetableExporter(writer).export(
        TimetableExportFormat.xlsx,
        Timetable([
          Course(
            sourceId: 'first-cell',
            sourceName: 'Shared class',
            name: 'First cell',
            weekday: 1,
            firstPeriod: 1,
            lastPeriod: 1,
          ),
          Course(
            sourceId: 'second-cell',
            sourceName: 'Shared class',
            name: 'Second cell',
            weekday: 1,
            firstPeriod: 2,
            lastPeriod: 2,
          ),
        ], periodCount: 2),
        strings: strings,
        paletteSeed: 11,
      );

      final sheet = Excel.decodeBytes(writer.file!.bytes)['Timetable'];
      final first = sheet.cell(CellIndex.indexByString('B2'));
      final second = sheet.cell(CellIndex.indexByString('B6'));
      expect(first.value.toString(), startsWith('First cell'));
      expect(second.value.toString(), startsWith('Second cell'));
      expect(
        first.cellStyle!.backgroundColor.colorHex,
        second.cellStyle!.backgroundColor.colorHex,
      );
    },
  );

  test('conflicting classes use red outlines in XLSX and PNG', () async {
    final conflicting = Timetable([
      Course(
        sourceId: 'left',
        name: 'Left',
        weekday: 1,
        firstPeriod: 1,
        lastPeriod: 2,
      ),
      Course(
        sourceId: 'right',
        name: 'Right',
        weekday: 1,
        firstPeriod: 2,
        lastPeriod: 2,
      ),
    ], periodCount: 2);
    final writer = _Writer();
    await TimetableExporter(writer).export(
      TimetableExportFormat.xlsx,
      conflicting,
      strings: strings,
      paletteSeed: 4,
    );
    final workbook = Excel.decodeBytes(writer.file!.bytes);
    final border = workbook['Timetable']
        .cell(CellIndex.indexByString('B2'))
        .cellStyle!
        .leftBorder;
    expect(border.borderStyle, BorderStyle.Thick);
    expect(border.borderColorHex, 'FFD32F2F');

    final png = await const CanvasTimetablePngEncoder().encode(
      conflicting,
      strings,
      4,
    );
    int pixel(double logical) => (logical * timetableExportScale).round();
    _expectColorNear(
      await _pixel(
        png,
        pixel(timetableExportPadding + timetableIndexWidth + 1),
        pixel(timetableExportPadding + timetableHeaderHeight + 10),
      ),
      timetableConflictColor,
    );
  });

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
      fontFamily: 'PKU Noto Serif CJK SC',
      fontWeight: ui.FontWeight.w700,
      indexColor: const Color(0xff123123),
      brightness: ui.Brightness.dark,
      surfaceColor: const Color(0xff101010),
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
    expect(encoder.fontFamily, 'PKU Noto Serif CJK SC');
    expect(encoder.fontWeight, ui.FontWeight.w700);
    expect(encoder.indexColor, const Color(0xff123123));
    expect(encoder.brightness, ui.Brightness.dark);
    expect(encoder.surfaceColor, const Color(0xff101010));
  });

  test('PNG uses page colors without fading non-current classes', () async {
    const surface = Color(0xff101010);
    const index = Color(0xfff0d0b0);
    const course = Color(0xff123456);
    final png = await const CanvasTimetablePngEncoder().encode(
      timetable,
      strings,
      4,
      courseAppearances: const {
        'a': CourseAppearance(color: course),
        'b': CourseAppearance(color: course),
      },
      indexColor: index,
      brightness: ui.Brightness.dark,
      surfaceColor: surface,
    );
    final effectiveIndex = themedTimetableColor(
      index,
      brightness: ui.Brightness.dark,
      surface: surface,
    );
    final effectiveCourse = themedTimetableColor(
      course,
      brightness: ui.Brightness.dark,
      surface: surface,
    );
    int pixel(double logical) => (logical * timetableExportScale).round();

    _expectColorNear(await _pixel(png, pixel(2), pixel(2)), surface);
    _expectColorNear(
      await _pixel(
        png,
        pixel(timetableExportPadding + 5),
        pixel(timetableExportPadding + 5),
      ),
      effectiveIndex,
    );
    _expectColorNear(
      await _pixel(
        png,
        pixel(timetableExportPadding + timetableIndexWidth + 5),
        pixel(timetableExportPadding + timetableHeaderHeight + 5),
      ),
      effectiveCourse,
    );
    _expectColorNear(
      await _pixel(
        png,
        pixel(
          timetableExportPadding +
              timetableIndexWidth +
              TimetableGeometry(timetable.periodCount).courseWidth * 4 +
              5,
        ),
        pixel(
          timetableExportPadding +
              TimetableGeometry(timetable.periodCount).periodTop(2) +
              5,
        ),
      ),
      effectiveCourse,
    );
    expect(effectiveCourse.a, 1);
  });

  test('PNG wraps and clips notes like timetable cells', () async {
    final noteTable = Timetable([
      Course(
        sourceId: 'note',
        name: 'Course',
        weekday: 1,
        firstPeriod: 1,
        lastPeriod: 3,
        room: 'Room',
        note: List.filled(40, 'MMMM').join(' '),
      ),
    ], periodCount: 3);
    final png = await const CanvasTimetablePngEncoder().encode(
      noteTable,
      strings,
      4,
    );
    int pixel(double logical) => (logical * timetableExportScale).round();
    final cellLeft = timetableExportPadding + timetableIndexWidth;
    final cellBottom = timetableExportPadding + timetableHeaderHeight + 300;

    expect(
      await _containsDarkPixel(
        png,
        left: pixel(cellLeft + timetableCourseContentPadding),
        top: pixel(cellBottom - timetableCourseContentPadding - 11),
        right: pixel(
          cellLeft +
              TimetableGeometry(noteTable.periodCount).courseWidth -
              timetableCourseContentPadding,
        ),
        bottom: pixel(cellBottom - timetableCourseContentPadding),
      ),
      isTrue,
    );
  });
}
