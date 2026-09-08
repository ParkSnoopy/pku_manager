import 'package:flutter/material.dart';

import '../../domain/course_meeting.dart';
import '../../domain/schedule_import.dart';
import '../../domain/week_frequency.dart';
import '../../l10n/app_strings.dart';
import '../timetable/timetable_controller.dart';

enum _Field { name, room, weekday, first, last, frequency, note, exam }

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

class _ScheduleImportReviewState extends State<ScheduleImportReview> {
  final _form = GlobalKey<FormState>();
  var _index = 0;
  late final Map<String, Map<_Field, TextEditingController>> _fields = {
    for (final record in widget.candidate.issues)
      record.meeting.sourceId: {
        for (final field in _Field.values)
          field: TextEditingController(text: _value(field, record.meeting)),
      },
  };

  ImportRecord get _record => widget.candidate.issues[_index];
  Map<_Field, TextEditingController> get _current =>
      _fields[_record.meeting.sourceId]!;

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
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final tutorialRooms = _record.meeting.name.contains('习题课')
        ? _roomChoices(_current[_Field.room]!.text)
        : const <String>[];
    return ColoredBox(
      color: Colors.black26,
      child: Center(
        child: Material(
          elevation: 12,
          color: Theme.of(context).colorScheme.surface,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720, maxHeight: 720),
            child: Form(
              key: _form,
              child: ListView(
                padding: const EdgeInsets.all(28),
                children: [
                  Text(
                    strings.text(AppText.completeInformation),
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  Text('${_index + 1} / ${widget.candidate.issues.length}'),
                  const Divider(height: 32),
                  SelectableText(_record.raw),
                  const SizedBox(height: 8),
                  Text(_record.issue!),
                  const SizedBox(height: 16),
                  for (final field in _Field.values) ...[
                    if (field == _Field.room && tutorialRooms.length > 1) ...[
                      Text(strings.text(AppText.chooseTutorialRoom)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: [
                          for (final room in tutorialRooms)
                            ChoiceChip(
                              label: Text(room),
                              selected: _current[_Field.room]!.text == room,
                              onSelected: (_) => setState(
                                () => _current[_Field.room]!.text = room,
                              ),
                            ),
                        ],
                      ),
                    ],
                    TextFormField(
                      controller: _current[field],
                      decoration: InputDecoration(
                        labelText: _label(strings, field),
                      ),
                      validator: (value) => _validate(strings, field, value),
                    ),
                  ],
                  const SizedBox(height: 24),
                  Wrap(
                    alignment: WrapAlignment.end,
                    spacing: 12,
                    children: [
                      TextButton(
                        onPressed: widget.controller.reject,
                        child: Text(strings.text(AppText.rejectIgnore)),
                      ),
                      if (_index > 0)
                        TextButton(
                          onPressed: () => setState(() => _index--),
                          child: Text(strings.text(AppText.back)),
                        ),
                      FilledButton(
                        onPressed: _advance,
                        child: Text(
                          strings.text(
                            _index + 1 == widget.candidate.issues.length
                                ? AppText.finish
                                : AppText.next,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _advance() {
    if (!_form.currentState!.validate()) return;
    if (_index + 1 < widget.candidate.issues.length) {
      setState(() => _index++);
      return;
    }
    widget.controller.complete({
      for (final record in widget.candidate.issues)
        record.meeting.sourceId: _meeting(
          record,
          _fields[record.meeting.sourceId]!,
        ),
    });
  }

  CourseMeeting _meeting(
    ImportRecord record,
    Map<_Field, TextEditingController> fields,
  ) {
    final frequencyText = fields[_Field.frequency]!.text;
    return CourseMeeting(
      sourceId: record.meeting.sourceId,
      name: fields[_Field.name]!.text.trim(),
      room: fields[_Field.room]!.text.trim(),
      weekday: int.parse(fields[_Field.weekday]!.text),
      firstPeriod: int.parse(fields[_Field.first]!.text),
      lastPeriod: int.parse(fields[_Field.last]!.text),
      frequency: WeekFrequency.parse(frequencyText),
      frequencyText: frequencyText,
      note: fields[_Field.note]!.text,
      exam: fields[_Field.exam]!.text,
    );
  }

  String? _validate(AppStrings strings, _Field field, String? value) {
    if (field == _Field.name || field == _Field.room) {
      if (value == null || value.trim().isEmpty) {
        return strings.text(AppText.required);
      }
    }
    if (field == _Field.weekday ||
        field == _Field.first ||
        field == _Field.last) {
      final number = int.tryParse(value ?? '');
      final maximum = field == _Field.weekday
          ? 5
          : widget.candidate.periodCount;
      if (number == null || number < 1 || number > maximum) {
        return '${strings.text(AppText.enterRange)}: 1–$maximum';
      }
      if (field == _Field.last &&
          number < (int.tryParse(_current[_Field.first]!.text) ?? 1)) {
        return strings.text(AppText.lastBeforeFirst);
      }
    }
    return null;
  }

  static String _value(_Field field, CourseMeeting meeting) => switch (field) {
    _Field.name => meeting.name,
    _Field.room => meeting.room,
    _Field.weekday => '${meeting.weekday}',
    _Field.first => '${meeting.firstPeriod}',
    _Field.last => '${meeting.lastPeriod}',
    _Field.frequency => meeting.frequencyText,
    _Field.note => meeting.note,
    _Field.exam => meeting.exam,
  };

  static String _label(AppStrings strings, _Field field) =>
      strings.text(switch (field) {
        _Field.name => AppText.course,
        _Field.room => AppText.room,
        _Field.weekday => AppText.weekday,
        _Field.first => AppText.firstPeriod,
        _Field.last => AppText.lastPeriod,
        _Field.frequency => AppText.frequency,
        _Field.note => AppText.notes,
        _Field.exam => AppText.exam,
      });

  static List<String> _roomChoices(String value) => value
      .split(RegExp(r'[、,，;；/]'))
      .map((room) => room.trim())
      .where((room) => room.isNotEmpty)
      .toSet()
      .toList();
}
