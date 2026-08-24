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
import 'package:iwb_canvas_engine/src/store/committed_document.dart';
import 'package:iwb_canvas_engine/src/store/document_store_kernel.dart';
import 'package:iwb_canvas_engine/src/store/sparse_store_commit.dart';
import 'package:iwb_canvas_engine/src/store/store_commit_finalization.dart';
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

  test('selection preparation failure rolls back before sparse install', () {
    expect(_verifySelectionPreparationFailureRollsBack, returnsNormally);
  });

  test('materialized apply shares one committed document with selection', () {
    expect(_verifyMaterializedApplyUsesOneCommittedDocument, returnsNormally);
  });

  test('document branch preserves its pre- and post-install boundary', () {
    expect(_verifyDocumentBranchAtomicity, returnsNormally);
  });

  test('selection-only and no-op apply never touch store installers', () {
    expect(_verifySelectionOnlyAndNoOpAvoidStoreInstallers, returnsNormally);
  });

  test('stale sparse preparation fails before every installer', () {
    expect(_verifyStaleSparsePreparationFailsBeforeInstallers, returnsNormally);
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

void _verifySelectionPreparationFailureRollsBack() {
  final proof = _SparseSelectionCommitProof();
  final before = _CommitApplyOwnerSnapshot.capture(
    proof.store,
    proof.selection,
    proof.events,
  );

  expect(proof.applyWithThrowingPreparation, throwsStateError);

  before.expectUnchanged(
    proof.store,
    proof.selection,
    proof.events,
    eventSuffix: ['prepare-selection'],
  );
  expect(proof.store.elementById(CanvasElementId('a')), isNotNull);
}

void _verifyStaleSparsePreparationFailsBeforeInstallers() {
  final proof = _SparseSelectionCommitProof();
  proof.makePreparedCommitStale();
  final before = _CommitApplyOwnerSnapshot.capture(
    proof.store,
    proof.selection,
    proof.events,
  );

  expect(proof.apply, throwsStateError);

  before.expectUnchanged(
    proof.store,
    proof.selection,
    proof.events,
    eventSuffix: ['prepare-selection'],
  );
  expect(proof.store.elementById(CanvasElementId('a')), isNotNull);
}

// Identity and caller-alias observations share the materialized apply trace,
// which keeps the one construction and one sealed action list directly visible.
// ignore: halstead-volume
void _verifyMaterializedApplyUsesOneCommittedDocument() {
  final sourceActionIntents = [_clearIntent()];
  final replacementPlan = CommitPlan(
    revisionDelta: const StoreRevisionDelta.structural(),
    touchedSet: TouchedSet(documentReplaced: true, selection: true),
    selectionEffect: ReplaceSelectionEffect([CanvasElementId('selected')]),
    actionIntents: sourceActionIntents,
  );
  final replacementResult = _expectMaterializedDocumentIdentity(
    replacementPlan,
  );
  sourceActionIntents.clear();
  expect(replacementResult.actionIntents, same(replacementPlan.actionIntents));
  expect(
    replacementResult.actionIntents.single,
    isA<ClearContentActionIntent>(),
  );
  expect(
    () => replacementResult.actionIntents.add(_clearIntent()),
    throwsUnsupportedError,
  );

  _expectMaterializedDocumentIdentity(
    CommitPlan(
      revisionDelta: const StoreRevisionDelta.structural(),
      touchedSet: TouchedSet(selection: true),
      selectionEffect: ReplaceSelectionEffect([CanvasElementId('selected')]),
    ),
  );
  _expectPreparedMaterializedStoreIdentity();
}

// Both materialized installer branches share this trace, so selection and the
// selected installer must observe the one aggregate construction identity.
// ignore: halstead-volume, source-lines-of-code
CommitDeliveryResult _expectMaterializedDocumentIdentity(CommitPlan plan) {
  Object? selectionDocument;
  Object? installedDocument;
  final aggregateEvents = <StoreSparseCandidateEventKind>[];

  final result = CommittedDocument.observeSparseCandidateEvents(
    (event) {
      aggregateEvents.add(event.kind);
    },
    () {
      return const CommitApplier().apply(
        document: AcceptedMaterializedDocument(
          document: CanvasDocument(),
          revisionDelta: const StoreRevisionDelta.structural(),
        ),
        plan: plan,
        documentInstallers: CommitDocumentInstallers(
          installDocument: (document, _) {
            if (plan.documentReplaced) {
              fail('Replacement reached the ordinary document installer.');
            }
            installedDocument = document;
          },
          replaceDocument: (document, _) {
            if (!plan.documentReplaced) {
              fail('Ordinary installation reached the replacement installer.');
            }
            installedDocument = document;
          },
          installSparseCommit: (_) => fail('Unexpected sparse install.'),
          installPreparedMaterializedCommit: (_) =>
              fail('Unexpected prepared materialized install.'),
        ),
        selectionInstallers: CommitSelectionInstallers(
          prepareSelectionEffect: (_, document) {
            selectionDocument =
                (document as PreparedMaterializedDocument).document;

            return PreparedSelectionEffect([CanvasElementId('selected')]);
          },
          installSelectionEffect: (_) => true,
        ),
      );
    },
  );

  expect(aggregateEvents, [StoreSparseCandidateEventKind.aggregatePublication]);
  expect(selectionDocument, same(installedDocument));

  return result;
}

// This compact prepared-DTO trace keeps selection and installer identities in
// one apply witness without a second fixture or a subtype-inventory helper.
// ignore: halstead-volume, source-lines-of-code
void _expectPreparedMaterializedStoreIdentity() {
  final store = documentStoreWithDocument(_document());
  final prepared = _prepareMaterializedBackgroundChange(store);
  PreparedMaterializedStoreCommit? selectionCommit;
  PreparedMaterializedStoreCommit? installedCommit;

  const CommitApplier().apply(
    document: AcceptedMaterializedStoreDocument(commit: prepared),
    plan: CommitPlan(
      revisionDelta: prepared.revisionDelta,
      touchedSet: TouchedSet(selection: true),
      selectionEffect: ReplaceSelectionEffect([CanvasElementId('selected')]),
    ),
    documentInstallers: CommitDocumentInstallers(
      installDocument: (_, _) => fail('Unexpected document install.'),
      replaceDocument: (_, _) => fail('Unexpected replacement.'),
      installSparseCommit: (_) => fail('Unexpected sparse install.'),
      installPreparedMaterializedCommit: (commit) {
        installedCommit = commit;
      },
    ),
    selectionInstallers: CommitSelectionInstallers(
      prepareSelectionEffect: (_, document) {
        selectionCommit =
            (document as PreparedMaterializedStoreDocument).commit;

        return PreparedSelectionEffect([CanvasElementId('selected')]);
      },
      installSelectionEffect: (_) => true,
    ),
  );

  expect(prepared.hasChanges, isTrue);
  expect(selectionCommit, same(prepared));
  expect(installedCommit, same(prepared));
}

PreparedMaterializedStoreCommit _prepareMaterializedBackgroundChange(
  DocumentStoreKernel store,
) {
  final base = store.readDocument();

  return store.prepareMaterializedCommit(
    CanvasDocument(
      camera: base.camera,
      background: const CanvasBackground(color: Color(0xFF102030)),
      palette: base.palette,
      metadata: base.metadata,
      resources: base.resources,
      backgroundElements: base.backgroundElements,
      layers: base.layers,
    ),
    const StoreRevisionDelta.background(),
  );
}

void _verifyDocumentBranchAtomicity() {
  _expectMaterializedConstructionFailurePreservesOwners();
  _expectDeliveryPreparationFailurePreservesOwners();
  _expectPreparedMaterializedStaleFailurePreservesOwners();
  _expectDocumentInstallSurvivesSelectionFailure();
}

// Materialized commits fail through a different condition than sparse commits.
// This keeps that failure beside the snapshot taken after the deliberate advance.
// ignore: halstead-volume, source-lines-of-code
void _expectPreparedMaterializedStaleFailurePreservesOwners() {
  final store = documentStoreWithDocument(_document());
  final selection = _selectionKernel()..setSelection([CanvasElementId('a')]);
  final events = <String>[];
  final prepared = _prepareMaterializedBackgroundChange(store);
  store.installDocument(
    CommittedDocument(_document()),
    const StoreRevisionDelta.structural(),
  );
  final before = _CommitApplyOwnerSnapshot.capture(store, selection, events);

  expect(
    () => const CommitApplier().apply(
      document: AcceptedMaterializedStoreDocument(commit: prepared),
      plan: CommitPlan(
        revisionDelta: prepared.revisionDelta,
        touchedSet: TouchedSet(selection: true),
        selectionEffect: ReplaceSelectionEffect([CanvasElementId('b')]),
      ),
      documentInstallers: CommitDocumentInstallers(
        installDocument: (_, _) => fail('Unexpected document install.'),
        replaceDocument: (_, _) => fail('Unexpected replacement.'),
        installSparseCommit: (_) => fail('Unexpected sparse install.'),
        installPreparedMaterializedCommit: (commit) {
          events.add('prepared-materialized-document');
          store.installPreparedMaterializedCommit(commit);
        },
      ),
      selectionInstallers: CommitSelectionInstallers(
        prepareSelectionEffect: (_, _) {
          events.add('prepare-selection');

          return PreparedSelectionEffect([CanvasElementId('b')]);
        },
        installSelectionEffect: (_) {
          events.add('selection');
          fail('Stale materialized commit reached selection installation.');
        },
      ),
    ),
    throwsA(
      isA<StateError>().having(
        (error) => error.toString(),
        'message',
        contains('Prepared materialized store commit is stale.'),
      ),
    ),
  );

  before.expectUnchanged(
    store,
    selection,
    events,
    eventSuffix: ['prepare-selection', 'prepared-materialized-document'],
  );
}

// This one trace must keep Store/admission installation, selection failure, and
// retained-owner observations adjacent to prove that order and no rollback.
// ignore: halstead-volume, source-lines-of-code
void _expectDocumentInstallSurvivesSelectionFailure() {
  final store = DocumentStoreKernel();
  final selection = _selectionKernel()..setSelection([CanvasElementId('a')]);
  final events = <String>[];

  expect(
    () => const CommitApplier().apply(
      document: AcceptedMaterializedDocument(
        document: CanvasDocument(
          layers: [
            CanvasLayer(
              id: CanvasLayerId('layer-1'),
              elements: [
                CanvasRectElement(
                  id: CanvasElementId('e0'),
                  size: const Size(1, 1),
                ),
              ],
            ),
          ],
        ),
        revisionDelta: const StoreRevisionDelta.structural(),
      ),
      plan: CommitPlan(
        revisionDelta: const StoreRevisionDelta.structural(),
        touchedSet: TouchedSet(selection: true),
        selectionEffect: ReplaceSelectionEffect([CanvasElementId('e0')]),
      ),
      documentInstallers: CommitDocumentInstallers(
        installDocument: (document, delta) {
          events.add('document');
          store.installDocument(document, delta);
        },
        replaceDocument: (_, _) => fail('Unexpected replacement.'),
        installSparseCommit: (_) => fail('Unexpected sparse install.'),
        installPreparedMaterializedCommit: (_) =>
            fail('Unexpected prepared materialized install.'),
      ),
      selectionInstallers: CommitSelectionInstallers(
        prepareSelectionEffect: (_, _) {
          events.add('prepare-selection');

          return PreparedSelectionEffect([CanvasElementId('e0')]);
        },
        installSelectionEffect: (_) {
          events.add('selection');
          throw StateError('prepared selection install failed');
        },
      ),
    ),
    throwsStateError,
  );

  expect(events, ['prepare-selection', 'document', 'selection']);
  expect(store.readDocument().layers.single.elements.single.id.value, 'e0');
  expect(store.documentRevision, 1);
  expect(store.readElementIdCandidate().value, 'e1');
  expect(selection.selectedElementIds, {CanvasElementId('a')});
}

// Aggregate construction and the exact unchanged snapshot share one witness so
// a constructor moved after any installer cannot produce a false green result.
// ignore: halstead-volume
void _expectMaterializedConstructionFailurePreservesOwners() {
  final store = DocumentStoreKernel();
  final selection = _selectionKernel()..setSelection([CanvasElementId('a')]);
  final events = <String>[];
  final before = _CommitApplyOwnerSnapshot.capture(store, selection, events);
  final aggregateEvents = <StoreSparseCandidateEventKind>[];

  expect(
    () => CommittedDocument.observeSparseCandidateEvents(
      (event) {
        aggregateEvents.add(event.kind);
        if (event.kind == StoreSparseCandidateEventKind.aggregatePublication) {
          throw StateError('materialized construction failed');
        }
      },
      () {
        const CommitApplier().apply(
          document: AcceptedMaterializedDocument(
            document: CanvasDocument(),
            revisionDelta: const StoreRevisionDelta.structural(),
          ),
          plan: CommitPlan(
            revisionDelta: const StoreRevisionDelta.structural(),
            touchedSet: TouchedSet(),
          ),
          documentInstallers: const CommitDocumentInstallers(
            installDocument: _unexpectedDocumentInstall,
            replaceDocument: _unexpectedDocumentInstall,
            installSparseCommit: _unexpectedSparseInstall,
            installPreparedMaterializedCommit: _unexpectedMaterializedInstall,
          ),
          selectionInstallers: const CommitSelectionInstallers(
            prepareSelectionEffect: _unexpectedSelectionPreparation,
            installSelectionEffect: _unexpectedSelectionInstall,
          ),
        );
      },
    ),
    throwsStateError,
  );

  before.expectUnchanged(store, selection, events);
  expect(aggregateEvents, [StoreSparseCandidateEventKind.aggregatePublication]);
}

// The cumulative work observer reports sealing before any installer, so this
// direct CommitApplier witness keeps the independent pre-install boundary.
// ignore: halstead-volume
void _expectDeliveryPreparationFailurePreservesOwners() {
  final store = DocumentStoreKernel();
  final selection = _selectionKernel()..setSelection([CanvasElementId('a')]);
  final events = <String>[];
  final before = _CommitApplyOwnerSnapshot.capture(store, selection, events);
  var preparationCalls = 0;

  expect(
    () => CommitApplier.observeSealedDeliveryWork(
      (work) {
        preparationCalls = work.preparations;
        throw StateError('delivery preparation failed');
      },
      () {
        const CommitApplier().apply(
          document: AcceptedMaterializedDocument(
            document: CanvasDocument(),
            revisionDelta: const StoreRevisionDelta.structural(),
          ),
          plan: CommitPlan(
            revisionDelta: const StoreRevisionDelta.structural(),
            touchedSet: TouchedSet(),
            effects: const [ProjectionEffect()],
          ),
          documentInstallers: const CommitDocumentInstallers(
            installDocument: _unexpectedDocumentInstall,
            replaceDocument: _unexpectedDocumentInstall,
            installSparseCommit: _unexpectedSparseInstall,
            installPreparedMaterializedCommit: _unexpectedMaterializedInstall,
          ),
          selectionInstallers: const CommitSelectionInstallers(
            prepareSelectionEffect: _unexpectedSelectionPreparation,
            installSelectionEffect: _unexpectedSelectionInstall,
          ),
        );
      },
    ),
    throwsStateError,
  );

  expect(preparationCalls, 1);
  before.expectUnchanged(store, selection, events);
}

void _unexpectedDocumentInstall(CommittedDocument _, StoreRevisionDelta _) {
  fail('Pre-install failure reached the document installer.');
}

void _unexpectedSparseInstall(PreparedSparseStoreCommit _) {
  fail('Pre-install failure reached the sparse installer.');
}

void _unexpectedMaterializedInstall(PreparedMaterializedStoreCommit _) {
  fail('Pre-install failure reached the materialized installer.');
}

PreparedSelectionEffect _unexpectedSelectionPreparation(
  CommitSelectionEffect _,
  PreparedCommitDocument _,
) => fail('Pre-install failure reached selection preparation.');

bool _unexpectedSelectionInstall(PreparedSelectionEffect _) {
  fail('Pre-install failure reached selection installation.');
}

// Shared installer sentinels keep effective, failed, and no-op selection traces
// together, so each one proves the same Store boundary without duplicate setup.
// ignore: halstead-volume, source-lines-of-code, maintainability-index
void _verifySelectionOnlyAndNoOpAvoidStoreInstallers() {
  final store = documentStoreWithDocument(_document());
  final selection = _selectionKernel()..setSelection([CanvasElementId('a')]);
  final events = <String>[];
  final installers = CommitDocumentInstallers(
    installDocument: (_, _) => fail('Selection-only apply touched Store.'),
    replaceDocument: (_, _) => fail('Selection-only apply touched Store.'),
    installSparseCommit: (_) => fail('Selection-only apply touched Store.'),
    installPreparedMaterializedCommit: (_) =>
        fail('Selection-only apply touched Store.'),
  );
  final selectionInstallers = CommitSelectionInstallers(
    prepareSelectionEffect: (_, _) {
      events.add('prepare-selection');

      return PreparedSelectionEffect([CanvasElementId('b')]);
    },
    installSelectionEffect: (effect) {
      events.add('selection');

      return selection.installPreparedEffect(effect);
    },
  );

  final selectionOnly = const CommitApplier().apply(
    document: const AcceptedUnchangedStoreDocument(),
    plan: CommitPlan.replaceSelection(elementIds: [CanvasElementId('b')]),
    documentInstallers: installers,
    selectionInstallers: selectionInstallers,
  );

  expect(events, ['prepare-selection', 'selection']);
  expect(selectionOnly.shouldPublishState, isTrue);
  expect(selection.selectedElementIds, {CanvasElementId('b')});

  final beforePreparationFailure = _CommitApplyOwnerSnapshot.capture(
    store,
    selection,
    events,
  );
  expect(
    () => const CommitApplier().apply(
      document: const AcceptedUnchangedStoreDocument(),
      plan: CommitPlan.replaceSelection(elementIds: [CanvasElementId('a')]),
      documentInstallers: installers,
      selectionInstallers: CommitSelectionInstallers(
        prepareSelectionEffect: (_, _) {
          events.add('prepare-selection');
          throw StateError('selection-only preparation failed');
        },
        installSelectionEffect: (_) =>
            fail('Selection-only preparation reached installation.'),
      ),
    ),
    throwsStateError,
  );
  beforePreparationFailure.expectUnchanged(
    store,
    selection,
    events,
    eventSuffix: ['prepare-selection'],
  );

  final beforeInstallFailure = _CommitApplyOwnerSnapshot.capture(
    store,
    selection,
    events,
  );
  expect(
    () => const CommitApplier().apply(
      document: const AcceptedUnchangedStoreDocument(),
      plan: CommitPlan.replaceSelection(elementIds: [CanvasElementId('a')]),
      documentInstallers: installers,
      selectionInstallers: CommitSelectionInstallers(
        prepareSelectionEffect: (_, _) {
          events.add('prepare-selection');

          return PreparedSelectionEffect([CanvasElementId('a')]);
        },
        installSelectionEffect: (_) {
          events.add('selection');
          throw StateError('selection-only installation failed');
        },
      ),
    ),
    throwsStateError,
  );
  beforeInstallFailure.expectUnchanged(
    store,
    selection,
    events,
    eventSuffix: ['prepare-selection', 'selection'],
  );

  final selectionNoOp = const CommitApplier().apply(
    document: const AcceptedUnchangedStoreDocument(),
    plan: CommitPlan.replaceSelection(
      elementIds: [CanvasElementId('b')],
      actionIntents: [_clearIntent()],
    ),
    documentInstallers: installers,
    selectionInstallers: selectionInstallers,
  );

  expect(events, [
    'prepare-selection',
    'selection',
    'prepare-selection',
    'prepare-selection',
    'selection',
    'prepare-selection',
    'selection',
  ]);
  expect(selectionNoOp.shouldPublishState, isFalse);
  expect(selectionNoOp.effects, isEmpty);
  expect(selectionNoOp.actionIntents, isEmpty);

  final trueNoOp = const CommitApplier().apply(
    document: const AcceptedUnchangedStoreDocument(),
    plan: CommitPlan.empty(),
    documentInstallers: installers,
    selectionInstallers: selectionInstallers,
  );

  expect(events, [
    'prepare-selection',
    'selection',
    'prepare-selection',
    'prepare-selection',
    'selection',
    'prepare-selection',
    'selection',
  ]);
  expect(trueNoOp.shouldPublishState, isFalse);
  expect(trueNoOp.effects, isEmpty);
  expect(trueNoOp.actionIntents, isEmpty);
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
      installPreparedMaterializedCommit: (_) =>
          events.add('prepared-materialized-document'),
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
  PreparedSparseStoreCommit? selectionCommit;
  PreparedSparseStoreCommit? installedCommit;

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
        installPreparedMaterializedCommit: (_) =>
            events.add('prepared-materialized-document'),
      ),
      selectionInstallers: CommitSelectionInstallers(
        prepareSelectionEffect: _prepareSelectionEffect,
        installSelectionEffect: _installSelectionEffect,
      ),
    );
  }

  void applyWithThrowingPreparation() {
    const CommitApplier().apply(
      document: AcceptedSparseStoreDocument(commit: prepared),
      plan: plan,
      documentInstallers: CommitDocumentInstallers(
        installDocument: (_, _) => events.add('document'),
        replaceDocument: (_, _) => events.add('replacement'),
        installSparseCommit: _installSparseCommit,
        installPreparedMaterializedCommit: (_) =>
            events.add('prepared-materialized-document'),
      ),
      selectionInstallers: CommitSelectionInstallers(
        prepareSelectionEffect: (_, _) {
          events.add('prepare-selection');
          throw StateError('selection preparation failed');
        },
        installSelectionEffect: _installSelectionEffect,
      ),
    );
  }

  void makePreparedCommitStale() {
    final preparedDocumentRevision = prepared.baseRevisions.documentRevision;
    store.installDocument(
      CommittedDocument(_document()),
      const StoreRevisionDelta.structural(),
    );
    if (store.documentRevision == preparedDocumentRevision) {
      fail('Stale sparse preparation setup did not advance Store revisions.');
    }
  }

  void expectAccepted() {
    expect(events, ['prepare-selection', 'sparse-document', 'selection']);
    expect(selection.selectedElementIds, {CanvasElementId('b')});
    expect(store.projectionBuildCount, 0);
    expect(selectionCommit, same(prepared));
    expect(installedCommit, same(prepared));
  }

  void _installSparseCommit(PreparedSparseStoreCommit commit) {
    events.add('sparse-document');
    installedCommit = commit;
    store.installSparseCommit(commit);
  }

  PreparedSelectionEffect _prepareSelectionEffect(
    CommitSelectionEffect effect,
    PreparedCommitDocument document,
  ) {
    events.add('prepare-selection');
    final commit = (document as PreparedSparseStoreDocument).commit;
    selectionCommit = commit;

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

final class _CommitApplyOwnerSnapshot {
  const _CommitApplyOwnerSnapshot({
    required this.document,
    required this.documentRevision,
    required this.structuralRevision,
    required this.boundsRevision,
    required this.elementVisualRevision,
    required this.backgroundRevision,
    required this.gridRevision,
    required this.resourceRevision,
    required this.projectionBuildCount,
    required this.nextElementId,
    required this.selectedElementIds,
    required this.selectionRevision,
    required this.events,
  });

  factory _CommitApplyOwnerSnapshot.capture(
    DocumentStoreKernel store,
    SelectionKernel selection,
    List<String> events,
  ) {
    return _CommitApplyOwnerSnapshot(
      document: store.readDocument(),
      documentRevision: store.documentRevision,
      structuralRevision: store.structuralRevision,
      boundsRevision: store.boundsRevision,
      elementVisualRevision: store.elementVisualRevision,
      backgroundRevision: store.backgroundRevision,
      gridRevision: store.gridRevision,
      resourceRevision: store.resourceRevision,
      projectionBuildCount: store.projectionBuildCount,
      nextElementId: store.readElementIdCandidate(),
      selectedElementIds: selection.selectedElementIds,
      selectionRevision: selection.selectionFacts.selectionRevision,
      events: List.unmodifiable(events),
    );
  }

  final CanvasDocument document;
  final int documentRevision;
  final int structuralRevision;
  final int boundsRevision;
  final int elementVisualRevision;
  final int backgroundRevision;
  final int gridRevision;
  final int resourceRevision;
  final int projectionBuildCount;
  final CanvasElementId nextElementId;
  final Set<CanvasElementId> selectedElementIds;
  final int selectionRevision;
  final List<String> events;

  void expectUnchanged(
    DocumentStoreKernel store,
    SelectionKernel selection,
    List<String> currentEvents, {
    Iterable<String> eventSuffix = const [],
  }) {
    expect(store.readDocument(), document);
    expect(store.documentRevision, documentRevision);
    expect(store.structuralRevision, structuralRevision);
    expect(store.boundsRevision, boundsRevision);
    expect(store.elementVisualRevision, elementVisualRevision);
    expect(store.backgroundRevision, backgroundRevision);
    expect(store.gridRevision, gridRevision);
    expect(store.resourceRevision, resourceRevision);
    expect(store.projectionBuildCount, projectionBuildCount);
    expect(store.readElementIdCandidate(), nextElementId);
    expect(selection.selectedElementIds, selectedElementIds);
    expect(selection.selectionFacts.selectionRevision, selectionRevision);
    expect(currentEvents, [...events, ...eventSuffix]);
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
