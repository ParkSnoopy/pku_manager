import 'package:flutter/material.dart';

import '../../l10n/app_strings.dart';
import '../timetable/timetable_color.dart';
import 'appearance_controller.dart';
import 'color_picker_dialog.dart';

const appearanceAccents = <Color>[
  Color(0xff171717),
  Color(0xff00695c),
  Color(0xff1565c0),
  Color(0xff6a1b9a),
  Color(0xffad1457),
  Color(0xffef6c00),
];

class SettingsPage extends StatelessWidget {
  const SettingsPage({
    super.key,
    required this.controller,
    this.colorPicker = showAppColorPicker,
  });

  final AppearanceController controller;
  final ColorPickerLauncher colorPicker;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) => Material(
      color: Colors.transparent,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            AppStrings.of(context).text(AppText.settings),
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 32),
          Text(
            AppStrings.of(context).text(AppText.theme),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          Text(AppStrings.of(context).text(AppText.accentColor)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final color in appearanceAccents)
                Semantics(
                  label: 'Accent ${color.toARGB32().toRadixString(16)}',
                  selected: controller.accent == color,
                  button: true,
                  child: IconButton(
                    key: ValueKey(
                      'accent-${color.toARGB32().toRadixString(16)}',
                    ),
                    onPressed: () => controller.setAccent(color),
                    icon: Icon(
                      controller.accent == color
                          ? Icons.check_circle
                          : Icons.circle,
                      color: color,
                      size: 32,
                    ),
                  ),
                ),
              Semantics(
                label: AppStrings.of(context).text(AppText.chooseColor),
                button: true,
                child: IconButton(
                  key: const ValueKey('custom-accent-color'),
                  tooltip: AppStrings.of(context).text(AppText.chooseColor),
                  onPressed: () async {
                    final color = await colorPicker(
                      context,
                      color: controller.accent,
                      title: AppStrings.of(context).text(AppText.chooseColor),
                    );
                    controller.setAccent(color);
                  },
                  icon: Stack(
                    alignment: Alignment.center,
                    children: [
                      Icon(Icons.circle, color: controller.accent, size: 32),
                      const Icon(Icons.palette_outlined, size: 18),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(AppStrings.of(context).text(AppText.rollPalette)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              for (final (index, palette) in rollPalettes.indexed)
                IconButton(
                  key: ValueKey('roll-palette-$index'),
                  tooltip: '${index + 1}',
                  onPressed: () => controller.setRollPalette(index),
                  icon: Stack(
                    alignment: Alignment.center,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (final color in palette)
                            Container(width: 8, height: 28, color: color),
                        ],
                      ),
                      if (controller.rollPaletteIndex == index)
                        const Icon(Icons.check, color: Colors.black),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 32),
          Row(
            children: [
              Expanded(
                child: Text(AppStrings.of(context).text(AppText.fontScale)),
              ),
              Text('${controller.fontScale.toStringAsFixed(2)}×'),
            ],
          ),
          Slider(
            key: const ValueKey('font-scale'),
            min: 1,
            max: 2,
            divisions: 20,
            value: controller.fontScale,
            label: '${controller.fontScale.toStringAsFixed(2)}×',
            onChanged: controller.setFontScale,
          ),
          Row(
            children: [
              Expanded(
                child: Text(AppStrings.of(context).text(AppText.fontWeight)),
              ),
              Text(
                AppStrings.of(context)
                    .text(_fontWeightText(controller.fontWeightValue)),
              ),
            ],
          ),
          Slider(
            key: const ValueKey('font-weight'),
            min: 100,
            max: 900,
            divisions: 8,
            value: controller.fontWeightValue.toDouble(),
            label: AppStrings.of(context)
                .text(_fontWeightText(controller.fontWeightValue)),
            onChanged: (value) => controller.setFontWeight(value.round()),
          ),
          const SizedBox(height: 32),
          Text(
            AppStrings.of(context).text(AppText.language),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              key: const ValueKey('language-cycle'),
              onPressed: controller.cycleLanguage,
              icon: const Icon(Icons.language),
              label: Text(
                AppStrings.of(context).text(switch (controller.language) {
                  AppLanguage.ko => AppText.korean,
                  AppLanguage.en => AppText.english,
                  AppLanguage.zhHans => AppText.chinese,
                }),
              ),
            ),
          ),
          const SizedBox(height: 24),
          SwitchListTile(
            key: const ValueKey('show-roll-navbar'),
            contentPadding: EdgeInsets.zero,
            title: Text(AppStrings.of(context).text(AppText.showRollInNavbar)),
            value: controller.showRollInNavbar,
            onChanged: controller.setShowRollInNavbar,
          ),
        ],
      ),
    ),
  );
}

AppText _fontWeightText(int value) => switch (value) {
  100 => AppText.thin,
  200 => AppText.extraLight,
  300 => AppText.light,
  400 => AppText.regular,
  500 => AppText.medium,
  600 => AppText.semiBold,
  700 => AppText.bold,
  800 => AppText.extraBold,
  900 => AppText.black,
  _ => throw ArgumentError.value(value, 'value'),
};
