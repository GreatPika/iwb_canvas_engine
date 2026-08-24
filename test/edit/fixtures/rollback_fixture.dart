import 'dart:ui';
import '../../support/runtime_root_with_committed_document_seed.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine/src/contracts/internal/commit_delivery.dart';
import 'package:iwb_canvas_engine/src/edit/draft_document.dart';
import 'package:iwb_canvas_engine/src/geometry/spatial_query_policy.dart';
import 'package:iwb_canvas_engine/src/geometry/spatial_query_result.dart';
import 'package:iwb_canvas_engine/src/runtime/runtime_root.dart';

import 'sparse_edit_session/sparse_edit_session_support.dart';

void main() {
  test('callback throw discards draft document mutations', () {
    expect(_expectCallbackThrowRollsBack, returnsNormally);
  });

  test('validation failure leaves committed store facts unchanged', () {
    expect(_expectValidationFailureRollsBack, returnsNormally);
  });

  test('draft replacement rolls back on callback and validation failure', () {
    expect(_expectDraftReplacementRollsBack, returnsNormally);
  });

  test('equivalent draft replacement still publishes replacement effects', () {
    expect(_expectEquivalentDraftReplacementPublishes, returnsNormally);
  });

  test(
    'draft replacement prepares one isolated backing before publication',
    () {
      expect(_expectDraftReplacementBackingAtomicity, returnsNormally);
    },
  );

  test('materialized finalization failure rolls back before install', () {
    expect(_expectMaterializedFinalizationFailureRollsBack, returnsNormally);
  });

  test('selection-prune rollback leaves committed owners unchanged', () {
    expect(_expectSelectionPruneRollsBack, returnsNormally);
  });

  test('live runtime mutations are rejected inside edit callbacks', () {
    expect(_expectLiveRuntimeMutationsRejectedDuringEdit, returnsNormally);
  });
}

void _expectCallbackThrowRollsBack() {
  final effectBatches = <List<CommitDeliveryEffect>>[];
  final root = _runtimeRoot(effectBatches);
  root.readDocument();
  final beforeBuilds = root.projectionBuildCount;
  final beforeFacts = root.documentFacts;
  final before = _RollbackSnapshot.capture(root, effectBatches);

  expect(
    () => root.edits.edit((edit) {
      edit.addElement(_rect('new'), layerId: CanvasLayerId('layer-1'));
      expect(edit.readDraftDocument().layers.single.elements, hasLength(2));
      throw StateError('rollback');
    }),
    throwsStateError,
  );

  expect(root.readDocument().layers.single.elements, hasLength(1));
  expect(root.documentFacts.documentRevision, beforeFacts.documentRevision);
  expect(root.documentFacts.structuralRevision, beforeFacts.structuralRevision);
  expect(root.projectionBuildCount, beforeBuilds);
  expect(effectBatches, isEmpty);
  before.expectUnchanged(root, effectBatches);
}

void _expectValidationFailureRollsBack() {
  final effectBatches = <List<CommitDeliveryEffect>>[];
  final root = _runtimeRoot(effectBatches);
  root.readDocument();
  final beforeFacts = root.documentFacts;
  final before = _RollbackSnapshot.capture(root, effectBatches);

  expect(
    () => root.edits.edit((edit) {
      edit.addElement(
        CanvasImageElement(
          id: CanvasElementId('missing-image'),
          resourceId: CanvasResourceId('missing-resource'),
          size: const Size(1, 1),
        ),
        layerId: CanvasLayerId('layer-1'),
      );
    }),
    throwsA(
      isA<CanvasDataException>().having(
        (error) => error.code,
        'code',
        CanvasDataErrorCode.missingResourceReference,
      ),
    ),
  );

  expect(root.readDocument().layers.single.elements, hasLength(1));
  expect(root.documentFacts.documentRevision, beforeFacts.documentRevision);
  expect(effectBatches, isEmpty);
  before.expectUnchanged(root, effectBatches);
}

void _expectDraftReplacementRollsBack() {
  _expectDraftReplacementCallbackThrowRollsBack();
  _expectDraftReplacementValidationFailureRollsBack();
}

