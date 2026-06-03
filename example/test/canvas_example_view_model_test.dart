import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine_example/src/canvas_example_defaults.dart';
import 'package:iwb_canvas_engine_example/src/canvas_example_view_model.dart';

void main() {
  _registerOwnedRuntimeLifecycleTest();
  _registerInjectedRuntimeLifecycleTest();
  _registerListenerCancellationTest();
  _registerActionProjectionCancellationTest();
  _registerContextProjectionCancellationTest();
  _registerDefaultProjectionTest();
  _registerLastExportPlaceholderTest();
  _registerToolTests();
  _registerSelectionProjectionTests();
  _registerSelectionRotateTest();
  _registerSelectionFlipTests();
  _registerSelectionDeleteTest();
  _registerCameraTests();
  _registerDocumentCommandTests();
}

void _registerOwnedRuntimeLifecycleTest() {
  test('owned runtime is disposed with the view model', () {
    final viewModel = CanvasExampleViewModel();
    final runtime = viewModel.runtime;

    viewModel.dispose();

    expect(() => runtime.camera.panBy(const Offset(1, 1)), throwsStateError);
  });
}

void _registerInjectedRuntimeLifecycleTest() {
  test('injected runtime is not disposed with the view model', () {
    final runtime = createCanvasExampleRuntime();
    addTearDown(runtime.dispose);
    final viewModel = CanvasExampleViewModel(runtime: runtime);

    viewModel.dispose();

    expect(() => runtime.camera.panBy(const Offset(1, 1)), returnsNormally);
  });
}

void _registerListenerCancellationTest() {
  test('runtime listener is cancelled after view model disposal', () {
    final runtime = createCanvasExampleRuntime();
    addTearDown(runtime.dispose);
    final viewModel = CanvasExampleViewModel(runtime: runtime);
    var notifications = 0;
    viewModel.addListener(() => notifications++);

    viewModel.panCameraBy(const Offset(10, 0));
    expect(notifications, 1);

    viewModel.dispose();
    runtime.camera.panBy(const Offset(10, 0));

    expect(notifications, 1);
  });
}

void _registerActionProjectionCancellationTest() {
  test('action projection stops after view model disposal', () async {
    final runtime = createCanvasExampleRuntime();
    addTearDown(runtime.dispose);
    final viewModel = CanvasExampleViewModel(runtime: runtime);
    var notifications = 0;
    viewModel.addListener(() => notifications++);

    _addRect(runtime, 'action-before-dispose');
    final clearAction = await _recordActionProjection(viewModel);
    expect(clearAction.type, CanvasActionType.clearContent);
    expect(notifications, greaterThan(0));

    final beforeDisposeNotifications = notifications;
    viewModel.dispose();
    _addRect(runtime, 'action-after-dispose');
    runtime.commands.clearContent();
    await _flushEvents();

    expect(viewModel.lastCommittedAction, same(clearAction));
    expect(notifications, beforeDisposeNotifications);
  });
}

void _registerContextProjectionCancellationTest() {
  test('context request projection stops after view model disposal', () async {
    final runtime = createCanvasExampleRuntime();
    addTearDown(runtime.dispose);
    final viewModel = CanvasExampleViewModel(runtime: runtime);
    var notifications = 0;
    viewModel.addListener(() => notifications++);

    final request = await _recordContextRequestProjection(viewModel);
    expect(request.target, isA<CanvasEmptyCanvasContextActionTarget>());
    expect(notifications, greaterThan(0));

    final beforeDisposeNotifications = notifications;
    viewModel.dispose();
    runtime.tools.handleDoubleTap(position: const Offset(12, 12));
    await _flushEvents();

    expect(viewModel.lastContextRequest, same(request));
    expect(notifications, beforeDisposeNotifications);
  });
}

