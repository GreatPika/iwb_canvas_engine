import 'dart:ui';

// This direct EditKernel fixture owns one interaction commit transaction with
// store, compiler, applier, and action-intent seams; splitting those imports
// would hide the temporal boundary the regression tests enforce.
// ignore_for_file: number-of-imports

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine/src/contracts/internal/commit_action_intent.dart';
import 'package:iwb_canvas_engine/src/contracts/internal/commit_delivery.dart';
import 'package:iwb_canvas_engine/src/contracts/internal/selection_membership_port.dart';
import 'package:iwb_canvas_engine/src/contracts/internal/touched_set.dart';
import 'package:iwb_canvas_engine/src/edit/commit_applier.dart';
import 'package:iwb_canvas_engine/src/edit/commit_plan.dart';
import 'package:iwb_canvas_engine/src/selection/selection_kernel.dart';
import 'package:iwb_canvas_engine/src/store/document_store_kernel.dart';
import 'package:iwb_canvas_engine/src/store/sparse_store_commit.dart';
import 'package:iwb_canvas_engine/src/store/store_revision_delta.dart';

import '../../support/document_store_with_document.dart';
import 'interaction_commit_scenario_support.dart';

void main() {
  test(
    'accepted interaction augments after store finalization',
    () => expect(_acceptedInteractionAugmentsFinalPlan, returnsNormally),
  );
  test(
    'append add interaction returns spatial element touch without layer rebuild',
    () => expect(_appendAddReturnsElementTouchOnly, returnsNormally),
  );
  test(
    'content removal interaction returns base layer spatial touch',
    () => expect(_contentRemovalReturnsSpatialLayerTouch, returnsNormally),
  );
  test(
    'background removal interaction returns spatial touch',
    () => expect(_backgroundRemovalReturnsSpatialTouch, returnsNormally),
  );
  test(
    'spatial-only update interaction returns geometry touch',
    () => expect(_spatialOnlyUpdateReturnsGeometryTouch, returnsNormally),
  );
  test(
    'transient selection prune does not deliver accepted selection effect',
    () => expect(
      _transientSelectionPruneDoesNotDeliverAcceptedSelectionEffect,
      returnsNormally,
    ),
  );
  test(
    'throwing interaction augmentation rolls back before install',
    () => expect(_throwingInteractionAugmentationRollsBack, returnsNormally),
  );
  test(
    'nested interaction augmentation rolls back before install',
    () => expect(_nestedInteractionAugmentationRollsBack, returnsNormally),
  );
  test(
    'prepared interaction terminals preserve every generalized owner form',
    () =>
        expect(_verifyGeneralizedPreparedInteractionTerminals, returnsNormally),
  );
}

void _acceptedInteractionAugmentsFinalPlan() {
  final store = documentStoreWithDocument(interactionCommitBaseDocument());
  final scenario = InteractionCommitScenario(store);
  final before = InteractionCommitSnapshot.capture(store, scenario);
  var augmentCallCount = 0;

  final result = scenario.kernel.prepareInteractionCommit(
    (edit) {
      edit.setCameraOffset(const Offset(9, 9));
      edit.setCameraOffset(Offset.zero);
      edit.setBackgroundColor(const Color(0xFF112233));
    },
    augmentPlan: (plan) {
      augmentCallCount += 1;
      _expectAcceptedBackgroundPlan(plan);

      return plan.withActionIntents([
        RemoveElementActionIntent(elementId: CanvasElementId('rect-1')),
      ]);
    },
  );

  _expectAugmentedBackgroundCommit(
    result: result,
    store: store,
    before: before,
    augmentCallCount: augmentCallCount,
  );
  _expectInstalledWithoutDelivery(scenario);
}

