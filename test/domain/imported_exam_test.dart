import 'package:flutter_test/flutter_test.dart';
import 'package:pku_manager/domain/imported_exam.dart';

void main() {
  for (final value in [
    ('考试：2027年1月10日上午', DateTime.utc(2027, 1, 10)),
    ('考试时间：20270104上午；', DateTime.utc(2027, 1, 4)),
    ('考试 2027-01-10 下午', DateTime.utc(2027, 1, 10, 5)),
    ('考试时间：2027/1/10 晚上', DateTime.utc(2027, 1, 10, 10, 40)),
  ]) {
    test('maps ${value.$1} to its class-period start', () {
      final exam = parseImportedExam(value.$1)!;
      expect(exam.startsAt, value.$2);
      expect(exam.sourceText, value.$1);
    });
  }

  test('rejects incomplete, invalid, and untimed exam details', () {
    expect(parseImportedExam('考试：另行通知'), isNull);
    expect(parseImportedExam('2027年2月30日上午'), isNull);
    expect(parseImportedExam('2027年1月10日'), isNull);
  });
}
