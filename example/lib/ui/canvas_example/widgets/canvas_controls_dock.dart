import 'package:flutter/material.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';

class CanvasCameraIndicator extends StatelessWidget {
  const CanvasCameraIndicator({super.key, required this.cameraX});

  final double cameraX;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.videocam_outlined, size: 18),
          const SizedBox(width: 8),
          Text(
            'Camera X: ${cameraX.toStringAsFixed(0)}',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class CanvasCameraPanControls extends StatelessWidget {
  const CanvasCameraPanControls({super.key, required this.onPan});

  final ValueChanged<Offset> onPan;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => onPan(const Offset(-50, 0)),
            iconSize: 18,
            tooltip: 'Pan left',
          ),
          IconButton(
            icon: const Icon(Icons.arrow_forward),
            onPressed: () => onPan(const Offset(50, 0)),
            iconSize: 18,
            tooltip: 'Pan right',
          ),
          IconButton(
            icon: const Icon(Icons.arrow_upward),
            onPressed: () => onPan(const Offset(0, -50)),
            iconSize: 18,
            tooltip: 'Pan up',
          ),
          IconButton(
            icon: const Icon(Icons.arrow_downward),
            onPressed: () => onPan(const Offset(0, 50)),
            iconSize: 18,
            tooltip: 'Pan down',
          ),
        ],
      ),
    );
  }
}

class CanvasControlsDock extends StatelessWidget {
  const CanvasControlsDock({
    super.key,
    required this.isDrawMode,
    required this.hasSelection,
    required this.currentMode,
    required this.currentDrawTool,
    required this.penColors,
    required this.selectedDrawColor,
    required this.isGridEnabled,
    required this.gridCellSize,
    required this.gridSizes,
    required this.backgroundColors,
    required this.selectedBackgroundColor,
    required this.onModeChanged,
    required this.onDrawToolChanged,
    required this.onDrawColorChanged,
    required this.onRotateLeft,
    required this.onRotateRight,
    required this.onFlipVertical,
    required this.onFlipHorizontal,
    required this.onDeleteSelection,
    required this.onAddSample,
    required this.onGridEnabledChanged,
    required this.onGridCellSizeChanged,
    required this.onBackgroundColorChanged,
    required this.onExportJson,
    required this.onImportJson,
    required this.onClearCanvas,
  });

  final bool isDrawMode;
  final bool hasSelection;
  final CanvasMode currentMode;
  final DrawTool currentDrawTool;
  final List<Color> penColors;
  final Color selectedDrawColor;
  final bool isGridEnabled;
  final double gridCellSize;
  final List<double> gridSizes;
  final List<Color> backgroundColors;
  final Color selectedBackgroundColor;
  final ValueChanged<CanvasMode> onModeChanged;
  final ValueChanged<DrawTool> onDrawToolChanged;
  final ValueChanged<Color> onDrawColorChanged;
  final VoidCallback onRotateLeft;
  final VoidCallback onRotateRight;
  final VoidCallback onFlipVertical;
  final VoidCallback onFlipHorizontal;
  final VoidCallback onDeleteSelection;
  final VoidCallback onAddSample;
  final ValueChanged<bool> onGridEnabledChanged;
  final ValueChanged<double> onGridCellSizeChanged;
  final ValueChanged<Color> onBackgroundColorChanged;
  final VoidCallback onExportJson;
  final VoidCallback onImportJson;
  final VoidCallback onClearCanvas;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 84,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          _ModeToggle(currentMode: currentMode, onModeChanged: onModeChanged),
          const VerticalDivider(indent: 20, endIndent: 20, width: 24),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  if (isDrawMode) ...[
                    _DrawToolButton(
                      tool: DrawTool.pen,
                      currentTool: currentDrawTool,
                      icon: Icons.brush,
                      label: 'Pen',
                      onPressed: onDrawToolChanged,
                    ),
                    _DrawToolButton(
                      tool: DrawTool.highlighter,
                      currentTool: currentDrawTool,
                      icon: Icons.border_color,
                      label: 'Marker',
                      onPressed: onDrawToolChanged,
                    ),
                    _DrawToolButton(
                      tool: DrawTool.line,
                      currentTool: currentDrawTool,
                      icon: Icons.show_chart,
                      label: 'Line',
                      onPressed: onDrawToolChanged,
                    ),
                    _DrawToolButton(
                      tool: DrawTool.eraser,
                      currentTool: currentDrawTool,
                      icon: Icons.auto_fix_normal,
                      label: 'Eraser',
                      onPressed: onDrawToolChanged,
                    ),
                    const VerticalDivider(indent: 25, endIndent: 25, width: 20),
                    _ColorPalette(
                      colors: penColors,
                      selected: selectedDrawColor,
                      onSelected: onDrawColorChanged,
                    ),
                  ] else ...[
                    _ActionButton(
                      icon: Icons.rotate_left,
                      label: 'Rotate L',
                      onTap: hasSelection ? onRotateLeft : null,
                    ),
                    _ActionButton(
                      icon: Icons.rotate_right,
                      label: 'Rotate R',
                      onTap: hasSelection ? onRotateRight : null,
                    ),
                    _ActionButton(
                      icon: Icons.flip,
                      label: 'Flip V',
                      onTap: hasSelection ? onFlipVertical : null,
                      quarterTurns: 1,
                    ),
                    _ActionButton(
                      icon: Icons.flip,
                      label: 'Flip H',
                      onTap: hasSelection ? onFlipHorizontal : null,
                    ),
                    _ActionButton(
                      icon: Icons.delete_outline,
                      label: 'Delete',
                      onTap: hasSelection ? onDeleteSelection : null,
                      color: Colors.red,
                    ),
                    _ActionButton(
                      icon: Icons.add_box_outlined,
                      label: 'Add Sample',
                      onTap: onAddSample,
                    ),
                  ],
                ],
              ),
            ),
          ),
          const VerticalDivider(indent: 20, endIndent: 20, width: 24),
          _GridMenu(
            isGridEnabled: isGridEnabled,
            gridCellSize: gridCellSize,
            gridSizes: gridSizes,
            onGridEnabledChanged: onGridEnabledChanged,
            onGridCellSizeChanged: onGridCellSizeChanged,
          ),
          _SystemMenu(
            backgroundColors: backgroundColors,
            selectedBackgroundColor: selectedBackgroundColor,
            onBackgroundColorChanged: onBackgroundColorChanged,
            onExportJson: onExportJson,
            onImportJson: onImportJson,
            onClearCanvas: onClearCanvas,
          ),
        ],
      ),
    );
  }
}

