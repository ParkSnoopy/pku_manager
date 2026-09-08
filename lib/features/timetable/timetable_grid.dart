import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../domain/calendar_schedule.dart';
import '../../domain/course.dart';
import '../../domain/timetable.dart';
import '../../domain/week_frequency.dart';
import '../../l10n/app_strings.dart';
import 'timetable_color.dart';
import 'timetable_style.dart';

class TimetableGrid extends StatelessWidget {
  const TimetableGrid({
    super.key,
    required this.timetable,
    required this.days,
    required this.paletteSeed,
    required this.paletteIndex,
    required this.fontWeight,
    required this.onEdit,
    this.schedules = const [],
    this.courseAppearances = const {},
    this.parity,
    this.previousDay,
    this.nextDay,
  });
  final Timetable timetable;
  final List<int> days;
  final int paletteSeed;
  final int paletteIndex;
  final FontWeight fontWeight;
  final List<CalendarSchedule> schedules;
  final Map<String, CourseAppearance> courseAppearances;
  final void Function(int weekday, int period, List<Course> meetings) onEdit;
  final WeekParity? parity;
  final VoidCallback? previousDay;
  final VoidCallback? nextDay;

  @override
  Widget build(BuildContext context) {
    final geometry = TimetableGeometry(timetable.periodCount);
    return LayoutBuilder(
      builder: (context, constraints) {
        if (days.length == 1) {
          final width = constraints.maxWidth;
          return SingleChildScrollView(
            child: SizedBox(
              width: width,
              height: geometry.height,
              child: _ReferenceTable(
                timetable: timetable,
                days: days,
                paletteSeed: paletteSeed,
                paletteIndex: paletteIndex,
                fontWeight: fontWeight,
                schedules: schedules,
                courseAppearances: courseAppearances,
                parity: parity,
                onEdit: onEdit,
                previousDay: previousDay,
                nextDay: nextDay,
                courseWidth: math.max(0.0, width - timetableIndexWidth),
              ),
            ),
          );
        }
        return FittedBox(
          fit: BoxFit.contain,
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: geometry.width,
            height: geometry.height,
            child: _ReferenceTable(
              timetable: timetable,
              days: days,
              paletteSeed: paletteSeed,
              paletteIndex: paletteIndex,
              fontWeight: fontWeight,
              schedules: schedules,
              courseAppearances: courseAppearances,
              parity: parity,
              onEdit: onEdit,
              previousDay: previousDay,
              nextDay: nextDay,
              courseWidth: geometry.courseWidth,
            ),
          ),
        );
      },
    );
  }
}

class _ReferenceTable extends StatelessWidget {
  const _ReferenceTable({
    required this.timetable,
    required this.days,
    required this.paletteSeed,
    required this.paletteIndex,
    required this.fontWeight,
    required this.schedules,
    required this.courseAppearances,
    required this.parity,
    required this.onEdit,
    required this.previousDay,
    required this.nextDay,
    required this.courseWidth,
  });

  final Timetable timetable;
  final List<int> days;
  final int paletteSeed;
  final int paletteIndex;
  final FontWeight fontWeight;
  final List<CalendarSchedule> schedules;
  final Map<String, CourseAppearance> courseAppearances;
  final WeekParity? parity;
  final void Function(int weekday, int period, List<Course> meetings) onEdit;
  final VoidCallback? previousDay;
  final VoidCallback? nextDay;
  final double courseWidth;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: timetableCanvas,
      border: Border.all(color: timetableDivider, width: timetableDividerWidth),
    ),
    child: Stack(
      children: [
        Column(
          children: [
            _Header(
              days: days,
              courseWidth: courseWidth,
              previousDay: previousDay,
              nextDay: nextDay,
              fontWeight: fontWeight,
            ),
            for (var period = 1; period <= timetable.periodCount; period++) ...[
              _PeriodRow(
                days: days,
                period: period,
                courseWidth: courseWidth,
                fontWeight: fontWeight,
                onEdit: onEdit,
                drawTopBorder:
                    period > 1 && !timetableMealBreaks.contains(period - 1),
              ),
              if (timetableMealBreaks.contains(period) &&
                  period < timetable.periodCount)
                const _MealBreak(),
            ],
          ],
        ),
        for (final (index, day) in days.indexed)
          Positioned(
            left: timetableIndexWidth + index * courseWidth,
            top: timetableHeaderHeight,
            width: courseWidth,
            bottom: 0,
            child: _DayGroups(
              timetable: timetable,
              day: day,
              courseWidth: courseWidth,
              paletteSeed: paletteSeed,
              paletteIndex: paletteIndex,
              fontWeight: fontWeight,
              schedules: schedules,
              courseAppearances: courseAppearances,
              parity: parity,
              onEdit: onEdit,
            ),
          ),
      ],
    ),
  );
}

