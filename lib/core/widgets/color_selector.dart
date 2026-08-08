import 'package:flutter/material.dart';

import '../../features/accounts/presentation/account_style.dart';
import 'custom_color_picker.dart';

/// A horizontal row of preset color swatches plus a custom-color swatch that
/// opens the full [showCustomColorPicker]. The selection is delivered through
/// [onChanged] as either a preset name or a `#RRGGBB` hex string.
class ColorSelectorRow extends StatelessWidget {
  const ColorSelectorRow({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  /// The stored color: a preset name or a hex string.
  final String selected;

  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isCustom = isHexColor(selected);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final c in colorChoices)
          _PresetSwatch(
            color: colorFromName(c),
            selected: selected == c,
            onTap: () => onChanged(c),
          ),
        _CustomSwatch(
          color: colorFromName(selected),
          selected: isCustom,
          borderColor: scheme.onSurface,
          onTap: () => showCustomColorPicker(
            context,
            initial: colorFromName(selected),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}

class _PresetSwatch extends StatelessWidget {
  const _PresetSwatch({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: selected
              ? Border.all(width: 3, color: scheme.onSurface)
              : null,
        ),
        child: selected
            ? Icon(Icons.check, color: scheme.onPrimary, size: 18)
            : null,
      ),
    );
  }
}

class _CustomSwatch extends StatelessWidget {
  const _CustomSwatch({
    required this.color,
    required this.selected,
    required this.borderColor,
    required this.onTap,
  });

  final Color color;
  final bool selected;
  final Color borderColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: const Key('custom-color-swatch'),
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        width: 40,
        height: 40,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const SweepGradient(
            colors: [
              Color(0xFFFF0000),
              Color(0xFFFFFF00),
              Color(0xFF00FF00),
              Color(0xFF00FFFF),
              Color(0xFF0000FF),
              Color(0xFFFF00FF),
              Color(0xFFFF0000),
            ],
          ),
          border: selected ? Border.all(width: 3, color: borderColor) : null,
        ),
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: selected ? color : Colors.white,
          ),
          child: Icon(
            Icons.colorize,
            size: 16,
            color: selected ? Colors.white : Colors.black54,
          ),
        ),
      ),
    );
  }
}