void _expectDraftReplacementCallbackThrowRollsBack() {
  final callbackEffects = <List<CommitDeliveryEffect>>[];
  final callbackRoot = _runtimeRoot(callbackEffects);
  callbackRoot.selection.setSelection([CanvasElementId('element-1')]);
  final beforeCallbackState = callbackRoot.state.value;
  final callbackSnapshot = _RollbackSnapshot.capture(
    callbackRoot,
    callbackEffects,
  );

  expect(
    () => callbackRoot.edits.edit((edit) {
      edit.replaceDraftDocument(_replacementDocument());
      expect(
        edit.readDraftDocument().backgroundElements.single.id.value,
        'replacement',
      );
      throw StateError('rollback replacement');
    }),
    throwsStateError,
  );
  expect(
    callbackRoot.readDocument().layers.single.elements.single.id.value,
    'element-1',
  );
  expect(callbackRoot.selectedElementIds, {CanvasElementId('element-1')});
  expect(callbackRoot.state.value, beforeCallbackState);
  callbackSnapshot.expectUnchanged(callbackRoot, callbackEffects);
}

void _expectDraftReplacementValidationFailureRollsBack() {
  final validationEffects = <List<CommitDeliveryEffect>>[];
  final validationRoot = _runtimeRoot(validationEffects);
  final beforeValidationState = validationRoot.state.value;
  final before = _RollbackSnapshot.capture(validationRoot, validationEffects);
  expect(
    () => validationRoot.edits.edit((edit) {
      edit.replaceDraftDocument(_invalidReplacementDocument());
    }),
    throwsA(
      isA<CanvasDataException>().having(
        (error) => error.code,
        'code',
        CanvasDataErrorCode.duplicateElementId,
      ),
    ),
  );
  expect(
    validationRoot.readDocument().layers.single.elements.single.id.value,
    'element-1',
  );
  expect(validationRoot.state.value, beforeValidationState);
  before.expectUnchanged(validationRoot, validationEffects);
}

void _expectEquivalentDraftReplacementPublishes() {
  final effectBatches = <List<CommitDeliveryEffect>>[];
  final root = _runtimeRoot(effectBatches);
  final before = root.state.value;
  final replacement = root.readDocument();

  root.edits.edit((edit) {
    edit.replaceDraftDocument(replacement);
  });

  final installed = root.readDocument();
  expect(
    installed.layers.single.elements.single.id,
    replacement.layers.single.elements.single.id,
  );
  expect(installed.background.color, replacement.background.color);
  expect(root.state.value.revisions.document, before.revisions.document + 1);
  expect(root.state.value.revisions.epoch, before.revisions.epoch + 1);
  expect(effectBatches, hasLength(1));
  expect(effectBatches.single.whereType<SpatialDeliveryEffect>(), hasLength(1));
  expect(
    effectBatches.single.whereType<PublicStateDeliveryEffect>(),
    hasLength(1),
  );
}

void _expectDraftReplacementBackingAtomicity() {
  _expectDraftReplacementFailureRetention();
  _expectDraftReplacementPublicationAndIsolation();
  _expectDraftReplacementAtSupportedSizeBuildsOnce();
}

// All injected phases share one before/after oracle so partial publication
// cannot hide behind final equality or a clone-back repair.
// ignore: halstead-volume, source-lines-of-code
void _expectDraftReplacementFailureRetention() {
  for (final phase in DraftReplacementWorkPhase.values) {
    final draft = _replacementDraft();
    final before = _DraftReplacementSnapshot.capture(draft);
    final events = <DraftReplacementWorkEvent>[];

    expect(
      () => DraftDocument.observeDraftReplacementWork((event) {
        events.add(event);
        if (event.phase == phase) {
          throw StateError('Injected replacement failure at $phase.');
        }
      }, () => draft.replaceDocument(_completeReplacementDocument())),
      throwsStateError,
    );

    before.expectUnchanged(draft);
    expect(
      events.map((event) => event.phase),
      _replacementPhasesThrough(phase),
    );
    expect(
      events.map((event) => event.activeBacking),
      everyElement(same(before.backing)),
    );
    if (phase == DraftReplacementWorkPhase.publication) {
      expect(events.last.replacementBacking, isNot(same(before.backing)));
    } else {
      expect(events.last.replacementBacking, isNull);
    }
  }

  final invalidDraft = _replacementDraft();
  final beforeInvalid = _DraftReplacementSnapshot.capture(invalidDraft);
  final invalidEvents = <DraftReplacementWorkEvent>[];
  expect(
    () => DraftDocument.observeDraftReplacementWork(
      invalidEvents.add,
      () => invalidDraft.replaceDocument(_invalidReplacementDocument()),
    ),
    throwsA(
      isA<CanvasDataException>().having(
        (error) => error.code,
        'code',
        CanvasDataErrorCode.duplicateElementId,
      ),
    ),
  );
  beforeInvalid.expectUnchanged(invalidDraft);
  expect(invalidEvents.map((event) => event.phase), [
    DraftReplacementWorkPhase.validation,
  ]);
  expect(invalidEvents.single.activeBacking, same(beforeInvalid.backing));
}

