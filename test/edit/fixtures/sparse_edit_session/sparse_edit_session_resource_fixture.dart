import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine/src/edit/draft_document.dart';
import 'package:iwb_canvas_engine/src/edit/edit_session.dart';

import 'sparse_edit_session_support.dart';

// One direct registration inventory makes this owner's complete public evidence visible.
// ignore: source-lines-of-code
void registerSparseEditSessionResourceTests() {
  test(
    'sparse resource references follow accepted element overlay',
    () => expect(_sparseResourceReferencesUseAcceptedOverlay, returnsNormally),
  );
  test(
    'sparse resource decisions use bounded split-count work',
    () => expect(
      _sparseResourceDecisionsUseBoundedSplitCountWork,
      returnsNormally,
    ),
  );
  test(
    'sparse remove touches background layer only for background removals',
    () => expect(
      _sparseRemoveTouchesBackgroundLayerOnlyForBackgroundRemovals,
      returnsNormally,
    ),
  );
  test(
    'sparse remove and re-add uses the current placement before clear',
    () => expect(
      _sparseRemoveAndReaddUsesCurrentPlacementBeforeClear,
      returnsNormally,
    ),
  );
  test(
    'sparse clear retains background image and vector resources',
    () => expect(
      _sparseClearRetainsBackgroundImageAndVectorResources,
      returnsNormally,
    ),
  );
  test(
    'sparse clear retains committed and local background resources',
    () => expect(
      _sparseClearRetainsCommittedAndLocalBackgroundResources,
      returnsNormally,
    ),
  );
  test(
    'promoted sparse clear keeps DraftDocument resource work bounded',
    () => expect(
      _promotedSparseClearKeepsDraftResourceWorkBounded,
      returnsNormally,
    ),
  );
  test(
    'sparse background to content move releases its resource during clear',
    () => expect(
      _sparseBackgroundToContentMoveReleasesResourceDuringClear,
      returnsNormally,
    ),
  );
}

int draftResourceWorkCount(
  Iterable<DraftResourceWorkEvent> events,
  DraftResourceWorkKind kind,
) => events.where((event) => event.kind == kind).length;

/// Independent current-row oracle for sparse reference decisions.
final class _SparseReferenceOracle {
  _SparseReferenceOracle(CanvasDocument seed) {
    for (final resource in seed.resources) {
      _resources[resource.id] = resource;
    }
    for (final element in seed.backgroundElements) {
      _rows[element.id] = element;
      _backgroundIds.add(element.id);
    }
    for (final layer in seed.layers) {
      for (final element in layer.elements) {
        _rows[element.id] = element;
      }
    }
  }

  final Map<CanvasResourceId, CanvasResource> _resources = {};
  final Map<CanvasElementId, CanvasElement> _rows = {};
  final Set<CanvasElementId> _backgroundIds = {};

  void addContent(CanvasElement element) {
    _rows[element.id] = element;
  }

  void replace(CanvasElement element) {
    _rows[element.id] = element;
  }

  void upsertResource(CanvasResource resource) {
    _resources[resource.id] = resource;
  }

  void remove(CanvasElementId id) {
    _rows.remove(id);
  }

  bool removeUnusedResource(CanvasResourceId id) {
    if (!_resources.containsKey(id) || imageCount(id) + vectorCount(id) > 0) {
      return false;
    }
    _resources.remove(id);
    return true;
  }

  CanvasClearResult clearContent({required bool removeUnusedResources}) {
    final removedElementIds = [
      for (final id in _rows.keys)
        if (!_backgroundIds.contains(id)) id,
    ];
    for (final id in removedElementIds) {
      _rows.remove(id);
    }
    final removedResourceIds = removeUnusedResources
        ? [
            for (final id in _resources.keys.toList())
              if (removeUnusedResource(id)) id,
          ]
        : const <CanvasResourceId>[];
    return CanvasClearResult(
      removedElementIds: removedElementIds,
      removedResourceIds: removedResourceIds,
      didClearContent:
          removedElementIds.isNotEmpty || removedResourceIds.isNotEmpty,
    );
  }

  int imageCount(CanvasResourceId id) => _referenceCount(id, image: true);

  int vectorCount(CanvasResourceId id) => _referenceCount(id, image: false);

  int _referenceCount(CanvasResourceId id, {required bool image}) {
    return _rows.values.where((element) {
      return switch (element) {
        CanvasImageElement(:final resourceId) => image && resourceId == id,
        CanvasVectorElement(:final resourceId) => !image && resourceId == id,
        _ => false,
      };
    }).length;
  }
}

final class _SparseReferenceWorkCounts {
  final Map<SparseEditReferenceWorkKind, int> _counts = {};
  final Map<
    ({SparseEditReferenceWorkKind kind, SparseEditReferenceFamily family}),
    int
  >
  _familyCounts = {};
  final Map<
    ({SparseEditReferenceFamily family, CanvasResourceId resourceId}),
    int
  >
  _familyResourceMutationCounts = {};

  void record(SparseEditReferenceWorkEvent event) {
    _counts.update(event.kind, (count) => count + 1, ifAbsent: () => 1);
    final family = event.family;
    if (family != null) {
      final key = (kind: event.kind, family: family);
      _familyCounts.update(key, (count) => count + 1, ifAbsent: () => 1);
      final resourceId = event.resourceId;
      if (resourceId != null &&
          (event.kind == SparseEditReferenceWorkKind.deltaEntryWrite ||
              event.kind == SparseEditReferenceWorkKind.deltaEntryRemove)) {
        final mutationKey = (family: family, resourceId: resourceId);
        _familyResourceMutationCounts.update(
          mutationKey,
          (count) => count + 1,
          ifAbsent: () => 1,
        );
      }
    }
  }

  int count(SparseEditReferenceWorkKind kind) => _counts[kind] ?? 0;

