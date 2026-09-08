import 'dart:typed_data';

import 'package:excel2003/excel2003.dart';

import '../domain/course.dart';
import '../domain/schedule_import.dart';
import '../domain/week_frequency.dart';

const maxScheduleBytes = 8 * 1024 * 1024;

class ScheduleXlsParser implements ScheduleDecoder {
  @override
  ScheduleCandidate parse(Uint8List bytes) {
    if (bytes.isEmpty || bytes.length > maxScheduleBytes) {
      throw const FormatException('Workbook must be between 1 byte and 8 MiB');
    }
    const signature = [0xd0, 0xcf, 0x11, 0xe0, 0xa1, 0xb1, 0x1a, 0xe1];
    if (bytes.length < 8 ||
        !Iterable<int>.generate(8).every((i) => bytes[i] == signature[i])) {
      throw const FormatException('Expected an Excel 97–2003 workbook');
    }
    final workbook = XlsReader.fromBytes(bytes);
    if (workbook.sheetCount != 1) {
      throw const FormatException('Expected one timetable sheet');
    }
    final sheet = workbook.sheet(0);
    if (sheet.rowCount > 256 || sheet.colCount > 32) {
      throw const FormatException(
        'Workbook dimensions exceed supported bounds',
      );
    }
    return parseCells(
      bytes,
      List.generate(
        sheet.rowCount,
        (r) => List.generate(
          sheet.colCount,
          (c) => sheet.cell(r, c)?.toString() ?? '',
        ),
      ),
    );
  }

  ScheduleCandidate parseCells(Uint8List bytes, List<List<String>> cells) {
    if (cells.isEmpty) throw const FormatException('Empty timetable');
    const days = ['星期一', '星期二', '星期三', '星期四', '星期五', '星期六', '星期日'];
    String normalizeHeader(String value) =>
        value.trim().replaceFirst(RegExp(r'^周'), '星期').replaceAll('星期天', '星期日');
    final headers = cells.map((r) => r.map(normalizeHeader).toList()).toList();
    final header = headers.indexWhere((r) => days.every(r.contains));
    if (header < 0) {
      throw const FormatException('Missing Monday–Sunday timetable header');
    }
    final columns = days.map(headers[header].indexOf).toList();
    if (days.any((day) => headers[header].where((v) => v == day).length != 1)) {
      throw const FormatException('Duplicate weekday column');
    }
    var indexColumn = headers[header].indexOf('节数');
    // The paired export has a blank top-left corner, not a period caption.
    if (indexColumn < 0 &&
        headers[header].first.isEmpty &&
        !columns.contains(0)) {
      indexColumn = 0;
    }
    if (indexColumn < 0) throw const FormatException('Missing period column');
    final records = <ImportRecord>[];
    var periodCount = 0;
    var previousPeriod = 0;
    for (var r = header + 1; r < cells.length; r++) {
      final row = cells[r];
      String cell(int c) => c < row.length ? row[c] : '';
      if (row.every((v) => v.trim().isEmpty)) continue;
      final period = _period(cell(indexColumn));
      if (period == null || period < previousPeriod) {
        throw FormatException('Unrecognized period at row ${r + 1}');
      }
      previousPeriod = period;
      if (period > periodCount) periodCount = period;
      // A detail row has no period label. Never treat an arbitrary unlabeled
      // row as a continuation: recognize every populated cell before consuming it.
      List<String>? details;
      if (r + 1 < cells.length) {
        final next = cells[r + 1];
        String below(int c) => c < next.length ? next[c] : '';
        if (below(indexColumn).trim().isEmpty &&
            next.any((v) => v.trim().isNotEmpty)) {
          for (var c = 0; c < next.length; c++) {
            if (next[c].trim().isEmpty) continue;
            if (!columns.contains(c) ||
                cell(c).trim().isEmpty ||
                (!RegExp(r'^\s*(备注\s*[:：]|考试)').hasMatch(next[c]) &&
                    !_isFormattedHeading(cell(c)))) {
              throw FormatException('Unrecognized detail at row ${r + 2}');
            }
          }
          details = next;
        }
      }
      for (var d = 0; d < 5; d++) {
        final raw = cell(columns[d]);
        if (raw.trim().isEmpty) continue;
        final detail = details != null && columns[d] < details.length
            ? details[columns[d]]
            : '';
        records.add(
          _parseOccurrence(
            'sheet:0/row:$r/column:${columns[d]}',
            raw,
            detail,
            d + 1,
            period,
          ),
        );
      }
      for (var c = 0; c < row.length; c++) {
        if (c != indexColumn &&
            !columns.contains(c) &&
            row[c].trim().isNotEmpty) {
          throw FormatException(
            'Unsupported content at row ${r + 1}, column ${c + 1}',
          );
        }
      }
      if (details != null) r++;
    }
    if (periodCount == 0) throw const FormatException('No timetable periods');
    // Keep every original occurrence, even repeated parents or occupied tutorial
    // destinations. Derived identities are tied to source locations, not titles.
    final tutorials = <ImportRecord>[];
    final seenTutorials = <(String, String)>{};
    final consumedTutorialNotes = <(String, String)>{};
    for (final record in records) {
      final meeting = record.meeting;
      if (meeting.note.contains('习题课') &&
          seenTutorials.add((meeting.name, meeting.note))) {
        final tutorial = _tutorial(record, periodCount);
        if (tutorial != null) {
          tutorials.add(tutorial);
          // A candidate cannot publish until this derived class is complete, so
          // its structured source remark must not also remain display content.
          consumedTutorialNotes.add((meeting.name, meeting.note));
        }
      }
    }
    final cleanedRecords = records.map((record) {
      final meeting = record.meeting;
      if (!consumedTutorialNotes.contains((meeting.name, meeting.note))) {
        return record;
      }
      return ImportRecord(
        meeting: _withNote(meeting, ''),
        raw: record.raw,
        issue: record.issue,
        failedFields: record.failedFields,
      );
    });
    return ScheduleCandidate(bytes, [
      ...cleanedRecords,
      ...tutorials,
    ], periodCount);
  }

