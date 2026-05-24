import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine/src/edit/commit_plan.dart';
import 'package:iwb_canvas_engine/src/runtime/runtime_root.dart';

void main() {
  test('successful synchronous edit preserves callback result', () {
    expect(_expectSynchronousResultPreserved, returnsNormally);
  });

  test('disposed runtime rejects edit sessions', () {
    expect(_expectDisposedRuntimeRejected, returnsNormally);
  });

  test('nested edit is rejected without closing the active handle', () {
    expect(_expectNestedEditRejected, returnsNormally);
  });

  test('Future-returning callback is rejected and publishes no state', () {
    expect(_expectFutureCallbackRejected, returnsNormally);
  });

  test('callback exception closes the handle and leaves no effects', () {
    expect(_expectExceptionClosesHandle, returnsNormally);
  });

  test('stale handles reject before mutation or replacement behavior', () {
    expect(_expectStaleHandleRejected, returnsNormally);
  });

  test('P6-owned load and replacement paths reject before side effects', () {
    expect(_expectP6PathsRejected, returnsNormally);
  });
}

void _expectSynchronousResultPreserved() {
  final effectBatches = <List<CommitEffect>>[];
  final runtime = _runtimeRoot(effectBatches);
  final beforeState = runtime.state.value;
  var notifications = 0;
  runtime.state.addListener(() {
    notifications += 1;
  });

  final result = runtime.edits.edit((edit) {
    _expectSameDocumentShape(edit.readDraftDocument(), runtime.readDocument());
    expect(
      edit.draftSummary,
      const CanvasDocumentSummary(
        elementCount: 2,
        layerCount: 1,
        resourceCount: 1,
      ),
    );

    return 'result';
  });

  expect(result, 'result');
  expect(runtime.state.value, beforeState);
  expect(notifications, 0);
  expect(effectBatches, isEmpty);
}

void _expectDisposedRuntimeRejected() {
  final runtime = CanvasRuntime(initialDocument: _document());
  runtime.dispose();

  expect(
    () => runtime.edits.edit((edit) => edit.readDraftDocument()),
    throwsStateError,
  );
}

void _expectNestedEditRejected() {
  final effectBatches = <List<CommitEffect>>[];
  final runtime = _runtimeRoot(effectBatches);
  late CanvasEdit captured;

  runtime.edits.edit((edit) {
    captured = edit;
    expect(() => runtime.edits.edit((nested) => null), throwsStateError);
    _expectSameDocumentShape(edit.readDraftDocument(), runtime.readDocument());
  });

  expect(() => captured.readDraftDocument(), throwsStateError);
  expect(effectBatches, isEmpty);
}

void _expectFutureCallbackRejected() {
  final effectBatches = <List<CommitEffect>>[];
  final runtime = _runtimeRoot(effectBatches);
  final beforeState = runtime.state.value;
  var notifications = 0;
  runtime.state.addListener(() {
    notifications += 1;
  });

  expect(
    () => runtime.edits.edit<Object?>((edit) => Future<void>.value()),
    throwsStateError,
  );

  expect(runtime.state.value, beforeState);
  expect(notifications, 0);
  expect(effectBatches, isEmpty);
}

void _expectExceptionClosesHandle() {
  final effectBatches = <List<CommitEffect>>[];
  final runtime = _runtimeRoot(effectBatches);
  final beforeState = runtime.state.value;
  CanvasEdit? captured;

  expect(
    () => runtime.edits.edit((edit) {
      captured = edit;
      throw StateError('boom');
    }),
    throwsStateError,
  );

  final staleHandle = captured;
  if (staleHandle == null) {
    fail('edit callback did not expose a handle before throwing.');
  }
  expect(runtime.state.value, beforeState);
  expect(() => staleHandle.draftSummary, throwsStateError);
  expect(effectBatches, isEmpty);
}

void _expectStaleHandleRejected() {
  final effectBatches = <List<CommitEffect>>[];
  final runtime = _runtimeRoot(effectBatches);
  final beforeState = runtime.state.value;
  late CanvasEdit captured;
  runtime.edits.edit((edit) {
    captured = edit;
  });

  _expectStaleReadEntriesRejected(captured);
  _expectStaleElementEntriesRejected(captured);
  _expectStaleResourceEntriesRejected(captured);
  _expectStaleDocumentEntriesRejected(captured);
  expect(runtime.state.value, same(beforeState));
  _expectSameDocumentShape(runtime.readDocument(), _document());
  expect(effectBatches, isEmpty);
}