  int countFamily(
    SparseEditReferenceWorkKind kind,
    SparseEditReferenceFamily family,
  ) {
    return _familyCounts[(kind: kind, family: family)] ?? 0;
  }

  int get deltaEntryMutations =>
      count(SparseEditReferenceWorkKind.deltaEntryWrite) +
      count(SparseEditReferenceWorkKind.deltaEntryRemove);

  int countFamilyResourceMutations(
    SparseEditReferenceFamily family,
    CanvasResourceId resourceId,
  ) {
    return _familyResourceMutationCounts[(
          family: family,
          resourceId: resourceId,
        )] ??
        0;
  }
}

EditSession _sparseSessionWithPopulatedReferenceDeltas() {
  final session = sparseSessionForDocument(_documentWithLifecycleReferences());
  expect(
    session.updateElement(
      CanvasImageElementUpdate(
        id: CanvasElementId('lifecycle-image-element'),
        resourceId: CanvasFieldSet(CanvasResourceId('lifecycle-image-next')),
      ),
    ),
    isTrue,
  );
  expect(
    session.updateElement(
      CanvasVectorElementUpdate(
        id: CanvasElementId('lifecycle-vector-element'),
        resourceId: CanvasFieldSet(CanvasResourceId('lifecycle-vector-next')),
      ),
    ),
    isTrue,
  );
  return session;
}

CanvasDocument _documentWithReferencedResource() {
  return CanvasDocument(
    resources: [sparseImageResource('resource-a')],
    layers: [
      CanvasLayer(
        id: CanvasLayerId('layer-a'),
        elements: [
          CanvasImageElement(
            id: CanvasElementId('image-a'),
            resourceId: CanvasResourceId('resource-a'),
            size: const Size(1, 1),
          ),
        ],
      ),
    ],
  );
}

CanvasDocument _documentWithTwoResources() {
  return CanvasDocument(
    resources: [
      sparseImageResource('resource-a'),
      sparseImageResource('resource-b'),
    ],
    layers: [
      CanvasLayer(
        id: CanvasLayerId('layer-a'),
        elements: [
          CanvasImageElement(
            id: CanvasElementId('image-a'),
            resourceId: CanvasResourceId('resource-a'),
            size: const Size(1, 1),
          ),
        ],
      ),
    ],
  );
}

CanvasDocument _documentWithReferenceOracleRows() {
  return CanvasDocument(
    resources: [
      sparseImageResource('shared-resource'),
      sparseImageResource('image-resource'),
      sparseImageResource('replacement-image'),
      CanvasVectorResource(
        id: CanvasResourceId('vector-resource'),
        source: CanvasResourceSource.appKey('vector-source'),
      ),
      sparseImageResource('background-vector-resource'),
    ],
    backgroundElements: [
      CanvasImageElement(
        id: CanvasElementId('background-shared'),
        resourceId: CanvasResourceId('shared-resource'),
        size: const Size(1, 1),
      ),
      CanvasVectorElement(
        id: CanvasElementId('background-vector'),
        resourceId: CanvasResourceId('background-vector-resource'),
        size: const Size(1, 1),
      ),
    ],
    layers: [
      CanvasLayer(
        id: CanvasLayerId('layer-a'),
        elements: [
          CanvasImageElement(
            id: CanvasElementId('cross-family'),
            resourceId: CanvasResourceId('shared-resource'),
            size: const Size(1, 1),
          ),
        ],
      ),
    ],
  );
}

CanvasDocument _documentWithLifecycleReferences() {
  return CanvasDocument(
    resources: [
      sparseImageResource('lifecycle-image'),
      sparseImageResource('lifecycle-image-next'),
      CanvasVectorResource(
        id: CanvasResourceId('lifecycle-vector'),
        source: CanvasResourceSource.appKey('lifecycle-vector'),
      ),
      CanvasVectorResource(
        id: CanvasResourceId('lifecycle-vector-next'),
        source: CanvasResourceSource.appKey('lifecycle-vector-next'),
      ),
    ],
    layers: [
      CanvasLayer(
        id: CanvasLayerId('layer-a'),
        elements: [
          CanvasImageElement(
            id: CanvasElementId('lifecycle-image-element'),
            resourceId: CanvasResourceId('lifecycle-image'),
            size: const Size(1, 1),
          ),
          CanvasVectorElement(
            id: CanvasElementId('lifecycle-vector-element'),
            resourceId: CanvasResourceId('lifecycle-vector'),
            size: const Size(1, 1),
          ),
        ],
      ),
    ],
  );
}

void _sparseResourceReferencesUseAcceptedOverlay() {
  _expectRemoveThenResourceRemoval();
  _expectImageUpdateThenResourceRemoval();
  _expectVectorRemovalThenResourceRemoval();
  _expectSparseReferencesMatchCurrentRowOracle();
  _expectSparseResourceQueryUsesSplitCommittedCounts();
  _expectSparseSplitCountsIgnoreDescriptorAndNoOpChanges();
  _expectReferencedResourceRemovalNoOp();
}

void _expectSparseResourceQueryUsesSplitCommittedCounts() {
  final facts = SparseFixtureFacts(_documentWithTwoResources());
  final session = EditSession.sparse(
    facts: facts,
    promoteDraft: () => DraftDocument(facts.document),
    selectedElementIds: const [],
  );

  expect(
    session.updateElement(
      CanvasImageElementUpdate(
        id: CanvasElementId('image-a'),
        resourceId: CanvasFieldSet(CanvasResourceId('resource-b')),
      ),
    ),
    isTrue,
  );
  expect(session.removeUnusedResource(CanvasResourceId('resource-a')), isTrue);
  expect(facts.elementIdsReadCount, 0);
  expect(facts.imageResourceReferenceCountReadCount, greaterThan(0));
  expect(facts.vectorResourceReferenceCountReadCount, greaterThan(0));
}