// Publication, backing identity, caller alias, and projection alias checks are
// one atomicity admission rather than separate fixture families.
// ignore: halstead-volume, source-lines-of-code, maintainability-index
void _expectDraftReplacementPublicationAndIsolation() {
  final draft = _replacementDraft();
  final before = _DraftReplacementSnapshot.capture(draft);
  final events = <DraftReplacementWorkEvent>[];

  DraftDocument.observeDraftReplacementWork(events.add, () {
    draft.replaceDocument(_completeReplacementDocument());
  });

  expect(events.map((event) => event.phase), DraftReplacementWorkPhase.values);
  expect(
    events.map((event) => event.activeBacking),
    everyElement(same(before.backing)),
  );
  final publication = events.last;
  final replacementBacking = publication.replacementBacking;
  expect(replacementBacking, isNotNull);
  expect(replacementBacking, isNot(same(before.backing)));
  expect(draft.replacementBackingHandle, same(replacementBacking));

  final replacement = draft.readDocument();
  expect(replacement.camera.offset, const Offset(12, 13));
  expect(replacement.background.color, const Color(0xFF102030));
  expect(replacement.palette.penColors, [const Color(0xFF010203)]);
  expect(replacement.resources.map((resource) => resource.id.value), [
    'next-r',
  ]);
  expect(
    replacement.layers.single.elements.map((element) => element.id.value),
    ['next-element'],
  );
  expect(
    draft.summary,
    const CanvasDocumentSummary(
      elementCount: 2,
      layerCount: 1,
      resourceCount: 1,
    ),
  );
  expect(draft.documentReplaced, isTrue);
  expect(draft.touchedSet.documentReplaced, isTrue);
  expect(draft.touchedSet.selection, isTrue);
  _expectReplacementRevisionDelta(draft);

  for (final element in <CanvasRectElement>[
    CanvasRectElement(
      id: CanvasElementId('ineligible-selection'),
      size: const Size(1, 1),
      isVisible: false,
    ),
    CanvasRectElement(
      id: CanvasElementId('ineligible-selection'),
      size: const Size(1, 1),
      isSelectable: false,
    ),
  ]) {
    final selectionDraft = DraftDocument(
      _document(),
      selectedElementIds: [CanvasElementId('ineligible-selection')],
    );
    selectionDraft.replaceDocument(
      CanvasDocument(
        layers: [
          CanvasLayer(
            id: CanvasLayerId('ineligible-layer'),
            elements: [element],
          ),
        ],
      ),
    );
    expect(selectionDraft.touchedSet.selection, isTrue);
  }

  final activeBeforeRetiredMutation = _DraftReplacementSnapshot.capture(draft);
  draft.mutateReplacementBackingForTesting(before.backing);
  activeBeforeRetiredMutation.expectUnchanged(draft);

  draft.addElement(
    CanvasImageElement(
      id: CanvasElementId('active-replacement-element'),
      resourceId: CanvasResourceId('next-r'),
      size: const Size(1, 1),
    ),
    layerId: CanvasLayerId('next-layer'),
  );
  expect(
    draft.upsertResource(
      CanvasImageResource(
        id: CanvasResourceId('active-replacement-resource'),
        source: CanvasResourceSource.appKey('active-replacement-resource'),
      ),
    ),
    isTrue,
  );
  final afterMutation = draft.readDocument();
  expect(
    afterMutation.layers.single.elements.map((element) => element.id.value),
    ['next-element', 'active-replacement-element'],
  );
  expect(afterMutation.resources.map((resource) => resource.id.value), [
    'next-r',
    'active-replacement-resource',
  ]);
  expect(
    draft.summary,
    const CanvasDocumentSummary(
      elementCount: 3,
      layerCount: 1,
      resourceCount: 2,
    ),
  );
  expect(draft.touchedSet.addedElementIds, {
    CanvasElementId('active-replacement-element'),
  });
  expect(draft.touchedSet.resourceDescriptorChangedIds, {
    CanvasResourceId('active-replacement-resource'),
  });
  expect(draft.touchedSet.layerIds, isEmpty);
  expect(draft.touchedSet.backgroundLayerChanged, isFalse);
  _expectReplacementRevisionDelta(draft);

  expect(() => replacement.layers.clear(), throwsUnsupportedError);
  expect(() => replacement.resources.clear(), throwsUnsupportedError);
  expect(draft.readDocument().layers.single.elements, hasLength(2));
  expect(draft.readDocument().resources, hasLength(2));
}

