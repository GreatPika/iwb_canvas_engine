import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine/src/edit/draft_document.dart';
import 'package:iwb_canvas_engine/src/edit/edit_session.dart';
import 'package:iwb_canvas_engine/src/store/indexed_order_sequence.dart';

import 'sparse_edit_session_support.dart';
import 'sparse_edit_session_resource_fixture.dart';
import 'sparse_edit_session_store_support.dart';
import 'sparse_edit_session_structure_fixture.dart';

void registerSparseEditSessionAggregateTest() {
  test(
    'aggregate edit lifecycle work remains phase-bounded',
    () => expect(
      _composedSparsePromotionDraftAndStoreWorkIsBounded,
      returnsNormally,
    ),
  );
}

// One phase-nested supported-size observation must keep all counts in one execution.
// ignore: halstead-volume, source-lines-of-code, maintainability-index
void _composedSparsePromotionDraftAndStoreWorkIsBounded() {
  const elementCount = 200000;
  const layerCount = 4096;
  const seedElementCount = elementCount - 1;
  final seed = supportedSizeDraftDocument(
    elementCount: seedElementCount,
    layerCount: layerCount,
  );
  final facts = SparseFixtureFacts(seed);
  final session = EditSession.sparse(
    facts: facts,
    promoteDraft: () => DraftDocument(seed),
    selectedElementIds: const [],
  );
  final sparseStructure = <SparseEditStructureWorkEvent>[];
  final sparseReferences = <SparseEditReferenceWorkEvent>[];
  final promotion = <SparsePromotionWorkEvent>[];
  final draftStructure = <DraftStructureWorkEvent>[];
  final draftResources = <DraftResourceWorkEvent>[];
  final sequence = <IndexedOrderSequenceWorkEvent>[];
  late SparseStoreAggregateObservation storeWork;
  var mutationCount = 0;
  late CanvasDocument document;

  observeSparseEditStructureWork(
    sparseStructure.add,
    () => observeSparseEditReferenceWork(
      sparseReferences.add,
      () => observeSparsePromotionWork(
        promotion.add,
        () => observeDraftStructureWork(
          draftStructure.add,
          () => observeDraftResourceWork(
            draftResources.add,
            () => IndexedOrderSequence.observeWork(sequence.add, () {
              expect(
                session.upsertResource(
                  sparseImageResource('lifecycle-resource'),
                ),
                isTrue,
              );
              session.addElement(
                CanvasImageElement(
                  id: CanvasElementId('lifecycle-element'),
                  resourceId: CanvasResourceId('lifecycle-resource'),
                  size: const Size(1, 1),
                ),
                layerId: CanvasLayerId('layer-0'),
                index: elementCount ~/ 2,
              );
              final commit = session.sparseCommit;
              mutationCount = commit.mutations.length;
              document = session.readDraftDocument();
              storeWork = prepareAndInstallSparseCommitForTrace(
                seed: seed,
                commit: commit,
                installedElementId: CanvasElementId('lifecycle-element'),
              );
            }),
          ),
        ),
      ),
    ),
  );

  expect(document.layers.first.elements, hasLength(elementCount));
  expect(storeWork.installedElement, isNotNull);
  final promotionStart = promotion.indexWhere(
    (event) => event.phase == SparsePromotionWorkPhase.open,
  );
  expect(promotionStart, mutationCount);
  expect(
    promotion.take(promotionStart).map((event) => event.phase),
    List.filled(mutationCount, SparsePromotionWorkPhase.journalElementRead),
  );
  expect(promotion.skip(promotionStart).map((event) => event.phase), [
    SparsePromotionWorkPhase.open,
    for (final _ in List.filled(mutationCount, null)) ...[
      SparsePromotionWorkPhase.journalElementRead,
      SparsePromotionWorkPhase.draftApplication,
    ],
    SparsePromotionWorkPhase.complete,
  ]);
  expect(
    draftStructureEventCount(
      draftStructure,
      DraftStructureWorkKind.constructionElementVisit,
    ),
    seedElementCount,
  );
  expect(
    draftStructureEventCount(
      draftStructure,
      DraftStructureWorkKind.materialization,
    ),
    layerCount + 2,
  );
  expect(
    draftResourceWorkCount(
      draftResources,
      DraftResourceWorkKind.constructionElementVisit,
    ),
    seedElementCount,
  );
  expect(
    draftResourceWorkCount(
      draftResources,
      DraftResourceWorkKind.descriptorMaterialization,
    ),
    1,
  );
  expect(
    draftResourceWorkCount(
      draftResources,
      DraftResourceWorkKind.imageCountTransition,
    ),
    1,
  );
  expect(
    indexedEventCount(sequence, IndexedOrderSequenceWorkEvent.buildInputVisit),
    // Sparse and Store open only the affected content order; Draft builds its
    // full structural backing once. A further whole-owner pass is a rebuild.
    3 * seedElementCount + layerCount,
  );
  expect(
    indexedEventCount(
      sequence,
      IndexedOrderSequenceWorkEvent.finalFlattenPublication,
    ),
    0,
  );
  expect(
    sparseReferences.where(
      (event) => event.kind == SparseEditReferenceWorkKind.transition,
    ),
    hasLength(1),
  );
  expect(
    sparseStructure.where(
      (event) => event.kind == SparseEditStructureWorkKind.orderOpen,
    ),
    hasLength(1),
  );
  expect(
    sparseReferences.where(
      (event) => event.kind == SparseEditReferenceWorkKind.deltaEntryVisit,
    ),
    isEmpty,
  );
  expect(
    storeWork.replayJournalIndexes,
    List.generate(mutationCount, (index) => index),
  );
  expect(storeWork.resourceFreezeCount, 1);
  expect(storeWork.structuralPublicationCount, 1);
  expect(storeWork.aggregatePublicationCount, 1);
}
