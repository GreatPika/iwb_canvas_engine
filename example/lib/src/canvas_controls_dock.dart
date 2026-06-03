import 'package:flutter/material.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';

import 'canvas_example_view_model.dart';

// Camera label composition is clearer inline than split into tiny text/icon
// wrappers solely to lower Flutter widget coupling.
// ignore: coupling-between-object-classes
final class CanvasCameraIndicator extends StatelessWidget {
  const CanvasCameraIndicator({required this.cameraOffset, super.key});

  final Offset cameraOffset;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: _panelDecoration,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.videocam_outlined, size: 18),
            const SizedBox(width: 8),
            Text(
              'X ${cameraOffset.dx.toStringAsFixed(0)}  '
              'Y ${cameraOffset.dy.toStringAsFixed(0)}',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

final class CanvasCameraPanControls extends StatelessWidget {
  const CanvasCameraPanControls({
    required this.onPan,
    required this.onReset,
    super.key,
  });

  final ValueChanged<Offset> onPan;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: _panelDecoration,
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _panButton('left', Icons.arrow_back, const Offset(-50, 0)),
            _panButton('right', Icons.arrow_forward, const Offset(50, 0)),
            _panButton('up', Icons.arrow_upward, const Offset(0, -50)),
            _panButton('down', Icons.arrow_downward, const Offset(0, 50)),
            _IconCommandButton(
              key: const ValueKey('camera.reset'),
              icon: Icons.center_focus_strong,
              tooltip: 'Reset camera',
              onPressed: onReset,
            ),
          ],
        ),
      ),
    );
  }

  Widget _panButton(String direction, IconData icon, Offset delta) {
    return _IconCommandButton(
      key: ValueKey('camera.pan.$direction'),
      icon: icon,
      tooltip: 'Pan $direction',
      onPressed: () => onPan(delta),
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
  // The move dock lists selection commands in their visual order; splitting
  // that row further would hide the command sequence the user scans.
  // ignore: source-lines-of-code
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: _dockDecoration,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            _ModeButtons(viewModel: viewModel),
            const VerticalDivider(width: 20),
            Expanded(child: _ModeSpecificControls(viewModel: viewModel)),
            const VerticalDivider(width: 20),
            _DocumentControls(viewModel: viewModel),
          ],
        ),
      ),
    );
  }
}

final class _ModeButtons extends StatelessWidget {
  const _ModeButtons({required this.viewModel});

  final CanvasExampleViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _ToggleCommandButton(
          key: const ValueKey('mode.move'),
          icon: Icons.pan_tool_alt,
          tooltip: 'Move mode',
          selected: viewModel.mode == CanvasInteractionMode.move,
          onPressed: () =>
              viewModel.setInteractionMode(CanvasInteractionMode.move),
        ),
        _ToggleCommandButton(
          key: const ValueKey('mode.draw'),
          icon: Icons.edit,
          tooltip: 'Draw mode',
          selected: viewModel.mode == CanvasInteractionMode.draw,
          onPressed: () =>
              viewModel.setInteractionMode(CanvasInteractionMode.draw),
        ),
      ],
    );
  }
}

final class _ModeSpecificControls extends StatelessWidget {
  const _ModeSpecificControls({required this.viewModel});

  final CanvasExampleViewModel viewModel;

  @override
  // Selection commands are kept as one visual row so their user-facing order is
  // visible at the dock boundary.
  // ignore: source-lines-of-code
  Widget build(BuildContext context) {
    if (viewModel.mode == CanvasInteractionMode.draw) {
      return _DrawControls(viewModel: viewModel);
    }

    return _MoveControls(viewModel: viewModel);
  }
}

// Draw controls keep tool buttons and palette together because their selected
// state is one public draw-style projection.
// ignore: coupling-between-object-classes
final class _DrawControls extends StatelessWidget {
  const _DrawControls({required this.viewModel});

