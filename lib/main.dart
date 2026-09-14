import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import 'app/app.dart';
import 'ui/app_window_controller.dart';
import 'ui/super_otc_font.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final windowController = isDesktopWindowPlatform
      ? DesktopWindowController(
          sizeStore: FileWindowSizeStore(
            File(
              '${(await getApplicationSupportDirectory()).path}/window_size.json',
            ),
          ),
        )
      : UnsupportedWindowController();
  if (windowController case final DesktopWindowController desktop) {
    await desktop.initialize();
  }
  await SuperOtcFontLoader.load();
  runApp(PkuManagerApp(windowController: windowController));
}