void _expectRemoveThenResourceRemoval() {
  final session = sparseSessionForDocument(_documentWithReferencedResource());

  expect(session.removeElement(CanvasElementId('image-a')), isTrue);
  expect(session.removeUnusedResource(CanvasResourceId('resource-a')), isTrue);
  expect(
    session.draftSummary,
    const CanvasDocumentSummary(
      elementCount: 0,
      layerCount: 1,
      resourceCount: 0,
    ),
  );
}

void _expectImageUpdateThenResourceRemoval() {
  final session = sparseSessionForDocument(_documentWithTwoResources());

  expect(
    session.updateElement(
      CanvasImageElementUpdate(
        id: CanvasElementId('image-a'),
        resourceId: CanvasFieldSet(CanvasResourceId('resource-b')),
      ),
    ),
    isTrue,
  );
  expect(session.removeUnusedResource(CanvasResourceId('resource-a')), isTrue);
  expect(
    session.draftSummary,
    const CanvasDocumentSummary(
      elementCount: 1,
      layerCount: 1,
      resourceCount: 1,
    ),
  );
}

void _expectVectorRemovalThenResourceRemoval() {
  final resourceId = CanvasResourceId('vector-resource');
  final session = sparseSessionForDocument(
    CanvasDocument(
      resources: [
        CanvasVectorResource(
          id: resourceId,
          source: CanvasResourceSource.appKey('vector-source'),
        ),
      ],
      layers: [
        CanvasLayer(
          id: CanvasLayerId('layer-a'),
          elements: [
            CanvasVectorElement(
              id: CanvasElementId('vector-a'),
              resourceId: resourceId,
              size: const Size(1, 1),
            ),
          ],
        ),
      ],
    ),
  );

  expect(session.removeElement(CanvasElementId('vector-a')), isTrue);
  expect(session.removeUnusedResource(resourceId), isTrue);
}

// Keep this sequence together: each public result becomes the next oracle state.
// ignore: halstead-volume, source-lines-of-code
void _expectSparseReferencesMatchCurrentRowOracle() {
  final events = <SparseEditReferenceWorkEvent>[];
  observeSparseEditReferenceWork(
    events.add,
    () => _runSparseReferencesMatchCurrentRowOracle(events),
  );
}

// The trace must remain linear because each observed count is the next state.
// ignore: halstead-volume, source-lines-of-code
void _runSparseReferencesMatchCurrentRowOracle(
  List<SparseEditReferenceWorkEvent> events,
) {
  final seed = _documentWithReferenceOracleRows();
  final oracle = _SparseReferenceOracle(seed);
  final session = sparseSessionForDocument(seed);
  final sharedResourceId = CanvasResourceId('shared-resource');
  final imageResourceId = CanvasResourceId('image-resource');
  final replacementImageResourceId = CanvasResourceId('replacement-image');
  final vectorResourceId = CanvasResourceId('vector-resource');

  final addedImage = CanvasImageElement(
    id: CanvasElementId('added-image'),
    resourceId: imageResourceId,
    size: const Size(1, 1),
  );
  session.addElement(addedImage);
  oracle.addContent(addedImage);
  _expectCurrentResourceDecision(session, oracle, imageResourceId, events);

  expect(
    session.updateElement(
      CanvasImageElementUpdate(
        id: addedImage.id,
        resourceId: CanvasFieldSet(replacementImageResourceId),
      ),
    ),
    isTrue,
  );
  oracle.replace(
    CanvasImageElement(
      id: addedImage.id,
      resourceId: replacementImageResourceId,
      size: const Size(1, 1),
    ),
  );
  _expectCurrentResourceDecision(session, oracle, imageResourceId, events);
  _expectCurrentResourceDecision(
    session,
    oracle,
    replacementImageResourceId,
    events,
  );

  expect(session.removeElement(CanvasElementId('cross-family')), isTrue);
  oracle.remove(CanvasElementId('cross-family'));
  _expectCurrentResourceDecision(session, oracle, sharedResourceId, events);

  final replacementVector = CanvasVectorElement(
    id: CanvasElementId('cross-family'),
    resourceId: sharedResourceId,
    size: const Size(1, 1),
  );
  session.addElement(replacementVector);
  oracle.addContent(replacementVector);
  _expectCurrentResourceDecision(session, oracle, sharedResourceId, events);

  final addedVector = CanvasVectorElement(
    id: CanvasElementId('added-vector'),
    resourceId: vectorResourceId,
    size: const Size(1, 1),
  );
  session.addElement(addedVector);
  oracle.addContent(addedVector);
  _expectCurrentResourceDecision(session, oracle, vectorResourceId, events);

  expect(session.removeElement(addedVector.id), isTrue);
  oracle.remove(addedVector.id);
  _expectCurrentResourceDecision(session, oracle, vectorResourceId, events);

  final clear = session.clearContent(removeUnusedResources: true);
  final expectedClear = oracle.clearContent(removeUnusedResources: true);
  expect(clear.removedElementIds, expectedClear.removedElementIds);
  expect(clear.removedResourceIds, expectedClear.removedResourceIds);
  expect(clear.didClearContent, expectedClear.didClearContent);
  _expectCurrentResourceDecision(session, oracle, sharedResourceId, events);
  _expectCurrentResourceDecision(
    session,
    oracle,
    CanvasResourceId('background-vector-resource'),
    events,
  );
}

void _expectCurrentResourceDecision(
  EditSession session,
  _SparseReferenceOracle oracle,
  CanvasResourceId id,
  List<SparseEditReferenceWorkEvent> events,
) {
  final start = events.length;
  final imageCount = oracle.imageCount(id);
  final vectorCount = oracle.vectorCount(id);
  expect(session.removeUnusedResource(id), oracle.removeUnusedResource(id));
  final observations = events
      .skip(start)
      .where(
        (event) =>
            event.kind == SparseEditReferenceWorkKind.currentSplitCount &&
            event.resourceId == id,
      )
      .toList();
  expect(
    observations,
    hasLength(1),
    reason: 'split observation for ${id.value}',
  );
  expect(observations.single.imageCount, imageCount);
  expect(observations.single.vectorCount, vectorCount);
}

