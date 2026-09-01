// Test body is a named helper so DCM metrics stay on the scenario; assertions
// live in that helper and DCM does not follow tear-offs.
// This fixture is one executable CommandFactsPort composition witness across
// Frame, Selection, Resource, and DeletionProjection; splitting for the import
// threshold would scatter shared fakes and setup, obscuring that boundary.
// ignore_for_file: missing-test-assertion, number-of-imports

import 'dart:collection';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine/src/contracts/internal/command_facts_port.dart';
import 'package:iwb_canvas_engine/src/contracts/internal/deletion_entry_projection_port.dart';
import 'package:iwb_canvas_engine/src/contracts/internal/frame_facts_port.dart';
import 'package:iwb_canvas_engine/src/contracts/internal/resource_catalog_port.dart';
import 'package:iwb_canvas_engine/src/contracts/internal/selection_facts_port.dart';
import 'package:iwb_canvas_engine/src/runtime/runtime_command_facts_adapter.dart';
import 'package:iwb_canvas_engine/src/runtime/runtime_root.dart';
import 'package:iwb_canvas_engine/src/runtime/selection_transform_facts_reader.dart';
import '../../support/accept_commit.dart';

void main() {
  test(
    'command facts are immutable and ordered by document handles',
    _commandFactsAreImmutableAndOrderedByDocumentHandles,
  );
  test(
    'clear facts use one typed frame and resource pass',
    _clearFactsUseOneTypedFrameAndResourcePass,
  );
  test(
    'selection deletion facts fail closed for unresolved and non-content IDs',
    _selectionDeletionFactsFailClosedForInvalidSelectionFacts,
  );
  test(
    'selection deletion resolves selected IDs through Store entries without a frame walk',
    _selectionDeletionUsesProjectedEntriesWithoutFrameWalk,
  );
  test(
    'selection transform resolves only selected handles without a frame walk',
    _selectionTransformResolvesOnlySelectedHandlesWithoutFrameWalk,
  );
  test(
    'selection transform skips sorting for select-all and one deselection',
    _selectionTransformSkipsSortingForCanonicalSelection,
  );
}

void _commandFactsAreImmutableAndOrderedByDocumentHandles() {
  final adapter = _adapter();

  _expectTransformFacts(adapter.selectionTransformFacts());
  _expectDeleteFacts(adapter.selectionDeleteFacts());
  _expectRemoveFacts(adapter);
  _expectClearFacts(adapter.clearContentFacts(removeUnusedResources: true));
}

RuntimeCommandFactsAdapter _adapter({FrameFactsPort? frame}) {
  return RuntimeCommandFactsAdapter(
    frame: frame ?? _FrameFacts(),
    selection: _SelectionFacts(),
    resources: _Resources(),
    deletionEntryProjection: _FixtureDeletionEntryProjection(),
    documentSummary: () => const CanvasDocumentSummary(
      elementCount: 6,
      layerCount: 1,
      resourceCount: 3,
    ),
  );
}

void _selectionTransformResolvesOnlySelectedHandlesWithoutFrameWalk() {
  final frame = _FrameFacts();
  final orderingWork = <SelectionTransformOrderingWorkEvent, int>{};

  final facts = observeSelectionTransformOrderingWork(
    (event) =>
        orderingWork.update(event, (count) => count + 1, ifAbsent: () => 1),
    () => _adapter(frame: frame).selectionTransformFacts(),
  );

  _expectTransformFacts(facts);
  expect(frame.handleEnumerations, 0);
  expect(frame.handleLookups, facts.selectedIds.length);
  expect(frame.elementResolutions, facts.selectedIds.length);
  expect(orderingWork[SelectionTransformOrderingWorkEvent.sortStarted], 1);
}