class _Header extends StatelessWidget {
  const _Header({
    required this.days,
    required this.courseWidth,
    required this.previousDay,
    required this.nextDay,
    required this.fontWeight,
  });

  final List<int> days;
  final double courseWidth;
  final VoidCallback? previousDay;
  final VoidCallback? nextDay;
  final FontWeight fontWeight;

  @override
  Widget build(BuildContext context) => Container(
    height: timetableHeaderHeight,
    decoration: const BoxDecoration(
      color: timetableIndexSurface,
      border: Border(bottom: BorderSide(color: timetableDivider)),
    ),
    child: Row(
      children: [
        const SizedBox(width: timetableIndexWidth),
        for (final day in days)
          SizedBox(
            width: courseWidth,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Text(
                  AppStrings.of(context).weekday(day),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: timetableMonoFont,
                    fontFamilyFallback: timetableFontFallback,
                    fontSize: 20,
                    fontWeight: fontWeight,
                    color: timetableInk,
                    height: 1,
                  ),
                ),
                if (days.length == 1) ...[
                  Positioned(
                    left: 0,
                    child: IconButton(
                      onPressed: previousDay,
                      tooltip: AppStrings.of(context).text(AppText.previousDay),
                      icon: const Icon(Icons.chevron_left),
                    ),
                  ),
                  Positioned(
                    right: 0,
                    child: IconButton(
                      onPressed: nextDay,
                      tooltip: AppStrings.of(context).text(AppText.nextDay),
                      icon: const Icon(Icons.chevron_right),
                    ),
                  ),
                ],
              ],
            ),
          ),
      ],
    ),
  );
}

class _PeriodRow extends StatelessWidget {
  const _PeriodRow({
    required this.days,
    required this.period,
    required this.courseWidth,
    required this.fontWeight,
    required this.onEdit,
    required this.drawTopBorder,
  });

  final List<int> days;
  final int period;
  final double courseWidth;
  final FontWeight fontWeight;
  final void Function(int weekday, int period, List<Course> meetings) onEdit;
  final bool drawTopBorder;

  @override
  Widget build(BuildContext context) => Container(
    height: timetablePeriodHeight,
    decoration: BoxDecoration(
      border: drawTopBorder
          ? const Border(top: BorderSide(color: timetableDivider))
          : null,
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: timetableIndexWidth,
          child: ColoredBox(
            color: timetableIndexSurface,
            child: _TimeLabel(period: period, fontWeight: fontWeight),
          ),
        ),
        for (final day in days)
          SizedBox(
            width: courseWidth,
            child: _CourseCell(day: day, period: period, onEdit: onEdit),
          ),
      ],
    ),
  );
}

class _TimeLabel extends StatelessWidget {
  const _TimeLabel({required this.period, required this.fontWeight});

  final int period;
  final FontWeight fontWeight;

  @override
  Widget build(BuildContext context) => Center(
    child: Text(
      '$period',
      style: TextStyle(
        fontFamily: timetablePeriodFont,
        fontSize: 30,
        fontWeight: fontWeight,
        color: timetableInk,
        height: 1,
      ),
    ),
  );
}

class _CourseCell extends StatelessWidget {
  const _CourseCell({
    required this.day,
    required this.period,
    required this.onEdit,
  });

  final int day;
  final int period;
  final void Function(int weekday, int period, List<Course> meetings) onEdit;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: timetableCanvas,
      child: InkWell(
        key: ValueKey('timetable-cell-$day-$period'),
        onTap: () => onEdit(day, period, const []),
      ),
    );
  }
}

class _DayGroups extends StatelessWidget {
  const _DayGroups({
    required this.timetable,
    required this.day,
    required this.courseWidth,
    required this.paletteSeed,
    required this.paletteIndex,
    required this.fontWeight,
    required this.schedules,
    required this.courseAppearances,
    required this.parity,
    required this.onEdit,
  });

