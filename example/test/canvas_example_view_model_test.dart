import 'dart:io';
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
  _registerTextStyleCommandTests();
  _registerInlineTextEditContextProjectionTest();
  _registerInlineTextEditStructuralGuardTest();
  _registerJsonExportImportTest();
  _registerJsonImportFailureTest();
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
    expect(viewModel.pointerPolicy.tapSlop, 1);
    expect(viewModel.pointerPolicy.dragStartSlop, 1.0);
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
  test(
    'selection rotation directions mutate the public document distinctly',
    () {
      final viewModel = CanvasExampleViewModel();
      addTearDown(viewModel.dispose);
      final clockwiseId = _addRect(viewModel.runtime, 'rotate-cw-target');
      final counterClockwiseId = _addRect(
        viewModel.runtime,
        'rotate-ccw-target',
      );

      final beforeClockwise = _findElement(
        viewModel.document,
        clockwiseId,
      ).transform;
      viewModel.setSelection([clockwiseId]);
      viewModel.rotateSelectionClockwise();
      final clockwiseTransform = _findElement(
        viewModel.document,
        clockwiseId,
      ).transform;
      expect(clockwiseTransform, isNot(beforeClockwise));

      final beforeCounterClockwise = _findElement(
        viewModel.document,
        counterClockwiseId,
      ).transform;
      viewModel.setSelection([counterClockwiseId]);
      viewModel.rotateSelectionCounterClockwise();
      final counterClockwiseTransform = _findElement(
        viewModel.document,
        counterClockwiseId,
      ).transform;
      expect(counterClockwiseTransform, isNot(beforeCounterClockwise));
      expect(counterClockwiseTransform, isNot(clockwiseTransform));
    },
  );
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

    final beforeHorizontal = _findElement(
      viewModel.document,
      flipHorizontalId,
    ).transform;
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

void _registerTextStyleCommandTests() {
  test('selected text style commands mutate public document updates', () {
    final viewModel = CanvasExampleViewModel();
    addTearDown(viewModel.dispose);
    final textId = _addText(viewModel.runtime, 'style-text');

    viewModel.setSelection([textId]);
    expect(viewModel.hasSelectedTextElement, isTrue);
    _applyTextStyleCommands(viewModel);
    _expectUpdatedTextStyle(viewModel.document, textId);
  });
}

void _registerInlineTextEditContextProjectionTest() {
  test('text context request stays public and leaves text visible', () async {
    final viewModel = CanvasExampleViewModel();
    addTearDown(viewModel.dispose);
    final textId = _addText(viewModel.runtime, 'edit-text');

    viewModel.runtime.tools.handleDoubleTap(position: const Offset(60, 0));
    await _flushEvents();

    final request = viewModel.lastContextRequest;
    if (request == null) {
      fail('Expected a context request projection.');
    }
    expect(request.target, isA<CanvasContentElementContextActionTarget>());
    final text = _findElement(viewModel.document, textId) as CanvasTextElement;
    expect(text.text, 'hello');
    expect(text.isVisible, isTrue);
    expect(viewModel.runtime.textEditing.activeSession.value, isNull);
  });
}

void _registerInlineTextEditStructuralGuardTest() {
  test(
    'example inline editing uses the public overlay without private hiding',
    () {
      final sourceRoot = _exampleSourceRoot();
      final exampleSources = Directory(sourceRoot)
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart'))
          .map((file) => MapEntry(file.path, file.readAsStringSync()))
          .toList();

      expect(
        File('$sourceRoot/canvas_text_edit_overlay.dart').existsSync(),
        isFalse,
      );
      for (final source in exampleSources) {
        _expectNoForbiddenInlineTextEditSource(source);
      }
    },
  );
}

void _expectNoForbiddenInlineTextEditSource(MapEntry<String, String> source) {
  for (final rule in _forbiddenInlineTextEditSourceRules) {
    expect(
      source.value,
      isNot(contains(rule.fragment)),
      reason: '${source.key} ${rule.reason}',
    );
  }
}

String _exampleSourceRoot() {
  if (Directory('example/lib/src').existsSync()) {
    return 'example/lib/src';
  }

  return 'lib/src';
}

