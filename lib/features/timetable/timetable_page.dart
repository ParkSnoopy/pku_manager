import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../domain/course_meeting.dart';
import '../../domain/timetable.dart';
import '../../domain/week_frequency.dart';
import '../../l10n/app_strings.dart';
import '../calendar/calendar_page.dart';
import '../calendar/calendar_schedule_controller.dart';
import '../calendar/upcoming_schedules_pane.dart';
import '../schedule_import/schedule_import_review.dart';
import '../settings/appearance_controller.dart';
import '../settings/settings_page.dart';
import 'course_editor_dialog.dart';
import 'timetable_controller.dart';
import 'timetable_color.dart';
import 'timetable_export.dart';
import 'timetable_grid.dart';
import 'timetable_side_pane.dart';

const teachingPortalUrl =
    'https://course.pku.edu.cn/webapps/portal/execute/tabs/tabAction?tab_tab_group_id=_1_1';

typedef BrowserLauncher = Future<bool> Function(Uri uri);

Future<bool> launchInDefaultBrowser(Uri uri) =>
    launchUrl(uri, mode: LaunchMode.externalApplication);

final class _EditorSelection {
  const _EditorSelection(this.weekday, this.period, this.meetings);

  final int weekday;
  final int period;
  final List<CourseMeeting> meetings;
}

class TimetablePage extends StatefulWidget {
  const TimetablePage({
    super.key,
    required this.controller,
    required this.calendar,
    required this.appearance,
    required this.exporter,
    this.browserLauncher = launchInDefaultBrowser,
  });
  final TimetableController controller;
  final CalendarScheduleController calendar;
  final AppearanceController appearance;
  final TimetableExporter exporter;
  final BrowserLauncher browserLauncher;
  @override
  State<TimetablePage> createState() => _TimetablePageState();
}

