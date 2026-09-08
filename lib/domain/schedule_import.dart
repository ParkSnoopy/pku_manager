import 'dart:typed_data';

import 'course.dart';
import 'timetable.dart';

final class ImportRecord {
  const ImportRecord({required this.meeting, required this.raw, this.issue});
  final Course meeting;
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
    Map<String, Course> completions,
  );
  Timetable saveMeeting(Course meeting);
  Timetable saveMeetings(Iterable<Course> meetings);
  Timetable removeUserMeeting(String sourceId);
  Timetable removeUserMeetings(Iterable<String> sourceIds);
}

abstract interface class ScheduleDecoder {
  ScheduleCandidate parse(Uint8List bytes);
}

abstract interface class SchedulePicker {
  Future<Uint8List?> pick();
}
