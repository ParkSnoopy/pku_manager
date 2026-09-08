import 'dart:math' as math;

import 'package:flutter/material.dart';

const timetableCanvas = Color(0xfffaf9f5);
const timetableIndexSurface = Color(0xffe8e0d2);
const timetableInk = Color(0xff141413);
const timetableBody = Color(0xff3d3d3a);
const timetableMuted = Color(0xff6c6a64);
const timetableDivider = Color(0xff92918d);

const timetableMonoFont = 'Roboto Mono Reference';
const timetableSansFont = 'Noto Sans CJK SC';
const timetableSerifFont = 'Noto Serif CJK SC';
const timetableFontFallback = <String>[timetableSansFont];

const timetableHeaderHeight = 44.0;
const timetablePeriodHeight = 100.0;
const timetableMealBreakHeight = 30.0;
const timetableIndexWidth = 120.0;
const timetableExportPadding = 12.0;
const timetableExportScale = 4.0;
const timetableAspectRatio = 1.15;
const timetableDividerWidth = 1.0;
const timetableMealBreaks = <int>{4, 9};

const timetableClassStarts = <int, String>{
  1: '08:00',
  2: '09:00',
  3: '10:10',
  4: '11:10',
  5: '13:00',
  6: '14:00',
  7: '15:10',
  8: '16:10',
  9: '17:10',
  10: '18:40',
  11: '19:40',
  12: '20:40',
};

final class TimetableGeometry {
  const TimetableGeometry(this.periodCount);

  final int periodCount;

  int get mealBreakCount =>
      timetableMealBreaks.where((period) => period < periodCount).length;

  double get height =>
      timetableHeaderHeight +
      timetablePeriodHeight * periodCount +
      timetableMealBreakHeight * mealBreakCount;

  double get courseWidth => math.max(
    160,
    math.min(
      ((height * timetableAspectRatio - timetableIndexWidth) / 5)
          .roundToDouble(),
      360,
    ),
  );

  double get width => timetableIndexWidth + courseWidth * 5;
  int get exportWidth =>
      ((width + timetableExportPadding * 2) * timetableExportScale).round();
  int get exportHeight =>
      ((height + timetableExportPadding * 2) * timetableExportScale).round();
}

String timetableClassEnd(String start) {
  final parts = start.split(':').map(int.parse).toList(growable: false);
  final end = parts[0] * 60 + parts[1] + 50;
  return '${(end ~/ 60).toString().padLeft(2, '0')}:'
      '${(end % 60).toString().padLeft(2, '0')}';
}
