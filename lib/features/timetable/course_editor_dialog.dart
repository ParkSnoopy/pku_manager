import 'package:flutter/material.dart';

import '../../domain/course_meeting.dart';
import '../../domain/week_frequency.dart';
import '../../l10n/app_strings.dart';

final class CourseEditResult {
  const CourseEditResult.save(this.meeting) : remove = false;
  const CourseEditResult.remove() : meeting = null, remove = true;
  final CourseMeeting? meeting;
  final bool remove;
}

class CourseEditorDialog extends StatefulWidget {
  const CourseEditorDialog({
    super.key,
    required this.weekday,
    required this.period,
    required this.periodCount,
    this.meeting,
  });

  final int weekday;
  final int period;
  final int periodCount;
  final CourseMeeting? meeting;

  @override
  State<CourseEditorDialog> createState() => _CourseEditorDialogState();
}

class _CourseEditorDialogState extends State<CourseEditorDialog> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.meeting?.name ?? '');
  late final _room = TextEditingController(text: widget.meeting?.room ?? '');
  late final _note = TextEditingController(text: widget.meeting?.note ?? '');
  late final _exam = TextEditingController(text: widget.meeting?.exam ?? '');
  late int _weekday = widget.meeting?.weekday ?? widget.weekday;
  late int _first = widget.meeting?.firstPeriod ?? widget.period;
  late int _last = widget.meeting?.lastPeriod ?? widget.period;
  late WeekFrequency _frequency =
      widget.meeting?.frequency ?? WeekFrequency.every;

  @override
  void dispose() {
    _name.dispose();
    _room.dispose();
    _note.dispose();
    _exam.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 680),
        child: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text(
                strings.text(
                  widget.meeting == null
                      ? AppText.addCourse
                      : AppText.editCourse,
                ),
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 20),
              TextFormField(
                key: const ValueKey('course-name'),
                controller: _name,
                decoration: InputDecoration(
                  labelText: strings.text(AppText.course),
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? strings.text(AppText.required)
                    : null,
              ),
              TextFormField(
                key: const ValueKey('course-room'),
                controller: _room,
                decoration: InputDecoration(
                  labelText: strings.text(AppText.room),
                ),
              ),
              const SizedBox(height: 20),
              Text(strings.text(AppText.weekday)),
              SegmentedButton<int>(
                showSelectedIcon: false,
                segments: [
                  for (var day = 1; day <= 5; day++)
                    ButtonSegment(
                      value: day,
                      label: Text(strings.weekday(day).substring(0, 1)),
                    ),
                ],
                selected: {_weekday},
                onSelectionChanged: (values) =>
                    setState(() => _weekday = values.single),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(child: _periodField(strings, true)),
                  const SizedBox(width: 16),
                  Expanded(child: _periodField(strings, false)),
                ],
              ),
              const SizedBox(height: 20),
              Text(strings.text(AppText.frequency)),
              SegmentedButton<WeekFrequency>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: WeekFrequency.every, label: Text('每周')),
                  ButtonSegment(value: WeekFrequency.odd, label: Text('单周')),
                  ButtonSegment(value: WeekFrequency.even, label: Text('双周')),
                ],
                selected: {_frequency},
                onSelectionChanged: (values) =>
                    setState(() => _frequency = values.single),
              ),
              TextFormField(
                controller: _note,
                decoration: InputDecoration(
                  labelText: strings.text(AppText.notes),
                ),
              ),
              TextFormField(
                controller: _exam,
                decoration: InputDecoration(
                  labelText: strings.text(AppText.exam),
                ),
              ),
              const SizedBox(height: 24),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 12,
                children: [
                  if (widget.meeting?.sourceId.startsWith('user:') ?? false)
                    TextButton(
                      onPressed: () => Navigator.pop(
                        context,
                        const CourseEditResult.remove(),
                      ),
                      child: Text(strings.text(AppText.remove)),
                    ),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(strings.text(AppText.cancel)),
                  ),
                  FilledButton(
                    onPressed: _save,
                    child: Text(strings.text(AppText.save)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _periodField(AppStrings strings, bool first) => TextFormField(
    initialValue: '${first ? _first : _last}',
    keyboardType: TextInputType.number,
    decoration: InputDecoration(
      labelText: strings.text(first ? AppText.firstPeriod : AppText.lastPeriod),
    ),
    validator: (value) {
      final number = int.tryParse(value ?? '');
      if (number == null || number < 1 || number > widget.periodCount) {
        return strings.text(AppText.enterRange);
      }
      if (!first && number < _first) {
        return strings.text(AppText.lastBeforeFirst);
      }
      if (first) {
        _first = number;
      } else {
        _last = number;
      }
      return null;
    },
  );

  void _save() {
    if (!_form.currentState!.validate()) return;
    final token = switch (_frequency) {
      WeekFrequency.every => '每周',
      WeekFrequency.odd => '单周',
      WeekFrequency.even => '双周',
    };
    Navigator.pop(
      context,
      CourseEditResult.save(
        CourseMeeting(
          sourceId:
              widget.meeting?.sourceId ??
              'user:${DateTime.now().microsecondsSinceEpoch}',
          name: _name.text.trim(),
          weekday: _weekday,
          firstPeriod: _first,
          lastPeriod: _last,
          room: _room.text.trim(),
          frequency: _frequency,
          frequencyText: token,
          note: _note.text,
          exam: _exam.text,
        ),
      ),
    );
  }
}
