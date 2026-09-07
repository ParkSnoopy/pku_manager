import 'package:flutter/material.dart';

import '../../domain/course_meeting.dart';
import '../../domain/timetable.dart';
import '../../domain/week_frequency.dart';

const weekdays = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

class TimetableGrid extends StatelessWidget {
  const TimetableGrid({
    super.key,
    required this.timetable,
    required this.days,
    required this.mode,
    this.parity,
    this.previousDay,
    this.nextDay,
  });
  final Timetable timetable;
  final List<int> days;
  final PreviewMode mode;
  final WeekParity? parity;
  final VoidCallback? previousDay;
  final VoidCallback? nextDay;

  bool _continues(CourseMeeting meeting, int period) =>
      meeting.firstPeriod < period ||
      timetable
          .consecutiveGroups(mode: mode, currentParity: parity)
          .any(
            (group) => group.skip(1).any((m) => m.sourceId == meeting.sourceId),
          );

  @override
  Widget build(BuildContext context) => Column(
    children: [
      SizedBox(
        height: 48,
        child: Row(
          children: [
            const SizedBox(width: 56, child: Center(child: Text('Period'))),
            if (days.length == 1)
              IconButton(
                onPressed: previousDay,
                tooltip: 'Previous day',
                icon: const Icon(Icons.chevron_left),
              ),
            for (final day in days)
              Expanded(
                child: Center(
                  child: Text(
                    weekdays[day - 1],
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            if (days.length == 1)
              IconButton(
                onPressed: nextDay,
                tooltip: 'Next day',
                icon: const Icon(Icons.chevron_right),
              ),
          ],
        ),
      ),
      Expanded(
        child: ListView.builder(
          itemCount: timetable.periodCount,
          itemBuilder: (context, index) => IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(width: 56, child: Center(child: Text('${index + 1}'))),
                for (final day in days)
                  Expanded(
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 104),
                      decoration: BoxDecoration(
                        border: Border(
                          top: BorderSide(
                            color: Theme.of(context).dividerColor,
                          ),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (final meeting in timetable.atPeriod(
                            day,
                            index + 1,
                            mode: mode,
                            currentParity: parity,
                          ))
                            _MeetingTile(
                              meeting,
                              continuation: _continues(meeting, index + 1),
                            ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    ],
  );
}

class _MeetingTile extends StatelessWidget {
  const _MeetingTile(this.meeting, {this.continuation = false});
  final CourseMeeting meeting;
  final bool continuation;
  @override
  Widget build(BuildContext context) {
    final hash = meeting.name.runes.fold(
      0,
      (value, rune) => (value * 31 + rune) & 0x7fffffff,
    );
    final background = HSLColor.fromAHSL(
      1,
      (hash % 360).toDouble(),
      .38,
      .91,
    ).toColor();
    final foreground = background.computeLuminance() > .5
        ? Colors.black
        : Colors.white;
    return Material(
      color: background,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => Scaffold(
              appBar: AppBar(title: const Text('Course details')),
              body: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  for (final text in [
                    meeting.name,
                    meeting.room,
                    meeting.frequencyText,
                    if (meeting.hasUnknownFrequency)
                      'Unknown frequency — visible in every preview',
                    meeting.note,
                    meeting.exam,
                  ])
                    if (text.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: SelectableText(text),
                      ),
                ],
              ),
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: DefaultTextStyle(
            style: TextStyle(color: foreground, fontSize: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  continuation ? '${meeting.name} · continued' : meeting.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  meeting.room,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  meeting.hasUnknownFrequency
                      ? 'Unknown frequency'
                      : meeting.frequencyText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
