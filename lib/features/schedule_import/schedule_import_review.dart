import 'package:flutter/material.dart';

import '../../domain/course.dart';
import '../../domain/schedule_import.dart';
import '../../domain/week_frequency.dart';
import '../../l10n/app_strings.dart';
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

class _ScheduleImportReviewState extends State<ScheduleImportReview> {
  final _form = GlobalKey<FormState>();
  var _index = 0;
  late final List<List<ImportRecord>> _groups = _groupIssues(
    widget.candidate.issues,
  );
  late final Map<String, Map<ImportField, TextEditingController>> _fields = {
    for (final group in _groups)
      group.first.meeting.sourceId: {
        for (final field in ImportField.values)
          field: TextEditingController(text: _groupValue(group, field)),
      },
  };

  List<ImportRecord> get _group => _groups[_index];
  ImportRecord get _record => _group.first;
  Map<ImportField, TextEditingController> get _current =>
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
    final failedFields = _group
        .expand(
          (record) => record.failedFields.isEmpty
              ? ImportField.values
              : record.failedFields,
        )
        .toSet();
    final tutorialRooms = _record.meeting.sourceId.endsWith('/tutorial')
        ? _roomChoices(_current[ImportField.room]!.text)
        : const <String>[];
    final classroomChoice =
        failedFields.length == 1 &&
        failedFields.contains(ImportField.room) &&
        tutorialRooms.length > 1;
    return ColoredBox(
      color: Colors.black26,
      child: Center(
        child: Material(
          elevation: 12,
          color: Theme.of(context).colorScheme.surface,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560, maxHeight: 720),
            child: Form(
              key: _form,
              child: ListView(
                padding: const EdgeInsets.all(28),
                children: [
                  Text(
                    strings.text(
                      classroomChoice
                          ? AppText.chooseTutorialRoom
                          : AppText.completeInformation,
                    ),
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  if (classroomChoice)
                    Text(
                      '${_record.meeting.name} · '
                      '${strings.weekday(_record.meeting.weekday)} · '
                      '${strings.periodRange(_record.meeting.firstPeriod, _record.meeting.lastPeriod)}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    )
                  else ...[
                    Text('${_index + 1} / ${_groups.length}'),
                    const Divider(height: 32),
                    SelectableText(_record.raw),
                  ],
                  const SizedBox(height: 20),
                  if (classroomChoice) ...[
                    for (final room in [...tutorialRooms, '暂无'])
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: OutlinedButton(
                          key: ValueKey('tutorial-room-$room'),
                          onPressed: () => _chooseTutorialRoom(room),
                          style: OutlinedButton.styleFrom(
                            alignment: Alignment.centerLeft,
                            minimumSize: const Size.fromHeight(44),
                          ),
                          child: Text(
                            room == '暂无'
                                ? strings.text(AppText.notAvailable)
                                : room,
                          ),
                        ),
                      ),
                  ] else ...[
                    for (final field in ImportField.values)
                      if (failedFields.contains(field))
                        TextFormField(
                          key: ValueKey('import-${field.name}'),
                          controller: _current[field],
                          decoration: InputDecoration(
                            labelText: _label(strings, field),
                          ),
                          validator: (value) =>
                              _validate(strings, field, value),
                        ),
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
                              _index + 1 == _groups.length
                                  ? AppText.finish
                                  : AppText.next,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _chooseTutorialRoom(String room) {
    _current[ImportField.room]!.text = room;
    _advance();
  }

  void _advance() {
    if (!_form.currentState!.validate()) return;
    if (_index + 1 < _groups.length) {
      setState(() => _index++);
      return;
    }
    widget.controller.complete({
      for (final group in _groups)
        for (final record in group)
          record.meeting.sourceId: _meeting(
            record,
            _fields[group.first.meeting.sourceId]!,
          ),
    });
  }

  Course _meeting(
    ImportRecord record,
    Map<ImportField, TextEditingController> fields,
  ) {
    String value(ImportField field) =>
        record.failedFields.isEmpty || record.failedFields.contains(field)
        ? fields[field]!.text
        : _value(field, record.meeting);
    final frequencyText = value(ImportField.frequency);
    return Course(
      sourceId: record.meeting.sourceId,
      sourceName: record.meeting.sourceName,
      name: value(ImportField.name).trim(),
      shortName: record.meeting.shortName,
      room: value(ImportField.room).trim(),
      weekday: int.parse(value(ImportField.weekday)),
      firstPeriod: int.parse(value(ImportField.firstPeriod)),
      lastPeriod: int.parse(value(ImportField.lastPeriod)),
      frequency: WeekFrequency.parse(frequencyText),
      frequencyText: frequencyText,
      note: value(ImportField.note),
      exam: value(ImportField.exam),
    );
  }

  String? _validate(AppStrings strings, ImportField field, String? value) {
    if (field == ImportField.name || field == ImportField.room) {
      if (value == null || value.trim().isEmpty) {
        return strings.text(AppText.required);
      }
    }
    if (field == ImportField.weekday ||
        field == ImportField.firstPeriod ||
        field == ImportField.lastPeriod) {
      final number = int.tryParse(value ?? '');
      final maximum = field == ImportField.weekday
          ? 5
          : widget.candidate.periodCount;
      if (number == null || number < 1 || number > maximum) {
        return '${strings.text(AppText.enterRange)}: 1–$maximum';
      }
      if (field == ImportField.lastPeriod &&
          number <
              (int.tryParse(_current[ImportField.firstPeriod]!.text) ?? 1)) {
        return strings.text(AppText.lastBeforeFirst);
      }
    }
    if (field == ImportField.frequency &&
        !const {'每周', '单周', '双周'}.contains(value?.trim())) {
      return strings.text(AppText.required);
    }
    return null;
  }

  static String _value(ImportField field, Course meeting) => switch (field) {
    ImportField.name => meeting.name,
    ImportField.room => meeting.room,
    ImportField.weekday => '${meeting.weekday}',
    ImportField.firstPeriod => '${meeting.firstPeriod}',
    ImportField.lastPeriod => '${meeting.lastPeriod}',
    ImportField.frequency => meeting.frequencyText,
    ImportField.note => meeting.note,
    ImportField.exam => meeting.exam,
  };

  static String _groupValue(List<ImportRecord> group, ImportField field) {
    for (final record in group) {
      if (record.failedFields.contains(field)) {
        return _value(field, record.meeting);
      }
    }
    return _value(field, group.first.meeting);
  }

  static List<List<ImportRecord>> _groupIssues(List<ImportRecord> records) {
    final groups = <String, List<ImportRecord>>{};
    for (final record in records) {
      groups.putIfAbsent(record.meeting.sourceName, () => []).add(record);
    }
    return groups.values.map(List<ImportRecord>.unmodifiable).toList();
  }

  static String _label(AppStrings strings, ImportField field) =>
      strings.text(switch (field) {
        ImportField.name => AppText.course,
        ImportField.room => AppText.room,
        ImportField.weekday => AppText.weekday,
        ImportField.firstPeriod => AppText.firstPeriod,
        ImportField.lastPeriod => AppText.lastPeriod,
        ImportField.frequency => AppText.frequency,
        ImportField.note => AppText.notes,
        ImportField.exam => AppText.exam,
      });

  static List<String> _roomChoices(String value) => value
      .split(RegExp(r'[、,，;；/]'))
      .map((room) => room.trim())
      .where((room) => room.isNotEmpty)
      .toSet()
      .toList();
}
