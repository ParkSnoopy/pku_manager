import '../domain/calendar_schedule.dart';
import 'app_database.dart';

final class CalendarScheduleRepository implements CalendarScheduleStore {
  CalendarScheduleRepository(this.store);

  final AppDatabase store;

  @override
  List<CalendarSchedule> load() => List.unmodifiable(
    store.database
        .select(
          '''SELECT id, title, starts_at, all_day, related_class_source_id,
note, color
FROM calendar_schedules ORDER BY starts_at, id''',
        )
        .map(_fromRow),
  );

  @override
  CalendarSchedule create({
    required String title,
    required DateTime startsAt,
    bool allDay = true,
    String? relatedClassSourceId,
    String note = '',
    int? colorValue,
  }) {
    final normalizedTitle = _validTitle(title);
    final normalizedStart = normalizedScheduleStart(startsAt, allDay);
    store.database.execute(
      '''INSERT INTO calendar_schedules(
title, starts_at, all_day, related_class_source_id, note, color)
VALUES (?, ?, ?, ?, ?, ?)''',
      [
        normalizedTitle,
        normalizedStart.millisecondsSinceEpoch,
        allDay ? 1 : 0,
        relatedClassSourceId,
        note,
        colorValue ?? 0,
      ],
    );
    return CalendarSchedule(
      id: store.database.lastInsertRowId,
      title: normalizedTitle,
      startsAt: normalizedStart,
      allDay: allDay,
      relatedClassSourceId: relatedClassSourceId,
      note: note,
      colorValue: colorValue,
    );
  }

  @override
  void update(CalendarSchedule schedule) {
    final normalizedTitle = _validTitle(schedule.title);
    store.database.execute(
      '''UPDATE calendar_schedules SET title = ?, starts_at = ?, all_day = ?,
related_class_source_id = ?, note = ?, color = ? WHERE id = ?''',
      [
        normalizedTitle,
        normalizedScheduleStart(
          schedule.startsAt,
          schedule.allDay,
        ).millisecondsSinceEpoch,
        schedule.allDay ? 1 : 0,
        schedule.relatedClassSourceId,
        schedule.note,
        schedule.colorValue ?? 0,
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

  CalendarSchedule _fromRow(dynamic row) {
    final color = row['color'] as int?;
    return CalendarSchedule(
      id: row['id'] as int,
      title: row['title'] as String,
      startsAt: DateTime.fromMillisecondsSinceEpoch(
        row['starts_at'] as int,
        isUtc: true,
      ),
      allDay: (row['all_day'] as int) != 0,
      relatedClassSourceId: row['related_class_source_id'] as String?,
      note: row['note'] as String,
      colorValue: color == null || color == 0 ? null : color,
    );
  }

  String _validTitle(String value) {
    final normalized = value.trim();
    if (normalized.isEmpty) {
      throw const FormatException('Schedule title is required');
    }
    return normalized;
  }
}