// The descriptor/no-op sequence must retain one current-row oracle so every
// decision is checked against the state produced by its immediate predecessor.
// ignore: halstead-volume, source-lines-of-code
void _expectSparseSplitCountsIgnoreDescriptorAndNoOpChanges() {
  final seed = _documentWithReferenceOracleRows();
  final oracle = _SparseReferenceOracle(seed);
  final session = sparseSessionForDocument(seed);
  final events = <SparseEditReferenceWorkEvent>[];
  final sharedResourceId = CanvasResourceId('shared-resource');
  final missingResourceId = CanvasResourceId('missing-resource');

  observeSparseEditReferenceWork(events.add, () {
    expect(
      session.upsertResource(sparseImageResource('shared-resource')),
      isFalse,
    );
    _expectCurrentResourceDecision(session, oracle, sharedResourceId, events);

    final replacement = CanvasImageResource(
      id: sharedResourceId,
      source: CanvasResourceSource.appKey('replacement-shared-resource'),
    );
    expect(session.upsertResource(replacement), isTrue);
    oracle.upsertResource(replacement);
    _expectCurrentResourceDecision(session, oracle, sharedResourceId, events);

    final missingImage = CanvasImageElement(
      id: CanvasElementId('missing-resource-image'),
      resourceId: missingResourceId,
      size: const Size(1, 1),
    );
    session.addElement(missingImage);
    oracle.addContent(missingImage);
    expect(session.removeUnusedResource(missingResourceId), isFalse);

    final missingDescriptor = sparseImageResource('missing-resource');
    expect(session.upsertResource(missingDescriptor), isTrue);
    oracle.upsertResource(missingDescriptor);
    _expectCurrentResourceDecision(session, oracle, missingResourceId, events);

    expect(
      session.updateElement(
        CanvasImageElementUpdate(
          id: CanvasElementId('absent-image'),
          resourceId: CanvasFieldSet(sharedResourceId),
        ),
      ),
      isFalse,
    );
    _expectCurrentResourceDecision(session, oracle, sharedResourceId, events);

    expect(
      session.updateElement(
        CanvasImageElementUpdate(
          id: missingImage.id,
          resourceId: CanvasFieldSet(missingResourceId),
        ),
      ),
      isFalse,
    );
    _expectCurrentResourceDecision(session, oracle, missingResourceId, events);

    final compensation = CanvasVectorElement(
      id: CanvasElementId('compensation-vector'),
      resourceId: sharedResourceId,
      size: const Size(1, 1),
    );
    session.addElement(compensation);
    oracle.addContent(compensation);
    _expectCurrentResourceDecision(session, oracle, sharedResourceId, events);
    expect(session.removeElement(compensation.id), isTrue);
    oracle.remove(compensation.id);
    _expectCurrentResourceDecision(session, oracle, sharedResourceId, events);
  });
}

void _sparseResourceDecisionsUseBoundedSplitCountWork() {
  final queryReadCosts = <int>[];
  for (final mutationCount in [1, 65, 257]) {
    queryReadCosts.add(
      _expectSparseResourceQueryWorkAtSupportedSize(mutationCount),
    );
  }
  expect(queryReadCosts.toSet(), hasLength(1));
  _expectSparseResourceClearWorkAtSupportedSize(priorImageMutationCount: 0);
  _expectSparseResourceClearWorkAtSupportedSize(priorImageMutationCount: 257);
  _expectSparseResourceReferenceLifecycleWork();
}

// One trace intentionally couples K mutations with both split-family queries.
// ignore: halstead-volume, source-lines-of-code, maintainability-index
int _expectSparseResourceQueryWorkAtSupportedSize(int imageMutationCount) {
  const elementCount = 200000;
  const resourceCount = 4096;
  final missingResourceId = CanvasResourceId('missing-resource');
  final facts = SupportedSizeSparseFacts(
    elementCount: elementCount,
    layerCount: 1,
    committedResourceCount: resourceCount,
  );
  final session = EditSession.sparse(
    facts: facts,
    promoteDraft: () => throw StateError('resource query must stay sparse'),
    selectedElementIds: const [],
  );
  final work = _SparseReferenceWorkCounts();
  var entryReadsBeforeQueries = 0;

  observeSparseEditReferenceWork(work.record, () {
    for (var index = 0; index < imageMutationCount; index += 1) {
      expect(
        session.updateElement(
          CanvasImageElementUpdate(
            id: CanvasElementId('element-0'),
            resourceId: CanvasFieldSet(
              CanvasResourceId(index.isEven ? 'resource-1' : 'resource-0'),
            ),
          ),
        ),
        isTrue,
      );
    }
    expect(
      session.updateElement(
        CanvasVectorElementUpdate(
          id: CanvasElementId('element-1'),
          resourceId: CanvasFieldSet(CanvasResourceId('resource-3')),
        ),
      ),
      isTrue,
    );
    expect(
      session.updateElement(
        CanvasImageElementUpdate(
          id: CanvasElementId('element-0'),
          resourceId: CanvasFieldSet(missingResourceId),
        ),
      ),
      isTrue,
    );
    entryReadsBeforeQueries = work.count(
      SparseEditReferenceWorkKind.deltaEntryRead,
    );
    expect(
      session.upsertResource(sparseImageResource('missing-resource')),
      isTrue,
    );
    expect(
      session.removeUnusedResource(CanvasResourceId('resource-0')),
      isTrue,
    );
    expect(
      session.removeUnusedResource(CanvasResourceId('resource-2')),
      isTrue,
    );
  });

  expect(facts.elementIdsReadCount, 0);
  expect(facts.resourceIdsReadCount, 0);
  expect(facts.imageResourceReferenceCountReadCount, 3);
  expect(facts.vectorResourceReferenceCountReadCount, 3);
  final transitionCount = imageMutationCount + 2;
  final queryEntryReads =
      work.count(SparseEditReferenceWorkKind.deltaEntryRead) -
      entryReadsBeforeQueries;
  _expectSparseReferenceWork(work, (
    transitions: transitionCount,
    resourceQueries: 3,
    maxDeltaEntryReads: transitionCount * 2 + 6,
    maxDeltaEntryMutations: transitionCount * 2,
  ));
  expect(queryEntryReads, lessThanOrEqualTo(6));
  expect(
    work.countFamilyResourceMutations(
      SparseEditReferenceFamily.image,
      missingResourceId,
    ),
    greaterThanOrEqualTo(1),
  );
  expect(
    work.countFamilyResourceMutations(
      SparseEditReferenceFamily.vector,
      CanvasResourceId('resource-2'),
    ),
    greaterThanOrEqualTo(1),
  );
  expect(
    work.countFamilyResourceMutations(
      SparseEditReferenceFamily.vector,
      CanvasResourceId('resource-3'),
    ),
    greaterThanOrEqualTo(1),
  );
  return queryEntryReads;
}

