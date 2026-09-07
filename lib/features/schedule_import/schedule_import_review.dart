import 'package:flutter/material.dart';

import '../../domain/course_meeting.dart';
import '../../domain/schedule_import.dart';
import '../../domain/week_frequency.dart';
import '../timetable/timetable_controller.dart';

class ScheduleImportReview extends StatefulWidget {
  const ScheduleImportReview({
    super.key,
    required this.candidate,
    required this.controller,
  });
  final ScheduleCandidate candidate;
  final TimetableController controller;
  @override
  State<ScheduleImportReview> createState() => _ScheduleImportReviewState();
}

enum _Field {
  name('Course'),
  room('Room'),
  weekday('Weekday'),
  first('First period'),
  last('Last period'),
  frequency('Frequency'),
  note('Notes'),
  exam('Exam');

  const _Field(this.label);
  final String label;
  String value(CourseMeeting m) => switch (this) {
    name => m.name,
    room => m.room,
    weekday => '${m.weekday}',
    first => '${m.firstPeriod}',
    last => '${m.lastPeriod}',
    frequency => m.frequencyText,
    note => m.note,
    exam => m.exam,
  };
}

class _ScheduleImportReviewState extends State<ScheduleImportReview> {
  final _form = GlobalKey<FormState>();
  late final Map<String, Map<_Field, TextEditingController>> _fields = {
    for (final r in widget.candidate.issues)
      r.meeting.sourceId: {
        for (final field in _Field.values)
          field: TextEditingController(text: field.value(r.meeting)),
      },
  };
  @override
  void dispose() {
    for (final fields in _fields.values) {
      for (final controller in fields.values) {
        controller.dispose();
      }
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Form(
    key: _form,
    child: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Complete information',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const Text(
          'Original workbook stays unchanged. Complete every required field or reject this import.',
        ),
        for (final r in widget.candidate.issues) ...[
          const Divider(height: 32),
          SelectableText(r.raw),
          Text(r.issue!),
          for (final field in _Field.values)
            TextFormField(
              controller: _fields[r.meeting.sourceId]![field],
              decoration: InputDecoration(labelText: field.label),
              validator: (v) {
                if (field == _Field.name || field == _Field.room) {
                  return v == null || v.trim().isEmpty ? 'Required' : null;
                }
                if (field == _Field.weekday ||
                    field == _Field.first ||
                    field == _Field.last) {
                  final number = int.tryParse(v ?? '');
                  final maximum = field == _Field.weekday
                      ? 7
                      : widget.candidate.periodCount;
                  if (number == null || number < 1 || number > maximum) {
                    return 'Enter 1–$maximum';
                  }
                  if (field == _Field.last &&
                      number <
                          (int.tryParse(
                                _fields[r.meeting.sourceId]![_Field.first]!
                                    .text,
                              ) ??
                              1)) {
                    return 'Must not precede first period';
                  }
                }
                return null;
              },
            ),
        ],
        const SizedBox(height: 24),
        Wrap(
          spacing: 12,
          children: [
            TextButton(
              onPressed: widget.controller.reject,
              child: const Text('Reject and ignore'),
            ),
            FilledButton(
              onPressed: () {
                if (!_form.currentState!.validate()) return;
                widget.controller.complete({
                  for (final r in widget.candidate.issues)
                    r.meeting.sourceId: CourseMeeting(
                      sourceId: r.meeting.sourceId,
                      name: _fields[r.meeting.sourceId]![_Field.name]!.text,
                      room: _fields[r.meeting.sourceId]![_Field.room]!.text,
                      weekday: int.parse(
                        _fields[r.meeting.sourceId]![_Field.weekday]!.text,
                      ),
                      firstPeriod: int.parse(
                        _fields[r.meeting.sourceId]![_Field.first]!.text,
                      ),
                      lastPeriod: int.parse(
                        _fields[r.meeting.sourceId]![_Field.last]!.text,
                      ),
                      frequency: WeekFrequency.parse(
                        _fields[r.meeting.sourceId]![_Field.frequency]!.text,
                      ),
                      frequencyText:
                          _fields[r.meeting.sourceId]![_Field.frequency]!.text,
                      note: _fields[r.meeting.sourceId]![_Field.note]!.text,
                      exam: _fields[r.meeting.sourceId]![_Field.exam]!.text,
                    ),
                });
              },
              child: const Text('Import'),
            ),
          ],
        ),
      ],
    ),
  );
}
