import 'dart:async';

import 'package:flutter/material.dart';

import '../schedule_import/schedule_import_review.dart';
import '../settings/appearance_controller.dart';
import '../settings/settings_page.dart';
import 'timetable_controller.dart';
import 'timetable_grid.dart';

class TimetablePage extends StatefulWidget {
  const TimetablePage({
    super.key,
    required this.controller,
    required this.appearance,
  });
  final TimetableController controller;
  final AppearanceController appearance;
  @override
  State<TimetablePage> createState() => _TimetablePageState();
}

class _TimetablePageState extends State<TimetablePage>
    with WidgetsBindingObserver {
  late int _day = widget.controller
      .clock()
      .toUtc()
      .add(const Duration(hours: 8))
      .weekday;
  double _dragDistance = 0;
  int _destination = 0;

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
    setState(() => _day = (_day + delta).clamp(1, 7));
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) {
      final c = widget.controller;
      final semesterWeek = c.week.calendar?.weekAt(c.clock());
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: _destination,
              onDestinationSelected: (value) =>
                  setState(() => _destination = value),
              labelType: NavigationRailLabelType.all,
              destinations: const [
                NavigationRailDestination(
                  icon: Icon(Icons.calendar_view_week_outlined),
                  selectedIcon: Icon(Icons.calendar_view_week),
                  label: Text('Timetable'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.settings_outlined),
                  selectedIcon: Icon(Icons.settings),
                  label: Text('Settings'),
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
                        tooltip: 'Roll colors',
                        icon: const Icon(Icons.casino_outlined),
                      ),
                      IconButton(
                        onPressed: c.importing || c.candidate != null
                            ? null
                            : c.import,
                        tooltip: 'Import',
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
                        const Padding(
                          padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                          child: Text(
                            'PKU Manager',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  semesterWeek == null
                                      ? 'Week unavailable · all classes shown'
                                      : 'Week ${semesterWeek.weekNumber} · ${semesterWeek.isOdd ? "Odd" : "Even"}',
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
                              ? const Center(
                                  child: Padding(
                                    padding: EdgeInsets.all(24),
                                    child: Text(
                                      'Import your exported schedule.xls.\nYour timetable stays on this device.',
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                )
                              : LayoutBuilder(
                                  builder: (context, constraints) =>
                                      constraints.maxWidth >= 1000
                                      ? TimetableGrid(
                                          timetable: c.timetable!,
                                          days: List.generate(7, (i) => i + 1),
                                          paletteSeed:
                                              widget.appearance.paletteSeed,
                                          parity: semesterWeek?.parity,
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
                                            nextDay: _day < 7
                                                ? () => _changeDay(1)
                                                : null,
                                            paletteSeed:
                                                widget.appearance.paletteSeed,
                                            parity: semesterWeek?.parity,
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