  ImportRecord parseRecord(String id, String raw, int day, int period) {
    final text = raw.replaceAll('（', '(').replaceAll('）', ')');
    // Balanced groups keep nested remarks out of the primary frequency/exam.
    final groups = <({int start, int end, String text})>[];
    var depth = 0;
    var start = 0;
    var malformed = false;
    for (var i = 0; i < text.length; i++) {
      if (text[i] == '(') {
        if (depth++ == 0) start = i;
      } else if (text[i] == ')') {
        if (depth == 0) {
          malformed = true;
        } else if (--depth == 0) {
          groups.add((
            start: start,
            end: i + 1,
            text: text.substring(start + 1, i),
          ));
        }
      }
    }
    malformed = malformed || depth != 0;
    final notePrefix = RegExp(r'^\s*备注\s*[:：]\s*');
    // Qualifiers precede the room. Prefer the last group before an explicit
    // remark, otherwise consume adjacent title qualifiers and the room group.
    var roomIndex = -1;
    final remarkIndex = groups.indexWhere((g) => notePrefix.hasMatch(g.text));
    if (remarkIndex > 0) {
      roomIndex = remarkIndex - 1;
    } else if (remarkIndex < 0 && groups.isNotEmpty) {
      roomIndex = 0;
      while (roomIndex + 1 < groups.length &&
          groups[roomIndex].text.runes.length <= 1 &&
          text
              .substring(groups[roomIndex].end, groups[roomIndex + 1].start)
              .trim()
              .isEmpty) {
        roomIndex++;
      }
    }
    final roomGroup = roomIndex < 0 ? null : groups[roomIndex];
    final name = roomGroup == null
        ? text.trim()
        : text.substring(0, roomGroup.start).trim();
    final room = roomGroup?.text.trim() ?? '';
    final notes = <String>[];
    final outside = StringBuffer();
    if (roomGroup != null) {
      var cursor = roomGroup.end;
      for (final group in groups.skip(roomIndex + 1)) {
        outside.write(text.substring(cursor, group.start));
        final note = raw
            .substring(group.start + 1, group.end - 1)
            .replaceFirst(notePrefix, '')
            .trim();
        if (note.isNotEmpty) notes.add(note);
        cursor = group.end;
      }
      outside.write(text.substring(cursor));
    }
    final tail = outside.toString().trim();
    final examStart = tail.indexOf('考试');
    final sourceToken = (examStart < 0 ? tail : tail.substring(0, examStart))
        .trim();
    final token = const {'每周', '单周', '双周'}.contains(sourceToken)
        ? sourceToken
        : '每周';
    final failedFields = <ImportField>{
      if (malformed) ImportField.note,
      if (roomGroup == null || room.isEmpty || room.contains('暂无'))
        ImportField.room,
      if (name.isEmpty || (malformed && roomGroup == null)) ImportField.name,
    };
    return ImportRecord(
      meeting: Course(
        sourceId: id,
        name: name.isEmpty ? raw : name,
        weekday: day,
        firstPeriod: period,
        lastPeriod: period,
        room: room,
        frequency: WeekFrequency.parse(token),
        frequencyText: token,
        note: notes.join('；'),
        exam: examStart < 0 ? '' : tail.substring(examStart),
      ),
      raw: raw,
      issue: failedFields.isEmpty ? null : 'Complete the highlighted fields.',
      failedFields: failedFields,
    );
  }

