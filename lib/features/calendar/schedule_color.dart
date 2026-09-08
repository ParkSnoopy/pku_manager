import 'package:flutter/material.dart';

import '../../domain/calendar_schedule.dart';

Color scheduleColor(CalendarSchedule schedule) => Color(schedule.colorValue);

Color scheduleForeground(Color background) =>
    background.computeLuminance() > .5 ? Colors.black : Colors.white;
