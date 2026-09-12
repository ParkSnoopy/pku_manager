import 'semester.dart';

enum WeekFreshness { fresh, cached, stale, unavailable }

final class WeekStatus {
  const WeekStatus(this.calendar, this.freshness, {this.message});
  final SemesterCalendar? calendar;
  final WeekFreshness freshness;
  final String? message;
}

abstract interface class WeekSource {
  WeekStatus cached();
  Future<WeekStatus> refresh();
}
