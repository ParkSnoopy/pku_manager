import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/app_strings.dart';
import '../timetable/timetable_color.dart';
import 'appearance_controller.dart';
import 'color_picker_dialog.dart';

const appearanceAccents = <Color>[
  Color(0xffffb3ba),
  Color(0xffffd3b6),
  Color(0xfffffacd),
  Color(0xffbffcc6),
  Color(0xffbfd7ff),
  Color(0xffdcc6e0),
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
          SwitchListTile(
            key: const ValueKey('dark-mode'),
            contentPadding: EdgeInsets.zero,
            title: Text(AppStrings.of(context).text(AppText.darkMode)),
            value: controller.darkMode,
            onChanged: controller.setDarkMode,
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
          SwitchListTile(
            key: const ValueKey('blend-accent-theme'),
            contentPadding: EdgeInsets.zero,
            title: Text(
              AppStrings.of(context).text(AppText.blendAccentIntoTheme),
            ),
            value: controller.blendAccentIntoTheme,
            onChanged: controller.setBlendAccentIntoTheme,
          ),
          const SizedBox(height: 24),
          Text(AppStrings.of(context).text(AppText.rollPalette)),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: PopupMenuButton<int>(
                key: const ValueKey('roll-palette-menu'),
                tooltip: rollPalettes[controller.rollPaletteIndex].name,
                onSelected: controller.setRollPalette,
                itemBuilder: (context) => [
                  for (final (index, palette) in rollPalettes.indexed)
                    PopupMenuItem<int>(
                      key: ValueKey('roll-palette-$index'),
                      value: index,
                      child: Row(
                        children: [
                          _PaletteSwatches(
                            colors: index == 0
                                ? controller.customPalette
                                : palette.colors,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              palette.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (controller.rollPaletteIndex == index)
                            const Padding(
                              padding: EdgeInsets.only(left: 8),
                              child: Icon(Icons.check, size: 20),
                            ),
                        ],
                      ),
                    ),
                ],
                child: InputDecorator(
                  decoration: const InputDecoration(
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                  ),
                  child: Row(
                    children: [
                      _PaletteSwatches(colors: controller.paletteColors),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          rollPalettes[controller.rollPaletteIndex].name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const Icon(Icons.arrow_drop_down),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (controller.rollPaletteIndex == 0) ...[
            const SizedBox(height: 12),
            Text(AppStrings.of(context).text(AppText.customPalette)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final (index, color) in controller.customPalette.indexed)
                  IconButton(
                    key: ValueKey('custom-palette-color-$index'),
                    tooltip: AppStrings.of(context).text(AppText.chooseColor),
                    onPressed: () async {
                      final selected = await colorPicker(
                        context,
                        color: color,
                        title: AppStrings.of(context).text(AppText.chooseColor),
                      );
                      controller.setCustomPaletteColor(index, selected);
                    },
                    icon: Icon(Icons.circle, color: color, size: 32),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 32),
          Text(AppStrings.of(context).text(AppText.timetableIndexColor)),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              key: const ValueKey('timetable-index-color'),
              onPressed: () async {
                final color = await colorPicker(
                  context,
                  color: controller.timetableIndexColor,
                  title: AppStrings.of(context)
                      .text(AppText.timetableIndexColor),
                );
                controller.setTimetableIndexColor(color);
              },
              icon: Icon(Icons.circle, color: controller.timetableIndexColor),
              label: Text(AppStrings.of(context).text(AppText.chooseColor)),
            ),
          ),
          SwitchListTile(
            key: const ValueKey('auto-text-color'),
            contentPadding: EdgeInsets.zero,
            title: Text(AppStrings.of(context).text(AppText.autoTextColor)),
            value: controller.autoTextColor,
            onChanged: controller.setAutoTextColor,
          ),
          const SizedBox(height: 32),
          Text(
            AppStrings.of(context).text(AppText.font),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              key: const ValueKey('font-family-cycle'),
              onPressed: controller.cycleFontFamily,
              icon: const Icon(Icons.text_fields),
              label: Text(
                AppStrings.of(context).text(
                  controller.fontFamily == AppFontFamily.serif
                      ? AppText.serif
                      : AppText.sans,
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          _PercentSetting(
            label: AppStrings.of(context).text(AppText.fontScale),
            fieldKey: const ValueKey('font-scale-input'),
            sliderKey: const ValueKey('font-scale'),
            min: .8,
            max: 1.5,
            divisions: 14,
            value: controller.fontScale,
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
          _PercentSetting(
            label: AppStrings.of(context).text(AppText.timetableFontScale),
            fieldKey: const ValueKey('timetable-font-scale-input'),
            sliderKey: const ValueKey('timetable-font-scale'),
            min: 1,
            max: 2,
            divisions: 20,
            value: controller.timetableFontScale,
            onChanged: controller.setTimetableFontScale,
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

class _PaletteSwatches extends StatelessWidget {
  const _PaletteSwatches({required this.colors});

  final List<Color> colors;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      for (final color in colors)
        Container(width: 14, height: 24, color: color),
    ],
  );
}

class _PercentSetting extends StatefulWidget {
  const _PercentSetting({
    required this.label,
    required this.fieldKey,
    required this.sliderKey,
    required this.min,
    required this.max,
    required this.divisions,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final Key fieldKey;
  final Key sliderKey;
  final double min;
  final double max;
  final int divisions;
  final double value;
  final ValueChanged<double> onChanged;

  @override
  State<_PercentSetting> createState() => _PercentSettingState();
}

class _PercentSettingState extends State<_PercentSetting> {
  late final TextEditingController _controller = TextEditingController(
    text: _percent(widget.value),
  );
  late final FocusNode _focusNode = FocusNode();

  @override
  void didUpdateWidget(_PercentSetting oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_focusNode.hasFocus && oldWidget.value != widget.value) {
      _controller.text = _percent(widget.value);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _parse(String text) {
    final percent = int.tryParse(text);
    if (percent == null) return;
    final value = percent / 100;
    if (value >= widget.min && value <= widget.max) {
      widget.onChanged(value);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Row(
        children: [
          Expanded(child: Text(widget.label)),
          SizedBox(
            width: 88,
            child: TextField(
              key: widget.fieldKey,
              controller: _controller,
              focusNode: _focusNode,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              textAlign: TextAlign.end,
              decoration: const InputDecoration(suffixText: '%', isDense: true),
              onChanged: _parse,
            ),
          ),
        ],
      ),
      Slider(
        key: widget.sliderKey,
        min: widget.min,
        max: widget.max,
        divisions: widget.divisions,
        value: widget.value,
        label: '${_percent(widget.value)}%',
        onChanged: (value) {
          _controller.text = _percent(value);
          widget.onChanged(value);
        },
      ),
    ],
  );
}

String _percent(double value) => (value * 100).round().toString();

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
