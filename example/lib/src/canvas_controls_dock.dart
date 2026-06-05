import 'package:flutter/material.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';

import 'canvas_example_view_model.dart';
import 'canvas_json_dialogs.dart';

// The indicator is a compact visual shell. Splitting its Flutter decoration
// would make the example harder to scan without reducing runtime risk.
// ignore: coupling-between-object-classes
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

// The four pan buttons are one cohesive camera affordance. Extra wrappers would
// only hide the key mapping between directions and offsets.
// ignore: coupling-between-object-classes
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
        children: _cameraPanCommands.map((command) {
          return _CameraPanButton(
            key: ValueKey(command.key),
            icon: command.icon,
            offset: command.offset,
            tooltip: command.tooltip,
            onPan: onPan,
          );
        }).toList(),
      ),
    );
  }
}

const _cameraPanCommands = [
  (
    key: 'camera.pan.left',
    icon: Icons.arrow_back,
    offset: Offset(-50, 0),
    tooltip: 'Pan left',
  ),
  (
    key: 'camera.pan.right',
    icon: Icons.arrow_forward,
    offset: Offset(50, 0),
    tooltip: 'Pan right',
  ),
  (
    key: 'camera.pan.up',
    icon: Icons.arrow_upward,
    offset: Offset(0, -50),
    tooltip: 'Pan up',
  ),
  (
    key: 'camera.pan.down',
    icon: Icons.arrow_downward,
    offset: Offset(0, 50),
    tooltip: 'Pan down',
  ),
];

final class _CameraPanButton extends StatelessWidget {
  const _CameraPanButton({
    required this.icon,
    required this.offset,
    required this.tooltip,
    required this.onPan,
    super.key,
  });

  final IconData icon;
  final Offset offset;
  final String tooltip;
  final ValueChanged<Offset> onPan;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon),
      onPressed: () => onPan(offset),
      iconSize: 18,
      tooltip: tooltip,
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
  // The dock mirrors the legacy example command order. Splitting each command
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
          Expanded(child: _ModeControlsStrip(viewModel: viewModel)),
          const VerticalDivider(indent: 20, endIndent: 20, width: 24),
          _GridMenu(viewModel: viewModel),
          _SystemMenu(viewModel: viewModel),
        ],
      ),
    );
  }
}

final class _ModeControlsStrip extends StatelessWidget {
  const _ModeControlsStrip({required this.viewModel});

  final CanvasExampleViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: viewModel.mode == CanvasInteractionMode.draw
          ? _DrawControlsStrip(viewModel: viewModel)
          : _MoveControlsStrip(viewModel: viewModel),
    );
  }
}

final class _DrawControlsStrip extends StatelessWidget {
  const _DrawControlsStrip({required this.viewModel});

  final CanvasExampleViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _DrawToolStrip(viewModel: viewModel),
        const VerticalDivider(indent: 25, endIndent: 25, width: 20),
        _ColorPalette(
          keyPrefix: 'draw.color',
          colors: viewModel.penColors,
          selected: viewModel.drawColor,
          onSelected: viewModel.setDrawColor,
        ),
      ],
    );
  }
}

final class _DrawToolStrip extends StatelessWidget {
  const _DrawToolStrip({required this.viewModel});

  final CanvasExampleViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
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
      ],
    );
  }
}

final class _MoveControlsStrip extends StatelessWidget {
  const _MoveControlsStrip({required this.viewModel});

  final CanvasExampleViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _SelectionTransformButtons(viewModel: viewModel),
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
      ],
    );
  }
}

final class _SelectionTransformButtons extends StatelessWidget {
  const _SelectionTransformButtons({required this.viewModel});

  final CanvasExampleViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
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
          onTap: viewModel.hasSelection
              ? viewModel.flipSelectionVertical
              : null,
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
      ],
    );
  }
}

// The mode toggle is a compact Material control. Splitting the shell from the
// two buttons would only obscure the mode-switching affordance.
// ignore: coupling-between-object-classes
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

