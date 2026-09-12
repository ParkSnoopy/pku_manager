import 'dart:convert';
import 'dart:io';

import '../features/settings/appearance_controller.dart';

final class FileDeviceSettingsStore implements DeviceSettingsStore {
  FileDeviceSettingsStore(this.file);

  final File file;

  @override
  double loadUiScale() {
    if (!file.existsSync()) return 1.5;
    final decoded = jsonDecode(file.readAsStringSync());
    if (decoded is! Map<String, dynamic> || decoded['uiScale'] is! num) {
      throw const FormatException('Invalid device settings');
    }
    final value = (decoded['uiScale'] as num).toDouble();
    final steps = (value * 20).round();
    if (value < .5 || value > 2 || (steps / 20 - value).abs() > 0.000001) {
      throw const FormatException('Invalid UI scale');
    }
    return steps / 20;
  }

  @override
  void saveUiScale(double value) {
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(jsonEncode({'uiScale': value}), flush: true);
  }

  @override
  void purge() {
    if (file.existsSync()) file.deleteSync();
  }
}
