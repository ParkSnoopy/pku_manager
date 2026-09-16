import 'dart:ui' as ui;

import 'package:excel/excel.dart';
import 'package:file_saver/file_saver.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';

import '../../domain/course.dart';
import '../../domain/timetable.dart';
import '../../l10n/app_strings.dart';
import 'timetable_color.dart';
import 'timetable_style.dart';

enum TimetableExportFormat { png, xlsx }

final class ExportFile {
  const ExportFile({
    required this.name,
    required this.extension,
    required this.mimeType,
    required this.bytes,
  });

  final String name;
  final String extension;
  final String mimeType;
  final Uint8List bytes;
}

abstract interface class ExportFileWriter {
  Future<void> save(ExportFile file);
}

abstract interface class TimetablePngEncoder {
  Future<Uint8List> encode(
    Timetable timetable,
    AppStrings strings,
    int paletteSeed, {
    Map<String, CourseAppearance> courseAppearances = const {},
    int paletteIndex = 0,
    List<ui.Color> customPalette = defaultCustomPalette,
    double fontScale = 1,
    String fontFamily = timetableSansFont,
    ui.FontWeight fontWeight = ui.FontWeight.w400,
    ui.Color indexColor = timetableIndexSurface,
    ui.Brightness brightness = ui.Brightness.light,
    ui.Color surfaceColor = timetableCanvas,
  });
}

final class NativeExportFileWriter implements ExportFileWriter {
  @override
  Future<void> save(ExportFile file) async {
    final fullName = '${file.name}.${file.extension}';
    if (defaultTargetPlatform
        case TargetPlatform.linux ||
            TargetPlatform.macOS ||
            TargetPlatform.windows) {
      final location = await getSaveLocation(
        suggestedName: fullName,
        acceptedTypeGroups: [
          XTypeGroup(
            label: file.extension.toUpperCase(),
            extensions: [file.extension],
            mimeTypes: [file.mimeType],
          ),
        ],
      );
      if (location == null) return;
      await XFile.fromData(
        file.bytes,
        mimeType: file.mimeType,
        name: fullName,
      ).saveTo(location.path);
      return;
    }
    await FileSaver.instance.saveAs(
      name: file.name,
      bytes: file.bytes,
      fileExtension: file.extension,
      mimeType: file.extension == 'png'
          ? MimeType.png
          : MimeType.microsoftExcel,
    );
  }
}

final class TimetableExporter {
  TimetableExporter(this.writer, {TimetablePngEncoder? pngEncoder})
    : pngEncoder = pngEncoder ?? const CanvasTimetablePngEncoder();

  final ExportFileWriter writer;
  final TimetablePngEncoder pngEncoder;

