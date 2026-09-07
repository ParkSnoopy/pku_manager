import 'package:flutter/material.dart';

import '../../domain/course_meeting.dart';

Color timetableCourseColor(CourseMeeting meeting, int paletteSeed) {
  final hash = meeting.name.runes.fold(
    0,
    (value, rune) => (value * 31 + rune) & 0x7fffffff,
  );
  return HSLColor.fromAHSL(
    1,
    ((hash + paletteSeed * 67) % 360).toDouble(),
    .38,
    .91,
  ).toColor();
}
