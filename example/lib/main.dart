import 'package:flutter/material.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';

void main() {
  runApp(const CanvasExampleApp());
}

class CanvasExampleApp extends StatelessWidget {
  const CanvasExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'IWB Canvas Engine Example',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF1565C0),
      ),
      home: const CanvasExampleScreen(),
    );
  }
}

class CanvasExampleScreen extends StatefulWidget {
  const CanvasExampleScreen({super.key});

  @override
  State<CanvasExampleScreen> createState() => _CanvasExampleScreenState();
}

class _CanvasExampleScreenState extends State<CanvasExampleScreen> {
  static const double _cameraMinX = -400;
  static const double _cameraMaxX = 400;

  late final SceneController _controller;
  int _sampleSeed = 0;
  int _nodeSeed = 0;

  @override
  void initState() {
    super.initState();
    _controller = SceneController(scene: _createScene());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('IWB Canvas Engine Example'),
      ),
      body: SafeArea(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            return Column(
              children: [
                _buildToolbar(context),
                const Divider(height: 1),
                Expanded(child: _buildCanvas()),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildToolbar(BuildContext context) {
    final scene = _controller.scene;
    final grid = scene.background.grid;
    final hasSelection = _controller.selectedNodeIds.isNotEmpty;
    final isDrawMode = _controller.mode == CanvasMode.draw;
    final theme = Theme.of(context);

    final cameraX = _controller.scene.camera.offset.dx;

    return Material(
      elevation: 1,
      color: theme.colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Wrap(
          spacing: 16,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _ToolbarGroup(
              label: 'Mode',
              child: SegmentedButton<CanvasMode>(
                segments: const [
                  ButtonSegment(
                    value: CanvasMode.move,
                    label: Text('Move'),
                    icon: Icon(Icons.open_with),
                  ),
                  ButtonSegment(
                    value: CanvasMode.draw,
                    label: Text('Draw'),
                    icon: Icon(Icons.edit),
                  ),
                ],
                selected: {_controller.mode},
                onSelectionChanged: (value) {
                  if (value.isEmpty) return;
                  _controller.setMode(value.first);
                },
              ),
            ),
            _ToolbarGroup(
              label: 'Tool',
              child: SegmentedButton<DrawTool>(
                segments: const [
                  ButtonSegment(
                    value: DrawTool.pen,
                    label: Text('Pen'),
                    icon: Icon(Icons.brush),
                  ),
                  ButtonSegment(
                    value: DrawTool.highlighter,
                    label: Text('Highlighter'),
                    icon: Icon(Icons.border_color),
                  ),
                  ButtonSegment(
                    value: DrawTool.line,
                    label: Text('Line'),
                    icon: Icon(Icons.show_chart),
                  ),
                  ButtonSegment(
                    value: DrawTool.eraser,
                    label: Text('Eraser'),
                    icon: Icon(Icons.auto_fix_normal),
                  ),
                ],
                selected: {_controller.drawTool},
                onSelectionChanged: isDrawMode
                    ? (value) {
                        if (value.isEmpty) return;
                        _controller.setDrawTool(value.first);
                      }
                    : null,
              ),
            ),
            _ToolbarGroup(
              label: 'Actions',
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Rotate left',
                    onPressed: hasSelection
                        ? () =>
                            _controller.rotateSelection(clockwise: false)
                        : null,
                    icon: const Icon(Icons.rotate_left),
                  ),
                  IconButton(
                    tooltip: 'Rotate right',
                    onPressed: hasSelection
                        ? () => _controller.rotateSelection(clockwise: true)
                        : null,
                    icon: const Icon(Icons.rotate_right),
                  ),
                  IconButton(
                    tooltip: 'Flip vertical',
                    onPressed: hasSelection
                        ? () => _controller.flipSelectionVertical()
                        : null,
                    icon: const Icon(Icons.flip),
                  ),
                  IconButton(
                    tooltip: 'Delete',
                    onPressed:
                        hasSelection ? () => _controller.deleteSelection() : null,
                    icon: const Icon(Icons.delete_outline),
                  ),
                  IconButton(
                    tooltip: 'Clear',
                    onPressed: () => _controller.clearScene(),
                    icon: const Icon(Icons.clear_all),
                  ),
                ],
              ),
            ),
            _ToolbarGroup(
              label: 'Samples',
              child: FilledButton.icon(
                onPressed: _addSampleObjects,
                icon: const Icon(Icons.add_box_outlined),
                label: const Text('Add objects'),
              ),
            ),
            _ToolbarGroup(
              label: 'Pen color',
              child: _ColorPalette(
                colors: scene.palette.penColors,
                selected: _controller.drawColor,
                onSelected: _setDrawColor,
              ),
            ),
            _ToolbarGroup(
              label: 'Background',
              child: _ColorPalette(
                colors: scene.palette.backgroundColors,
                selected: scene.background.color,
                onSelected: _setBackgroundColor,
              ),
            ),
            _ToolbarGroup(
              label: 'Grid',
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Switch(
                        value: grid.isEnabled,
                        onChanged: _setGridEnabled,
                      ),
                      Text(grid.isEnabled ? 'On' : 'Off'),
                    ],
                  ),
                  SegmentedButton<double>(
                    segments: scene.palette.gridSizes
                        .map(
                          (size) => ButtonSegment<double>(
                            value: size,
                            label: Text('${size.toInt()}'),
                          ),
                        )
                        .toList(growable: false),
                    selected: {grid.cellSize},
                    onSelectionChanged: grid.isEnabled
                        ? (value) {
                            if (value.isEmpty) return;
                            _setGridSize(value.first);
                          }
                        : null,
                  ),
                ],
              ),
            ),
            _ToolbarGroup(
              label: 'Camera X',
              child: SizedBox(
                width: 220,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Slider(
                      value: cameraX.clamp(_cameraMinX, _cameraMaxX).toDouble(),
                      min: _cameraMinX,
                      max: _cameraMaxX,
                      divisions: 80,
                      label: cameraX.toStringAsFixed(0),
                      onChanged: _setCameraX,
                    ),
                    Text(
                      'Offset: ${cameraX.toStringAsFixed(0)}',
                      style: theme.textTheme.labelMedium,
                    ),
                  ],
                ),
              ),
            ),
            if (_controller.hasPendingLineStart)
              _ToolbarGroup(
                label: 'Line start',
                child: Chip(
                  avatar: const Icon(Icons.adjust, size: 16),
                  label: const Text('Tap to set end'),
                  backgroundColor: theme.colorScheme.secondaryContainer
                      .withAlpha((0.6 * 255).round()),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCanvas() {
    return Stack(
      children: [
        SceneView(
          controller: _controller,
          imageResolver: (_) => null,
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              painter: _PendingLineMarkerPainter(controller: _controller),
            ),
          ),
        ),
      ],
    );
  }

  Scene _createScene() {
    return Scene(layers: [Layer()]);
  }

  void _addSampleObjects() {
    final scene = _controller.scene;
    final layer = _ensureContentLayer(scene);
    final baseX = 120 + (_sampleSeed * 30);
    final baseY = 120 + (_sampleSeed * 20);

    layer.nodes.addAll([
      RectNode(
        id: _nextSampleId(),
        size: const Size(140, 90),
        fillColor: const Color(0xFFBBDEFB),
        strokeColor: const Color(0xFF1E88E5),
        strokeWidth: 2,
      )..position = Offset(baseX.toDouble(), baseY.toDouble()),
      TextNode(
        id: _nextSampleId(),
        text: 'Hello canvas',
        size: const Size(180, 60),
        fontSize: 24,
        color: const Color(0xFF263238),
        isBold: true,
      )..position = Offset(baseX + 220, baseY.toDouble()),
      PathNode(
        id: _nextSampleId(),
        svgPathData: 'M0 0 H40 V30 H0 Z M12 8 H28 V22 H12 Z',
        fillRule: PathFillRule.evenOdd,
        fillColor: const Color(0xFF81C784),
        strokeColor: const Color(0xFF2E7D32),
        strokeWidth: 2,
      )..position = Offset(baseX + 100, baseY + 160),
      ImageNode(
        id: _nextSampleId(),
        imageId: 'sample-image',
        size: const Size(120, 90),
      )..position = Offset(baseX + 280, baseY + 160),
      LineNode(
        id: _nextSampleId(),
        start: Offset(baseX.toDouble(), baseY + 220),
        end: Offset(baseX + 180, baseY + 260),
        thickness: 4,
        color: const Color(0xFFE53935),
      ),
    ]);

    _sampleSeed += 1;
    _controller.notifySceneChanged();
  }

  Layer _ensureContentLayer(Scene scene) {
    for (var i = scene.layers.length - 1; i >= 0; i--) {
      final layer = scene.layers[i];
      if (!layer.isBackground) return layer;
    }
    final layer = Layer();
    scene.layers.add(layer);
    return layer;
  }

  NodeId _nextSampleId() {
    final id = _nodeSeed++;
    return 'sample-$id';
  }

  void _setDrawColor(Color color) {
    if (_controller.drawColor == color) return;
    _controller.setDrawColor(color);
  }

  void _setBackgroundColor(Color color) {
    _controller.setBackgroundColor(color);
  }

  void _setGridEnabled(bool value) {
    _controller.setGridEnabled(value);
  }

  void _setGridSize(double value) {
    _controller.setGridCellSize(value);
  }

  void _setCameraX(double value) {
    final camera = _controller.scene.camera;
    _controller.setCameraOffset(Offset(value, camera.offset.dy));
  }
}

