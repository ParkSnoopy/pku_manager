import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';

import '../../domain/calendar_schedule.dart';
import '../../domain/timetable.dart';
import '../../l10n/app_strings.dart';
import '../../ui/flashing_outline.dart';
import '../settings/color_picker_dialog.dart';
import 'calendar_schedule_controller.dart';
import 'schedule_color.dart';

class CalendarPage extends StatefulWidget {
  const CalendarPage({
    super.key,
    required this.now,
    required this.controller,
    this.timetable,
    this.focusedScheduleId,
    this.onScheduleSelected,
    this.colorPicker = showAppColorPicker,
  });

  final DateTime now;
  final CalendarScheduleController controller;
  final Timetable? timetable;
  final int? focusedScheduleId;
  final ValueChanged<CalendarSchedule>? onScheduleSelected;
  final ColorPickerLauncher colorPicker;

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  late DateTime _month = _beijingDate(widget.now);
  late DateTime _baseWeek;
  late final PageController _weekController;
  double _pointerScrollAccumulator = 0;
  int? _pointerScrollTarget;
  int _scrollRevision = 0;

  static const _initialWeek = 1200;
  static const _weekCount = 2401;
  static const _visibleRows = 5;
  static const _dragSensitivity = .5;
  static const _pointerScrollThresholdInWeeks = 1.25;

