// Test body is a named helper so DCM metrics stay on the scenario; assertions
// live in that helper and DCM does not follow tear-offs.
// ignore_for_file: missing-test-assertion

import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine/src/contracts/internal/command_facts_port.dart';
import 'package:iwb_canvas_engine/src/contracts/internal/frame_facts_port.dart';
import 'package:iwb_canvas_engine/src/contracts/internal/resource_catalog_port.dart';
import 'package:iwb_canvas_engine/src/contracts/internal/selection_facts_port.dart';
import 'package:iwb_canvas_engine/src/runtime/runtime_command_facts_adapter.dart';

void main() {
  test(
    'command facts are immutable and ordered by document handles',
    _commandFactsAreImmutableAndOrderedByDocumentHandles,
  );
}

void _commandFactsAreImmutableAndOrderedByDocumentHandles() {
  final adapter = _adapter();

  _expectTransformFacts(adapter.selectionTransformFacts());
  _expectDeleteFacts(adapter.selectionDeleteFacts());
  _expectRemoveFacts(adapter);
  _expectClearFacts(adapter.clearContentFacts(removeUnusedResources: true));
}

RuntimeCommandFactsAdapter _adapter() {
  return RuntimeCommandFactsAdapter(
    frame: _FrameFacts(),
    selection: _SelectionFacts(),
    resources: _Resources(),
    documentSummary: () => const CanvasDocumentSummary(
      elementCount: 5,
      layerCount: 1,
      resourceCount: 1,
    ),
  );
}

void _expectTransformFacts(SelectionTransformFacts transform) {
  expect(transform.selectedIds, [
    CanvasElementId('background-a'),
    CanvasElementId('rect-a'),
    CanvasElementId('rect-b'),
    CanvasElementId('locked-a'),
  ]);
  expect(transform.movableElements.map((element) => element.id), [
    CanvasElementId('rect-a'),
    CanvasElementId('rect-b'),
  ]);
  expect(transform.selectionBoundsWorld, const Rect.fromLTRB(-1, -1, 11, 1));
  expect(
    () => transform.selectedIds.add(CanvasElementId('x')),
    throwsUnsupportedError,
  );
  expect(() => transform.movableElements.clear(), throwsUnsupportedError);
}

void _expectDeleteFacts(SelectionDeleteFacts delete) {
  expect(delete.deletableIds, [
    CanvasElementId('rect-a'),
    CanvasElementId('rect-b'),
    CanvasElementId('locked-a'),
  ]);
  expect(() => delete.deletableIds.clear(), throwsUnsupportedError);
}

void _expectRemoveFacts(RuntimeCommandFactsAdapter adapter) {
  expect(
    adapter.removeElementFacts(CanvasElementId('rect-a')).canRemove,
    isTrue,
  );
  expect(
    adapter.removeElementFacts(CanvasElementId('background-a')).canRemove,
    isTrue,
  );
  expect(
    adapter.removeElementFacts(CanvasElementId('not-deletable-a')).canRemove,
    isTrue,
  );
  expect(
    adapter.removeElementFacts(CanvasElementId('missing')).canRemove,
    isFalse,
  );
}

void _expectClearFacts(ClearContentFacts clear) {
  expect(
    clear.summary,
    const CanvasDocumentSummary(
      elementCount: 5,
      layerCount: 1,
      resourceCount: 1,
    ),
  );
  expect(clear.removableElementIds, [
    CanvasElementId('background-a'),
    CanvasElementId('rect-a'),
    CanvasElementId('rect-b'),
    CanvasElementId('locked-a'),
    CanvasElementId('not-deletable-a'),
  ]);
  expect(clear.removableResourceIds, [CanvasResourceId('resource-a')]);
  expect(() => clear.removableElementIds.clear(), throwsUnsupportedError);
}