  // Recognize both plain subtitles and the original formatter's (room, frequency).
  ({String name, String room, String frequency})? _formattedHeading(
    String raw,
  ) {
    final lines = raw.trim().split(RegExp(r'\r?\n'));
    if (lines.length != 2 || lines[0].trim().isEmpty) return null;
    final subtitle = lines[1].trim().replaceAll('（', '(').replaceAll('）', ')');
    final match =
        RegExp(r'^\((.+)[,，]\s*([^(),，]+)\)$').firstMatch(subtitle) ??
        RegExp(r'^(.+?)\s+(每周|单周|双周)$').firstMatch(subtitle);
    if (match == null) return null;
    return (
      name: lines[0].trim(),
      room: match[1]!.trim(),
      frequency: match[2]!.trim(),
    );
  }

  bool _isFormattedHeading(String raw) => _formattedHeading(raw) != null;

  ImportRecord _parseOccurrence(
    String id,
    String heading,
    String detail,
    int day,
    int period,
  ) {
    var input = heading;
    final formatted = _formattedHeading(heading);
    if (formatted != null) {
      final frequency = const {'每周', '单周', '双周'}.contains(formatted.frequency)
          ? formatted.frequency
          : '每周';
      input = '${formatted.name}(${formatted.room})$frequency';
    }
    final parsed = parseRecord(id, input, day, period);
    if (detail.isEmpty && input == heading) return parsed;
    final main = parsed.meeting;
    final examStart = detail.indexOf('考试');
    final note = (examStart < 0 ? detail : detail.substring(0, examStart))
        .replaceFirst(RegExp(r'^\s*备注\s*[:：]\s*'), '')
        .replaceFirst(RegExp(r'[；;\s]+$'), '')
        .trim();
    final exam = examStart < 0 ? '' : detail.substring(examStart).trim();
    return ImportRecord(
      meeting: Course(
        sourceId: main.sourceId,
        name: main.name,
        weekday: day,
        firstPeriod: period,
        lastPeriod: period,
        room: main.room,
        frequency: main.frequency,
        frequencyText: main.frequencyText,
        note: [main.note, note].where((s) => s.isNotEmpty).join('；'),
        exam: [main.exam, exam].where((s) => s.isNotEmpty).join('；'),
      ),
      raw: detail.isEmpty ? heading : '$heading\n$detail',
      issue: parsed.issue,
      failedFields: parsed.failedFields,
    );
  }

