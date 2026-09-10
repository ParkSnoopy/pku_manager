import 'package:flutter/material.dart';

import '../../domain/calendar_schedule.dart';
import '../../domain/semester.dart';
import '../../domain/timetable.dart';
import '../../l10n/app_strings.dart';
import '../../ui/following_hover_card.dart';
import '../timetable/upcoming_course.dart';
import 'calendar_schedule_controller.dart';
import 'schedule_color.dart';

class UpcomingSchedulesPane extends StatelessWidget {
  const UpcomingSchedulesPane({
    super.key,
    required this.controller,
    required this.now,
    required this.onSelected,
    required this.onEdit,
    required this.onClassSelected,
    required this.onClassEdit,
    this.timetable,
    this.calendar,
  });

  final CalendarScheduleController controller;
  final DateTime now;
  final ValueChanged<CalendarSchedule> onSelected;
  final ValueChanged<CalendarSchedule> onEdit;
  final ValueChanged<UpcomingCourse> onClassSelected;
  final ValueChanged<UpcomingCourse> onClassEdit;
  final Timetable? timetable;
  final SemesterCalendar? calendar;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      final strings = AppStrings.of(context);
      final schedules = controller.schedules
          .where((schedule) => isUpcomingSchedule(schedule, now))
          .toList(growable: false);
      final courses = timetable == null
          ? const <UpcomingCourse>[]
          : upcomingCourses(timetable!, now, calendar: calendar);
      return Material(
        key: const ValueKey('upcoming-schedule-pane'),
        color: Theme.of(context).colorScheme.surface,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 16, 12),
              child: Text(
                strings.text(AppText.upcomingSchedule),
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: schedules.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text(strings.text(AppText.noUpcomingSchedule)),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: schedules.length * 2 - 1,
                      itemBuilder: (context, index) {
                        if (index.isOdd) {
                          return SizedBox(
                            key: ValueKey(
                              'upcoming-schedule-gap-${index ~/ 2}',
                            ),
                            height: 12,
                          );
                        }
                        final schedule = schedules[index ~/ 2];
                        final background = scheduleColor(context, schedule);
                        final foreground = scheduleForeground(background);
                        final relatedClass = courses
                            .where(
                              (course) => course.group.meetings.any(
                                (meeting) =>
                                    meeting.sourceId ==
                                    schedule.relatedClassSourceId,
                              ),
                            )
                            .firstOrNull;
                        return _ScheduleWithClassEntry(
                          schedule: schedule,
                          now: now,
                          background: background,
                          foreground: foreground,
                          relatedClass: relatedClass,
                          onScheduleTap: () => onEdit(schedule),
                          onScheduleDoubleTap: () => onSelected(schedule),
                          onClassTap: relatedClass == null
                              ? null
                              : () => onClassEdit(relatedClass),
                          onClassDoubleTap: relatedClass == null
                              ? null
                              : () => onClassSelected(relatedClass),
                        );
                      },
                    ),
            ),
          ],
        ),
      );
    },
  );
}

class _ScheduleWithClassEntry extends StatelessWidget {
  const _ScheduleWithClassEntry({
    required this.schedule,
    required this.now,
    required this.background,
    required this.foreground,
    required this.relatedClass,
    required this.onScheduleTap,
    required this.onScheduleDoubleTap,
    required this.onClassTap,
    required this.onClassDoubleTap,
  });

