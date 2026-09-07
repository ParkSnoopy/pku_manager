import 'dart:ui' as ui;

import 'package:excel/excel.dart';
import 'package:file_saver/file_saver.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';

import '../../domain/course_meeting.dart';
import '../../domain/timetable.dart';
import '../../l10n/app_strings.dart';
import 'timetable_color.dart';

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
    int paletteSeed,
  );
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
  }) async {
    final bytes = switch (format) {
      TimetableExportFormat.xlsx => _xlsx(timetable, strings, paletteSeed),
      TimetableExportFormat.png => await pngEncoder.encode(
        timetable,
        strings,
        paletteSeed,
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

  Uint8List _xlsx(Timetable timetable, AppStrings strings, int paletteSeed) {
    final excel = Excel.createExcel();
    excel.rename(excel.getDefaultSheet()!, 'Timetable');
    final sheet = excel['Timetable'];
    sheet.appendRow([
      TextCellValue(''),
      for (var day = 1; day <= 5; day++) TextCellValue(strings.weekday(day)),
    ]);
    for (var period = 1; period <= timetable.periodCount; period++) {
      sheet.appendRow([
        IntCellValue(period),
        for (var day = 1; day <= 5; day++)
          TextCellValue(_cellText(timetable.atPeriod(day, period))),
      ]);
    }
    sheet.setColumnWidth(0, 8);
    for (var column = 1; column <= 5; column++) {
      sheet.setColumnWidth(column, 24);
    }
    for (var row = 0; row <= timetable.periodCount; row++) {
      sheet.setRowHeight(row, row == 0 ? 24 : 42);
      for (var column = 0; column <= 5; column++) {
        final cell = sheet.cell(
          CellIndex.indexByColumnRow(columnIndex: column, rowIndex: row),
        );
        final meetings = row == 0 || column == 0
            ? const <CourseMeeting>[]
            : timetable.atPeriod(column, row);
        cell.cellStyle = CellStyle(
          bold: row == 0 || column == 0,
          textWrapping: TextWrapping.WrapText,
          verticalAlign: VerticalAlign.Center,
          horizontalAlign: column == 0
              ? HorizontalAlign.Center
              : HorizontalAlign.Left,
          backgroundColorHex: meetings.isEmpty
              ? (row == 0 || column == 0
                    ? ExcelColor.fromHexString('#FFF2F2F2')
                    : ExcelColor.none)
              : ExcelColor.fromHexString(
                  _hex(timetableCourseColor(meetings.first, paletteSeed)),
                ),
          bottomBorder: Border(borderStyle: BorderStyle.Thin),
          rightBorder: Border(borderStyle: BorderStyle.Thin),
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
    int paletteSeed,
  ) async {
    const width = 1200.0;
    const headerHeight = 60.0;
    const rowHeight = 60.0;
    const periodWidth = 100.0;
    const dayWidth = (width - periodWidth) / 5;
    final height = headerHeight + rowHeight * timetable.periodCount;
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    canvas.drawRect(
      ui.Rect.fromLTWH(0, 0, width, height),
      ui.Paint()..color = const ui.Color(0xffffffff),
    );
    final border = ui.Paint()
      ..color = const ui.Color(0xffd6d6d6)
      ..style = ui.PaintingStyle.stroke
      ..strokeWidth = 1;
    for (var day = 1; day <= 5; day++) {
      _drawText(
        canvas,
        strings.weekday(day),
        ui.Rect.fromLTWH(
          periodWidth + (day - 1) * dayWidth,
          0,
          dayWidth,
          headerHeight,
        ),
        center: true,
        bold: true,
      );
    }
    for (var period = 1; period <= timetable.periodCount; period++) {
      final top = headerHeight + (period - 1) * rowHeight;
      _drawText(
        canvas,
        '$period',
        ui.Rect.fromLTWH(0, top, periodWidth, rowHeight),
        center: true,
        bold: true,
      );
      for (var day = 1; day <= 5; day++) {
        final rect = ui.Rect.fromLTWH(
          periodWidth + (day - 1) * dayWidth,
          top,
          dayWidth,
          rowHeight,
        );
        final meetings = timetable.atPeriod(day, period);
        if (meetings.isEmpty) continue;
        final itemHeight = rowHeight / meetings.length;
        for (var index = 0; index < meetings.length; index++) {
          final meeting = meetings[index];
          final item = ui.Rect.fromLTWH(
            rect.left,
            rect.top + itemHeight * index,
            rect.width,
            itemHeight,
          );
          canvas.drawRect(
            item,
            ui.Paint()..color = timetableCourseColor(meeting, paletteSeed),
          );
          _drawText(
            canvas,
            '${meeting.name}\n  ${meeting.room}',
            item,
            bold: true,
          );
        }
      }
    }
    for (var column = 0; column <= 5; column++) {
      final x = column == 0 ? 0.0 : periodWidth + (column - 1) * dayWidth;
      canvas.drawLine(ui.Offset(x, 0), ui.Offset(x, height), border);
    }
    canvas.drawLine(ui.Offset(width, 0), ui.Offset(width, height), border);
    for (var row = 0; row <= timetable.periodCount + 1; row++) {
      final y = row == 0 ? 0.0 : headerHeight + (row - 1) * rowHeight;
      canvas.drawLine(ui.Offset(0, y), ui.Offset(width, y), border);
    }
    final image = recorder.endRecording().toImageSync(
      width.toInt(),
      height.toInt(),
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

String _cellText(List<CourseMeeting> meetings) =>
    meetings.map((meeting) => '${meeting.name}\n  ${meeting.room}').join('\n');

String _hex(ui.Color color) =>
    '#${color.toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase()}';

void _drawText(
  ui.Canvas canvas,
  String text,
  ui.Rect rect, {
  bool center = false,
  bool bold = false,
}) {
  final builder =
      ui.ParagraphBuilder(
        ui.ParagraphStyle(
          maxLines: 2,
          textAlign: center ? ui.TextAlign.center : ui.TextAlign.left,
          ellipsis: '…',
        ),
      )..pushStyle(
        ui.TextStyle(
          color: const ui.Color(0xff171717),
          fontSize: 16,
          fontWeight: bold ? ui.FontWeight.w600 : ui.FontWeight.w400,
        ),
      );
  builder.addText(text);
  final paragraph = builder.build()
    ..layout(ui.ParagraphConstraints(width: rect.width - 16));
  canvas.save();
  canvas.clipRect(rect);
  canvas.drawParagraph(
    paragraph,
    ui.Offset(
      rect.left + 8,
      center ? rect.top + (rect.height - paragraph.height) / 2 : rect.top + 8,
    ),
  );
  canvas.restore();
  paragraph.dispose();
}