  Future<void> export(
    TimetableExportFormat format,
    Timetable timetable, {
    required AppStrings strings,
    required int paletteSeed,
    Map<String, CourseAppearance> courseAppearances = const {},
    int paletteIndex = 0,
    List<ui.Color> customPalette = defaultCustomPalette,
    double timetableFontScale = 1,
    String fontFamily = timetableSansFont,
    ui.FontWeight fontWeight = ui.FontWeight.w400,
    ui.Color indexColor = timetableIndexSurface,
    ui.Brightness brightness = ui.Brightness.light,
    ui.Color surfaceColor = timetableCanvas,
  }) async {
    final bytes = switch (format) {
      TimetableExportFormat.xlsx => _xlsx(
        timetable,
        strings,
        paletteSeed,
        courseAppearances,
        paletteIndex,
        customPalette,
        timetableFontScale,
        fontFamily,
        fontWeight,
        indexColor,
        brightness,
        surfaceColor,
      ),
      TimetableExportFormat.png => await pngEncoder.encode(
        timetable,
        strings,
        paletteSeed,
        courseAppearances: courseAppearances,
        paletteIndex: paletteIndex,
        customPalette: customPalette,
        fontScale: timetableFontScale,
        fontFamily: fontFamily,
        fontWeight: fontWeight,
        indexColor: indexColor,
        brightness: brightness,
        surfaceColor: surfaceColor,
      ),
    };
    await writer.save(
      ExportFile(
        name: 'pku-timetable',
        extension: format.name,
        mimeType: switch (format) {
          TimetableExportFormat.png => 'image/png',
          TimetableExportFormat.xlsx =>
            'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        },
        bytes: bytes,
      ),
    );
  }

  Uint8List _xlsx(
    Timetable timetable,
    AppStrings strings,
    int paletteSeed,
    Map<String, CourseAppearance> courseAppearances,
    int paletteIndex,
    List<ui.Color> customPalette,
    double fontScale,
    String fontFamily,
    ui.FontWeight fontWeight,
    ui.Color indexColor,
    ui.Brightness brightness,
    ui.Color surfaceColor,
  ) {
    final excel = Excel.createExcel();
    excel.rename(excel.getDefaultSheet()!, 'Timetable');
    final sheet = excel['Timetable'];
    final conflictingSourceIds = timetable.conflictingSourceIds;
    final courseColors = timetableCourseColors(
      timetable,
      paletteSeed,
      courseAppearances: courseAppearances,
      paletteIndex: paletteIndex,
      customPalette: customPalette,
    );
    final effectiveIndexColor = themedTimetableColor(
      indexColor,
      brightness: brightness,
      surface: surfaceColor,
    );
    sheet.appendRow([
      TextCellValue(''),
      for (var day = 1; day <= 5; day++) TextCellValue(strings.weekday(day)),
    ]);
    for (var period = 1; period <= timetable.periodCount; period++) {
      for (var role = 0; role < 4; role++) {
        sheet.appendRow([
          switch (role) {
            1 => IntCellValue(period),
            _ => TextCellValue(''),
          },
          for (var day = 1; day <= 5; day++)
            TextCellValue(
              _xlsxCourseValue(timetable.atPeriod(day, period), role),
            ),
        ]);
      }
    }
    sheet.setColumnWidth(0, 16.43);
    for (var column = 1; column <= 5; column++) {
      sheet.setColumnWidth(
        column,
        (TimetableGeometry(timetable.periodCount).courseWidth - 5) / 7,
      );
    }
    sheet.setRowHeight(0, 33);
    const roleHeights = [23.55, 16.75, 17.35, 17.35];
    for (var row = 0; row <= timetable.periodCount * 4; row++) {
      if (row > 0) sheet.setRowHeight(row, roleHeights[(row - 1) % 4]);
      for (var column = 0; column <= 5; column++) {
        final cell = sheet.cell(
          CellIndex.indexByColumnRow(columnIndex: column, rowIndex: row),
        );
        final period = row == 0 ? 0 : ((row - 1) ~/ 4) + 1;
        final role = row == 0 ? 0 : (row - 1) % 4;
        final meetings = row == 0 || column == 0
            ? const <Course>[]
            : timetable.atPeriod(column, period);
        final courseAppearance = meetings.isEmpty
            ? null
            : courseAppearances[meetings.first.sourceId];
        final conflicting = meetings.any(
          (meeting) => conflictingSourceIds.contains(meeting.sourceId),
        );
        final important = conflicting || (courseAppearance?.outlined ?? false);
        final importantColor = ExcelColor.fromHexString(
          _hex(
            conflicting
                ? timetableConflictColor
                : courseAppearance?.outlineColor ?? defaultCourseOutlineColor,
          ),
        );
        final importantStyle = _xlsxOutlineStyle(
          conflicting
              ? timetableConflictWidth
              : courseAppearance?.outlineWidth ?? defaultCourseOutlineWidth,
        );
        final index = row == 0 || column == 0;
        final courseColor = meetings.isEmpty
            ? null
            : themedTimetableColor(
                courseColors[meetings.first.sourceId]!,
                brightness: brightness,
                surface: surfaceColor,
              );
        final foreground = index
            ? timetableContrastForeground(effectiveIndexColor)
            : courseColor == null
            ? brightness == ui.Brightness.dark
                  ? const ui.Color(0xffffffff)
                  : const ui.Color(0xff000000)
            : timetableContrastForeground(courseColor);
        final outer = ExcelColor.fromHexString('#FF92918D');
        final thin = ExcelColor.fromHexString('#FFE6DFD8');
        cell.cellStyle = CellStyle(
          bold:
              !index && meetings.isNotEmpty && role == 0 ||
              fontWeight.value >= ui.FontWeight.w600.value,
          fontFamily: _xlsxFontFamily(fontFamily),
          fontSize:
              ((row == 0
                          ? 15
                          : column == 0
                          ? (role == 1 ? 23 : 12)
                          : (role <= 1 ? 14 : 11)) *
                      fontScale)
                  .round(),
          fontColorHex: ExcelColor.fromHexString(_hex(foreground)),
          textWrapping: TextWrapping.WrapText,
          verticalAlign: VerticalAlign.Center,
          horizontalAlign: index
              ? HorizontalAlign.Center
              : HorizontalAlign.Left,
          backgroundColorHex: meetings.isEmpty
              ? (index
                    ? ExcelColor.fromHexString(_hex(effectiveIndexColor))
                    : ExcelColor.fromHexString(_hex(surfaceColor)))
              : ExcelColor.fromHexString(_hex(courseColor!)),
          leftBorder: Border(
            borderStyle: column == 0 || important
                ? (important ? importantStyle : BorderStyle.Medium)
                : BorderStyle.Thin,
            borderColorHex: important
                ? importantColor
                : column == 0
                ? outer
                : thin,
          ),
          rightBorder: Border(
            borderStyle: column == 5 || important
                ? (important ? importantStyle : BorderStyle.Medium)
                : BorderStyle.Thin,
            borderColorHex: important
                ? importantColor
                : column == 5
                ? outer
                : thin,
          ),
          topBorder: Border(
            borderStyle: row == 0 || (important && role == 0)
                ? (important ? importantStyle : BorderStyle.Medium)
                : BorderStyle.None,
            borderColorHex: important ? importantColor : outer,
          ),
          bottomBorder: Border(
            borderStyle: row == 0
                ? BorderStyle.Thin
                : important && role == 3
                ? importantStyle
                : role == 3
                ? BorderStyle.Medium
                : BorderStyle.None,
            borderColorHex: important
                ? importantColor
                : row == 0
                ? thin
                : outer,
          ),
        );
      }
    }
    for (var day = 1; day <= 5; day++) {
      final layout = TimetableDayLayout.from(timetable, day);
      if (layout.laneCount != 1) continue;
      for (final span in layout.spans) {
        final meeting = span.group.primary;
        final startRow = 1 + (span.firstPeriod - 1) * 4;
        final endRow = span.lastPeriod * 4;
        final start = CellIndex.indexByColumnRow(
          columnIndex: day,
          rowIndex: startRow,
        );
        final style = sheet.cell(start).cellStyle;
        sheet.merge(
          start,
          CellIndex.indexByColumnRow(columnIndex: day, rowIndex: endRow),
          customValue: TextCellValue(_courseText(meeting)),
        );
        sheet.cell(start).cellStyle = style;
      }
    }
    return Uint8List.fromList(excel.encode()!);
  }
}

final class CanvasTimetablePngEncoder implements TimetablePngEncoder {
  const CanvasTimetablePngEncoder();

