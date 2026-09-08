import 'dart:ui' as ui;

import 'package:excel/excel.dart';
import 'package:file_saver/file_saver.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';

import '../../domain/course_meeting.dart';
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
  }) async {
    final bytes = switch (format) {
      TimetableExportFormat.xlsx => _xlsx(
        timetable,
        strings,
        paletteSeed,
        courseAppearances,
      ),
      TimetableExportFormat.png => await pngEncoder.encode(
        timetable,
        strings,
        paletteSeed,
        courseAppearances: courseAppearances,
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
  ) {
    final excel = Excel.createExcel();
    excel.rename(excel.getDefaultSheet()!, 'Timetable');
    final sheet = excel['Timetable'];
    sheet.appendRow([
      TextCellValue(''),
      for (var day = 1; day <= 5; day++) TextCellValue(strings.weekday(day)),
    ]);
    for (var period = 1; period <= timetable.periodCount; period++) {
      final start = timetableClassStarts[period] ?? '';
      for (var role = 0; role < 4; role++) {
        sheet.appendRow([
          switch (role) {
            0 => TextCellValue(start),
            1 => IntCellValue(period),
            2 => TextCellValue(start.isEmpty ? '' : timetableClassEnd(start)),
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
            ? const <CourseMeeting>[]
            : timetable.atPeriod(column, period);
        final courseAppearance = meetings.isEmpty
            ? null
            : courseAppearances[meetings.first.sourceId];
        final important = courseAppearance?.outlined ?? false;
        final index = row == 0 || column == 0;
        final outer = ExcelColor.fromHexString('#FF92918D');
        final thin = ExcelColor.fromHexString('#FFE6DFD8');
        cell.cellStyle = CellStyle(
          bold:
              row == 0 ||
              (column == 0 && role == 1) ||
              (column > 0 && role == 0),
          fontFamily: column == 0 && row > 0 && role == 1
              ? 'Noto Serif CJK SC'
              : 'Roboto Mono',
          fontSize: row == 0
              ? 15
              : column == 0
              ? (role == 1 ? 23 : 12)
              : (role == 0 ? 14 : 11),
          fontColorHex: ExcelColor.fromHexString(
            column == 0 && row > 0 && role != 1 ? '#FF6C6A64' : '#FF141413',
          ),
          textWrapping: TextWrapping.WrapText,
          verticalAlign: VerticalAlign.Center,
          horizontalAlign: index
              ? HorizontalAlign.Center
              : HorizontalAlign.Left,
          backgroundColorHex: meetings.isEmpty
              ? (index
                    ? ExcelColor.fromHexString('#FFE8E0D2')
                    : ExcelColor.fromHexString('#FFFAF9F5'))
              : ExcelColor.fromHexString(
                  _hex(
                    timetableCourseColor(
                      meetings.first,
                      paletteSeed,
                      appearance: courseAppearance,
                    ),
                  ),
                ),
          leftBorder: Border(
            borderStyle: column == 0 || important
                ? BorderStyle.Medium
                : BorderStyle.Thin,
            borderColorHex: column == 0 || important ? outer : thin,
          ),
          rightBorder: Border(
            borderStyle: column == 5 || important
                ? BorderStyle.Medium
                : BorderStyle.Thin,
            borderColorHex: column == 5 || important ? outer : thin,
          ),
          topBorder: Border(
            borderStyle: row == 0 || (important && role == 0)
                ? BorderStyle.Medium
                : BorderStyle.None,
            borderColorHex: outer,
          ),
          bottomBorder: Border(
            borderStyle: row == 0
                ? BorderStyle.Thin
                : important && role == 3
                ? BorderStyle.Medium
                : role == 3
                ? BorderStyle.Medium
                : BorderStyle.None,
            borderColorHex: row == 0 ? thin : outer,
          ),
        );
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
  }) async {
    final geometry = TimetableGeometry(timetable.periodCount);
    final logicalWidth = geometry.width + timetableExportPadding * 2;
    final logicalHeight = geometry.height + timetableExportPadding * 2;
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    canvas.scale(timetableExportScale);
    canvas.drawRect(
      ui.Rect.fromLTWH(0, 0, logicalWidth, logicalHeight),
      ui.Paint()..color = timetableCanvas,
    );
    canvas.translate(timetableExportPadding, timetableExportPadding);
    final border = ui.Paint()
      ..color = timetableDivider
      ..style = ui.PaintingStyle.stroke
      ..strokeWidth = timetableDividerWidth;
    canvas.drawRect(
      ui.Rect.fromLTWH(0, 0, geometry.width, timetableHeaderHeight),
      ui.Paint()..color = timetableIndexSurface,
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
        fontFamily: timetableMonoFont,
        fontFallback: timetableFontFallback,
        fontSize: 20,
        bold: true,
        color: timetableInk,
      );
    }
    var top = timetableHeaderHeight;
    canvas.drawLine(ui.Offset(0, top), ui.Offset(geometry.width, top), border);
    for (var period = 1; period <= timetable.periodCount; period++) {
      canvas.drawRect(
        ui.Rect.fromLTWH(0, top, timetableIndexWidth, timetablePeriodHeight),
        ui.Paint()..color = timetableIndexSurface,
      );
      final start = timetableClassStarts[period] ?? '';
      if (start.isNotEmpty) {
        _drawReferenceText(
          canvas,
          start,
          ui.Rect.fromLTWH(0, top + 10, timetableIndexWidth, 16),
          center: true,
          fontFamily: timetableMonoFont,
          fontSize: 16,
          weight: ui.FontWeight.w500,
          color: timetableMuted,
          lineHeight: 1,
        );
        _drawReferenceText(
          canvas,
          timetableClassEnd(start),
          ui.Rect.fromLTWH(
            0,
            top + timetablePeriodHeight - 26,
            timetableIndexWidth,
            16,
          ),
          center: true,
          fontFamily: timetableMonoFont,
          fontSize: 16,
          weight: ui.FontWeight.w500,
          color: timetableMuted,
          lineHeight: 1,
        );
      }
      _drawReferenceText(
        canvas,
        '$period',
        ui.Rect.fromLTWH(0, top, timetableIndexWidth, timetablePeriodHeight),
        center: true,
        fontFamily: timetableSerifFont,
        fontSize: 30,
        bold: true,
        color: timetableInk,
        lineHeight: 1,
      );
      for (var day = 1; day <= 5; day++) {
        final rect = ui.Rect.fromLTWH(
          timetableIndexWidth + (day - 1) * geometry.courseWidth,
          top,
          geometry.courseWidth,
          timetablePeriodHeight,
        );
        final meetings = timetable.atPeriod(day, period);
        if (meetings.isEmpty) continue;
        final itemHeight = timetablePeriodHeight / meetings.length;
        for (var index = 0; index < meetings.length; index++) {
          final meeting = meetings[index];
          final item = ui.Rect.fromLTWH(
            rect.left,
            rect.top + itemHeight * index,
            rect.width,
            itemHeight,
          );
          final appearance = courseAppearances[meeting.sourceId];
          canvas.drawRect(
            item,
            ui.Paint()
              ..color = timetableCourseColor(
                meeting,
                paletteSeed,
                appearance: appearance,
              ),
          );
          final foreground =
              timetableCourseColor(
                    meeting,
                    paletteSeed,
                    appearance: appearance,
                  ).computeLuminance() >
                  .5
              ? const ui.Color(0xff000000)
              : const ui.Color(0xffffffff);
          if (appearance?.outlined ?? false) {
            canvas.drawRect(
              item.deflate(2),
              ui.Paint()
                ..color = foreground
                ..style = ui.PaintingStyle.stroke
                ..strokeWidth = 4,
            );
          }
          _drawReferenceText(
            canvas,
            meeting.name,
            ui.Rect.fromLTWH(item.left + 4, item.top + 2, item.width - 8, 24),
            fontFamily: timetableMonoFont,
            fontFallback: timetableFontFallback,
            fontSize: timetableCourseNameFontSize(meeting.name, item.width),
            bold: true,
            color: foreground,
            letterSpacing: -.2,
          );
          _drawReferenceText(
            canvas,
            '  ${meeting.room}',
            ui.Rect.fromLTWH(
              item.left + 4,
              item.top + 25.4,
              item.width - 8,
              20,
            ),
            fontFamily: timetableMonoFont,
            fontFallback: timetableFontFallback,
            fontSize: 15,
            weight: ui.FontWeight.w500,
            color: foreground,
          );
        }
      }
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

String _xlsxCourseValue(List<CourseMeeting> meetings, int role) =>
    switch (role) {
      0 => meetings.map((meeting) => meeting.name).join('\n'),
      1 => meetings.map((meeting) => '  ${meeting.room}').join('\n'),
      _ => '',
    };

String _hex(ui.Color color) =>
    '#${color.toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase()}';

void _drawReferenceText(
  ui.Canvas canvas,
  String text,
  ui.Rect rect, {
  bool center = false,
  bool bold = false,
  required String fontFamily,
  List<String>? fontFallback,
  required double fontSize,
  ui.FontWeight? weight,
  required ui.Color color,
  double? letterSpacing,
  double lineHeight = 1.3,
}) {
  final builder =
      ui.ParagraphBuilder(
        ui.ParagraphStyle(
          maxLines: 1,
          textAlign: center ? ui.TextAlign.center : ui.TextAlign.left,
          ellipsis: '…',
        ),
      )..pushStyle(
        ui.TextStyle(
          color: color,
          fontFamily: fontFamily,
          fontFamilyFallback: fontFallback,
          fontSize: fontSize,
          fontWeight: bold ? ui.FontWeight.w700 : weight ?? ui.FontWeight.w400,
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
