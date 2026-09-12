import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pku_manager/ui/app_window_controller.dart';

void main() {
  test('Linux tray icon is staged outside the executable mount', () async {
    final runtimeDirectory = await Directory.systemTemp.createTemp(
      'pku_manager_tray_test.',
    );
    addTearDown(() => runtimeDirectory.delete(recursive: true));
    final iconBytes = Uint8List.fromList([1, 2, 3, 4]);
    Map<String, Object?>? arguments;
    final backend = TrayManagerBackend(
      assetBundle: _AssetBundle(iconBytes),
      environment: {'XDG_RUNTIME_DIR': runtimeDirectory.path},
      invokeLinuxMethod: (method, value) async {
        expect(method, 'setIcon');
        arguments = value;
      },
    );

    await backend.setIcon(desktopTrayIconPath);

    expect(desktopTrayIconPath, 'linux/runner/resources/pku_manager.png');
    final stagedPath = arguments!['iconPath']! as String;
    expect(stagedPath, startsWith('${runtimeDirectory.path}/'));
    expect(stagedPath, isNot(contains('flutter_assets')));
    expect(File(stagedPath).readAsBytesSync(), iconBytes);
  }, skip: !Platform.isLinux);
}

final class _AssetBundle extends CachingAssetBundle {
  _AssetBundle(this.bytes);

  final Uint8List bytes;

  @override
  Future<ByteData> load(String key) async => ByteData.sublistView(bytes);
}