  final Timetable timetable;
  final int day;
  final double courseWidth;
  final int paletteSeed;
  final int paletteIndex;
  final FontWeight fontWeight;
  final List<CalendarSchedule> schedules;
  final Map<String, CourseAppearance> courseAppearances;
  final WeekParity? parity;
  final void Function(int weekday, int period, List<Course> meetings) onEdit;

  @override
  Widget build(BuildContext context) {
    final geometry = TimetableGeometry(timetable.periodCount);
    final layout = TimetableDayLayout.from(timetable, day, parity: parity);
    final laneWidth = courseWidth / layout.laneCount;
    final sourceNames = {
      for (final course in timetable.meetings)
        course.sourceId: course.sourceName,
    };
    return Stack(
      clipBehavior: Clip.hardEdge,
      children: [
        for (final group in layout.spans)
          Positioned(
            left: group.lane * laneWidth,
            top: geometry.periodTop(group.firstPeriod) - timetableHeaderHeight,
            width: laneWidth,
            height:
                (group.lastPeriod - group.firstPeriod + 1) *
                timetablePeriodHeight,
            child: _MeetingTile(
              group.group.primary,
              firstPeriod: group.firstPeriod,
              lastPeriod: group.lastPeriod,
              isCurrent: group.group.primary.frequency.isCurrent(parity),
              paletteSeed: paletteSeed,
              paletteIndex: paletteIndex,
              fontWeight: fontWeight,
              schedules: schedules
                  .where(
                    (schedule) =>
                        sourceNames[schedule.relatedClassSourceId] ==
                        group.group.primary.sourceName,
                  )
                  .toList(growable: false),
              appearance: courseAppearances[group.group.primary.sourceId],
              onEdit: () =>
                  onEdit(day, group.firstPeriod, group.group.meetings),
            ),
          ),
      ],
    );
  }
}

class _MealBreak extends StatelessWidget {
  const _MealBreak();

  @override
  Widget build(BuildContext context) => Container(
    height: timetableMealBreakHeight,
    decoration: const BoxDecoration(
      color: timetableCanvas,
      border: Border(
        top: BorderSide(color: timetableDivider),
        bottom: BorderSide(color: timetableDivider),
      ),
    ),
  );
}

class _MeetingTile extends StatefulWidget {
  const _MeetingTile(
    this.meeting, {
    required this.firstPeriod,
    required this.lastPeriod,
    required this.isCurrent,
    required this.paletteSeed,
    required this.paletteIndex,
    required this.fontWeight,
    required this.schedules,
    required this.appearance,
    required this.onEdit,
  });

  final Course meeting;
  final int firstPeriod;
  final int lastPeriod;
  final bool isCurrent;
  final int paletteSeed;
  final int paletteIndex;
  final FontWeight fontWeight;
  final List<CalendarSchedule> schedules;
  final CourseAppearance? appearance;
  final VoidCallback onEdit;

  @override
  State<_MeetingTile> createState() => _MeetingTileState();
}

class _MeetingTileState extends State<_MeetingTile> {
  Timer? _hoverTimer;
  OverlayEntry? _details;
  Offset _pointer = Offset.zero;

  void _move(PointerEvent event) {
    _pointer = event.position;
    _details?.markNeedsBuild();
  }

  void _enter(PointerEnterEvent event) {
    _move(event);
    _hoverTimer = Timer(const Duration(milliseconds: 100), _showDetails);
  }

  void _exit(PointerExitEvent event) {
    _hoverTimer?.cancel();
    _removeDetails();
  }

