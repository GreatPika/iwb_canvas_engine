import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';

import 'canvas_example_defaults.dart';
import 'sample_image_asset_service.dart';
import 'sample_image_resolver.dart';

// The example view model is the app-owned public-port boundary for controls,
// lifecycle, and state projection; splitting these pass-throughs would scatter
// runtime ownership across widgets instead of making the boundary auditable.
// ignore: coupling-between-object-classes, number-of-methods, response-for-class, weighted-methods-per-class
final class CanvasExampleViewModel extends ChangeNotifier {
  CanvasExampleViewModel({
    CanvasRuntime? runtime,
    VoidCallback? addSampleCommand,
    SampleImageAssetService? sampleImageAssetService,
  }) : _addSampleCommand = addSampleCommand,
       _sampleImageAssetService =
           sampleImageAssetService ?? SampleImageAssetService(),
       _runtime = runtime ?? createCanvasExampleRuntime(),
       _ownsRuntime = runtime == null {
    _runtime.state.addListener(_handleRuntimeChanged);
    _actionsSubscription = _runtime.actions.listen(_handleActionCommitted);
    _contextRequestSubscription = _runtime.contextActionRequests.listen(
      _handleContextActionRequested,
    );
  }

  final CanvasRuntime _runtime;
  final bool _ownsRuntime;
  final VoidCallback? _addSampleCommand;
  final SampleImageAssetService _sampleImageAssetService;

  late final StreamSubscription<CanvasActionCommitted> _actionsSubscription;
  late final StreamSubscription<CanvasContextActionRequested>
  _contextRequestSubscription;

  bool _disposed = false;
  CanvasActionCommitted? _lastCommittedAction;
  CanvasContextActionRequested? _lastContextRequest;
  String? _lastExportedJson;
  String? _sampleImageError;
  int _sampleImageErrorRevision = 0;
  Future<void>? _sampleImageLoad;
  ui.Image? _sampleCatImage;
  int _sampleSeed = 0;
  int _sampleElementSeed = 0;

  CanvasRuntime get runtime => _runtime;
  CanvasDocument get document => _runtime.readDocument();
  CanvasRuntimeState get runtimeState => _runtime.state.value;
  CanvasInteractionMode get mode => _runtime.tools.mode;
  CanvasDrawTool get drawTool => _runtime.tools.drawStyle.tool;
  CanvasDrawStyle get drawStyle => _runtime.tools.drawStyle;
  ui.Color get drawColor => _runtime.tools.drawStyle.color;
  CanvasPointerPolicy get pointerPolicy => _runtime.tools.pointerPolicy;
  CanvasCamera get camera => _runtime.camera.camera;
  ui.Offset get cameraOffset => _runtime.camera.offset;
  CanvasBackground get background => document.background;
  CanvasGrid get grid => document.background.grid;
  CanvasPalette get palette => document.palette;
  List<ui.Color> get penColors => palette.penColors;
  List<ui.Color> get backgroundColors => palette.backgroundColors;
  List<double> get gridSizes => palette.gridSizes;
  CanvasPreviewState get preview => _runtime.preview;
  Set<CanvasElementId> get selectedElementIds =>
      _runtime.selection.selectedElementIds;
  bool get hasSelection => selectedElementIds.isNotEmpty;
  CanvasActionCommitted? get lastCommittedAction => _lastCommittedAction;
  CanvasContextActionRequested? get lastContextRequest => _lastContextRequest;
  String? get lastExportedJson => _lastExportedJson;
  String? get sampleImageError => _sampleImageError;
  int get sampleImageErrorRevision => _sampleImageErrorRevision;
  CanvasResourceResolver get resourceResolver {
    return SampleImageResolver(sampleCatImage: _sampleCatImage);
  }

  void rememberLastExportedJson(String json) {
    _lastExportedJson = json;
    _notifyIfActive();
  }

  void setInteractionMode(CanvasInteractionMode mode) {
    _runtime.tools.setMode(mode);
  }

  void setMoveMode() => _runtime.tools.setMode(CanvasInteractionMode.move);

  void setDrawMode() => _runtime.tools.setMode(CanvasInteractionMode.draw);

  void setDrawTool(CanvasDrawTool tool) => _runtime.tools.setDrawTool(tool);

  void setDrawColor(ui.Color color) => _runtime.tools.setDrawColor(color);

  void setSelection(Iterable<CanvasElementId> ids) {
    _runtime.selection.setSelection(ids);
  }

  void clearSelection() {
    _runtime.selection.clearSelection();
  }

  void selectAll({bool onlySelectable = true}) {
    _runtime.selection.selectAll(onlySelectable: onlySelectable);
  }

  void rotateSelectionClockwise() {
    _runtime.selection.rotateSelectionClockwise();
  }

  void rotateSelectionCounterClockwise() {
    _runtime.selection.rotateSelectionCounterClockwise();
  }

  void flipSelectionVertical() {
    _runtime.selection.flipSelectionVertical();
  }

  void flipSelectionHorizontal() {
    _runtime.selection.flipSelectionHorizontal();
  }

  void deleteSelection() {
    _runtime.selection.deleteSelection();
  }

  void panCameraBy(ui.Offset delta) {
    _runtime.camera.panBy(delta);
  }

  void resetCamera() {
    _runtime.camera.setOffset(ui.Offset.zero);
  }

  void setBackgroundColor(ui.Color color) {
    _runtime.edits.edit((edit) => edit.setBackgroundColor(color));
  }

  void setGridEnabled({required bool enabled}) {
    _updateGrid((grid) {
      return CanvasGrid(
        enabled: enabled,
        cellSize: grid.cellSize,
        color: grid.color,
      );
    });
  }