  final CanvasExampleViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _DrawToolButton(
            key: const ValueKey('tool.pencil'),
            icon: Icons.brush,
            tool: CanvasDrawTool.pencil,
            viewModel: viewModel,
          ),
          _DrawToolButton(
            key: const ValueKey('tool.marker'),
            icon: Icons.border_color,
            tool: CanvasDrawTool.marker,
            viewModel: viewModel,
          ),
          _DrawToolButton(
            key: const ValueKey('tool.line'),
            icon: Icons.show_chart,
            tool: CanvasDrawTool.line,
            viewModel: viewModel,
          ),
          _DrawToolButton(
            key: const ValueKey('tool.eraser'),
            icon: Icons.auto_fix_normal,
            tool: CanvasDrawTool.eraser,
            viewModel: viewModel,
          ),
          const SizedBox(width: 8),
          for (final color in viewModel.penColors)
            _ColorSwatchButton(
              key: ValueKey('draw.color.${color.toARGB32()}'),
              color: color,
              selected: viewModel.drawColor == color,
              onPressed: () => viewModel.setDrawColor(color),
            ),
        ],
      ),
    );
  }
}

final class _MoveControls extends StatelessWidget {
  const _MoveControls({required this.viewModel});

  final CanvasExampleViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _selectionButton(
            key: 'selection.rotate.ccw',
            icon: Icons.rotate_left,
            tooltip: 'Rotate left',
            action: viewModel.rotateSelectionCounterClockwise,
          ),
          _selectionButton(
            key: 'selection.rotate.cw',
            icon: Icons.rotate_right,
            tooltip: 'Rotate right',
            action: viewModel.rotateSelectionClockwise,
          ),
          _selectionButton(
            key: 'selection.flip.vertical',
            icon: Icons.flip,
            tooltip: 'Flip vertical',
            quarterTurns: 1,
            action: viewModel.flipSelectionVertical,
          ),
          _selectionButton(
            key: 'selection.flip.horizontal',
            icon: Icons.flip,
            tooltip: 'Flip horizontal',
            action: viewModel.flipSelectionHorizontal,
          ),
          _selectionButton(
            key: 'selection.delete',
            icon: Icons.delete_outline,
            tooltip: 'Delete selection',
            action: viewModel.deleteSelection,
          ),
          _TextStyleControls(viewModel: viewModel),
          _addSampleButton(),
        ],
      ),
    );
  }

  VoidCallback? _selectionAction(VoidCallback action) {
    return viewModel.hasSelection ? action : null;
  }

  Widget _addSampleButton() {
    return _IconCommandButton(
      key: const ValueKey('sample.add'),
      icon: Icons.add_box_outlined,
      tooltip: 'Add sample',
      onPressed: viewModel.requestAddSample,
    );
  }

  // Button identity, display, and callback stay explicit because tests and
  // visual command order depend on the same local declaration.
  // ignore: number-of-parameters
  Widget _selectionButton({
    required String key,
    required IconData icon,
    required String tooltip,
    required VoidCallback action,
    int quarterTurns = 0,
  }) {
    return _IconCommandButton(
      key: ValueKey(key),
      icon: icon,
      tooltip: tooltip,
      quarterTurns: quarterTurns,
      onPressed: _selectionAction(action),
    );
  }
}

// Text controls are a separate move-mode group because they are shown only for
// a selected public text element and mutate text fields, not selection state.
// ignore: coupling-between-object-classes
final class _TextStyleControls extends StatelessWidget {
  const _TextStyleControls({required this.viewModel});

  final CanvasExampleViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final text = viewModel.selectedTextElement;
    if (text == null) {
      return const SizedBox.shrink();
    }