final class _SelectionFacts implements SelectionFactsPort {
  @override
  SelectionFacts get selectionFacts => SelectionFacts(
    selectedElementIds: [
      CanvasElementId('rect-b'),
      CanvasElementId('rect-a'),
      CanvasElementId('locked-a'),
      CanvasElementId('background-a'),
    ],
    selectionRevision: 1,
  );
}

final class _Resources implements ResourceCatalogPort {
  final _resources = [
    CanvasImageResource(
      id: CanvasResourceId('resource-a'),
      source: CanvasResourceSource.appKey('asset-a'),
    ),
  ];

  @override
  int get resourceCount => _resources.length;

  @override
  List<CanvasResource> get resources => _resources;

  @override
  CanvasResource? resourceById(CanvasResourceId id) {
    return _resources.where((resource) => resource.id == id).firstOrNull;
  }
}

final class _FrameFacts implements FrameFactsPort {
  final _handles = [
    _handle('background-a', 0),
    _handle('rect-a', 1),
    _handle('rect-b', 2),
    _handle('locked-a', 3),
    _handle('not-deletable-a', 4),
  ];

  @override
  FrameRevisionFacts get frameRevisions => const FrameRevisionFacts(
    documentRevision: 0,
    structuralRevision: 0,
    boundsRevision: 0,
    elementVisualRevision: 0,
    backgroundRevision: 0,
    gridRevision: 0,
    resourceRevision: 0,
  );

  @override
  CanvasBackground get background => const CanvasBackground();

  @override
  int elementCount(int structuralRevision) => _handles.length;

  @override
  List<FrameElementHandle> elementHandles(int structuralRevision) => _handles;

  @override
  FrameElementHandle? elementHandleForId(
    int structuralRevision,
    CanvasElementId id,
  ) {
    return _handles.where((handle) => handle.id == id).firstOrNull;
  }

  @override
  FrameElementFacts? resolveElement(FrameElementHandle handle) {
    return switch (handle.id.value) {
      'background-a' => _facts(
        id: handle.id,
        orderToken: handle.orderToken,
        locationKind: FrameElementLocationKind.background,
      ),
      'rect-a' => _facts(id: handle.id, orderToken: handle.orderToken),
      'rect-b' => _facts(
        id: handle.id,
        orderToken: handle.orderToken,
        transform: CanvasTransform.translation(const Offset(10, 0)),
      ),
      'locked-a' => _facts(
        id: handle.id,
        orderToken: handle.orderToken,
        isLocked: true,
      ),
      'not-deletable-a' => _facts(
        id: handle.id,
        orderToken: handle.orderToken,
        isDeletable: false,
      ),
      _ => null,
    };
  }

  @override
  FrameResourceDescriptorFacts? resourceDescriptor(CanvasResourceId id) => null;
}

FrameElementHandle _handle(String id, int orderToken) {
  return FrameElementHandle(
    id: CanvasElementId(id),
    structuralRevision: 0,
    generation: orderToken,
    orderToken: orderToken,
  );
}

// Fake frame facts mirror the internal port shape. Keeping the optional fact
// knobs on one builder makes the fixture owner cases explicit.
// ignore: number-of-parameters
FrameElementFacts _facts({
  required CanvasElementId id,
  required int orderToken,
  FrameElementLocationKind locationKind = FrameElementLocationKind.content,
  CanvasTransform transform = CanvasTransform.identity,
  bool isLocked = false,
  bool isDeletable = true,
}) {
  return FrameElementFacts(
    id: id,
    kind: CanvasElementKind.rect,
    revision: 0,
    generation: orderToken,
    orderToken: orderToken,
    locationKind: locationKind,
    transform: transform,
    opacity: 1,
    hitPadding: 0,
    isVisible: true,
    isSelectable: true,
    isLocked: isLocked,
    isDeletable: isDeletable,
    isTransformable: true,
    metadata: const CanvasMetadata.empty(),
    size: const Size(2, 2),
  );
}
