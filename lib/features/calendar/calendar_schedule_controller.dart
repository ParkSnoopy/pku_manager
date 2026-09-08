import 'package:flutter/foundation.dart';

import '../../domain/calendar_schedule.dart';

final class CalendarScheduleController extends ChangeNotifier {
  CalendarScheduleController(this.store) {
    reload();
  }

  final CalendarScheduleStore store;
  List<CalendarSchedule> _schedules = const [];

  List<CalendarSchedule> get schedules => _schedules;

  void reload() {
    _schedules = store.load();
    notifyListeners();
  }

  void create({required String title, required DateTime startsAt}) {
    store.create(title: title, startsAt: startsAt);
    reload();
  }

  void update(CalendarSchedule schedule) {
    store.update(schedule);
    reload();
  }

  void remove(int id) {
    store.remove(id);
    reload();
  }
}

final class MemoryCalendarScheduleStore implements CalendarScheduleStore {
  final List<CalendarSchedule> _schedules = [];
  int _nextId = 1;

  @override
  List<CalendarSchedule> load() => List.unmodifiable(
    [..._schedules]..sort((a, b) {
      final byTime = a.startsAt.compareTo(b.startsAt);
      return byTime != 0 ? byTime : a.id.compareTo(b.id);
    }),
  );

  @override
  CalendarSchedule create({required String title, required DateTime startsAt}) {
    final normalized = title.trim();
    if (normalized.isEmpty) {
      throw const FormatException('Schedule title is required');
    }
    final schedule = CalendarSchedule(
      id: _nextId++,
      title: normalized,
      startsAt: startsAt.toUtc(),
    );
    _schedules.add(schedule);
    return schedule;
  }

  @override
  void update(CalendarSchedule schedule) {
    final index = _schedules.indexWhere((item) => item.id == schedule.id);
    if (index < 0) {
      throw ArgumentError('Schedule does not exist');
    }
    final normalized = schedule.title.trim();
    if (normalized.isEmpty) {
      throw const FormatException('Schedule title is required');
    }
    _schedules[index] = schedule.copyWith(
      title: normalized,
      startsAt: schedule.startsAt.toUtc(),
    );
  }

  @override
  void remove(int id) {
    final before = _schedules.length;
    _schedules.removeWhere((schedule) => schedule.id == id);
    if (_schedules.length == before) {
      throw ArgumentError('Schedule does not exist');
    }
  }
}