void _appendAddReturnsElementTouchOnly() {
  final store = documentStoreWithDocument(interactionCommitBaseDocument());
  final scenario = InteractionCommitScenario(store);

  final result = scenario.kernel.prepareInteractionCommit((edit) {
    edit.addElement(
      CanvasRectElement(
        id: CanvasElementId('implicit-layer-add'),
        size: const Size(2, 3),
      ),
    );
  });

  final spatial = result.effects.whereType<SpatialDeliveryEffect>().single;
  expect(spatial.touchedSet.addedElementIds, {
    CanvasElementId('implicit-layer-add'),
  });
  expect(spatial.touchedSet.layerIds, isEmpty);
  expect(scenario.installCount, 1);
  expect(store.projectionBuildCount, 0);
}

void _contentRemovalReturnsSpatialLayerTouch() {
  final store = documentStoreWithDocument(interactionCommitBaseDocument());
  final scenario = InteractionCommitScenario(store);

  final result = scenario.kernel.prepareInteractionCommit((edit) {
    edit.removeElement(CanvasElementId('rect-1'));
  });

  final spatial = result.effects.whereType<SpatialDeliveryEffect>().single;
  expect(spatial.touchedSet.removedElementIds, {CanvasElementId('rect-1')});
  expect(spatial.touchedSet.layerIds, {CanvasLayerId('layer-1')});
  expect(scenario.installCount, 1);
  expect(store.projectionBuildCount, 0);
}

void _backgroundRemovalReturnsSpatialTouch() {
  final store = documentStoreWithDocument(
    interactionCommitBaseDocument(backgroundElementIds: ['background-1']),
  );
  final scenario = InteractionCommitScenario(store);

  final result = scenario.kernel.prepareInteractionCommit((edit) {
    edit.removeElement(CanvasElementId('background-1'));
  });

  final spatial = result.effects.whereType<SpatialDeliveryEffect>().single;
  expect(spatial.touchedSet.removedElementIds, {
    CanvasElementId('background-1'),
  });
  expect(spatial.touchedSet.backgroundLayerChanged, isTrue);
  expect(scenario.installCount, 1);
  expect(store.projectionBuildCount, 0);
}

void _spatialOnlyUpdateReturnsGeometryTouch() {
  final store = documentStoreWithDocument(interactionCommitBaseDocument());
  final scenario = InteractionCommitScenario(store);

  final result = scenario.kernel.prepareInteractionCommit((edit) {
    edit.updateElement(
      CanvasRectElementUpdate(
        id: CanvasElementId('rect-1'),
        isSelectable: const CanvasFieldSet(false),
      ),
    );
  });

  final spatial = result.effects.whereType<SpatialDeliveryEffect>().single;
  expect(spatial.touchedSet.updatedElementIds, {CanvasElementId('rect-1')});
  expect(spatial.touchedSet.geometryElementIds, {CanvasElementId('rect-1')});
  expect(scenario.installCount, 1);
  expect(store.projectionBuildCount, 0);
}

void _transientSelectionPruneDoesNotDeliverAcceptedSelectionEffect() {
  final store = documentStoreWithDocument(interactionCommitBaseDocument());
  final scenario = InteractionCommitScenario(
    store,
    selectedElementIds: {CanvasElementId('rect-1')},
  );

  final result = scenario.kernel.prepareInteractionCommit((edit) {
    edit.updateElement(
      CanvasRectElementUpdate(
        id: CanvasElementId('rect-1'),
        isSelectable: const CanvasFieldSet(false),
      ),
    );
    edit.updateElement(
      CanvasRectElementUpdate(
        id: CanvasElementId('rect-1'),
        isSelectable: const CanvasFieldSet(true),
        opacity: const CanvasFieldSet(0.5),
      ),
    );
  });

  expect(result.effects.whereType<SelectionDeliveryEffect>(), isEmpty);
  expect(scenario.prepareSelectionCount, 0);
  expect(scenario.installCount, 1);
  final element = store.elementById(CanvasElementId('rect-1'));
  if (element is! CanvasRectElement) {
    throw StateError('Expected rect-1 to remain a committed rect.');
  }
  expect(element.isSelectable, isTrue);
  expect(element.opacity, 0.5);
}