void _selectionTransformSkipsSortingForCanonicalSelection() {
  final all = _canonicalSelectionTransformOrderingWork();
  final allButOne = _canonicalSelectionTransformOrderingWork(
    deselectedId: CanvasElementId('ordered-b'),
  );

  expect(all[SelectionTransformOrderingWorkEvent.sortStarted], isNull);
  expect(all[SelectionTransformOrderingWorkEvent.canonicalOrderComparison], 2);
  expect(allButOne[SelectionTransformOrderingWorkEvent.sortStarted], isNull);
  expect(
    allButOne[SelectionTransformOrderingWorkEvent.canonicalOrderComparison],
    1,
  );
}

Map<SelectionTransformOrderingWorkEvent, int>
_canonicalSelectionTransformOrderingWork({CanvasElementId? deselectedId}) {
  final root = RuntimeRoot(
    config: const CanvasRuntimeConfig(commitResolver: acceptCommit),
  );
  try {
    root.edits.loadDocumentFromJson(
      encodeCanvasDocumentToJson(_orderedSelectionDocument()),
    );
    root.selectAll(onlySelectable: false);
    if (deselectedId != null) {
      root.toggleSelection(deselectedId);
    }
    final work = <SelectionTransformOrderingWorkEvent, int>{};
    observeSelectionTransformOrderingWork(
      (event) => work.update(event, (count) => count + 1, ifAbsent: () => 1),
      () => root.moveSelection(const Offset(1, 0)),
    );

    return work;
  } finally {
    root.dispose();
  }
}

CanvasDocument _orderedSelectionDocument() {
  return CanvasDocument(
    layers: [
      CanvasLayer(
        id: CanvasLayerId('ordered-layer'),
        elements: [
          CanvasRectElement(
            id: CanvasElementId('ordered-a'),
            size: const Size(1, 1),
          ),
          CanvasRectElement(
            id: CanvasElementId('ordered-b'),
            size: const Size(1, 1),
          ),
          CanvasRectElement(
            id: CanvasElementId('ordered-c'),
            size: const Size(1, 1),
          ),
        ],
      ),
    ],
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
  expect(delete.hasSelection, isTrue);
  expect(delete.allSelectedElementsDeletable, isFalse);
  expect(delete.availability.hasAnySelectedElementDeletable, isTrue);
  expect(
    delete.availability,
    const CanvasSelectionDeleteAvailability(
      hasSelection: true,
      allSelectedElementsDeletable: false,
      hasAnySelectedElementDeletable: true,
    ),
  );
  expect(
    delete.removalIdsFor(CanvasSelectionDeletePolicy.partial),
    delete.deletableIds,
  );
  expect(delete.removalIdsFor(CanvasSelectionDeletePolicy.allOrNone), isEmpty);
  expect(() => delete.deletableIds.clear(), throwsUnsupportedError);
}

void _selectionDeletionFactsFailClosedForInvalidSelectionFacts() {
  final root = RuntimeRoot(
    config: const CanvasRuntimeConfig(commitResolver: acceptCommit),
  );
  addTearDown(root.dispose);
  root.edits.loadDocumentFromJson(
    encodeCanvasDocumentToJson(_invalidFactsDocument()),
  );

  final unresolved = _adapterWithControlledSelection(root, [
    CanvasElementId('eligible-a'),
    CanvasElementId('missing-a'),
  ]).selectionDeleteFacts();
  _expectInvalidSelectionFacts(unresolved);

  final backgroundId = CanvasElementId('background-a');
  final handle = root.elementHandleForId(
    root.frameRevisions.structuralRevision,
    backgroundId,
  );
  final backgroundFacts = handle == null ? null : root.resolveElement(handle);
  expect(handle, isNotNull);
  expect(backgroundFacts?.locationKind, FrameElementLocationKind.background);
  final nonContent = _adapterWithControlledSelection(root, [
    CanvasElementId('eligible-a'),
    backgroundId,
  ]).selectionDeleteFacts();
  _expectInvalidSelectionFacts(nonContent);
}

void _selectionDeletionUsesProjectedEntriesWithoutFrameWalk() {
  final frame = _FrameFacts();
  final facts = RuntimeCommandFactsAdapter(
    frame: frame,
    selection: _SelectionFacts(),
    resources: _Resources(),
    deletionEntryProjection: _FixtureDeletionEntryProjection(),
    documentSummary: () => const CanvasDocumentSummary(
      elementCount: 6,
      layerCount: 1,
      resourceCount: 3,
    ),
  ).selectionDeleteFacts();

  expect(frame.handleEnumerations, 0);
  expect(facts.deletableIds, [
    CanvasElementId('rect-a'),
    CanvasElementId('rect-b'),
    CanvasElementId('locked-a'),
  ]);
  expect(
    facts.removalEntriesFor(CanvasSelectionDeletePolicy.partial)[0].element,
    same(facts.deletableEntries[0].element),
  );
}

RuntimeCommandFactsAdapter _adapterWithControlledSelection(
  RuntimeRoot root,
  Iterable<CanvasElementId> selectedIds,
) {
  return RuntimeCommandFactsAdapter(
    frame: root,
    selection: _ControlledSelectionFacts(selectedIds),
    resources: root.resourceCatalogPort,
    deletionEntryProjection: root.deletionEntryProjectionForTesting,
    documentSummary: () => const CanvasDocumentSummary(
      elementCount: 2,
      layerCount: 1,
      resourceCount: 0,
    ),
  );
}

void _expectInvalidSelectionFacts(SelectionDeleteFacts facts) {
  expect(facts.hasSelection, isTrue);
  expect(facts.allSelectedElementsDeletable, isFalse);
  expect(facts.deletableIds, [CanvasElementId('eligible-a')]);
  expect(facts.removalIdsFor(CanvasSelectionDeletePolicy.partial), [
    CanvasElementId('eligible-a'),
  ]);
  expect(facts.removalIdsFor(CanvasSelectionDeletePolicy.allOrNone), isEmpty);
}

CanvasDocument _invalidFactsDocument() {
  return CanvasDocument(
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
            id: CanvasElementId('eligible-a'),
            size: const Size(1, 1),
          ),
        ],
      ),
    ],
  );
}

