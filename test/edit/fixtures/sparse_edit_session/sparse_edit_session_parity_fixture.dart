import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine/src/edit/draft_document.dart';
import 'package:iwb_canvas_engine/src/edit/edit_session.dart';
import 'package:iwb_canvas_engine/src/store/sparse_store_commit.dart';
import 'package:iwb_canvas_engine/src/store/store_revision_delta.dart';

import 'sparse_edit_session_support.dart';
import 'sparse_edit_session_store_support.dart';

void registerSparseEditSessionParityTests() {
  test(
    'sparse clear remains an ordered journal barrier',
    () => expect(_sparseClearRemainsAnOrderedJournalBarrier, returnsNormally),
  );
  test(
    'sparse, materialized Draft, and direct Store resource traces have parity',
    () => expect(_sparseResourceTracesHaveThreePathParity, returnsNormally),
  );
}

// Regression: evaluating removeUnusedResource against a final clear state
// rather than its journal position would make one of these paired traces
// retain or release the ordinary-content descriptor incorrectly; the paired trace is one witness.
// ignore: halstead-volume, source-lines-of-code, maintainability-index
void _expectRemoveUnusedResourceBarrierThroughSparseSession() {
  final resourceId = CanvasResourceId('content-image-resource');
  final removeBeforeClear = _runSparseClearTrace([
    _ClearTraceAction.removeUnusedResource(resourceId),
    const _ClearTraceAction.clearContent(removeUnusedResources: false),
  ]);
  final clearBeforeRemove = _runSparseClearTrace([
    const _ClearTraceAction.clearContent(removeUnusedResources: false),
    _ClearTraceAction.removeUnusedResource(resourceId),
  ]);

  _expectSparseClearTraceMatchesOracle(removeBeforeClear);
  _expectSparseClearTraceMatchesOracle(clearBeforeRemove);
  _expectSparseCommitInstallsTrace(removeBeforeClear);
  _expectSparseCommitInstallsTrace(clearBeforeRemove);

  expect(removeBeforeClear.actualResults[0].changed, isFalse);
  expect(removeBeforeClear.sparseCommit.mutations, hasLength(1));
  expect(
    removeBeforeClear.sparseCommit.mutations.single,
    isA<StoreSparseClearContent>(),
  );
  final retainedClear = removeBeforeClear.actualResults[1].clearResult;
  expect(retainedClear?.didClearContent, isTrue);
  expect(retainedClear?.removedElementIds, [CanvasElementId('content-image')]);
  expect(retainedClear?.removedResourceIds, isEmpty);
  expect(removeBeforeClear.document.resources.map((resource) => resource.id), [
    CanvasResourceId('background-image-resource'),
    CanvasResourceId('background-vector-resource'),
    resourceId,
  ]);
  expect(removeBeforeClear.session.touchedSet.removedElementIds, {
    CanvasElementId('content-image'),
  });
  expect(
    removeBeforeClear.session.touchedSet.resourceDescriptorChangedIds,
    isEmpty,
  );
  expect(removeBeforeClear.session.revisionDelta.structural, isTrue);
  expect(removeBeforeClear.session.revisionDelta.resource, isFalse);

  final removedClear = clearBeforeRemove.actualResults[0].clearResult;
  expect(removedClear?.didClearContent, isTrue);
  expect(removedClear?.removedElementIds, [CanvasElementId('content-image')]);
  expect(removedClear?.removedResourceIds, isEmpty);
  expect(clearBeforeRemove.actualResults[1].changed, isTrue);
  expect(clearBeforeRemove.sparseCommit.mutations, hasLength(2));
  expect(
    clearBeforeRemove.sparseCommit.mutations.first,
    isA<StoreSparseClearContent>(),
  );
  expect(
    clearBeforeRemove.sparseCommit.mutations.last,
    isA<StoreSparseRemoveUnusedResource>().having(
      (mutation) => mutation.id,
      'resource id',
      resourceId,
    ),
  );
  expect(clearBeforeRemove.document.resources.map((resource) => resource.id), [
    CanvasResourceId('background-image-resource'),
    CanvasResourceId('background-vector-resource'),
  ]);
  expect(clearBeforeRemove.session.touchedSet.removedElementIds, {
    CanvasElementId('content-image'),
  });
  expect(clearBeforeRemove.session.touchedSet.resourceDescriptorChangedIds, {
    resourceId,
  });
  expect(clearBeforeRemove.session.revisionDelta.structural, isTrue);
  expect(clearBeforeRemove.session.revisionDelta.resource, isTrue);
}

void _expectSparseCommitInstallsTrace(
  _SparseClearTraceOutcome outcome, {
  String? reason,
  bool verifyCallbackCommit = false,
}) {
  _expectStoreTraceAgainstOracle(outcome.directCommit, outcome, reason: reason);
  if (!verifyCallbackCommit) {
    return;
  }
  _expectStoreTraceAgainstOracle(
    outcome.sparseCommit,
    outcome,
    reason: '$reason callback sparse commit',
  );
}