void _expectAcceptedBackgroundPlan(CommitPlan plan) {
  expect(plan.hasChanges, isTrue);
  expect(plan.revisionDelta.document, isTrue);
  expect(plan.revisionDelta.projection, isTrue);
  expect(plan.revisionDelta.background, isTrue);
  expect(plan.revisionDelta.bounds, isFalse);
  expect(plan.revisionDelta.elementVisual, isFalse);
  expect(plan.touchedSet.persistedCamera, isFalse);
  expect(plan.touchedSet.background, isTrue);
}

void _expectAugmentedBackgroundCommit({
  required CommitDeliveryResult result,
  required DocumentStoreKernel store,
  required InteractionCommitSnapshot before,
  required int augmentCallCount,
}) {
  expect(augmentCallCount, 1);
  expect(result.shouldPublishState, isTrue);
  expect(result.effects, isNotEmpty);
  expect(result.actionIntents, hasLength(1));
  expect(
    result.actionIntents.single.kind,
    CommitActionIntentKind.removeElement,
  );
  expect(store.background.color, const Color(0xFF112233));
  expect(store.camera, before.camera);
  expect(store.documentRevision, before.documentRevision + 1);
  expect(store.projectionBuildCount, before.projectionBuildCount);
}

void _expectInstalledWithoutDelivery(InteractionCommitScenario scenario) {
  expect(scenario.installCount, 1);
  expect(scenario.deliverCount, 0);
  expect(scenario.loadCount, 0);
}

void _throwingInteractionAugmentationRollsBack() {
  final store = documentStoreWithDocument(interactionCommitBaseDocument());
  final scenario = InteractionCommitScenario(store);
  final before = InteractionCommitSnapshot.capture(store, scenario);

  expect(
    () => scenario.kernel.prepareInteractionCommit(
      (edit) {
        edit.setBackgroundColor(const Color(0xFF445566));
      },
      augmentPlan: (_) {
        throw StateError('augment failed');
      },
    ),
    throwsStateError,
  );

  before.expectUnchanged(store, scenario);
}

void _nestedInteractionAugmentationRollsBack() {
  final store = documentStoreWithDocument(interactionCommitBaseDocument());
  final scenario = InteractionCommitScenario(store);
  final before = InteractionCommitSnapshot.capture(store, scenario);

  expect(
    () => scenario.kernel.prepareInteractionCommit(
      (edit) {
        edit.setBackgroundColor(const Color(0xFF778899));
      },
      augmentPlan: (_) {
        scenario.kernel.prepareInteractionCommit((nested) {
          nested.setCameraOffset(const Offset(4, 5));
        });
        throw StateError('nested interaction unexpectedly returned');
      },
    ),
    throwsStateError,
  );

  before.expectUnchanged(store, scenario);
}

/// Exercises the public prepared capability through all current accepted forms;
/// four terminal orders share one owner snapshot rather than test private state.
// ignore: halstead-volume, source-lines-of-code, reason: The terminal matrix is one admitted owner-lifetime witness.
void _verifyGeneralizedPreparedInteractionTerminals() {
  for (final form in _TerminalInteractionForm.values) {
    _verifyPreparedTerminal(form, _PreparedTerminal.consumeThenConsume);
    _verifyPreparedTerminal(form, _PreparedTerminal.discardThenConsume);
    _verifyPreparedTerminal(form, _PreparedTerminal.consumeThenDiscard);
    _verifyPreparedTerminal(form, _PreparedTerminal.discardThenDiscard);
  }
}