// This leaf widget owns one selectable icon button state, so its Material
// styling types are clearer inline than behind extra wrappers.
// ignore: coupling-between-object-classes
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

// The menu anchor must compose Material menu style, trigger state, and icon
// state together for the popup entry point to remain easy to audit.
// ignore: coupling-between-object-classes
final class _GridMenu extends StatelessWidget {
  const _GridMenu({required this.viewModel});

  final CanvasExampleViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

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
        SizedBox(width: 340, child: _GridMenuBody(viewModel: viewModel)),
      ],
    );
  }
}

// The body keeps the three grid menu sections in their visual order. Another
// container layer would not reduce behavioral coupling.
// ignore: coupling-between-object-classes
final class _GridMenuBody extends StatelessWidget {
  const _GridMenuBody({required this.viewModel});

  final CanvasExampleViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const _MenuHeader(icon: Icons.grid_on, title: 'Grid Appearance'),
          const SizedBox(height: 24),
          _GridEnabledRow(viewModel: viewModel),
          const SizedBox(height: 24),
          _GridSizeSelector(viewModel: viewModel),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

// Menu headers intentionally own their icon, label, and theme styling as one
// visual unit used by menu bodies.
// ignore: coupling-between-object-classes
final class _MenuHeader extends StatelessWidget {
  const _MenuHeader({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer.withValues(alpha: 0.4),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 18, color: colorScheme.primary),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            color: colorScheme.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

// The grid switch row keeps label copy and the boundary callback together so
// the enabled-state control stays readable.
// ignore: coupling-between-object-classes
final class _GridEnabledRow extends StatelessWidget {
  const _GridEnabledRow({required this.viewModel});

  final CanvasExampleViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Row(
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
    );
  }
}

// Segmented grid-size selection needs Material segments and theme colors in one
// place to keep the selected-value contract obvious.
// ignore: coupling-between-object-classes
final class _GridSizeSelector extends StatelessWidget {
  const _GridSizeSelector({required this.viewModel});

  final CanvasExampleViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final gridSizes = viewModel.gridSizes.isEmpty
        ? [viewModel.grid.cellSize]
        : viewModel.gridSizes;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _GridSizeLabel(colorScheme: colorScheme),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<double>(
            key: const ValueKey('grid.size.menu'),
            showSelectedIcon: false,
            segments: _gridSizeSegments(gridSizes),
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
      ],
    );
  }

  List<ButtonSegment<double>> _gridSizeSegments(List<double> gridSizes) {
    return gridSizes.map((size) {
      return ButtonSegment<double>(
        value: size,
        label: Text(
          size.toInt().toString(),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      );
    }).toList();
  }
}

final class _GridSizeLabel extends StatelessWidget {
  const _GridSizeLabel({required this.colorScheme});

  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Text(
      'Cell Size',
      style: Theme.of(context).textTheme.labelMedium?.copyWith(
        color: colorScheme.onSurfaceVariant,
        fontWeight: FontWeight.bold,
        letterSpacing: 0.5,
      ),
    );
  }
}

// The system menu entry point composes only the Material anchor and trigger.
// moving style pieces out would hide the popup boundary.
// ignore: coupling-between-object-classes
final class _SystemMenu extends StatelessWidget {
  const _SystemMenu({required this.viewModel});

  final CanvasExampleViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

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
          child: _SystemMenuBody(viewModel: viewModel, dialogContext: context),
        ),
      ],
    );
  }
}

final class _SystemMenuBody extends StatelessWidget {
  const _SystemMenuBody({required this.viewModel, required this.dialogContext});

  final CanvasExampleViewModel viewModel;
  final BuildContext dialogContext;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _BackgroundColorSection(viewModel: viewModel),
        const Divider(indent: 16, endIndent: 16),
        _JsonMenuActions(viewModel: viewModel, dialogContext: dialogContext),
        const Divider(indent: 16, endIndent: 16),
        _ClearCanvasMenuAction(onPressed: viewModel.clearCanvas),
        const SizedBox(height: 8),
      ],
    );
  }
}

