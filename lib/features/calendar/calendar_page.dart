import 'package:flutter/material.dart';

import '../../domain/calendar_schedule.dart';
import '../../domain/timetable.dart';
import '../../l10n/app_strings.dart';
import 'calendar_schedule_controller.dart';
import 'schedule_color.dart';

class CalendarPage extends StatefulWidget {
  const CalendarPage({
    super.key,
    required this.now,
    required this.controller,
    this.timetable,
    this.focusedScheduleId,
  });

  final DateTime now;
  final CalendarScheduleController controller;
  final Timetable? timetable;
  final int? focusedScheduleId;

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  late DateTime _month = _beijingDate(widget.now);

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_scheduleChanged);
    _focusSchedule();
  }

  @override
  void didUpdateWidget(CalendarPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_scheduleChanged);
      widget.controller.addListener(_scheduleChanged);
    }
    if (oldWidget.focusedScheduleId != widget.focusedScheduleId) {
      _focusSchedule();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_scheduleChanged);
    super.dispose();
  }

  void _scheduleChanged() {
    if (mounted) setState(() {});
  }

  void _focusSchedule() {
    final id = widget.focusedScheduleId;
    if (id == null) return;
    final schedule = widget.controller.schedules
        .where((item) => item.id == id)
        .firstOrNull;
    if (schedule == null) return;
    _month = _beijingDate(schedule.startsAt);
  }

  void _changeMonth(int delta) =>
      setState(() => _month = DateTime.utc(_month.year, _month.month + delta));

  Future<void> _editSchedule(
    DateTime date, [
    CalendarSchedule? schedule,
  ]) async {
    try {
      final target =
          schedule ??
          widget.controller.create(
            title: AppStrings.of(context).text(AppText.newSchedule),
            startsAt: DateTime.utc(
              date.year,
              date.month,
              date.day,
            ).subtract(const Duration(hours: 8)),
          );
      await showDialog<void>(
        context: context,
        builder: (_) => _ScheduleEditor(
          schedule: target,
          timetable: widget.timetable,
          onChanged: _updateSchedule,
          onRemove: () {
            if (_removeSchedule(target.id)) Navigator.pop(context);
          },
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppStrings.of(context).text(AppText.scheduleUpdateFailed),
            ),
          ),
        );
      }
    }
  }

  void _updateSchedule(CalendarSchedule schedule) {
    try {
      widget.controller.update(schedule);
    } catch (_) {
      _showUpdateFailure();
    }
  }

  bool _removeSchedule(int id) {
    try {
      widget.controller.remove(id);
      return true;
    } catch (_) {
      _showUpdateFailure();
      return false;
    }
  }

  void _showUpdateFailure() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          AppStrings.of(context).text(AppText.scheduleUpdateFailed),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final today = _beijingDate(widget.now);
    final first = DateTime.utc(_month.year, _month.month);
    final gridStart = first.subtract(Duration(days: first.weekday - 1));
    return Material(
      key: const ValueKey('calendar-page'),
      color: Theme.of(context).colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                IconButton(
                  key: const ValueKey('calendar-previous-month'),
                  tooltip: strings.text(AppText.previousMonth),
                  onPressed: () => _changeMonth(-1),
                  icon: const Icon(Icons.chevron_left),
                ),
                Expanded(
                  child: Text(
                    strings.monthLabel(_month),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  key: const ValueKey('calendar-next-month'),
                  tooltip: strings.text(AppText.nextMonth),
                  onPressed: () => _changeMonth(1),
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                for (var day = 1; day <= 7; day++)
                  Expanded(
                    child: Text(
                      strings.weekday(day).substring(0, 1),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final cellWidth = constraints.maxWidth / 7;
                  final cellHeight = constraints.maxHeight / 6;
                  return GridView.builder(
                    key: const ValueKey('calendar-month-grid'),
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 7,
                      childAspectRatio: cellWidth / cellHeight,
                    ),
                    itemCount: 42,
                    itemBuilder: (context, index) {
                      final date = gridStart.add(Duration(days: index));
                      final schedules = widget.controller.schedules
                          .where((schedule) => _sameBeijingDate(schedule, date))
                          .toList(growable: false);
                      return _CalendarDay(
                        date: date,
                        today: today,
                        inMonth: date.month == _month.month,
                        schedules: schedules,
                        focusedScheduleId: widget.focusedScheduleId,
                        onAdd: () => _editSchedule(date),
                        onEdit: (schedule) => _editSchedule(date, schedule),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CalendarDay extends StatelessWidget {
  const _CalendarDay({
    required this.date,
    required this.today,
    required this.inMonth,
    required this.schedules,
    required this.focusedScheduleId,
    required this.onAdd,
    required this.onEdit,
  });

  final DateTime date;
  final DateTime today;
  final bool inMonth;
  final List<CalendarSchedule> schedules;
  final int? focusedScheduleId;
  final VoidCallback onAdd;
  final ValueChanged<CalendarSchedule> onEdit;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final strings = AppStrings.of(context);
    final isToday = date == today;
    return Semantics(
      label: '${date.year}-${date.month}-${date.day}',
      child: DecoratedBox(
        key: ValueKey('calendar-day-${date.year}-${date.month}-${date.day}'),
        decoration: BoxDecoration(
          border: Border.all(
            color: isToday ? colors.primary : colors.outlineVariant,
            width: isToday ? 2 : .5,
          ),
        ),
        child: ClipRect(
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${date.day}',
                        style: TextStyle(
                          color: inMonth ? colors.onSurface : colors.outline,
                          fontSize: 14,
                          fontWeight: isToday
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                    ),
                    if (inMonth)
                      IconButton(
                        key: ValueKey(
                          'calendar-add-${date.year}-${date.month}-${date.day}',
                        ),
                        onPressed: onAdd,
                        tooltip: strings.text(AppText.addSchedule),
                        icon: const Icon(Icons.add, size: 16),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints.tightFor(
                          width: 24,
                          height: 24,
                        ),
                        visualDensity: VisualDensity.compact,
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Expanded(
                  child: ListView.builder(
                    padding: EdgeInsets.zero,
                    itemCount: schedules.length,
                    itemBuilder: (context, index) {
                      final schedule = schedules[index];
                      final starts = _beijingDateTime(schedule.startsAt);
                      final background = scheduleColor(schedule.id);
                      final foreground = scheduleForeground(background);
                      final focused = schedule.id == focusedScheduleId;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Material(
                          key: ValueKey(
                            'calendar-schedule-color-${schedule.id}',
                          ),
                          color: background,
                          shape: focused
                              ? RoundedRectangleBorder(
                                  side: BorderSide(
                                    color: colors.primary,
                                    width: 3,
                                  ),
                                )
                              : null,
                          child: InkWell(
                            key: ValueKey('calendar-schedule-${schedule.id}'),
                            onTap: () => onEdit(schedule),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 3,
                              ),
                              child: Text(
                                '${schedule.allDay ? '' : '${_two(starts.hour)}:${_two(starts.minute)} '}'
                                '${schedule.title}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: foreground,
                                  fontSize: 14,
                                  fontWeight: focused
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ScheduleEditor extends StatefulWidget {
  const _ScheduleEditor({
    required this.schedule,
    required this.onChanged,
    required this.onRemove,
    this.timetable,
  });

  final CalendarSchedule schedule;
  final Timetable? timetable;
  final ValueChanged<CalendarSchedule> onChanged;
  final VoidCallback onRemove;

  @override
  State<_ScheduleEditor> createState() => _ScheduleEditorState();
}

class _ScheduleEditorState extends State<_ScheduleEditor> {
  late final TextEditingController _title = TextEditingController(
    text: widget.schedule.title,
  );
  late CalendarSchedule _schedule = widget.schedule;
  late DateTime _date = _beijingDate(widget.schedule.startsAt);
  late TimeOfDay _time = TimeOfDay.fromDateTime(
    _beijingDateTime(widget.schedule.startsAt),
  );
  bool _showRequired = false;

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _chooseDate() async {
    final value = await showDatePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDate: DateTime(_date.year, _date.month, _date.day),
    );
    if (value != null) {
      _date = DateTime.utc(value.year, value.month, value.day);
      _publishDateTime();
    }
  }

  Future<void> _chooseTime() async {
    final value = await showTimePicker(context: context, initialTime: _time);
    if (value != null) {
      _time = value;
      _publishDateTime();
    }
  }

  void _publishDateTime() {
    final startsAt = DateTime.utc(
      _date.year,
      _date.month,
      _date.day,
      _schedule.allDay ? 0 : _time.hour,
      _schedule.allDay ? 0 : _time.minute,
    ).subtract(const Duration(hours: 8));
    _publish(_schedule.copyWith(startsAt: startsAt));
  }

  void _publish(CalendarSchedule value) {
    setState(() => _schedule = value);
    widget.onChanged(value);
  }

  List<({String sourceId, String name})> get _classes {
    final values = <String, ({String sourceId, String name})>{};
    for (final course in widget.timetable?.meetings ?? const []) {
      values.putIfAbsent(
        course.sourceName,
        () => (sourceId: course.sourceId, name: course.sourceName),
      );
    }
    return values.values.toList(growable: false)
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    return AlertDialog(
      key: const ValueKey('schedule-editor'),
      title: Text(strings.text(AppText.editSchedule)),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              key: const ValueKey('schedule-title'),
              controller: _title,
              autofocus: true,
              decoration: InputDecoration(
                labelText: strings.text(AppText.scheduleTitle),
                errorText: _showRequired
                    ? strings.text(AppText.scheduleTitleRequired)
                    : null,
              ),
              onChanged: (value) {
                final title = value.trim();
                setState(() => _showRequired = title.isEmpty);
                if (title.isNotEmpty) {
                  _publish(_schedule.copyWith(title: title));
                }
              },
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              key: const ValueKey('schedule-all-day'),
              contentPadding: EdgeInsets.zero,
              title: Text(strings.text(AppText.allDay)),
              value: _schedule.allDay,
              onChanged: (value) {
                _schedule = _schedule.copyWith(allDay: value);
                _publishDateTime();
              },
            ),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    key: const ValueKey('schedule-date'),
                    onPressed: _chooseDate,
                    icon: const Icon(Icons.calendar_today_outlined),
                    label: Text(
                      '${_date.year}-${_two(_date.month)}-${_two(_date.day)}',
                    ),
                  ),
                ),
                if (!_schedule.allDay) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      key: const ValueKey('schedule-time'),
                      onPressed: _chooseTime,
                      icon: const Icon(Icons.schedule),
                      label: Text(_time.format(context)),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String?>(
              key: const ValueKey('schedule-related-class'),
              initialValue: _schedule.relatedClassSourceId,
              decoration: InputDecoration(
                labelText: strings.text(AppText.relatedClass),
              ),
              items: [
                DropdownMenuItem<String?>(
                  value: null,
                  child: Text(strings.text(AppText.noRelatedClass)),
                ),
                for (final course in _classes)
                  DropdownMenuItem<String?>(
                    value: course.sourceId,
                    child: Text(course.name),
                  ),
              ],
              onChanged: (value) =>
                  _publish(_schedule.copyWith(relatedClassSourceId: value)),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          key: const ValueKey('remove-schedule'),
          onPressed: widget.onRemove,
          child: Text(strings.text(AppText.remove)),
        ),
        TextButton(
          key: const ValueKey('close-schedule-editor'),
          onPressed: () => Navigator.pop(context),
          child: Text(strings.text(AppText.close)),
        ),
      ],
    );
  }
}

DateTime _beijingDate(DateTime value) {
  final local = _beijingDateTime(value);
  return DateTime.utc(local.year, local.month, local.day);
}

DateTime _beijingDateTime(DateTime value) =>
    value.toUtc().add(const Duration(hours: 8));

bool _sameBeijingDate(CalendarSchedule schedule, DateTime date) =>
    _beijingDate(schedule.startsAt) == date;

String _two(int value) => value.toString().padLeft(2, '0');
