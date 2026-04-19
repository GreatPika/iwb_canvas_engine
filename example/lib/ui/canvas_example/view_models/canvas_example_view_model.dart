import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';

import '../../../data/services/sample_image_asset_service.dart';

class CanvasExampleViewModel extends ChangeNotifier {
  CanvasExampleViewModel({
    SceneController? controller,
    SampleImageAssetService? sampleImageAssetService,
  }) : _sampleImageAssetService =
           sampleImageAssetService ?? SampleImageAssetService(),
       _controller =
           controller ??
           SceneController(
             initialSnapshot: SceneSnapshot(
               layers: <ContentLayerSnapshot>[
                 ContentLayerSnapshot(id: 'layer-auto-0'),
                 ContentLayerSnapshot(id: 'layer-auto-1'),
               ],
             ),
             clearSelectionOnDrawModeEnter: true,
             pointerSettings: const PointerInputSettings(
               tapSlop: 16,
               doubleTapSlop: 32,
               doubleTapMaxDelayMs: 450,
             ),
           ),
       _ownsController = controller == null {
    _controller.addListener(_handleControllerChanged);
    _editTextSubscription = _controller.editTextRequests.listen(
      _beginInlineTextEdit,
    );
    unawaited(ensureSampleImageLoaded());
  }

  static const double lineHeightMinMultiplier = 0.8;
  static const double lineHeightMaxMultiplier = 3.0;
  static const double defaultLineHeightMultiplier = 1.2;
  static const String sampleCatImageId = 'sample-cat';

  final SampleImageAssetService _sampleImageAssetService;
  final SceneController _controller;
  final bool _ownsController;

  StreamSubscription<EditTextRequested>? _editTextSubscription;
  Future<void>? _sampleImageLoad;
  ui.Image? _sampleCatImage;
  int _sampleSeed = 0;
  int _nodeSeed = 0;
  String? _lastExportedJson;
  NodeId? _editingNodeId;
  bool _disposed = false;

  SceneController get controller => _controller;
  String? get lastExportedJson => _lastExportedJson;
  NodeId? get editingNodeId => _editingNodeId;
  bool get isEditingText => _editingNodeId != null;

  Offset get cameraOffset => _controller.snapshot.camera.offset;
  double get cameraX => cameraOffset.dx;
  CanvasMode get mode => _controller.interaction.mode;
  DrawTool get drawTool => _controller.interaction.drawTool;
  Color get drawColor => _controller.interaction.drawColor;
  bool get isDrawMode => mode == CanvasMode.draw;
  bool get hasSelection => _controller.selectedNodeIds.isNotEmpty;
  ui.Image? Function(String imageId) get imageResolver => resolveSceneImage;
  Offset? get pendingLineStart => _controller.interaction.pendingLineStart;
  Color? get pendingLineColor => _controller.interaction.pendingLineColor;
  double? get pendingLineThickness =>
      _controller.interaction.pendingLineThickness;

  List<Color> get penColors => _controller.snapshot.palette.penColors;
  List<double> get gridSizes => _controller.snapshot.palette.gridSizes;
  List<Color> get backgroundColors =>
      _controller.snapshot.palette.backgroundColors;

  bool get isGridEnabled => _controller.snapshot.background.grid.isEnabled;
  double get gridCellSize => _controller.snapshot.background.grid.cellSize;
  Color get backgroundColor => _controller.snapshot.background.color;

  List<TextNodeSnapshot> get selectedTextNodes {
    final selectedIds = _controller.selectedNodeIds;
    if (selectedIds.isEmpty) {
      return const <TextNodeSnapshot>[];
    }

    final nodes = <TextNodeSnapshot>[];
    for (final layer in _controller.snapshot.layers) {
      for (final node in layer.nodes) {
        if (node is TextNodeSnapshot && selectedIds.contains(node.id)) {
          nodes.add(node);
        }
      }
    }
    return nodes;
  }

  TextNodeSnapshot? get editingTextNode {
    final nodeId = _editingNodeId;
    if (nodeId == null) {
      return null;
    }
    return findTextNode(nodeId);
  }

  Future<void> ensureSampleImageLoaded() {
    final load = _sampleImageLoad;
    if (load != null) {
      return load;
    }

    final nextLoad = _loadSampleImage();
    _sampleImageLoad = nextLoad;
    return nextLoad;
  }

