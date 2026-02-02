import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vector_math/vector_math_64.dart' show Vector3;
import 'package:iwb_canvas_engine/advanced.dart';

void main() {
  runApp(const CanvasExampleApp());
}

class CanvasExampleApp extends StatelessWidget {
  const CanvasExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'IWB Canvas Engine',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF1565C0),
        brightness: Brightness.light,
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
  late final SceneController _controller;
  int _sampleSeed = 0;
  int _nodeSeed = 0;
  String? _lastExportedJson;
  NodeId? _editingNodeId;
  TextEditingController? _textEditController;
  FocusNode? _textEditFocusNode;

  @override
  void initState() {
    super.initState();
    _controller = SceneController(
      scene: Scene(layers: [Layer()]),
      pointerSettings: const PointerInputSettings(
        tapSlop: 16,
        doubleTapSlop: 32,
        doubleTapMaxDelayMs: 450,
      ),
    );
    _controller.editTextRequests.listen(_beginInlineTextEdit);
  }

  @override
  void dispose() {
    _textEditController?.dispose();
    _textEditFocusNode?.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      body: SafeArea(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            return Stack(
              children: [
                // 1. Основной холст
                Positioned.fill(child: _buildCanvas()),

                // 2. Индикатор камеры (сверху слева)
                Positioned(top: 20, left: 20, child: _buildCameraIndicator()),

                // 3. Контекстное меню для текста (появляется над нижней панелью)
                if (_selectedTextNodes().isNotEmpty)
                  Positioned(
                    bottom: 120,
                    left: 20,
                    right: 20,
                    child: _buildTextOptionsPanel(),
                  ),

                // 4. ГЛАВНАЯ НИЖНЯЯ ПАНЕЛЬ (DOCK)
                Positioned(
                  bottom: 20,
                  left: 20,
                  right: 20,
                  child: _buildMainBottomBar(),
                ),

                // 5. Оверлей редактирования текста
                if (_editingNodeId != null)
                  _buildTextEditOverlay() ?? const SizedBox.shrink(),
              ],
            );
          },
        ),
      ),
    );
  }

  // --- UI СЕКЦИИ ---

  Widget _buildCameraIndicator() {
    final cameraX = _controller.scene.camera.offset.dx;
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
            "Camera X: ${cameraX.toStringAsFixed(0)}",
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildMainBottomBar() {
    final isDrawMode = _controller.mode == CanvasMode.draw;
    final hasSelection = _controller.selectedNodeIds.isNotEmpty;

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
          // Режимы работы
          _buildModeToggle(),
          const VerticalDivider(indent: 20, endIndent: 20, width: 24),

          // Инструменты (динамические)
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  if (isDrawMode) ...[
                    _buildDrawToolButton(DrawTool.pen, Icons.brush, "Pen"),
                    _buildDrawToolButton(
                      DrawTool.highlighter,
                      Icons.border_color,
                      "Marker",
                    ),
                    _buildDrawToolButton(
                      DrawTool.line,
                      Icons.show_chart,
                      "Line",
                    ),
                    _buildDrawToolButton(
                      DrawTool.eraser,
                      Icons.auto_fix_normal,
                      "Eraser",
                    ),
                    const VerticalDivider(indent: 25, endIndent: 25, width: 20),
                    _ColorPalette(
                      colors: _controller.scene.palette.penColors,
                      selected: _controller.drawColor,
                      onSelected: _setDrawColor,
                    ),
                  ] else ...[
                    _buildActionButton(
                      Icons.rotate_left,
                      "Rotate L",
                      hasSelection
                          ? () => _controller.rotateSelection(clockwise: false)
                          : null,
                    ),
                    _buildActionButton(
                      Icons.rotate_right,
                      "Rotate R",
                      hasSelection
                          ? () => _controller.rotateSelection(clockwise: true)
                          : null,
                    ),
                    _buildActionButton(
                      Icons.flip,
                      "Flip V",
                      hasSelection
                          ? () => _controller.flipSelectionVertical()
                          : null,
                      quarterTurns: 1,
                    ),
                    _buildActionButton(
                      Icons.flip,
                      "Flip H",
                      hasSelection
                          ? () => _controller.flipSelectionHorizontal()
                          : null,
                    ),
                    _buildActionButton(
                      Icons.delete_outline,
                      "Delete",
                      hasSelection ? () => _controller.deleteSelection() : null,
                      color: Colors.red,
                    ),
                    _buildActionButton(
                      Icons.add_box_outlined,
                      "Add Sample",
                      _addSampleObjects,
                    ),
                  ],
                ],
              ),
            ),
          ),

          const VerticalDivider(indent: 20, endIndent: 20, width: 24),

          // Системные действия
          _buildGridMenu(),
          _buildSystemMenu(),
        ],
      ),
    );
  }

  Widget _buildModeToggle() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          _buildSmallModeBtn(CanvasMode.move, Icons.pan_tool_alt),
          _buildSmallModeBtn(CanvasMode.draw, Icons.edit),
        ],
      ),
    );
  }

  Widget _buildSmallModeBtn(CanvasMode mode, IconData icon) {
    final isSelected = _controller.mode == mode;
    return GestureDetector(
      onTap: () => _controller.setMode(mode),
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

  Widget _buildDrawToolButton(DrawTool tool, IconData icon, String label) {
    final isSelected = _controller.drawTool == tool;
    return IconButton(
      icon: Icon(icon),
      onPressed: () => _controller.setDrawTool(tool),
      color: isSelected ? Colors.blue : Colors.grey[700],
      iconSize: 28,
      tooltip: label,
    );
  }

  Widget _buildActionButton(
    IconData icon,
    String label,
    VoidCallback? onTap, {
    Color? color,
    int quarterTurns = 0,
  }) {
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

  Widget _buildTextOptionsPanel() {
    final nodes = _selectedTextNodes();
    if (nodes.isEmpty) return const SizedBox.shrink();
    final node = nodes.first;

    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildTextStyleToggle(
                Icons.format_bold,
                node.isBold,
                _toggleSelectedTextBold,
              ),
              _buildTextStyleToggle(
                Icons.format_italic,
                node.isItalic,
                _toggleSelectedTextItalic,
              ),
              _buildTextStyleToggle(
                Icons.format_underline,
                node.isUnderline,
                _toggleSelectedTextUnderline,
              ),
              const VerticalDivider(width: 20),
              _buildAlignSelector(node.align),
              const VerticalDivider(width: 20),
              const Text(
                "Size: ",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Slider(
                value: node.fontSize.clamp(10, 72).toDouble(),
                min: 10,
                max: 72,
                divisions: 10,
                onChanged: _setSelectedTextFontSize,
              ),
              const VerticalDivider(width: 20),
              const Text(
                "Line Height: ",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Slider(
                value: (node.lineHeight ?? node.fontSize * 1.2).clamp(
                  node.fontSize * 0.8,
                  node.fontSize * 3.0,
                ),
                min: node.fontSize * 0.8,
                max: node.fontSize * 3.0,
                divisions: 20,
                label: node.lineHeight == null
                    ? 'Auto'
                    : node.lineHeight!.toStringAsFixed(1),
                onChanged: _setSelectedTextLineHeight,
              ),
              const VerticalDivider(width: 20),
              _ColorPalette(
                colors: _controller.scene.palette.penColors,
                selected: node.color,
                onSelected: _setSelectedTextColor,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextStyleToggle(IconData icon, bool active, VoidCallback onTap) {
    return IconButton(
      icon: Icon(icon),
      color: active ? Colors.blue : Colors.grey,
      onPressed: onTap,
    );
  }

  Widget _buildAlignSelector(TextAlign current) {
    return Row(
      children: [TextAlign.left, TextAlign.center, TextAlign.right].map((a) {
        return IconButton(
          icon: Icon(
            a == TextAlign.left
                ? Icons.format_align_left
                : a == TextAlign.center
                ? Icons.format_align_center
                : Icons.format_align_right,
          ),
          color: current == a ? Colors.blue : Colors.grey,
          onPressed: () => _setSelectedTextAlign(a),
        );
      }).toList(),
    );
  }

  // --- ЛОГИКА ДИАЛОГОВ ---

  Widget _buildGridMenu() {
    final grid = _controller.scene.background.grid;
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
            grid.isEnabled ? Icons.grid_4x4 : Icons.grid_off,
            color: grid.isEnabled
                ? colorScheme.primary
                : colorScheme.onSurfaceVariant,
          ),
          onPressed: () =>
              controller.isOpen ? controller.close() : controller.open(),
          tooltip: "Grid Settings",
          iconSize: 28,
        );
      },
      menuChildren: [
        SizedBox(
          width: 300,
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
                      "Grid Appearance",
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
                            "Display Grid",
                            style: theme.textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            "Enable alignment guides",
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: grid.isEnabled,
                      onChanged: (v) {
                        _setGridEnabled(v);
                        setState(() {});
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Text(
                  "Cell Size",
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
                    segments: _controller.scene.palette.gridSizes.map((s) {
                      return ButtonSegment<double>(
                        value: s,
                        label: Text(
                          s.toInt().toString(),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      );
                    }).toList(),
                    selected: {grid.cellSize},
                    onSelectionChanged: (Set<double> newSelection) {
                      _setGridSize(newSelection.first);
                      setState(() {});
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

  Widget _buildSystemMenu() {
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
          tooltip: "System Menu",
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
                      "Background",
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
                  children: _controller.scene.palette.backgroundColors.map((c) {
                    final isSelected = _controller.scene.background.color == c;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: () {
                          _setBackgroundColor(c);
                          setState(() {});
                        },
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: c,
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
                                  color: c.computeLuminance() > 0.5
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
                onPressed: _exportSceneJson,
                child: const Text("Export (JSON)"),
              ),
              MenuItemButton(
                leadingIcon: const Icon(Icons.upload_outlined, size: 20),
                onPressed: _importSceneJson,
                child: const Text("Import (JSON)"),
              ),
              const Divider(indent: 16, endIndent: 16),
              MenuItemButton(
                leadingIcon: Icon(
                  Icons.delete_sweep_outlined,
                  color: colorScheme.error,
                  size: 20,
                ),
                onPressed: () => _controller.clearScene(),
                child: Text(
                  "Clear Canvas",
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

  // --- БАЗОВЫЕ МЕТОДЫ (СОХРАНЕНЫ ИЗ ОРИГИНАЛА) ---

  Widget _buildCanvas() {
    return Stack(
      children: [
        SceneView(
          controller: _controller,
          imageResolver: (_) => null,
          selectionColor: const Color(0xFFFFFF00),
          selectionStrokeWidth: 4,
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

  List<TextNode> _selectedTextNodes() {
    final selectedIds = _controller.selectedNodeIds;
    if (selectedIds.isEmpty) return const <TextNode>[];
    final nodes = <TextNode>[];
    for (final layer in _controller.scene.layers) {
      for (final node in layer.nodes) {
        if (node is TextNode && selectedIds.contains(node.id)) nodes.add(node);
      }
    }
    return nodes;
  }

  void _updateSelectedTextNodes(void Function(TextNode node) update) {
    final nodes = _selectedTextNodes();
    if (nodes.isEmpty) return;
    for (final node in nodes) {
      update(node);
    }
    _controller.notifySceneChanged();
  }

  TextNode? _findTextNode(NodeId id) {
    for (final layer in _controller.scene.layers) {
      for (final node in layer.nodes) {
        if (node is TextNode && node.id == id) return node;
      }
    }
    return null;
  }

  void _beginInlineTextEdit(EditTextRequested request) {
    if (_editingNodeId != null) return;
    final node = _findTextNode(request.nodeId);
    if (node == null) return;
    setState(() {
      _editingNodeId = node.id;
      node.isVisible = false;
      _textEditController = TextEditingController(text: node.text);
      _textEditFocusNode = FocusNode();
    });
    _controller.notifySceneChanged();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _textEditFocusNode?.requestFocus();
    });
  }

  void _finishInlineTextEdit({required bool save}) {
    final nodeId = _editingNodeId;
    if (nodeId == null) return;

    final node = _findTextNode(nodeId);
    if (node != null) {
      if (save) {
        final newText = _textEditController?.text ?? "";
        node.text = newText;

        // Update node size to fit the text precisely
        final textStyle = TextStyle(
          fontSize: node.fontSize,
          fontWeight: node.isBold ? FontWeight.bold : FontWeight.normal,
          fontStyle: node.isItalic ? FontStyle.italic : FontStyle.normal,
          fontFamily: node.fontFamily,
          height: node.lineHeight == null
              ? null
              : node.lineHeight! / node.fontSize,
        );
        final tp = TextPainter(
          text: TextSpan(text: newText, style: textStyle),
          textDirection: TextDirection.ltr,
          textAlign: node.align,
        )..layout();

        // Exact size matches prevent jumping back
        node.size = Size(tp.width, tp.height);
      }
      node.isVisible = true;
      _controller.notifySceneChanged();
    }

    setState(() {
      _editingNodeId = null;
      _textEditController?.dispose();
      _textEditFocusNode?.dispose();
    });
  }

  Widget? _buildTextEditOverlay() {
    final nodeId = _editingNodeId;
    if (nodeId == null || _textEditController == null) return null;
    final node = _findTextNode(nodeId);
    if (node == null) return null;

    final viewPosition = toView(node.position, _controller.scene.camera.offset);
    final alignment = _mapTextAlignToAlignment(node.align);

    return Positioned(
      left: viewPosition.dx,
      top: viewPosition.dy,
      child: Transform(
        transform: Matrix4.rotationZ(
          node.rotationDeg * math.pi / 180,
        ).scaledByVector3(Vector3(node.scaleX, node.scaleY, 1.0)),
        child: FractionalTranslation(
          translation: const Offset(-0.5, -0.5),
          child: SizedBox(
            width: node.size.width,
            height: node.size.height,
            child: OverflowBox(
              maxWidth: 3000,
              maxHeight: 2000,
              alignment: alignment,
              child: TextField(
                controller: _textEditController,
                focusNode: _textEditFocusNode,
                maxLines: null,
                textAlign: node.align,
                scrollPadding: EdgeInsets.zero,
                onTapOutside: (_) => _finishInlineTextEdit(save: true),
                strutStyle: StrutStyle(
                  fontSize: node.fontSize,
                  height: node.lineHeight == null
                      ? null
                      : node.lineHeight! / node.fontSize,
                  forceStrutHeight: true,
                ),
                style: TextStyle(
                  fontSize: node.fontSize,
                  color: node.color,
                  fontWeight: node.isBold ? FontWeight.bold : FontWeight.normal,
                  fontStyle: node.isItalic
                      ? FontStyle.italic
                      : FontStyle.normal,
                  decoration: node.isUnderline
                      ? TextDecoration.underline
                      : null,
                  fontFamily: node.fontFamily,
                  height: node.lineHeight == null
                      ? null
                      : node.lineHeight! / node.fontSize,
                ),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Alignment _mapTextAlignToAlignment(TextAlign align) {
    switch (align) {
      case TextAlign.center:
        return Alignment.center;
      case TextAlign.right:
        return Alignment.centerRight;
      default:
        return Alignment.centerLeft;
    }
  }

  Future<void> _exportSceneJson() async {
    final json = encodeSceneToJson(_controller.scene);
    _lastExportedJson = json;
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Scene JSON'),
        content: SizedBox(
          width: 400,
          child: TextField(
            controller: TextEditingController(text: json),
            maxLines: 8,
            readOnly: true,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: json));
              Navigator.pop(context);
            },
            child: const Text('Copy'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _importSceneJson() async {
    final controller = TextEditingController(text: _lastExportedJson ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Import Scene'),
        content: TextField(controller: controller, maxLines: 8),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Import'),
          ),
        ],
      ),
    );
    if (result != null && result.isNotEmpty) {
      try {
        final decoded = decodeSceneFromJson(result);
        _applyDecodedScene(decoded);
        _controller.notifySceneChanged();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  void _applyDecodedScene(Scene decoded) {
    final scene = _controller.scene;
    scene.layers
      ..clear()
      ..addAll(decoded.layers);
    scene.camera.offset = decoded.camera.offset;
    scene.background.color = decoded.background.color;
    scene.background.grid.isEnabled = decoded.background.grid.isEnabled;
    scene.background.grid.cellSize = decoded.background.grid.cellSize;
  }

  void _addSampleObjects() {
    final layerIndex = 0;
    final baseX = 100 + (_sampleSeed * 30);
    final baseY = 100 + (_sampleSeed * 20);

    final nodes = <SceneNode>[
      RectNode(
        id: 'sample-${_nodeSeed++}',
        size: const Size(140, 90),
        fillColor: Colors.blue.withValues(alpha: 0.2),
        strokeColor: Colors.blue,
        strokeWidth: 2,
      )..position = Offset(baseX.toDouble(), baseY.toDouble()),
    ];

    // Calculate proper size for text node
    final textNode = TextNode(
      id: 'sample-${_nodeSeed++}',
      text: 'New Note',
      size: const Size(100, 30), // temporary
      fontSize: 20,
      color: Colors.black87,
    );

    final textPainter = TextPainter(
      text: TextSpan(
        text: textNode.text,
        style: TextStyle(
          fontSize: textNode.fontSize,
          fontWeight: textNode.isBold ? FontWeight.bold : FontWeight.normal,
          fontStyle: textNode.isItalic ? FontStyle.italic : FontStyle.normal,
          fontFamily: textNode.fontFamily,
          height: textNode.lineHeight == null
              ? null
              : textNode.lineHeight! / textNode.fontSize,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: textNode.align,
    )..layout();

    textNode.size = Size(textPainter.width, textPainter.height);
    textNode.position = Offset(baseX + 160, baseY.toDouble());
    nodes.add(textNode);

    _sampleSeed++;
    for (final node in nodes) {
      _controller.addNode(node, layerIndex: layerIndex);
    }
  }

  // Сеттеры
  void _setDrawColor(Color c) => _controller.setDrawColor(c);
  void _setBackgroundColor(Color c) => _controller.setBackgroundColor(c);
  void _setGridEnabled(bool v) => _controller.setGridEnabled(v);
  void _setGridSize(double s) => _controller.setGridCellSize(s);
  void _setSelectedTextColor(Color c) =>
      _updateSelectedTextNodes((n) => n.color = c);
  void _setSelectedTextAlign(TextAlign a) =>
      _updateSelectedTextNodes((n) => n.align = a);
  void _setSelectedTextFontSize(double v) =>
      _updateSelectedTextNodes((n) => n.fontSize = v);
  void _setSelectedTextLineHeight(double v) =>
      _updateSelectedTextNodes((n) => n.lineHeight = v);
  void _toggleSelectedTextBold() =>
      _updateSelectedTextNodes((n) => n.isBold = !n.isBold);
  void _toggleSelectedTextItalic() =>
      _updateSelectedTextNodes((n) => n.isItalic = !n.isItalic);
  void _toggleSelectedTextUnderline() =>
      _updateSelectedTextNodes((n) => n.isUnderline = !n.isUnderline);
}

// --- ВСПОМОГАТЕЛЬНЫЕ ВИДЖЕТЫ ---

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
      children: colors
          .map(
            (color) => GestureDetector(
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
            ),
          )
          .toList(),
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
    final viewPos = toView(start, controller.scene.camera.offset);
    final paint = Paint()
      ..color = controller.drawColor.withAlpha(200)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(viewPos, 12, paint);
    canvas.drawLine(
      viewPos + const Offset(-15, 0),
      viewPos + const Offset(15, 0),
      paint,
    );
    canvas.drawLine(
      viewPos + const Offset(0, -15),
      viewPos + const Offset(0, 15),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _PendingLineMarkerPainter oldDelegate) =>
      oldDelegate.controller != controller;
}
