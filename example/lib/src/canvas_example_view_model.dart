import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';

import 'canvas_example_defaults.dart';

// The example view model is the app-owned public-port boundary for controls,
// lifecycle, and state projection; splitting these pass-throughs would scatter
// runtime ownership across widgets instead of making the boundary auditable.
// ignore: coupling-between-object-classes, number-of-methods, response-for-class, weighted-methods-per-class
final class CanvasExampleViewModel extends ChangeNotifier {
  CanvasExampleViewModel({
    CanvasRuntime? runtime,
    VoidCallback? addSampleCommand,
  }) : _addSampleCommand = addSampleCommand,
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

  late final StreamSubscription<CanvasActionCommitted> _actionsSubscription;
  late final StreamSubscription<CanvasContextActionRequested>
  _contextRequestSubscription;

  bool _disposed = false;
  CanvasActionCommitted? _lastCommittedAction;
  CanvasContextActionRequested? _lastContextRequest;
  String? _lastExportedJson;

  CanvasRuntime get runtime => _runtime;
  CanvasDocument get document => _runtime.readDocument();
  CanvasRuntimeState get runtimeState => _runtime.state.value;
  CanvasInteractionMode get mode => _runtime.tools.mode;
  CanvasDrawTool get drawTool => _runtime.tools.drawStyle.tool;
  CanvasDrawStyle get drawStyle => _runtime.tools.drawStyle;
  Color get drawColor => _runtime.tools.drawStyle.color;
  CanvasPointerPolicy get pointerPolicy => _runtime.tools.pointerPolicy;
  CanvasCamera get camera => _runtime.camera.camera;
  Offset get cameraOffset => _runtime.camera.offset;
  CanvasBackground get background => document.background;
  CanvasGrid get grid => document.background.grid;
  CanvasPalette get palette => document.palette;
  List<Color> get penColors => palette.penColors;
  List<Color> get backgroundColors => palette.backgroundColors;
  List<double> get gridSizes => palette.gridSizes;
  CanvasPreviewState get preview => _runtime.preview;
  Set<CanvasElementId> get selectedElementIds =>
      _runtime.selection.selectedElementIds;
  bool get hasSelection => selectedElementIds.isNotEmpty;
  CanvasActionCommitted? get lastCommittedAction => _lastCommittedAction;
  CanvasContextActionRequested? get lastContextRequest => _lastContextRequest;
  String? get lastExportedJson => _lastExportedJson;

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

  void setDrawColor(Color color) => _runtime.tools.setDrawColor(color);

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

  void panCameraBy(Offset delta) {
    _runtime.camera.panBy(delta);
  }

  void resetCamera() {
    _runtime.camera.setOffset(Offset.zero);
  }

  void setBackgroundColor(Color color) {
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

  void setGridColor(Color color) {
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
    _addSampleCommand?.call();
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