  ui.Image? resolveSceneImage(String imageId) {
    if (imageId == sampleCatImageId) {
      return _sampleCatImage;
    }
    return null;
  }

  String exportSceneJson() {
    final json = encodeSceneToJson(_controller.snapshot);
    _lastExportedJson = json;
    return json;
  }

  String? importSceneJson(String rawJson) {
    if (rawJson.isEmpty) {
      return null;
    }

    try {
      final decoded = decodeSceneFromJson(rawJson);
      _controller.scene.replaceScene(decoded);
      return null;
    } catch (error) {
      return 'Error: $error';
    }
  }

  void setMode(
    CanvasMode nextMode, {
    String? activeInlineText,
    bool saveInlineText = true,
  }) {
    if (_controller.interaction.mode == nextMode) {
      return;
    }
    if (nextMode != CanvasMode.move && _editingNodeId != null) {
      finishInlineTextEdit(save: saveInlineText, text: activeInlineText);
    }
    _controller.interaction.setMode(nextMode);
  }

  void setDrawTool(DrawTool tool) => _controller.interaction.setDrawTool(tool);

  void setDrawColor(Color color) => _controller.interaction.setDrawColor(color);

  void panCameraBy(Offset delta) {
    final nextOffset = _controller.snapshot.camera.offset + delta;
    _controller.scene.setCameraOffset(nextOffset);
  }

  void setBackgroundColor(Color color) =>
      _controller.scene.setBackgroundColor(color);

  void setGridEnabled(bool isEnabled) =>
      _controller.scene.setGridEnabled(isEnabled);

  void setGridSize(double cellSize) =>
      _controller.scene.setGridCellSize(cellSize);

  void rotateSelection({required bool clockwise}) =>
      _controller.selection.rotateSelection(clockwise: clockwise);

  void flipSelectionVertical() => _controller.selection.flipSelectionVertical();

  void flipSelectionHorizontal() =>
      _controller.selection.flipSelectionHorizontal();

  void deleteSelection() => _controller.selection.deleteSelection();

  void clearCanvas() => _controller.scene.clearScene();

  void setSelectedTextColor(Color color) => _updateSelectedTextNodes(
    (node) => TextNodePatch(id: node.id, color: PatchField<Color>.value(color)),
  );

  void setSelectedTextAlign(TextAlign align) => _updateSelectedTextNodes(
    (node) =>
        TextNodePatch(id: node.id, align: PatchField<TextAlign>.value(align)),
  );

  void setSelectedTextFontSize(double fontSize) =>
      _updateSelectedTextNodes((node) {
        return TextNodePatch(
          id: node.id,
          fontSize: PatchField<double>.value(fontSize),
          lineHeight: _lineHeightPatchForFontSizeChange(
            node: node,
            nextFontSize: fontSize,
          ),
        );
      });

  void setSelectedTextLineHeightMultiplier(double multiplier) =>
      _updateSelectedTextNodes(
        (node) => TextNodePatch(
          id: node.id,
          lineHeight: PatchField<double?>.value(multiplier * node.fontSize),
        ),
      );

  void toggleSelectedTextBold() => _updateSelectedTextNodes(
    (node) => TextNodePatch(
      id: node.id,
      isBold: PatchField<bool>.value(!node.isBold),
    ),
  );

  void toggleSelectedTextItalic() => _updateSelectedTextNodes(
    (node) => TextNodePatch(
      id: node.id,
      isItalic: PatchField<bool>.value(!node.isItalic),
    ),
  );

  void toggleSelectedTextUnderline() => _updateSelectedTextNodes(
    (node) => TextNodePatch(
      id: node.id,
      isUnderline: PatchField<bool>.value(!node.isUnderline),
    ),
  );

  double lineHeightMultiplierForNode(TextNodeSnapshot node) {
    final lineHeight = node.lineHeight;
    if (lineHeight == null) {
      return defaultLineHeightMultiplier;
    }

    final ratio = lineHeight / node.fontSize;
    if (!ratio.isFinite || ratio <= 0) {
      return defaultLineHeightMultiplier;
    }
    return ratio;
  }