// ignore: halstead-volume, reason: One terminal order must retain the real owner snapshot and lifetime events together.
void _verifyPreparedTerminal(
  _TerminalInteractionForm form,
  _PreparedTerminal terminal,
) {
  final owners = _TerminalOwners(form);
  final work = <PreparedInteractionApplyWorkEvent>[];
  CommitApplier.observePreparedInteractionWork(work.add, () {
    final before = _TerminalOwnerSnapshot.capture(owners);
    final prepared = _prepareTerminalInteraction(owners, form);
    before.expectUnchanged(owners);

    switch (terminal) {
      case _PreparedTerminal.consumeThenConsume:
        prepared.consume();
        _expectTerminalConsume(owners, before, form);
        final afterFirst = _TerminalOwnerSnapshot.capture(owners);
        expect(prepared.consume, throwsStateError);
        afterFirst.expectUnchanged(owners);
      case _PreparedTerminal.discardThenConsume:
        prepared.discard();
        before.expectUnchanged(owners);
        expect(prepared.consume, throwsStateError);
        before.expectUnchanged(owners);
      case _PreparedTerminal.consumeThenDiscard:
        prepared.consume();
        _expectTerminalConsume(owners, before, form);
        final afterFirst = _TerminalOwnerSnapshot.capture(owners);
        expect(prepared.discard, throwsStateError);
        afterFirst.expectUnchanged(owners);
      case _PreparedTerminal.discardThenDiscard:
        prepared.discard();
        before.expectUnchanged(owners);
        final afterFirst = _TerminalOwnerSnapshot.capture(owners);
        expect(prepared.discard, throwsStateError);
        afterFirst.expectUnchanged(owners);
    }
  });
  _expectTerminalWork(work, form, terminal);
}

void _expectTerminalWork(
  List<PreparedInteractionApplyWorkEvent> work,
  _TerminalInteractionForm form,
  _PreparedTerminal terminal,
) {
  final hasSelection = form != _TerminalInteractionForm.noOp;
  final terminalEvent = switch (terminal) {
    _PreparedTerminal.consumeThenConsume ||
    _PreparedTerminal.consumeThenDiscard =>
      PreparedInteractionApplyWorkEvent.consumed,
    _PreparedTerminal.discardThenConsume ||
    _PreparedTerminal.discardThenDiscard =>
      PreparedInteractionApplyWorkEvent.discarded,
  };
  expect(work, [
    if (hasSelection)
      PreparedInteractionApplyWorkEvent.selectionBackingTransferred,
    if (hasSelection) PreparedInteractionApplyWorkEvent.prepared,
    PreparedInteractionApplyWorkEvent.ownershipReleased,
    terminalEvent,
  ], reason: '$form $terminal work');
}