// Direct Store preparation, accepted facts, revisions, and installed views are
// one atomic oracle; splitting them would hide a cross-phase parity gap.
// ignore: cyclomatic-complexity, halstead-volume, source-lines-of-code, maintainability-index
void _expectStoreTraceAgainstOracle(
  StoreSparseCommit commit,
  _SparseClearTraceOutcome outcome, {
  String? reason,
}) {
  final store = sparseTraceDocumentStore(
    clearBackgroundResourcesDocument(includeUnusedResource: false),
  );
  expect(store.projectionBuildCount, 0, reason: reason);
  final prepared = store.prepareSparseCommit(commit);

  expect(
    prepared.hasChanges,
    outcome.expectedEffects.structural || outcome.expectedEffects.resource,
    reason: reason,
  );
  expect(
    prepared.touchedFacts.addedElementIds,
    outcome.acceptedStoreAddedElementIds,
    reason: '$reason accepted Store added touched ids',
  );
  expect(
    prepared.touchedFacts.removedElementIds,
    outcome.acceptedStoreRemovedElementIds,
    reason: '$reason accepted Store removed touched ids',
  );
  expect(prepared.touchedFacts.updatedElementIds, isEmpty, reason: reason);
  expect(prepared.touchedFacts.transformedElementIds, isEmpty, reason: reason);
  expect(prepared.touchedFacts.geometryElementIds, isEmpty, reason: reason);
  expect(prepared.touchedFacts.visualElementIds, isEmpty, reason: reason);
  expect(
    prepared.touchedFacts.selectionPruneElementIds,
    outcome.acceptedStoreRemovedElementIds,
    reason: '$reason accepted Store selection-prune ids',
  );
  expect(
    prepared.touchedFacts.resourceDescriptorChangedIds,
    outcome.acceptedStoreResourceDescriptorChangedIds,
    reason: '$reason accepted Store descriptor touched ids',
  );
  expect(
    prepared.touchedFacts.resourceVisualChangedIds,
    outcome.acceptedStoreResourceVisualChangedIds,
    reason: '$reason accepted Store resource visual touched ids',
  );
  expect(
    prepared.touchedFacts.layerIds,
    outcome.expectedEffects.structural
        ? {CanvasLayerId('layer-a')}
        : <CanvasLayerId>{},
  );
  expect(prepared.touchedFacts.backgroundLayerChanged, isFalse);
  expect(prepared.touchedFacts.persistedCamera, isFalse);
  expect(prepared.touchedFacts.background, isFalse);
  expect(prepared.touchedFacts.grid, isFalse);
  expect(prepared.touchedFacts.palette, isFalse);
  expect(
    prepared.revisionDelta.document,
    outcome.expectedEffects.structural || outcome.expectedEffects.resource,
  );
  expect(
    prepared.revisionDelta.projection,
    outcome.expectedEffects.structural || outcome.expectedEffects.resource,
  );
  expect(prepared.revisionDelta.structural, outcome.expectedEffects.structural);
  expect(prepared.revisionDelta.bounds, outcome.expectedEffects.structural);
  expect(prepared.revisionDelta.resource, outcome.expectedEffects.resource);
  expect(
    prepared.revisionDelta.elementVisual,
    outcome.expectedEffects.structural || outcome.expectedEffects.elementVisual,
  );
  expect(prepared.revisionDelta.background, isFalse);
  expect(prepared.revisionDelta.grid, isFalse);

  store.installSparseCommit(prepared);
  expect(store.projectionBuildCount, 0, reason: reason);

  expect(
    store.backgroundElementIds,
    outcome.expectedDocument.backgroundElements.map((element) => element.id),
  );
  _expectTraceElements([
    for (final id in store.backgroundElementIds)
      _requireInstalledTraceElement(store.elementById(id), id),
  ], outcome.expectedDocument.backgroundElements);
  expect(
    store.elementIdsInLayer(CanvasLayerId('layer-a')),
    outcome.expectedDocument.layers.single.elements.map(
      (element) => element.id,
    ),
  );
  _expectTraceElements([
    for (final id in store.elementIdsInLayer(CanvasLayerId('layer-a')))
      _requireInstalledTraceElement(store.elementById(id), id),
  ], outcome.expectedDocument.layers.single.elements);
  expect(
    store.resourceIds,
    outcome.expectedDocument.resources.map((resource) => resource.id),
  );
  for (final resource in outcome.expectedDocument.resources) {
    expectInstalledSparseTraceDescriptor(
      store.resourceDescriptor(resource.id),
      resource,
      expectedResourceRevision:
          outcome.acceptedStoreResourceDescriptorChangedIds.contains(
            resource.id,
          )
          ? store.resourceRevision
          : store.resourceRevision - (prepared.revisionDelta.resource ? 1 : 0),
    );
  }
}

// Image/vector descriptor matching is one sealed installed-view contract.
// ignore: halstead-volume
CanvasElement _requireInstalledTraceElement(
  CanvasElement? element,
  CanvasElementId id,
) {
  if (element == null) {
    fail('installed trace element is absent for $id.');
  }
  return element;
}

// Paired ordered traces and their commit observations form one barrier witness.
// ignore: halstead-volume, source-lines-of-code, maintainability-index
void _sparseClearRemainsAnOrderedJournalBarrier() {
  _expectRemoveUnusedResourceBarrierThroughSparseSession();

  final beforeClearTrace = [
    _ClearTraceAction.upsertResource(
      sparseImageResource('content-image-resource'),
    ),
    _ClearTraceAction.upsertResource(
      CanvasImageResource(
        id: CanvasResourceId('content-image-resource'),
        source: CanvasResourceSource.appKey('replacement-content-image'),
      ),
    ),
    _ClearTraceAction.upsertResource(
      sparseImageResource('resource-before-clear'),
    ),
    _ClearTraceAction.addElement(
      CanvasImageElement(
        id: CanvasElementId('content-before-clear'),
        resourceId: CanvasResourceId('resource-before-clear'),
        size: const Size(8, 9),
        isDeletable: false,
      ),
    ),
    _ClearTraceAction.addElement(
      CanvasImageElement(
        id: CanvasElementId('missing-before-clear'),
        resourceId: CanvasResourceId('missing-resource-before-clear'),
        size: const Size(3, 4),
      ),
    ),
    _ClearTraceAction.removeElement(CanvasElementId('missing-before-clear')),
    _ClearTraceAction.addElement(
      CanvasImageElement(
        id: CanvasElementId('missing-before-clear'),
        resourceId: CanvasResourceId('missing-resource-before-clear'),
        size: const Size(3, 4),
      ),
    ),
    _ClearTraceAction.upsertResource(
      sparseImageResource('missing-resource-before-clear'),
    ),
    const _ClearTraceAction.clearContent(removeUnusedResources: false),
    _ClearTraceAction.removeUnusedResource(
      CanvasResourceId('content-image-resource'),
    ),
    const _ClearTraceAction.clearContent(removeUnusedResources: true),
    _ClearTraceAction.removeUnusedResource(
      CanvasResourceId('resource-before-clear'),
    ),
  ];
  final afterClearTrace = [
    const _ClearTraceAction.clearContent(removeUnusedResources: false),
    _ClearTraceAction.removeUnusedResource(
      CanvasResourceId('content-image-resource'),
    ),
    const _ClearTraceAction.clearContent(removeUnusedResources: true),
    _ClearTraceAction.upsertResource(
      sparseImageResource('resource-after-clear'),
    ),
    _ClearTraceAction.addElement(
      CanvasImageElement(
        id: CanvasElementId('content-after-clear'),
        resourceId: CanvasResourceId('resource-after-clear'),
        size: const Size(10, 11),
        isDeletable: false,
      ),
    ),
  ];

  final beforeClear = _runSparseClearTrace(beforeClearTrace);
  final afterClear = _runSparseClearTrace(afterClearTrace);

  _expectSparseClearTraceMatchesOracle(beforeClear);
  _expectSparseClearTraceMatchesOracle(afterClear);
  _expectSparseClearTracePrefixes(beforeClearTrace);
  _expectSparseClearTracePrefixes(afterClearTrace);
  expect(beforeClear.document.layers.single.elements, isEmpty);
  expect(
    afterClear.document.layers.single.elements.map((element) => element.id),
    [CanvasElementId('content-after-clear')],
  );
  expect(beforeClear.document.resources.map((resource) => resource.id), [
    CanvasResourceId('background-image-resource'),
    CanvasResourceId('background-vector-resource'),
  ]);
  expect(afterClear.document.resources.map((resource) => resource.id), [
    CanvasResourceId('background-image-resource'),
    CanvasResourceId('background-vector-resource'),
    CanvasResourceId('resource-after-clear'),
  ]);
  for (final outcome in [beforeClear, afterClear]) {
    expect(outcome.document.backgroundElements.map((element) => element.id), [
      CanvasElementId('background-image'),
      CanvasElementId('background-vector'),
    ]);
  }
}

