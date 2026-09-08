import 'package:flutter/material.dart';

import '../../domain/course_meeting.dart';

const defaultCourseOutlineColor = Color(0xffffff00);
const defaultCourseOutlineWidth = 1.5;

final class CourseAppearance {
  const CourseAppearance({
    this.color,
    this.lockColor = true,
    this.outlined = false,
    this.outlineColor = defaultCourseOutlineColor,
    this.outlineWidth = defaultCourseOutlineWidth,
  }) : assert(outlineWidth >= .5 && outlineWidth <= 6);

  final Color? color;
  final bool lockColor;
  final bool outlined;
  final Color outlineColor;
  final double outlineWidth;

  CourseAppearance withoutUnlockedColor() => CourseAppearance(
    lockColor: lockColor,
    outlined: outlined,
    outlineColor: outlineColor,
    outlineWidth: outlineWidth,
  );

  bool get isEmpty => color == null && !outlined;

  @override
  bool operator ==(Object other) =>
      other is CourseAppearance &&
      color == other.color &&
      lockColor == other.lockColor &&
      outlined == other.outlined &&
      outlineColor == other.outlineColor &&
      outlineWidth == other.outlineWidth;

  @override
  int get hashCode =>
      Object.hash(color, lockColor, outlined, outlineColor, outlineWidth);
}

const courseColorChoices = <Color>[
  Color(0xffffcdd2),
  Color(0xffffe0b2),
  Color(0xfffff9c4),
  Color(0xffc8e6c9),
  Color(0xffb2dfdb),
  Color(0xffbbdefb),
  Color(0xffd1c4e9),
  Color(0xfff8bbd0),
];

Color timetableCourseColor(
  CourseMeeting meeting,
  int paletteSeed, {
  CourseAppearance? appearance,
}) {
  if (appearance?.color case final color?) return color;
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
