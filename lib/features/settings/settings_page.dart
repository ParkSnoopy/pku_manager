import 'package:flutter/material.dart';

import '../../l10n/app_strings.dart';
import 'appearance_controller.dart';

const appearanceAccents = <Color>[
  Color(0xff171717),
  Color(0xff00695c),
  Color(0xff1565c0),
  Color(0xff6a1b9a),
  Color(0xffad1457),
  Color(0xffef6c00),
];

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key, required this.controller});

  final AppearanceController controller;

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
            ],
          ),
          const SizedBox(height: 32),
          Text(
            AppStrings.of(context).text(AppText.language),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          SegmentedButton<AppLanguage>(
            showSelectedIcon: false,
            segments: [
              ButtonSegment(
                value: AppLanguage.ko,
                label: Text(AppStrings.of(context).text(AppText.korean)),
              ),
              ButtonSegment(
                value: AppLanguage.en,
                label: Text(AppStrings.of(context).text(AppText.english)),
              ),
              ButtonSegment(
                value: AppLanguage.zhHans,
                label: Text(AppStrings.of(context).text(AppText.chinese)),
              ),
            ],
            selected: {controller.language},
            onSelectionChanged: (values) =>
                controller.setLanguage(values.single),
          ),
        ],
      ),
    ),
  );
}
