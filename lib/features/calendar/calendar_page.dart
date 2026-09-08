import 'package:flutter/material.dart';

import '../../domain/calendar_schedule.dart';
import '../../l10n/app_strings.dart';
import 'calendar_schedule_controller.dart';

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key, required this.now, required this.controller});

  final DateTime now;
  final CalendarScheduleController controller;

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  late DateTime _month = _beijingDate(widget.now);

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_scheduleChanged);
  }

  @override
  void didUpdateWidget(CalendarPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller == widget.controller) return;
    oldWidget.controller.removeListener(_scheduleChanged);
    widget.controller.addListener(_scheduleChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_scheduleChanged);
    super.dispose();
  }

  void _scheduleChanged() {
    if (mounted) setState(() {});
  }

  void _changeMonth(int delta) =>
      setState(() => _month = DateTime.utc(_month.year, _month.month + delta));

  Future<void> _editSchedule(
    DateTime date, [
    CalendarSchedule? schedule,
  ]) async {
    final result = await showDialog<_ScheduleEditResult>(
      context: context,
      builder: (_) => _ScheduleEditor(date: date, schedule: schedule),
    );
    if (result == null) return;
    try {
      if (result.remove) {
        widget.controller.remove(schedule!.id);
      } else if (schedule == null) {
        widget.controller.create(
          title: result.title,
          startsAt: result.startsAt,
        );
      } else {
        widget.controller.update(
          schedule.copyWith(title: result.title, startsAt: result.startsAt),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppStrings.of(context).text(AppText.scheduleSaveFailed),
            ),
          ),
        );
      }
    }
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
    required this.onAdd,
    required this.onEdit,
  });

  final DateTime date;
  final DateTime today;
  final bool inMonth;
  final List<CalendarSchedule> schedules;
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
                      return InkWell(
                        key: ValueKey('calendar-schedule-${schedule.id}'),
                        onTap: () => onEdit(schedule),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Text(
                            '${_two(starts.hour)}:${_two(starts.minute)} '
                            '${schedule.title}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12),
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

final class _ScheduleEditResult {
  const _ScheduleEditResult({
    required this.title,
    required this.startsAt,
    this.remove = false,
  });

  final String title;
  final DateTime startsAt;
  final bool remove;
}

class _ScheduleEditor extends StatefulWidget {
  const _ScheduleEditor({required this.date, this.schedule});

  final DateTime date;
  final CalendarSchedule? schedule;

  @override
  State<_ScheduleEditor> createState() => _ScheduleEditorState();
}

class _ScheduleEditorState extends State<_ScheduleEditor> {
  late final TextEditingController _title = TextEditingController(
    text: widget.schedule?.title ?? '',
  );
  late DateTime _date = widget.schedule == null
      ? widget.date
      : _beijingDate(widget.schedule!.startsAt);
  late TimeOfDay _time = widget.schedule == null
      ? const TimeOfDay(hour: 9, minute: 0)
      : TimeOfDay.fromDateTime(_beijingDateTime(widget.schedule!.startsAt));
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
      setState(() => _date = DateTime.utc(value.year, value.month, value.day));
    }
  }

  Future<void> _chooseTime() async {
    final value = await showTimePicker(context: context, initialTime: _time);
    if (value != null) setState(() => _time = value);
  }

  void _save() {
    final title = _title.text.trim();
    if (title.isEmpty) {
      setState(() => _showRequired = true);
      return;
    }
    final startsAt = DateTime.utc(
      _date.year,
      _date.month,
      _date.day,
      _time.hour,
      _time.minute,
    ).subtract(const Duration(hours: 8));
    Navigator.pop(
      context,
      _ScheduleEditResult(title: title, startsAt: startsAt),
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    return AlertDialog(
      key: const ValueKey('schedule-editor'),
      title: Text(
        strings.text(
          widget.schedule == null ? AppText.addSchedule : AppText.editSchedule,
        ),
      ),
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
              onSubmitted: (_) => _save(),
            ),
            const SizedBox(height: 12),
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
            ),
          ],
        ),
      ),
      actions: [
        if (widget.schedule != null)
          TextButton(
            key: const ValueKey('remove-schedule'),
            onPressed: () => Navigator.pop(
              context,
              _ScheduleEditResult(
                title: widget.schedule!.title,
                startsAt: widget.schedule!.startsAt,
                remove: true,
              ),
            ),
            child: Text(strings.text(AppText.remove)),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(strings.text(AppText.cancel)),
        ),
        FilledButton(
          key: const ValueKey('save-schedule'),
          onPressed: _save,
          child: Text(strings.text(AppText.save)),
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