class _ToolbarGroup extends StatelessWidget {
  const _ToolbarGroup({
    required this.label,
    required this.child,
  });

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.textTheme.labelSmall),
        const SizedBox(height: 4),
        child,
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
      spacing: 6,
      children: colors
          .map(
            (color) => _ColorSwatch(
              color: color,
              isSelected: color == selected,
              onTap: () => onSelected(color),
            ),
          )
          .toList(growable: false),
    );
  }
}

class _ColorSwatch extends StatelessWidget {
  const _ColorSwatch({
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final borderColor = isSelected
        ? Theme.of(context).colorScheme.onSurface
        : Theme.of(context)
            .colorScheme
            .onSurface
            .withAlpha((0.2 * 255).round());

    return InkResponse(
      onTap: onTap,
      radius: 18,
      child: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: borderColor,
            width: isSelected ? 2 : 1,
          ),
        ),
      ),
    );
  }
}

class _PendingLineMarkerPainter extends CustomPainter {
  _PendingLineMarkerPainter({required this.controller})
      : super(repaint: controller);

  final SceneController controller;

  @override
  void paint(Canvas canvas, Size size) {
    final start = controller.pendingLineStart;
    if (start == null) return;

    final viewPosition = toView(start, controller.scene.camera.offset);
    final paint = Paint()
      ..color = controller.drawColor.withAlpha((0.8 * 255).round())
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    canvas.drawCircle(viewPosition, 8, paint);
    canvas.drawLine(
      viewPosition + const Offset(-12, 0),
      viewPosition + const Offset(12, 0),
      paint,
    );
    canvas.drawLine(
      viewPosition + const Offset(0, -12),
      viewPosition + const Offset(0, 12),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _PendingLineMarkerPainter oldDelegate) {
    return oldDelegate.controller != controller;
  }
}
