import 'dart:ui';
import "../../support/runtime_root_with_committed_document_seed.dart";
import "../../support/document_store_with_document.dart";

// This fixture intentionally names commit, selection, and runtime boundaries in
// one proof surface so prepared-selection ordering is validated end to end.
// ignore_for_file: number-of-imports

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine/src/contracts/internal/commit_action_intent.dart';
import 'package:iwb_canvas_engine/src/contracts/internal/commit_delivery.dart';
import 'package:iwb_canvas_engine/src/contracts/internal/prepared_selection_effect.dart';
import 'package:iwb_canvas_engine/src/contracts/internal/selection_membership_port.dart';
import 'package:iwb_canvas_engine/src/contracts/internal/touched_set.dart';
import 'package:iwb_canvas_engine/src/edit/commit_applier.dart';
import 'package:iwb_canvas_engine/src/edit/commit_plan.dart';
import 'package:iwb_canvas_engine/src/runtime/runtime_root.dart';
import 'package:iwb_canvas_engine/src/selection/selection_kernel.dart';
import 'package:iwb_canvas_engine/src/store/document_store_kernel.dart';
import 'package:iwb_canvas_engine/src/store/sparse_store_commit.dart';
import 'package:iwb_canvas_engine/src/store/store_revision_delta.dart';

void main() {
  test('selection replacement commits without document delta', () {
    expect(_verifySelectionReplacementCommit, returnsNormally);
  });

  test('selection no-op drops effects and action intents', () {
    expect(_verifySelectionNoOpDropsActionIntents, returnsNormally);
  });

  test('accepted delivery carries payload-aware action intents', () {
    expect(_verifyPayloadAwareActionIntents, returnsNormally);
  });

  test('document remove and clear prune selection atomically', () {
    expect(_verifyDocumentEditsPruneSelection, returnsNormally);
  });

  test('prepared selection install does not read membership', () {
    expect(_verifyPreparedSelectionInstallSkipsMembership, returnsNormally);
  });

  test('sparse commit prepares selection from accepted store facts', () {
    expect(_verifySparseCommitPreparesSelectionFromStoreFacts, returnsNormally);
  });
}

void _verifySelectionReplacementCommit() {
  final selection = _selectionKernel()..setSelection([CanvasElementId('a')]);
  final events = <String>[];
  final plan = CommitPlan.replaceSelection(
    elementIds: [CanvasElementId('b'), CanvasElementId('c')],
    actionIntents: [
      SelectMarqueeActionIntent(
        previousSelection: [CanvasElementId('a')],
        nextSelection: [CanvasElementId('b'), CanvasElementId('c')],
        marqueeRectWorld: const Rect.fromLTRB(0, 0, 10, 10),
      ),
    ],
  );

  final result = _applyPlan(plan, selection, events);

  expect(plan.revisionDelta.hasChanges, isFalse);
  expect(events, ['prepare-selection', 'selection']);
  _expectReplacementSelectionInstalled(selection);
  _expectReplacementDelivery(result);
}

void _expectReplacementSelectionInstalled(SelectionKernel selection) {
  expect(selection.selectionFacts.selectedElementIds, {
    CanvasElementId('b'),
    CanvasElementId('c'),
  });
  expect(selection.selectionFacts.selectionRevision, 2);
}

void _expectReplacementDelivery(CommitDeliveryResult result) {
  expect(result.shouldPublishState, isTrue);
  expect(result.effects.whereType<SelectionDeliveryEffect>(), hasLength(1));
  expect(result.effects.whereType<PublicStateDeliveryEffect>(), hasLength(1));
  final intent = result.actionIntents.single as SelectMarqueeActionIntent;
  expect(intent.kind, CommitActionIntentKind.selectMarquee);
  expect(intent.previousSelection, [CanvasElementId('a')]);
  expect(intent.nextSelection, [CanvasElementId('b'), CanvasElementId('c')]);
  expect(intent.elementIds, [CanvasElementId('b'), CanvasElementId('c')]);
  expect(intent.marqueeRectWorld, const Rect.fromLTRB(0, 0, 10, 10));
  expect(
    () => result.actionIntents.add(_clearIntent()),
    throwsUnsupportedError,
  );
}