// Early and post-transition clear share one owner-attributed work witness.
// ignore: halstead-volume, source-lines-of-code, maintainability-index
void _expectSparseResourceClearWorkAtSupportedSize({
  required int priorImageMutationCount,
}) {
  const elementCount = 200000;
  const resourceCount = 4096;
  final facts = SupportedSizeSparseFacts(
    elementCount: elementCount,
    layerCount: 1,
    committedResourceCount: resourceCount,
  );
  final session = EditSession.sparse(
    facts: facts,
    promoteDraft: () => throw StateError('clear must stay sparse'),
    selectedElementIds: const [],
  );
  if (priorImageMutationCount > 0) {
    for (var index = 0; index < priorImageMutationCount; index += 1) {
      session.updateElement(
        CanvasImageElementUpdate(
          id: CanvasElementId('element-0'),
          resourceId: CanvasFieldSet(
            CanvasResourceId(index.isEven ? 'resource-1' : 'resource-0'),
          ),
        ),
      );
    }
    session.updateElement(
      CanvasVectorElementUpdate(
        id: CanvasElementId('element-1'),
        resourceId: CanvasFieldSet(CanvasResourceId('resource-3')),
      ),
    );
  }
  final work = _SparseReferenceWorkCounts();
  final clear = observeSparseEditReferenceWork(
    work.record,
    () => session.clearContent(removeUnusedResources: true),
  );

  expect(clear.removedElementIds, hasLength(elementCount));
  expect(clear.removedResourceIds, hasLength(resourceCount));
  expect(facts.elementIdsReadCount, 0);
  expect(facts.resourceIdsReadCount, 1);
  _expectSparseReferenceWork(work, (
    transitions: elementCount,
    resourceQueries: resourceCount,
    maxDeltaEntryReads: resourceCount * 2 + 2,
    maxDeltaEntryMutations: 2,
  ));
  final imageId = CanvasResourceId(
    priorImageMutationCount == 0 ? 'resource-0' : 'resource-1',
  );
  final vectorId = CanvasResourceId(
    priorImageMutationCount == 0 ? 'resource-2' : 'resource-3',
  );
  expect(
    work.countFamilyResourceMutations(SparseEditReferenceFamily.image, imageId),
    greaterThanOrEqualTo(1),
  );
  expect(
    work.countFamilyResourceMutations(
      SparseEditReferenceFamily.vector,
      vectorId,
    ),
    greaterThanOrEqualTo(1),
  );
}

void _expectSparseReferenceWork(
  _SparseReferenceWorkCounts work,
  ({
    int transitions,
    int resourceQueries,
    int maxDeltaEntryReads,
    int maxDeltaEntryMutations,
  })
  bounds,
) {
  expect(
    work.count(SparseEditReferenceWorkKind.transition),
    bounds.transitions,
  );
  expect(
    work.count(SparseEditReferenceWorkKind.deltaEntryRead),
    lessThanOrEqualTo(bounds.maxDeltaEntryReads),
  );
  expect(
    work.deltaEntryMutations,
    lessThanOrEqualTo(bounds.maxDeltaEntryMutations),
  );
  expect(work.count(SparseEditReferenceWorkKind.deltaEntryVisit), 0);
  expect(
    work.count(SparseEditReferenceWorkKind.resourceQuery),
    bounds.resourceQueries,
  );
  expect(
    work.count(SparseEditReferenceWorkKind.imageCommittedCountRead),
    bounds.resourceQueries,
  );
  expect(
    work.count(SparseEditReferenceWorkKind.vectorCommittedCountRead),
    bounds.resourceQueries,
  );
}

void _expectSparseResourceReferenceLifecycleWork() {
  final closeWork = _SparseReferenceWorkCounts();
  final closingSession = _sparseSessionWithPopulatedReferenceDeltas();
  observeSparseEditReferenceWork(closeWork.record, closingSession.close);
  _expectSparseReferenceDeltaExitWork(closeWork);

  final promotionWork = _SparseReferenceWorkCounts();
  final promotingSession = _sparseSessionWithPopulatedReferenceDeltas();
  final promoted = observeSparseEditReferenceWork(
    promotionWork.record,
    promotingSession.readDraftDocument,
  );
  final promotedElements = promoted.layers.single.elements;
  expect(
    (promotedElements[0] as CanvasImageElement).resourceId,
    CanvasResourceId('lifecycle-image-next'),
  );
  expect(
    (promotedElements[1] as CanvasVectorElement).resourceId,
    CanvasResourceId('lifecycle-vector-next'),
  );
  _expectSparseReferenceDeltaExitWork(promotionWork);
}

