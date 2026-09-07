import 'dart:async';

import 'package:flutter/material.dart';

import '../../domain/course_meeting.dart';
import '../../l10n/app_strings.dart';
import '../schedule_import/schedule_import_review.dart';
import '../settings/appearance_controller.dart';
import '../settings/settings_page.dart';
import 'course_editor_dialog.dart';
import 'timetable_controller.dart';
import 'timetable_export.dart';
import 'timetable_grid.dart';

class TimetablePage extends StatefulWidget {
  const TimetablePage({
    super.key,
    required this.controller,
    required this.appearance,
    required this.exporter,
  });
  final TimetableController controller;
  final AppearanceController appearance;
  final TimetableExporter exporter;
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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
    super.dispose();
  }

  void _changeDay(int delta) {
    setState(() => _day = (_day + delta).clamp(1, 5));
  }

  Future<void> _editCell(
    int weekday,
    int period,
    CourseMeeting? meeting,
  ) async {
    final result = await showDialog<CourseEditResult>(
      context: context,
      builder: (_) => CourseEditorDialog(
        weekday: weekday,
        period: period,
        periodCount: widget.controller.timetable!.periodCount,
        meeting: meeting,
      ),
    );
    if (result == null) return;
    if (result.remove) {
      widget.controller.removeUserMeeting(meeting!.sourceId);
    } else {
      widget.controller.saveMeeting(result.meeting!);
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
              onDestinationSelected: (value) =>
                  setState(() => _destination = value),
              labelType: NavigationRailLabelType.all,
              destinations: [
                NavigationRailDestination(
                  icon: const Icon(Icons.calendar_view_week_outlined),
                  selectedIcon: const Icon(Icons.calendar_view_week),
                  label: Text(strings.text(AppText.timetable)),
                ),
                NavigationRailDestination(
                  icon: const Icon(Icons.settings_outlined),
                  selectedIcon: const Icon(Icons.settings),
                  label: Text(strings.text(AppText.settings)),
                ),
              ],
              trailing: Expanded(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
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
            const VerticalDivider(width: 1),
            Expanded(
              child: _destination == 1
                  ? SettingsPage(controller: widget.appearance)
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
                          child: c.candidate != null
                              ? ScheduleImportReview(
                                  key: ObjectKey(c.candidate),
                                  candidate: c.candidate!,
                                  controller: c,
                                )
                              : c.timetable == null
                              ? Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(24),
                                    child: Text(
                                      strings.text(AppText.noTimetable),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                )
                              : LayoutBuilder(
                                  builder: (context, constraints) =>
                                      constraints.maxWidth >= 1000
                                      ? Align(
                                          alignment: Alignment.topLeft,
                                          child: FractionallySizedBox(
                                            widthFactor: 6 / 7,
                                            child: TimetableGrid(
                                              timetable: c.timetable!,
                                              days: List.generate(
                                                5,
                                                (i) => i + 1,
                                              ),
                                              paletteSeed:
                                                  widget.appearance.paletteSeed,
                                              parity: semesterWeek?.parity,
                                              onEdit: _editCell,
                                            ),
                                          ),
                                        )
                                      : GestureDetector(
                                          onHorizontalDragStart: (_) =>
                                              _dragDistance = 0,
                                          onHorizontalDragUpdate: (details) =>
                                              _dragDistance += details.delta.dx,
                                          onHorizontalDragEnd: (_) {
                                            if (_dragDistance.abs() >= 40) {
                                              _changeDay(
                                                _dragDistance < 0 ? 1 : -1,
                                              );
                                            }
                                          },
                                          child: TimetableGrid(
                                            timetable: c.timetable!,
                                            days: [_day],
                                            previousDay: _day > 1
                                                ? () => _changeDay(-1)
                                                : null,
                                            nextDay: _day < 5
                                                ? () => _changeDay(1)
                                                : null,
                                            paletteSeed:
                                                widget.appearance.paletteSeed,
                                            parity: semesterWeek?.parity,
                                            onEdit: _editCell,
                                          ),
                                        ),
                                ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      );
    },
  );
}
