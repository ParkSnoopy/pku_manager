import 'package:flutter_test/flutter_test.dart';
import 'package:pku_manager/l10n/app_strings.dart';

void main() {
  test('Korean is default and every supported language has every string', () {
    expect(AppLanguage.defaultLanguage, AppLanguage.ko);
    expect(AppStrings.supportedLocales.map((locale) => locale.languageCode), [
      'ko',
      'en',
      'zh',
    ]);
    for (final language in AppLanguage.values) {
      final strings = AppStrings(language.locale);
      for (final key in AppText.values) {
        expect(strings.text(key), isNotEmpty, reason: '$language $key');
      }
    }
  });

  test('time remaining uses the unified DDL expression', () {
    const duration = Duration(days: 1, hours: 2, minutes: 3);
    for (final language in AppLanguage.values) {
      expect(AppStrings(language.locale).deadline(duration), 'DDL: 1d 2h');
    }
    expect(
      AppStrings(AppLanguage.en.locale).deadline(const Duration(minutes: 43)),
      'DDL: 43m',
    );
  });
}
