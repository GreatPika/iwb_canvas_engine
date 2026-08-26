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
  _registerPresenceAndAliasTests();
  _registerSequentialBackingTest();
  _registerSparseCandidateTest();
}

void _registerPresenceAndAliasTests() {
  _registerPresenceApplicationTest();
  _registerAliasIsolationTest();
}

void _registerPresenceApplicationTest() {
  _registerPresenceAndPopulatedFieldTest();
  _registerEmptyPenColorsTest();
  _registerEmptyBackgroundColorsTest();
  _registerEmptyGridSizesTest();
}

void _registerPresenceAndPopulatedFieldTest() {
  test(
    'absence, empty, and individual fields retain the intended siblings',
    () {
      final root = runtimeRootWithCommittedDocumentSeed(_baseDocument());

      root.edits.edit((edit) {
        edit.updatePalette(CanvasPaletteUpdate());
        edit.updatePalette(
          CanvasPaletteUpdate(penColors: const [Color(0xFFAAAAAA)]),
        );
        edit.updatePalette(CanvasPaletteUpdate(backgroundColors: const []));
        edit.updatePalette(CanvasPaletteUpdate(gridSizes: const [12, 24]));
      });

      final palette = root.readAppearance().palette;
      expect(palette.penColors, const [Color(0xFFAAAAAA)]);
      expect(palette.backgroundColors, isEmpty);
      expect(palette.gridSizes, const [12, 24]);
      root.dispose();
    },
  );
}

void _registerEmptyPenColorsTest() {
  test('supplied empty pen colors clear only pen colors', () {
    final root = runtimeRootWithCommittedDocumentSeed(_baseDocument());

    root.edits.edit(
      (edit) => edit.updatePalette(CanvasPaletteUpdate(penColors: const [])),
    );

    final palette = root.readAppearance().palette;
    expect(palette.penColors, isEmpty);
    expect(palette.backgroundColors, const [Color(0xFF202020)]);
    expect(palette.gridSizes, const [8]);
    root.dispose();
  });
}

void _registerEmptyBackgroundColorsTest() {
  test('supplied empty background colors clear only background colors', () {
    final root = runtimeRootWithCommittedDocumentSeed(_baseDocument());

    root.edits.edit(
      (edit) =>
          edit.updatePalette(CanvasPaletteUpdate(backgroundColors: const [])),
    );

    final palette = root.readAppearance().palette;
    expect(palette.penColors, const [Color(0xFF101010)]);
    expect(palette.backgroundColors, isEmpty);
    expect(palette.gridSizes, const [8]);
    root.dispose();
  });
}

void _registerEmptyGridSizesTest() {
  test('supplied empty grid sizes clear only grid sizes', () {
    final root = runtimeRootWithCommittedDocumentSeed(_baseDocument());

    root.edits.edit(
      (edit) => edit.updatePalette(CanvasPaletteUpdate(gridSizes: const [])),
    );

    final palette = root.readAppearance().palette;
    expect(palette.penColors, const [Color(0xFF101010)]);
    expect(palette.backgroundColors, const [Color(0xFF202020)]);
    expect(palette.gridSizes, isEmpty);
    root.dispose();
  });
}

// This one temporal alias witness must retain all before/after mutations and
// installed-value assertions together; splitting it would obscure the contract.
// ignore: halstead-volume
void _registerAliasIsolationTest() {
  test('updates snapshot caller collections before and after application', () {
    final penColors = <Color>[const Color(0xFF010203)];
    final backgroundColors = <Color>[const Color(0xFF040506)];
    final gridSizes = <double>[12];
    final update = CanvasPaletteUpdate(
      penColors: penColors,
      backgroundColors: backgroundColors,
      gridSizes: gridSizes,
    );
    penColors[0] = const Color(0xFF111111);
    backgroundColors.clear();
    gridSizes.add(24);

    final root = runtimeRootWithCommittedDocumentSeed(_baseDocument());
    root.edits.edit((edit) => edit.updatePalette(update));
    penColors.clear();
    backgroundColors.add(const Color(0xFF222222));
    gridSizes.clear();

    expect(update.penColors, const [Color(0xFF010203)]);
    expect(update.backgroundColors, const [Color(0xFF040506)]);
    expect(update.gridSizes, const [12]);
    expect(() => update.penColors.clear(), throwsUnsupportedError);
    expect(() => update.backgroundColors.clear(), throwsUnsupportedError);
    expect(() => update.gridSizes.clear(), throwsUnsupportedError);
    final palette = root.readAppearance().palette;
    expect(palette.penColors, const [Color(0xFF010203)]);
    expect(palette.backgroundColors, const [Color(0xFF040506)]);
    expect(palette.gridSizes, const [12]);
    root.dispose();
  });
}

