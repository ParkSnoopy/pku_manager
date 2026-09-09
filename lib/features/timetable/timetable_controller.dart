import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../domain/course.dart';
import '../../domain/schedule_import.dart';
import '../../domain/timetable.dart';

import '../../domain/week_source.dart';

class TimetableController extends ChangeNotifier {
  TimetableController({
    required this.schedules,
    required this.decoder,
    required this.picker,
    required this.weeks,
    DateTime Function()? clock,
  }) : clock = clock ?? DateTime.now;
  final ScheduleStore schedules;
  final ScheduleDecoder decoder;
  final SchedulePicker picker;
  final WeekSource weeks;
  final DateTime Function() clock;
  Timetable? timetable;
  ScheduleCandidate? candidate;
  WeekStatus week = const WeekStatus(null, WeekFreshness.unavailable);

  bool importing = false;
  bool refreshing = false;
  String? error;
  bool _disposed = false;
  Timer? _timer;

  void start() {
    _timer?.cancel();
    try {
      timetable = schedules.load();
    } catch (_) {
      error = 'Timetable could not be loaded.';
    }
    week = weeks.cached();
    _timer = Timer.periodic(const Duration(minutes: 1), (_) => _notify());
    _notify();
    unawaited(refresh());
  }

  Future<void> refresh() async {
    if (refreshing || _disposed) return;
    refreshing = true;
    _notify();
    try {
      week = await weeks.refresh();
    } catch (_) {
      week = WeekStatus(
        week.calendar,
        week.calendar == null ? WeekFreshness.unavailable : WeekFreshness.stale,
        message: 'Week refresh failed.',
      );
    } finally {
      refreshing = false;
      _notify();
    }
  }

  Future<void> import() async {
    if (importing || candidate != null || _disposed) return;
    importing = true;
    error = null;
    _notify();
    var selecting = true;
    try {
      final bytes = await picker.pick();
      if (bytes == null || _disposed) return;
      selecting = false;
      candidate = decoder.parse(bytes);
      if (candidate!.issues.isEmpty) complete({});
    } catch (_) {
      candidate = null;
      error = selecting
          ? 'The selected file could not be read.'
          : 'This file is not a supported timetable.';
    } finally {
      importing = false;
      _notify();
    }
  }

  void complete(Map<String, Course> values) {
    final current = candidate;
    if (current == null || _disposed) return;
    try {
      timetable = schedules.publish(current, values);
      candidate = null;
      error = null;
    } catch (_) {
      error =
          'Import could not be applied. Check required fields and try again.';
    }
    _notify();
  }

  void reject() {
    candidate = null;
    error = null;
    _notify();
  }

  void saveMeeting(Course meeting) {
    saveMeetings([meeting]);
  }

  void saveMeetings(Iterable<Course> meetings) {
    try {
      timetable = schedules.saveMeetings(meetings);
      error = null;
    } catch (_) {
      error = 'Course changes could not be applied.';
    }
    _notify();
  }

  bool removeMeeting(String sourceId) {
    return removeMeetings([sourceId]);
  }

  bool removeMeetings(Iterable<String> sourceIds) {
    try {
      timetable = schedules.removeMeetings(sourceIds);
      error = null;
      _notify();
      return true;
    } catch (_) {
      error = 'Course could not be removed.';
      _notify();
      return false;
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    super.dispose();
  }
}