void _sparseResourceTracesHaveThreePathParity() {
  _expectSeededTracePrefixes();
  _expectDeferredRelationshipDiagnostics();
  _expectPromotionBoundaryTraceParity();
}

// A fixed LCG keeps the action trace reproducible. Every prefix is a shrink
// witness: a future failure reports the one seed and shortest failing prefix.
void _expectSeededTracePrefixes() {
  const seed = 7331;
  final trace = _seededTrace(seed);
  for (var length = 1; length <= trace.length; length += 1) {
    final reason = 'seed=$seed prefix=$length';
    try {
      final outcome = _runSparseClearTrace(trace.take(length).toList());
      _expectSparseClearTraceMatchesOracle(outcome, reason: reason);
      _expectSparseCommitInstallsTrace(
        outcome,
        reason: reason,
        verifyCallbackCommit: true,
      );
    } on TestFailure catch (error) {
      fail('$reason: $error');
    }
  }
}

void _expectPromotionBoundaryTraceParity() {
  final trace = [
    ..._seededTrace(7331),
    _ClearTraceAction.upsertResource(
      sparseImageResource('after-promotion-resource'),
    ),
    _ClearTraceAction.addElement(
      CanvasImageElement(
        id: CanvasElementId('after-promotion-image'),
        resourceId: CanvasResourceId('after-promotion-resource'),
        size: const Size(1, 1),
      ),
    ),
  ];
  final clearIndexes = [
    for (var index = 0; index < trace.length; index += 1)
      if (trace[index].kind == _ClearTraceActionKind.clearContent) index,
  ];
  for (final boundary in [clearIndexes.first, clearIndexes.last + 1]) {
    final outcome = _runSparseClearTrace(trace, promoteBeforeAction: boundary);
    final reason = 'promotion before action $boundary';
    try {
      _expectSparseClearTraceMatchesOracle(outcome, reason: reason);
      _expectSparseCommitInstallsTrace(outcome, reason: reason);
    } on TestFailure catch (error) {
      fail('$reason: $error');
    }
  }
}

// A seeded trace must remain one deterministic, shrinkable action sequence.
// ignore: halstead-volume
List<_ClearTraceAction> _seededTrace(int seed) {
  var state = seed;
  int nextIndex() {
    state = (state * 1103515245 + 12345) & 0x7fffffff;
    return (state % 9) - 4;
  }

  final resourceId = CanvasResourceId('seed-image-resource');
  final nextResourceId = CanvasResourceId('seed-image-next');
  final first = CanvasImageElement(
    id: CanvasElementId('seed-image-a'),
    resourceId: resourceId,
    size: const Size(1, 1),
  );
  final second = CanvasImageElement(
    id: CanvasElementId('seed-image-b'),
    resourceId: nextResourceId,
    size: const Size(1, 1),
  );
  final updated = CanvasImageElement(
    id: first.id,
    resourceId: nextResourceId,
    size: first.size,
    revision: first.revision + 1,
  );
  final nextDescriptor = sparseImageResource(nextResourceId.value);
  return [
    _ClearTraceAction.upsertResource(sparseImageResource(resourceId.value)),
    _ClearTraceAction.addElement(first, index: nextIndex()),
    _ClearTraceAction.upsertResource(nextDescriptor),
    _ClearTraceAction.updateImageResource(before: first, after: updated),
    _ClearTraceAction.addElement(second, index: nextIndex()),
    _ClearTraceAction.removeElement(first.id),
    _ClearTraceAction.addElement(first, index: nextIndex()),
    _ClearTraceAction.upsertResource(nextDescriptor),
    const _ClearTraceAction.clearContent(removeUnusedResources: false),
    _ClearTraceAction.removeUnusedResource(resourceId),
    const _ClearTraceAction.clearContent(removeUnusedResources: true),
  ];
}

void _expectDeferredRelationshipDiagnostics() {
  final missing = _runSparseClearTrace([
    _ClearTraceAction.addElement(
      CanvasImageElement(
        id: CanvasElementId('missing-trace-image'),
        resourceId: CanvasResourceId('missing-trace-resource'),
        size: const Size(1, 1),
      ),
    ),
  ]);
  _expectDirectTraceFailure(missing, (
    code: CanvasDataErrorCode.missingResourceReference,
    message: 'resource element references a missing resource.',
    path: 'image.resourceId',
  ));
  final wrongKind = _runSparseClearTrace([
    _ClearTraceAction.upsertResource(
      CanvasVectorResource(
        id: CanvasResourceId('wrong-kind-trace-resource'),
        source: CanvasResourceSource.appKey('wrong-kind-trace-resource'),
      ),
    ),
    _ClearTraceAction.addElement(
      CanvasImageElement(
        id: CanvasElementId('wrong-kind-trace-image'),
        resourceId: CanvasResourceId('wrong-kind-trace-resource'),
        size: const Size(1, 1),
      ),
    ),
  ]);
  _expectDirectTraceFailure(wrongKind, (
    code: CanvasDataErrorCode.resourceKindMismatch,
    message: 'resource kind does not match the referencing element.',
    path: 'image.resourceId',
  ));
}

