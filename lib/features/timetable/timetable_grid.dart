import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/calendar_schedule.dart';
import '../../domain/course.dart';
import '../../domain/timetable.dart';
import '../../domain/week_frequency.dart';
import '../../l10n/app_strings.dart';
import '../../ui/flashing_outline.dart';
import '../../ui/following_hover_card.dart';
import 'timetable_color.dart';
import 'timetable_style.dart';

class TimetableGrid extends StatelessWidget {
  const TimetableGrid({
    super.key,
    required this.timetable,
    required this.days,
    required this.paletteSeed,
    required this.paletteIndex,
    required this.customPalette,
    required this.fontWeight,
    required this.fontScale,
    required this.onEdit,
    this.focusedCourseSourceIds = const {},
    this.indexColor = timetableIndexSurface,
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
  final List<Color> customPalette;
  final FontWeight fontWeight;
  final double fontScale;
  final Set<String> focusedCourseSourceIds;
  final Color indexColor;
  final List<CalendarSchedule> schedules;
  final Map<String, CourseAppearance> courseAppearances;
  final void Function(int weekday, int period, List<Course> meetings) onEdit;
  final WeekParity? parity;
  final VoidCallback? previousDay;
  final VoidCallback? nextDay;

  @override
  Widget build(BuildContext context) {
    final geometry = TimetableGeometry(timetable.periodCount);
    final theme = Theme.of(context);
    final effectiveIndexColor = themedTimetableColor(
      indexColor,
      brightness: theme.brightness,
      surface: theme.colorScheme.surface,
    );
    final inheritedScale = MediaQuery.textScalerOf(context).scale(1);
    return MediaQuery(
      data: MediaQuery.of(context)
          .copyWith(textScaler: TextScaler.linear(inheritedScale * fontScale)),
      child: LayoutBuilder(
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
                  customPalette: customPalette,
                  fontWeight: fontWeight,
                  focusedCourseSourceIds: focusedCourseSourceIds,
                  indexColor: effectiveIndexColor,
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
                customPalette: customPalette,
                fontWeight: fontWeight,
                focusedCourseSourceIds: focusedCourseSourceIds,
                indexColor: effectiveIndexColor,
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
      ),
    );
  }
}

class _ReferenceTable extends StatelessWidget {
  const _ReferenceTable({
    required this.timetable,
    required this.days,
    required this.paletteSeed,
    required this.paletteIndex,
    required this.customPalette,
    required this.fontWeight,
    required this.focusedCourseSourceIds,
    required this.indexColor,
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
  final List<Color> customPalette;
  final FontWeight fontWeight;
  final Set<String> focusedCourseSourceIds;
  final Color indexColor;
  final List<CalendarSchedule> schedules;
  final Map<String, CourseAppearance> courseAppearances;
  final WeekParity? parity;
  final void Function(int weekday, int period, List<Course> meetings) onEdit;
  final VoidCallback? previousDay;
  final VoidCallback? nextDay;
  final double courseWidth;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    key: const ValueKey('timetable-grid-background'),
    decoration: BoxDecoration(
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
              color: indexColor,
            ),
            for (var period = 1; period <= timetable.periodCount; period++) ...[
              _PeriodRow(
                days: days,
                period: period,
                courseWidth: courseWidth,
                fontWeight: fontWeight,
                indexColor: indexColor,
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
              customPalette: customPalette,
              fontWeight: fontWeight,
              focusedCourseSourceIds: focusedCourseSourceIds,
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
    required this.color,
  });

  final List<int> days;
  final double courseWidth;
  final VoidCallback? previousDay;
  final VoidCallback? nextDay;
  final FontWeight fontWeight;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final foreground = timetableContrastForeground(color);
    return Container(
      key: const ValueKey('timetable-weekday-row'),
      height: timetableHeaderHeight,
      decoration: BoxDecoration(
        color: color,
        border: const Border(bottom: BorderSide(color: timetableDivider)),
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
                    key: ValueKey('timetable-weekday-$day'),
                    AppStrings.of(context).weekday(day),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.fontFamily,
                      fontSize: 20,
                      fontWeight: fontWeight,
                      color: foreground,
                      height: 1,
                    ),
                  ),
                  if (days.length == 1) ...[
                    Positioned(
                      left: 0,
                      child: IconButton(
                        onPressed: previousDay,
                        tooltip: AppStrings.of(context)
                            .text(AppText.previousDay),
                        icon: Icon(Icons.chevron_left, color: foreground),
                      ),
                    ),
                    Positioned(
                      right: 0,
                      child: IconButton(
                        onPressed: nextDay,
                        tooltip: AppStrings.of(context).text(AppText.nextDay),
                        icon: Icon(Icons.chevron_right, color: foreground),
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
}

class _PeriodRow extends StatelessWidget {
  const _PeriodRow({
    required this.days,
    required this.period,
    required this.courseWidth,
    required this.fontWeight,
    required this.indexColor,
    required this.onEdit,
    required this.drawTopBorder,
  });

  final List<int> days;
  final int period;
  final double courseWidth;
  final FontWeight fontWeight;
  final Color indexColor;
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
            key: ValueKey('timetable-index-$period'),
            color: indexColor,
            child: _TimeLabel(
              period: period,
              fontWeight: fontWeight,
              color: timetableContrastForeground(indexColor),
            ),
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
  const _TimeLabel({
    required this.period,
    required this.fontWeight,
    required this.color,
  });

  final int period;
  final FontWeight fontWeight;
  final Color color;

  @override
  Widget build(BuildContext context) => Center(
    child: Text(
      key: ValueKey('timetable-index-label-$period'),
      '$period',
      style: TextStyle(
        fontFamily: Theme.of(context).textTheme.bodyMedium?.fontFamily,
        fontSize: 30,
        fontWeight: fontWeight,
        color: color,
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
      color: Colors.transparent,
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
    required this.customPalette,
    required this.fontWeight,
    required this.focusedCourseSourceIds,
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
  final List<Color> customPalette;
  final FontWeight fontWeight;
  final Set<String> focusedCourseSourceIds;
  final List<CalendarSchedule> schedules;
  final Map<String, CourseAppearance> courseAppearances;
  final WeekParity? parity;
  final void Function(int weekday, int period, List<Course> meetings) onEdit;

  @override
  Widget build(BuildContext context) {
    final geometry = TimetableGeometry(timetable.periodCount);
    final layout = TimetableDayLayout.from(timetable, day, parity: parity);
    final laneWidth = courseWidth / layout.laneCount;
    final conflictingSourceIds = timetable.conflictingSourceIds;
    final courseColors = timetableCourseColors(
      timetable,
      paletteSeed,
      courseAppearances: courseAppearances,
      paletteIndex: paletteIndex,
      customPalette: customPalette,
    );
    return Stack(
      clipBehavior: Clip.hardEdge,
      children: [
        for (final span in layout.spans)
          Positioned(
            left: span.lane * laneWidth,
            top: geometry.periodTop(span.firstPeriod) - timetableHeaderHeight,
            width: laneWidth,
            height:
                (span.lastPeriod - span.firstPeriod + 1) *
                timetablePeriodHeight,
            child: _MeetingTile(
              span.meeting,
              firstPeriod: span.firstPeriod,
              lastPeriod: span.lastPeriod,
              isCurrent: span.meeting.frequency.isCurrent(parity),
              conflicting: conflictingSourceIds.contains(span.meeting.sourceId),
              color: courseColors[span.meeting.sourceId]!,
              fontWeight: fontWeight,
              focused: focusedCourseSourceIds.contains(span.meeting.sourceId),
              schedules: schedules
                  .where(
                    (schedule) =>
                        schedule.relatedClassSourceId == span.meeting.sourceId,
                  )
                  .toList(growable: false),
              appearance: courseAppearances[span.meeting.sourceId],
              onEdit: () => onEdit(day, span.firstPeriod, [span.meeting]),
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
    required this.conflicting,
    required this.color,
    required this.fontWeight,
    required this.focused,
    required this.schedules,
    required this.appearance,
    required this.onEdit,
  });

  final Course meeting;
  final int firstPeriod;
  final int lastPeriod;
  final bool isCurrent;
  final bool conflicting;
  final Color color;
  final FontWeight fontWeight;
  final bool focused;
  final List<CalendarSchedule> schedules;
  final CourseAppearance? appearance;
  final VoidCallback onEdit;

  @override
  State<_MeetingTile> createState() => _MeetingTileState();
}

class _MeetingTileState extends State<_MeetingTile> {
  @override
  Widget build(BuildContext context) {
    final meeting = widget.meeting;
    final theme = Theme.of(context);
    final background = themedTimetableColor(
      widget.color,
      brightness: theme.brightness,
      surface: theme.colorScheme.surface,
    );
    final foreground = timetableContrastForeground(background);
    final outline = widget.conflicting
        ? Border.all(
            color: timetableConflictColor,
            width: timetableConflictWidth,
          )
        : widget.appearance?.outlined ?? false
        ? Border.all(
            color: widget.appearance!.outlineColor,
            width: widget.appearance!.outlineWidth,
          )
        : const Border(
            bottom: BorderSide(
              color: timetableDivider,
              width: timetableDividerWidth,
            ),
          );
    return FollowingHoverCard(
      cardKey: ValueKey('meeting-hover-${widget.meeting.sourceId}'),
      cursor: SystemMouseCursors.click,
      card: _Details(
        meeting: widget.meeting,
        firstPeriod: widget.firstPeriod,
        lastPeriod: widget.lastPeriod,
        schedules: widget.schedules,
      ),
      child: Opacity(
        opacity: widget.isCurrent ? 1 : .25,
        child: SizedBox(
          key: ValueKey('meeting-cell-${meeting.sourceId}'),
          width: double.infinity,
          child: Material(
            key: ValueKey('meeting-color-${meeting.sourceId}'),
            color: background,
            child: FlashingOutline(
              key: ValueKey('meeting-flash-${meeting.sourceId}'),
              active: widget.focused,
              child: DecoratedBox(
                key: ValueKey('meeting-outline-${meeting.sourceId}'),
                decoration: BoxDecoration(border: outline),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    InkWell(
                      onTap: widget.onEdit,
                      child: widget.isCurrent
                          ? Padding(
                              key: ValueKey(
                                'meeting-content-${meeting.sourceId}',
                              ),
                              padding: const EdgeInsets.all(
                                timetableCourseContentPadding,
                              ),
                              child: DefaultTextStyle(
                                key: ValueKey(
                                  'meeting-text-style-${meeting.sourceId}',
                                ),
                                style: TextStyle(
                                  color: foreground,
                                  fontFamily: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.fontFamily,
                                ),
                                child: SingleChildScrollView(
                                  physics: const NeverScrollableScrollPhysics(),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        meeting.displayName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: timetableCourseNameFontSize,
                                          fontWeight:
                                              timetableCourseNameFontWeight,
                                          height: 1.5,
                                          letterSpacing: -.2,
                                        ),
                                      ),
                                      if (meeting.room.isNotEmpty) ...[
                                        Text(
                                          '  ${meeting.room}',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize:
                                                timetableClassroomFontSize,
                                            fontWeight: widget.fontWeight,
                                            height: 1.5,
                                          ),
                                        ),
                                      ],
                                      if (meeting.note.isNotEmpty) ...[
                                        const SizedBox(
                                          height:
                                              timetableClassroomFontSize * 1.5,
                                        ),
                                        Text(
                                          meeting.note,
                                          softWrap: true,
                                          style: TextStyle(
                                            fontSize:
                                                timetableCourseNoteFontSize,
                                            fontWeight: widget.fontWeight,
                                            height: 1.5,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            )
                          : null,
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
  Widget build(BuildContext context) {
    final items = <Widget>[
      Text(meeting.displayName, style: Theme.of(context).textTheme.titleMedium),
      if (timetableClassStarts[firstPeriod] case final start?)
        Text(
          '$start–${timetableClassEnd(timetableClassStarts[lastPeriod] ?? start)}',
        ),
      for (final text in [
        meeting.room,
        meeting.frequencyText,
        meeting.note,
        meeting.exam,
      ])
        if (text.isNotEmpty) Text(text),
      for (final schedule in schedules) Text(_scheduleLabel(schedule)),
    ];
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (index, item) in items.indexed) ...[
          if (index > 0) const Divider(height: 17),
          item,
        ],
      ],
    );
  }
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
