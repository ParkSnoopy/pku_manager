import 'dart:convert';
import 'dart:io';

import '../features/settings/appearance_controller.dart';

final class FileDeviceSettingsStore implements DeviceSettingsStore {
  FileDeviceSettingsStore(this.file);

  static const _formatVersion = 1;

  final File file;

  @override
  double loadUiScale() {
    if (!file.existsSync()) return defaultUiScale;
    final decoded = jsonDecode(file.readAsStringSync());
    if (decoded is! Map<String, dynamic> || decoded['uiScale'] is! num) {
      throw const FormatException('Invalid device settings');
    }
    final formatVersion = decoded['formatVersion'];
    if (formatVersion != null && formatVersion != _formatVersion) {
      throw const FormatException('Unsupported device settings version');
    }
    final value = (decoded['uiScale'] as num).toDouble();
    final steps = (value * 20).round();
    if (value < .5 || value > 2 || (steps / 20 - value).abs() > 0.000001) {
      throw const FormatException('Invalid UI scale');
    }
    if (formatVersion == null) {
      saveUiScale(defaultUiScale);
      return defaultUiScale;
    }
    return steps / 20;
  }

  @override
  void saveUiScale(double value) {
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(
      jsonEncode({'formatVersion': _formatVersion, 'uiScale': value}),
      flush: true,
    );
  }

  @override
  void purge() {
    if (file.existsSync()) file.deleteSync();
  }
}
