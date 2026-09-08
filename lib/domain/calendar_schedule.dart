final class CalendarSchedule {
  const CalendarSchedule({
    required this.id,
    required this.title,
    required this.startsAt,
    this.allDay = true,
    this.relatedClassSourceId,
    this.note = '',
    this.colorValue = 0xffffd6a5,
  });

  final int id;
  final String title;
  final DateTime startsAt;
  final bool allDay;
  final String? relatedClassSourceId;
  final String note;
  final int colorValue;

  CalendarSchedule copyWith({
    String? title,
    DateTime? startsAt,
    bool? allDay,
    Object? relatedClassSourceId = _unchanged,
    String? note,
    int? colorValue,
  }) => CalendarSchedule(
    id: id,
    title: title ?? this.title,
    startsAt: startsAt ?? this.startsAt,
    allDay: allDay ?? this.allDay,
    relatedClassSourceId: identical(relatedClassSourceId, _unchanged)
        ? this.relatedClassSourceId
        : relatedClassSourceId as String?,
    note: note ?? this.note,
    colorValue: colorValue ?? this.colorValue,
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
    String note = '',
    int colorValue = 0xffffd6a5,
  });

  void update(CalendarSchedule schedule);

  void remove(int id);
}
