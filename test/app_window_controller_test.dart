import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';
import 'package:pku_manager/domain/application_close_action.dart';
import 'package:pku_manager/ui/app_window_controller.dart';
import 'package:tray_manager/tray_manager.dart' as tray;
import 'package:window_manager/window_manager.dart';

void main() {
  test('file window size store round-trips valid dimensions', () async {
    final directory = await Directory.systemTemp.createTemp('pku-window-size-');
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/window-size.json');
    final store = FileWindowSizeStore(file);

    expect(await store.load(), isNull);
    await store.save(const Size(901, 701));
    expect(await store.load(), const Size(901, 701));
    await file.writeAsString('{"width":0,"height":701}');
    expect(await store.load(), isNull);
  });

  test('desktop tray is ready at launch and handles close actions', () async {
    final window = _WindowBackend();
    final systemTray = _TrayBackend();
    final controller = DesktopWindowController(
      windowBackend: window,
      displayBackend: const _DisplayBackend(),
      trayBackend: systemTray,
    );
    addTearDown(controller.dispose);
    await controller.initialize();
    expect(window.options!.size, const Size(1280, 720));
    expect(window.options!.center, isTrue);
    expect(window.preventClose, isTrue);
    expect(systemTray.iconPath, desktopTrayIconPath);
    expect(
      systemTray.menu!.getMenuItem('show_window')!.label,
      'Show application',
    );

    await controller.configureCloseAction(
      ApplicationCloseAction.exitToSystemTray,
      showLabel: 'Show application',
      exitLabel: 'Close the app',
    );
    await controller.handleWindowClose();
    expect(window.hideCount, 1);
    expect(window.destroyCount, 0);
    expect(
      systemTray.menu!.getMenuItem('show_window')!.label,
      'Show application',
    );

    controller.onTrayIconMouseDown();
    await Future<void>.delayed(Duration.zero);
    expect(window.showCount, 2);
    expect(window.focusCount, 2);

    await controller.configureCloseAction(
      ApplicationCloseAction.closeApp,
      showLabel: 'Show application',
      exitLabel: 'Close the app',
    );
    expect(systemTray.destroyCount, 0);
    await controller.handleWindowClose();
    expect(systemTray.destroyCount, 1);
    expect(window.destroyCount, 1);
  });

  test('unavailable tray keeps the application window visible', () async {
    final window = _WindowBackend();
    final systemTray = _TrayBackend()..available = false;
    final controller = DesktopWindowController(
      windowBackend: window,
      displayBackend: const _DisplayBackend(),
      trayBackend: systemTray,
    );
    addTearDown(controller.dispose);
    await controller.initialize();
    await controller.configureCloseAction(
      ApplicationCloseAction.exitToSystemTray,
      showLabel: 'Show application',
      exitLabel: 'Close the app',
    );

    await controller.handleWindowClose();

    expect(window.hideCount, 0);
    expect(window.showCount, 2);
    expect(window.focusCount, 2);
    expect(window.destroyCount, 0);
  });

  test('restores and remembers the last ordinary window size', () async {
    final window = _WindowBackend();
    final store = _SizeStore(const Size(900, 700));
    final controller = DesktopWindowController(
      windowBackend: window,
      displayBackend: const _DisplayBackend(),
      sizeStore: store,
      trayBackend: _TrayBackend(),
    );
    addTearDown(controller.dispose);

    await controller.initialize();
    expect(window.options!.size, const Size(900, 700));
    expect(window.options!.center, isFalse);

    window.size = const Size(1000, 750);
    controller.onWindowResize();
    await Future<void>.delayed(const Duration(milliseconds: 250));
    expect(store.size, const Size(1000, 750));

    window
      ..maximized = true
      ..size = const Size(1600, 900);
    controller.onWindowResize();
    await Future<void>.delayed(const Duration(milliseconds: 250));
    expect(store.size, const Size(1000, 750));
  });

  test('tray setup failure does not block application launch', () async {
    final window = _WindowBackend();
    final systemTray = _TrayBackend()..setIconError = StateError('no tray');
    final controller = DesktopWindowController(
      windowBackend: window,
      displayBackend: const _DisplayBackend(),
      trayBackend: systemTray,
    );
    addTearDown(controller.dispose);

    await controller.initialize();

    expect(window.showCount, 1);
    expect(window.focusCount, 1);
    expect(window.destroyCount, 0);
  });
}

final class _WindowBackend implements DesktopWindowBackend {
  final listeners = <WindowListener>[];
  bool preventClose = false;
  int hideCount = 0;
  int destroyCount = 0;
  int showCount = 0;
  int focusCount = 0;
  bool maximized = false;
  Size size = const Size(1280, 720);
  WindowOptions? options;

  @override
  void addListener(WindowListener listener) => listeners.add(listener);

  @override
  Future<void> destroy() async => destroyCount++;

  @override
  Future<void> ensureInitialized() async {}

  @override
  Future<void> focus() async => focusCount++;

  @override
  Future<void> hide() async => hideCount++;

  @override
  Future<bool> isFullScreen() async => false;

  @override
  Future<bool> isMaximized() async => maximized;

  @override
  Future<Size> getSize() async => size;

  @override
  void removeListener(WindowListener listener) => listeners.remove(listener);

  @override
  Future<void> setFullScreen(bool value) async {}

  @override
  Future<void> setPreventClose(bool value) async => preventClose = value;

  @override
  Future<void> show() async => showCount++;

  @override
  Future<void> waitUntilReadyToShow(
    WindowOptions options,
    Future<void> Function() callback,
  ) {
    this.options = options;
    return callback();
  }
}

final class _DisplayBackend implements DesktopDisplayBackend {
  const _DisplayBackend();

  @override
  Future<Size> primaryWorkAreaSize() async => const Size(1600, 900);
}

final class _SizeStore implements WindowSizeStore {
  _SizeStore(this.size);

  Size? size;

  @override
  Future<Size?> load() async => size;

  @override
  Future<void> save(Size value) async => size = value;
}

final class _TrayBackend implements SystemTrayBackend {
  final listeners = <tray.TrayListener>[];
  int destroyCount = 0;
  String? iconPath;
  tray.Menu? menu;
  Object? setIconError;

  @override
  bool available = true;

  @override
  void addListener(tray.TrayListener listener) => listeners.add(listener);

  @override
  Future<void> destroy() async => destroyCount++;

  @override
  void removeListener(tray.TrayListener listener) => listeners.remove(listener);

  @override
  Future<void> setContextMenu(tray.Menu value) async => menu = value;

  @override
  Future<void> setIcon(String value) async {
    if (setIconError case final error?) throw error;
    iconPath = value;
  }

  @override
  Future<void> setToolTip(String value) async {}
}