void _registerSequentialBackingTest() {
  test(
    'sparse and materialized updates merge from their latest local palette',
    () {
      final sparse = _applySequentialUpdates(materialize: false);
      final materialized = _applySequentialUpdates(materialize: true);

      expect(sparse.palette.penColors, materialized.palette.penColors);
      expect(
        sparse.palette.backgroundColors,
        materialized.palette.backgroundColors,
      );
      expect(sparse.palette.gridSizes, materialized.palette.gridSizes);
      expect(sparse.sparseProjectionBuilds, 0);
    },
  );
}

void _registerSparseCandidateTest() {
  test(
    'public update admits one complete sparse palette candidate and replays once on promotion',
    () =>
        expect(_expectSinglePaletteCandidateFromPublicUpdate, returnsNormally),
  );
}

// This trace ties the public edit entry to its sole journal mutation, replay,
// and Store candidate, so separating it would weaken that causal witness.
// ignore: halstead-volume, source-lines-of-code, maintainability-index
void _expectSinglePaletteCandidateFromPublicUpdate() {
  final update = CanvasPaletteUpdate(
    penColors: const [Color(0xFFAAAAAA)],
    backgroundColors: const [Color(0xFFBBBBBB)],
    gridSizes: const [12],
  );
  final session = sparseSessionForDocument(_baseDocument());
  final CanvasEdit edit = session;

  edit.updatePalette(update);

  final sparseCommit = session.sparseCommit;
  expect(sparseCommit.mutations, hasLength(1));
  final mutation = sparseCommit.mutations.single;
  expect(mutation, isA<StoreSparseSetPalette>());
  final paletteMutation = mutation as StoreSparseSetPalette;
  _expectPaletteMatchesUpdate(paletteMutation.palette, update);

  final promotionEvents = <SparsePromotionWorkEvent>[];
  final appliedMutations = <StoreSparseMutation>[];
  final promoted = DraftDocument.observeSparseMutationApplications(
    appliedMutations.add,
    () => observeSparsePromotionWork(
      promotionEvents.add,
      session.readDraftDocument,
    ),
  );
  _expectPaletteMatchesUpdate(promoted.palette, update);
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
    root.edits.edit((edit) => edit.updatePalette(update));
  });
  _expectPaletteMatchesUpdate(root.readAppearance().palette, update);
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
    edit.updatePalette(update);
    edit.readDraftDocument();
  });
  _expectPaletteMatchesUpdate(
    materializedRoot.readAppearance().palette,
    update,
  );
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
    isEmpty,
  );
  materializedRoot.dispose();
}

void _expectPaletteMatchesUpdate(
  CanvasPalette palette,
  CanvasPaletteUpdate update,
) {
  expect(palette.penColors, update.penColors);
  expect(palette.backgroundColors, update.backgroundColors);
  expect(palette.gridSizes, update.gridSizes);
}

_PaletteUpdateResult _applySequentialUpdates({required bool materialize}) {
  final root = runtimeRootWithCommittedDocumentSeed(_baseDocument());
  final beforeBuilds = root.projectionBuildCount;
  root.edits.edit((edit) {
    if (materialize) {
      edit.readDraftDocument();
    }
    edit.updatePalette(
      CanvasPaletteUpdate(penColors: const [Color(0xFF111111)]),
    );
    edit.updatePalette(
      CanvasPaletteUpdate(backgroundColors: const [Color(0xFF222222)]),
    );
    edit.updatePalette(
      CanvasPaletteUpdate(penColors: const [Color(0xFF333333)]),
    );
  });
  final result = _PaletteUpdateResult(
    palette: root.readAppearance().palette,
    sparseProjectionBuilds: materialize
        ? -1
        : root.projectionBuildCount - beforeBuilds,
  );
  root.dispose();
  return result;
}

final class _PaletteUpdateResult {
  const _PaletteUpdateResult({
    required this.palette,
    required this.sparseProjectionBuilds,
  });

  final CanvasPalette palette;
  final int sparseProjectionBuilds;
}

CanvasDocument _baseDocument() {
  return CanvasDocument(
    palette: CanvasPalette(
      penColors: const [Color(0xFF101010)],
      backgroundColors: const [Color(0xFF202020)],
      gridSizes: const [8],
    ),
  );
}