// ignore: halstead-volume, source-lines-of-code, maintainability-index, reason: One switch maps every admitted public document form to the real Store owner.
PreparedInteractionApply _prepareTerminalInteraction(
  _TerminalOwners owners,
  _TerminalInteractionForm form,
) {
  late final AcceptedCommitDocument document;
  late final CommitPlan plan;
  late final Set<CanvasElementId> selectedIds;

  switch (form) {
    case _TerminalInteractionForm.materialized:
      document = AcceptedMaterializedDocument(
        document: _terminalMaterializedDocument(owners.store),
        revisionDelta: _terminalMaterializedDelta,
      );
      selectedIds = {CanvasElementId('e0')};
      plan = _terminalPlan(
        revisionDelta: _terminalMaterializedDelta,
        selectedIds: selectedIds,
      );
    case _TerminalInteractionForm.materializedStore:
      final prepared = owners.store.prepareMaterializedCommit(
        _terminalMaterializedDocument(owners.store),
        _terminalMaterializedDelta,
      );
      document = AcceptedMaterializedStoreDocument(commit: prepared);
      selectedIds = {CanvasElementId('e0')};
      plan = _terminalPlan(
        revisionDelta: prepared.revisionDelta,
        selectedIds: selectedIds,
      );
    case _TerminalInteractionForm.replacement:
      document = AcceptedMaterializedDocument(
        document: _terminalReplacementDocument(),
        revisionDelta: const StoreRevisionDelta.documentReplacement(),
      );
      selectedIds = {CanvasElementId('e7')};
      plan = _terminalPlan(
        revisionDelta: const StoreRevisionDelta.documentReplacement(),
        selectedIds: selectedIds,
        documentReplaced: true,
      );
    case _TerminalInteractionForm.sparse:
      final prepared = owners.store.prepareSparseCommit(
        StoreSparseCommit(
          mutations: [
            const StoreSparseSetBackground(
              CanvasBackground(color: Color(0xFF204060)),
            ),
            StoreSparseEnsureLayer(CanvasLayerId('l0')),
            StoreSparseAddElement(
              layerId: CanvasLayerId('l0'),
              element: CanvasRectElement(
                id: CanvasElementId('e0'),
                size: const Size(2, 2),
              ),
            ),
            StoreSparseUpsertResource(_terminalResource('r0')),
          ],
          revisionDelta: _terminalSparseDelta,
        ),
      );
      document = AcceptedSparseStoreDocument(commit: prepared);
      selectedIds = {CanvasElementId('e0')};
      plan = _terminalPlan(
        revisionDelta: prepared.revisionDelta,
        selectedIds: selectedIds,
      );
    case _TerminalInteractionForm.selectionOnly:
      document = const AcceptedUnchangedStoreDocument();
      selectedIds = {CanvasElementId('rect-1')};
      plan = _terminalPlan(
        revisionDelta: const StoreRevisionDelta(),
        selectedIds: selectedIds,
      );
    case _TerminalInteractionForm.noOp:
      document = const AcceptedUnchangedStoreDocument();
      selectedIds = const {};
      plan = CommitPlan.empty();
  }

  return const CommitApplier().prepareInteraction(
    document: document,
    plan: plan,
    documentInstallers: CommitDocumentInstallers(
      prepareDocumentInstall: (prepared, {required documentReplaced}) =>
          _prepareTerminalDocumentInstall(
            owners.store,
            prepared,
            documentReplaced: documentReplaced,
          ),
    ),
    selectionInstallers: CommitSelectionInstallers(
      prepareSelectionEffect: (effect, prepared) {
        final normalized = _normalizeTerminalSelection(
          owners.store,
          prepared,
          (effect as ReplaceSelectionEffect).elementIds,
        );
        return owners.selection.prepareEffect(normalized);
      },
      installSelectionEffect: owners.selection.installPreparedEffect,
    ),
  );
}

CommitPlan _terminalPlan({
  required StoreRevisionDelta revisionDelta,
  required Set<CanvasElementId> selectedIds,
  bool documentReplaced = false,
}) => CommitPlan(
  revisionDelta: revisionDelta,
  touchedSet: TouchedSet(selection: true, documentReplaced: documentReplaced),
  selectionEffect: ReplaceSelectionEffect(selectedIds),
);

void Function() _prepareTerminalDocumentInstall(
  DocumentStoreKernel store,
  PreparedCommitDocument document, {
  required bool documentReplaced,
}) => switch (document) {
  PreparedMaterializedDocument(:final document, :final revisionDelta) =>
    (documentReplaced
            ? store.prepareReplacementDocumentInstall(document, revisionDelta)
            : store.prepareDocumentInstall(document, revisionDelta))
        .consume,
  PreparedSparseStoreDocument(:final commit) =>
    store.prepareSparseInstall(commit).consume,
  PreparedMaterializedStoreDocument(:final commit) =>
    store.preparePreparedMaterializedInstall(commit).consume,
  PreparedUnchangedStoreDocument() => () => 0,
};

Set<CanvasElementId> _normalizeTerminalSelection(
  DocumentStoreKernel store,
  PreparedCommitDocument document,
  Iterable<CanvasElementId> ids,
) => switch (document) {
  PreparedMaterializedDocument(:final document) =>
    store.normalizeSelectionForCommittedDocument(document, ids),
  PreparedSparseStoreDocument(:final commit) =>
    store.normalizeSelectionForSparseCommit(commit, ids),
  PreparedMaterializedStoreDocument(:final commit) =>
    store.normalizeSelectionForCommittedDocument(commit.document, ids),
  PreparedUnchangedStoreDocument() => store.normalizeSelection(ids),
};

