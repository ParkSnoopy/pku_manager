import 'package:flutter/material.dart';

import '../../domain/calendar_schedule.dart';
import '../../domain/semester.dart';
import '../../domain/timetable.dart';
import '../../l10n/app_strings.dart';
import '../calendar/schedule_color.dart';
import '../calendar/upcoming_schedules_pane.dart';
import 'timetable_style.dart';

final class UpcomingCourse {
  const UpcomingCourse({required this.group, required this.startsAt});

  final CourseGroup group;
  final DateTime startsAt;
}

List<UpcomingCourse> upcomingCourses(
  Timetable timetable,
  DateTime now, {
  SemesterCalendar? calendar,
}) {
  final result = <UpcomingCourse>[];
  final beijingNow = now.toUtc().add(const Duration(hours: 8));
  for (var day = 1; day <= 5; day++) {
    for (final group in timetable.groupsForDay(day)) {
      final start = timetableClassStarts[group.firstPeriod];
      if (start == null) continue;
      final parts = start.split(':').map(int.parse).toList(growable: false);
      for (var offset = 0; offset <= 14; offset++) {
        final beijingDate = DateTime.utc(
          beijingNow.year,
          beijingNow.month,
          beijingNow.day + offset,
        );
        if (beijingDate.weekday != group.weekday) continue;
        final startsAt = DateTime.utc(
          beijingDate.year,
          beijingDate.month,
          beijingDate.day,
          parts[0],
          parts[1],
        ).subtract(const Duration(hours: 8));
        if (!startsAt.isAfter(now)) continue;
        final semesterWeek = calendar?.weekAt(startsAt);
        if (calendar != null && semesterWeek == null) continue;
        final parity = semesterWeek?.parity;
        if (!group.primary.frequency.isCurrent(parity)) continue;
        result.add(UpcomingCourse(group: group, startsAt: startsAt));
        break;
      }
    }
  }
  result.sort((a, b) => a.startsAt.compareTo(b.startsAt));
  return List.unmodifiable(result);
}

List<UpcomingCourse> tomorrowCourses(
  Timetable timetable,
  DateTime now, {
  SemesterCalendar? calendar,
}) {
  final beijingNow = now.toUtc().add(const Duration(hours: 8));
  final tomorrow = DateTime.utc(
    beijingNow.year,
    beijingNow.month,
    beijingNow.day + 1,
  );
  return List.unmodifiable(
    upcomingCourses(timetable, now, calendar: calendar).where((course) {
      final date = course.startsAt.toUtc().add(const Duration(hours: 8));
      return date.year == tomorrow.year &&
          date.month == tomorrow.month &&
          date.day == tomorrow.day;
    }),
  );
}

class UpcomingClassPane extends StatelessWidget {
  const UpcomingClassPane({
    super.key,
    required this.timetable,
    required this.now,
    required this.onSelected,
    required this.schedules,
    required this.onScheduleSelected,
    this.calendar,
  });

  final Timetable timetable;
  final DateTime now;
  final ValueChanged<UpcomingCourse> onSelected;
  final List<CalendarSchedule> schedules;
  final ValueChanged<CalendarSchedule> onScheduleSelected;
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
                        ListTile(
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
                        for (final schedule in schedulesFor(item))
                          _ScheduleEntry(
                            schedule: schedule,
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
  const _ScheduleEntry({required this.schedule, required this.onTap});

  final CalendarSchedule schedule;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final background = scheduleColor(schedule);
    final foreground = scheduleForeground(background);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 8, 8),
      child: Material(
        key: ValueKey('tomorrow-schedule-color-${schedule.id}'),
        color: background,
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
            schedule.allDay
                ? scheduleDateLabel(schedule)
                : '${scheduleDateLabel(schedule)} ${scheduleTimeLabel(schedule)}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }
}