    return Row(
      children: [
        const SizedBox(width: 8),
        _ToggleCommandButton(
          key: const ValueKey('text.bold'),
          icon: Icons.format_bold,
          tooltip: 'Bold',
          selected: text.isBold,
          onPressed: viewModel.toggleSelectedTextBold,
        ),
        _ToggleCommandButton(
          key: const ValueKey('text.italic'),
          icon: Icons.format_italic,
          tooltip: 'Italic',
          selected: text.isItalic,
          onPressed: viewModel.toggleSelectedTextItalic,
        ),
        _ToggleCommandButton(
          key: const ValueKey('text.underline'),
          icon: Icons.format_underline,
          tooltip: 'Underline',
          selected: text.isUnderline,
          onPressed: viewModel.toggleSelectedTextUnderline,
        ),
        _textAlignMenu(),
        _textFontSizeMenu(),
        _textLineHeightMenu(),
        _textColorMenu(),
      ],
    );
  }

  Widget _textAlignMenu() {
    return PopupMenuButton<TextAlign>(
      key: const ValueKey('text.align.menu'),
      icon: const Icon(Icons.format_align_left),
      tooltip: 'Text alignment',
      onSelected: viewModel.setSelectedTextAlign,
      itemBuilder: (context) => const [
        PopupMenuItem(
          value: TextAlign.left,
          child: Icon(Icons.format_align_left),
        ),
        PopupMenuItem(
          value: TextAlign.center,
          child: Icon(Icons.format_align_center),
        ),
        PopupMenuItem(
          value: TextAlign.right,
          child: Icon(Icons.format_align_right),
        ),
      ],
    );
  }

  Widget _textFontSizeMenu() {
    return PopupMenuButton<double>(
      key: const ValueKey('text.font.size.menu'),
      icon: const Icon(Icons.format_size),
      tooltip: 'Font size',
      onSelected: viewModel.setSelectedTextFontSize,
      itemBuilder: (context) => const [
        PopupMenuItem(value: 16, child: Text('16')),
        PopupMenuItem(value: 20, child: Text('20')),
        PopupMenuItem(value: 24, child: Text('24')),
        PopupMenuItem(value: 32, child: Text('32')),
      ],
    );
  }

  Widget _textLineHeightMenu() {
    return PopupMenuButton<double>(
      key: const ValueKey('text.line.height.menu'),
      icon: const Icon(Icons.format_line_spacing),
      tooltip: 'Line height',
      onSelected: viewModel.setSelectedTextLineHeight,
      itemBuilder: (context) => const [
        PopupMenuItem(value: 1, child: Text('1.0')),
        PopupMenuItem(value: 1.2, child: Text('1.2')),
        PopupMenuItem(value: 1.5, child: Text('1.5')),
        PopupMenuItem(value: 2, child: Text('2.0')),
      ],
    );
  }

  Widget _textColorMenu() {
    return PopupMenuButton<Color>(
      key: const ValueKey('text.color.menu'),
      icon: const Icon(Icons.format_color_text),
      tooltip: 'Text color',
      onSelected: viewModel.setSelectedTextColor,
      itemBuilder: (context) => [
        for (final color in viewModel.penColors)
          PopupMenuItem(
            value: color,
            child: _ColorMenuItem(color: color),
          ),
      ],
    );
  }
}

// Document controls are grouped because grid/background/clear are the global
// document commands users scan together in the dock.
// ignore: coupling-between-object-classes
final class _DocumentControls extends StatelessWidget {
  const _DocumentControls({required this.viewModel});