void _verifySelectionNoOpDropsActionIntents() {
  final selection = _selectionKernel()..setSelection([CanvasElementId('a')]);
  final events = <String>[];
  final plan = CommitPlan.replaceSelection(
    elementIds: [CanvasElementId('a')],
    actionIntents: [
      SelectMarqueeActionIntent(
        previousSelection: [CanvasElementId('a')],
        nextSelection: [CanvasElementId('a')],
        marqueeRectWorld: const Rect.fromLTRB(0, 0, 10, 10),
      ),
    ],
  );

  final result = _applyPlan(plan, selection, events);

  expect(events, ['prepare-selection', 'selection']);
  expect(selection.selectionFacts.selectionRevision, 1);
  expect(result.shouldPublishState, isFalse);
  expect(result.effects, isEmpty);
  expect(result.actionIntents, isEmpty);
}

void _verifyPayloadAwareActionIntents() {
  final selection = _selectionKernel();
  final result = _applyPlan(
    CommitPlan.replaceSelection(
      elementIds: [CanvasElementId('b')],
      actionIntents: _allPayloadAwareIntents(),
    ),
    selection,
    <String>[],
  );

  _expectMoveIntent(result.actionIntents[0]);
  _expectTransformIntent(result.actionIntents[1]);
  _expectDeleteIntent(result.actionIntents[2]);
  _expectRemoveIntent(result.actionIntents[3]);
  _expectClearIntent(result.actionIntents[4]);
}

List<CommitActionIntent> _allPayloadAwareIntents() {
  return [
    MoveSelectionActionIntent(
      elementIds: [CanvasElementId('a')],
      transform: CanvasTransform.translation(const Offset(2, 3)),
    ),
    TransformSelectionActionIntent(
      elementIds: [CanvasElementId('b')],
      transform: CanvasTransform.rotationDegrees(90),
      operation: CanvasTransformOperation.rotateClockwise,
      pivotWorld: const Offset(4, 5),
    ),
    DeleteSelectionActionIntent(
      removedElementIds: [CanvasElementId('a'), CanvasElementId('b')],
    ),
    RemoveElementActionIntent(elementId: CanvasElementId('c')),
    _clearIntent(),
  ];
}

void _expectMoveIntent(CommitActionIntent intent) {
  final move = intent as MoveSelectionActionIntent;
  expect(move.kind, CommitActionIntentKind.moveSelection);
  expect(move.elementIds, [CanvasElementId('a')]);
  expect(move.transform, CanvasTransform.translation(const Offset(2, 3)));
  expect(move.operation, CanvasTransformOperation.move);
  expect(move.pivotWorld, isNull);
  expect(
    () => move.elementIds.add(CanvasElementId('x')),
    throwsUnsupportedError,
  );
}

void _expectTransformIntent(CommitActionIntent intent) {
  final transform = intent as TransformSelectionActionIntent;
  expect(transform.kind, CommitActionIntentKind.transformSelection);
  expect(transform.elementIds, [CanvasElementId('b')]);
  expect(transform.transform, CanvasTransform.rotationDegrees(90));
  expect(transform.operation, CanvasTransformOperation.rotateClockwise);
  expect(transform.pivotWorld, const Offset(4, 5));
}

void _expectDeleteIntent(CommitActionIntent intent) {
  final delete = intent as DeleteSelectionActionIntent;
  expect(delete.kind, CommitActionIntentKind.deleteSelection);
  expect(delete.elementIds, [CanvasElementId('a'), CanvasElementId('b')]);
  expect(delete.removedElementIds, [
    CanvasElementId('a'),
    CanvasElementId('b'),
  ]);
}

