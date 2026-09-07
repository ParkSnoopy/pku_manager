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
}