  @override
  void initState() {
    super.initState();
    final first = DateTime.utc(_month.year, _month.month);
    final visibleStart = first.subtract(Duration(days: first.weekday - 1));
    _baseWeek = visibleStart.subtract(
      const Duration(days: _initialWeek * DateTime.daysPerWeek),
    );
    _weekController = PageController(
      initialPage: _initialWeek + _visibleRows ~/ 2,
      viewportFraction: 1 / _visibleRows,
    );
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
    _weekController.dispose();
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
    final target = _beijingDate(schedule.startsAt);
    final first = DateTime.utc(target.year, target.month);
    final visibleStart = first.subtract(Duration(days: first.weekday - 1));
    final page =
        visibleStart.difference(_baseWeek).inDays ~/ 7 + _visibleRows ~/ 2;
    _month = target;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_weekController.hasClients && page >= 0 && page < _weekCount) {
        _weekController.jumpToPage(page);
      }
    });
  }

  void _updateSuperiorMonth(int centerVisibleWeek) {
    final firstVisibleWeek = centerVisibleWeek - _visibleRows ~/ 2;
    final firstDate = _baseWeek.add(Duration(days: firstVisibleWeek * 7));
    final counts = <(int, int), int>{};
    for (var day = 0; day < _visibleRows * 7; day++) {
      final date = firstDate.add(Duration(days: day));
      counts.update(
        (date.year, date.month),
        (value) => value + 1,
        ifAbsent: () => 1,
      );
    }
    final center = firstDate.add(const Duration(days: 17));
    final superior = counts.entries.reduce((left, right) {
      if (left.value != right.value) {
        return left.value > right.value ? left : right;
      }
      final leftIsCenter = left.key == (center.year, center.month);
      return leftIsCenter ? left : right;
    }).key;
    final month = DateTime.utc(superior.$1, superior.$2);
    if (month != _month) {
      setState(() => _month = month);
    }
  }

  void _handlePointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent || !_weekController.hasClients) return;
    final delta = event.scrollDelta.dy;
    if (delta == 0) return;
    event.respond(allowPlatformDefault: false);
    final pageThreshold =
        _weekController.position.viewportDimension /
        _visibleRows *
        _pointerScrollThresholdInWeeks;
    _pointerScrollAccumulator += delta;
    final weeks = (_pointerScrollAccumulator / pageThreshold).truncate();
    if (weeks == 0) return;
    _pointerScrollAccumulator -= weeks * pageThreshold;
    _animateByWeeks(weeks);
  }

  void _animateByWeeks(int weeks) {
    final current =
        _pointerScrollTarget ?? _weekController.page?.round() ?? _initialWeek;
    _animateToWeek(current + weeks);
  }

  void _animateToWeek(int week) {
    _pointerScrollTarget = week.clamp(0, _weekCount - 1);
    final revision = ++_scrollRevision;
    _weekController
        .animateToPage(
          _pointerScrollTarget!,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
        )
        .whenComplete(() {
          if (mounted && revision == _scrollRevision) {
            _pointerScrollTarget = null;
          }
        });
  }

  void _handleVerticalDragStart(DragStartDetails _) {
    _pointerScrollAccumulator = 0;
    _pointerScrollTarget = null;
    _scrollRevision++;
  }

  void _handleVerticalDragUpdate(DragUpdateDetails details) {
    if (!_weekController.hasClients) return;
    final position = _weekController.position;
    final target =
        (position.pixels - (details.primaryDelta ?? 0) * _dragSensitivity)
            .clamp(position.minScrollExtent, position.maxScrollExtent)
            .toDouble();
    _weekController.jumpTo(target);
  }

  void _handleVerticalDragEnd(DragEndDetails _) {
    if (!_weekController.hasClients) return;
    final page = _weekController.page;
    if (page == null) return;
    _animateToWeek(page.round());
  }

  Future<void> _editSchedule(
    DateTime date, [
    CalendarSchedule? schedule,
  ]) async {
    try {
      final target =
          schedule ??
          CalendarSchedule(
            id: 0,
            title: '',
            startsAt: DateTime.utc(
              date.year,
              date.month,
              date.day,
            ).subtract(const Duration(hours: 8)),
          );
      final result = await showDialog<CalendarSchedule>(
        context: context,
        builder: (_) => ScheduleEditorDialog(
          schedule: target,
          timetable: widget.timetable,
          colorPicker: widget.colorPicker,
        ),
      );
      if (result == null) return;
      if (schedule == null) {
        widget.controller.create(
          title: result.title,
          startsAt: result.startsAt,
          allDay: result.allDay,
          relatedClassSourceId: result.relatedClassSourceId,
          note: result.note,
          colorValue: result.colorValue,
        );
      } else {
        widget.controller.update(result);
      }
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

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final today = _beijingDate(widget.now);
    return Material(
      key: const ValueKey('calendar-page'),
      color: Theme.of(context).colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    strings.monthLabel(_month),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
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
              child: Listener(
                onPointerSignal: _handlePointerSignal,
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onVerticalDragStart: _handleVerticalDragStart,
                  onVerticalDragUpdate: _handleVerticalDragUpdate,
                  onVerticalDragEnd: _handleVerticalDragEnd,
                  child: PageView.builder(
                    key: const ValueKey('calendar-month-grid'),
                    controller: _weekController,
                    physics: const NeverScrollableScrollPhysics(),
                    scrollDirection: Axis.vertical,
                    itemCount: _weekCount,
                    onPageChanged: _updateSuperiorMonth,
                    itemBuilder: (context, weekIndex) => Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (var day = 0; day < 7; day++)
                          Expanded(
                            child: Builder(
                              builder: (context) {
                                final date = _baseWeek.add(
                                  Duration(days: weekIndex * 7 + day),
                                );
                                final schedules = widget.controller.schedules
                                    .where(
                                      (schedule) =>
                                          _sameBeijingDate(schedule, date),
                                    )
                                    .toList(growable: false);
                                return _CalendarDay(
                                  date: date,
                                  today: today,
                                  inMonth: date.month == _month.month,
                                  schedules: schedules,
                                  focusedScheduleId: widget.focusedScheduleId,
                                  onAdd: () => _editSchedule(date),
                                  onSelect: widget.onScheduleSelected,
                                  onEdit: (schedule) =>
                                      _editSchedule(date, schedule),
                                );
                              },
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
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
    required this.onSelect,
    required this.onEdit,
  });

  final DateTime date;
  final DateTime today;
  final bool inMonth;
  final List<CalendarSchedule> schedules;
  final int? focusedScheduleId;
  final VoidCallback onAdd;
  final ValueChanged<CalendarSchedule>? onSelect;
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
          color: inMonth
              ? Colors.transparent
              : colors.brightness == Brightness.dark
              ? colors.surfaceContainerHighest
              : const Color(0xffd3d3d3),
          border: Border.all(color: colors.outlineVariant, width: .5),
        ),
        child: ClipRect(
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '${date.day}',
                      style: TextStyle(
                        color: inMonth ? colors.onSurface : colors.outline,
                        fontSize: 14,
                        fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                    if (isToday)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(left: 4),
                          child: Text(
                            'TODAY',
                            key: const ValueKey('calendar-today-label'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: colors.primary,
                              fontSize: 8,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      )
                    else
                      const Spacer(),
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
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: schedules.length,
                    itemBuilder: (context, index) {
                      final schedule = schedules[index];
                      final starts = _beijingDateTime(schedule.startsAt);
                      final background = scheduleColor(context, schedule);
                      final foreground = scheduleForeground(background);
                      final focused = schedule.id == focusedScheduleId;
                      final canSelect =
                          onSelect != null &&
                          schedule.relatedClassSourceId != null;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: FlashingOutline(
                          key: ValueKey(
                            'calendar-schedule-flash-${schedule.id}',
                          ),
                          active: focused,
                          child: Material(
                            key: ValueKey(
                              'calendar-schedule-color-${schedule.id}',
                            ),
                            color: background,
                            child: MouseRegion(
                              cursor: canSelect
                                  ? SystemMouseCursors.click
                                  : MouseCursor.defer,
                              child: InkWell(
                                key: ValueKey(
                                  'calendar-schedule-${schedule.id}',
                                ),
                                onTap: !canSelect
                                    ? null
                                    : () => onSelect!(schedule),
                                onLongPress: () => onEdit(schedule),
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
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
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

class ScheduleEditorDialog extends StatefulWidget {
  const ScheduleEditorDialog({
    super.key,
    required this.schedule,
    this.colorPicker = showAppColorPicker,
    this.timetable,
  });

  final CalendarSchedule schedule;
  final Timetable? timetable;
  final ColorPickerLauncher colorPicker;

  @override
  State<ScheduleEditorDialog> createState() => _ScheduleEditorDialogState();
}

class _ScheduleEditorDialogState extends State<ScheduleEditorDialog> {
  late final TextEditingController _title = TextEditingController(
    text: widget.schedule.title,
  );
  late final TextEditingController _note = TextEditingController(
    text: widget.schedule.note,
  );
  late CalendarSchedule _schedule = widget.schedule;
  late Color? _color = widget.schedule.colorValue == null
      ? null
      : Color(widget.schedule.colorValue!);
  late DateTime _date = _beijingDate(widget.schedule.startsAt);
  late TimeOfDay _time = TimeOfDay.fromDateTime(
    _beijingDateTime(widget.schedule.startsAt),
  );
  bool _showRequired = false;

  @override
  void dispose() {
    _title.dispose();
    _note.dispose();
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
      _schedule.allDay ? 23 : _time.hour,
      _schedule.allDay ? 59 : _time.minute,
    ).subtract(const Duration(hours: 8));
    setState(() => _schedule = _schedule.copyWith(startsAt: startsAt));
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

  Future<void> _chooseColor() async {
    final color = await widget.colorPicker(
      context,
      color: _color ?? Theme.of(context).colorScheme.primary,
      title: AppStrings.of(context).text(AppText.scheduleColor),
    );
    if (mounted) setState(() => _color = color);
  }

  void _save() {
    final title = _title.text.trim();
    if (title.isEmpty) {
      setState(() => _showRequired = true);
      return;
    }
    Navigator.pop(
      context,
      _schedule.copyWith(
        title: title,
        note: _note.text.trim(),
        colorValue: _color?.toARGB32(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    return AlertDialog(
      key: const ValueKey('schedule-editor'),
      insetPadding: const EdgeInsets.all(24),
      backgroundColor: Theme.of(context).colorScheme.surface
          .withValues(alpha: 1),
      surfaceTintColor: Colors.transparent,
      title: Text(strings.text(AppText.editSchedule)),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 620),
        child: SizedBox(
          width: 560,
          child: SingleChildScrollView(
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
                    if (_showRequired && value.trim().isNotEmpty) {
                      setState(() => _showRequired = false);
                    }
                  },
                ),
                const SizedBox(height: 16),
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
                      const SizedBox(width: 12),
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
                const SizedBox(height: 16),
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
                  onChanged: (value) => setState(
                    () => _schedule = _schedule.copyWith(
                      relatedClassSourceId: value,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  key: const ValueKey('schedule-note'),
                  controller: _note,
                  minLines: 3,
                  maxLines: 5,
                  decoration: InputDecoration(
                    labelText: strings.text(AppText.scheduleNote),
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Wrap(
                    spacing: 8,
                    children: [
                      OutlinedButton.icon(
                        key: const ValueKey('schedule-color'),
                        onPressed: _chooseColor,
                        icon: Icon(
                          Icons.circle,
                          color:
                              _color ?? Theme.of(context).colorScheme.primary,
                        ),
                        label: Text(strings.text(AppText.scheduleColor)),
                      ),
                      if (_color != null)
                        TextButton(
                          key: const ValueKey('schedule-color-unfix'),
                          onPressed: () => setState(() => _color = null),
                          child: Text(strings.text(AppText.useThemeColor)),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          key: const ValueKey('cancel-schedule-editor'),
          onPressed: () => Navigator.pop(context),
          child: Text(strings.text(AppText.cancel)),
        ),
        FilledButton(
          key: const ValueKey('save-schedule-editor'),
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
