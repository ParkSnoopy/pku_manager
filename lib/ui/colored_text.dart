import 'package:flutter/material.dart';

Color coloredTextForeground(
  BuildContext context,
  Color background, {
  required bool autoTextColor,
}) {
  if (autoTextColor) {
    return background.computeLuminance() > .5 ? Colors.black : Colors.white;
  }
  return Theme.of(context).brightness == Brightness.dark
      ? Colors.white
      : Colors.black;
}