  @override
  Future<Uint8List> encode(
    Timetable timetable,
    AppStrings strings,
    int paletteSeed, {
    Map<String, CourseAppearance> courseAppearances = const {},
    int paletteIndex = 0,
    List<ui.Color> customPalette = defaultCustomPalette,
    double fontScale = 1,
    String fontFamily = timetableSansFont,
    ui.FontWeight fontWeight = ui.FontWeight.w400,
    ui.Color indexColor = timetableIndexSurface,
    ui.Brightness brightness = ui.Brightness.light,
    ui.Color surfaceColor = timetableCanvas,
  }) async {
    final geometry = TimetableGeometry(timetable.periodCount);
    final logicalWidth = geometry.width + timetableExportPadding * 2;
    final logicalHeight = geometry.height + timetableExportPadding * 2;
    final effectiveIndexColor = themedTimetableColor(
      indexColor,
      brightness: brightness,
      surface: surfaceColor,
    );
    final indexForeground = timetableContrastForeground(effectiveIndexColor);
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    canvas.scale(timetableExportScale);
    canvas.drawRect(
      ui.Rect.fromLTWH(0, 0, logicalWidth, logicalHeight),
      ui.Paint()..color = surfaceColor,
    );
    canvas.translate(timetableExportPadding, timetableExportPadding);
    final border = ui.Paint()
      ..color = timetableDivider
      ..style = ui.PaintingStyle.stroke
      ..strokeWidth = timetableDividerWidth;
    canvas.drawRect(
      ui.Rect.fromLTWH(0, 0, geometry.width, timetableHeaderHeight),
      ui.Paint()..color = effectiveIndexColor,
    );
    for (var day = 1; day <= 5; day++) {
      _drawReferenceText(
        canvas,
        strings.weekday(day),
        ui.Rect.fromLTWH(
          timetableIndexWidth + (day - 1) * geometry.courseWidth,
          0,
          geometry.courseWidth,
          timetableHeaderHeight,
        ),
        center: true,
        fontFamily: fontFamily,
        fontFallback: timetableFontFallback,
        fontSize: 20 * fontScale,
        weight: fontWeight,
        color: indexForeground,
      );
    }
    var top = timetableHeaderHeight;
    canvas.drawLine(ui.Offset(0, top), ui.Offset(geometry.width, top), border);
    for (var period = 1; period <= timetable.periodCount; period++) {
      canvas.drawRect(
        ui.Rect.fromLTWH(0, top, timetableIndexWidth, timetablePeriodHeight),
        ui.Paint()..color = effectiveIndexColor,
      );
      _drawReferenceText(
        canvas,
        '$period',
        ui.Rect.fromLTWH(0, top, timetableIndexWidth, timetablePeriodHeight),
        center: true,
        fontFamily: fontFamily,
        fontSize: 30 * fontScale,
        weight: fontWeight,
        color: indexForeground,
        lineHeight: 1,
      );
      top += timetablePeriodHeight;
      canvas.drawLine(
        ui.Offset(0, top),
        ui.Offset(geometry.width, top),
        border,
      );
      if (timetableMealBreaks.contains(period) &&
          period < timetable.periodCount) {
        top += timetableMealBreakHeight;
        canvas.drawLine(
          ui.Offset(0, top),
          ui.Offset(geometry.width, top),
          border,
        );
      }
    }
    final conflictingSourceIds = timetable.conflictingSourceIds;
    final courseColors = timetableCourseColors(
      timetable,
      paletteSeed,
      courseAppearances: courseAppearances,
      paletteIndex: paletteIndex,
      customPalette: customPalette,
    );
    for (var day = 1; day <= 5; day++) {
      final layout = TimetableDayLayout.from(timetable, day);
      final laneWidth = geometry.courseWidth / layout.laneCount;
      for (final span in layout.spans) {
        final meeting = span.group.primary;
        final appearance = courseAppearances[meeting.sourceId];
        final item = ui.Rect.fromLTWH(
          timetableIndexWidth +
              (day - 1) * geometry.courseWidth +
              span.lane * laneWidth,
          geometry.periodTop(span.firstPeriod),
          laneWidth,
          (span.lastPeriod - span.firstPeriod + 1) * timetablePeriodHeight,
        );
        final background = themedTimetableColor(
          courseColors[meeting.sourceId]!,
          brightness: brightness,
          surface: surfaceColor,
        );
        canvas.drawRect(item, ui.Paint()..color = background);
        final foreground = timetableContrastForeground(background);
        const inset = timetableCourseContentPadding;
        final nameHeight = timetableCourseNameFontSize * fontScale * 1.5;
        final roomHeight = timetableClassroomFontSize * fontScale * 1.5;
        final conflicting = span.group.meetings.any(
          (meeting) => conflictingSourceIds.contains(meeting.sourceId),
        );
        if (conflicting || (appearance?.outlined ?? false)) {
          final outlineWidth = conflicting
              ? timetableConflictWidth
              : appearance!.outlineWidth;
          canvas.drawRect(
            item.deflate(outlineWidth / 2),
            ui.Paint()
              ..color = conflicting
                  ? timetableConflictColor
                  : appearance!.outlineColor
              ..style = ui.PaintingStyle.stroke
              ..strokeWidth = outlineWidth,
          );
        }
        _drawReferenceText(
          canvas,
          meeting.displayName,
          ui.Rect.fromLTWH(
            item.left + inset,
            item.top + inset,
            item.width - inset * 2,
            nameHeight,
          ),
          fontFamily: fontFamily,
          fontFallback: timetableFontFallback,
          fontSize: timetableCourseNameFontSize * fontScale,
          weight: timetableCourseNameFontWeight,
          color: foreground,
          letterSpacing: -.2,
          lineHeight: 1.5,
        );
        var contentTop = item.top + inset + nameHeight;
        final metadata = _courseMetadata(meeting);
        if (metadata.isNotEmpty) {
          _drawReferenceText(
            canvas,
            metadata,
            ui.Rect.fromLTWH(
              item.left + inset,
              contentTop,
              item.width - inset * 2,
              roomHeight,
            ),
            fontFamily: fontFamily,
            fontFallback: timetableFontFallback,
            fontSize: timetableClassroomFontSize * fontScale,
            weight: fontWeight,
            color: foreground,
            lineHeight: 1.5,
          );
          contentTop += roomHeight;
        }
        if (meeting.note.isNotEmpty) {
          contentTop += timetableClassroomFontSize * 1.5;
          final availableHeight = item.bottom - inset - contentTop;
          if (availableHeight > 0) {
            _drawReferenceText(
              canvas,
              meeting.note,
              ui.Rect.fromLTWH(
                item.left + inset,
                contentTop,
                item.width - inset * 2,
                availableHeight,
              ),
              fontFamily: fontFamily,
              fontFallback: timetableFontFallback,
              fontSize: timetableCourseNoteFontSize * fontScale,
              weight: fontWeight,
              color: foreground,
              lineHeight: 1.5,
              maxLines: null,
              ellipsize: false,
            );
          }
        }
      }
    }
    canvas.drawRect(
      ui.Rect.fromLTWH(0, 0, geometry.width, geometry.height),
      border,
    );
    final image = recorder.endRecording().toImageSync(
      geometry.exportWidth,
      geometry.exportHeight,
    );
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) throw StateError('PNG encoding failed');
      return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    } finally {
      image.dispose();
    }
  }
}