void _expectDirectTraceFailure(
  _SparseClearTraceOutcome outcome,
  ({CanvasDataErrorCode code, String message, String path}) expected,
) {
  final store = sparseTraceDocumentStore(
    clearBackgroundResourcesDocument(includeUnusedResource: false),
  );
  expect(
    () => store.prepareSparseCommit(outcome.directCommit),
    throwsA(
      isA<CanvasDataException>()
          .having((error) => error.code, 'code', expected.code)
          .having((error) => error.message, 'message', expected.message)
          .having((error) => error.path, 'path', expected.path),
    ),
  );
}

void _expectSparseClearTracePrefixes(List<_ClearTraceAction> trace) {
  for (var length = 1; length <= trace.length; length += 1) {
    _expectSparseClearTraceMatchesOracle(
      _runSparseClearTrace(trace.take(length).toList()),
    );
  }
}

// Capturing immediate sparse facts next to promotion keeps both phases tied to
// the same sequential trace; splitting it would hide their order relationship.
// ignore: halstead-volume, source-lines-of-code, maintainability-index
_SparseClearTraceOutcome _runSparseClearTrace(
  List<_ClearTraceAction> trace, {
  int? promoteBeforeAction,
}) {
  final seed = clearBackgroundResourcesDocument(includeUnusedResource: false);
  final oracle = _ClearSequentialOracle(
    seed,
    selectedElementIds: {CanvasElementId('content-image')},
  );
  final session = EditSession.sparse(
    facts: SparseFixtureFacts(seed),
    promoteDraft: () => DraftDocument(
      seed,
      selectedElementIds: [CanvasElementId('content-image')],
    ),
    selectedElementIds: [CanvasElementId('content-image')],
  );
  final materialized = DraftDocument(
    seed,
    selectedElementIds: [CanvasElementId('content-image')],
  );
  final actualResults = <_ClearTraceResult>[];
  final materializedResults = <_ClearTraceResult>[];
  final expectedResults = <_ClearTraceResult>[];
  final directMutations = <StoreSparseMutation>[];
  StoreSparseCommit? sparseCommit;

  for (var index = 0; index < trace.length; index += 1) {
    if (index == promoteBeforeAction) {
      sparseCommit = session.sparseCommit;
      session.readDraftDocument();
    }
    final action = trace[index];
    actualResults.add(action.applyToSession(session));
    materializedResults.add(action.applyToDraft(materialized));
    final expected = action.applyToOracle(oracle);
    expectedResults.add(expected);
    final direct = action.storeMutationFor(expected);
    if (direct != null) {
      directMutations.add(direct);
    }
  }
  sparseCommit ??= session.sparseCommit;
  final sparseTouchedSet = (
    addedElementIds: session.touchedSet.addedElementIds,
    removedElementIds: session.touchedSet.removedElementIds,
    resourceDescriptorChangedIds:
        session.touchedSet.resourceDescriptorChangedIds,
    selection: session.touchedSet.selection,
    backgroundLayerChanged: session.touchedSet.backgroundLayerChanged,
    background: session.touchedSet.background,
    grid: session.touchedSet.grid,
  );
  final sparseRevisionDelta = (
    structural: session.revisionDelta.structural,
    resource: session.revisionDelta.resource,
    background: session.revisionDelta.background,
    grid: session.revisionDelta.grid,
  );

  return _SparseClearTraceOutcome(
    actualResults: actualResults,
    materializedResults: materializedResults,
    expectedResults: expectedResults,
    sparseCommit: sparseCommit,
    directCommit: StoreSparseCommit(
      mutations: directMutations,
      revisionDelta: _directTraceRevisionDelta(oracle.effects),
    ),
    document: session.readDraftDocument(),
    materializedDocument: materialized.readDocument(),
    expectedDocument: oracle.toDocument(),
    session: session,
    sparseTouchedSet: sparseTouchedSet,
    materializedTouchedSet: (
      addedElementIds: materialized.touchedSet.addedElementIds,
      removedElementIds: materialized.touchedSet.removedElementIds,
      resourceDescriptorChangedIds:
          materialized.touchedSet.resourceDescriptorChangedIds,
      selection: materialized.touchedSet.selection,
    ),
    sparseRevisionDelta: sparseRevisionDelta,
    materializedRevisionDelta: (
      structural: materialized.revisionDelta.structural,
      resource: materialized.revisionDelta.resource,
    ),
    acceptedStoreAddedElementIds: oracle.acceptedStoreAddedElementIds,
    acceptedStoreRemovedElementIds: oracle.acceptedStoreRemovedElementIds,
    acceptedStoreResourceDescriptorChangedIds:
        oracle.acceptedStoreResourceDescriptorChangedIds,
    acceptedStoreResourceVisualChangedIds:
        oracle.acceptedStoreResourceVisualChangedIds,
    expectedEffects: oracle.effects,
  );
}

StoreRevisionDelta _directTraceRevisionDelta(_ClearTraceEffects effects) {
  var delta = const StoreRevisionDelta();
  if (effects.structural) {
    delta = delta.merge(const StoreRevisionDelta.structural());
  }
  if (effects.resource) {
    delta = delta.merge(const StoreRevisionDelta.resource());
  }
  if (effects.elementVisual) {
    delta = delta.merge(const StoreRevisionDelta.elementVisual());
  }
  return delta;
}

