import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

const desktopLaunchSize = Size(1600, 900);
const desktopWindowOptions = WindowOptions(
  size: desktopLaunchSize,
  center: true,
  title: 'PKU Manager',
);

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
}

final class UnsupportedWindowController extends AppWindowController {
  @override
  bool get supported => false;

  @override
  bool get isFullScreen => false;

  @override
  Future<void> toggleFullScreen() async {}
}

final class DesktopWindowController extends AppWindowController
    with WindowListener {
  DesktopWindowController();

  bool _isFullScreen = false;

  @override
  bool get supported => true;

  @override
  bool get isFullScreen => _isFullScreen;

  Future<void> initialize() async {
    await windowManager.ensureInitialized();
    windowManager.addListener(this);
    _isFullScreen = await windowManager.isFullScreen();
    unawaited(
      windowManager.waitUntilReadyToShow(desktopWindowOptions, () async {
        await windowManager.show();
        await windowManager.focus();
      }),
    );
  }

  @override
  Future<void> toggleFullScreen() async {
    final fullScreen = !_isFullScreen;
    await windowManager.setFullScreen(fullScreen);
    _updateFullScreen(fullScreen);
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
    windowManager.removeListener(this);
    super.dispose();
  }
}
