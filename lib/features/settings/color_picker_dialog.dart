import 'package:flex_color_picker/flex_color_picker.dart';
import 'package:flutter/material.dart';

typedef ColorPickerLauncher = Future<Color> Function(
  BuildContext context, {
  required Color color,
  required String title,
});

Future<Color> showAppColorPicker(
  BuildContext context, {
  required Color color,
  required String title,
}) => showColorPickerDialog(
  context,
  color,
  pickersEnabled: const {
    ColorPickerType.both: false,
    ColorPickerType.primary: true,
    ColorPickerType.accent: true,
    ColorPickerType.bw: false,
    ColorPickerType.custom: false,
    ColorPickerType.wheel: true,
  },
  enableTonalPalette: true,
  showColorCode: true,
  showColorName: false,
  showMaterialName: false,
  dialogTitle: Text(title),
  constraints: const BoxConstraints(maxWidth: 520, maxHeight: 680),
);