  final CanvasExampleViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _gridToggle(),
        _gridSizeMenu(),
        _backgroundColorMenu(),
        _IconCommandButton(
          key: const ValueKey('json.export'),
          icon: Icons.upload_file,
          tooltip: 'Export JSON',
          onPressed: () {},
        ),
        _IconCommandButton(
          key: const ValueKey('json.import'),
          icon: Icons.download,
          tooltip: 'Import JSON',
          onPressed: () {},
        ),
        _IconCommandButton(
          key: const ValueKey('canvas.clear'),
          icon: Icons.layers_clear,
          tooltip: 'Clear canvas',
          onPressed: viewModel.clearCanvas,
        ),
      ],
    );
  }

  Widget _gridToggle() {
    return _IconCommandButton(
      key: const ValueKey('grid.toggle'),
      icon: viewModel.grid.enabled ? Icons.grid_on : Icons.grid_off,
      tooltip: 'Toggle grid',
      onPressed: () =>
          viewModel.setGridEnabled(enabled: !viewModel.grid.enabled),
    );
  }

  Widget _gridSizeMenu() {
    return PopupMenuButton<double>(
      key: const ValueKey('grid.size.menu'),
      icon: const Icon(Icons.apps),
      tooltip: 'Grid size',
      onSelected: viewModel.setGridCellSize,
      itemBuilder: (context) => [
        for (final size in viewModel.gridSizes)
          PopupMenuItem(value: size, child: Text(size.toStringAsFixed(0))),
      ],
    );
  }

  Widget _backgroundColorMenu() {
    return PopupMenuButton<Color>(
      key: const ValueKey('background.color.menu'),
      icon: const Icon(Icons.format_color_fill),
      tooltip: 'Background color',
      onSelected: viewModel.setBackgroundColor,
      itemBuilder: (context) => [
        for (final color in viewModel.backgroundColors)
          PopupMenuItem(
            value: color,
            child: _ColorMenuItem(color: color),
          ),
      ],
    );
  }
}

final class _DrawToolButton extends StatelessWidget {
  const _DrawToolButton({
    required this.icon,
    required this.tool,
    required this.viewModel,
    super.key,
  });

  final IconData icon;
  final CanvasDrawTool tool;
  final CanvasExampleViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return _ToggleCommandButton(
      icon: icon,
      tooltip: tool.name,
      selected: viewModel.drawTool == tool,
      onPressed: () => viewModel.setDrawTool(tool),
    );
  }
}

final class _ToggleCommandButton extends StatelessWidget {
  const _ToggleCommandButton({
    required this.icon,
    required this.tooltip,
    required this.selected,
    required this.onPressed,
    super.key,
  });

  final IconData icon;
  final String tooltip;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton.filledTonal(
      isSelected: selected,
      icon: Icon(icon),
      tooltip: tooltip,
      onPressed: onPressed,
    );
  }
}

final class _IconCommandButton extends StatelessWidget {
  const _IconCommandButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.quarterTurns = 0,
    super.key,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final int quarterTurns;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: RotatedBox(quarterTurns: quarterTurns, child: Icon(icon)),
      tooltip: tooltip,
      onPressed: onPressed,
    );
  }
}

final class _ColorSwatchButton extends StatelessWidget {
  const _ColorSwatchButton({
    required this.color,
    required this.selected,
    required this.onPressed,
    super.key,
  });

  final Color color;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: DecoratedBox(
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? Colors.black : Colors.white,
            width: selected ? 3 : 1,
          ),
        ),
        child: const SizedBox(width: 18, height: 18),
      ),
      tooltip: 'Color ${color.toARGB32().toRadixString(16)}',
      onPressed: onPressed,
    );
  }
}

final class _ColorMenuItem extends StatelessWidget {
  const _ColorMenuItem({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        DecoratedBox(
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          child: const SizedBox(width: 18, height: 18),
        ),
        const SizedBox(width: 8),
        Text('#${color.toARGB32().toRadixString(16).padLeft(8, '0')}'),
      ],
    );
  }
}

final _panelDecoration = BoxDecoration(
  color: Colors.white.withValues(alpha: 0.9),
  borderRadius: BorderRadius.circular(8),
  border: Border.all(color: Colors.black12),
);

final _dockDecoration = BoxDecoration(
  color: Colors.white,
  borderRadius: BorderRadius.circular(8),
  boxShadow: [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.15),
      blurRadius: 18,
      offset: const Offset(0, 4),
    ),
  ],
);