CanvasDocument _terminalMaterializedDocument(DocumentStoreKernel store) {
  final base = store.readDocument();
  return CanvasDocument(
    camera: base.camera,
    background: const CanvasBackground(color: Color(0xFF102030)),
    palette: base.palette,
    metadata: base.metadata,
    resources: [...base.resources, _terminalResource('r0')],
    backgroundElements: base.backgroundElements,
    layers: [
      ...base.layers,
      CanvasLayer(
        id: CanvasLayerId('l0'),
        elements: [
          CanvasRectElement(id: CanvasElementId('e0'), size: const Size(2, 2)),
        ],
      ),
    ],
  );
}

CanvasDocument _terminalReplacementDocument() => CanvasDocument(
  resources: [_terminalResource('r7')],
  layers: [
    CanvasLayer(
      id: CanvasLayerId('l7'),
      elements: [
        CanvasRectElement(id: CanvasElementId('e7'), size: const Size(2, 2)),
      ],
    ),
  ],
);

CanvasImageResource _terminalResource(String id) => CanvasImageResource(
  id: CanvasResourceId(id),
  source: CanvasResourceSource.appKey('terminal-$id'),
);

const _terminalMaterializedDelta = StoreRevisionDelta(
  document: true,
  projection: true,
  structural: true,
  bounds: true,
  elementVisual: true,
  background: true,
  grid: true,
  resource: true,
);

const _terminalSparseDelta = StoreRevisionDelta(
  document: true,
  projection: true,
  structural: true,
  bounds: true,
  elementVisual: true,
  background: true,
  resource: true,
);

void _expectTerminalConsume(
  _TerminalOwners owners,
  _TerminalOwnerSnapshot before,
  _TerminalInteractionForm form,
) {
  final expected = _TerminalExpected.forForm(form);
  expected.expectInstalled(owners, before, form);
}

enum _TerminalInteractionForm {
  materialized,
  materializedStore,
  replacement,
  sparse,
  selectionOnly,
  noOp,
}

enum _PreparedTerminal {
  consumeThenConsume,
  discardThenConsume,
  consumeThenDiscard,
  discardThenDiscard,
}

final class _TerminalOwners {
  _TerminalOwners(_TerminalInteractionForm form)
    : store = documentStoreWithDocument(interactionCommitBaseDocument()),
      selection = SelectionKernel(membership: const _TerminalMembership()) {
    if (form == _TerminalInteractionForm.replacement) {
      store.generateElementId();
      store.generateLayerId();
      store.generateResourceId();
    }
  }

  final DocumentStoreKernel store;
  final SelectionKernel selection;
}

// ignore: coupling-between-object-classes, reason: The terminal oracle deliberately names all committed owner facts that one terminal must preserve.
final class _TerminalExpected {
  const _TerminalExpected({
    required this.documentChanged,
    required this.selection,
    required this.nextElementId,
    required this.nextLayerId,
    required this.nextResourceId,
    required this.gridChanged,
    this.elementId,
    this.layerId,
    this.resourceId,
  });