// The supported-size witness observes only replacement's one Draft backing
// construction and publication; structure/resource mutation work stays owned
// by their existing focused suites.
// ignore: halstead-volume, source-lines-of-code
void _expectDraftReplacementAtSupportedSizeBuildsOnce() {
  const elementCount = 200000;
  const layerCount = 4096;
  final draft = DraftDocument(_document());
  final replacement = supportedSizeDraftDocument(
    elementCount: elementCount,
    layerCount: layerCount,
  );
  final replacementEvents = <DraftReplacementWorkEvent>[];
  var constructionLayerVisits = 0;
  var constructionElementVisits = 0;
  var constructionDescriptorVisits = 0;
  var resourceConstructionElementVisits = 0;
  var structureMapReads = 0;

  DraftDocument.observeDraftReplacementWork(
    replacementEvents.add,
    () => observeDraftStructureWork(
      (event) {
        if (event.mapOperation == DraftStructureMapOperation.read) {
          structureMapReads += 1;
        }
        switch (event.kind) {
          case DraftStructureWorkKind.constructionLayerVisit:
            constructionLayerVisits += 1;
          case DraftStructureWorkKind.constructionElementVisit:
            constructionElementVisits += 1;
          case _:
            break;
        }
      },
      () => observeDraftResourceWork((event) {
        switch (event.kind) {
          case DraftResourceWorkKind.constructionDescriptorVisit:
            constructionDescriptorVisits += 1;
          case DraftResourceWorkKind.constructionElementVisit:
            resourceConstructionElementVisits += 1;
          case _:
            break;
        }
      }, () => draft.replaceDocument(replacement)),
    ),
  );

  expect(
    replacementEvents.map((event) => event.phase),
    DraftReplacementWorkPhase.values,
  );
  expect(
    replacementEvents.where(
      (event) => event.phase == DraftReplacementWorkPhase.publication,
    ),
    hasLength(1),
  );
  expect(constructionLayerVisits, layerCount);
  expect(constructionElementVisits, elementCount);
  expect(constructionDescriptorVisits, 0);
  expect(resourceConstructionElementVisits, elementCount);
  expect(structureMapReads, 0);
  expect(
    draft.summary,
    const CanvasDocumentSummary(
      elementCount: elementCount,
      layerCount: layerCount,
      resourceCount: 0,
    ),
  );
}

DraftDocument _replacementDraft() {
  final selectedElementIds = <CanvasElementId>[CanvasElementId('element-1')];
  final draft = DraftDocument(
    _document(),
    selectedElementIds: selectedElementIds,
  );
  selectedElementIds.clear();
  draft.setCameraOffset(const Offset(2, 3));
  draft.setPalette(
    CanvasPalette(
      penColors: const [Color(0xFF112233)],
      backgroundColors: const [Color(0xFF445566)],
      gridSizes: const [8],
    ),
  );
  return draft;
}

Iterable<DraftReplacementWorkPhase> _replacementPhasesThrough(
  DraftReplacementWorkPhase phase,
) {
  return DraftReplacementWorkPhase.values.take(phase.index + 1);
}

void _expectReplacementRevisionDelta(DraftDocument draft) {
  final delta = draft.revisionDelta;
  expect(delta.document, isTrue);
  expect(delta.projection, isTrue);
  expect(delta.structural, isTrue);
  expect(delta.bounds, isTrue);
  expect(delta.elementVisual, isTrue);
  expect(delta.background, isTrue);
  expect(delta.grid, isTrue);
  expect(delta.resource, isTrue);
}

void _expectMaterializedFinalizationFailureRollsBack() {
  final effectBatches = <List<CommitDeliveryEffect>>[];
  final root = _runtimeRoot(effectBatches);
  root.selection.setSelection([CanvasElementId('element-1')]);
  final before = _RollbackSnapshot.capture(root, effectBatches);

  expect(
    () => root.edits.edit((edit) {
      edit.readDraftDocument();
      edit.addElement(
        CanvasImageElement(
          id: CanvasElementId('missing-materialized-image'),
          resourceId: CanvasResourceId('missing-resource'),
          size: const Size(1, 1),
        ),
        layerId: CanvasLayerId('layer-1'),
      );
    }),
    throwsA(
      isA<CanvasDataException>().having(
        (error) => error.code,
        'code',
        CanvasDataErrorCode.missingResourceReference,
      ),
    ),
  );

  before.expectUnchanged(root, effectBatches);
}