void _expectRemoveIntent(CommitActionIntent intent) {
  final remove = intent as RemoveElementActionIntent;
  expect(remove.kind, CommitActionIntentKind.removeElement);
  expect(remove.elementIds, [CanvasElementId('c')]);
  expect(remove.removedElementIds, [CanvasElementId('c')]);
}

void _expectClearIntent(CommitActionIntent intent) {
  final clear = intent as ClearContentActionIntent;
  expect(clear.kind, CommitActionIntentKind.clearContent);
  expect(clear.elementIds, [CanvasElementId('a'), CanvasElementId('b')]);
  expect(clear.removedElementIds, [CanvasElementId('a'), CanvasElementId('b')]);
  expect(clear.removedResourceIds, [CanvasResourceId('r1')]);
}

ClearContentActionIntent _clearIntent() {
  return ClearContentActionIntent(
    removedElementIds: [CanvasElementId('a'), CanvasElementId('b')],
    removedResourceIds: [CanvasResourceId('r1')],
  );
}

void _verifyDocumentEditsPruneSelection() {
  _verifyRemovePrunesSelection();
  _verifyClearPrunesSelection();
}

void _verifyPreparedSelectionInstallSkipsMembership() {
  final selection = SelectionKernel(membership: const _ThrowingMembership());

  expect(
    selection.installPreparedEffect(
      PreparedSelectionEffect([CanvasElementId('prepared')]),
    ),
    isTrue,
  );
  expect(selection.selectedElementIds, {CanvasElementId('prepared')});
}

void _verifySparseCommitPreparesSelectionFromStoreFacts() {
  final proof = _SparseSelectionCommitProof();

  proof.apply();
  proof.expectAccepted();
}

void _verifyRemovePrunesSelection() {
  final root = _runtimeRoot();
  root.selection.setSelection([CanvasElementId('a'), CanvasElementId('b')]);
  final before = root.state.value;

  root.edits.edit((edit) {
    expect(edit.removeElement(CanvasElementId('a')), isTrue);
  });

  expect(root.selectedElementIds, {CanvasElementId('b')});
  expect(root.state.value.revisions.document, before.revisions.document + 1);
  expect(root.state.value.revisions.selection, before.revisions.selection + 1);
}

void _verifyClearPrunesSelection() {
  final root = _runtimeRoot();
  root.selection.setSelection([CanvasElementId('a'), CanvasElementId('b')]);
  final before = root.state.value;

  root.edits.edit((edit) {
    final result = edit.clearContent(removeUnusedResources: true);
    expect(result.didClearContent, isTrue);
  });

  expect(root.selectedElementIds, isEmpty);
  expect(root.state.value.revisions.document, before.revisions.document + 1);
  expect(root.state.value.revisions.selection, before.revisions.selection + 1);
}

CommitDeliveryResult _applyPlan(
  CommitPlan plan,
  SelectionKernel selection,
  List<String> events,
) {
  return const CommitApplier().apply(
    document: AcceptedMaterializedDocument(
      document: CanvasDocument(),
      revisionDelta: plan.revisionDelta,
    ),
    plan: plan,
    documentInstallers: CommitDocumentInstallers(
      installDocument: (_, _) => events.add('document'),
      replaceDocument: (_, _) => events.add('replacement'),
      installSparseCommit: (_) => events.add('sparse-document'),
    ),
    selectionInstallers: CommitSelectionInstallers(
      prepareSelectionEffect: (effect, _) {
        events.add('prepare-selection');

        return switch (effect) {
          PruneSelectionEffect() => PreparedSelectionEffect(
            selection.selectedElementIds,
          ),
          ReplaceSelectionEffect(:final elementIds) => PreparedSelectionEffect(
            elementIds,
          ),
        };
      },
      installSelectionEffect: (effect) {
        events.add('selection');

        return selection.installPreparedEffect(effect);
      },
    ),
  );
}

// This proof object deliberately spans commit, store, and selection owners so
// the sparse accepted-document handoff is tested as one boundary.
// ignore: coupling-between-object-classes
final class _SparseSelectionCommitProof {
  final DocumentStoreKernel store = documentStoreWithDocument(_document());
  final SelectionKernel selection = _selectionKernel()
    ..setSelection([CanvasElementId('a'), CanvasElementId('b')]);
  final List<String> events = [];

