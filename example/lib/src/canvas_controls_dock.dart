import 'package:flutter/material.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';

import 'canvas_example_view_model.dart';
import 'canvas_json_dialogs.dart';

final class CanvasCameraIndicator extends StatelessWidget {
  const CanvasCameraIndicator({required this.cameraX, super.key});

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

final class CanvasCameraPanControls extends StatelessWidget {
  const CanvasCameraPanControls({required this.onPan, super.key});

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
            key: const ValueKey('camera.pan.left'),
            icon: const Icon(Icons.arrow_back),
            onPressed: () => onPan(const Offset(-50, 0)),
            iconSize: 18,
            tooltip: 'Pan left',
          ),
          IconButton(
            key: const ValueKey('camera.pan.right'),
            icon: const Icon(Icons.arrow_forward),
            onPressed: () => onPan(const Offset(50, 0)),
            iconSize: 18,
            tooltip: 'Pan right',
          ),
          IconButton(
            key: const ValueKey('camera.pan.up'),
            icon: const Icon(Icons.arrow_upward),
            onPressed: () => onPan(const Offset(0, -50)),
            iconSize: 18,
            tooltip: 'Pan up',
          ),
          IconButton(
            key: const ValueKey('camera.pan.down'),
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

// The dock intentionally owns the visible command groups in one row so spacing
// and overflow behavior stay auditable at the screen boundary.
// ignore: coupling-between-object-classes
final class CanvasControlsDock extends StatelessWidget {
  const CanvasControlsDock({required this.viewModel, super.key});

  final CanvasExampleViewModel viewModel;

  @override
  // The dock mirrors the legacy example command order; splitting each command
  // group would hide the visual contract this file owns.
  // ignore: source-lines-of-code
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
          _ModeToggle(viewModel: viewModel),
          const VerticalDivider(indent: 20, endIndent: 20, width: 24),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: viewModel.mode == CanvasInteractionMode.draw
                    ? _drawControls()
                    : _moveControls(),
              ),
            ),
          ),
          const VerticalDivider(indent: 20, endIndent: 20, width: 24),
          _GridMenu(viewModel: viewModel),
          _SystemMenu(viewModel: viewModel),
        ],
      ),
    );
  }

  List<Widget> _drawControls() {
    return [
      _DrawToolButton(
        key: const ValueKey('tool.pencil'),
        tool: CanvasDrawTool.pencil,
        currentTool: viewModel.drawTool,
        icon: Icons.brush,
        label: 'Pen',
        onPressed: viewModel.setDrawTool,
      ),
      _DrawToolButton(
        key: const ValueKey('tool.marker'),
        tool: CanvasDrawTool.marker,
        currentTool: viewModel.drawTool,
        icon: Icons.border_color,
        label: 'Marker',
        onPressed: viewModel.setDrawTool,
      ),
      _DrawToolButton(
        key: const ValueKey('tool.line'),
        tool: CanvasDrawTool.line,
        currentTool: viewModel.drawTool,
        icon: Icons.show_chart,
        label: 'Line',
        onPressed: viewModel.setDrawTool,
      ),
      _DrawToolButton(
        key: const ValueKey('tool.eraser'),
        tool: CanvasDrawTool.eraser,
        currentTool: viewModel.drawTool,
        icon: Icons.auto_fix_normal,
        label: 'Eraser',
        onPressed: viewModel.setDrawTool,
      ),
      const VerticalDivider(indent: 25, endIndent: 25, width: 20),
      _ColorPalette(
        keyPrefix: 'draw.color',
        colors: viewModel.penColors,
        selected: viewModel.drawColor,
        onSelected: viewModel.setDrawColor,
      ),
    ];
  }

  List<Widget> _moveControls() {
    return [
      _ActionButton(
        key: const ValueKey('selection.rotate.ccw'),
        icon: Icons.rotate_left,
        label: 'Rotate L',
        onTap: viewModel.hasSelection
            ? viewModel.rotateSelectionCounterClockwise
            : null,
      ),
      _ActionButton(
        key: const ValueKey('selection.rotate.cw'),
        icon: Icons.rotate_right,
        label: 'Rotate R',
        onTap: viewModel.hasSelection
            ? viewModel.rotateSelectionClockwise
            : null,
      ),
      _ActionButton(
        key: const ValueKey('selection.flip.vertical'),
        icon: Icons.flip,
        label: 'Flip V',
        onTap: viewModel.hasSelection ? viewModel.flipSelectionVertical : null,
        quarterTurns: 1,
      ),
      _ActionButton(
        key: const ValueKey('selection.flip.horizontal'),
        icon: Icons.flip,
        label: 'Flip H',
        onTap: viewModel.hasSelection
            ? viewModel.flipSelectionHorizontal
            : null,
      ),
      _ActionButton(
        key: const ValueKey('selection.delete'),
        icon: Icons.delete_outline,
        label: 'Delete',
        onTap: viewModel.hasSelection ? viewModel.deleteSelection : null,
        color: Colors.red,
      ),
      _ActionButton(
        key: const ValueKey('sample.add'),
        icon: Icons.add_box_outlined,
        label: 'Add Sample',
        onTap: viewModel.requestAddSample,
      ),
    ];
  }
}

