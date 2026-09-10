import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:tray_manager/tray_manager.dart' as tray;
import 'package:window_manager/window_manager.dart';

import '../domain/application_close_action.dart';

const desktopLaunchSize = Size(1600, 900);
const desktopWindowOptions = WindowOptions(
  size: desktopLaunchSize,
  center: true,
  title: 'PKU Manager',
);
const _desktopTrayPng =
    'macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_32.png';
const _desktopTrayIco = 'windows/runner/resources/app_icon.ico';
String get desktopTrayIconPath =>
    Platform.isWindows ? _desktopTrayIco : _desktopTrayPng;

bool get isDesktopWindowPlatform =>
    !kIsWeb &&
    switch (defaultTargetPlatform) {
      TargetPlatform.linux ||
      TargetPlatform.macOS ||
      TargetPlatform.windows => true,
      _ => false,
    };

abstract class AppWindowController extends ChangeNotifier {
  bool get supported;
  bool get isFullScreen;
  Future<void> toggleFullScreen();
  Future<void> configureCloseAction(
    ApplicationCloseAction action, {
    required String showLabel,
    required String exitLabel,
  });
}

final class UnsupportedWindowController extends AppWindowController {
  @override
  bool get supported => false;

  @override
  bool get isFullScreen => false;

  @override
  Future<void> toggleFullScreen() async {}

  @override
  Future<void> configureCloseAction(
    ApplicationCloseAction action, {
    required String showLabel,
    required String exitLabel,
  }) async {}
}

abstract interface class DesktopWindowBackend {
  Future<void> ensureInitialized();
  void addListener(WindowListener listener);
  void removeListener(WindowListener listener);
  Future<bool> isFullScreen();
  Future<void> waitUntilReadyToShow(
    WindowOptions options,
    Future<void> Function() callback,
  );
  Future<void> show();
  Future<void> hide();
  Future<void> focus();
  Future<void> destroy();
  Future<void> setFullScreen(bool value);
  Future<void> setPreventClose(bool value);
}

abstract interface class SystemTrayBackend {
  bool get available;
  void addListener(tray.TrayListener listener);
  void removeListener(tray.TrayListener listener);
  Future<void> setIcon(String path);
  Future<void> setToolTip(String value);
  Future<void> setContextMenu(tray.Menu menu);
  Future<void> destroy();
}

final class _WindowManagerBackend implements DesktopWindowBackend {
  const _WindowManagerBackend();

  @override
  void addListener(WindowListener listener) =>
      windowManager.addListener(listener);
  @override
  Future<void> destroy() => windowManager.destroy();
  @override
  Future<void> ensureInitialized() => windowManager.ensureInitialized();
  @override
  Future<void> focus() => windowManager.focus();
  @override
  Future<void> hide() => windowManager.hide();
  @override
  Future<bool> isFullScreen() => windowManager.isFullScreen();
  @override
  void removeListener(WindowListener listener) =>
      windowManager.removeListener(listener);
  @override
  Future<void> setFullScreen(bool value) => windowManager.setFullScreen(value);
  @override
  Future<void> setPreventClose(bool value) =>
      windowManager.setPreventClose(value);
  @override
  Future<void> show() => windowManager.show();
  @override
  Future<void> waitUntilReadyToShow(
    WindowOptions options,
    Future<void> Function() callback,
  ) async {
    await windowManager.waitUntilReadyToShow(options);
    await callback();
  }
}

final class _TrayManagerBackend implements SystemTrayBackend {
  const _TrayManagerBackend();

  @override
  bool get available =>
      !Platform.isLinux ||
      (Platform.environment['DBUS_SESSION_BUS_ADDRESS']?.isNotEmpty ?? false);
  @override
  void addListener(tray.TrayListener listener) =>
      tray.trayManager.addListener(listener);
  @override
  Future<void> destroy() => tray.trayManager.destroy();
  @override
  void removeListener(tray.TrayListener listener) =>
      tray.trayManager.removeListener(listener);
  @override
  Future<void> setContextMenu(tray.Menu menu) =>
      tray.trayManager.setContextMenu(menu);
  @override
  Future<void> setIcon(String path) => tray.trayManager.setIcon(path);
  @override
  Future<void> setToolTip(String value) => tray.trayManager.setToolTip(value);
}

