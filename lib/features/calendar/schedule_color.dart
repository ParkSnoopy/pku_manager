import 'package:flutter/material.dart';

const _scheduleColors = <Color>[
  Color(0xffffc8dd),
  Color(0xffffd6a5),
  Color(0xfffdffb6),
  Color(0xffcaffbf),
  Color(0xff9bf6ff),
  Color(0xffa0c4ff),
  Color(0xffbdb2ff),
];

Color scheduleColor(int id) =>
    _scheduleColors[id.abs() % _scheduleColors.length];

Color scheduleForeground(Color background) =>
    background.computeLuminance() > .5 ? Colors.black : Colors.white;
