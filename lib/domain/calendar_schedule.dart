final class CalendarSchedule {
  const CalendarSchedule({
    required this.id,
    required this.title,
    required this.startsAt,
    this.allDay = true,
    this.relatedClassSourceId,
  });

  final int id;
  final String title;
  final DateTime startsAt;
  final bool allDay;
  final String? relatedClassSourceId;

  CalendarSchedule copyWith({
    String? title,
    DateTime? startsAt,
    bool? allDay,
    Object? relatedClassSourceId = _unchanged,
  }) => CalendarSchedule(
    id: id,
    title: title ?? this.title,
    startsAt: startsAt ?? this.startsAt,
    allDay: allDay ?? this.allDay,
    relatedClassSourceId: identical(relatedClassSourceId, _unchanged)
        ? this.relatedClassSourceId
        : relatedClassSourceId as String?,
  );
}

const _unchanged = Object();

abstract interface class CalendarScheduleStore {
  List<CalendarSchedule> load();

  CalendarSchedule create({
    required String title,
    required DateTime startsAt,
    bool allDay = true,
    String? relatedClassSourceId,
  });

  void update(CalendarSchedule schedule);

  void remove(int id);
}