void _expectSelectionPruneRollsBack() {
  final effectBatches = <List<CommitDeliveryEffect>>[];
  final root = _runtimeRoot(effectBatches);
  root.selection.setSelection([CanvasElementId('element-1')]);
  final before = _RollbackSnapshot.capture(root, effectBatches);

  expect(
    () => root.edits.edit((edit) {
      edit.updateElement(
        CanvasRectElementUpdate(
          id: CanvasElementId('element-1'),
          isSelectable: const CanvasFieldSet(false),
        ),
      );
      throw StateError('rollback selection prune');
    }),
    throwsStateError,
  );

  before.expectUnchanged(root, effectBatches);
}

void _expectLiveRuntimeMutationsRejectedDuringEdit() {
  final effectBatches = <List<CommitDeliveryEffect>>[];
  final root = _runtimeRoot(effectBatches);
  root.selection.setSelection([CanvasElementId('element-1')]);
  root.cameraPort().setOffset(const Offset(4, 5));
  final beforeState = root.state.value;

  _expectLiveMutationRejectedDuringEdit(
    root,
    () => root.selection.clearSelection(),
  );
  _expectLiveMutationRejectedDuringEdit(
    root,
    () => root.cameraPort().panBy(const Offset(1, 1)),
  );
  _expectLiveMutationRejectedDuringEdit(root, root.dispose);

  expect(root.isDisposed, isFalse);
  expect(root.state.value, beforeState);
  expect(root.readDocument().layers.single.elements, hasLength(1));
  expect(effectBatches, isEmpty);
}

RuntimeRoot _runtimeRoot(List<List<CommitDeliveryEffect>> effectBatches) {
  return runtimeRootWithCommittedDocumentSeed(
    _document(),
    config: const CanvasRuntimeConfig(),
    commitEffectObserver: effectBatches.add,
  );
}

void _expectLiveMutationRejectedDuringEdit(
  RuntimeRoot root,
  void Function() mutate,
) {
  expect(
    () => root.edits.edit((edit) {
      edit.addElement(_rect('new'), layerId: CanvasLayerId('layer-1'));
      mutate();
    }),
    throwsStateError,
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
    layers: [
      CanvasLayer(id: CanvasLayerId('layer-1'), elements: [_rect('element-1')]),
    ],
  );
}

CanvasDocument _replacementDocument() {
  return CanvasDocument(
    backgroundElements: [
      CanvasRectElement(
        id: CanvasElementId('replacement'),
        size: const Size(1, 1),
      ),
    ],
  );
}

CanvasDocument _invalidReplacementDocument() {
  return CanvasDocument(
    backgroundElements: [
      CanvasRectElement(
        id: CanvasElementId('duplicate'),
        size: const Size(1, 1),
      ),
    ],
    layers: [
      CanvasLayer(
        id: CanvasLayerId('layer'),
        elements: [
          CanvasRectElement(
            id: CanvasElementId('duplicate'),
            size: const Size(1, 1),
          ),
        ],
      ),
    ],
  );
}

CanvasRectElement _rect(String id) {
  return CanvasRectElement(id: CanvasElementId(id), size: const Size(1, 1));
}

CanvasDocument _completeReplacementDocument() {
  return CanvasDocument(
    camera: CanvasCamera(offset: const Offset(12, 13)),
    background: const CanvasBackground(color: Color(0xFF102030)),
    palette: CanvasPalette(
      penColors: const [Color(0xFF010203)],
      backgroundColors: const [Color(0xFF040506)],
      gridSizes: const [16],
    ),
    resources: [
      CanvasImageResource(
        id: CanvasResourceId('next-r'),
        source: CanvasResourceSource.appKey('next-r'),
      ),
    ],
    backgroundElements: [
      CanvasRectElement(
        id: CanvasElementId('next-background'),
        size: const Size(1, 1),
      ),
    ],
    layers: [
      CanvasLayer(
        id: CanvasLayerId('next-layer'),
        elements: [
          CanvasImageElement(
            id: CanvasElementId('next-element'),
            resourceId: CanvasResourceId('next-r'),
            size: const Size(1, 1),
          ),
        ],
      ),
    ],
  );
}