void _expectSparseReferenceDeltaExitWork(_SparseReferenceWorkCounts work) {
  expect(work.count(SparseEditReferenceWorkKind.deltaEntryClear), 2);
  expect(
    work.countFamily(
      SparseEditReferenceWorkKind.deltaEntryClear,
      SparseEditReferenceFamily.image,
    ),
    1,
  );
  expect(
    work.countFamily(
      SparseEditReferenceWorkKind.deltaEntryClear,
      SparseEditReferenceFamily.vector,
    ),
    1,
  );
  expect(work.count(SparseEditReferenceWorkKind.deltaEntryVisit), 0);
}

void _expectReferencedResourceRemovalNoOp() {
  final session = sparseSessionForDocument(_documentWithReferencedResource());

  expect(session.removeUnusedResource(CanvasResourceId('resource-a')), isFalse);
  expect(
    session.draftSummary,
    const CanvasDocumentSummary(
      elementCount: 1,
      layerCount: 1,
      resourceCount: 1,
    ),
  );
}

// Background resource identity, counts, touched facts, revisions, and clear
// preservation stay in one lifecycle; descriptor fidelity belongs to parity.
// ignore: halstead-volume, source-lines-of-code, maintainability-index
void _sparseClearRetainsBackgroundImageAndVectorResources() {
  var materializations = 0;
  final facts = SparseFixtureFacts(clearBackgroundResourcesDocument());
  final session = EditSession.sparse(
    facts: facts,
    promoteDraft: () {
      materializations += 1;

      return DraftDocument(clearBackgroundResourcesDocument());
    },
    selectedElementIds: [CanvasElementId('content-image')],
  );
  facts.resetReadCounters();

  final clear = session.clearContent(removeUnusedResources: true);

  expect(clear.didClearContent, isTrue);
  expect(clear.removedElementIds, [CanvasElementId('content-image')]);
  expect(clear.removedResourceIds, [
    CanvasResourceId('content-image-resource'),
    CanvasResourceId('unused-resource'),
    CanvasResourceId('unused-resource-a'),
    CanvasResourceId('unused-resource-b'),
    CanvasResourceId('unused-resource-c'),
    CanvasResourceId('unused-resource-d'),
  ]);
  expect(materializations, 0);
  expect(session.hasMaterializedDraft, isFalse);
  expect(
    session.draftSummary,
    const CanvasDocumentSummary(
      elementCount: 2,
      layerCount: 1,
      resourceCount: 2,
    ),
  );
  expect(session.touchedSet.removedElementIds, {
    CanvasElementId('content-image'),
  });
  expect(session.touchedSet.resourceDescriptorChangedIds, {
    CanvasResourceId('content-image-resource'),
    CanvasResourceId('unused-resource'),
    CanvasResourceId('unused-resource-a'),
    CanvasResourceId('unused-resource-b'),
    CanvasResourceId('unused-resource-c'),
    CanvasResourceId('unused-resource-d'),
  });
  expect(session.touchedSet.selection, isTrue);
  expect(session.touchedSet.backgroundLayerChanged, isFalse);
  expect(session.touchedSet.background, isFalse);
  expect(session.touchedSet.grid, isFalse);
  expect(session.revisionDelta.structural, isTrue);
  expect(session.revisionDelta.resource, isTrue);
  expect(session.revisionDelta.background, isFalse);
  expect(session.revisionDelta.grid, isFalse);
  expect(facts.resourceIdsReadCount, 1);
  expect(facts.elementIdsReadCount, 0);

  final document = session.readDraftDocument();

  expect(materializations, 1);
  expect(document.backgroundElements.map((element) => element.id), [
    CanvasElementId('background-image'),
    CanvasElementId('background-vector'),
  ]);
  expect(document.resources.map((resource) => resource.id), [
    CanvasResourceId('background-image-resource'),
    CanvasResourceId('background-vector-resource'),
  ]);
}