String _xlsxCourseValue(List<Course> meetings, int role) => switch (role) {
  0 => meetings.map((meeting) => meeting.displayName).join('\n'),
  1 => meetings.map(_courseMetadata).join('\n'),
  3 => meetings.map((meeting) => meeting.note).join('\n'),
  _ => '',
};

String _courseText(Course meeting) => [
  meeting.displayName,
  if (_courseMetadata(meeting).isNotEmpty) _courseMetadata(meeting),
  if (meeting.note.isNotEmpty) '',
  if (meeting.note.isNotEmpty) meeting.note,
].join('\n');

String _courseMetadata(Course meeting) {
  final values = [
    if (meeting.room.trim().isNotEmpty) meeting.room.trim(),
    if (meeting.frequencyText.trim().isNotEmpty) meeting.frequencyText.trim(),
  ];
  return values.isEmpty ? '' : '  (${values.join(', ')})';
}

String _xlsxFontFamily(String family) =>
    family.startsWith('PKU ') ? family.substring(4) : family;

String _hex(ui.Color color) =>
    '#${color.toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase()}';

BorderStyle _xlsxOutlineStyle(double width) => width <= 1
    ? BorderStyle.Thin
    : width <= 2
    ? BorderStyle.Medium
    : BorderStyle.Thick;