  late final PreparedSparseStoreCommit prepared = store.prepareSparseCommit(
    StoreSparseCommit(
      revisionDelta: const StoreRevisionDelta.structural(),
      mutations: [StoreSparseRemoveElement(CanvasElementId('a'))],
    ),
  );

  late final CommitPlan plan = CommitPlan(
    revisionDelta: prepared.revisionDelta,
    touchedSet: TouchedSet(selection: true),
    selectionEffect: const PruneSelectionEffect(),
    effects: const [SelectionEffect(), PublicStateEffect()],
  );

  void apply() {
    const CommitApplier().apply(
      document: AcceptedSparseStoreDocument(commit: prepared),
      plan: plan,
      documentInstallers: CommitDocumentInstallers(
        installDocument: (_, _) => events.add('document'),
        replaceDocument: (_, _) => events.add('replacement'),
        installSparseCommit: _installSparseCommit,
      ),
      selectionInstallers: CommitSelectionInstallers(
        prepareSelectionEffect: _prepareSelectionEffect,
        installSelectionEffect: _installSelectionEffect,
      ),
    );
  }

  void expectAccepted() {
    expect(events, ['prepare-selection', 'sparse-document', 'selection']);
    expect(selection.selectedElementIds, {CanvasElementId('b')});
    expect(store.projectionBuildCount, 0);
  }

  void _installSparseCommit(PreparedSparseStoreCommit commit) {
    events.add('sparse-document');
    store.installSparseCommit(commit);
  }

  PreparedSelectionEffect _prepareSelectionEffect(
    CommitSelectionEffect effect,
    AcceptedCommitDocument document,
  ) {
    events.add('prepare-selection');
    final commit = (document as AcceptedSparseStoreDocument).commit;

    return switch (effect) {
      PruneSelectionEffect() => PreparedSelectionEffect(
        store.normalizeSelectionForSparseCommit(
          commit,
          selection.selectedElementIds,
        ),
      ),
      ReplaceSelectionEffect(:final elementIds) => PreparedSelectionEffect(
        store.normalizeSelectionForSparseCommit(commit, elementIds),
      ),
    };
  }

  bool _installSelectionEffect(PreparedSelectionEffect effect) {
    events.add('selection');

    return selection.installPreparedEffect(effect);
  }
}

RuntimeRoot _runtimeRoot() {
  return runtimeRootWithCommittedDocumentSeed(
    _document(),
    config: const CanvasRuntimeConfig(),
  );
}

SelectionKernel _selectionKernel() {
  return SelectionKernel(membership: const _SelectionMembership());
}

CanvasDocument _document() {
  return CanvasDocument(
    layers: [
      CanvasLayer(
        id: CanvasLayerId('layer-1'),
        elements: [
          CanvasRectElement(id: CanvasElementId('a'), size: const Size(1, 1)),
          CanvasRectElement(id: CanvasElementId('b'), size: const Size(1, 1)),
        ],
      ),
    ],
  );
}

final class _SelectionMembership implements SelectionMembershipPort {
  const _SelectionMembership();

  @override
  Set<CanvasElementId> normalizeSelection(Iterable<CanvasElementId> ids) {
    return Set.unmodifiable(ids);
  }

  @override
  Set<CanvasElementId> selectAllElementIds({required bool onlySelectable}) {
    return {CanvasElementId('a'), CanvasElementId('b'), CanvasElementId('c')};
  }
}

final class _ThrowingMembership implements SelectionMembershipPort {
  const _ThrowingMembership();

  @override
  Set<CanvasElementId> normalizeSelection(Iterable<CanvasElementId> ids) {
    throw StateError('membership should not be read.');
  }

  @override
  Set<CanvasElementId> selectAllElementIds({required bool onlySelectable}) {
    throw StateError('membership should not be read.');
  }
}