void _registerDefaultProjectionTest() {
  test('default projection reflects the public runtime state', () {
    final viewModel = CanvasExampleViewModel();
    addTearDown(viewModel.dispose);

    expect(viewModel.runtimeState.summary.layerCount, 2);
    expect(viewModel.runtimeState.summary.elementCount, 0);
    expect(viewModel.mode, CanvasInteractionMode.move);
    expect(viewModel.drawTool, CanvasDrawTool.pencil);
    expect(viewModel.drawColor.toARGB32(), 0xFF000000);
    expect(viewModel.pointerPolicy.tapSlop, 16);
    expect(viewModel.cameraOffset, Offset.zero);
    expect(viewModel.grid.enabled, isFalse);
    expect(viewModel.background.color.toARGB32(), 0xFFFFFFFF);
    expect(viewModel.palette.gridSizes, [10, 20, 40, 80]);
  });
}

void _registerLastExportPlaceholderTest() {
  test('last export placeholder state notifies app listeners', () {
    final viewModel = CanvasExampleViewModel();
    addTearDown(viewModel.dispose);
    var notifications = 0;
    viewModel.addListener(() => notifications++);

    viewModel.rememberLastExportedJson('{"schemaVersion":1}');

    expect(viewModel.lastExportedJson, '{"schemaVersion":1}');
    expect(notifications, 1);
  });
}

void _registerToolTests() {
  test('mode, draw tool, and draw color map to public tool port calls', () {
    final viewModel = CanvasExampleViewModel();
    addTearDown(viewModel.dispose);

    viewModel.setDrawMode();
    viewModel.setDrawTool(CanvasDrawTool.marker);
    viewModel.setDrawColor(const Color(0xFFE53935));

    expect(viewModel.mode, CanvasInteractionMode.draw);
    expect(viewModel.drawTool, CanvasDrawTool.marker);
    expect(viewModel.drawColor.toARGB32(), 0xFFE53935);

    viewModel.setDrawTool(CanvasDrawTool.line);
    expect(viewModel.drawTool, CanvasDrawTool.line);

    viewModel.setDrawTool(CanvasDrawTool.eraser);
    expect(viewModel.drawTool, CanvasDrawTool.eraser);

    viewModel.setMoveMode();
    expect(viewModel.mode, CanvasInteractionMode.move);
  });
}

void _registerSelectionProjectionTests() {
  test('selection commands project through public selection state', () {
    final viewModel = CanvasExampleViewModel();
    addTearDown(viewModel.dispose);
    final firstId = _addRect(viewModel.runtime, 'rect-a');
    final secondId = _addRect(viewModel.runtime, 'rect-b');

    viewModel.setSelection([firstId]);
    expect(viewModel.selectedElementIds, {firstId});
    expect(viewModel.hasSelection, isTrue);

    viewModel.selectAll();
    expect(viewModel.selectedElementIds, {firstId, secondId});

    viewModel.clearSelection();
    expect(viewModel.selectedElementIds, isEmpty);
    expect(viewModel.hasSelection, isFalse);
  });
}

void _registerSelectionRotateTest() {
  test('selection rotation directions mutate the public document distinctly', () {
    final viewModel = CanvasExampleViewModel();
    addTearDown(viewModel.dispose);
    final clockwiseId = _addRect(viewModel.runtime, 'rotate-cw-target');
    final counterClockwiseId = _addRect(viewModel.runtime, 'rotate-ccw-target');

    final beforeClockwise =
        _findElement(viewModel.document, clockwiseId).transform;
    viewModel.setSelection([clockwiseId]);
    viewModel.rotateSelectionClockwise();
    final clockwiseTransform =
        _findElement(viewModel.document, clockwiseId).transform;
    expect(
      clockwiseTransform,
      isNot(beforeClockwise),
    );

    final beforeCounterClockwise =
        _findElement(viewModel.document, counterClockwiseId).transform;
    viewModel.setSelection([counterClockwiseId]);
    viewModel.rotateSelectionCounterClockwise();
    final counterClockwiseTransform =
        _findElement(viewModel.document, counterClockwiseId).transform;
    expect(
      counterClockwiseTransform,
      isNot(beforeCounterClockwise),
    );
    expect(counterClockwiseTransform, isNot(clockwiseTransform));
  });
}