final class _ControlledSelectionFacts implements SelectionFactsPort {
  _ControlledSelectionFacts(Iterable<CanvasElementId> selectedIds)
    : _facts = SelectionFacts(
        selectedElementIds: selectedIds,
        selectionRevision: 1,
      );

  final SelectionFacts _facts;

  @override
  SelectionFacts get selectionFacts => _facts;
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
      elementCount: 6,
      layerCount: 1,
      resourceCount: 3,
    ),
  );
  expect(clear.removableElementIds, [
    CanvasElementId('rect-a'),
    CanvasElementId('rect-b'),
    CanvasElementId('locked-a'),
    CanvasElementId('not-deletable-a'),
  ]);
  expect(clear.removableResourceIds, [CanvasResourceId('unused-resource')]);
  expect(() => clear.removableElementIds.clear(), throwsUnsupportedError);
  expect(() => clear.removableResourceIds.clear(), throwsUnsupportedError);
}

// The single invocation must keep its exact output and semantic work bounds
// together; splitting the assertions would obscure their shared port witness.
// ignore: halstead-volume, source-lines-of-code
void _clearFactsUseOneTypedFrameAndResourcePass() {
  final frame = _CountingFrameFacts();
  final selection = _CountingSelectionFacts();
  final resources = _CountingResources(_workResources());
  final adapter = RuntimeCommandFactsAdapter(
    frame: frame,
    selection: selection,
    resources: resources,
    deletionEntryProjection: _FixtureDeletionEntryProjection(),
    documentSummary: _workSummary,
  );

  final facts = adapter.clearContentFacts(removeUnusedResources: true);

  expect(facts.removableElementIds, _workContentIds);
  expect(facts.removableResourceIds, _workRemovedResourceIds);
  expect(frame.handleEnumerations, 1);
  expect(frame.resolveCounts, {for (final id in _workHandleIds) id: 1});
  expect(selection.reads, 0);
  expect(resources.catalogReads, 1);
  expect(resources.list.enumerations, 1);
  expect(resources.list.visits, _workResources().length);
  expect(resources.resourceByIdLookups, 0);
  expect(
    () => facts.removableElementIds.add(CanvasElementId('x')),
    throwsUnsupportedError,
  );
  expect(
    () => facts.removableResourceIds.add(CanvasResourceId('x')),
    throwsUnsupportedError,
  );

  final noCleanupFrame = _CountingFrameFacts();
  final noCleanupResources = _CountingResources(_workResources());
  final noCleanup = RuntimeCommandFactsAdapter(
    frame: noCleanupFrame,
    selection: _CountingSelectionFacts(),
    resources: noCleanupResources,
    deletionEntryProjection: _FixtureDeletionEntryProjection(),
    documentSummary: _workSummary,
  ).clearContentFacts(removeUnusedResources: false);

  expect(noCleanup.removableElementIds, _workContentIds);
  expect(noCleanup.removableResourceIds, isEmpty);
  expect(noCleanupFrame.handleEnumerations, 1);
  expect(noCleanupFrame.resolveCounts, {
    for (final id in _workHandleIds) id: 1,
  });
  expect(noCleanupResources.catalogReads, 0);
  expect(noCleanupResources.list.enumerations, 0);
  expect(noCleanupResources.resourceByIdLookups, 0);
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
      id: CanvasResourceId('background-image-resource'),
      source: CanvasResourceSource.appKey('background-image-source'),
    ),
    CanvasVectorResource(
      id: CanvasResourceId('background-vector-resource'),
      source: CanvasResourceSource.appKey('background-vector-source'),
    ),
    CanvasImageResource(
      id: CanvasResourceId('unused-resource'),
      source: CanvasResourceSource.appKey('unused-source'),
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

final class _FixtureDeletionEntryProjection
    implements DeletionEntryProjectionPort {
  @override
  DeletionEntryProjection projectDeletionEntries(
    Iterable<CanvasElementId> ids,
  ) {
    final entries = <DeletionEntryFacts>[];
    for (final id in ids) {
      final element = switch (id.value) {
        'not-deletable-a' => CanvasRectElement(
          id: id,
          size: const Size(1, 1),
          isDeletable: false,
        ),
        'background-a' || 'background-vector-a' || 'missing' => null,
        _ => CanvasRectElement(id: id, size: const Size(1, 1)),
      };
      if (element != null) {
        entries.add(
          DeletionEntryFacts(
            element: element,
            layerId: CanvasLayerId('layer-a'),
            elementIndex: _orderToken(id),
            orderToken: _orderToken(id),
          ),
        );
      }
    }
    entries.sort((left, right) => left.orderToken.compareTo(right.orderToken));
    return DeletionEntryProjection(entries);
  }

  int _orderToken(CanvasElementId id) => switch (id.value) {
    'rect-a' => 2,
    'rect-b' => 3,
    'locked-a' => 4,
    'not-deletable-a' => 5,
    _ => 0,
  };
}

final class _FrameFacts implements FrameFactsPort {
  final _handles = [
    _handle('background-a', 0),
    _handle('background-vector-a', 1),
    _handle('rect-a', 2),
    _handle('rect-b', 3),
    _handle('locked-a', 4),
    _handle('not-deletable-a', 5),
  ];
  int handleEnumerations = 0;
  int handleLookups = 0;
  int elementResolutions = 0;

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
  List<FrameElementHandle> elementHandles(int structuralRevision) {
    handleEnumerations += 1;
    return _handles;
  }

  @override
  FrameElementHandle? elementHandleForId(
    int structuralRevision,
    CanvasElementId id,
  ) {
    handleLookups += 1;
    return _handles.where((handle) => handle.id == id).firstOrNull;
  }

  @override
  FrameElementFacts? resolveElement(FrameElementHandle handle) {
    elementResolutions += 1;
    return switch (handle.id.value) {
      'background-a' ||
      'background-vector-a' => _fixtureBackgroundFacts(handle),
      'rect-a' ||
      'rect-b' ||
      'locked-a' ||
      'not-deletable-a' => _fixtureContentFacts(handle),
      _ => null,
    };
  }

  @override
  FrameResourceDescriptorFacts? resourceDescriptor(CanvasResourceId id) => null;
}

FrameElementFacts _fixtureBackgroundFacts(FrameElementHandle handle) {
  return switch (handle.id.value) {
    'background-a' => _facts(
      id: handle.id,
      orderToken: handle.orderToken,
      locationKind: FrameElementLocationKind.background,
      kind: CanvasElementKind.image,
      resourceId: CanvasResourceId('background-image-resource'),
    ),
    'background-vector-a' => _facts(
      id: handle.id,
      orderToken: handle.orderToken,
      locationKind: FrameElementLocationKind.background,
      kind: CanvasElementKind.vector,
      resourceId: CanvasResourceId('background-vector-resource'),
    ),
    _ => throw StateError('not a background fixture handle'),
  };
}

FrameElementFacts _fixtureContentFacts(FrameElementHandle handle) {
  return switch (handle.id.value) {
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
    _ => _facts(id: handle.id, orderToken: handle.orderToken),
  };
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
  CanvasElementKind kind = CanvasElementKind.rect,
  CanvasResourceId? resourceId,
  CanvasTransform transform = CanvasTransform.identity,
  bool isLocked = false,
  bool isDeletable = true,
}) {
  return FrameElementFacts(
    id: id,
    kind: kind,
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
    resourceId: resourceId,
    size: const Size(2, 2),
  );
}

