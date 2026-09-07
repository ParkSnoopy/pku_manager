import 'package:flutter/material.dart';

import '../../domain/week_frequency.dart';
import '../schedule_import/schedule_import_review.dart';
import 'timetable_controller.dart';
import 'timetable_grid.dart';

class TimetablePage extends StatefulWidget {
  const TimetablePage({super.key, required this.controller});
  final TimetableController controller;
  @override
  State<TimetablePage> createState() => _TimetablePageState();
}

class _TimetablePageState extends State<TimetablePage> {
  late int _day = widget.controller
      .clock()
      .toUtc()
      .add(const Duration(hours: 8))
      .weekday;
  double _dragDistance = 0;
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
        appBar: AppBar(
          title: const Text('PKU Manager'),
          actions: [
            TextButton(
              onPressed: c.importing || c.candidate != null ? null : c.import,
              child: Text(c.importing ? 'Importing…' : 'Import'),
            ),
          ],
        ),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                children: [
                  Text(
                    semesterWeek == null
                        ? 'Current week unavailable · all classes shown'
                        : 'Week ${semesterWeek.weekNumber} · ${semesterWeek.isOdd ? "Odd" : "Even"}',
                  ),
                  TextButton(
                    onPressed: c.refreshing ? null : c.refresh,
                    child: Text(
                      c.refreshing
                          ? 'Refreshing…'
                          : '${c.week.freshness.name} · Refresh',
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
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            if (c.week.message != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(c.week.message!),
              ),
            if (c.candidate == null)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.all(12),
                child: SegmentedButton<PreviewMode>(
                  showSelectedIcon: false,
                  style: const ButtonStyle(
                    visualDensity: VisualDensity.compact,
                  ),
                  segments: PreviewMode.values
                      .map(
                        (m) => ButtonSegment(
                          value: m,
                          label: Text(switch (m) {
                            PreviewMode.current => 'Current',
                            PreviewMode.odd => 'Odd',
                            PreviewMode.even => 'Even',
                            PreviewMode.all => 'All',
                          }),
                        ),
                      )
                      .toList(),
                  selected: {c.mode},
                  onSelectionChanged: (m) => c.selectMode(m.single),
                ),
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
                              mode: c.mode,
                              parity: semesterWeek?.parity,
                            )
                          : GestureDetector(
                              onHorizontalDragStart: (_) => _dragDistance = 0,
                              onHorizontalDragUpdate: (details) =>
                                  _dragDistance += details.delta.dx,
                              onHorizontalDragEnd: (_) {
                                if (_dragDistance.abs() >= 40) {
                                  _changeDay(_dragDistance < 0 ? 1 : -1);
                                }
                              },
                              child: TimetableGrid(
                                timetable: c.timetable!,
                                days: [_day],
                                previousDay: _day > 1
                                    ? () => _changeDay(-1)
                                    : null,
                                nextDay: _day < 7 ? () => _changeDay(1) : null,
                                mode: c.mode,
                                parity: semesterWeek?.parity,
                              ),
                            ),
                    ),
            ),
          ],
        ),
      );
    },
  );
}