  ImportRecord? _tutorial(ImportRecord parent, int periodCount) {
    final main = parent.meeting;
    final note = main.note;
    // Match the entire note: alternatives/multiple schedules must be reviewed,
    // not truncated to the first plausible room or time.
    final frequencyMatch = RegExp(r'(每周|单周|双周)').firstMatch(note);
    final placementMatch = RegExp(
      r'(?:星期|周)([一二三四五六日天])\s*(\d{1,2})'
      r'(?:\s*[-－–—至~～]\s*(\d{1,2}))?\s*节?',
    ).firstMatch(note);
    final roomMatch = RegExp(r'(?:上课)?教室\s*[:：]\s*([^；;]+)').firstMatch(note);
    final first = int.tryParse(placementMatch?[2] ?? '');
    final last = int.tryParse(placementMatch?[3] ?? placementMatch?[2] ?? '');
    final room =
        roomMatch?[1]?.replaceAll(RegExp(r'[，,。\s]+$'), '').trim() ?? '';
    final day = placementMatch == null
        ? null
        : '一二三四五六日天'.indexOf(placementMatch[1]!) + 1;
    final validFirst = first != null && first >= 1 && first <= periodCount;
    final validLast =
        last != null && validFirst && last >= first && last <= periodCount;
    final failedFields = <ImportField>{
      if (frequencyMatch == null) ImportField.frequency,
      if (day == null || day > 5) ImportField.weekday,
      if (!validFirst) ImportField.firstPeriod,
      if (!validLast) ImportField.lastPeriod,
      if (room.isEmpty || RegExp(r'[、,，/\n]|或|待定|另行|习题课').hasMatch(room))
        ImportField.room,
    };
    final safeFirst = validFirst ? first : main.firstPeriod;
    final safeLast = validLast ? last : safeFirst;
    return ImportRecord(
      meeting: Course(
        sourceId: '${main.sourceId}/tutorial',
        name: '${main.name} 习题课',
        // Review placeholders are never published until the issue is completed.
        weekday: day != null && day <= 5 ? day : main.weekday,
        firstPeriod: safeFirst,
        lastPeriod: safeLast,
        room: room,
        frequency: WeekFrequency.parse(frequencyMatch?[1] ?? ''),
        frequencyText: frequencyMatch?[1] ?? '每周',
        note: '',
      ),
      raw: note,
      issue: failedFields.isEmpty ? null : 'Complete the highlighted fields.',
      failedFields: failedFields,
    );
  }

  Course _withNote(Course meeting, String note) => Course(
    sourceId: meeting.sourceId,
    sourceName: meeting.sourceName,
    name: meeting.name,
    weekday: meeting.weekday,
    firstPeriod: meeting.firstPeriod,
    lastPeriod: meeting.lastPeriod,
    room: meeting.room,
    frequency: meeting.frequency,
    frequencyText: meeting.frequencyText,
    note: note,
    exam: meeting.exam,
  );

  int? _period(String value) {
    final lines = value.trim().split(RegExp(r'\r?\n'));
    if (lines.length > 1) {
      if (lines.length != 2 ||
          !RegExp(r'^\s*\d{1,2}:\d{2}\s*[-－–—]\s*\d{1,2}:\d{2}\s*$')
              .hasMatch(lines[1])) {
        return null;
      }
      value = lines[0];
    }
    final numeric = int.tryParse(value.replaceAll(RegExp('[第节\\s]'), ''));
    if (numeric != null && numeric > 0 && numeric <= 53) return numeric;
    const chinese = [
      '一',
      '二',
      '三',
      '四',
      '五',
      '六',
      '七',
      '八',
      '九',
      '十',
      '十一',
      '十二',
      '十三',
      '十四',
      '十五',
      '十六',
      '十七',
      '十八',
      '十九',
      '二十',
    ];
    final i = chinese.indexOf(
      value.replaceAll('第', '').replaceAll('节', '').trim(),
    );
    return i < 0 ? null : i + 1;
  }
}