// This keeps committed and local sparse facts in one lifecycle: local elements
// are admitted before their resources so the real reference policy need not
// fall back to committed full-frame facts while preparing the clear candidate.
// Keeping the exact lifecycle assertions together is clearer than splitting
// their shared fact-port budget and retained-state proof across helpers.
// ignore: halstead-volume, source-lines-of-code, maintainability-index
void _sparseClearRetainsCommittedAndLocalBackgroundResources() {
  var materializations = 0;
  final seed = _documentWithCommittedAndLocalClearResources();
  final facts = SparseFixtureFacts(seed);
  final session = EditSession.sparse(
    facts: facts,
    promoteDraft: () {
      materializations += 1;

      return DraftDocument(seed);
    },
    selectedElementIds: const [],
  );

  session.addBackgroundElement(
    CanvasImageElement(
      id: CanvasElementId('local-background-image'),
      resourceId: CanvasResourceId('local-background-image-resource'),
      size: const Size(31, 37),
      naturalSize: const Size(62, 74),
      revision: 7,
      isDeletable: false,
    ),
  );
  expect(
    session.upsertResource(
      CanvasImageResource(
        id: CanvasResourceId('local-background-image-resource'),
        source: CanvasResourceSource.appKey('local-background-image-source'),
        mimeType: 'image/jpeg',
        contentHash: 'local-background-image-hash',
        byteLength: 303,
      ),
    ),
    isTrue,
  );
  session.addBackgroundElement(
    CanvasVectorElement(
      id: CanvasElementId('local-background-vector'),
      resourceId: CanvasResourceId('local-background-vector-resource'),
      size: const Size(41, 43),
      naturalSize: const Size(82, 86),
      revision: 8,
      isDeletable: false,
    ),
  );
  expect(
    session.upsertResource(
      CanvasVectorResource(
        id: CanvasResourceId('local-background-vector-resource'),
        source: CanvasResourceSource.appKey('local-background-vector-source'),
        contentHash: 'local-background-vector-hash',
        byteLength: 404,
      ),
    ),
    isTrue,
  );
  session.addElement(
    CanvasImageElement(
      id: CanvasElementId('local-content-image'),
      resourceId: CanvasResourceId('local-content-image-resource'),
      size: const Size(47, 53),
      isDeletable: false,
    ),
  );
  expect(
    session.upsertResource(
      CanvasImageResource(
        id: CanvasResourceId('local-content-image-resource'),
        source: CanvasResourceSource.appKey('local-content-image-source'),
      ),
    ),
    isTrue,
  );
  session.addElement(
    CanvasVectorElement(
      id: CanvasElementId('local-unused-reference'),
      resourceId: CanvasResourceId('local-unused-vector-resource'),
      size: const Size(59, 61),
    ),
  );
  expect(
    session.upsertResource(
      CanvasVectorResource(
        id: CanvasResourceId('local-unused-vector-resource'),
        source: CanvasResourceSource.appKey('local-unused-vector-source'),
      ),
    ),
    isTrue,
  );
  expect(
    session.removeElement(CanvasElementId('local-unused-reference')),
    isTrue,
  );

  final backgroundReadsBeforeClear = facts.backgroundElementIdsReadCount;
  final resourceReadsBeforeClear = facts.resourceIdsReadCount;
  final elementIdsReadsBeforeClear = facts.elementIdsReadCount;

  final clear = session.clearContent(removeUnusedResources: true);

  expect(clear.didClearContent, isTrue);
  expect(clear.removedElementIds, [
    CanvasElementId('committed-content-image'),
    CanvasElementId('local-content-image'),
  ]);
  expect(clear.removedResourceIds, [
    CanvasResourceId('committed-content-image-resource'),
    CanvasResourceId('committed-unused-vector-resource'),
    CanvasResourceId('local-content-image-resource'),
    CanvasResourceId('local-unused-vector-resource'),
  ]);
  expect(materializations, 0);
  expect(session.hasMaterializedDraft, isFalse);
  expect(facts.backgroundElementIdsReadCount, backgroundReadsBeforeClear);
  expect(facts.resourceIdsReadCount - resourceReadsBeforeClear, 1);
  expect(facts.elementIdsReadCount - elementIdsReadsBeforeClear, 0);
  expect(facts.resourceIdsReadCount, 1);
  expect(facts.elementIdsReadCount, 0);

  final document = session.readDraftDocument();

  expect(materializations, 1);
  expect(document.backgroundElements.map((element) => element.id), [
    CanvasElementId('committed-background-image'),
    CanvasElementId('committed-background-vector'),
    CanvasElementId('local-background-image'),
    CanvasElementId('local-background-vector'),
  ]);
  expect(document.backgroundElements.map((element) => element.kind), [
    CanvasElementKind.image,
    CanvasElementKind.vector,
    CanvasElementKind.image,
    CanvasElementKind.vector,
  ]);
  final committedImage =
      document.backgroundElements.first as CanvasImageElement;
  final committedVector = document.backgroundElements[1] as CanvasVectorElement;
  final localImage = document.backgroundElements[2] as CanvasImageElement;
  final localVector = document.backgroundElements[3] as CanvasVectorElement;
  expect(
    committedImage.resourceId,
    CanvasResourceId('committed-background-image-resource'),
  );
  expect(
    committedVector.resourceId,
    CanvasResourceId('committed-background-vector-resource'),
  );
  expect(
    localImage.resourceId,
    CanvasResourceId('local-background-image-resource'),
  );
  expect(localImage.size, const Size(31, 37));
  expect(localImage.naturalSize, const Size(62, 74));
  expect(localImage.revision, 7);
  expect(
    localVector.resourceId,
    CanvasResourceId('local-background-vector-resource'),
  );
  expect(localVector.size, const Size(41, 43));
  expect(localVector.naturalSize, const Size(82, 86));
  expect(localVector.revision, 8);
  expect(document.layers.single.elements, isEmpty);
  expect(document.resources.map((resource) => resource.id), [
    CanvasResourceId('committed-background-image-resource'),
    CanvasResourceId('committed-background-vector-resource'),
    CanvasResourceId('local-background-image-resource'),
    CanvasResourceId('local-background-vector-resource'),
  ]);
  expect(document.resources.map((resource) => resource.runtimeType), [
    CanvasImageResource,
    CanvasVectorResource,
    CanvasImageResource,
    CanvasVectorResource,
  ]);
  final committedImageResource =
      document.resources.first as CanvasImageResource;
  final committedVectorResource = document.resources[1] as CanvasVectorResource;
  expect(
    committedImageResource.source,
    CanvasResourceSource.appKey('committed-background-image-source'),
  );
  expect(
    committedVectorResource.source,
    CanvasResourceSource.appKey('committed-background-vector-source'),
  );
  final localImageResource = document.resources[2] as CanvasImageResource;
  final localVectorResource = document.resources[3] as CanvasVectorResource;
  expect(
    localImageResource.source,
    CanvasResourceSource.appKey('local-background-image-source'),
  );
  expect(localImageResource.mimeType, 'image/jpeg');
  expect(localImageResource.contentHash, 'local-background-image-hash');
  expect(localImageResource.byteLength, 303);
  expect(
    localVectorResource.source,
    CanvasResourceSource.appKey('local-background-vector-source'),
  );
  expect(localVectorResource.contentHash, 'local-background-vector-hash');
  expect(localVectorResource.byteLength, 404);
}

