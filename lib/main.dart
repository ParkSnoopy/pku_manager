import 'package:flutter/material.dart';

import 'app/app.dart';
import 'ui/super_otc_font.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SuperOtcFontLoader.load();
  runApp(const PkuManagerApp());
}
