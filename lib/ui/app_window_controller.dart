import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:tray_manager/tray_manager.dart' as tray;
import 'package:window_manager/window_manager.dart';

import '../domain/application_close_action.dart';

const desktopInitialSizeFraction = .8;

WindowOptions desktopWindowOptions(Size size, {required bool center}) =>
    WindowOptions(title: 'PKU Manager', size: size, center: center);
const _linuxDesktopTrayPng = 'linux/runner/resources/pku_manager.png';
const _macosDesktopTrayPng =
    'macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_32.png';
const _desktopTrayIco = 'windows/runner/resources/app_icon.ico';
String get desktopTrayIconPath => Platform.isWindows
    ? _desktopTrayIco
    : Platform.isLinux
    ? _linuxDesktopTrayPng
    : _macosDesktopTrayPng;

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
  Future<bool> isMaximized();
  Future<Size> getSize();
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

abstract interface class DesktopDisplayBackend {
  Future<Size> primaryWorkAreaSize();
}

abstract interface class WindowSizeStore {
  Future<Size?> load();
  Future<void> save(Size size);
}

final class FileWindowSizeStore implements WindowSizeStore {
  FileWindowSizeStore(this.file);

  final File file;

  @override
  Future<Size?> load() async {
    if (!await file.exists()) return null;
    try {
      final value = jsonDecode(await file.readAsString());
      if (value is! Map<String, dynamic> ||
          value['width'] is! num ||
          value['height'] is! num) {
        return null;
      }
      final width = (value['width'] as num).toDouble();
      final height = (value['height'] as num).toDouble();
      if (!width.isFinite || !height.isFinite || width < 1 || height < 1) {
        return null;
      }
      return Size(width, height);
    } on FormatException {
      return null;
    } on FileSystemException {
      return null;
    }
  }

  @override
  Future<void> save(Size size) async {
    await file.parent.create(recursive: true);
    await file.writeAsString(
      jsonEncode({'width': size.width, 'height': size.height}),
      flush: true,
    );
  }
}

final class _ScreenRetrieverBackend implements DesktopDisplayBackend {
  const _ScreenRetrieverBackend();

  @override
  Future<Size> primaryWorkAreaSize() async {
    final display = await screenRetriever.getPrimaryDisplay();
    return display.visibleSize ?? display.size;
  }
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
  Future<bool> isMaximized() => windowManager.isMaximized();
  @override
  Future<Size> getSize() => windowManager.getSize();
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

typedef LinuxTrayMethodInvoker = Future<void> Function(
  String method,
  Map<String, Object?> arguments,
);

final class TrayManagerBackend implements SystemTrayBackend {
  TrayManagerBackend({
    AssetBundle? assetBundle,
    Map<String, String>? environment,
    LinuxTrayMethodInvoker? invokeLinuxMethod,
  }) : _assetBundle = assetBundle ?? rootBundle,
       _environment = environment ?? Platform.environment,
       _invokeLinuxMethod =
           invokeLinuxMethod ??
           ((method, arguments) =>
               _channel.invokeMethod<void>(method, arguments));

  static const _channel = MethodChannel('tray_manager');
  final AssetBundle _assetBundle;
  final Map<String, String> _environment;
  final LinuxTrayMethodInvoker _invokeLinuxMethod;
  File? _stagedLinuxIcon;

  @override
  bool get available =>
      !Platform.isLinux ||
      (Platform.environment['DBUS_SESSION_BUS_ADDRESS']?.isNotEmpty ?? false);
  @override
  void addListener(tray.TrayListener listener) =>
      tray.trayManager.addListener(listener);
  @override
  Future<void> destroy() async {
    await tray.trayManager.destroy();
    final icon = _stagedLinuxIcon;
    _stagedLinuxIcon = null;
    if (icon == null) return;
    try {
      await icon.parent.delete(recursive: true);
    } on FileSystemException {
      // Runtime directories are cleared by the operating system at logout.
    }
  }

  @override
  void removeListener(tray.TrayListener listener) =>
      tray.trayManager.removeListener(listener);
  @override
  Future<void> setContextMenu(tray.Menu menu) =>
      tray.trayManager.setContextMenu(menu);
  @override
  Future<void> setIcon(String path) async {
    if (!Platform.isLinux) {
      await tray.trayManager.setIcon(path);
      return;
    }
    final runtimeDirectory = _environment['XDG_RUNTIME_DIR'];
    if (runtimeDirectory == null || runtimeDirectory.isEmpty) {
      throw StateError('XDG_RUNTIME_DIR is unavailable.');
    }
    final directory = Directory('$runtimeDirectory/pku_manager-$pid');
    await directory.create();
    final icon = File('${directory.path}/tray_icon.png');
    final data = await _assetBundle.load(path);
    await icon.writeAsBytes(
      data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      flush: true,
    );
    _stagedLinuxIcon = icon;
    await _invokeLinuxMethod('setIcon', {
      'id': 'com.parksnoopy.pku_manager',
      'iconPath': icon.path,
    });
  }

  @override
  Future<void> setToolTip(String value) => tray.trayManager.setToolTip(value);
}

final class DesktopWindowController extends AppWindowController
    with WindowListener, tray.TrayListener {
  DesktopWindowController({
    DesktopWindowBackend? windowBackend,
    DesktopDisplayBackend? displayBackend,
    this.sizeStore,
    SystemTrayBackend? trayBackend,
  }) : _window = windowBackend ?? const _WindowManagerBackend(),
       _display = displayBackend ?? const _ScreenRetrieverBackend(),
       _tray = trayBackend ?? TrayManagerBackend();

  final DesktopWindowBackend _window;
  final DesktopDisplayBackend _display;
  final WindowSizeStore? sizeStore;
  final SystemTrayBackend _tray;
  Timer? _saveSizeTimer;
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
    await _tryEnsureTray();
    final savedSize = await sizeStore?.load();
    final size =
        savedSize ??
        (await _display.primaryWorkAreaSize()) * desktopInitialSizeFraction;
    await _window.waitUntilReadyToShow(
      desktopWindowOptions(size, center: savedSize == null),
      showWindow,
    );
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
    if (_trayReady) {
      await _setTrayMenu();
    } else {
      await _tryEnsureTray();
    }
  }

  Future<void> handleWindowClose() async {
    if (_exiting) return;
    if (_closeAction == ApplicationCloseAction.closeApp) {
      _exiting = true;
      _saveSizeTimer?.cancel();
      await _saveWindowSize();
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

  Future<void> _tryEnsureTray() async {
    if (!_tray.available) return;
    try {
      await _ensureTray();
    } catch (error, stackTrace) {
      debugPrint('System tray could not be opened: $error\n$stackTrace');
    }
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
    _saveSizeTimer?.cancel();
    await _saveWindowSize();
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
  void onWindowResize() {
    _saveSizeTimer?.cancel();
    _saveSizeTimer = Timer(
      const Duration(milliseconds: 200),
      () => _run(_saveWindowSize()),
    );
  }

  Future<void> _saveWindowSize() async {
    final store = sizeStore;
    if (store == null || _isFullScreen || await _window.isMaximized()) return;
    final size = await _window.getSize();
    if (size.width >= 1 && size.height >= 1) await store.save(size);
  }

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
    _saveSizeTimer?.cancel();
    _window.removeListener(this);
    _tray.removeListener(this);
    _run(_destroyTray());
    super.dispose();
  }
}