const _forbiddenInlineTextEditSourceRules = [
  _ForbiddenSourceRule(
    'package:iwb_canvas_engine/src',
    'must use the public package barrel.',
  ),
  _ForbiddenSourceRule(
    'CanvasExampleTextEditSession',
    'must not reintroduce an app-owned edit session.',
  ),
  _ForbiddenSourceRule(
    'TextPainter',
    'must not duplicate overlay text height measurement.',
  ),
  _ForbiddenSourceRule(
    'isVisible: const CanvasFieldSet(false)',
    'must not hide text for inline editing.',
  ),
  _ForbiddenSourceRule(
    'isVisible: CanvasFieldSet(false)',
    'must not hide text for inline editing.',
  ),
  _ForbiddenSourceRule(
    'boundsWorld',
    'must not calculate overlay placement from context target bounds.',
  ),
];

final class _ForbiddenSourceRule {
  const _ForbiddenSourceRule(this.fragment, this.reason);

  final String fragment;
  final String reason;
}

void _registerJsonExportImportTest() {
  test(
    'schema v1 JSON export and valid import replace the public document',
    () {
      final viewModel = CanvasExampleViewModel();
      addTearDown(viewModel.dispose);
      final textId = _addText(viewModel.runtime, 'json-text');

      final json = viewModel.exportDocumentJson();

      expect(json, contains('"schemaVersion":1'));
      expect(viewModel.lastExportedJson, json);

      viewModel.clearCanvas();
      expect(viewModel.runtimeState.summary.elementCount, 0);

      expect(viewModel.importDocumentJson(json), isTrue);
      expect(
        (_findElement(viewModel.document, textId) as CanvasTextElement).text,
        'hello',
      );
    },
  );
}

void _registerJsonImportFailureTest() {
  test('invalid and retired-shape JSON leave the document unchanged', () {
    final viewModel = CanvasExampleViewModel();
    addTearDown(viewModel.dispose);
    _addText(viewModel.runtime, 'json-failure-text');
    final beforeInvalid = viewModel.document;

    expect(viewModel.importDocumentJson('{'), isFalse);
    expect(viewModel.document, same(beforeInvalid));
    expect(
      viewModel.jsonImportError,
      'Unable to import schema v1 document JSON.',
    );
    expect(viewModel.jsonImportErrorRevision, 1);

    expect(viewModel.importDocumentJson('{"nodes":[]}'), isFalse);
    expect(viewModel.document, same(beforeInvalid));
    expect(viewModel.jsonImportErrorRevision, 2);
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

CanvasElementId _addText(CanvasRuntime runtime, String id) {
  final elementId = CanvasElementId(id);
  runtime.edits.edit((edit) {
    edit.addElement(
      _textElement(elementId, 'hello'),
      layerId: CanvasLayerId('layer-auto-0'),
    );
  });

  return elementId;
}

CanvasTextElement _textElement(CanvasElementId id, String text) {
  return CanvasTextElement(
    id: id,
    text: text,
    color: const Color(0xFF111827),
    textDirection: TextDirection.ltr,
    transform: CanvasTransform.translation(const Offset(60, 0)),
  );
}

void _applyTextStyleCommands(CanvasExampleViewModel viewModel) {
  expect(viewModel.hasSelectedTextElement, isTrue);
  expect(viewModel.toggleSelectedTextBold(), isTrue);
  expect(viewModel.toggleSelectedTextItalic(), isTrue);
  expect(viewModel.toggleSelectedTextUnderline(), isTrue);
  expect(viewModel.setSelectedTextAlign(TextAlign.center), isTrue);
  expect(viewModel.setSelectedTextFontSize(32), isTrue);
  expect(viewModel.setSelectedTextLineHeight(1.5), isTrue);
  expect(viewModel.setSelectedTextColor(const Color(0xFFE53935)), isTrue);
}

void _expectUpdatedTextStyle(CanvasDocument document, CanvasElementId textId) {
  final text = _findElement(document, textId) as CanvasTextElement;
  expect(text.isBold, isTrue);
  expect(text.isItalic, isTrue);
  expect(text.isUnderline, isTrue);
  expect(text.align, TextAlign.center);
  expect(text.fontSize, 32);
  expect(text.lineHeight, 1.5);
  expect(text.color.toARGB32(), 0xFFE53935);
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
