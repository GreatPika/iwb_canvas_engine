import 'dart:ui';
import '../../support/runtime_root_with_committed_document_seed.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine/src/contracts/internal/commit_delivery.dart';
import 'package:iwb_canvas_engine/src/geometry/spatial_query_policy.dart';
import 'package:iwb_canvas_engine/src/geometry/spatial_query_result.dart';
import 'package:iwb_canvas_engine/src/runtime/runtime_root.dart';

import 'draft_replacement_backing_fixture.dart';

void main() {
  registerDraftReplacementBackingTests();

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
    config: const CanvasRuntimeConfig(
      deletionCommitResolver: _acceptDeletionCommit,
    ),
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

CanvasDeletionDecision _acceptDeletionCommit(CanvasDeletionCommitRequest _) =>
    CanvasDeletionDecision.accept;
