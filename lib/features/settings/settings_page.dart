import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/app_strings.dart';
import '../../domain/application_close_action.dart';
import '../timetable/timetable_color.dart';
import 'appearance_controller.dart';
import 'color_picker_dialog.dart';

typedef AppDataAction = Future<bool> Function();

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
    this.showCloseAction = false,
    this.exportAppData,
    this.importAppData,
    this.purgeAppData,
  });

  final AppearanceController controller;
  final ColorPickerLauncher colorPicker;
  final bool showCloseAction;
  final AppDataAction? exportAppData;
  final AppDataAction? importAppData;
  final AppDataAction? purgeAppData;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) => Material(
      color: Colors.transparent,
      child: ListView(
        key: const ValueKey('settings-scroll'),
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
          _PercentSetting(
            label: AppStrings.of(context).text(AppText.uiScale),
            fieldKey: const ValueKey('ui-scale-input'),
            sliderKey: const ValueKey('ui-scale'),
            min: .5,
            max: 2,
            divisions: 30,
            value: controller.uiScale,
            onChanged: controller.setUiScale,
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
          if (showCloseAction) ...[
            const SizedBox(height: 24),
            SwitchListTile(
              key: const ValueKey('on-application-close'),
              contentPadding: EdgeInsets.zero,
              title: Text(
                AppStrings.of(context).text(AppText.onApplicationClose),
              ),
              subtitle: Text(
                AppStrings.of(context).text(
                  controller.applicationCloseAction ==
                          ApplicationCloseAction.exitToSystemTray
                      ? AppText.exitToSystemTray
                      : AppText.closeTheApp,
                ),
              ),
              value:
                  controller.applicationCloseAction ==
                  ApplicationCloseAction.exitToSystemTray,
              onChanged: (value) => controller.setApplicationCloseAction(
                value
                    ? ApplicationCloseAction.exitToSystemTray
                    : ApplicationCloseAction.closeApp,
              ),
            ),
          ],
          if (exportAppData != null && importAppData != null) ...[
            const SizedBox(height: 32),
            _AppDataControls(
              exportAppData: exportAppData!,
              importAppData: importAppData!,
              purgeAppData: purgeAppData,
            ),
          ],
        ],
      ),
    ),
  );
}

class _AppDataControls extends StatefulWidget {
  const _AppDataControls({
    required this.exportAppData,
    required this.importAppData,
    this.purgeAppData,
  });

  final AppDataAction exportAppData;
  final AppDataAction importAppData;
  final AppDataAction? purgeAppData;

  @override
  State<_AppDataControls> createState() => _AppDataControlsState();
}

class _AppDataControlsState extends State<_AppDataControls> {
  bool _busy = false;

  Future<void> _run(
    AppDataAction action,
    AppText success, {
    AppText failure = AppText.appDataTransferFailed,
  }) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final completed = await action();
      if (!mounted || !completed) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.of(context).text(success))),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.of(context).text(failure))),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _import() async {
    final strings = AppStrings.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(strings.text(AppText.importAppData)),
        content: Text(strings.text(AppText.importAppDataWarning)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.onSurface,
            ),
            child: Text(strings.text(AppText.cancel)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(strings.text(AppText.importAppData)),
          ),
        ],
      ),
    );
    if (confirmed ?? false) {
      await _run(widget.importAppData, AppText.appDataImported);
    }
  }

  Future<void> _purge() async {
    final strings = AppStrings.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(strings.text(AppText.purgeAppData)),
        content: Text(strings.text(AppText.purgeAppDataWarning)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.onSurface,
            ),
            child: Text(strings.text(AppText.cancel)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            child: Text(strings.text(AppText.purgeAppData)),
          ),
        ],
      ),
    );
    final action = widget.purgeAppData;
    if ((confirmed ?? false) && action != null) {
      await _run(
        action,
        AppText.appDataPurged,
        failure: AppText.appDataPurgeFailed,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          strings.text(AppText.appData),
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            OutlinedButton.icon(
              key: const ValueKey('export-app-data'),
              onPressed: _busy
                  ? null
                  : () => _run(widget.exportAppData, AppText.appDataExported),
              icon: const Icon(Icons.file_upload_outlined),
              label: Text(strings.text(AppText.exportAppData)),
            ),
            FilledButton.tonalIcon(
              key: const ValueKey('import-app-data'),
              onPressed: _busy ? null : _import,
              icon: const Icon(Icons.file_download_outlined),
              label: Text(strings.text(AppText.importAppData)),
            ),
            if (widget.purgeAppData != null)
              TextButton.icon(
                key: const ValueKey('purge-app-data'),
                onPressed: _busy ? null : _purge,
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.error,
                ),
                icon: const Icon(Icons.delete_forever_outlined),
                label: Text(strings.text(AppText.purgeAppData)),
              ),
          ],
        ),
      ],
    );
  }
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
    final steps = (value - widget.min) * 20;
    if (value >= widget.min &&
        value <= widget.max &&
        (steps.roundToDouble() - steps).abs() < 0.000001) {
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