// Complete cross-path facts belong to one oracle at the public trace seam.
// ignore: halstead-volume, source-lines-of-code, maintainability-index
void _expectSparseClearTraceMatchesOracle(
  _SparseClearTraceOutcome outcome, {
  String? reason,
}) {
  expect(
    outcome.actualResults.length,
    outcome.expectedResults.length,
    reason: reason,
  );
  for (var index = 0; index < outcome.actualResults.length; index += 1) {
    _expectClearTraceResult(
      outcome.actualResults[index],
      outcome.expectedResults[index],
    );
  }
  for (var index = 0; index < outcome.materializedResults.length; index += 1) {
    _expectClearTraceResult(
      outcome.materializedResults[index],
      outcome.expectedResults[index],
    );
  }
  expect(outcome.document.background, outcome.expectedDocument.background);
  _expectTraceElements(
    outcome.document.backgroundElements,
    outcome.expectedDocument.backgroundElements,
  );
  expect(
    outcome.document.layers.map((layer) => layer.id),
    outcome.expectedDocument.layers.map((layer) => layer.id),
  );
  for (var index = 0; index < outcome.document.layers.length; index += 1) {
    _expectTraceElements(
      outcome.document.layers[index].elements,
      outcome.expectedDocument.layers[index].elements,
    );
  }
  _expectTraceResources(
    outcome.document.resources,
    outcome.expectedDocument.resources,
  );
  expect(
    outcome.materializedDocument.background,
    outcome.expectedDocument.background,
  );
  _expectTraceElements(
    outcome.materializedDocument.backgroundElements,
    outcome.expectedDocument.backgroundElements,
  );
  _expectTraceResources(
    outcome.materializedDocument.resources,
    outcome.expectedDocument.resources,
  );
  for (
    var index = 0;
    index < outcome.materializedDocument.layers.length;
    index += 1
  ) {
    _expectTraceElements(
      outcome.materializedDocument.layers[index].elements,
      outcome.expectedDocument.layers[index].elements,
    );
  }
  expect(
    outcome.sparseTouchedSet.addedElementIds,
    outcome.expectedEffects.addedElementIds,
    reason: '$reason sparse added touched ids',
  );
  expect(
    outcome.sparseTouchedSet.removedElementIds,
    outcome.expectedEffects.removedElementIds,
    reason: '$reason sparse removed touched ids',
  );
  expect(
    outcome.sparseTouchedSet.resourceDescriptorChangedIds,
    outcome.expectedEffects.resourceDescriptorChangedIds,
    reason: '$reason sparse resource touched ids',
  );
  expect(
    outcome.sparseTouchedSet.selection,
    outcome.expectedEffects.selection,
    reason: '$reason sparse selection touched',
  );
  expect(
    outcome.materializedTouchedSet.addedElementIds,
    outcome.expectedEffects.addedElementIds,
    reason: '$reason materialized added touched ids',
  );
  expect(
    outcome.materializedTouchedSet.removedElementIds,
    outcome.expectedEffects.removedElementIds,
    reason: '$reason materialized removed touched ids',
  );
  expect(
    outcome.materializedTouchedSet.resourceDescriptorChangedIds,
    outcome.expectedEffects.resourceDescriptorChangedIds,
    reason: '$reason materialized resource touched ids',
  );
  expect(
    outcome.materializedTouchedSet.selection,
    outcome.expectedEffects.selection,
    reason: '$reason materialized selection touched',
  );
  expect(outcome.sparseTouchedSet.backgroundLayerChanged, isFalse);
  expect(outcome.sparseTouchedSet.background, isFalse);
  expect(outcome.sparseTouchedSet.grid, isFalse);
  expect(
    outcome.sparseRevisionDelta.structural,
    outcome.expectedEffects.structural,
  );
  expect(
    outcome.sparseRevisionDelta.resource,
    outcome.expectedEffects.resource,
  );
  expect(
    outcome.materializedRevisionDelta.structural,
    outcome.expectedEffects.structural,
  );
  expect(
    outcome.materializedRevisionDelta.resource,
    outcome.expectedEffects.resource,
  );
  expect(outcome.sparseRevisionDelta.background, isFalse);
  expect(outcome.sparseRevisionDelta.grid, isFalse);
}

void _expectClearTraceResult(
  _ClearTraceResult actual,
  _ClearTraceResult expected,
) {
  expect(actual.kind, expected.kind);
  expect(actual.elementId, expected.elementId);
  expect(actual.changed, expected.changed);
  final actualClear = actual.clearResult;
  final expectedClear = expected.clearResult;
  expect(actualClear?.didClearContent, expectedClear?.didClearContent);
  expect(actualClear?.removedElementIds, expectedClear?.removedElementIds);
  expect(actualClear?.removedResourceIds, expectedClear?.removedResourceIds);
}

// Every public image/vector field is part of this exhaustive element matcher.
// ignore: halstead-volume
void _expectTraceElements(
  List<CanvasElement> actual,
  List<CanvasElement> expected,
) {
  expect(actual.length, expected.length, reason: 'trace element count');
  for (var index = 0; index < actual.length; index += 1) {
    final actualElement = actual[index];
    final expectedElement = expected[index];
    expect(actualElement.runtimeType, expectedElement.runtimeType);
    expect(actualElement.id, expectedElement.id);
    expect(actualElement.revision, expectedElement.revision);
    expect(actualElement.transform, expectedElement.transform);
    expect(actualElement.opacity, expectedElement.opacity);
    expect(actualElement.hitPadding, expectedElement.hitPadding);
    expect(actualElement.isVisible, expectedElement.isVisible);
    expect(actualElement.isSelectable, expectedElement.isSelectable);
    expect(actualElement.isLocked, expectedElement.isLocked);
    expect(actualElement.isDeletable, expectedElement.isDeletable);
    expect(actualElement.isTransformable, expectedElement.isTransformable);
    expect(actualElement.metadata, expectedElement.metadata);
    switch ((actualElement, expectedElement)) {
      case (
        final CanvasImageElement actualImage,
        final CanvasImageElement expectedImage,
      ):
        expect(actualImage.resourceId, expectedImage.resourceId);
        expect(actualImage.size, expectedImage.size);
        expect(actualImage.naturalSize, expectedImage.naturalSize);
      case (
        final CanvasVectorElement actualVector,
        final CanvasVectorElement expectedVector,
      ):
        expect(actualVector.resourceId, expectedVector.resourceId);
        expect(actualVector.size, expectedVector.size);
        expect(actualVector.naturalSize, expectedVector.naturalSize);
      default:
        fail('trace fixture supports image and vector elements only.');
    }
  }
}

void _expectTraceResources(
  List<CanvasResource> actual,
  List<CanvasResource> expected,
) {
  expect(actual.length, expected.length, reason: 'trace resource count');
  for (var index = 0; index < actual.length; index += 1) {
    final actualResource = actual[index];
    final expectedResource = expected[index];
    expect(actualResource.runtimeType, expectedResource.runtimeType);
    expect(actualResource.id, expectedResource.id);
    expect(actualResource.source, expectedResource.source);
    expect(actualResource.contentHash, expectedResource.contentHash);
    expect(actualResource.byteLength, expectedResource.byteLength);
    expect(actualResource.metadata, expectedResource.metadata);
    switch ((actualResource, expectedResource)) {
      case (
        final CanvasImageResource actualImage,
        final CanvasImageResource expectedImage,
      ):
        expect(actualImage.mimeType, expectedImage.mimeType);
      case (CanvasVectorResource(), CanvasVectorResource()):
        break;
      default:
        fail('trace fixture supports image and vector resources only.');
    }
  }
}