void _registerSelectionFlipTests() {
  test('selection flips mutate the public document', () {
    final viewModel = CanvasExampleViewModel();
    addTearDown(viewModel.dispose);
    final flipVerticalId = _addRect(viewModel.runtime, 'flip-v-target');
    final flipHorizontalId = _addRect(viewModel.runtime, 'flip-h-target');

    final beforeVertical = _findElement(
      viewModel.document,
      flipVerticalId,
    ).transform;
    viewModel.setSelection([flipVerticalId]);
    viewModel.flipSelectionVertical();
    expect(
      _findElement(viewModel.document, flipVerticalId).transform,
      isNot(beforeVertical),
    );

    final beforeHorizontal =
        _findElement(viewModel.document, flipHorizontalId).transform;
    viewModel.setSelection([flipHorizontalId]);
    viewModel.flipSelectionHorizontal();
    expect(
      _findElement(viewModel.document, flipHorizontalId).transform,
      isNot(beforeHorizontal),
    );
  });
}

void _registerSelectionDeleteTest() {
  test('selection deletion mutates the public document', () {
    final viewModel = CanvasExampleViewModel();
    addTearDown(viewModel.dispose);
    final deleteId = _addRect(viewModel.runtime, 'delete-target');

    viewModel.setSelection([deleteId]);
    viewModel.deleteSelection();

    expect(_tryFindElement(viewModel.document, deleteId), isNull);
  });
}

void _registerCameraTests() {
  test('camera commands update public camera projection', () {
    final viewModel = CanvasExampleViewModel();
    addTearDown(viewModel.dispose);

    viewModel.panCameraBy(const Offset(24, -12));
    expect(viewModel.cameraOffset, const Offset(24, -12));

    viewModel.resetCamera();
    expect(viewModel.cameraOffset, Offset.zero);
  });
}

void _registerDocumentCommandTests() {
  test('grid, background, and clear commands mutate public document state', () {
    final viewModel = CanvasExampleViewModel();
    addTearDown(viewModel.dispose);
    _addRect(viewModel.runtime, 'clear-target');

    viewModel.setBackgroundColor(const Color(0xFFFFF9C4));
    viewModel.setGridEnabled(enabled: true);
    viewModel.setGridCellSize(40);
    viewModel.setGridColor(const Color(0x33000000));
    final clearResult = viewModel.clearCanvas();

    expect(viewModel.background.color.toARGB32(), 0xFFFFF9C4);
    expect(viewModel.grid.enabled, isTrue);
    expect(viewModel.grid.cellSize, 40);
    expect(viewModel.grid.color.toARGB32(), 0x33000000);
    expect(clearResult.didClearContent, isTrue);
    expect(viewModel.runtimeState.summary.elementCount, 0);
  });
}

CanvasElementId _addRect(CanvasRuntime runtime, String id) {
  final elementId = CanvasElementId(id);
  runtime.edits.edit((edit) {
    edit.addElement(
      CanvasRectElement(id: elementId, size: const Size(40, 30)),
      layerId: CanvasLayerId('layer-auto-0'),
    );
  });

  return elementId;
}

CanvasElement _findElement(CanvasDocument document, CanvasElementId id) {
  final element = _tryFindElement(document, id);
  if (element == null) {
    throw StateError('Missing element ${id.value}.');
  }

  return element;
}

CanvasElement? _tryFindElement(CanvasDocument document, CanvasElementId id) {
  for (final layer in document.layers) {
    for (final element in layer.elements) {
      if (element.id == id) {
        return element;
      }
    }
  }

  return null;
}

Future<CanvasActionCommitted> _recordActionProjection(
  CanvasExampleViewModel viewModel,
) async {
  viewModel.clearCanvas();
  await _flushEvents();
  final action = viewModel.lastCommittedAction;
  if (action == null) {
    throw StateError('Expected an action projection.');
  }

  return action;
}

Future<CanvasContextActionRequested> _recordContextRequestProjection(
  CanvasExampleViewModel viewModel,
) async {
  viewModel.runtime.tools.handleDoubleTap(position: const Offset(200, 200));
  await _flushEvents();
  final request = viewModel.lastContextRequest;
  if (request == null) {
    throw StateError('Expected a context request projection.');
  }

  return request;
}

Future<void> _flushEvents() => Future<void>.delayed(Duration.zero);
