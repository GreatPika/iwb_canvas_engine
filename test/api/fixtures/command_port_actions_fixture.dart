// Test bodies are named helpers so DCM metrics stay on each scenario; the
// assertions live in those helpers and DCM does not follow tear-offs.
// ignore_for_file: missing-test-assertion

import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';

import '../../support/runtime_with_document.dart';

void main() {
  test(
    'remove element emits delete action for existing elements',
    _removeElementEmitsDeleteActionForExistingElements,
  );

  test(
    'clear content returns removed ids resources and emits clear action',
    _clearContentReturnsRemovedIdsResourcesAndEmitsClearAction,
  );

  test(
    'clear content resource-only cleanup returns result without action',
    _clearContentResourceOnlyCleanupReturnsResultWithoutAction,
  );

  test(
    'commit text edit returns false for unknown requests',
    _commitTextEditReturnsFalseForUnknownRequests,
  );
}

// The repeated public ids and payload fields are the contract surface under
// test; splitting this assertion block would hide the command no-op/commit pair.
// ignore: halstead-volume
Future<void> _removeElementEmitsDeleteActionForExistingElements() async {
  final runtime = runtimeWithDocument(_document());
  final actions = <CanvasActionCommitted>[];
  final subscription = runtime.actions.listen(actions.add);
  addTearDown(() async {
    await subscription.cancel();
    runtime.dispose();
  });

  expect(
    runtime.commands.removeElement(CanvasElementId('missing'), timestampMs: 2),
    isFalse,
  );
  expect(
    runtime.commands.removeElement(
      CanvasElementId('not-deletable-a'),
      timestampMs: 1,
    ),
    isTrue,
  );
  expect(
    runtime.commands.removeElement(CanvasElementId('rect-a'), timestampMs: 3),
    isTrue,
  );
  await Future<void>.delayed(Duration.zero);

  expect(actions, hasLength(2));
  _expectDeleteAction(
    actions.first,
    CanvasElementId('not-deletable-a'),
    timestampMs: 1,
  );
  _expectDeleteAction(actions.last, CanvasElementId('rect-a'), timestampMs: 3);
}

Future<void>
_clearContentReturnsRemovedIdsResourcesAndEmitsClearAction() async {
  final runtime = runtimeWithDocument(_document());
  final actions = <CanvasActionCommitted>[];
  final subscription = runtime.actions.listen(actions.add);
  addTearDown(() async {
    await subscription.cancel();
    runtime.dispose();
  });

  final result = runtime.commands.clearContent(
    removeUnusedResources: true,
    timestampMs: 4,
  );
  await Future<void>.delayed(Duration.zero);

  _expectClearResult(runtime, result);
  _expectClearAction(actions.single, result);
  final noop = runtime.commands.clearContent(removeUnusedResources: true);
  await Future<void>.delayed(Duration.zero);
  expect(noop.didClearContent, isFalse);
  expect(actions, hasLength(1));
}

Future<void>
_clearContentResourceOnlyCleanupReturnsResultWithoutAction() async {
  final runtime = runtimeWithDocument(_resourceOnlyDocument());
  final actions = <CanvasActionCommitted>[];
  final subscription = runtime.actions.listen(actions.add);
  addTearDown(() async {
    await subscription.cancel();
    runtime.dispose();
  });

  final result = runtime.commands.clearContent(
    removeUnusedResources: true,
    timestampMs: 6,
  );
  await Future<void>.delayed(Duration.zero);

  expect(result.didClearContent, isTrue);
  expect(result.removedElementIds, isEmpty);
  expect(result.removedResourceIds, [CanvasResourceId('unused-resource')]);
  expect(actions, isEmpty);
}

void _expectDeleteAction(
  CanvasActionCommitted action,
  CanvasElementId id, {
  required int timestampMs,
}) {
  expect(action.type, CanvasActionType.deleteElements);
  expect(action.elementIds, [id]);
  expect(action.timestampMs, timestampMs);
  expect((action.payload as CanvasDeleteActionPayload).removedElementIds, [id]);
}

void _expectClearResult(CanvasRuntime runtime, CanvasClearResult result) {
  expect(result.didClearContent, isTrue);
  expect(result.removedElementIds, [
    CanvasElementId('background-a'),
    CanvasElementId('rect-a'),
    CanvasElementId('not-deletable-a'),
    CanvasElementId('image-a'),
  ]);
  expect(result.removedResourceIds, [CanvasResourceId('image-resource')]);
  expect(runtime.readDocument().layers.single.elements, isEmpty);
  expect(runtime.readDocument().resources, isEmpty);
}

void _expectClearAction(
  CanvasActionCommitted action,
  CanvasClearResult result,
) {
  expect(action.type, CanvasActionType.clearContent);
  expect(action.elementIds, result.removedElementIds);
  expect(action.timestampMs, 4);
  final payload = action.payload as CanvasClearActionPayload;
  expect(payload.removedElementIds, result.removedElementIds);
  expect(payload.removedResourceIds, result.removedResourceIds);
}

void _commitTextEditReturnsFalseForUnknownRequests() {
  final runtime = runtimeWithDocument(_document());
  addTearDown(runtime.dispose);

  expect(
    runtime.commands.commitTextEdit(
      CanvasInteractionRequestId('unknown-request'),
      'updated text',
      timestampMs: 5,
    ),
    isFalse,
  );
}

CanvasDocument _document() {
  return CanvasDocument(
    resources: [
      CanvasImageResource(
        id: CanvasResourceId('image-resource'),
        source: CanvasResourceSource.appKey('image-asset'),
      ),
    ],
    backgroundElements: [
      CanvasRectElement(
        id: CanvasElementId('background-a'),
        size: const Size(1, 1),
      ),
    ],
    layers: [
      CanvasLayer(
        id: CanvasLayerId('layer-a'),
        elements: [
          CanvasRectElement(
            id: CanvasElementId('rect-a'),
            size: const Size(2, 2),
          ),
          CanvasRectElement(
            id: CanvasElementId('not-deletable-a'),
            size: const Size(2, 2),
            isDeletable: false,
          ),
          CanvasImageElement(
            id: CanvasElementId('image-a'),
            resourceId: CanvasResourceId('image-resource'),
            size: const Size(2, 2),
          ),
        ],
      ),
    ],
  );
}

CanvasDocument _resourceOnlyDocument() {
  return CanvasDocument(
    resources: [
      CanvasImageResource(
        id: CanvasResourceId('unused-resource'),
        source: CanvasResourceSource.appKey('unused-image-asset'),
      ),
    ],
  );
}
