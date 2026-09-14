import 'dart:convert';
import 'dart:io';

import '../features/settings/appearance_controller.dart';

final class FileDeviceSettingsStore implements DeviceSettingsStore {
  FileDeviceSettingsStore(this.file);

  static const _formatVersion = 1;

  final File file;

  @override
  double loadUiScale() {
    final settings = _load();
    if (settings.legacy) {
      _save(defaultUiScale, TimetableFontFamily.app);
      return defaultUiScale;
    }
    return settings.uiScale;
  }

  @override
  TimetableFontFamily loadTimetableFontFamily() => _load().timetableFontFamily;

  ({double uiScale, TimetableFontFamily timetableFontFamily, bool legacy})
  _load() {
    if (!file.existsSync()) {
      return (
        uiScale: defaultUiScale,
        timetableFontFamily: TimetableFontFamily.app,
        legacy: false,
      );
    }
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
    final fontValue = decoded['timetableFontFamily'] ?? 'app';
    if (fontValue is! String) {
      throw const FormatException('Invalid timetable font family');
    }
    return (
      uiScale: steps / 20,
      timetableFontFamily: TimetableFontFamily.parse(fontValue),
      legacy: formatVersion == null,
    );
  }

  @override
  void saveUiScale(double value) => _save(value, loadTimetableFontFamily());

  @override
  void saveTimetableFontFamily(TimetableFontFamily value) =>
      _save(loadUiScale(), value);

  void _save(double uiScale, TimetableFontFamily timetableFontFamily) {
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(
      jsonEncode({
        'formatVersion': _formatVersion,
        'uiScale': uiScale,
        'timetableFontFamily': timetableFontFamily.code,
      }),
      flush: true,
    );
  }

  @override
  void purge() {
    if (file.existsSync()) file.deleteSync();
  }
}
