import 'package:flutter/material.dart';

import '../../domain/semester.dart';
import '../../domain/timetable.dart';
import '../../l10n/app_strings.dart';
import 'timetable_style.dart';

final class UpcomingCourse {
  const UpcomingCourse({required this.group, required this.startsAt});

  final CourseMeetingGroup group;
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

class UpcomingClassesPane extends StatelessWidget {
  const UpcomingClassesPane({
    super.key,
    required this.timetable,
    required this.now,
    this.calendar,
    this.mode = UpcomingPaneMode.schedule,
  });

  final Timetable timetable;
  final DateTime now;
  final SemesterCalendar? calendar;
  final UpcomingPaneMode mode;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final upcoming = upcomingCourses(timetable, now, calendar: calendar);
    final visible = mode == UpcomingPaneMode.nextClass
        ? upcoming.take(1).toList(growable: false)
        : upcoming;
    return Material(
      key: ValueKey(
        mode == UpcomingPaneMode.schedule
            ? 'upcoming-schedule-pane'
            : 'upcoming-class-pane',
      ),
      color: Theme.of(context).colorScheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 16, 12),
            child: Text(
              strings.text(
                mode == UpcomingPaneMode.schedule
                    ? AppText.upcomingSchedule
                    : AppText.upcomingClass,
              ),
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: visible.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(
                      strings.text(
                        mode == UpcomingPaneMode.schedule
                            ? AppText.noUpcomingSchedule
                            : AppText.noUpcomingClass,
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: visible.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final item = visible[index];
                      final meeting = item.group.primary;
                      final remaining = item.startsAt.difference(now);
                      return ListTile(
                        key: ValueKey('upcoming-course-${meeting.sourceId}'),
                        title: Text(
                          meeting.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          '${strings.weekday(meeting.weekday)} '
                          '${timetableClassStarts[item.group.firstPeriod]}'
                          '${meeting.room.isEmpty ? '' : ' · ${meeting.room}'}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 14),
                        ),
                        trailing: Text(
                          strings.startsIn(remaining),
                          textAlign: TextAlign.end,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

enum UpcomingPaneMode { schedule, nextClass }