enum _ClearTraceActionKind {
  addElement,
  updateImageResource,
  removeElement,
  upsertResource,
  removeUnusedResource,
  clearContent,
}

// The action vocabulary is intentionally kept together for trace replay.
// ignore: coupling-between-object-classes, number-of-methods, weighted-methods-per-class
final class _ClearTraceAction {
  const _ClearTraceAction._({
    required this.kind,
    this.element,
    this.imageUpdate,
    this.elementId,
    this.resource,
    this.resourceId,
    this.removeUnusedResources,
    this.index,
  });
  factory _ClearTraceAction.addElement(CanvasElement element, {int? index}) =>
      _ClearTraceAction._(
        kind: _ClearTraceActionKind.addElement,
        element: element,
        index: index,
      );
  factory _ClearTraceAction.updateImageResource({
    required CanvasImageElement before,
    required CanvasImageElement after,
  }) => _ClearTraceAction._(
    kind: _ClearTraceActionKind.updateImageResource,
    imageUpdate: (before: before, after: after),
  );
  factory _ClearTraceAction.removeElement(CanvasElementId id) =>
      _ClearTraceAction._(
        kind: _ClearTraceActionKind.removeElement,
        elementId: id,
      );
  factory _ClearTraceAction.upsertResource(CanvasResource resource) =>
      _ClearTraceAction._(
        kind: _ClearTraceActionKind.upsertResource,
        resource: resource,
      );
  factory _ClearTraceAction.removeUnusedResource(CanvasResourceId id) =>
      _ClearTraceAction._(
        kind: _ClearTraceActionKind.removeUnusedResource,
        resourceId: id,
      );
  const _ClearTraceAction.clearContent({required bool removeUnusedResources})
    : this._(
        kind: _ClearTraceActionKind.clearContent,
        removeUnusedResources: removeUnusedResources,
      );
  final _ClearTraceActionKind kind;
  final CanvasElement? element;
  final ({CanvasImageElement before, CanvasImageElement after})? imageUpdate;
  final CanvasElementId? elementId;
  final CanvasResource? resource;
  final CanvasResourceId? resourceId;
  final bool? removeUnusedResources;
  final int? index;

  CanvasElement get _element =>
      element ?? (throw StateError('missing element'));
  ({CanvasImageElement before, CanvasImageElement after}) get _imageUpdate =>
      imageUpdate ?? (throw StateError('missing image update'));
  CanvasElementId get _elementId =>
      elementId ?? (throw StateError('missing element id'));
  CanvasResource get _resource =>
      resource ?? (throw StateError('missing resource'));
  CanvasResourceId get _resourceId =>
      resourceId ?? (throw StateError('missing resource id'));
  bool get _removeUnusedResources =>
      removeUnusedResources ?? (throw StateError('missing clear policy'));
  _ClearTraceResult applyToSession(EditSession session) => switch (kind) {
    _ClearTraceActionKind.addElement => _ClearTraceResult.added(
      session.addElement(_element, index: index),
    ),
    _ClearTraceActionKind.updateImageResource => _ClearTraceResult.changed(
      kind,
      changed: session.updateElement(
        CanvasImageElementUpdate(
          id: _imageUpdate.after.id,
          resourceId: CanvasFieldSet(_imageUpdate.after.resourceId),
        ),
      ),
    ),
    _ClearTraceActionKind.removeElement => _ClearTraceResult.changed(
      kind,
      changed: session.removeElement(_elementId),
    ),
    _ClearTraceActionKind.upsertResource => _ClearTraceResult.changed(
      kind,
      changed: session.upsertResource(_resource),
    ),
    _ClearTraceActionKind.removeUnusedResource => _ClearTraceResult.changed(
      kind,
      changed: session.removeUnusedResource(_resourceId),
    ),
    _ClearTraceActionKind.clearContent => _ClearTraceResult.cleared(
      session.clearContent(removeUnusedResources: _removeUnusedResources),
    ),
  };
  _ClearTraceResult applyToDraft(DraftDocument draft) => switch (kind) {
    _ClearTraceActionKind.addElement => _ClearTraceResult.added(
      draft.addElement(_element, index: index),
    ),
    _ClearTraceActionKind.updateImageResource => _ClearTraceResult.changed(
      kind,
      changed: draft.updateElement(
        CanvasImageElementUpdate(
          id: _imageUpdate.after.id,
          resourceId: CanvasFieldSet(_imageUpdate.after.resourceId),
        ),
      ),
    ),
    _ClearTraceActionKind.removeElement => _ClearTraceResult.changed(
      kind,
      changed: draft.removeElement(_elementId),
    ),
    _ClearTraceActionKind.upsertResource => _ClearTraceResult.changed(
      kind,
      changed: draft.upsertResource(_resource),
    ),
    _ClearTraceActionKind.removeUnusedResource => _ClearTraceResult.changed(
      kind,
      changed: draft.removeUnusedResource(_resourceId),
    ),
    _ClearTraceActionKind.clearContent => _ClearTraceResult.cleared(
      draft.clearContent(removeUnusedResources: _removeUnusedResources),
    ),
  };
  _ClearTraceResult applyToOracle(_ClearSequentialOracle oracle) =>
      oracle.apply(this);
  StoreSparseMutation? storeMutationFor(_ClearTraceResult result) {
    final changed = result.changed;
    final clearResult = result.clearResult;
    return switch (kind) {
      _ClearTraceActionKind.addElement => StoreSparseAddElement(
        element: _element,
        index: index,
      ),
      _ClearTraceActionKind.updateImageResource when changed == true =>
        StoreSparseUpdateElement(
          before: _imageUpdate.before,
          element: _imageUpdate.after,
          elementRevisionDelta: const StoreRevisionDelta.elementVisual(),
        ),
      _ClearTraceActionKind.removeElement when changed == true =>
        StoreSparseRemoveElement(_elementId),
      _ClearTraceActionKind.upsertResource when changed == true =>
        StoreSparseUpsertResource(_resource),
      _ClearTraceActionKind.removeUnusedResource when changed == true =>
        StoreSparseRemoveUnusedResource(_resourceId),
      _ClearTraceActionKind.clearContent
          when clearResult?.didClearContent == true =>
        StoreSparseClearContent(removeUnusedResources: _removeUnusedResources),
      _ => null,
    };
  }
}

final class _ClearTraceResult {
  const _ClearTraceResult._({
    required this.kind,
    this.elementId,
    this.changed,
    this.clearResult,
  });

