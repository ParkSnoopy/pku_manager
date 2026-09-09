import 'package:flutter/material.dart';

import '../../domain/calendar_schedule.dart';
import '../../domain/semester.dart';
import '../../domain/timetable.dart';
import '../../l10n/app_strings.dart';
import '../calendar/schedule_color.dart';
import '../calendar/upcoming_schedules_pane.dart';
import 'timetable_style.dart';
import 'upcoming_course.dart';

class UpcomingClassPane extends StatelessWidget {
  const UpcomingClassPane({
    super.key,
    required this.timetable,
    required this.now,
    required this.onSelected,
    required this.schedules,
    required this.onScheduleSelected,
    this.autoTextColor = false,
    this.calendar,
  });

  final Timetable timetable;
  final DateTime now;
  final ValueChanged<UpcomingCourse> onSelected;
  final List<CalendarSchedule> schedules;
  final ValueChanged<CalendarSchedule> onScheduleSelected;
  final bool autoTextColor;
  final SemesterCalendar? calendar;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final courses = tomorrowCourses(timetable, now, calendar: calendar);
    final upcomingSchedules = schedules
        .where((schedule) => isUpcomingSchedule(schedule, now))
        .toList(growable: false);
    final sourceNames = {
      for (final course in timetable.meetings)
        course.sourceId: course.sourceName,
    };
    List<CalendarSchedule> schedulesFor(UpcomingCourse course) =>
        upcomingSchedules
            .where(
              (schedule) =>
                  sourceNames[schedule.relatedClassSourceId] ==
                  course.group.primary.sourceName,
            )
            .toList(growable: false);
    final unrelated = upcomingSchedules
        .where((schedule) => schedule.relatedClassSourceId == null)
        .toList(growable: false);
    return Material(
      key: const ValueKey('upcoming-class-pane'),
      color: Theme.of(context).colorScheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 16, 12),
            child: Text(
              strings.text(AppText.tomorrowClasses),
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: courses.isEmpty && unrelated.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(strings.text(AppText.noClassesTomorrow)),
                  )
                : ListView(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    children: [
                      for (final item in courses) ...[
                        MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: ListTile(
                            key: ValueKey(
                              'upcoming-class-${item.group.primary.sourceId}',
                            ),
                            onTap: () => onSelected(item),
                            title: Text(
                              item.group.primary.displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(
                              '${timetableClassStarts[item.group.firstPeriod]}'
                              '${item.group.primary.room.isEmpty ? '' : ' · ${item.group.primary.room}'}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                        ),
                        for (final schedule in schedulesFor(item))
                          _ScheduleEntry(
                            schedule: schedule,
                            now: now,
                            autoTextColor: autoTextColor,
                            onTap: () => onScheduleSelected(schedule),
                          ),
                        const Divider(height: 1),
                      ],
                      if (unrelated.isNotEmpty) ...[
                        const Divider(height: 24, thickness: 2),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 0, 16, 8),
                          child: Text(
                            strings.text(AppText.unrelatedSchedules),
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                        ),
                        for (final schedule in unrelated)
                          _ScheduleEntry(
                            schedule: schedule,
                            now: now,
                            autoTextColor: autoTextColor,
                            onTap: () => onScheduleSelected(schedule),
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

class _ScheduleEntry extends StatelessWidget {
  const _ScheduleEntry({
    required this.schedule,
    required this.now,
    required this.autoTextColor,
    required this.onTap,
  });

  final CalendarSchedule schedule;
  final DateTime now;
  final bool autoTextColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final background = scheduleColor(context, schedule);
    final foreground = scheduleForeground(
      context,
      background,
      autoTextColor: autoTextColor,
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 8, 8),
      child: Material(
        key: ValueKey('tomorrow-schedule-color-${schedule.id}'),
        color: background,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: ListTile(
            key: ValueKey('tomorrow-schedule-${schedule.id}'),
            onTap: onTap,
            textColor: foreground,
            dense: true,
            title: Text(
              schedule.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              '${schedule.allDay ? scheduleDateLabel(schedule) : '${scheduleDateLabel(schedule)} ${scheduleTimeLabel(schedule)}'}\n'
              '${AppStrings.of(context).deadline(scheduleDeadline(schedule).difference(now))}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ),
    );
  }
}
