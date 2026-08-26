import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine/src/contracts/internal/commit_delivery.dart';
import 'package:iwb_canvas_engine/src/edit/draft_document.dart';
import 'package:iwb_canvas_engine/src/edit/edit_session.dart';
import 'package:iwb_canvas_engine/src/store/committed_document.dart';
import 'package:iwb_canvas_engine/src/store/sparse_store_commit.dart';

import '../../support/runtime_root_with_committed_document_seed.dart';
import 'sparse_edit_session/sparse_edit_session_support.dart';

void main() {
  _registerFieldMergeTest();
  _registerValidationTest();
  _registerBoundaryApplicationTest();
  _registerSequentialBackingTest();
  _registerStorePathTest();
}

void _registerFieldMergeTest() {
  test('grid updates merge supplied fields from latest local values', () {
    final root = runtimeRootWithCommittedDocumentSeed(_baseDocument());

    root.edits.edit((edit) {
      edit.updateGrid(CanvasGridUpdate(enabled: true));
      edit.updateGrid(CanvasGridUpdate(cellSize: 24));
      edit.updateGrid(CanvasGridUpdate(color: const Color(0xFF010203)));
    });

    expect(
      root.readAppearance().grid,
      CanvasGrid(enabled: true, cellSize: 24, color: const Color(0xFF010203)),
    );
    root.dispose();
  });
}

void _registerValidationTest() {
  // ignore: missing-test-assertion, reason: The named helper owns both boundary assertions.
  test('grid updates preserve omission and reject invalid merged values', () {
    _expectMergeInvalidEnableRejected(
      _baseDocumentWithDisabledGrid(cellSize: 0),
      CanvasDataErrorCode.fieldMustBePositive,
    );
    _expectMergeInvalidEnableRejected(
      _baseDocumentWithDisabledGrid(cellSize: 0.5),
      CanvasDataErrorCode.fieldMustBeInRange,
    );
  });
}

void _registerBoundaryApplicationTest() {
  test('grid updates apply disabled zero and enabled minimum boundaries', () {
    final root = runtimeRootWithCommittedDocumentSeed(_baseDocument());

    root.edits.edit((edit) => edit.updateGrid(CanvasGridUpdate(cellSize: 0)));
    expect(root.readAppearance().grid.cellSize, 0);
    expect(root.readAppearance().grid.enabled, isFalse);
    root.edits.edit((edit) {
      edit.updateGrid(CanvasGridUpdate(enabled: true, cellSize: 1.0));
    });
    expect(root.readAppearance().grid.enabled, isTrue);
    expect(root.readAppearance().grid.cellSize, 1.0);
    root.edits.edit((edit) {
      edit.updateGrid(CanvasGridUpdate(cellSize: 10000000));
    });
    expect(root.readAppearance().grid.cellSize, 10000000);
    root.dispose();
  });
}

void _expectMergeInvalidEnableRejected(
  CanvasDocument document,
  CanvasDataErrorCode code,
) {
  final root = runtimeRootWithCommittedDocumentSeed(document);
  final before = root.readAppearance().grid;

  root.edits.edit((edit) => edit.updateGrid(CanvasGridUpdate()));
  expect(root.readAppearance().grid, before);
  expect(
    () => root.edits.edit(
      (edit) => edit.updateGrid(CanvasGridUpdate(enabled: true)),
    ),
    throwsA(
      isA<CanvasDataException>()
          .having((error) => error.code, 'code', code)
          .having((error) => error.path, 'path', 'grid.cellSize'),
    ),
  );
  expect(root.readAppearance().grid, before);
  root.dispose();
}

void _registerSequentialBackingTest() {
  test('sparse and materialized grid updates use latest local values', () {
    final sparse = _applySequentialUpdates(materialize: false);
    final materialized = _applySequentialUpdates(materialize: true);

    expect(sparse.grid, materialized.grid);
    expect(
      sparse.grid,
      CanvasGrid(enabled: true, cellSize: 32, color: const Color(0xFF040506)),
    );
    expect(sparse.sparseProjectionBuilds, 0);
  });
}

void _registerStorePathTest() {
  test(
    'public update admits one complete sparse grid candidate and replays once on promotion',
    () => expect(_expectSingleGridCandidateFromPublicUpdate, returnsNormally),
  );
}

