import '../domain/calendar_schedule.dart';
import 'app_database.dart';

final class CalendarScheduleRepository implements CalendarScheduleStore {
  CalendarScheduleRepository(this.store);

  final AppDatabase store;

  @override
  List<CalendarSchedule> load() => List.unmodifiable(
    store.database
        .select(
          'SELECT id, title, starts_at FROM calendar_schedules ORDER BY starts_at, id',
        )
        .map(_fromRow),
  );

  @override
  CalendarSchedule create({required String title, required DateTime startsAt}) {
    final normalizedTitle = _validTitle(title);
    final normalizedStart = startsAt.toUtc();
    store.database.execute(
      'INSERT INTO calendar_schedules(title, starts_at) VALUES (?, ?)',
      [normalizedTitle, normalizedStart.millisecondsSinceEpoch],
    );
    return CalendarSchedule(
      id: store.database.lastInsertRowId,
      title: normalizedTitle,
      startsAt: normalizedStart,
    );
  }

  @override
  void update(CalendarSchedule schedule) {
    final normalizedTitle = _validTitle(schedule.title);
    store.database.execute(
      'UPDATE calendar_schedules SET title = ?, starts_at = ? WHERE id = ?',
      [
        normalizedTitle,
        schedule.startsAt.toUtc().millisecondsSinceEpoch,
        schedule.id,
      ],
    );
    if (store.database.updatedRows != 1) {
      throw ArgumentError('Schedule does not exist');
    }
  }

  @override
  void remove(int id) {
    store.database.execute('DELETE FROM calendar_schedules WHERE id = ?', [id]);
    if (store.database.updatedRows != 1) {
      throw ArgumentError('Schedule does not exist');
    }
  }

  CalendarSchedule _fromRow(dynamic row) => CalendarSchedule(
    id: row['id'] as int,
    title: row['title'] as String,
    startsAt: DateTime.fromMillisecondsSinceEpoch(
      row['starts_at'] as int,
      isUtc: true,
    ),
  );

  String _validTitle(String value) {
    final normalized = value.trim();
    if (normalized.isEmpty) {
      throw const FormatException('Schedule title is required');
    }
    return normalized;
  }
}
