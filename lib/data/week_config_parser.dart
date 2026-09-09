import '../domain/semester.dart';

class WeekConfigParser {
  WeekConfigParser(this.config);
  final SemesterConfig config;

  SemesterCalendar parse(String text) {
    final values = <String, String>{};
    for (final line in text.split('\n')) {
      final content = line.split('#').first.trim();
      if (content.isEmpty) continue;
      final match = RegExp(r'^(base_date|timezone)\s*=\s*(.+)$')
          .firstMatch(content);
      if (match == null || values.containsKey(match.group(1))) {
        throw const FormatException(
          'Unsupported or duplicate week configuration field',
        );
      }
      values[match.group(1)!] = match.group(2)!;
    }
    if (values['timezone'] != '"Asia/Shanghai"') {
      throw const FormatException('Expected Asia/Shanghai timezone');
    }
    final list = values['base_date'] ?? '';
    if (!RegExp(
      r'^\[\s*"\d{4}-\d{2}-\d{2}"(?:\s*,\s*"\d{4}-\d{2}-\d{2}")*\s*,?\s*\]$',
    ).hasMatch(list)) {
      throw const FormatException(
        'Expected a nonempty list of ISO semester dates',
      );
    }
    final starts = RegExp(r'\d{4}-\d{2}-\d{2}').allMatches(list).map((match) {
      final raw = match.group(0)!;
      final date = DateTime.parse('${raw}T00:00:00Z');
      if (date.toIso8601String().substring(0, 10) != raw) {
        throw const FormatException('Invalid semester calendar date');
      }
      return date;
    }).toList();
    try {
      return SemesterCalendar(starts: starts, config: config);
    } on ArgumentError {
      throw const FormatException(
        'Semester dates must be unique and ascending',
      );
    }
  }
}