final class _DraftReplacementSnapshot {
  const _DraftReplacementSnapshot({
    required this.backing,
    required this.document,
    required this.summary,
    required this.revisionFacts,
    required this.touchedFacts,
    required this.didChange,
    required this.documentReplaced,
  });

  factory _DraftReplacementSnapshot.capture(DraftDocument draft) {
    return _DraftReplacementSnapshot(
      backing: draft.replacementBackingHandle,
      document: draft.readDocument(),
      summary: draft.summary,
      revisionFacts: _revisionFacts(draft),
      touchedFacts: _touchedFacts(draft),
      didChange: draft.didChange,
      documentReplaced: draft.documentReplaced,
    );
  }

  final Object backing;
  final CanvasDocument document;
  final CanvasDocumentSummary summary;
  final List<bool> revisionFacts;
  final List<Object> touchedFacts;
  final bool didChange;
  final bool documentReplaced;

  void expectUnchanged(DraftDocument draft) {
    expect(draft.replacementBackingHandle, same(backing));
    expect(
      encodeCanvasDocument(draft.readDocument()),
      encodeCanvasDocument(document),
    );
    expect(draft.summary, summary);
    expect(draft.didChange, didChange);
    expect(draft.documentReplaced, documentReplaced);
    expect(_revisionFacts(draft), revisionFacts);
    expect(_touchedFacts(draft), touchedFacts);
  }
}

List<bool> _revisionFacts(DraftDocument draft) {
  final delta = draft.revisionDelta;

  return [
    delta.document,
    delta.projection,
    delta.structural,
    delta.bounds,
    delta.elementVisual,
    delta.background,
    delta.grid,
    delta.resource,
  ];
}

List<Object> _touchedFacts(DraftDocument draft) {
  final touched = draft.touchedSet;

  return [
    touched.addedElementIds,
    touched.removedElementIds,
    touched.updatedElementIds,
    touched.transformedElementIds,
    touched.geometryElementIds,
    touched.visualElementIds,
    touched.resourceDescriptorChangedIds,
    touched.resourceVisualChangedIds,
    touched.layerIds,
    touched.allResourceVisualsChanged,
    touched.backgroundLayerChanged,
    touched.selection,
    touched.persistedCamera,
    touched.background,
    touched.grid,
    touched.palette,
    touched.documentReplaced,
  ];
}

final class _RollbackSnapshot {
  const _RollbackSnapshot({
    required this.document,
    required this.selectedElementIds,
    required this.publicState,
    required this.projectionBuildCount,
    required this.spatialElementIds,
    required this.effectBatchCount,
  });

  factory _RollbackSnapshot.capture(
    RuntimeRoot root,
    List<List<CommitDeliveryEffect>> effectBatches,
  ) {
    return _RollbackSnapshot(
      document: root.readDocument(),
      selectedElementIds: Set.of(root.selectedElementIds),
      publicState: root.state.value,
      projectionBuildCount: root.projectionBuildCount,
      spatialElementIds: _spatialIds(root),
      effectBatchCount: effectBatches.length,
    );
  }

  final CanvasDocument document;
  final Set<CanvasElementId> selectedElementIds;
  final CanvasRuntimeState publicState;
  final int projectionBuildCount;
  final List<CanvasElementId> spatialElementIds;
  final int effectBatchCount;

  void expectUnchanged(
    RuntimeRoot root,
    List<List<CommitDeliveryEffect>> effectBatches,
  ) {
    expect(root.readDocument(), document);
    expect(root.selectedElementIds, selectedElementIds);
    expect(root.state.value, publicState);
    expect(root.projectionBuildCount, projectionBuildCount);
    expect(_spatialIds(root), spatialElementIds);
    expect(effectBatches, hasLength(effectBatchCount));
  }
}

List<CanvasElementId> _spatialIds(RuntimeRoot root) {
  final result = root.spatialKernel.queryHit(
    SpatialQueryWindow(
      boundsWorld: const Rect.fromLTRB(-20, -20, 20, 20),
      structuralRevision: root.frameRevisions.structuralRevision,
    ),
  );

  return switch (result) {
    SpatialCandidatesResult(:final orderedCandidates) =>
      orderedCandidates.map((handle) => handle.id).toList(),
    _ => fail('Expected SpatialCandidatesResult, got $result'),
  };
}
