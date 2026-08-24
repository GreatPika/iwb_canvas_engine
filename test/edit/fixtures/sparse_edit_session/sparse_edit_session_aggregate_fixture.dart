import 'dart:ui';

// This cohesive fixture directly imports distinct observation owners; a test
// barrel would hide those dependencies and recreate the forbidden re-export.
// ignore_for_file: number-of-imports

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine/src/edit/draft_resources.dart';
import 'package:iwb_canvas_engine/src/edit/draft_structure.dart';
import 'package:iwb_canvas_engine/src/edit/edit_session.dart';
import 'package:iwb_canvas_engine/src/edit/sparse_edit_resource_references.dart';
import 'package:iwb_canvas_engine/src/edit/sparse_edit_structure.dart';
import 'package:iwb_canvas_engine/src/store/committed_document.dart';
import 'package:iwb_canvas_engine/src/store/document_store_kernel.dart';
import 'package:iwb_canvas_engine/src/store/indexed_order_sequence.dart';

import '../interaction_commit_scenario_support.dart';
import 'sparse_edit_session_support.dart';

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
  final store = DocumentStoreKernel.withCommittedDocumentForTesting(
    CommittedDocument(seed),
  );
  final scenario = InteractionCommitScenario(store);
  final sparseStructure = <SparseEditStructureWorkEvent>[];
  final sparseReferences = <SparseEditReferenceWorkEvent>[];
  final promotion = <SparsePromotionWorkEvent>[];
  final draftStructure = <DraftStructureWorkEvent>[];
  final draftResources = <DraftResourceWorkEvent>[];
  final sequence = <IndexedOrderSequenceWorkEvent>[];
  final storeCandidateEvents = <StoreSparseCandidateEvent>[];
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
            () => CommittedDocument.observeSparseCandidateEvents(
              storeCandidateEvents.add,
              () => IndexedOrderSequence.observeWork(sequence.add, () {
                scenario.kernel.prepareInteractionCommit((edit) {
                  expect(
                    edit.upsertResource(
                      sparseImageResource('lifecycle-resource'),
                    ),
                    isTrue,
                  );
                  edit.addElement(
                    CanvasImageElement(
                      id: CanvasElementId('lifecycle-element'),
                      resourceId: CanvasResourceId('lifecycle-resource'),
                      size: const Size(1, 1),
                    ),
                    layerId: CanvasLayerId('layer-0'),
                    index: elementCount ~/ 2,
                  );
                  document = edit.readDraftDocument();
                });
              }),
            ),
          ),
        ),
      ),
    ),
  );

  expect(document.layers.first.elements, hasLength(elementCount));
  expect(store.elementById(CanvasElementId('lifecycle-element')), isNotNull);
  expect(store.projectionBuildCount, 1);
  expect(promotion.map((event) => event.phase), [
    SparsePromotionWorkPhase.open,
    for (final _ in List.filled(2, null)) ...[
      SparsePromotionWorkPhase.journalElementRead,
      SparsePromotionWorkPhase.draftApplication,
    ],
    SparsePromotionWorkPhase.complete,
  ]);
  expect(
    draftStructure
        .where(
          (event) =>
              event.kind == DraftStructureWorkKind.constructionElementVisit,
        )
        .length,
    seedElementCount,
  );
  expect(
    draftStructure
        .where((event) => event.kind == DraftStructureWorkKind.materialization)
        .length,
    2 * (layerCount + 2),
  );
  expect(
    draftResources
        .where(
          (event) =>
              event.kind == DraftResourceWorkKind.constructionElementVisit,
        )
        .length,
    seedElementCount,
  );
  expect(
    draftResources
        .where(
          (event) =>
              event.kind == DraftResourceWorkKind.descriptorMaterialization,
        )
        .length,
    2,
  );
  expect(
    draftResources
        .where(
          (event) => event.kind == DraftResourceWorkKind.imageCountTransition,
        )
        .length,
    1,
  );
  expect(
    sequence
        .where(
          (event) => event == IndexedOrderSequenceWorkEvent.buildInputVisit,
        )
        .length,
    // Promotion builds the Draft backing, then materialized Store preparation
    // visits its candidate once. A further whole-owner pass is a rebuild.
    2 * seedElementCount + layerCount,
  );
  expect(
    sequence
        .where(
          (event) =>
              event == IndexedOrderSequenceWorkEvent.finalFlattenPublication,
        )
        .length,
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
  expect(scenario.installCount, 1);
  expect(scenario.preparedMaterializedInstallCount, 1);
  expect(scenario.sparseInstallCount, 0);
  expect(
    storeCandidateEvents.where(
      (event) =>
          event.kind == StoreSparseCandidateEventKind.aggregatePublication,
    ),
    hasLength(2),
  );
}