void _expectStaleReadEntriesRejected(CanvasEdit captured) {
  expect(() => captured.readDraftDocument(), throwsStateError);
  expect(() => captured.draftSummary, throwsStateError);
}

void _expectStaleElementEntriesRejected(CanvasEdit captured) {
  expect(
    () => captured.ensureLayer(CanvasLayerId('next-layer')),
    throwsStateError,
  );
  expect(() => captured.addElement(_rect('next')), throwsStateError);
  expect(
    () => captured.addBackgroundElement(_rect('next-background')),
    throwsStateError,
  );
  expect(
    () => captured.updateElement(
      CanvasRectElementUpdate(
        id: CanvasElementId('element-1'),
        fillColor: const CanvasFieldSet(Color(0xFF00FF00)),
      ),
    ),
    throwsStateError,
  );
  expect(
    () => captured.removeElement(CanvasElementId('element-1')),
    throwsStateError,
  );
}

void _expectStaleResourceEntriesRejected(CanvasEdit captured) {
  expect(
    () => captured.upsertResource(
      CanvasImageResource(
        id: CanvasResourceId('resource-2'),
        source: CanvasResourceSource.appKey('resource-2'),
      ),
    ),
    throwsStateError,
  );
  expect(
    () => captured.removeUnusedResource(CanvasResourceId('resource-1')),
    throwsStateError,
  );
}

void _expectStaleDocumentEntriesRejected(CanvasEdit captured) {
  expect(
    () => captured.setBackgroundColor(const Color(0xFF000000)),
    throwsStateError,
  );
  expect(
    () => captured.setGrid(CanvasGrid(enabled: true, cellSize: 8)),
    throwsStateError,
  );
  expect(
    () => captured.setPalette(
      CanvasPalette(
        penColors: const [Color(0xFF000000)],
        backgroundColors: const [],
        gridSizes: const [8],
      ),
    ),
    throwsStateError,
  );
  expect(() => captured.setCameraOffset(const Offset(1, 2)), throwsStateError);
  expect(() => captured.clearContent(), throwsStateError);
  expect(
    () => captured.replaceDraftDocument(CanvasDocument()),
    throwsStateError,
  );
}

void _expectP6PathsRejected() {
  final effectBatches = <List<CommitEffect>>[];
  final runtime = _runtimeRoot(effectBatches);
  final beforeState = runtime.state.value;

  expect(
    () => runtime.edits.loadDocument(CanvasDocument()),
    _throwsP6UnsupportedError(),
  );
  runtime.edits.edit((edit) {
    expect(
      () => edit.replaceDraftDocument(CanvasDocument()),
      _throwsP6UnsupportedError(),
    );
    _expectSameDocumentShape(edit.readDraftDocument(), runtime.readDocument());
  });

  expect(runtime.state.value, beforeState);
  expect(runtime.readDocument().resources, hasLength(1));
  expect(runtime.readDocument().backgroundElements, hasLength(1));
  expect(runtime.readDocument().layers, hasLength(1));
  expect(runtime.readDocument().layers.single.elements, hasLength(1));
  expect(effectBatches, isEmpty);
}

RuntimeRoot _runtimeRoot(List<List<CommitEffect>> effectBatches) {
  return RuntimeRoot(
    initialDocument: _document(),
    config: const CanvasRuntimeConfig(),
    commitEffectObserver: effectBatches.add,
  );
}

Matcher _throwsP6UnsupportedError() {
  return throwsA(
    isA<UnsupportedError>().having(
      (error) => error.message,
      'message',
      contains('P6'),
    ),
  );
}

CanvasDocument _document() {
  return CanvasDocument(
    resources: [
      CanvasImageResource(
        id: CanvasResourceId('resource-1'),
        source: CanvasResourceSource.appKey('resource-1'),
      ),
    ],
    backgroundElements: [_rect('background-1')],
    layers: [
      CanvasLayer(id: CanvasLayerId('layer-1'), elements: [_rect('element-1')]),
    ],
  );
}

CanvasRectElement _rect(String id) {
  return CanvasRectElement(id: CanvasElementId(id), size: const Size(1, 1));
}

void _expectSameDocumentShape(CanvasDocument actual, CanvasDocument expected) {
  expect(actual.resources, hasLength(expected.resources.length));
  expect(
    actual.backgroundElements,
    hasLength(expected.backgroundElements.length),
  );
  expect(actual.layers, hasLength(expected.layers.length));
  for (var index = 0; index < actual.layers.length; index += 1) {
    expect(
      actual.layers[index].elements,
      hasLength(expected.layers[index].elements.length),
    );
  }
}
