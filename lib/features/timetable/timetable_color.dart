import 'package:flutter/material.dart';

import '../../domain/course.dart';

const defaultCourseOutlineColor = Color(0xffff0000);
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
  Color(0xff79adac),
  Color(0xffbeadf2),
  Color(0xffa0c8f2),
  Color(0xffadf7b6),
  Color(0xffffea99),
];

// Exact usable palettes from ParkSnoopy/pku-elective-prettify palette.json
// at eaacca788e246a18c36ea013ced2bed6b62bd995. The upstream palette whose
// literal `##ffafcc` entry is invalid is deliberately not normalized.
const rollPalettes = <List<Color>>[
  [
    Color(0xff79adac),
    Color(0xffbeadf2),
    Color(0xffa0c8f2),
    Color(0xffadf7b6),
    Color(0xffffea99),
  ],
  [
    Color(0xff809bce),
    Color(0xff95b8d1),
    Color(0xffb8e0d2),
    Color(0xffd6eadf),
    Color(0xffeac4d5),
  ],
  [
    Color(0xffccd5ae),
    Color(0xffe9edc9),
    Color(0xfffefae0),
    Color(0xfffaedcd),
    Color(0xffd4a373),
  ],
  [
    Color(0xff79addc),
    Color(0xffffc09f),
    Color(0xffffee93),
    Color(0xfffcf5c7),
    Color(0xffadf7b6),
  ],
  [
    Color(0xfff1c494),
    Color(0xfffaf3a5),
    Color(0xff9df79c),
    Color(0xff89d1fb),
    Color(0xffcfaaf6),
  ],
  [
    Color(0xffb7e4ba),
    Color(0xff95d59d),
    Color(0xff74c691),
    Color(0xff52b776),
    Color(0xff40915d),
  ],
  [
    Color(0xffb8d6ec),
    Color(0xfff6c7b7),
    Color(0xffd6c8e8),
    Color(0xfff9f3e3),
    Color(0xffcfcbc5),
  ],
  [
    Color(0xfff0ed5f),
    Color(0xfff3c6fc),
    Color(0xff9de0e7),
    Color(0xffedbb7d),
    Color(0xffb5c4fa),
  ],
  [
    Color(0xffea7d72),
    Color(0xff97851e),
    Color(0xff3e5241),
    Color(0xff2194c2),
    Color(0xffb085de),
  ],
  [
    Color(0xffabb9c2),
    Color(0xffc6d6da),
    Color(0xffa9c7ce),
    Color(0xffc8dce9),
    Color(0xffa3b6ba),
  ],
];

Color timetableCourseColor(
  Course meeting,
  int paletteSeed, {
  CourseAppearance? appearance,
  int paletteIndex = 0,
}) {
  if (appearance?.color case final color?) return color;
  final hash = meeting.sourceName.runes.fold(
    0,
    (value, rune) => (value * 31 + rune) & 0x7fffffff,
  );
  final palette = rollPalettes[paletteIndex];
  return palette[(hash + paletteSeed) % palette.length];
}