final class _ModeToggle extends StatelessWidget {
  const _ModeToggle({required this.viewModel});

  final CanvasExampleViewModel viewModel;

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
            key: const ValueKey('mode.move'),
            mode: CanvasInteractionMode.move,
            currentMode: viewModel.mode,
            icon: Icons.pan_tool_alt,
            onTap: viewModel.setInteractionMode,
          ),
          _SmallModeButton(
            key: const ValueKey('mode.draw'),
            mode: CanvasInteractionMode.draw,
            currentMode: viewModel.mode,
            icon: Icons.edit,
            onTap: viewModel.setInteractionMode,
          ),
        ],
      ),
    );
  }
}

final class _SmallModeButton extends StatelessWidget {
  const _SmallModeButton({
    required this.mode,
    required this.currentMode,
    required this.icon,
    required this.onTap,
    super.key,
  });

  final CanvasInteractionMode mode;
  final CanvasInteractionMode currentMode;
  final IconData icon;
  final ValueChanged<CanvasInteractionMode> onTap;

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

final class _DrawToolButton extends StatelessWidget {
  const _DrawToolButton({
    required this.tool,
    required this.currentTool,
    required this.icon,
    required this.label,
    required this.onPressed,
    super.key,
  });

  final CanvasDrawTool tool;
  final CanvasDrawTool currentTool;
  final IconData icon;
  final String label;
  final ValueChanged<CanvasDrawTool> onPressed;

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

final class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
    this.quarterTurns = 0,
    super.key,
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

final class _GridMenu extends StatelessWidget {
  const _GridMenu({required this.viewModel});

  final CanvasExampleViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final gridSizes = viewModel.gridSizes.isEmpty
        ? [viewModel.grid.cellSize]
        : viewModel.gridSizes;

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
          key: const ValueKey('grid.menu'),
          icon: Icon(
            viewModel.grid.enabled ? Icons.grid_4x4 : Icons.grid_off,
            color: viewModel.grid.enabled
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
                      value: viewModel.grid.enabled,
                      onChanged: (enabled) {
                        viewModel.setGridEnabled(enabled: enabled);
                      },
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
                    key: const ValueKey('grid.size.menu'),
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
                    selected: {viewModel.grid.cellSize},
                    onSelectionChanged: (selection) {
                      viewModel.setGridCellSize(selection.first);
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

final class _SystemMenu extends StatelessWidget {
  const _SystemMenu({required this.viewModel});

  final CanvasExampleViewModel viewModel;

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
          key: const ValueKey('system.menu'),
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
                  children: viewModel.backgroundColors.map((color) {
                    final isSelected = viewModel.background.color == color;

                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        key: ValueKey('background.color.${color.toARGB32()}'),
                        onTap: () => viewModel.setBackgroundColor(color),
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
                key: const ValueKey('json.export'),
                leadingIcon: const Icon(Icons.download_outlined, size: 20),
                onPressed: () => showCanvasJsonExportDialog(context, viewModel),
                child: const Text('Export (JSON)'),
              ),
              MenuItemButton(
                key: const ValueKey('json.import'),
                leadingIcon: const Icon(Icons.upload_outlined, size: 20),
                onPressed: () => showCanvasJsonImportDialog(context, viewModel),
                child: const Text('Import (JSON)'),
              ),
              const Divider(indent: 16, endIndent: 16),
              MenuItemButton(
                key: const ValueKey('canvas.clear'),
                leadingIcon: Icon(
                  Icons.delete_sweep_outlined,
                  color: colorScheme.error,
                  size: 20,
                ),
                onPressed: viewModel.clearCanvas,
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

final class _ColorPalette extends StatelessWidget {
  const _ColorPalette({
    required this.keyPrefix,
    required this.colors,
    required this.selected,
    required this.onSelected,
  });

  final String keyPrefix;
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
          key: ValueKey('$keyPrefix.${color.toARGB32()}'),
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
