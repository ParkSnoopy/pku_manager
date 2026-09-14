final class CalendarSchedule {
  const CalendarSchedule({
    required this.id,
    required this.title,
    required this.startsAt,
    this.allDay = true,
    this.relatedClassSourceId,
    this.note = '',
    this.colorValue,
  });

  final int id;
  final String title;
  final DateTime startsAt;
  final bool allDay;
  final String? relatedClassSourceId;
  final String note;
  final int? colorValue;

  CalendarSchedule copyWith({
    String? title,
    DateTime? startsAt,
    bool? allDay,
    Object? relatedClassSourceId = _unchanged,
    String? note,
    Object? colorValue = _unchanged,
  }) => CalendarSchedule(
    id: id,
    title: title ?? this.title,
    startsAt: startsAt ?? this.startsAt,
    allDay: allDay ?? this.allDay,
    relatedClassSourceId: identical(relatedClassSourceId, _unchanged)
        ? this.relatedClassSourceId
        : relatedClassSourceId as String?,
    note: note ?? this.note,
    colorValue: identical(colorValue, _unchanged)
        ? this.colorValue
        : colorValue as int?,
  );
}

const _unchanged = Object();

DateTime normalizedScheduleStart(DateTime startsAt, bool allDay) {
  final value = startsAt.toUtc();
  if (!allDay) return value;
  final beijing = value.add(const Duration(hours: 8));
  return DateTime.utc(
    beijing.year,
    beijing.month,
    beijing.day,
    23,
    59,
  ).subtract(const Duration(hours: 8));
}

abstract interface class CalendarScheduleStore {
  List<CalendarSchedule> load();

  CalendarSchedule create({
    required String title,
    required DateTime startsAt,
    bool allDay = true,
    String? relatedClassSourceId,
    String note = '',
    int? colorValue,
  });

  void update(CalendarSchedule schedule);

  void remove(int id);
}