  void finishInlineTextEdit({required bool save, String? text}) {
    final nodeId = _editingNodeId;
    if (nodeId == null) {
      return;
    }

    _editingNodeId = null;
    final node = findTextNode(nodeId);
    if (node == null) {
      notifyListeners();
      return;
    }

    _controller.scene.patchNode(
      TextNodePatch(
        id: node.id,
        text: save
            ? PatchField<String>.value(text ?? '')
            : const PatchField<String>.absent(),
        common: CommonNodePatch(isVisible: PatchField<bool>.value(true)),
      ),
    );
    notifyListeners();
  }

  void addSampleObjects() {
    final baseX = 100 + (_sampleSeed * 30);
    final baseY = 100 + (_sampleSeed * 20);

    if (_sampleCatImage == null) {
      unawaited(ensureSampleImageLoaded());
    }

    final nodes = <NodeSpec>[
      RectNodeSpec(
        id: 'sample-${_nodeSeed++}',
        size: const Size(140, 90),
        fillColor: Colors.blue.withValues(alpha: 0.2),
        strokeColor: Colors.blue,
        strokeWidth: 2,
        transform: Transform2D.translation(
          Offset(baseX.toDouble(), baseY.toDouble()),
        ),
      ),
      TextNodeSpec(
        id: 'sample-${_nodeSeed++}',
        text: 'New Note',
        fontSize: 20,
        color: Colors.black87,
        textDirection: TextDirection.ltr,
        transform: Transform2D.translation(
          Offset(baseX + 160, baseY.toDouble()),
        ),
      ),
      ImageNodeSpec(
        id: 'sample-${_nodeSeed++}',
        imageId: sampleCatImageId,
        size: const Size(120, 180),
        transform: Transform2D.translation(Offset(baseX + 80, baseY + 170)),
      ),
    ];

    _sampleSeed++;
    for (final node in nodes) {
      _controller.scene.addNode(node);
    }
  }

  TextNodeSnapshot? findTextNode(NodeId id) {
    for (final layer in _controller.snapshot.layers) {
      for (final node in layer.nodes) {
        if (node is TextNodeSnapshot && node.id == id) {
          return node;
        }
      }
    }
    return null;
  }

  @override
  void dispose() {
    _disposed = true;
    _editTextSubscription?.cancel();
    _controller.removeListener(_handleControllerChanged);
    _sampleCatImage?.dispose();
    _sampleCatImage = null;
    if (_ownsController) {
      _controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadSampleImage() async {
    if (_sampleCatImage != null) {
      return;
    }

    try {
      final image = await _sampleImageAssetService.loadSampleCatImage();
      if (_disposed) {
        image.dispose();
        return;
      }

      final previousImage = _sampleCatImage;
      _sampleCatImage = image;
      previousImage?.dispose();
      _controller.scene.notifySceneChanged();
      notifyListeners();
    } catch (error, stackTrace) {
      debugPrint(
        'Failed to load sample image. Tried keys: '
        '"${SampleImageAssetService.sampleCatPackageAssetKey}", '
        '"${SampleImageAssetService.sampleCatLocalAssetKey}". Error: $error',
      );
      debugPrintStack(stackTrace: stackTrace);
    } finally {
      _sampleImageLoad = null;
    }
  }

  void _handleControllerChanged() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  void _beginInlineTextEdit(EditTextRequested request) {
    if (_editingNodeId != null) {
      return;
    }

    final node = findTextNode(request.nodeId);
    if (node == null) {
      return;
    }

    _editingNodeId = node.id;
    _controller.scene.patchNode(
      TextNodePatch(
        id: node.id,
        common: CommonNodePatch(isVisible: PatchField<bool>.value(false)),
      ),
    );
    notifyListeners();
  }

  void _updateSelectedTextNodes(
    TextNodePatch Function(TextNodeSnapshot node) patchBuilder,
  ) {
    final nodes = selectedTextNodes;
    if (nodes.isEmpty) {
      return;
    }

    for (final node in nodes) {
      _controller.scene.patchNode(patchBuilder(node));
    }
  }

  PatchField<double?> _lineHeightPatchForFontSizeChange({
    required TextNodeSnapshot node,
    required double nextFontSize,
  }) {
    final lineHeight = node.lineHeight;
    if (lineHeight == null) {
      return const PatchField<double?>.absent();
    }

    final ratio = lineHeightMultiplierForNode(node);
    return PatchField<double?>.value(ratio * nextFontSize);
  }
}
