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
  expect(noop.removedElementIds, isEmpty);
  expect(noop.removedResourceIds, isEmpty);
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

// Result and retained public state are one command outcome, so their exact
// assertions stay together rather than being split only to change metrics.
// ignore: halstead-volume
void _expectClearResult(CanvasRuntime runtime, CanvasClearResult result) {
  expect(result.didClearContent, isTrue);
  expect(result.removedElementIds, [
    CanvasElementId('rect-a'),
    CanvasElementId('not-deletable-a'),
    CanvasElementId('image-a'),
    CanvasElementId('vector-a'),
  ]);
  expect(result.removedResourceIds, [
    CanvasResourceId('content-image-resource'),
    CanvasResourceId('content-vector-resource'),
    CanvasResourceId('unused-image-resource'),
    CanvasResourceId('unused-vector-resource'),
  ]);
  final document = runtime.readDocument();
  expect(
    document.background,
    CanvasBackground(
      color: const Color(0xFF123456),
      grid: CanvasGrid(
        enabled: true,
        cellSize: 24,
        color: const Color(0xFF654321),
      ),
    ),
  );
  expect(document.backgroundElements, hasLength(2));
  _expectRetainedBackgroundImage(document.backgroundElements.first);
  _expectRetainedBackgroundVector(document.backgroundElements.last);
  expect(document.layers.single.elements, isEmpty);
  expect(document.resources, hasLength(2));
  _expectRetainedImageResource(document.resources.first);
  _expectRetainedVectorResource(document.resources.last);
}

void _expectRetainedBackgroundImage(CanvasElement element) {
  expect(element, isA<CanvasImageElement>());
  final image = element as CanvasImageElement;
  expect(image.id, CanvasElementId('background-image'));
  expect(image.resourceId, CanvasResourceId('background-image-resource'));
  expect(image.size, const Size(31, 32));
  expect(image.naturalSize, const Size(33, 34));
  expect(image.revision, 7);
}

void _expectRetainedBackgroundVector(CanvasElement element) {
  expect(element, isA<CanvasVectorElement>());
  final vector = element as CanvasVectorElement;
  expect(vector.id, CanvasElementId('background-vector'));
  expect(vector.resourceId, CanvasResourceId('background-vector-resource'));
  expect(vector.size, const Size(41, 42));
  expect(vector.naturalSize, const Size(43, 44));
  expect(vector.revision, 8);
}

void _expectRetainedImageResource(CanvasResource resource) {
  expect(resource, isA<CanvasImageResource>());
  final image = resource as CanvasImageResource;
  expect(image.id, CanvasResourceId('background-image-resource'));
  expect(
    (image.source as CanvasAppKeyResourceSource).key,
    'background-image-source',
  );
  expect(image.mimeType, 'image/png');
  expect(image.contentHash, 'background-image-hash');
  expect(image.byteLength, 31);
}

void _expectRetainedVectorResource(CanvasResource resource) {
  expect(resource, isA<CanvasVectorResource>());
  final vector = resource as CanvasVectorResource;
  expect(vector.id, CanvasResourceId('background-vector-resource'));
  expect(
    (vector.source as CanvasAppKeyResourceSource).key,
    'background-vector-source',
  );
  expect(vector.contentHash, 'background-vector-hash');
  expect(vector.byteLength, 41);
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

// This one document deliberately combines all retained and removed public
// variants; keeping it together makes the command fixture's state legible.
// ignore: halstead-volume, source-lines-of-code, maintainability-index
CanvasDocument _document() {
  return CanvasDocument(
    resources: [
      CanvasImageResource(
        id: CanvasResourceId('background-image-resource'),
        source: CanvasResourceSource.appKey('background-image-source'),
        mimeType: 'image/png',
        contentHash: 'background-image-hash',
        byteLength: 31,
      ),
      CanvasVectorResource(
        id: CanvasResourceId('background-vector-resource'),
        source: CanvasResourceSource.appKey('background-vector-source'),
        contentHash: 'background-vector-hash',
        byteLength: 41,
      ),
      CanvasImageResource(
        id: CanvasResourceId('content-image-resource'),
        source: CanvasResourceSource.appKey('content-image-source'),
      ),
      CanvasVectorResource(
        id: CanvasResourceId('content-vector-resource'),
        source: CanvasResourceSource.appKey('content-vector-source'),
      ),
      CanvasImageResource(
        id: CanvasResourceId('unused-image-resource'),
        source: CanvasResourceSource.appKey('unused-image-source'),
      ),
      CanvasVectorResource(
        id: CanvasResourceId('unused-vector-resource'),
        source: CanvasResourceSource.appKey('unused-vector-source'),
      ),
    ],
    background: CanvasBackground(
      color: const Color(0xFF123456),
      grid: CanvasGrid(
        enabled: true,
        cellSize: 24,
        color: const Color(0xFF654321),
      ),
    ),
    backgroundElements: [
      CanvasImageElement(
        id: CanvasElementId('background-image'),
        resourceId: CanvasResourceId('background-image-resource'),
        size: const Size(31, 32),
        naturalSize: const Size(33, 34),
        revision: 7,
      ),
      CanvasVectorElement(
        id: CanvasElementId('background-vector'),
        resourceId: CanvasResourceId('background-vector-resource'),
        size: const Size(41, 42),
        naturalSize: const Size(43, 44),
        revision: 8,
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
            resourceId: CanvasResourceId('content-image-resource'),
            size: const Size(2, 2),
          ),
          CanvasVectorElement(
            id: CanvasElementId('vector-a'),
            resourceId: CanvasResourceId('content-vector-resource'),
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
