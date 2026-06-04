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
    _resourceResolver = SampleImageResolver(
      sampleCatImage: () => _sampleCatImage,
    );
    _runtime.state.addListener(_handleRuntimeChanged);
    _actionsSubscription = _runtime.actions.listen(_handleActionCommitted);
    _contextRequestSubscription = _runtime.contextActionRequests.listen(
      _handleContextActionRequested,
    );
  }

  static const double lineHeightMinMultiplier = 0.8;
  static const double lineHeightMaxMultiplier = 3.0;
  static const double defaultLineHeightMultiplier = 1.2;

  final CanvasRuntime _runtime;
  final bool _ownsRuntime;
  final VoidCallback? _addSampleCommand;
  final SampleImageAssetService _sampleImageAssetService;
  late final CanvasResourceResolver _resourceResolver;

  late final StreamSubscription<CanvasActionCommitted> _actionsSubscription;
  late final StreamSubscription<CanvasContextActionRequested>
  _contextRequestSubscription;

  bool _disposed = false;
  CanvasActionCommitted? _lastCommittedAction;
  CanvasContextActionRequested? _lastContextRequest;
  CanvasExampleTextEditSession? _activeTextEdit;
  String? _lastExportedJson;
  String? _jsonImportError;
  int _jsonImportErrorRevision = 0;
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
  CanvasTextElement? get selectedTextElement {
    if (selectedElementIds.length != 1) {
      return null;
    }

    return _findTextElement(selectedElementIds.single);
  }

  bool get hasSelectedTextElement => selectedTextElement != null;
  CanvasActionCommitted? get lastCommittedAction => _lastCommittedAction;
  CanvasContextActionRequested? get lastContextRequest => _lastContextRequest;
  CanvasExampleTextEditSession? get activeTextEdit => _activeTextEdit;
  String? get lastExportedJson => _lastExportedJson;
  String? get jsonImportError => _jsonImportError;
  int get jsonImportErrorRevision => _jsonImportErrorRevision;
  String? get sampleImageError => _sampleImageError;
  int get sampleImageErrorRevision => _sampleImageErrorRevision;
  CanvasResourceResolver get resourceResolver => _resourceResolver;

  void rememberLastExportedJson(String json) {
    _lastExportedJson = json;
    _notifyIfActive();
  }

  String exportDocumentJson() {
    final json = encodeCanvasDocumentToJson(document);
    _lastExportedJson = json;
    _notifyIfActive();

    return json;
  }

  bool importDocumentJson(String json) {
    try {
      final document = decodeCanvasDocumentFromJson(json);
      _runtime.edits.loadDocument(document);
      _lastExportedJson = json;
      _jsonImportError = null;
      _notifyIfActive();

      return true;
    } on Object {
      _jsonImportError = 'Unable to import schema v1 document JSON.';
      _jsonImportErrorRevision += 1;
      _notifyIfActive();

      return false;
    }
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

  bool toggleSelectedTextBold() {
    final text = selectedTextElement;

    return text != null &&
        _updateSelectedText(
          CanvasTextElementUpdate(
            id: text.id,
            isBold: CanvasFieldSet(!text.isBold),
          ),
        );
  }

  bool toggleSelectedTextItalic() {
    final text = selectedTextElement;

    return text != null &&
        _updateSelectedText(
          CanvasTextElementUpdate(
            id: text.id,
            isItalic: CanvasFieldSet(!text.isItalic),
          ),
        );
  }

  bool toggleSelectedTextUnderline() {
    final text = selectedTextElement;

    return text != null &&
        _updateSelectedText(
          CanvasTextElementUpdate(
            id: text.id,
            isUnderline: CanvasFieldSet(!text.isUnderline),
          ),
        );
  }

  bool setSelectedTextAlign(ui.TextAlign align) {
    final text = selectedTextElement;

    return text != null &&
        _updateSelectedText(
          CanvasTextElementUpdate(id: text.id, align: CanvasFieldSet(align)),
        );
  }

  bool setSelectedTextFontSize(double fontSize) {
    final text = selectedTextElement;

    return text != null &&
        _updateSelectedText(
          CanvasTextElementUpdate(
            id: text.id,
            fontSize: CanvasFieldSet(fontSize),
            lineHeight: _lineHeightUpdateForFontSizeChange(text),
          ),
        );
  }

  bool setSelectedTextLineHeight(double lineHeight) {
    final text = selectedTextElement;

    return text != null &&
        _updateSelectedText(
          CanvasTextElementUpdate(
            id: text.id,
            lineHeight: CanvasFieldSet(lineHeight),
          ),
        );
  }

  bool setSelectedTextLineHeightMultiplier(double multiplier) {
    final text = selectedTextElement;

    return text != null &&
        _updateSelectedText(
          CanvasTextElementUpdate(
            id: text.id,
            lineHeight: CanvasFieldSet(multiplier),
          ),
        );
  }

  bool setSelectedTextColor(ui.Color color) {
    final text = selectedTextElement;

    return text != null &&
        _updateSelectedText(
          CanvasTextElementUpdate(id: text.id, color: CanvasFieldSet(color)),
        );
  }

  CanvasClearResult clearCanvas() {
    return _runtime.commands.clearContent(removeUnusedResources: true);
  }

  double lineHeightMultiplierForText(CanvasTextElement text) {
    final lineHeight = text.lineHeight;
    if (lineHeight == null) {
      return defaultLineHeightMultiplier;
    }

    if (!lineHeight.isFinite || lineHeight <= 0) {
      return defaultLineHeightMultiplier;
    }

    return lineHeight;
  }

  bool commitActiveTextEdit(String text) {
    final session = _activeTextEdit;
    if (session == null) {
      return false;
    }
    _activeTextEdit = null;
    final current = _findTextElement(session.elementId);
    if (current == null || current.revision != session.editingRevision) {
      _notifyIfActive();

      return false;
    }
    final didCommit = _updateTextEditElement(
      session: session,
      text: text,
      isVisible: true,
    );
    _notifyIfActive();

    return didCommit;
  }

  void dismissActiveTextEdit() {
    final session = _activeTextEdit;
    if (session == null) {
      return;
    }
    _activeTextEdit = null;
    final current = _findTextElement(session.elementId);
    if (current != null && current.revision == session.editingRevision) {
      _updateTextEditElement(
        session: session,
        text: session.initialText,
        isVisible: true,
      );
    }
    _notifyIfActive();
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
    _activeTextEdit = null;
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

  bool _updateSelectedText(CanvasTextElementUpdate update) {
    var didUpdate = false;
    _runtime.edits.edit((edit) {
      didUpdate = edit.updateElement(update);
    });

    return didUpdate;
  }

  CanvasFieldUpdate<double?> _lineHeightUpdateForFontSizeChange(
    CanvasTextElement text,
  ) {
    final lineHeight = text.lineHeight;
    if (lineHeight == null) {
      return const CanvasFieldUpdate<double?>.absent();
    }

    return CanvasFieldSet(lineHeightMultiplierForText(text));
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

  CanvasTextElement? _findTextElement(CanvasElementId id) {
    for (final layer in document.layers) {
      for (final element in layer.elements) {
        if (element.id == id && element is CanvasTextElement) {
          return element;
        }
      }
    }

    return null;
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
    _activeTextEdit = _beginTextEditSession(request);
    _notifyIfActive();
  }

  CanvasExampleTextEditSession? _beginTextEditSession(
    CanvasContextActionRequested request,
  ) {
    final target = request.target;
    if (target is! CanvasContentElementContextActionTarget) {
      return null;
    }
    final element = target.elementSnapshot;
    if (element is! CanvasTextElement) {
      return null;
    }
    _runtime.edits.edit((edit) {
      edit.updateElement(
        CanvasTextElementUpdate(
          id: element.id,
          isVisible: const CanvasFieldSet(false),
        ),
      );
    });
    final hiddenElement = _findTextElement(element.id);
    if (hiddenElement == null || hiddenElement.isVisible) {
      return null;
    }

    return CanvasExampleTextEditSession(
      requestId: request.requestId,
      elementSnapshot: element,
      boundsWorld: target.boundsWorld,
      editingRevision: hiddenElement.revision,
    );
  }

  bool _updateTextEditElement({
    required CanvasExampleTextEditSession session,
    required String text,
    required bool isVisible,
  }) {
    var didUpdate = false;
    _runtime.edits.edit((edit) {
      didUpdate = edit.updateElement(
        CanvasTextElementUpdate(
          id: session.elementId,
          text: CanvasFieldSet(text),
          isVisible: CanvasFieldSet(isVisible),
        ),
      );
    });

    return didUpdate;
  }

  void _notifyIfActive() {
    if (!_disposed) {
      notifyListeners();
    }
  }
}

final class CanvasExampleTextEditSession {
  const CanvasExampleTextEditSession({
    required this.requestId,
    required this.elementSnapshot,
    required this.boundsWorld,
    required this.editingRevision,
  });

  final CanvasInteractionRequestId requestId;
  final CanvasTextElement elementSnapshot;
  final ui.Rect boundsWorld;
  final int editingRevision;
  CanvasElementId get elementId => elementSnapshot.id;
  String get initialText => elementSnapshot.text;
}
