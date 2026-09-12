import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/timetable.dart';
import '../../domain/week_frequency.dart';
import '../../ui/super_otc_font.dart';

export '../../domain/class_period_time.dart';

const timetableCanvas = Color(0xfffaf9f5);
const timetableIndexSurface = Color(0xffe8e0d2);
const timetableInk = Color(0xff141413);
const timetableBody = Color(0xff3d3d3a);
const timetableMuted = Color(0xff6c6a64);
const timetableDivider = Color(0xff92918d);
const timetableConflictColor = Color(0xffd32f2f);

const timetableMonoFont = 'Roboto Mono Reference';
const timetableSansFont = pkuNotoSansScFamily;
const timetablePeriodFont = pkuNotoSansScFamily;
const timetableFontFallback = <String>[timetableSansFont];

const timetableHeaderHeight = 44.0;
const timetablePeriodHeight = 100.0;
const timetableMealBreakHeight = 30.0;
const timetableIndexWidth = 120.0;
const timetableExportPadding = 12.0;
const timetableExportScale = 4.0;
const timetableAspectRatio = 1.15;
const timetableDividerWidth = 1.0;
const timetableConflictWidth = 3.0;
const timetableMealBreaks = <int>{4, 9};
const timetableCourseNameFontSize = 22.5;
const timetableClassroomFontSize = 22.5;
const timetableCourseNoteFontSize = 16.0;
const timetableCourseContentPadding = 10.0;
const timetableCourseNameFontWeight = FontWeight.bold;

Color themedTimetableColor(
  Color color, {
  required Brightness brightness,
  required Color surface,
}) {
  if (brightness != Brightness.dark) return color;
  return Color.alphaBlend(surface.withValues(alpha: .65), color);
}

Color timetableContrastForeground(Color background) =>
    background.computeLuminance() > .5 ? Colors.black : Colors.white;

Color timetableCourseForeground(
  Color background, {
  required Brightness brightness,
  required bool autoTextColor,
}) =>
    brightness == Brightness.dark ||
        autoTextColor && background.computeLuminance() <= .5
    ? Colors.white
    : Colors.black;

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
  double periodTop(int period) =>
      timetableHeaderHeight +
      (period - 1) * timetablePeriodHeight +
      timetableMealBreaks.where((breakPeriod) => breakPeriod < period).length *
          timetableMealBreakHeight;
  int get exportWidth =>
      ((width + timetableExportPadding * 2) * timetableExportScale).round();
  int get exportHeight =>
      ((height + timetableExportPadding * 2) * timetableExportScale).round();
}

final class TimetableVisualSpan {
  const TimetableVisualSpan({
    required this.group,
    required this.firstPeriod,
    required this.lastPeriod,
    required this.lane,
  });

  final CourseGroup group;
  final int firstPeriod;
  final int lastPeriod;
  final int lane;
}

final class TimetableDayLayout {
  TimetableDayLayout._(this.spans, this.laneCount);

  final List<TimetableVisualSpan> spans;
  final int laneCount;

  factory TimetableDayLayout.from(
    Timetable timetable,
    int day, {
    WeekParity? parity,
  }) {
    final pending = <({CourseGroup group, int first, int last})>[];
    for (final group in timetable.groupsForDay(
      day,
      breakAfter: timetableMealBreaks,
      currentParity: parity,
    )) {
      var first = group.firstPeriod;
      for (final breakPeriod in timetableMealBreaks) {
        if (first <= breakPeriod && breakPeriod < group.lastPeriod) {
          pending.add((group: group, first: first, last: breakPeriod));
          first = breakPeriod + 1;
        }
      }
      pending.add((group: group, first: first, last: group.lastPeriod));
    }
    pending.sort((a, b) => a.first.compareTo(b.first));
    final laneEnds = <int>[];
    final spans = <TimetableVisualSpan>[];
    for (final item in pending) {
      var lane = laneEnds.indexWhere((end) => end < item.first);
      if (lane < 0) {
        lane = laneEnds.length;
        laneEnds.add(item.last);
      } else {
        laneEnds[lane] = item.last;
      }
      spans.add(
        TimetableVisualSpan(
          group: item.group,
          firstPeriod: item.first,
          lastPeriod: item.last,
          lane: lane,
        ),
      );
    }
    return TimetableDayLayout._(
      List.unmodifiable(spans),
      math.max(1, laneEnds.length),
    );
  }
}