class _ModeToggle extends StatelessWidget {
  const _ModeToggle({required this.currentMode, required this.onModeChanged});

  final CanvasMode currentMode;
  final ValueChanged<CanvasMode> onModeChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          _SmallModeButton(
            mode: CanvasMode.move,
            currentMode: currentMode,
            icon: Icons.pan_tool_alt,
            onTap: onModeChanged,
          ),
          _SmallModeButton(
            mode: CanvasMode.draw,
            currentMode: currentMode,
            icon: Icons.edit,
            onTap: onModeChanged,
          ),
        ],
      ),
    );
  }
}

class _SmallModeButton extends StatelessWidget {
  const _SmallModeButton({
    required this.mode,
    required this.currentMode,
    required this.icon,
    required this.onTap,
  });

  final CanvasMode mode;
  final CanvasMode currentMode;
  final IconData icon;
  final ValueChanged<CanvasMode> onTap;

  @override
  Widget build(BuildContext context) {
    final isSelected = currentMode == mode;
    return GestureDetector(
      onTap: () => onTap(mode),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          boxShadow: isSelected
              ? [const BoxShadow(color: Colors.black12, blurRadius: 4)]
              : null,
        ),
        child: Icon(
          icon,
          color: isSelected ? Colors.blue[800] : Colors.grey[600],
        ),
      ),
    );
  }
}

