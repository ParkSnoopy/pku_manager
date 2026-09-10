import 'package:flutter_test/flutter_test.dart';
import 'package:pku_manager/domain/application_close_action.dart';
import 'package:pku_manager/ui/app_window_controller.dart';
import 'package:tray_manager/tray_manager.dart' as tray;
import 'package:window_manager/window_manager.dart';

void main() {
  test('desktop close action hides to tray or destroys the app', () async {
    final window = _WindowBackend();
    final systemTray = _TrayBackend();
    final controller = DesktopWindowController(
      windowBackend: window,
      trayBackend: systemTray,
    );
    addTearDown(controller.dispose);
    await controller.initialize();
    expect(window.preventClose, isTrue);

    controller.configureCloseAction(
      ApplicationCloseAction.exitToSystemTray,
      showLabel: 'Show application',
      exitLabel: 'Close the app',
    );
    await controller.handleWindowClose();
    expect(window.hideCount, 1);
    expect(window.destroyCount, 0);
    expect(systemTray.iconPath, desktopTrayIconPath);
    expect(
      systemTray.menu!.getMenuItem('show_window')!.label,
      'Show application',
    );

    controller.onTrayIconMouseDown();
    await Future<void>.delayed(Duration.zero);
    expect(window.showCount, 2);
    expect(window.focusCount, 2);

    controller.configureCloseAction(
      ApplicationCloseAction.closeApp,
      showLabel: 'Show application',
      exitLabel: 'Close the app',
    );
    await controller.handleWindowClose();
    expect(systemTray.destroyCount, 1);
    expect(window.destroyCount, 1);
  });

  test('unavailable tray keeps the application window visible', () async {
    final window = _WindowBackend();
    final systemTray = _TrayBackend()..available = false;
    final controller = DesktopWindowController(
      windowBackend: window,
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
}

final class _WindowBackend implements DesktopWindowBackend {
  final listeners = <WindowListener>[];
  bool preventClose = false;
  int hideCount = 0;
  int destroyCount = 0;
  int showCount = 0;
  int focusCount = 0;

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
  ) => callback();
}

final class _TrayBackend implements SystemTrayBackend {
  final listeners = <tray.TrayListener>[];
  int destroyCount = 0;
  String? iconPath;
  tray.Menu? menu;

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
  Future<void> setIcon(String value) async => iconPath = value;

  @override
  Future<void> setToolTip(String value) async {}
}