  void _showDetails() {
    if (!mounted || _details != null) return;
    _details = OverlayEntry(
      builder: (context) {
        final size = MediaQuery.sizeOf(context);
        final width = math.min(320.0, size.width - 16);
        final left = (_pointer.dx + 14).clamp(8.0, size.width - width - 8);
        final top = (_pointer.dy + 14)
            .clamp(8.0, math.max(8.0, size.height - 220))
            .toDouble();
        return Positioned(
          key: ValueKey('meeting-hover-${widget.meeting.sourceId}'),
          left: left,
          top: top,
          width: width,
          child: IgnorePointer(
            child: Material(
              elevation: 8,
              color: Theme.of(context).colorScheme.surface,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: _Details(
                  meeting: widget.meeting,
                  firstPeriod: widget.firstPeriod,
                  lastPeriod: widget.lastPeriod,
                  schedules: widget.schedules,
                ),
              ),
            ),
          ),
        );
      },
    );
    Overlay.of(context).insert(_details!);
  }

  void _removeDetails() {
    _details?.remove();
    _details = null;
  }

  @override
  void dispose() {
    _hoverTimer?.cancel();
    _removeDetails();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final meeting = widget.meeting;
    final background = timetableCourseColor(
      meeting,
      widget.paletteSeed,
      appearance: widget.appearance,
      paletteIndex: widget.paletteIndex,
    );
    final foreground = background.computeLuminance() > .5
        ? Colors.black
        : Colors.white;
    return MouseRegion(
      onEnter: _enter,
      onHover: _move,
      onExit: _exit,
      child: Opacity(
        opacity: widget.isCurrent ? 1 : .5,
        child: SizedBox(
          key: ValueKey('meeting-cell-${meeting.sourceId}'),
          width: double.infinity,
          child: Material(
            key: ValueKey('meeting-color-${meeting.sourceId}'),
            color: background,
            child: DecoratedBox(
              key: ValueKey('meeting-outline-${meeting.sourceId}'),
              decoration: BoxDecoration(
                border: widget.appearance?.outlined ?? false
                    ? Border.all(
                        color: widget.appearance!.outlineColor,
                        width: widget.appearance!.outlineWidth,
                      )
                    : null,
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  InkWell(
                    onTap: () {
                      _hoverTimer?.cancel();
                      _removeDetails();
                      widget.onEdit();
                    },
                    child: Padding(
                      key: ValueKey('meeting-content-${meeting.sourceId}'),
                      padding: EdgeInsets.fromLTRB(
                        timetableCourseContentPadding,
                        8,
                        widget.appearance?.color != null
                            ? 30
                            : timetableCourseContentPadding,
                        8,
                      ),
                      child: DefaultTextStyle(
                        style: TextStyle(
                          color: foreground,
                          fontFamily: timetableMonoFont,
                          fontFamilyFallback: timetableFontFallback,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              meeting.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: timetableCourseNameFontSize,
                                fontWeight: widget.fontWeight,
                                height: 1.15,
                                letterSpacing: -.2,
                              ),
                            ),
                            Text(
                              meeting.room.isEmpty ? '' : '  ${meeting.room}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: timetableClassroomFontSize,
                                fontWeight: widget.fontWeight,
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (widget.appearance?.color != null)
                    Positioned(
                      top: 4,
                      right: 4,
                      child: IgnorePointer(
                        child: Container(
                          key: ValueKey('manual-color-${meeting.sourceId}'),
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: foreground,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            widget.appearance!.lockColor
                                ? Icons.lock
                                : Icons.palette,
                            size: 16,
                            color: background,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Details extends StatelessWidget {
  const _Details({
    required this.meeting,
    required this.firstPeriod,
    required this.lastPeriod,
    required this.schedules,
  });

  final Course meeting;
  final int firstPeriod;
  final int lastPeriod;
  final List<CalendarSchedule> schedules;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(meeting.name, style: Theme.of(context).textTheme.titleMedium),
      if (timetableClassStarts[firstPeriod] case final start?)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            '$start–${timetableClassEnd(timetableClassStarts[lastPeriod] ?? start)}',
          ),
        ),
      for (final text in [
        meeting.room,
        meeting.frequencyText,
        meeting.note,
        meeting.exam,
      ])
        if (text.isNotEmpty)
          Padding(padding: const EdgeInsets.only(top: 8), child: Text(text)),
      for (final schedule in schedules)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(_scheduleLabel(schedule)),
        ),
    ],
  );
}

String _scheduleLabel(CalendarSchedule schedule) {
  final value = schedule.startsAt.toUtc().add(const Duration(hours: 8));
  final date =
      '${value.year}-${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
  final time = schedule.allDay
      ? ''
      : ' ${value.hour.toString().padLeft(2, '0')}:'
            '${value.minute.toString().padLeft(2, '0')}';
  return '$date$time · ${schedule.title}';
}
