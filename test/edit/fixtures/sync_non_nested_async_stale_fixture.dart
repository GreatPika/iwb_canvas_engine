import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';

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
  final runtime = CanvasRuntime(initialDocument: _document());
  final beforeState = runtime.state.value;
  var notifications = 0;
  runtime.state.addListener(() {
    notifications += 1;
  });

  final result = runtime.edits.edit((edit) {
    expect(edit.readDraftDocument(), runtime.readDocument());
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
  final runtime = CanvasRuntime(initialDocument: _document());
  late CanvasEdit captured;

  runtime.edits.edit((edit) {
    captured = edit;
    expect(() => runtime.edits.edit((nested) => null), throwsStateError);
    expect(edit.readDraftDocument(), runtime.readDocument());
  });

  expect(() => captured.readDraftDocument(), throwsStateError);
}

void _expectFutureCallbackRejected() {
  final runtime = CanvasRuntime(initialDocument: _document());
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
}

void _expectExceptionClosesHandle() {
  final runtime = CanvasRuntime(initialDocument: _document());
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
}

void _expectStaleHandleRejected() {
  final runtime = CanvasRuntime(initialDocument: _document());
  late CanvasEdit captured;
  runtime.edits.edit((edit) {
    captured = edit;
  });

  expect(() => captured.readDraftDocument(), throwsStateError);
  expect(() => captured.draftSummary, throwsStateError);
  expect(
    () => captured.ensureLayer(CanvasLayerId('next-layer')),
    throwsStateError,
  );
  expect(() => captured.addElement(_rect('next')), throwsStateError);
  expect(
    () => captured.replaceDraftDocument(CanvasDocument()),
    throwsStateError,
  );
}

void _expectP6PathsRejected() {
  final runtime = CanvasRuntime(initialDocument: _document());
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
    expect(edit.readDraftDocument(), runtime.readDocument());
  });

  expect(runtime.state.value, beforeState);
  expect(runtime.readDocument().resources, hasLength(1));
  expect(runtime.readDocument().backgroundElements, hasLength(1));
  expect(runtime.readDocument().layers, hasLength(1));
  expect(runtime.readDocument().layers.single.elements, hasLength(1));
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