class _TimetablePageState extends State<TimetablePage>
    with WidgetsBindingObserver {
  late int _day = widget.controller
      .clock()
      .toUtc()
      .add(const Duration(hours: 8))
      .weekday
      .clamp(1, 5);
  double _dragDistance = 0;
  int _destination = 0;
  bool _exporting = false;
  _EditorSelection? _editor;
  Timetable? _appearanceTimetable;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _appearanceTimetable = widget.controller.timetable;
    widget.controller.addListener(_syncCourseAppearances);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(widget.controller.refresh());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.controller.removeListener(_syncCourseAppearances);
    super.dispose();
  }

  void _syncCourseAppearances() {
    if (identical(_appearanceTimetable, widget.controller.timetable)) return;
    _appearanceTimetable = widget.controller.timetable;
    widget.appearance.reloadCourseAppearances();
  }

  void _changeDay(int delta) {
    setState(() => _day = (_day + delta).clamp(1, 5));
  }

  Future<void> _editCell(
    int weekday,
    int period,
    List<CourseMeeting> meetings,
  ) async {
    if (MediaQuery.orientationOf(context) == Orientation.landscape) {
      setState(() => _editor = _EditorSelection(weekday, period, meetings));
      return;
    }
    final result = await showDialog<CourseEditResult>(
      context: context,
      builder: (_) => CourseEditorDialog(
        weekday: weekday,
        period: period,
        periodCount: widget.controller.timetable!.periodCount,
        meetings: meetings,
        courseAppearance: meetings.isEmpty
            ? const CourseAppearance()
            : widget.appearance.courseAppearanceFor(meetings.first.sourceId) ??
                  const CourseAppearance(),
        suggestedColor: meetings.isEmpty
            ? courseColorChoices.first
            : timetableCourseColor(
                meetings.first,
                widget.appearance.paletteSeed,
                appearance: widget.appearance.courseAppearanceFor(
                  meetings.first.sourceId,
                ),
              ),
      ),
    );
    if (result != null) _applyEdit(result, meetings);
  }

  void _applyEdit(CourseEditResult result, List<CourseMeeting> original) {
    if (result.remove) {
      widget.controller.removeUserMeetings(
        original.map((meeting) => meeting.sourceId),
      );
      widget.appearance.setCourseAppearance(
        original.map((meeting) => meeting.sourceId),
        const CourseAppearance(),
      );
    } else {
      widget.controller.saveMeetings(result.meetings);
      widget.appearance.setCourseAppearance(
        result.meetings.map((meeting) => meeting.sourceId),
        result.appearance,
      );
    }
    setState(() => _editor = null);
  }

  Future<void> _openTeachingPortal() async {
    try {
      final opened = await widget.browserLauncher(Uri.parse(teachingPortalUrl));
      if (!opened) throw StateError('Browser did not open');
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppStrings.of(context).text(AppText.openBrowserFailed),
            ),
          ),
        );
      }
    }
  }

  Future<void> _export(TimetableExportFormat format) async {
    final timetable = widget.controller.timetable;
    if (timetable == null || _exporting) return;
    setState(() => _exporting = true);
    try {
      await widget.exporter.export(
        format,
        timetable,
        strings: AppStrings.of(context),
        paletteSeed: widget.appearance.paletteSeed,
        courseAppearances: widget.appearance.courseAppearances,
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppStrings.of(context).text(AppText.exportFailed)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) {
      final c = widget.controller;
      final semesterWeek = c.week.calendar?.weekAt(c.clock());
      final strings = AppStrings.of(context);
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: _destination,
              onDestinationSelected: (value) {
                if (value == 3) {
                  unawaited(_openTeachingPortal());
                } else {
                  setState(() {
                    _destination = value;
                    _editor = null;
                  });
                }
              },
              labelType: NavigationRailLabelType.all,
              destinations: [
                NavigationRailDestination(
                  icon: const Icon(Icons.calendar_view_week_outlined),
                  selectedIcon: const Icon(Icons.calendar_view_week),
                  label: Text(strings.text(AppText.timetable)),
                ),
                NavigationRailDestination(
                  icon: const Icon(Icons.calendar_month_outlined),
                  selectedIcon: const Icon(Icons.calendar_month),
                  label: Text(strings.text(AppText.calendar)),
                ),
                NavigationRailDestination(
                  icon: const Icon(Icons.settings_outlined),
                  selectedIcon: const Icon(Icons.settings),
                  label: Text(strings.text(AppText.settings)),
                ),
                NavigationRailDestination(
                  icon: const Icon(Icons.school_outlined),
                  selectedIcon: const Icon(Icons.school),
                  label: Text(strings.text(AppText.teachingPortal)),
                ),
              ],
              trailing: Expanded(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (widget.appearance.showRollInNavbar)
                          IconButton(
                            onPressed: c.timetable == null
                                ? null
                                : widget.appearance.rollPalette,
                            tooltip: strings.text(AppText.rollColors),
                            icon: const Icon(Icons.casino_outlined),
                          ),
                        PopupMenuButton<TimetableExportFormat>(
                          enabled: c.timetable != null && !_exporting,
                          tooltip: strings.text(AppText.export),
                          icon: _exporting
                              ? const SizedBox.square(
                                  dimension: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.ios_share_outlined),
                          onSelected: _export,
                          itemBuilder: (_) => [
                            PopupMenuItem(
                              value: TimetableExportFormat.png,
                              child: Text(strings.text(AppText.exportPng)),
                            ),
                            PopupMenuItem(
                              value: TimetableExportFormat.xlsx,
                              child: Text(strings.text(AppText.exportXlsx)),
                            ),
                          ],
                        ),
                        IconButton(
                          onPressed: c.importing || c.candidate != null
                              ? null
                              : c.import,
                          tooltip: strings.text(AppText.import),
                          icon: c.importing
                              ? const SizedBox.square(
                                  dimension: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.file_open_outlined),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const VerticalDivider(width: 1),
            Expanded(
              child: _destination == 2
                  ? SettingsPage(controller: widget.appearance)
                  : _destination == 1
                  ? _calendarBody(c)
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  semesterWeek == null
                                      ? strings.text(AppText.weekUnavailable)
                                      : strings.weekLabel(
                                          semesterWeek.weekNumber,
                                          semesterWeek.isOdd,
                                        ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (c.error != null)
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(
                              c.error!,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                          ),
                        if (c.week.message != null)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Text(c.week.message!),
                          ),

                        Expanded(
                          child: _timetableBody(c, semesterWeek?.parity),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      );
    },
  );

  Widget _timetableBody(TimetableController controller, WeekParity? parity) {
    final candidate = controller.candidate;
    if (candidate != null) {
      return ScheduleImportReview(
        key: ObjectKey(candidate),
        candidate: candidate,
        controller: controller,
      );
    }
    final timetable = controller.timetable;
    if (timetable == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            AppStrings.of(context).text(AppText.noTimetable),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final landscape = constraints.maxWidth > constraints.maxHeight;
        if (!landscape) return _grid(timetable, parity, false);
        final paneWidth = (constraints.maxWidth * .28).clamp(280.0, 360.0);
        final allDays = constraints.maxWidth - paneWidth >= 700;
        return Row(
          children: [
            Expanded(child: _grid(timetable, parity, allDays)),
            const VerticalDivider(width: 1),
            SizedBox(
              width: paneWidth,
              child: _editor == null
                  ? UpcomingSchedulesPane(
                      controller: widget.calendar,
                      now: controller.clock(),
                    )
                  : CourseEditorDialog(
                      key: ValueKey(
                        'editor-${_editor!.weekday}-${_editor!.period}-'
                        '${_editor!.meetings.map((m) => m.sourceId).join('|')}',
                      ),
                      weekday: _editor!.weekday,
                      period: _editor!.period,
                      periodCount: timetable.periodCount,
                      meetings: _editor!.meetings,
                      embedded: true,
                      courseAppearance: _editor!.meetings.isEmpty
                          ? const CourseAppearance()
                          : widget.appearance.courseAppearanceFor(
                                  _editor!.meetings.first.sourceId,
                                ) ??
                                const CourseAppearance(),
                      suggestedColor: _editor!.meetings.isEmpty
                          ? courseColorChoices.first
                          : timetableCourseColor(
                              _editor!.meetings.first,
                              widget.appearance.paletteSeed,
                              appearance: widget.appearance.courseAppearanceFor(
                                _editor!.meetings.first.sourceId,
                              ),
                            ),
                      onCancel: () => setState(() => _editor = null),
                      onResult: (result) =>
                          _applyEdit(result, _editor!.meetings),
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _calendarBody(TimetableController controller) {
    final calendarPage = CalendarPage(
      now: controller.clock(),
      controller: widget.calendar,
    );
    final timetable = controller.timetable;
    if (timetable == null) return calendarPage;
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth <= constraints.maxHeight) return calendarPage;
        final paneWidth = (constraints.maxWidth * .28).clamp(280.0, 360.0);
        return Row(
          children: [
            Expanded(child: calendarPage),
            const VerticalDivider(width: 1),
            SizedBox(
              width: paneWidth,
              child: UpcomingClassPane(
                timetable: timetable,
                now: controller.clock(),
                calendar: controller.week.calendar,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _grid(Timetable timetable, WeekParity? parity, bool allDays) {
    final grid = TimetableGrid(
      timetable: timetable,
      days: allDays ? List.generate(5, (index) => index + 1) : [_day],
      previousDay: !allDays && _day > 1 ? () => _changeDay(-1) : null,
      nextDay: !allDays && _day < 5 ? () => _changeDay(1) : null,
      paletteSeed: widget.appearance.paletteSeed,
      courseAppearances: widget.appearance.courseAppearances,
      parity: parity,
      onEdit: _editCell,
    );
    if (allDays) return grid;
    return GestureDetector(
      onHorizontalDragStart: (_) => _dragDistance = 0,
      onHorizontalDragUpdate: (details) => _dragDistance += details.delta.dx,
      onHorizontalDragEnd: (_) {
        if (_dragDistance.abs() >= 40) {
          _changeDay(_dragDistance < 0 ? 1 : -1);
        }
      },
      child: grid,
    );
  }
}
