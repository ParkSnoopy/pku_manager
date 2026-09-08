import 'package:flutter/material.dart';

import '../../domain/calendar_schedule.dart';
import '../../l10n/app_strings.dart';
import 'calendar_schedule_controller.dart';
import 'schedule_color.dart';

class UpcomingSchedulesPane extends StatelessWidget {
  const UpcomingSchedulesPane({
    super.key,
    required this.controller,
    required this.now,
    required this.onSelected,
  });

  final CalendarScheduleController controller;
  final DateTime now;
  final ValueChanged<CalendarSchedule> onSelected;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      final strings = AppStrings.of(context);
      final schedules = controller.schedules
          .where((schedule) => _isUpcoming(schedule, now))
          .toList(growable: false);
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
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: schedules.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final schedule = schedules[index];
                        final background = scheduleColor(schedule.id);
                        final foreground = scheduleForeground(background);
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Material(
                            key: ValueKey(
                              'upcoming-schedule-color-${schedule.id}',
                            ),
                            color: background,
                            child: ListTile(
                              key: ValueKey('upcoming-schedule-${schedule.id}'),
                              onTap: () => onSelected(schedule),
                              textColor: foreground,
                              title: Text(
                                schedule.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 15),
                              ),
                              subtitle: Text(
                                _dateLabel(schedule),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 14),
                              ),
                              trailing: Text(
                                schedule.allDay
                                    ? strings.text(AppText.allDay)
                                    : _timeLabel(schedule),
                                textAlign: TextAlign.end,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
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
      );
    },
  );
}

String _dateLabel(CalendarSchedule schedule) {
  final value = schedule.startsAt.toUtc().add(const Duration(hours: 8));
  return '${value.year}-${_two(value.month)}-${_two(value.day)}';
}

String _timeLabel(CalendarSchedule schedule) {
  final value = schedule.startsAt.toUtc().add(const Duration(hours: 8));
  return '${_two(value.hour)}:${_two(value.minute)}';
}

bool _isUpcoming(CalendarSchedule schedule, DateTime now) {
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

String _two(int value) => value.toString().padLeft(2, '0');
