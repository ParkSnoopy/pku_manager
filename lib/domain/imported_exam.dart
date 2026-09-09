import 'class_period_time.dart';

final class ImportedExam {
  const ImportedExam({required this.startsAt, required this.sourceText});

  final DateTime startsAt;
  final String sourceText;
}

ImportedExam? parseImportedExam(String value) {
  final sourceText = value.trim();
  if (sourceText.isEmpty) return null;
  final date = RegExp(
    r'(\d{4})\s*(?:年|[-/.])\s*(\d{1,2})\s*(?:月|[-/.])\s*(\d{1,2})\s*日?',
  ).firstMatch(sourceText);
  if (date == null) return null;
  final period = switch (sourceText) {
    final text when text.contains('上午') => 1,
    final text when text.contains('下午') => 5,
    final text when text.contains('晚上') => 10,
    _ => null,
  };
  if (period == null) return null;
  final start = timetableClassStarts[period]!;
  final clock = start.split(':').map(int.parse).toList(growable: false);
  final year = int.parse(date[1]!);
  final month = int.parse(date[2]!);
  final day = int.parse(date[3]!);
  final beijing = DateTime.utc(year, month, day, clock[0], clock[1]);
  if (beijing.year != year || beijing.month != month || beijing.day != day) {
    return null;
  }
  return ImportedExam(
    startsAt: beijing.subtract(const Duration(hours: 8)),
    sourceText: sourceText,
  );
}