  // ignore: halstead-volume, source-lines-of-code, reason: The finite form map keeps independent literal expected owner facts beside its terminal cases.
  factory _TerminalExpected.forForm(_TerminalInteractionForm form) =>
      switch (form) {
        _TerminalInteractionForm.materialized ||
        _TerminalInteractionForm.materializedStore => _TerminalExpected(
          documentChanged: true,
          selection: {CanvasElementId('e0')},
          nextElementId: CanvasElementId('e1'),
          nextLayerId: CanvasLayerId('l1'),
          nextResourceId: CanvasResourceId('r1'),
          gridChanged: form == _TerminalInteractionForm.materialized,
          elementId: CanvasElementId('e0'),
          layerId: CanvasLayerId('l0'),
          resourceId: CanvasResourceId('r0'),
        ),
        _TerminalInteractionForm.sparse => _TerminalExpected(
          documentChanged: true,
          selection: {CanvasElementId('e0')},
          nextElementId: CanvasElementId('e1'),
          nextLayerId: CanvasLayerId('l1'),
          nextResourceId: CanvasResourceId('r1'),
          gridChanged: false,
          elementId: CanvasElementId('e0'),
          layerId: CanvasLayerId('l0'),
          resourceId: CanvasResourceId('r0'),
        ),
        _TerminalInteractionForm.replacement => _TerminalExpected(
          documentChanged: true,
          selection: {CanvasElementId('e7')},
          nextElementId: CanvasElementId('e0'),
          nextLayerId: CanvasLayerId('l0'),
          nextResourceId: CanvasResourceId('r0'),
          gridChanged: true,
          elementId: CanvasElementId('e7'),
          layerId: CanvasLayerId('l7'),
          resourceId: CanvasResourceId('r7'),
        ),
        _TerminalInteractionForm.selectionOnly => _TerminalExpected(
          documentChanged: false,
          selection: {CanvasElementId('rect-1')},
          nextElementId: CanvasElementId('e0'),
          nextLayerId: CanvasLayerId('l0'),
          nextResourceId: CanvasResourceId('r0'),
          gridChanged: false,
        ),
        _TerminalInteractionForm.noOp => _TerminalExpected(
          documentChanged: false,
          selection: {},
          nextElementId: CanvasElementId('e0'),
          nextLayerId: CanvasLayerId('l0'),
          nextResourceId: CanvasResourceId('r0'),
          gridChanged: false,
        ),
      };

  final bool documentChanged;
  final Set<CanvasElementId> selection;
  final CanvasElementId nextElementId;
  final CanvasLayerId nextLayerId;
  final CanvasResourceId nextResourceId;
  final bool gridChanged;
  final CanvasElementId? elementId;
  final CanvasLayerId? layerId;
  final CanvasResourceId? resourceId;

  // ignore: cyclomatic-complexity, halstead-volume, source-lines-of-code, maintainability-index, reason: One snapshot assertion must compare every Store, Selection, and ID owner fact after a terminal.
  void expectInstalled(
    _TerminalOwners owners,
    _TerminalOwnerSnapshot before,
    _TerminalInteractionForm form,
  ) {
    expect(
      owners.store.documentRevision,
      documentChanged ? before.documentRevision + 1 : before.documentRevision,
      reason: '$form document revision',
    );
    expect(
      owners.store.structuralRevision,
      documentChanged
          ? before.structuralRevision + 1
          : before.structuralRevision,
      reason: '$form structural revision',
    );
    expect(
      owners.store.boundsRevision,
      documentChanged ? before.boundsRevision + 1 : before.boundsRevision,
      reason: '$form bounds revision',
    );
    expect(
      owners.store.elementVisualRevision,
      documentChanged
          ? before.elementVisualRevision + 1
          : before.elementVisualRevision,
      reason: '$form visual revision',
    );
    expect(
      owners.store.backgroundRevision,
      documentChanged
          ? before.backgroundRevision + 1
          : before.backgroundRevision,
      reason: '$form background revision',
    );
    expect(
      owners.store.gridRevision,
      gridChanged ? before.gridRevision + 1 : before.gridRevision,
      reason: '$form grid revision',
    );
    expect(
      owners.store.resourceRevision,
      documentChanged ? before.resourceRevision + 1 : before.resourceRevision,
      reason: '$form resource revision',
    );
    expect(
      owners.selection.selectionFacts.selectionRevision,
      selection.isEmpty
          ? before.selectionRevision
          : before.selectionRevision + 1,
      reason: '$form selection revision',
    );
    expect(
      owners.selection.selectedElementIds,
      selection,
      reason: '$form selection',
    );
    expect(
      owners.store.readElementIdCandidate(),
      nextElementId,
      reason: '$form element candidate',
    );
    expect(
      owners.store.readLayerIdCandidate(),
      nextLayerId,
      reason: '$form layer candidate',
    );
    expect(
      owners.store.readResourceIdCandidate(),
      nextResourceId,
      reason: '$form resource candidate',
    );
    final elementId = this.elementId;
    if (elementId != null) {
      expect(owners.store.elementById(elementId), isNotNull);
    }
    final layerId = this.layerId;
    if (layerId != null) {
      expect(
        owners.store.readDocument().layers.map((layer) => layer.id),
        contains(layerId),
      );
    }
    final resourceId = this.resourceId;
    if (resourceId != null) {
      expect(owners.store.resourceById(resourceId), isNotNull);
    }
  }
}

