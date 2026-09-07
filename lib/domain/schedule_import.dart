import 'dart:typed_data';

import 'course_meeting.dart';
import 'timetable.dart';

final class ImportRecord {
  const ImportRecord({required this.meeting, required this.raw, this.issue});
  final CourseMeeting meeting;
  final String raw;
  final String? issue;
}

final class ScheduleCandidate {
  ScheduleCandidate(
    Uint8List bytes,
    Iterable<ImportRecord> records,
    this.periodCount,
  ) : bytes = Uint8List.fromList(bytes).asUnmodifiableView(),
      records = List.unmodifiable(records);
  final Uint8List bytes;
  final List<ImportRecord> records;
  final int periodCount;
  List<ImportRecord> get issues =>
      records.where((r) => r.issue != null).toList();
}

abstract interface class ScheduleStore {
  Timetable? load();
  Timetable publish(
    ScheduleCandidate candidate,
    Map<String, CourseMeeting> completions,
  );
  Timetable saveMeeting(CourseMeeting meeting);
  Timetable removeUserMeeting(String sourceId);
}

abstract interface class ScheduleDecoder {
  ScheduleCandidate parse(Uint8List bytes);
}

abstract interface class SchedulePicker {
  Future<Uint8List?> pick();
}
