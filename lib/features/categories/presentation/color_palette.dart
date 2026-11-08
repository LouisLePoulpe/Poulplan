import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';

/// Colors offered for categories and events (Material 600 shades, readable
/// with white text, plus the Poulplan brown).
const paletteColors = <int>[
  0xFFE53935,
  0xFFD81B60,
  0xFF8E24AA,
  0xFF5E35B1,
  0xFF3949AB,
  0xFF1E88E5,
  0xFF039BE5,
  0xFF00897B,
  0xFF43A047,
  0xFF7CB342,
  0xFFC0CA33,
  0xFFFDD835,
  0xFFFFB300,
  0xFFFB8C00,
  0xFF8F6400,
  0xFF6D4C41,
  0xFF757575,
  0xFF546E7A,
];

class ColorPalette extends StatelessWidget {
  const ColorPalette({
    super.key,
    required this.selected,
    required this.onSelected,
    this.allowNone = false,
    this.noneLabel,
  });

  final int? selected;
  final ValueChanged<int?> onSelected;
  final bool allowNone;
  final String? noneLabel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Wrap(
      children: [
        if (allowNone)
          Tooltip(
            message: noneLabel ?? '',
            child: _Swatch(
              color: scheme.surfaceContainerHighest,
              selected: selected == null,
              icon: Icons.format_color_reset,
              label: noneLabel,
              onTap: () => onSelected(null),
            ),
          ),
        for (final (i, c) in paletteColors.indexed)
          _Swatch(
            label: AppLocalizations.of(context).colorNumber(i + 1),
            color: Color(c),
            selected: selected == c,
            onTap: () => onSelected(c),
          ),
      ],
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.color,
    required this.selected,
    required this.onTap,
    this.icon,
    this.label,
  });

  final Color color;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final onColor =
        ThemeData.estimateBrightnessForColor(color) == Brightness.dark
        ? Colors.white
        : Colors.black;
    // 32 px disc, 48 px touch target.
    return Semantics(
      selected: selected,
      button: true,
      label: label,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: selected
                  ? Border.all(
                      color: Theme.of(context).colorScheme.onSurface,
                      width: 3,
                    )
                  : null,
            ),
            child: selected
                ? Icon(Icons.check, size: 18, color: onColor)
                : icon == null
                ? null
                : Icon(icon, size: 18, color: onColor),
          ),
        ),
      ),
    );
  }
}