// The promotion and clear observations form one owner-attributed lifecycle.
// ignore: halstead-volume
void _promotedSparseClearKeepsDraftResourceWorkBounded() {
  var materializations = 0;
  final session = sparseSessionForDocument(
    clearBackgroundResourcesDocument(),
    promoteDraft: () {
      materializations += 1;

      return DraftDocument(clearBackgroundResourcesDocument());
    },
  );

  session.readDraftDocument();
  final work = <DraftResourceWorkEvent>[];
  final clear = observeDraftResourceWork(
    work.add,
    () => session.clearContent(removeUnusedResources: true),
  );

  expect(materializations, 1);
  expect(clear.removedElementIds, [CanvasElementId('content-image')]);
  expect(clear.removedResourceIds, [
    CanvasResourceId('content-image-resource'),
    CanvasResourceId('unused-resource'),
    CanvasResourceId('unused-resource-a'),
    CanvasResourceId('unused-resource-b'),
    CanvasResourceId('unused-resource-c'),
    CanvasResourceId('unused-resource-d'),
  ]);
  expect(
    draftResourceWorkCount(work, DraftResourceWorkKind.imageCountTransition),
    1,
  );
  expect(
    draftResourceWorkCount(work, DraftResourceWorkKind.vectorCountTransition),
    0,
  );
  expect(draftResourceWorkCount(work, DraftResourceWorkKind.referenceQuery), 8);
  expect(
    draftResourceWorkCount(work, DraftResourceWorkKind.descriptorRemove),
    6,
  );
}

// The fixture seed declares one literal committed frame so expected local versus
// committed retention facts stay visible without a test-owned inventory.
// ignore: halstead-volume, source-lines-of-code
CanvasDocument _documentWithCommittedAndLocalClearResources() {
  return CanvasDocument(
    resources: [
      CanvasImageResource(
        id: CanvasResourceId('committed-background-image-resource'),
        source: CanvasResourceSource.appKey(
          'committed-background-image-source',
        ),
        mimeType: 'image/png',
        contentHash: 'committed-background-image-hash',
        byteLength: 101,
      ),
      CanvasVectorResource(
        id: CanvasResourceId('committed-background-vector-resource'),
        source: CanvasResourceSource.appKey(
          'committed-background-vector-source',
        ),
        contentHash: 'committed-background-vector-hash',
        byteLength: 202,
      ),
      CanvasImageResource(
        id: CanvasResourceId('committed-content-image-resource'),
        source: CanvasResourceSource.appKey('committed-content-image-source'),
      ),
      CanvasVectorResource(
        id: CanvasResourceId('committed-unused-vector-resource'),
        source: CanvasResourceSource.appKey('committed-unused-vector-source'),
      ),
    ],
    backgroundElements: [
      CanvasImageElement(
        id: CanvasElementId('committed-background-image'),
        resourceId: CanvasResourceId('committed-background-image-resource'),
        size: const Size(11, 13),
        naturalSize: const Size(22, 26),
        revision: 3,
      ),
      CanvasVectorElement(
        id: CanvasElementId('committed-background-vector'),
        resourceId: CanvasResourceId('committed-background-vector-resource'),
        size: const Size(17, 19),
        naturalSize: const Size(34, 38),
        revision: 4,
      ),
    ],
    layers: [
      CanvasLayer(
        id: CanvasLayerId('committed-content-layer'),
        elements: [
          CanvasImageElement(
            id: CanvasElementId('committed-content-image'),
            resourceId: CanvasResourceId('committed-content-image-resource'),
            size: const Size(23, 29),
            isDeletable: false,
          ),
        ],
      ),
    ],
  );
}

void _sparseRemoveTouchesBackgroundLayerOnlyForBackgroundRemovals() {
  final contentRemove = sparseSessionForDocument(baseSparseDocument());
  expect(contentRemove.removeElement(CanvasElementId('content-a')), isTrue);
  expect(contentRemove.commitPlan.touchedSet.backgroundLayerChanged, isFalse);

  final backgroundRemove = sparseSessionForDocument(baseSparseDocument());
  expect(
    backgroundRemove.removeElement(CanvasElementId('background-a')),
    isTrue,
  );
  expect(backgroundRemove.commitPlan.touchedSet.backgroundLayerChanged, isTrue);
}

void _sparseRemoveAndReaddUsesCurrentPlacementBeforeClear() {
  final session = sparseSessionForDocument(baseSparseDocument());
  final contentId = CanvasElementId('content-a');

  expect(session.removeElement(contentId), isTrue);
  session.addBackgroundElement(sparseRect('content-a'), index: 0);

  final clear = session.clearContent();

  expect(clear.removedElementIds, isEmpty);
  expect(
    session.readDraftDocument().backgroundElements.map((element) => element.id),
    [contentId, CanvasElementId('background-a')],
  );
}

// The expected result is a literal sequential oracle: after the moved row is
// cleared, neither it nor its only descriptor can remain in current state.
void _sparseBackgroundToContentMoveReleasesResourceDuringClear() {
  final elementId = CanvasElementId('background-image');
  final resourceId = CanvasResourceId('background-image-resource');
  final session = sparseSessionForDocument(
    _documentWithSingleBackgroundImageResource(),
  );

  expect(session.removeElement(elementId), isTrue);
  session.addElement(
    CanvasImageElement(
      id: elementId,
      resourceId: resourceId,
      size: const Size(4, 6),
    ),
    layerId: CanvasLayerId('layer-a'),
  );

  final clear = session.clearContent(removeUnusedResources: true);

  expect(clear.removedElementIds, [elementId]);
  expect(clear.removedResourceIds, [resourceId]);
  final document = session.readDraftDocument();
  expect(document.backgroundElements, isEmpty);
  expect(document.layers.single.elements, isEmpty);
  expect(document.resources, isEmpty);
}

CanvasDocument _documentWithSingleBackgroundImageResource() {
  return CanvasDocument(
    resources: [
      CanvasImageResource(
        id: CanvasResourceId('background-image-resource'),
        source: CanvasResourceSource.appKey('background-image-source'),
      ),
    ],
    backgroundElements: [
      CanvasImageElement(
        id: CanvasElementId('background-image'),
        resourceId: CanvasResourceId('background-image-resource'),
        size: const Size(4, 6),
      ),
    ],
    layers: [CanvasLayer(id: CanvasLayerId('layer-a'))],
  );
}
