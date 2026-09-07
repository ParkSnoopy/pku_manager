import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pku_manager/data/app_database.dart';
import 'package:pku_manager/data/sqlite_appearance_store.dart';
import 'package:pku_manager/features/settings/appearance_controller.dart';
import 'package:pku_manager/features/settings/settings_page.dart';

void main() {
  test('theme and repeated palette rolls persist as typed SQLite values', () {
    final database = AppDatabase(':memory:');
    addTearDown(database.close);
    final store = SqliteAppearanceStore(database);
    final controller = AppearanceController(store);
    expect(controller.dark, isFalse);
    expect(controller.paletteSeed, 0);

    controller.setDark(true);
    controller.setAccent(const Color(0xff00695c));
    controller.rollPalette();
    controller.rollPalette();

    final restored = AppearanceController(store);
    expect(restored.dark, isTrue);
    expect(restored.accent, const Color(0xff00695c));
    expect(restored.paletteSeed, 2);
  });

  testWidgets('settings page edits theme without a dropdown', (tester) async {
    final database = AppDatabase(':memory:');
    addTearDown(database.close);
    final controller = AppearanceController(SqliteAppearanceStore(database));
    await tester.pumpWidget(
      MaterialApp(home: SettingsPage(controller: controller)),
    );
    expect(find.text('Theme'), findsOneWidget);
    expect(find.byType(DropdownButton<dynamic>), findsNothing);
    await tester.tap(find.text('Dark'));
    await tester.pump();
    expect(controller.dark, isTrue);
    await tester.tap(find.byKey(const ValueKey('accent-ff00695c')));
    await tester.pump();
    expect(controller.accent, const Color(0xff00695c));
  });
}
