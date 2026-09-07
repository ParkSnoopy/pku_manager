import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
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
    required this.paletteSeed,
    this.parity,
    this.previousDay,
    this.nextDay,
  });
  final Timetable timetable;
  final List<int> days;
  final int paletteSeed;
  final WeekParity? parity;
  final VoidCallback? previousDay;
  final VoidCallback? nextDay;

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
                      constraints: const BoxConstraints(minHeight: 60),
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
                            currentParity: parity,
                          ))
                            _MeetingTile(
                              meeting,
                              isCurrent: meeting.frequency.isCurrent(parity),
                              paletteSeed: paletteSeed,
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

class _MeetingTile extends StatefulWidget {
  const _MeetingTile(
    this.meeting, {
    required this.isCurrent,
    required this.paletteSeed,
  });

  final CourseMeeting meeting;
  final bool isCurrent;
  final int paletteSeed;

  @override
  State<_MeetingTile> createState() => _MeetingTileState();
}

class _MeetingTileState extends State<_MeetingTile> {
  Timer? _hoverTimer;
  OverlayEntry? _details;
  Offset _pointer = Offset.zero;

  void _move(PointerEvent event) {
    _pointer = event.position;
    _details?.markNeedsBuild();
  }

  void _enter(PointerEnterEvent event) {
    _move(event);
    _hoverTimer = Timer(const Duration(milliseconds: 1000), _showDetails);
  }

  void _exit(PointerExitEvent event) {
    _hoverTimer?.cancel();
    _removeDetails();
  }

  void _showDetails() {
    if (!mounted || _details != null) return;
    _details = OverlayEntry(
      builder: (context) {
        final size = MediaQuery.sizeOf(context);
        final width = math.min(320.0, size.width - 16);
        final left = (_pointer.dx + 14).clamp(8.0, size.width - width - 8);
        final top = (_pointer.dy + 14)
            .clamp(8.0, math.max(8.0, size.height - 220))
            .toDouble();
        return Positioned(
          key: ValueKey('meeting-hover-${widget.meeting.sourceId}'),
          left: left,
          top: top,
          width: width,
          child: IgnorePointer(
            child: Material(
              elevation: 8,
              color: Theme.of(context).colorScheme.surface,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: _Details(meeting: widget.meeting),
              ),
            ),
          ),
        );
      },
    );
    Overlay.of(context).insert(_details!);
  }

  void _removeDetails() {
    _details?.remove();
    _details = null;
  }

  @override
  void dispose() {
    _hoverTimer?.cancel();
    _removeDetails();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final meeting = widget.meeting;
    final hash = meeting.name.runes.fold(
      0,
      (value, rune) => (value * 31 + rune) & 0x7fffffff,
    );
    final background = HSLColor.fromAHSL(
      1,
      ((hash + widget.paletteSeed * 67) % 360).toDouble(),
      .38,
      .91,
    ).toColor();
    final foreground = background.computeLuminance() > .5
        ? Colors.black
        : Colors.white;
    return MouseRegion(
      onEnter: _enter,
      onHover: _move,
      onExit: _exit,
      child: Opacity(
        opacity: widget.isCurrent ? 1 : .5,
        child: SizedBox(
          key: ValueKey('meeting-cell-${meeting.sourceId}'),
          height: 60,
          width: double.infinity,
          child: Material(
            key: ValueKey('meeting-color-${meeting.sourceId}'),
            color: background,
            child: InkWell(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => Scaffold(
                    appBar: AppBar(title: const Text('Course details')),
                    body: ListView(
                      padding: const EdgeInsets.all(24),
                      children: [_Details(meeting: meeting)],
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
                        meeting.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        meeting.room,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Details extends StatelessWidget {
  const _Details({required this.meeting});

  final CourseMeeting meeting;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(meeting.name, style: Theme.of(context).textTheme.titleMedium),
      for (final text in [
        meeting.room,
        meeting.frequencyText,
        meeting.note,
        meeting.exam,
      ])
        if (text.isNotEmpty)
          Padding(padding: const EdgeInsets.only(top: 8), child: Text(text)),
    ],
  );
}