  factory _ClearTraceResult.added(CanvasElementId id) {
    return _ClearTraceResult._(
      kind: _ClearTraceActionKind.addElement,
      elementId: id,
    );
  }

  factory _ClearTraceResult.changed(
    _ClearTraceActionKind kind, {
    required bool changed,
  }) {
    return _ClearTraceResult._(kind: kind, changed: changed);
  }

  factory _ClearTraceResult.cleared(CanvasClearResult result) {
    return _ClearTraceResult._(
      kind: _ClearTraceActionKind.clearContent,
      clearResult: result,
    );
  }

  final _ClearTraceActionKind kind;
  final CanvasElementId? elementId;
  final bool? changed;
  final CanvasClearResult? clearResult;
}

// This independent sequential state machine must retain all transition rules.
// ignore: coupling-between-object-classes, number-of-methods, response-for-class, weighted-methods-per-class
final class _ClearSequentialOracle {
  _ClearSequentialOracle(
    CanvasDocument seed, {
    required Set<CanvasElementId> selectedElementIds,
  }) : _background = seed.background,
       _backgroundElements = List.of(seed.backgroundElements),
       _resources = List.of(seed.resources),
       _layers = [
         for (final layer in seed.layers)
           _ClearOracleLayer(layer.id, List.of(layer.elements)),
       ],
       _selectedElementIds = selectedElementIds {
    _seedElementIds.addAll([
      for (final element in seed.backgroundElements) element.id,
      for (final layer in seed.layers)
        for (final element in layer.elements) element.id,
    ]);
    _seedResources.addEntries(
      seed.resources.map((resource) => MapEntry(resource.id, resource)),
    );
    _seedReferencedResourceIds.addAll(_resourceIdsIn(seed.backgroundElements));
    for (final layer in seed.layers) {
      _seedReferencedResourceIds.addAll(_resourceIdsIn(layer.elements));
    }
  }

  final CanvasBackground _background;
  final List<CanvasElement> _backgroundElements;
  final List<CanvasResource> _resources;
  final List<_ClearOracleLayer> _layers;
  final Set<CanvasElementId> _selectedElementIds;
  final Set<CanvasElementId> _seedElementIds = {};
  final Map<CanvasResourceId, CanvasResource> _seedResources = {};
  final Set<CanvasResourceId> _seedReferencedResourceIds = {};
  final effects = _ClearTraceEffects();

  Set<CanvasElementId> get acceptedStoreAddedElementIds =>
      _currentElementIds.difference(_seedElementIds);

  Set<CanvasElementId> get acceptedStoreRemovedElementIds =>
      _seedElementIds.difference(_currentElementIds);

  Set<CanvasElementId> get _currentElementIds => {
    for (final element in _backgroundElements) element.id,
    for (final layer in _layers)
      for (final element in layer.elements) element.id,
  };

  Set<CanvasResourceId> get acceptedStoreResourceDescriptorChangedIds {
    final current = {for (final resource in _resources) resource.id: resource};
    return {
      for (final id in {..._seedResources.keys, ...current.keys})
        if (_seedResources[id] != current[id]) id,
    };
  }

  Set<CanvasResourceId> get acceptedStoreResourceVisualChangedIds => {
    for (final id in acceptedStoreResourceDescriptorChangedIds)
      if (_seedReferencedResourceIds.contains(id) ||
          _currentReferencedResourceIds.contains(id))
        id,
  };

  Set<CanvasResourceId> get _currentReferencedResourceIds => {
    ..._resourceIdsIn(_backgroundElements),
    for (final layer in _layers) ..._resourceIdsIn(layer.elements),
  };

  static Iterable<CanvasResourceId> _resourceIdsIn(
    Iterable<CanvasElement> elements,
  ) sync* {
    for (final element in elements) {
      switch (element) {
        case CanvasImageElement(:final resourceId) ||
            CanvasVectorElement(:final resourceId):
          yield resourceId;
        default:
          continue;
      }
    }
  }

  _ClearTraceResult apply(_ClearTraceAction action) {
    return switch (action.kind) {
      _ClearTraceActionKind.addElement => _addElement(
        action._element,
        index: action.index,
      ),
      _ClearTraceActionKind.updateImageResource => _updateImageResource(
        action._imageUpdate,
      ),
      _ClearTraceActionKind.removeElement => _removeElement(action._elementId),
      _ClearTraceActionKind.upsertResource => _upsertResource(action._resource),
      _ClearTraceActionKind.removeUnusedResource => _removeUnusedResource(
        action._resourceId,
      ),
      _ClearTraceActionKind.clearContent => _clearContent(
        removeUnusedResources: action._removeUnusedResources,
      ),
    };
  }

  _ClearTraceResult _addElement(CanvasElement element, {int? index}) {
    final elements = _layers.last.elements;
    final requestedIndex = index ?? elements.length;
    final resolvedIndex = requestedIndex < 0
        ? 0
        : requestedIndex > elements.length
        ? elements.length
        : requestedIndex;
    elements.insert(resolvedIndex, element);
    _recordElementAddition(element.id);
    effects.structural = true;

    return _ClearTraceResult.added(element.id);
  }

  _ClearTraceResult _updateImageResource(
    ({CanvasImageElement before, CanvasImageElement after}) update,
  ) {
    for (final layer in _layers) {
      final index = layer.elements.indexWhere(
        (element) => element.id == update.before.id,
      );
      if (index < 0) {
        continue;
      }
      layer.elements[index] = update.after;
      effects.elementVisual = true;
      return _ClearTraceResult.changed(
        _ClearTraceActionKind.updateImageResource,
        changed: true,
      );
    }
    return _ClearTraceResult.changed(
      _ClearTraceActionKind.updateImageResource,
      changed: false,
    );
  }

  _ClearTraceResult _removeElement(CanvasElementId id) {
    for (final layer in _layers) {
      final index = layer.elements.indexWhere((element) => element.id == id);
      if (index < 0) {
        continue;
      }
      layer.elements.removeAt(index);
      _recordElementRemoval(id);
      effects.selection = effects.selection || _selectedElementIds.contains(id);
      effects.structural = true;
      return _ClearTraceResult.changed(
        _ClearTraceActionKind.removeElement,
        changed: true,
      );
    }
    return _ClearTraceResult.changed(
      _ClearTraceActionKind.removeElement,
      changed: false,
    );
  }