// This trace ties the public edit entry to its sole journal mutation, replay,
// and Store candidate, so separating it would weaken that causal witness.
// ignore: halstead-volume, source-lines-of-code, maintainability-index
void _expectSingleGridCandidateFromPublicUpdate() {
  final update = CanvasGridUpdate(enabled: true, cellSize: 24);
  final expected = CanvasGrid(
    enabled: true,
    cellSize: 24,
    color: const Color(0xFF202122),
  );
  final session = sparseSessionForDocument(_baseDocument());
  final CanvasEdit edit = session;

  edit.updateGrid(update);

  final sparseCommit = session.sparseCommit;
  expect(sparseCommit.mutations, hasLength(1));
  final mutation = sparseCommit.mutations.single;
  expect(mutation, isA<StoreSparseSetBackground>());
  final backgroundMutation = mutation as StoreSparseSetBackground;
  expect(backgroundMutation.background.grid, expected);

  final promotionEvents = <SparsePromotionWorkEvent>[];
  final appliedMutations = <StoreSparseMutation>[];
  final promoted = DraftDocument.observeSparseMutationApplications(
    appliedMutations.add,
    () => observeSparsePromotionWork(
      promotionEvents.add,
      session.readDraftDocument,
    ),
  );
  expect(promoted.background.grid, expected);
  expect(appliedMutations, [same(mutation)]);
  expect(promotionEvents.map((event) => event.phase), const [
    SparsePromotionWorkPhase.open,
    SparsePromotionWorkPhase.journalElementRead,
    SparsePromotionWorkPhase.draftApplication,
    SparsePromotionWorkPhase.complete,
  ]);
  expect(identical(promotionEvents[1].mutation, mutation), isTrue);
  expect(identical(promotionEvents[2].mutation, mutation), isTrue);

  final candidateEvents = <StoreSparseCandidateEvent>[];
  final root = runtimeRootWithCommittedDocumentSeed(_baseDocument());
  CommittedDocument.observeSparseCandidateEvents(candidateEvents.add, () {
    root.edits.edit((edit) => edit.updateGrid(update));
  });
  expect(root.readAppearance().grid, expected);
  expect(
    candidateEvents.where(
      (event) => event.kind == StoreSparseCandidateEventKind.open,
    ),
    hasLength(1),
  );
  expect(
    candidateEvents
        .where(
          (event) =>
              event.kind == StoreSparseCandidateEventKind.aggregatePublication,
        )
        .length,
    inInclusiveRange(0, 1),
  );
  expect(root.projectionBuildCount, 0);
  root.dispose();

  final materializedEffects = <List<CommitDeliveryEffect>>[];
  final materializedRoot = runtimeRootWithCommittedDocumentSeed(
    _baseDocument(),
    commitEffectObserver: materializedEffects.add,
  );
  materializedRoot.edits.edit((edit) {
    edit.updateGrid(update);
    edit.readDraftDocument();
  });
  expect(materializedRoot.readAppearance().grid, expected);
  expect(materializedRoot.documentFacts.documentRevision, 1);
  expect(materializedRoot.projectionBuildCount, 1);
  expect(materializedEffects, hasLength(1));
  expect(
    materializedEffects.single.whereType<ProjectionDeliveryEffect>(),
    hasLength(1),
  );
  expect(
    materializedEffects.single.whereType<PublicStateDeliveryEffect>(),
    hasLength(1),
  );
  expect(
    materializedEffects.single.whereType<RepaintDeliveryEffect>(),
    hasLength(1),
  );
  materializedRoot.dispose();
}

CanvasDocument _baseDocument() {
  return CanvasDocument(
    background: CanvasBackground(
      color: const Color(0xFF101112),
      grid: CanvasGrid(
        enabled: false,
        cellSize: 10,
        color: const Color(0xFF202122),
      ),
    ),
  );
}

CanvasDocument _baseDocumentWithDisabledGrid({required double cellSize}) {
  return CanvasDocument(
    background: CanvasBackground(grid: CanvasGrid(cellSize: cellSize)),
  );
}

_GridUpdateResult _applySequentialUpdates({required bool materialize}) {
  final root = runtimeRootWithCommittedDocumentSeed(_baseDocument());
  final beforeBuilds = root.projectionBuildCount;
  root.edits.edit((edit) {
    if (materialize) {
      edit.readDraftDocument();
    }
    edit.updateGrid(CanvasGridUpdate(enabled: true));
    edit.updateGrid(CanvasGridUpdate(color: const Color(0xFF010203)));
    edit.updateGrid(CanvasGridUpdate(cellSize: 24));
    edit.updateGrid(CanvasGridUpdate(color: const Color(0xFF040506)));
    edit.updateGrid(CanvasGridUpdate(cellSize: 32));
  });
  final result = _GridUpdateResult(
    grid: root.readAppearance().grid,
    sparseProjectionBuilds: materialize
        ? -1
        : root.projectionBuildCount - beforeBuilds,
  );
  root.dispose();
  return result;
}

final class _GridUpdateResult {
  const _GridUpdateResult({
    required this.grid,
    required this.sparseProjectionBuilds,
  });

  final CanvasGrid grid;
  final int sparseProjectionBuilds;
}
