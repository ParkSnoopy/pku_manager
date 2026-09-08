import 'package:flutter/material.dart';

import '../../l10n/app_strings.dart';

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key, required this.now});

  final DateTime now;

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  late DateTime _month = _beijingDate(widget.now);

  void _changeMonth(int delta) =>
      setState(() => _month = DateTime.utc(_month.year, _month.month + delta));

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final today = _beijingDate(widget.now);
    final first = DateTime.utc(_month.year, _month.month);
    final gridStart = first.subtract(Duration(days: first.weekday - 1));
    return Material(
      key: const ValueKey('calendar-page'),
      color: Theme.of(context).colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                IconButton(
                  key: const ValueKey('calendar-previous-month'),
                  tooltip: strings.text(AppText.previousMonth),
                  onPressed: () => _changeMonth(-1),
                  icon: const Icon(Icons.chevron_left),
                ),
                Expanded(
                  child: Text(
                    strings.monthLabel(_month),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  key: const ValueKey('calendar-next-month'),
                  tooltip: strings.text(AppText.nextMonth),
                  onPressed: () => _changeMonth(1),
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                for (var day = 1; day <= 7; day++)
                  Expanded(
                    child: Text(
                      strings.weekday(day).substring(0, 1),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final cellWidth = constraints.maxWidth / 7;
                  final cellHeight = constraints.maxHeight / 6;
                  return GridView.builder(
                    key: const ValueKey('calendar-month-grid'),
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 7,
                      childAspectRatio: cellWidth / cellHeight,
                    ),
                    itemCount: 42,
                    itemBuilder: (context, index) {
                      final date = gridStart.add(Duration(days: index));
                      return _CalendarDay(
                        date: date,
                        today: today,
                        inMonth: date.month == _month.month,
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CalendarDay extends StatelessWidget {
  const _CalendarDay({
    required this.date,
    required this.today,
    required this.inMonth,
  });

  final DateTime date;
  final DateTime today;
  final bool inMonth;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isToday = date == today;
    return Semantics(
      label: '${date.year}-${date.month}-${date.day}',
      child: DecoratedBox(
        key: ValueKey('calendar-day-${date.year}-${date.month}-${date.day}'),
        decoration: BoxDecoration(
          border: Border.all(
            color: isToday ? colors.primary : colors.outlineVariant,
            width: isToday ? 2 : .5,
          ),
        ),
        child: ClipRect(
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${date.day}',
                  style: TextStyle(
                    color: inMonth ? colors.onSurface : colors.outline,
                    fontSize: 14,
                    fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

DateTime _beijingDate(DateTime value) {
  final local = value.toUtc().add(const Duration(hours: 8));
  return DateTime.utc(local.year, local.month, local.day);
}
