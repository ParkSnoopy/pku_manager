final class CalendarSchedule {
  const CalendarSchedule({
    required this.id,
    required this.title,
    required this.startsAt,
  });

  final int id;
  final String title;
  final DateTime startsAt;

  CalendarSchedule copyWith({String? title, DateTime? startsAt}) =>
      CalendarSchedule(
        id: id,
        title: title ?? this.title,
        startsAt: startsAt ?? this.startsAt,
      );
}

abstract interface class CalendarScheduleStore {
  List<CalendarSchedule> load();

  CalendarSchedule create({required String title, required DateTime startsAt});

  void update(CalendarSchedule schedule);

  void remove(int id);
}
