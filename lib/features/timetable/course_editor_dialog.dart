import 'package:flutter/material.dart';

import '../../domain/course_meeting.dart';
import '../../domain/week_frequency.dart';
import '../../l10n/app_strings.dart';
import '../settings/color_picker_dialog.dart';
import 'timetable_color.dart';

final class CourseEditResult {
  CourseEditResult.save(
    Iterable<CourseMeeting> meetings, {
    this.appearance = const CourseAppearance(),
  }) : meetings = List.unmodifiable(meetings),
       remove = false;
  const CourseEditResult.remove()
    : meetings = const [],
      appearance = const CourseAppearance(),
      remove = true;
  final List<CourseMeeting> meetings;
  final CourseAppearance appearance;
  final bool remove;

  CourseMeeting? get meeting => meetings.firstOrNull;
}

class CourseEditorDialog extends StatefulWidget {
  const CourseEditorDialog({
    super.key,
    required this.weekday,
    required this.period,
    required this.periodCount,
    this.meeting,
    this.meetings = const [],
    this.embedded = false,
    this.onCancel,
    this.onResult,
    this.courseAppearance = const CourseAppearance(),
    this.suggestedColor = const Color(0xffe0e0e0),
    this.colorPicker = showAppColorPicker,
  });

  final int weekday;
  final int period;
  final int periodCount;
  final CourseMeeting? meeting;
  final List<CourseMeeting> meetings;
  final bool embedded;
  final VoidCallback? onCancel;
  final ValueChanged<CourseEditResult>? onResult;
  final CourseAppearance courseAppearance;
  final Color suggestedColor;
  final ColorPickerLauncher colorPicker;

  @override
  State<CourseEditorDialog> createState() => _CourseEditorDialogState();
}

class _CourseEditorDialogState extends State<CourseEditorDialog> {
  final _form = GlobalKey<FormState>();
  late final List<CourseMeeting> _meetings = widget.meetings.isNotEmpty
      ? widget.meetings
      : [if (widget.meeting != null) widget.meeting!];
  CourseMeeting? get _primary => _meetings.firstOrNull;
  late final _name = TextEditingController(text: _primary?.name ?? '');
  late final _room = TextEditingController(text: _primary?.room ?? '');
  late final _note = TextEditingController(text: _primary?.note ?? '');
  late final _exam = TextEditingController(text: _primary?.exam ?? '');
  late int _weekday = _primary?.weekday ?? widget.weekday;
  late int _first = _meetings.isEmpty
      ? widget.period
      : _meetings
            .map((meeting) => meeting.firstPeriod)
            .reduce((a, b) => a < b ? a : b);
  late int _last = _meetings.isEmpty
      ? widget.period
      : _meetings
            .map((meeting) => meeting.lastPeriod)
            .reduce((a, b) => a > b ? a : b);
  late WeekFrequency _frequency = _primary?.frequency ?? WeekFrequency.every;
  late Color _color = widget.courseAppearance.color ?? widget.suggestedColor;
  late bool _customColor = widget.courseAppearance.color != null;
  late bool _lockColor = widget.courseAppearance.lockColor;
  late bool _outlined = widget.courseAppearance.outlined;

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
    final editor = ConstrainedBox(
      key: ValueKey(
        widget.embedded ? 'course-editor-pane' : 'course-editor-dialog',
      ),
      constraints: widget.embedded
          ? const BoxConstraints(maxWidth: 560)
          : const BoxConstraints(maxWidth: 560, maxHeight: 760),
      child: Form(
        key: _form,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  Text(
                    strings.text(
                      widget.meeting == null && _meetings.isEmpty
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
                  Text(strings.text(AppText.classColor)),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      key: const ValueKey('course-custom-color'),
                      onPressed: _chooseColor,
                      icon: Icon(Icons.circle, color: _color),
                      label: Text(
                        strings.text(
                          _customColor
                              ? AppText.manualColor
                              : AppText.rolledColor,
                        ),
                      ),
                    ),
                  ),
                  SwitchListTile(
                    key: const ValueKey('course-color-lock'),
                    contentPadding: EdgeInsets.zero,
                    title: Text(strings.text(AppText.keepColorWhenRolling)),
                    value: _lockColor,
                    onChanged: _customColor
                        ? (value) => setState(() => _lockColor = value)
                        : null,
                  ),
                  SwitchListTile(
                    key: const ValueKey('course-important-outline'),
                    contentPadding: EdgeInsets.zero,
                    title: Text(strings.text(AppText.importantOutline)),
                    value: _outlined,
                    onChanged: (value) => setState(() => _outlined = value),
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
                      ButtonSegment(
                        value: WeekFrequency.every,
                        label: Text('每周'),
                      ),
                      ButtonSegment(
                        value: WeekFrequency.odd,
                        label: Text('单周'),
                      ),
                      ButtonSegment(
                        value: WeekFrequency.even,
                        label: Text('双周'),
                      ),
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
                ],
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Wrap(
                alignment: WrapAlignment.end,
                spacing: 12,
                children: [
                  if (_meetings.isNotEmpty &&
                      _meetings.every(
                        (meeting) => meeting.sourceId.startsWith('user:'),
                      ))
                    TextButton(
                      onPressed: () => _finish(const CourseEditResult.remove()),
                      child: Text(strings.text(AppText.remove)),
                    ),
                  TextButton(
                    onPressed: _cancel,
                    child: Text(strings.text(AppText.cancel)),
                  ),
                  FilledButton(
                    onPressed: _save,
                    child: Text(strings.text(AppText.save)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    return widget.embedded
        ? Material(color: Theme.of(context).colorScheme.surface, child: editor)
        : Dialog(child: editor);
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
      if (!first && number - _first + 1 < _meetings.length) {
        return strings.text(AppText.periodRangeTooShort);
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
    final originals = _meetings.isEmpty
        ? [
            CourseMeeting(
              sourceId: 'user:${DateTime.now().microsecondsSinceEpoch}',
              name: _name.text.trim(),
              weekday: _weekday,
              firstPeriod: _first,
              lastPeriod: _last,
            ),
          ]
        : _meetings;
    final span = _last - _first + 1;
    final updates = <CourseMeeting>[];
    for (var index = 0; index < originals.length; index++) {
      final first = _first + span * index ~/ originals.length;
      final last = _first + span * (index + 1) ~/ originals.length - 1;
      updates.add(
        CourseMeeting(
          sourceId: originals[index].sourceId,
          name: _name.text.trim(),
          weekday: _weekday,
          firstPeriod: first,
          lastPeriod: last,
          room: _room.text.trim(),
          frequency: _frequency,
          frequencyText: token,
          note: _note.text,
          exam: _exam.text,
        ),
      );
    }
    _finish(
      CourseEditResult.save(
        updates,
        appearance: CourseAppearance(
          color: _customColor ? _color : null,
          lockColor: _lockColor,
          outlined: _outlined,
        ),
      ),
    );
  }

  Future<void> _chooseColor() async {
    final strings = AppStrings.of(context);
    final color = await widget.colorPicker(
      context,
      color: _color,
      title: strings.text(AppText.chooseColor),
    );
    if (!mounted) return;
    setState(() {
      _color = color;
      _customColor = true;
      _lockColor = true;
    });
  }

  void _cancel() {
    if (widget.onCancel != null) {
      widget.onCancel!();
    } else {
      Navigator.pop(context);
    }
  }

  void _finish(CourseEditResult result) {
    if (widget.onResult != null) {
      widget.onResult!(result);
    } else {
      Navigator.pop(context, result);
    }
  }
}