final class DesktopWindowController extends AppWindowController
    with WindowListener, tray.TrayListener {
  DesktopWindowController({
    DesktopWindowBackend? windowBackend,
    SystemTrayBackend? trayBackend,
  }) : _window = windowBackend ?? const _WindowManagerBackend(),
       _tray = trayBackend ?? const _TrayManagerBackend();

  final DesktopWindowBackend _window;
  final SystemTrayBackend _tray;
  bool _isFullScreen = false;
  bool _trayReady = false;
  bool _exiting = false;
  ApplicationCloseAction _closeAction = ApplicationCloseAction.closeApp;
  String _showLabel = 'Show application';
  String _exitLabel = 'Close the app';

  @override
  bool get supported => true;

  @override
  bool get isFullScreen => _isFullScreen;

  Future<void> initialize() async {
    await _window.ensureInitialized();
    _window.addListener(this);
    _tray.addListener(this);
    await _window.setPreventClose(true);
    _isFullScreen = await _window.isFullScreen();
    await _window.waitUntilReadyToShow(desktopWindowOptions, showWindow);
  }

  @override
  Future<void> toggleFullScreen() async {
    final fullScreen = !_isFullScreen;
    await _window.setFullScreen(fullScreen);
    _updateFullScreen(fullScreen);
  }

  @override
  Future<void> configureCloseAction(
    ApplicationCloseAction action, {
    required String showLabel,
    required String exitLabel,
  }) async {
    _closeAction = action;
    _showLabel = showLabel;
    _exitLabel = exitLabel;
    if (_trayReady && action == ApplicationCloseAction.closeApp) {
      await _destroyTray();
    } else if (_trayReady) {
      await _setTrayMenu();
    }
  }

  Future<void> handleWindowClose() async {
    if (_exiting) return;
    if (_closeAction == ApplicationCloseAction.closeApp) {
      _exiting = true;
      await _destroyTray();
      await _window.destroy();
      return;
    }
    if (!_tray.available) {
      await showWindow();
      return;
    }
    try {
      await _ensureTray();
      await _window.hide();
    } catch (error, stackTrace) {
      debugPrint('System tray could not be opened: $error\n$stackTrace');
      await showWindow();
    }
  }

  Future<void> showWindow() async {
    await _window.show();
    await _window.focus();
  }

  Future<void> _ensureTray() async {
    if (!_trayReady) {
      await _tray.setIcon(desktopTrayIconPath);
      if (!Platform.isLinux) await _tray.setToolTip('PKU Manager');
      await _setTrayMenu();
      _trayReady = true;
      return;
    }
    await _setTrayMenu();
  }

  Future<void> _setTrayMenu() => _tray.setContextMenu(
    tray.Menu(
      items: [
        tray.MenuItem(key: 'show_window', label: _showLabel),
        tray.MenuItem.separator(),
        tray.MenuItem(key: 'exit_app', label: _exitLabel),
      ],
    ),
  );

  Future<void> _destroyTray() async {
    if (!_trayReady) return;
    _trayReady = false;
    await _tray.destroy();
  }

  Future<void> _exit() async {
    if (_exiting) return;
    _exiting = true;
    await _destroyTray();
    await _window.destroy();
  }

  Future<void> _reportFailure(Future<void> operation) async {
    try {
      await operation;
    } catch (error, stackTrace) {
      debugPrint('$error\n$stackTrace');
    }
  }

  void _run(Future<void> operation) => unawaited(_reportFailure(operation));

  @override
  void onWindowClose() => _run(handleWindowClose());

  @override
  void onTrayIconMouseDown() => _run(showWindow());

  @override
  void onTrayMenuItemClick(tray.MenuItem menuItem) {
    switch (menuItem.key) {
      case 'show_window':
        _run(showWindow());
        break;
      case 'exit_app':
        _run(_exit());
        break;
    }
  }

  @override
  void onWindowEnterFullScreen() => _updateFullScreen(true);

  @override
  void onWindowLeaveFullScreen() => _updateFullScreen(false);

  void _updateFullScreen(bool value) {
    if (_isFullScreen == value) return;
    _isFullScreen = value;
    notifyListeners();
  }

  @override
  void dispose() {
    _window.removeListener(this);
    _tray.removeListener(this);
    _run(_destroyTray());
    super.dispose();
  }
}