  _ClearTraceResult _upsertResource(CanvasResource resource) {
    final index = _resources.indexWhere((item) => item.id == resource.id);
    if (index >= 0) {
      if (_resources[index] == resource) {
        return _ClearTraceResult.changed(
          _ClearTraceActionKind.upsertResource,
          changed: false,
        );
      }
      _resources[index] = resource;
    } else {
      _resources.add(resource);
    }
    effects.resourceDescriptorChangedIds.add(resource.id);
    effects.resource = true;

    return _ClearTraceResult.changed(
      _ClearTraceActionKind.upsertResource,
      changed: true,
    );
  }

  _ClearTraceResult _removeUnusedResource(CanvasResourceId id) {
    if (_resourceIsReferenced(id)) {
      return _ClearTraceResult.changed(
        _ClearTraceActionKind.removeUnusedResource,
        changed: false,
      );
    }
    final resourceCountBefore = _resources.length;
    _resources.removeWhere((resource) => resource.id == id);
    final removed = _resources.length < resourceCountBefore;
    if (removed) {
      effects.resourceDescriptorChangedIds.add(id);
      effects.resource = true;
    }

    return _ClearTraceResult.changed(
      _ClearTraceActionKind.removeUnusedResource,
      changed: removed,
    );
  }

  _ClearTraceResult _clearContent({required bool removeUnusedResources}) {
    final removedElementIds = [
      for (final layer in _layers)
        ...layer.elements.map((element) => element.id),
    ];
    for (final layer in _layers) {
      layer.elements.clear();
    }
    if (removedElementIds.isNotEmpty) {
      for (final id in removedElementIds) {
        _recordElementRemoval(id);
      }
      effects.selection =
          effects.selection ||
          removedElementIds.any(_selectedElementIds.contains);
      effects.structural = true;
    }
    final removedResourceIds = removeUnusedResources
        ? _removeResourcesNotReferencedByBackground()
        : const <CanvasResourceId>[];
    if (removedResourceIds.isNotEmpty) {
      effects.resourceDescriptorChangedIds.addAll(removedResourceIds);
      effects.resource = true;
    }

    return _ClearTraceResult.cleared(
      CanvasClearResult(
        removedElementIds: removedElementIds,
        removedResourceIds: removedResourceIds,
        didClearContent:
            removedElementIds.isNotEmpty || removedResourceIds.isNotEmpty,
      ),
    );
  }

  void _recordElementAddition(CanvasElementId id) {
    effects.addedElementIds.add(id);
  }

  void _recordElementRemoval(CanvasElementId id) {
    effects.removedElementIds.add(id);
  }

  List<CanvasResourceId> _removeResourcesNotReferencedByBackground() {
    final retainedIds = <CanvasResourceId>{
      for (final element in _backgroundElements)
        if (element
            case CanvasImageElement(:final resourceId) ||
                CanvasVectorElement(:final resourceId))
          resourceId,
    };
    final removedIds = <CanvasResourceId>[];
    _resources.removeWhere((resource) {
      if (retainedIds.contains(resource.id)) {
        return false;
      }
      removedIds.add(resource.id);

      return true;
    });

    return removedIds;
  }

  bool _resourceIsReferenced(CanvasResourceId id) {
    return [
      ..._backgroundElements,
      for (final layer in _layers) ...layer.elements,
    ].any(
      (element) => switch (element) {
        CanvasImageElement(:final resourceId) ||
        CanvasVectorElement(:final resourceId) => resourceId == id,
        _ => false,
      },
    );
  }

  CanvasDocument toDocument() {
    return CanvasDocument(
      background: _background,
      resources: _resources,
      backgroundElements: _backgroundElements,
      layers: [
        for (final layer in _layers)
          CanvasLayer(id: layer.id, elements: layer.elements),
      ],
    );
  }
}

final class _ClearOracleLayer {
  _ClearOracleLayer(this.id, this.elements);

  final CanvasLayerId id;
  final List<CanvasElement> elements;
}

final class _ClearTraceEffects {
  final Set<CanvasElementId> addedElementIds = {};
  final Set<CanvasElementId> removedElementIds = {};
  final Set<CanvasResourceId> resourceDescriptorChangedIds = {};
  bool selection = false;
  bool structural = false;
  bool elementVisual = false;
  bool resource = false;
}

final class _SparseClearTraceOutcome {
  const _SparseClearTraceOutcome({
    required this.actualResults,
    required this.materializedResults,
    required this.expectedResults,
    required this.sparseCommit,
    required this.directCommit,
    required this.document,
    required this.materializedDocument,
    required this.expectedDocument,
    required this.session,
    required this.sparseTouchedSet,
    required this.materializedTouchedSet,
    required this.sparseRevisionDelta,
    required this.materializedRevisionDelta,
    required this.acceptedStoreAddedElementIds,
    required this.acceptedStoreRemovedElementIds,
    required this.acceptedStoreResourceDescriptorChangedIds,
    required this.acceptedStoreResourceVisualChangedIds,
    required this.expectedEffects,
  });

  final List<_ClearTraceResult> actualResults;
  final List<_ClearTraceResult> materializedResults;
  final List<_ClearTraceResult> expectedResults;
  final StoreSparseCommit sparseCommit;
  final StoreSparseCommit directCommit;
  final CanvasDocument document;
  final CanvasDocument materializedDocument;
  final CanvasDocument expectedDocument;
  final EditSession session;
  final ({
    Set<CanvasElementId> addedElementIds,
    Set<CanvasElementId> removedElementIds,
    Set<CanvasResourceId> resourceDescriptorChangedIds,
    bool selection,
    bool backgroundLayerChanged,
    bool background,
    bool grid,
  })
  sparseTouchedSet;
  final ({
    Set<CanvasElementId> addedElementIds,
    Set<CanvasElementId> removedElementIds,
    Set<CanvasResourceId> resourceDescriptorChangedIds,
    bool selection,
  })
  materializedTouchedSet;
  final ({bool structural, bool resource, bool background, bool grid})
  sparseRevisionDelta;
  final ({bool structural, bool resource}) materializedRevisionDelta;
  final Set<CanvasElementId> acceptedStoreAddedElementIds;
  final Set<CanvasElementId> acceptedStoreRemovedElementIds;
  final Set<CanvasResourceId> acceptedStoreResourceDescriptorChangedIds;
  final Set<CanvasResourceId> acceptedStoreResourceVisualChangedIds;
  final _ClearTraceEffects expectedEffects;
}