  void setGridCellSize(double cellSize) {
    _updateGrid((grid) {
      return CanvasGrid(
        enabled: grid.enabled,
        cellSize: cellSize,
        color: grid.color,
      );
    });
  }

  void setGridColor(ui.Color color) {
    _updateGrid((grid) {
      return CanvasGrid(
        enabled: grid.enabled,
        cellSize: grid.cellSize,
        color: color,
      );
    });
  }

  CanvasClearResult clearCanvas() {
    return _runtime.commands.clearContent(removeUnusedResources: true);
  }

  void requestAddSample() {
    final command = _addSampleCommand;
    if (command != null) {
      command();

      return;
    }

    unawaited(addSampleObjects());
  }

  Future<void> addSampleObjects() async {
    try {
      await ensureSampleImageLoaded();
    } on Object {
      _sampleImageError = 'Unable to load sample cat image.';
      _sampleImageErrorRevision += 1;
      _notifyIfActive();

      return;
    }
    if (_disposed) {
      return;
    }
    _insertSampleObjects();
    _sampleImageError = null;
    _notifyIfActive();
  }

  Future<void> ensureSampleImageLoaded() {
    if (_sampleCatImage != null) {
      return Future<void>.value();
    }
    final activeLoad = _sampleImageLoad;
    if (activeLoad != null) {
      return activeLoad;
    }

    final load = _loadSampleImage();
    _sampleImageLoad = load;
    return load;
  }

  @override
  void dispose() {
    if (_disposed) {
      return;
    }
    _disposed = true;
    _runtime.state.removeListener(_handleRuntimeChanged);
    unawaited(_actionsSubscription.cancel());
    unawaited(_contextRequestSubscription.cancel());
    _sampleCatImage?.dispose();
    _sampleCatImage = null;
    if (_ownsRuntime) {
      _runtime.dispose();
    }
    super.dispose();
  }

  void _updateGrid(CanvasGrid Function(CanvasGrid grid) update) {
    _runtime.edits.edit((edit) {
      final current = edit.readDraftDocument().background.grid;
      edit.setGrid(update(current));
    });
  }

  Future<void> _loadSampleImage() async {
    try {
      final image = await _sampleImageAssetService.loadSampleCatImage();
      if (_disposed) {
        image.dispose();
        return;
      }
      _sampleCatImage?.dispose();
      _sampleCatImage = image;
    } finally {
      _sampleImageLoad = null;
    }
  }

  void _insertSampleObjects() {
    final baseX = 100.0 + (_sampleSeed * 30);
    final baseY = 100.0 + (_sampleSeed * 20);
    final reservedIds = _existingElementIdValues();
    final rectId = _nextSampleElementId(reservedIds);
    final textId = _nextSampleElementId(reservedIds);
    final imageId = _nextSampleElementId(reservedIds);
    _sampleSeed += 1;

    _runtime.edits.edit((edit) {
      edit.upsertResource(
        CanvasImageResource(
          id: SampleImageResolver.sampleCatResourceId,
          source: CanvasResourceSource.appKey('sample-cat'),
          mimeType: 'image/png',
        ),
      );
      edit.addElement(
        _sampleRectElement(rectId, ui.Offset(baseX, baseY)),
        layerId: CanvasLayerId('layer-auto-0'),
      );
      edit.addElement(
        _sampleTextElement(textId, ui.Offset(baseX + 160, baseY)),
        layerId: CanvasLayerId('layer-auto-0'),
      );
      edit.addElement(
        _sampleImageElement(imageId, ui.Offset(baseX + 80, baseY + 170)),
        layerId: CanvasLayerId('layer-auto-0'),
      );
    });
  }

  CanvasRectElement _sampleRectElement(
    CanvasElementId id,
    ui.Offset translation,
  ) {
    return CanvasRectElement(
      id: id,
      size: const ui.Size(140, 90),
      fillColor: const ui.Color(0xFF2196F3).withValues(alpha: 0.2),
      strokeColor: const ui.Color(0xFF2196F3),
      strokeWidth: 2,
      transform: CanvasTransform.translation(translation),
    );
  }

  CanvasTextElement _sampleTextElement(
    CanvasElementId id,
    ui.Offset translation,
  ) {
    return CanvasTextElement(
      id: id,
      text: 'New Note',
      fontSize: 20,
      color: const ui.Color(0xDD000000),
      textDirection: ui.TextDirection.ltr,
      transform: CanvasTransform.translation(translation),
    );
  }

  CanvasImageElement _sampleImageElement(
    CanvasElementId id,
    ui.Offset translation,
  ) {
    return CanvasImageElement(
      id: id,
      resourceId: SampleImageResolver.sampleCatResourceId,
      size: const ui.Size(120, 180),
      transform: CanvasTransform.translation(translation),
    );
  }

  Set<String> _existingElementIdValues() {
    return {
      for (final layer in document.layers)
        for (final element in layer.elements) element.id.value,
    };
  }

  CanvasElementId _nextSampleElementId(Set<String> reservedIds) {
    while (reservedIds.contains('sample-$_sampleElementSeed')) {
      _sampleElementSeed += 1;
    }
    final value = 'sample-$_sampleElementSeed';
    reservedIds.add(value);
    _sampleElementSeed += 1;

    return CanvasElementId(value);
  }

  void _handleRuntimeChanged() {
    _notifyIfActive();
  }

  void _handleActionCommitted(CanvasActionCommitted action) {
    _lastCommittedAction = action;
    _notifyIfActive();
  }

  void _handleContextActionRequested(CanvasContextActionRequested request) {
    _lastContextRequest = request;
    _notifyIfActive();
  }

  void _notifyIfActive() {
    if (!_disposed) {
      notifyListeners();
    }
  }
}
