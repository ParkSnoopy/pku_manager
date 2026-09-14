import 'package:flutter_test/flutter_test.dart';
import 'package:pku_manager/domain/semester.dart';

void main() {
  test('build definition is validated rather than silently defaulted', () {
    const raw = String.fromEnvironment('SEMESTER_WEEKS', defaultValue: '16');
    final count = int.tryParse(raw);
    if (count == null) {
      expect(SemesterConfig.fromEnvironment, throwsFormatException);
    } else if (count < 1 || count > 53) {
      expect(SemesterConfig.fromEnvironment, throwsRangeError);
    } else {
      expect(SemesterConfig.fromEnvironment().weekCount, count);
    }
  });
}
