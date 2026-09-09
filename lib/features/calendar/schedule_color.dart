import 'package:flutter/material.dart';

import '../../domain/calendar_schedule.dart';

Color scheduleColor(BuildContext context, CalendarSchedule schedule) =>
    schedule.colorValue == null
    ? Theme.of(context).colorScheme.primary
    : Color(schedule.colorValue!);

Color scheduleForeground(Color background) =>
    background.computeLuminance() > .5 ? Colors.black : Colors.white;
