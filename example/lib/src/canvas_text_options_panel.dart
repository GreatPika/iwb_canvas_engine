import 'package:flutter/material.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';

final class CanvasTextOptionsPanel extends StatelessWidget {
  const CanvasTextOptionsPanel({
    required this.element,
    required this.paletteColors,
    required this.lineHeightMinMultiplier,
    required this.lineHeightMaxMultiplier,
    required this.lineHeightMultiplier,
    required this.onToggleBold,
    required this.onToggleItalic,
    required this.onToggleUnderline,
    required this.onAlignChanged,
    required this.onFontSizeChanged,
    required this.onLineHeightMultiplierChanged,
    required this.onColorChanged,
    super.key,
  });

  final CanvasTextElement element;
  final List<Color> paletteColors;
  final double lineHeightMinMultiplier;
  final double lineHeightMaxMultiplier;
  final double lineHeightMultiplier;
  final VoidCallback onToggleBold;
  final VoidCallback onToggleItalic;
  final VoidCallback onToggleUnderline;
  final ValueChanged<TextAlign> onAlignChanged;
  final ValueChanged<double> onFontSizeChanged;
  final ValueChanged<double> onLineHeightMultiplierChanged;
  final ValueChanged<Color> onColorChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _TextStyleToggle(
                key: const ValueKey('text.bold'),
                icon: Icons.format_bold,
                active: element.isBold,
                onTap: onToggleBold,
              ),
              _TextStyleToggle(
                key: const ValueKey('text.italic'),
                icon: Icons.format_italic,
                active: element.isItalic,
                onTap: onToggleItalic,
              ),
              _TextStyleToggle(
                key: const ValueKey('text.underline'),
                icon: Icons.format_underline,
                active: element.isUnderline,
                onTap: onToggleUnderline,
              ),
              const VerticalDivider(width: 20),
              _AlignSelector(
                current: element.align,
                onAlignChanged: onAlignChanged,
              ),
              const VerticalDivider(width: 20),
              const Text(
                'Size: ',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Slider(
                key: const ValueKey('text.font.size.slider'),
                value: element.fontSize.clamp(10, 72).toDouble(),
                min: 10,
                max: 72,
                divisions: 10,
                onChanged: onFontSizeChanged,
              ),
              const VerticalDivider(width: 20),
              const Text(
                'Line Height: ',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Slider(
                key: const ValueKey('text.line.height.slider'),
                value: lineHeightMultiplier.clamp(
                  lineHeightMinMultiplier,
                  lineHeightMaxMultiplier,
                ),
                min: lineHeightMinMultiplier,
                max: lineHeightMaxMultiplier,
                divisions: 22,
                label: '${lineHeightMultiplier.toStringAsFixed(2)}x',
                onChanged: onLineHeightMultiplierChanged,
              ),
              const VerticalDivider(width: 20),
              _ColorPalette(
                colors: paletteColors,
                selected: element.color,
                onSelected: onColorChanged,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

final class _TextStyleToggle extends StatelessWidget {
  const _TextStyleToggle({
    required this.icon,
    required this.active,
    required this.onTap,
    super.key,
  });

  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon),
      color: active ? Colors.blue : Colors.grey,
      onPressed: onTap,
    );
  }
}

final class _AlignSelector extends StatelessWidget {
  const _AlignSelector({required this.current, required this.onAlignChanged});

  final TextAlign current;
  final ValueChanged<TextAlign> onAlignChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [TextAlign.left, TextAlign.center, TextAlign.right].map((
        align,
      ) {
        return IconButton(
          key: ValueKey('text.align.${align.name}'),
          icon: Icon(
            align == TextAlign.left
                ? Icons.format_align_left
                : align == TextAlign.center
                ? Icons.format_align_center
                : Icons.format_align_right,
          ),
          color: current == align ? Colors.blue : Colors.grey,
          onPressed: () => onAlignChanged(align),
        );
      }).toList(),
    );
  }
}

final class _ColorPalette extends StatelessWidget {
  const _ColorPalette({
    required this.colors,
    required this.selected,
    required this.onSelected,
  });

  final List<Color> colors;
  final Color selected;
  final ValueChanged<Color> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      children: List<Widget>.generate(colors.length, (index) {
        final color = colors[index];
        return GestureDetector(
          key: ValueKey('text.color.${color.toARGB32()}'),
          onTap: () => onSelected(color),
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(
                color: color == selected ? Colors.black : Colors.black12,
                width: color == selected ? 3 : 1,
              ),
              boxShadow: color == selected
                  ? [
                      BoxShadow(
                        color: color.withValues(alpha: 0.4),
                        blurRadius: 4,
                      ),
                    ]
                  : null,
            ),
          ),
        );
      }),
    );
  }
}