class _DrawToolButton extends StatelessWidget {
  const _DrawToolButton({
    required this.tool,
    required this.currentTool,
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final DrawTool tool;
  final DrawTool currentTool;
  final IconData icon;
  final String label;
  final ValueChanged<DrawTool> onPressed;

  @override
  Widget build(BuildContext context) {
    final isSelected = currentTool == tool;
    return IconButton(
      icon: Icon(icon),
      onPressed: () => onPressed(tool),
      color: isSelected ? Colors.blue : Colors.grey[700],
      iconSize: 28,
      tooltip: label,
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
    this.quarterTurns = 0,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Color? color;
  final int quarterTurns;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: RotatedBox(
        quarterTurns: quarterTurns,
        child: Icon(
          icon,
          color: onTap == null ? Colors.grey[300] : (color ?? Colors.grey[800]),
        ),
      ),
      onPressed: onTap,
      tooltip: label,
      iconSize: 28,
    );
  }
}

class _GridMenu extends StatelessWidget {
  const _GridMenu({
    required this.isGridEnabled,
    required this.gridCellSize,
    required this.gridSizes,
    required this.onGridEnabledChanged,
    required this.onGridCellSizeChanged,
  });

  final bool isGridEnabled;
  final double gridCellSize;
  final List<double> gridSizes;
  final ValueChanged<bool> onGridEnabledChanged;
  final ValueChanged<double> onGridCellSizeChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return MenuAnchor(
      alignmentOffset: const Offset(-240, 0),
      style: MenuStyle(
        padding: WidgetStateProperty.all(
          const EdgeInsets.symmetric(vertical: 12),
        ),
        shape: WidgetStateProperty.all(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        ),
        elevation: WidgetStateProperty.all(12),
      ),
      builder: (context, controller, child) {
        return IconButton(
          icon: Icon(
            isGridEnabled ? Icons.grid_4x4 : Icons.grid_off,
            color: isGridEnabled
                ? colorScheme.primary
                : colorScheme.onSurfaceVariant,
          ),
          onPressed: () =>
              controller.isOpen ? controller.close() : controller.open(),
          tooltip: 'Grid Settings',
          iconSize: 28,
        );
      },
      menuChildren: [
        SizedBox(
          width: 340,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer.withValues(
                          alpha: 0.4,
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.grid_on,
                        size: 18,
                        color: colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Grid Appearance',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: colorScheme.onSurface,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Display Grid',
                            style: theme.textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Enable alignment guides',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: isGridEnabled,
                      onChanged: onGridEnabledChanged,
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Text(
                  'Cell Size',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<double>(
                    showSelectedIcon: false,
                    segments: gridSizes.map((size) {
                      return ButtonSegment<double>(
                        value: size,
                        label: Text(
                          size.toInt().toString(),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      );
                    }).toList(),
                    selected: {gridCellSize},
                    onSelectionChanged: (selection) {
                      onGridCellSizeChanged(selection.first);
                    },
                    style: SegmentedButton.styleFrom(
                      visualDensity: VisualDensity.comfortable,
                      selectedBackgroundColor: colorScheme.primary,
                      selectedForegroundColor: colorScheme.onPrimary,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SystemMenu extends StatelessWidget {
  const _SystemMenu({
    required this.backgroundColors,
    required this.selectedBackgroundColor,
    required this.onBackgroundColorChanged,
    required this.onExportJson,
    required this.onImportJson,
    required this.onClearCanvas,
  });

  final List<Color> backgroundColors;
  final Color selectedBackgroundColor;
  final ValueChanged<Color> onBackgroundColorChanged;
  final VoidCallback onExportJson;
  final VoidCallback onImportJson;
  final VoidCallback onClearCanvas;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return MenuAnchor(
      alignmentOffset: const Offset(-240, 0),
      style: MenuStyle(
        padding: WidgetStateProperty.all(
          const EdgeInsets.symmetric(vertical: 12),
        ),
        shape: WidgetStateProperty.all(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        ),
        elevation: WidgetStateProperty.all(12),
      ),
      builder: (context, controller, child) {
        return IconButton(
          icon: Icon(Icons.settings, color: colorScheme.onSurfaceVariant),
          onPressed: () =>
              controller.isOpen ? controller.close() : controller.open(),
          tooltip: 'System Menu',
          iconSize: 28,
        );
      },
      menuChildren: [
        SizedBox(
          width: 280,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                child: Row(
                  children: [
                    Icon(
                      Icons.palette_outlined,
                      size: 18,
                      color: colorScheme.primary,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Background',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                child: Row(
                  children: backgroundColors.map((color) {
                    final isSelected = selectedBackgroundColor == color;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: () => onBackgroundColorChanged(color),
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected
                                  ? colorScheme.primary
                                  : Colors.black12,
                              width: isSelected ? 2 : 1,
                            ),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: colorScheme.primary.withValues(
                                        alpha: 0.3,
                                      ),
                                      blurRadius: 4,
                                    ),
                                  ]
                                : null,
                          ),
                          child: isSelected
                              ? Icon(
                                  Icons.check,
                                  size: 16,
                                  color: color.computeLuminance() > 0.5
                                      ? Colors.black
                                      : Colors.white,
                                )
                              : null,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const Divider(indent: 16, endIndent: 16),
              MenuItemButton(
                leadingIcon: const Icon(Icons.download_outlined, size: 20),
                onPressed: onExportJson,
                child: const Text('Export (JSON)'),
              ),
              MenuItemButton(
                leadingIcon: const Icon(Icons.upload_outlined, size: 20),
                onPressed: onImportJson,
                child: const Text('Import (JSON)'),
              ),
              const Divider(indent: 16, endIndent: 16),
              MenuItemButton(
                leadingIcon: Icon(
                  Icons.delete_sweep_outlined,
                  color: colorScheme.error,
                  size: 20,
                ),
                onPressed: onClearCanvas,
                child: Text(
                  'Clear Canvas',
                  style: TextStyle(
                    color: colorScheme.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ],
    );
  }
}

class _ColorPalette extends StatelessWidget {
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
