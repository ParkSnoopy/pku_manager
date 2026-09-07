import '../domain/course_meeting.dart';
import '../domain/schedule_import.dart';
import '../domain/timetable.dart';
import '../domain/week_frequency.dart';
import 'app_database.dart';

class ScheduleRepository implements ScheduleStore {
  ScheduleRepository(this.store);
  final AppDatabase store;

  @override
  Timetable? load() {
    if (store.activeSource == null) return null;
    final rows = store.database.select('''
SELECT m.*, c.name AS completed_name, c.room AS completed_room,
c.frequency AS completed_frequency, c.weekday AS completed_weekday,
c.first_period AS completed_first, c.last_period AS completed_last,
c.note AS completed_note, c.exam AS completed_exam FROM meetings m
JOIN active_schedule a ON a.source = m.source
LEFT JOIN completions c ON c.source = m.source AND c.identity = m.identity
WHERE m.weekday BETWEEN 1 AND 5
ORDER BY m.rowid''');
    final userRows = store.database.select('''
SELECT u.* FROM user_meetings u
JOIN active_schedule a ON a.source = u.source
ORDER BY u.rowid''');
    final periods =
        store.database
                .select(
                  'SELECT period_count FROM sources JOIN active_schedule ON sources.id = active_schedule.source',
                )
                .first['period_count']
            as int;
    return Timetable([
      ...rows.map((r) {
        final token = _frequencyText(
          (r['completed_frequency'] ?? r['frequency']) as String,
        );
        return CourseMeeting(
          sourceId: r['identity'] as String,
          name: (r['completed_name'] ?? r['name']) as String,
          weekday: (r['completed_weekday'] ?? r['weekday']) as int,
          firstPeriod: (r['completed_first'] ?? r['first_period']) as int,
          lastPeriod: (r['completed_last'] ?? r['last_period']) as int,
          room: (r['completed_room'] ?? r['room']) as String,
          frequency: WeekFrequency.parse(token),
          frequencyText: token,
          note: (r['completed_note'] ?? r['note']) as String,
          exam: (r['completed_exam'] ?? r['exam']) as String,
        );
      }),
      ...userRows.map(
        (r) => CourseMeeting(
          sourceId: r['identity'] as String,
          name: r['name'] as String,
          weekday: r['weekday'] as int,
          firstPeriod: r['first_period'] as int,
          lastPeriod: r['last_period'] as int,
          room: r['room'] as String,
          frequency: WeekFrequency.parse(r['frequency'] as String),
          frequencyText: _frequencyText(r['frequency'] as String),
          note: r['note'] as String,
          exam: r['exam'] as String,
        ),
      ),
    ], periodCount: periods);
  }

  @override
  Timetable publish(
    ScheduleCandidate candidate,
    Map<String, CourseMeeting> completions,
  ) {
    final identities = candidate.issues.map((r) => r.meeting.sourceId).toSet();
    if (completions.keys.any((k) => !identities.contains(k))) {
      throw ArgumentError('Completion does not belong to this candidate');
    }
    for (final record in candidate.issues) {
      final completed = completions[record.meeting.sourceId];
      if (completed == null ||
          completed.name.trim().isEmpty ||
          completed.room.trim().isEmpty ||
          completed.sourceId != record.meeting.sourceId ||
          completed.lastPeriod > candidate.periodCount ||
          completed.frequency != WeekFrequency.parse(completed.frequencyText)) {
        throw const FormatException(
          'Complete every required field before import',
        );
      }
    }
    Timetable(
      candidate.records.map(
        (r) => completions[r.meeting.sourceId] ?? r.meeting,
      ),
      periodCount: candidate.periodCount,
    );
    return store.transaction(() {
      final db = store.database;
      db.execute('INSERT INTO sources(bytes, period_count) VALUES (?, ?)', [
        candidate.bytes,
        candidate.periodCount,
      ]);
      final source = db.lastInsertRowId;
      for (final r in candidate.records) {
        final m = r.meeting;
        db.execute(
          'INSERT INTO meetings VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
          [
            source,
            m.sourceId,
            m.name,
            m.weekday,
            m.firstPeriod,
            m.lastPeriod,
            m.room,
            _frequencyText(m.frequencyText),
            m.note,
            m.exam,
            r.raw,
          ],
        );
        if (r.issue != null) {
          db.execute('INSERT INTO issues VALUES (?, ?, ?)', [
            source,
            m.sourceId,
            r.issue,
          ]);
        }
        final c = completions[m.sourceId];
        if (c != null) {
          db.execute(
            'INSERT INTO completions VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
            [
              source,
              m.sourceId,
              c.name,
              c.room,
              _frequencyText(c.frequencyText),
              c.weekday,
              c.firstPeriod,
              c.lastPeriod,
              c.note,
              c.exam,
            ],
          );
        }
      }
      db.execute(
        'INSERT INTO active_schedule VALUES (1, ?) ON CONFLICT(id) DO UPDATE SET source=excluded.source',
        [source],
      );
      return load()!;
    });
  }

  @override
  Timetable saveMeeting(CourseMeeting meeting) {
    return store.transaction(() {
      final source = _activeSourceId();
      final values = [
        source,
        meeting.sourceId,
        meeting.name,
        meeting.weekday,
        meeting.firstPeriod,
        meeting.lastPeriod,
        meeting.room,
        _frequencyText(meeting.frequencyText),
        meeting.note,
        meeting.exam,
      ];
      if (meeting.sourceId.startsWith('user:')) {
        store.database.execute(
          '''INSERT INTO user_meetings VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
ON CONFLICT(source, identity) DO UPDATE SET name=excluded.name,
weekday=excluded.weekday, first_period=excluded.first_period,
last_period=excluded.last_period, room=excluded.room,
frequency=excluded.frequency, note=excluded.note, exam=excluded.exam''',
          values,
        );
      } else {
        final exists = store.database.select(
          'SELECT 1 FROM meetings WHERE source = ? AND identity = ?',
          [source, meeting.sourceId],
        );
        if (exists.isEmpty) {
          throw ArgumentError('Meeting does not belong to active schedule');
        }
        store.database.execute(
          '''INSERT INTO completions(source, identity, name, room, frequency,
weekday, first_period, last_period, note, exam) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
ON CONFLICT(source, identity) DO UPDATE SET name=excluded.name,
room=excluded.room, frequency=excluded.frequency, weekday=excluded.weekday,
first_period=excluded.first_period, last_period=excluded.last_period,
note=excluded.note, exam=excluded.exam''',
          [
            source,
            meeting.sourceId,
            meeting.name,
            meeting.room,
            _frequencyText(meeting.frequencyText),
            meeting.weekday,
            meeting.firstPeriod,
            meeting.lastPeriod,
            meeting.note,
            meeting.exam,
          ],
        );
      }
      return load()!;
    });
  }

  @override
  Timetable removeUserMeeting(String sourceId) {
    if (!sourceId.startsWith('user:')) {
      throw ArgumentError('Only user-created meetings can be removed');
    }
    return store.transaction(() {
      store.database.execute(
        'DELETE FROM user_meetings WHERE source = ? AND identity = ?',
        [_activeSourceId(), sourceId],
      );
      return load()!;
    });
  }

  int _activeSourceId() {
    final rows = store.database.select(
      'SELECT source FROM active_schedule WHERE id = 1',
    );
    if (rows.isEmpty) throw StateError('No active schedule');
    return rows.single['source'] as int;
  }
}

String _frequencyText(String value) =>
    const {'每周', '单周', '双周'}.contains(value) ? value : '每周';