  final CalendarSchedule schedule;
  final DateTime now;
  final Color background;
  final Color foreground;
  final UpcomingCourse? relatedClass;
  final VoidCallback onScheduleTap;
  final VoidCallback onScheduleDoubleTap;
  final VoidCallback? onClassTap;
  final VoidCallback? onClassDoubleTap;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final course = relatedClass;
    final colors = Theme.of(context).colorScheme;
    final deadline = scheduleDeadline(schedule).difference(now);
    const deadlineLabelSize = 14.0;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FollowingHoverCard(
            cardKey: ValueKey('upcoming-schedule-hover-card-${schedule.id}'),
            cursor: SystemMouseCursors.click,
            card: _ScheduleHoverDetails(schedule: schedule),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onScheduleTap,
              onDoubleTap: onScheduleDoubleTap,
              onSecondaryTap: onScheduleTap,
              onLongPress: onScheduleTap,
              child: Material(
                key: ValueKey('upcoming-schedule-color-${schedule.id}'),
                color: background,
                child: ListTile(
                  key: ValueKey('upcoming-schedule-${schedule.id}'),
                  textColor: foreground,
                  title: Text(
                    schedule.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 15),
                  ),
                  subtitle: Text(
                    key: ValueKey('upcoming-schedule-info-${schedule.id}'),
                    schedule.allDay
                        ? scheduleDateLabel(schedule)
                        : '${scheduleDateLabel(schedule)} ${scheduleTimeLabel(schedule)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14),
                  ),
                  trailing: Text.rich(
                    key: ValueKey('upcoming-schedule-deadline-${schedule.id}'),
                    TextSpan(
                      children: [
                        const TextSpan(
                          text: 'DDL: ',
                          style: TextStyle(fontSize: deadlineLabelSize),
                        ),
                        TextSpan(
                          text: strings.deadlineValue(deadline),
                          style: const TextStyle(
                            fontSize: deadlineLabelSize * 1.25,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end,
                  ),
                ),
              ),
            ),
          ),
          if (course != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 0, 0),
              child: Material(
                key: ValueKey('upcoming-related-class-${schedule.id}'),
                color: colors.secondaryContainer,
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: InkWell(
                    onTap: onClassTap,
                    onDoubleTap: onClassDoubleTap,
                    child: ListTile(
                      textColor: colors.onSecondaryContainer,
                      dense: true,
                      leading: const Icon(Icons.school_outlined),
                      title: Text(
                        course.group.primary.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        '${beijingDateLabel(course.startsAt)} '
                        '${beijingTimeLabel(course.startsAt)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ScheduleHoverDetails extends StatelessWidget {
  const _ScheduleHoverDetails({required this.schedule});

  final CalendarSchedule schedule;

  @override
  Widget build(BuildContext context) {
    final items = <Widget>[
      Text(schedule.title, style: Theme.of(context).textTheme.titleMedium),
      Text(
        schedule.allDay
            ? scheduleDateLabel(schedule)
            : '${scheduleDateLabel(schedule)} ${scheduleTimeLabel(schedule)}',
      ),
      if (schedule.note.isNotEmpty) Text(schedule.note),
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

String scheduleDateLabel(CalendarSchedule schedule) {
  return beijingDateLabel(schedule.startsAt);
}

String beijingDateLabel(DateTime instant) {
  final value = instant.toUtc().add(const Duration(hours: 8));
  return '${value.year}-${_two(value.month)}-${_two(value.day)}';
}

String scheduleTimeLabel(CalendarSchedule schedule) {
  return beijingTimeLabel(schedule.startsAt);
}

String beijingTimeLabel(DateTime instant) {
  final value = instant.toUtc().add(const Duration(hours: 8));
  return '${_two(value.hour)}:${_two(value.minute)}';
}

bool isUpcomingSchedule(CalendarSchedule schedule, DateTime now) {
  if (!schedule.allDay) return schedule.startsAt.isAfter(now);
  final scheduleDate = schedule.startsAt.toUtc().add(const Duration(hours: 8));
  final nowDate = now.toUtc().add(const Duration(hours: 8));
  return DateTime.utc(
        scheduleDate.year,
        scheduleDate.month,
        scheduleDate.day,
      ).compareTo(DateTime.utc(nowDate.year, nowDate.month, nowDate.day)) >=
      0;
}

DateTime scheduleDeadline(CalendarSchedule schedule) =>
    normalizedScheduleStart(schedule.startsAt, schedule.allDay);

String _two(int value) => value.toString().padLeft(2, '0');
