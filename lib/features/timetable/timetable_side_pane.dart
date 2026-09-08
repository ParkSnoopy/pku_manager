import 'package:flutter/material.dart';

import '../../domain/semester.dart';
import '../../domain/timetable.dart';
import '../../l10n/app_strings.dart';
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

class UpcomingClassPane extends StatelessWidget {
  const UpcomingClassPane({
    super.key,
    required this.timetable,
    required this.now,
    required this.onSelected,
    this.calendar,
  });

  final Timetable timetable;
  final DateTime now;
  final ValueChanged<UpcomingCourse> onSelected;
  final SemesterCalendar? calendar;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final upcoming = upcomingCourses(timetable, now, calendar: calendar);
    final item = upcoming.isEmpty ? null : upcoming.first;
    final meeting = item?.group.primary;
    return Material(
      key: const ValueKey('upcoming-class-pane'),
      color: Theme.of(context).colorScheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 16, 12),
            child: Text(
              strings.text(AppText.upcomingClass),
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: item == null || meeting == null
                ? Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(strings.text(AppText.noUpcomingClass)),
                  )
                : ListTile(
                    key: ValueKey('upcoming-class-${meeting.sourceId}'),
                    onTap: () => onSelected(item),
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
                      strings.startsIn(item.startsAt.difference(now)),
                      textAlign: TextAlign.end,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