// Background colors are a small visual palette. Keeping the scroll row with its
// source list makes the menu behavior easier to verify.
// ignore: coupling-between-object-classes
final class _BackgroundColorSection extends StatelessWidget {
  const _BackgroundColorSection({required this.viewModel});

  final CanvasExampleViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const _BackgroundHeader(),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Row(
            children: viewModel.backgroundColors.map((color) {
              return _BackgroundColorButton(
                color: color,
                isSelected: viewModel.background.color == color,
                onSelected: viewModel.setBackgroundColor,
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

// The background header is a single visual label with themed icon styling. More
// wrappers would add indirection without reducing risk.
// ignore: coupling-between-object-classes
final class _BackgroundHeader extends StatelessWidget {
  const _BackgroundHeader();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: Row(
        children: [
          Icon(Icons.palette_outlined, size: 18, color: colorScheme.primary),
          const SizedBox(width: 12),
          Text(
            'Background',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

// The color swatch owns its selected decoration and tap target together because
// that is the stable UI responsibility.
// ignore: coupling-between-object-classes
final class _BackgroundColorButton extends StatelessWidget {
  const _BackgroundColorButton({
    required this.color,
    required this.isSelected,
    required this.onSelected,
  });

  final Color color;
  final bool isSelected;
  final ValueChanged<Color> onSelected;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        key: ValueKey('background.color.${color.toARGB32()}'),
        onTap: () => onSelected(color),
        child: Container(
          width: 32,
          height: 32,
          decoration: _backgroundDecoration(colorScheme),
          child: isSelected ? _SelectedColorIcon(color: color) : null,
        ),
      ),
    );
  }

  BoxDecoration _backgroundDecoration(ColorScheme colorScheme) {
    return BoxDecoration(
      color: color,
      shape: BoxShape.circle,
      border: Border.all(
        color: isSelected ? colorScheme.primary : Colors.black12,
        width: isSelected ? 2 : 1,
      ),
      boxShadow: isSelected
          ? [
              BoxShadow(
                color: colorScheme.primary.withValues(alpha: 0.3),
                blurRadius: 4,
              ),
            ]
          : null,
    );
  }
}

final class _SelectedColorIcon extends StatelessWidget {
  const _SelectedColorIcon({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Icon(
      Icons.check,
      size: 16,
      color: color.computeLuminance() > 0.5 ? Colors.black : Colors.white,
    );
  }
}

final class _JsonMenuActions extends StatelessWidget {
  const _JsonMenuActions({
    required this.viewModel,
    required this.dialogContext,
  });

  final CanvasExampleViewModel viewModel;
  final BuildContext dialogContext;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        MenuItemButton(
          key: const ValueKey('json.export'),
          leadingIcon: const Icon(Icons.download_outlined, size: 20),
          onPressed: () => showCanvasJsonExportDialog(dialogContext, viewModel),
          child: const Text('Export (JSON)'),
        ),
        MenuItemButton(
          key: const ValueKey('json.import'),
          leadingIcon: const Icon(Icons.upload_outlined, size: 20),
          onPressed: () => showCanvasJsonImportDialog(dialogContext, viewModel),
          child: const Text('Import (JSON)'),
        ),
      ],
    );
  }
}

final class _ClearCanvasMenuAction extends StatelessWidget {
  const _ClearCanvasMenuAction({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return MenuItemButton(
      key: const ValueKey('canvas.clear'),
      leadingIcon: Icon(
        Icons.delete_sweep_outlined,
        color: colorScheme.error,
        size: 20,
      ),
      onPressed: onPressed,
      child: Text(
        'Clear Canvas',
        style: TextStyle(color: colorScheme.error, fontWeight: FontWeight.w600),
      ),
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