final _workHandleIds = [
  CanvasElementId('background-image'),
  CanvasElementId('background-vector'),
  CanvasElementId('content-rect'),
  CanvasElementId('content-locked'),
  CanvasElementId('content-not-deletable'),
  CanvasElementId('content-image'),
  CanvasElementId('content-vector'),
];

final _workContentIds = [
  CanvasElementId('content-rect'),
  CanvasElementId('content-locked'),
  CanvasElementId('content-not-deletable'),
  CanvasElementId('content-image'),
  CanvasElementId('content-vector'),
];

final _workRemovedResourceIds = [
  CanvasResourceId('content-image-resource'),
  CanvasResourceId('content-vector-resource'),
  CanvasResourceId('unused-image-resource'),
  CanvasResourceId('unused-vector-resource'),
];

CanvasDocumentSummary _workSummary() {
  return const CanvasDocumentSummary(
    elementCount: 7,
    layerCount: 1,
    resourceCount: 6,
  );
}

List<CanvasResource> _workResources() {
  return [
    CanvasImageResource(
      id: CanvasResourceId('background-image-resource'),
      source: CanvasResourceSource.appKey('background-image-source'),
    ),
    CanvasVectorResource(
      id: CanvasResourceId('background-vector-resource'),
      source: CanvasResourceSource.appKey('background-vector-source'),
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
  ];
}

final class _CountingSelectionFacts implements SelectionFactsPort {
  int reads = 0;

  @override
  SelectionFacts get selectionFacts {
    reads += 1;
    return SelectionFacts(selectedElementIds: const [], selectionRevision: 0);
  }
}

final class _CountingResources implements ResourceCatalogPort {
  _CountingResources(List<CanvasResource> resources)
    : list = _VisitCountingResourceList(resources);

  final _VisitCountingResourceList list;
  int catalogReads = 0;
  int resourceByIdLookups = 0;

  @override
  int get resourceCount => list.length;

  @override
  List<CanvasResource> get resources {
    catalogReads += 1;
    return list;
  }

  @override
  CanvasResource? resourceById(CanvasResourceId id) {
    resourceByIdLookups += 1;
    return null;
  }
}

final class _VisitCountingResourceList extends ListBase<CanvasResource> {
  _VisitCountingResourceList(this._values);

  final List<CanvasResource> _values;
  int enumerations = 0;
  int visits = 0;

  @override
  int get length => _values.length;

  @override
  set length(int value) => _values.length = value;

  @override
  CanvasResource operator [](int index) => _values[index];

  @override
  void operator []=(int index, CanvasResource value) {
    _values[index] = value;
  }

  @override
  Iterator<CanvasResource> get iterator {
    enumerations += 1;
    return _VisitCountingIterator(_values.iterator, () => visits += 1);
  }
}

final class _VisitCountingIterator implements Iterator<CanvasResource> {
  _VisitCountingIterator(this._delegate, this._recordVisit);

  final Iterator<CanvasResource> _delegate;
  final void Function() _recordVisit;

  @override
  CanvasResource get current => _delegate.current;

  @override
  bool moveNext() {
    final hasNext = _delegate.moveNext();
    if (hasNext) {
      _recordVisit();
    }
    return hasNext;
  }
}

final class _CountingFrameFacts implements FrameFactsPort {
  _CountingFrameFacts()
    : _handles = List.unmodifiable([
        for (var index = 0; index < _workHandleIds.length; index += 1)
          FrameElementHandle(
            id: _workHandleIds[index],
            structuralRevision: 4,
            generation: index,
            orderToken: index,
          ),
      ]);

  final List<FrameElementHandle> _handles;
  final Map<CanvasElementId, int> resolveCounts = {};
  int handleEnumerations = 0;

  @override
  FrameRevisionFacts get frameRevisions => const FrameRevisionFacts(
    documentRevision: 4,
    structuralRevision: 4,
    boundsRevision: 4,
    elementVisualRevision: 4,
    backgroundRevision: 4,
    gridRevision: 4,
    resourceRevision: 4,
  );

  @override
  CanvasBackground get background => const CanvasBackground();

  @override
  int elementCount(int structuralRevision) => _handles.length;

  @override
  List<FrameElementHandle> elementHandles(int structuralRevision) {
    handleEnumerations += 1;
    return _handles;
  }

  @override
  FrameElementHandle? elementHandleForId(
    int structuralRevision,
    CanvasElementId id,
  ) {
    return null;
  }

  @override
  FrameElementFacts? resolveElement(FrameElementHandle handle) {
    resolveCounts.update(handle.id, (count) => count + 1, ifAbsent: () => 1);
    return switch (handle.id.value) {
      'background-image' || 'background-vector' => _workBackgroundFacts(handle),
      'content-rect' ||
      'content-locked' ||
      'content-not-deletable' ||
      'content-image' ||
      'content-vector' => _workContentFacts(handle),
      _ => null,
    };
  }

  @override
  FrameResourceDescriptorFacts? resourceDescriptor(CanvasResourceId id) => null;
}

FrameElementFacts _workBackgroundFacts(FrameElementHandle handle) {
  return switch (handle.id.value) {
    'background-image' => _facts(
      id: handle.id,
      orderToken: handle.orderToken,
      locationKind: FrameElementLocationKind.background,
      kind: CanvasElementKind.image,
      resourceId: CanvasResourceId('background-image-resource'),
    ),
    'background-vector' => _facts(
      id: handle.id,
      orderToken: handle.orderToken,
      locationKind: FrameElementLocationKind.background,
      kind: CanvasElementKind.vector,
      resourceId: CanvasResourceId('background-vector-resource'),
    ),
    _ => throw StateError('not a work background handle'),
  };
}

FrameElementFacts _workContentFacts(FrameElementHandle handle) {
  return switch (handle.id.value) {
    'content-locked' => _facts(
      id: handle.id,
      orderToken: handle.orderToken,
      isLocked: true,
    ),
    'content-not-deletable' => _facts(
      id: handle.id,
      orderToken: handle.orderToken,
      isDeletable: false,
    ),
    'content-image' => _facts(
      id: handle.id,
      orderToken: handle.orderToken,
      kind: CanvasElementKind.image,
      resourceId: CanvasResourceId('content-image-resource'),
    ),
    'content-vector' => _facts(
      id: handle.id,
      orderToken: handle.orderToken,
      kind: CanvasElementKind.vector,
      resourceId: CanvasResourceId('content-vector-resource'),
    ),
    _ => _facts(id: handle.id, orderToken: handle.orderToken),
  };
}