final class _TerminalMembership implements SelectionMembershipPort {
  const _TerminalMembership();

  @override
  Set<CanvasElementId> normalizeSelection(Iterable<CanvasElementId> ids) =>
      Set.unmodifiable(ids);

  @override
  Set<CanvasElementId> selectAllElementIds({required bool onlySelectable}) =>
      const {};
}

final class _TerminalOwnerSnapshot {
  const _TerminalOwnerSnapshot({
    required this.document,
    required this.documentRevision,
    required this.structuralRevision,
    required this.boundsRevision,
    required this.elementVisualRevision,
    required this.backgroundRevision,
    required this.gridRevision,
    required this.resourceRevision,
    required this.selectedIds,
    required this.selectionRevision,
    required this.nextElementId,
    required this.nextLayerId,
    required this.nextResourceId,
  });

  factory _TerminalOwnerSnapshot.capture(_TerminalOwners owners) =>
      _TerminalOwnerSnapshot(
        document: owners.store.readDocument(),
        documentRevision: owners.store.documentRevision,
        structuralRevision: owners.store.structuralRevision,
        boundsRevision: owners.store.boundsRevision,
        elementVisualRevision: owners.store.elementVisualRevision,
        backgroundRevision: owners.store.backgroundRevision,
        gridRevision: owners.store.gridRevision,
        resourceRevision: owners.store.resourceRevision,
        selectedIds: owners.selection.selectedElementIds,
        selectionRevision: owners.selection.selectionFacts.selectionRevision,
        nextElementId: owners.store.readElementIdCandidate(),
        nextLayerId: owners.store.readLayerIdCandidate(),
        nextResourceId: owners.store.readResourceIdCandidate(),
      );

  final CanvasDocument document;
  final int documentRevision;
  final int structuralRevision;
  final int boundsRevision;
  final int elementVisualRevision;
  final int backgroundRevision;
  final int gridRevision;
  final int resourceRevision;
  final Set<CanvasElementId> selectedIds;
  final int selectionRevision;
  final CanvasElementId nextElementId;
  final CanvasLayerId nextLayerId;
  final CanvasResourceId nextResourceId;

  void expectUnchanged(_TerminalOwners owners) {
    expect(owners.store.readDocument(), same(document));
    expect(owners.store.documentRevision, documentRevision);
    expect(owners.store.structuralRevision, structuralRevision);
    expect(owners.store.boundsRevision, boundsRevision);
    expect(owners.store.elementVisualRevision, elementVisualRevision);
    expect(owners.store.backgroundRevision, backgroundRevision);
    expect(owners.store.gridRevision, gridRevision);
    expect(owners.store.resourceRevision, resourceRevision);
    expect(owners.selection.selectedElementIds, selectedIds);
    expect(
      owners.selection.selectionFacts.selectionRevision,
      selectionRevision,
    );
    expect(owners.store.readElementIdCandidate(), nextElementId);
    expect(owners.store.readLayerIdCandidate(), nextLayerId);
    expect(owners.store.readResourceIdCandidate(), nextResourceId);
  }
}