void _drawReferenceText(
  ui.Canvas canvas,
  String text,
  ui.Rect rect, {
  bool center = false,
  required String fontFamily,
  List<String>? fontFallback,
  required double fontSize,
  ui.FontWeight? weight,
  required ui.Color color,
  double? letterSpacing,
  double lineHeight = 1.3,
  int? maxLines = 1,
  bool ellipsize = true,
}) {
  final builder =
      ui.ParagraphBuilder(
        ui.ParagraphStyle(
          maxLines: maxLines,
          textAlign: center ? ui.TextAlign.center : ui.TextAlign.left,
          ellipsis: ellipsize ? '…' : null,
        ),
      )..pushStyle(
        ui.TextStyle(
          color: color,
          fontFamily: fontFamily,
          fontFamilyFallback: fontFallback,
          fontSize: fontSize,
          fontWeight: weight ?? ui.FontWeight.w400,
          height: lineHeight,
          letterSpacing: letterSpacing,
        ),
      );
  builder.addText(text);
  final paragraph = builder.build()
    ..layout(ui.ParagraphConstraints(width: rect.width));
  canvas.save();
  canvas.clipRect(rect);
  canvas.drawParagraph(
    paragraph,
    ui.Offset(
      rect.left,
      center ? rect.top + (rect.height - paragraph.height) / 2 : rect.top,
    ),
  );
  canvas.restore();
  paragraph.dispose();
}
