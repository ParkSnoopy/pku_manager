import 'package:flutter/material.dart';

import '../../domain/calendar_schedule.dart';
import '../../ui/colored_text.dart';

Color scheduleColor(BuildContext context, CalendarSchedule schedule) =>
    schedule.colorValue == null
    ? Theme.of(context).colorScheme.primary
    : Color(schedule.colorValue!);

Color scheduleForeground(
  BuildContext context,
  Color background, {
  required bool autoTextColor,
}) => coloredTextForeground(context, background, autoTextColor: autoTextColor);
