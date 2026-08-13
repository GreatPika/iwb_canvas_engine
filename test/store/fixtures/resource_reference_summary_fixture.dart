import 'dart:ui' show Size;

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine/src/contracts/internal/schema_v1_import_events.dart';
import 'package:iwb_canvas_engine/src/store/committed_document.dart';
import 'package:iwb_canvas_engine/src/store/document_store_kernel.dart';
import 'package:iwb_canvas_engine/src/store/family_tables.dart';
import 'package:iwb_canvas_engine/src/store/sparse_store_commit.dart';
import 'package:iwb_canvas_engine/src/store/store_revision_delta.dart';

import 'family_tables_telemetry.dart';

const _supportedReferringRowCount = 200000;

// These independent owner lifecycle witnesses share literal rows and one
// oracle, so retaining their registration together is clearer than a web of
// test-only forwarding helpers solely to reduce local metric values.
// ignore: halstead-volume, source-lines-of-code, maintainability-index
void main() {
  test(
    'construction and schema import keep exact split row multiplicities',
    () {
      final constructionWork = FamilyTablesTelemetry();
      final constructed = FamilyTables.observeTelemetry(
        constructionWork.record,
        () => FamilyTables(_referenceRows()),
      );
      _expectReferenceCounts(
        constructed,
        image: const {'image-a': 2, 'missing-image': 1},
        vector: const {'vector-a': 2, 'missing-vector': 1},
      );
      expect(constructionWork.referenceConstructionRowVisitCount, 6);

      final directAdded = constructed.addElement(_image('direct', 'image-a'));
      _expectReferenceCounts(
        directAdded,
        image: const {'image-a': 3, 'missing-image': 1},
        vector: const {'vector-a': 2, 'missing-vector': 1},
      );
      final directRemoved = directAdded.removeElement(
        CanvasElementId('image-c'),
      );
      _expectReferenceCounts(
        directRemoved,
        image: const {'image-a': 3},
        vector: const {'vector-a': 2, 'missing-vector': 1},
      );
      _expectReferenceCounts(
        directRemoved.clearElements(),
        image: const {},
        vector: const {},
      );

      final importWork = FamilyTablesTelemetry();
      final imported = FamilyTables.observeTelemetry(importWork.record, () {
        final builder = FamilyTablesSchemaV1ImportBuilder();
        builder.add(_imageImportEvent('import-image', 'missing-image'));
        builder.add(_vectorImportEvent('import-vector', 'missing-vector'));

        return builder.consume();
      });
      _expectReferenceCounts(
        imported,
        image: const {'missing-image': 1},
        vector: const {'missing-vector': 1},
      );
      expect(importWork.referenceConstructionRowVisitCount, 2);
    },
  );

  test('editor count deltas match every sequential row transition', () {
    final base = FamilyTables(_referenceRows());
    final work = FamilyTablesTelemetry();
    final frozen = FamilyTables.observeTelemetry(
      work.record,
      () => base.editSparse((editor) {
        _expectReferenceCounts(
          editor,
          image: const {'image-a': 2, 'missing-image': 1},
          vector: const {'vector-a': 2, 'missing-vector': 1},
        );

        editor.replaceElement(_image('image-a', 'image-b'));
        _expectReferenceCounts(
          editor,
          image: const {'image-a': 1, 'image-b': 1, 'missing-image': 1},
          vector: const {'vector-a': 2, 'missing-vector': 1},
        );

        editor.addElement(_image('image-d', 'missing-added'));
        _expectReferenceCounts(
          editor,
          image: const {
            'image-a': 1,
            'image-b': 1,
            'missing-image': 1,
            'missing-added': 1,
          },
          vector: const {'vector-a': 2, 'missing-vector': 1},
        );

        editor.replaceElement(_vector('vector-a', 'vector-a'));
        _expectReferenceCounts(
          editor,
          image: const {
            'image-a': 1,
            'image-b': 1,
            'missing-image': 1,
            'missing-added': 1,
          },
          vector: const {'vector-a': 2, 'missing-vector': 1},
        );

        editor.removeElement(CanvasElementId('image-b'));
        _expectReferenceCounts(
          editor,
          image: const {'image-b': 1, 'missing-added': 1},
          vector: const {'vector-a': 2, 'missing-vector': 1},
        );

        editor.removeElement(CanvasElementId('vector-b'));
        _expectReferenceCounts(
          editor,
          image: const {'image-b': 1, 'missing-added': 1},
          vector: const {'vector-a': 1, 'missing-vector': 1},
        );

        editor.clearElements();
        _expectReferenceCounts(editor, image: const {}, vector: const {});

        editor.addElement(_vector('after-clear', 'missing-after-clear'));
        _expectReferenceCounts(
          editor,
          image: const {},
          vector: const {'missing-after-clear': 1},
        );

        return editor.freeze();
      }),
    );
    _expectReferenceCounts(
      frozen,
      image: const {},
      vector: const {'missing-after-clear': 1},
    );
    expect(work.imageReferenceSummaryDeltaOpenCount, 1);
    expect(work.vectorReferenceSummaryDeltaOpenCount, 1);
    expect(work.imageReferenceAffectedIdUpdateCount, 4);
    expect(work.vectorReferenceAffectedIdUpdateCount, 2);
    expect(work.imageReferenceSummaryCompleteCopyCount, 0);
    expect(work.vectorReferenceSummaryCompleteCopyCount, 0);
    expect(work.imageReferenceSummaryMaterializationCount, 1);
    expect(work.vectorReferenceSummaryMaterializationCount, 1);
    expect(work.imageReferenceSummaryPublicationCount, 1);
    expect(work.vectorReferenceSummaryPublicationCount, 1);
  });

  test('committed and working reference queries stay bounded', () {
    final tables = FamilyTables(_largeImageRows());
    final committedWork = FamilyTablesTelemetry();

    final committed = FamilyTables.observeTelemetry(
      committedWork.record,
      () => tables.referencesResource(CanvasResourceId('absent')),
    );

    expect(committed, isFalse);
    expect(committedWork.referenceQueryFamilyRowVisitCount, 0);
    expect(committedWork.referenceCommittedSummaryReadCount, 2);

    final workingWork = FamilyTablesTelemetry();
    final working = FamilyTables.observeTelemetry(
      workingWork.record,
      () => tables.editSparse((editor) {
        for (var index = 0; index < 64; index += 1) {
          editor.replaceElement(_image('image-0', 'replacement-$index'));
        }

        return editor.referencesResource(CanvasResourceId('absent'));
      }),
    );

    expect(working, isFalse);
    expect(workingWork.referenceQueryFamilyRowVisitCount, 0);
    expect(workingWork.referenceEditorBaseSummaryReadCount, 2);
    expect(workingWork.referenceEditorDeltaReadCount, 2);
    expect(workingWork.referenceEditorMaximumDeltaDepth, 1);
    expect(workingWork.imageReferenceSummaryDeltaOpenCount, 1);
  });

  test(
    'kernel reference consumers use summaries without descriptor coupling',
    () {
      final resourceId = CanvasResourceId('resource');
      final store = DocumentStoreKernel.withCommittedDocumentForTesting(
        CommittedDocument(
          CanvasDocument(
            resources: [
              CanvasImageResource(
                id: resourceId,
                source: CanvasResourceSource.appKey('before'),
              ),
            ],
            layers: [
              CanvasLayer(
                id: CanvasLayerId('layer'),
                elements: [_image('image', 'resource')],
              ),
            ],
          ),
        ),
      );
      final work = FamilyTablesTelemetry();

      final prepared = FamilyTables.observeTelemetry(
        work.record,
        () => store.prepareSparseCommit(
          StoreSparseCommit(
            revisionDelta: const StoreRevisionDelta.resource(),
            mutations: [
              StoreSparseRemoveUnusedResource(resourceId),
              StoreSparseUpsertResource(
                CanvasImageResource(
                  id: resourceId,
                  source: CanvasResourceSource.appKey('after'),
                ),
              ),
            ],
          ),
        ),
      );

      expect(prepared.hasChanges, isTrue);
      expect(prepared.document.resourceDescriptor(resourceId), isNotNull);
      expect(work.referenceQueryFamilyRowVisitCount, 0);
      expect(work.referenceCommittedSummaryReadCount, 2);
      expect(work.referenceEditorBaseSummaryReadCount, 2);
      expect(work.referenceEditorDeltaReadCount, 2);
      expect(work.imageReferenceAffectedIdUpdateCount, 0);
      expect(work.vectorReferenceAffectedIdUpdateCount, 0);
      expect(work.editorDecisionTrace, [
        FamilyTablesDecision.removeUnusedReference,
      ]);
      // Accepted touched classification now uses the normalized immutable
      // candidate after publication, so this owner trace ends at the current
      // remove-unused read rather than retaining a post-freeze editor read.
      expect(work.staleDecisionReadCount, 0);
      expect(work.postFreezeWriteCount, 0);
      expect(work.postFreezeCopyCount, 0);
      expect(work.postFreezeNormalizationCount, 0);
      expect(work.postFreezeImmutablePublicationCount, 0);
      _expectNoSummaryMaterialization(work);
    },
  );

  // This large real editor failure and final no-op distinguish a flat delta
  // from an eager complete summary clone that is discarded before publication.
  // ignore: halstead-volume, source-lines-of-code
  test(
    'summary maintenance defers materialization through failure and no-op',
    () {
      final tables = FamilyTables(_largeImageRows());
      final failureWork = FamilyTablesTelemetry();

      expect(
        () => FamilyTables.observeTelemetry(
          failureWork.record,
          () => tables.editSparse((editor) {
            editor.replaceElement(_image('image-0', 'failure-replacement'));
            _expectReferenceCounts(
              editor,
              image: const {
                'resource-0': 0,
                'resource-1': 1,
                'failure-replacement': 1,
              },
              vector: const {},
            );
            throw StateError('reject the editor');
          }),
        ),
        throwsStateError,
      );
      _expectNoSummaryMaterialization(failureWork);

      final noOpWork = FamilyTablesTelemetry();
      final store = DocumentStoreKernel.withCommittedDocumentForTesting(
        CommittedDocument(_largeImageDocument()),
      );
      final prepared = FamilyTables.observeTelemetry(
        noOpWork.record,
        () => store.prepareSparseCommit(_largeCompensatingImageCommit()),
      );

      expect(prepared.hasChanges, isFalse);
      _expectReferenceCounts(
        prepared.document.elements.familyTables,
        image: const {'resource-0': _supportedReferringRowCount},
        vector: const {},
      );
      _expectNoSummaryMaterialization(noOpWork);
    },
  );

  test(
    'accepted freeze materializes changed summaries once and shares others',
    () {
      final tables = FamilyTables(_largeImageRows());
      final work = FamilyTablesTelemetry();

      final frozen = FamilyTables.observeTelemetry(
        work.record,
        () => tables.editSparse((editor) {
          editor.replaceElement(_image('image-0', 'replacement'));
          expect(work.imageReferenceSummaryCompleteCopyCount, 0);
          expect(work.vectorReferenceSummaryCompleteCopyCount, 0);
          expect(work.imageReferenceSummaryMaterializationCount, 0);
          expect(work.vectorReferenceSummaryMaterializationCount, 0);

          return editor.freeze();
        }),
      );

      _expectReferenceCounts(
        frozen,
        image: {
          'replacement': 1,
          for (var index = 1; index < _supportedReferringRowCount; index += 1)
            'resource-$index': 1,
        },
        vector: const {},
      );
      expect(work.imageReferenceSummaryCompleteCopyCount, 1);
      expect(work.imageReferenceSummaryMaterializationCount, 1);
      expect(work.imageReferenceSummaryPublicationCount, 1);
      expect(work.vectorReferenceSummaryCompleteCopyCount, 0);
      expect(work.vectorReferenceSummaryMaterializationCount, 0);
      expect(work.vectorReferenceSummaryPublicationCount, 0);
      expect(work.imageReferenceSummaryRetainsBaseIdentity, isFalse);
      expect(work.vectorReferenceSummaryRetainsBaseIdentity, isTrue);
      expect(work.transactionOpenCount(CanvasElementKind.image), 1);
      expect(
        work.transactionBaseEntryCopyCount(CanvasElementKind.image),
        200000,
      );
      expect(work.transactionFreezeCount(CanvasElementKind.image), 1);
      expect(work.transactionOpenCount(CanvasElementKind.vector), 0);
      expect(work.transactionFreezeCount(CanvasElementKind.vector), 0);
    },
  );
}

void _expectReferenceCounts(
  Object tables, {
  required Map<String, int> image,
  required Map<String, int> vector,
}) {
  final queries = _referenceCountQueriesFor(tables);
  final ids = {...image.keys, ...vector.keys, 'absent'};
  for (final id in ids) {
    final resourceId = CanvasResourceId(id);
    final imageCount = queries.imageCount(resourceId);
    final vectorCount = queries.vectorCount(resourceId);
    expect(imageCount, image[id] ?? 0, reason: 'image count for $id');
    expect(vectorCount, vector[id] ?? 0, reason: 'vector count for $id');
    expect(queries.references(resourceId), imageCount + vectorCount > 0);
  }
}

void _expectNoSummaryMaterialization(FamilyTablesTelemetry work) {
  expect(work.imageReferenceSummaryCompleteCopyCount, 0);
  expect(work.vectorReferenceSummaryCompleteCopyCount, 0);
  expect(work.imageReferenceSummaryMaterializationCount, 0);
  expect(work.vectorReferenceSummaryMaterializationCount, 0);
  expect(work.imageReferenceSummaryPublicationCount, 0);
  expect(work.vectorReferenceSummaryPublicationCount, 0);
}

typedef _ReferenceCountQueries = ({
  int Function(CanvasResourceId id) imageCount,
  int Function(CanvasResourceId id) vectorCount,
  bool Function(CanvasResourceId id) references,
});

_ReferenceCountQueries _referenceCountQueriesFor(Object tables) {
  return switch (tables) {
    FamilyTables() => (
      imageCount: tables.imageResourceReferenceCount,
      vectorCount: tables.vectorResourceReferenceCount,
      references: tables.referencesResource,
    ),
    FamilyTablesEditor() => (
      imageCount: tables.imageResourceReferenceCount,
      vectorCount: tables.vectorResourceReferenceCount,
      references: tables.referencesResource,
    ),
    _ => throw ArgumentError.value(tables, 'tables'),
  };
}

List<CanvasElement> _referenceRows() {
  return [
    _image('image-a', 'image-a'),
    _image('image-b', 'image-a'),
    _image('image-c', 'missing-image'),
    _vector('vector-a', 'vector-a'),
    _vector('vector-b', 'vector-a'),
    _vector('vector-c', 'missing-vector'),
  ];
}

CanvasImageElement _image(String id, String resourceId, {int revision = 0}) {
  return CanvasImageElement(
    id: CanvasElementId(id),
    resourceId: CanvasResourceId(resourceId),
    size: const Size(1, 1),
    revision: revision,
  );
}

CanvasVectorElement _vector(String id, String resourceId) {
  return CanvasVectorElement(
    id: CanvasElementId(id),
    resourceId: CanvasResourceId(resourceId),
    size: const Size(1, 1),
  );
}

Iterable<CanvasElement> _largeImageRows() sync* {
  for (var index = 0; index < _supportedReferringRowCount; index += 1) {
    yield _image('image-$index', 'resource-$index');
  }
}

Iterable<CanvasElement> _largeImageRowsForCompensatingCommit() sync* {
  for (var index = 0; index < _supportedReferringRowCount; index += 1) {
    yield _image('image-$index', 'resource-0');
  }
}

CanvasDocument _largeImageDocument() {
  return CanvasDocument(
    resources: [
      CanvasImageResource(
        id: CanvasResourceId('resource-0'),
        source: CanvasResourceSource.appKey('resource-0'),
      ),
    ],
    layers: [
      CanvasLayer(
        id: CanvasLayerId('layer'),
        elements: _largeImageRowsForCompensatingCommit(),
      ),
    ],
  );
}

StoreSparseCommit _largeCompensatingImageCommit() {
  final before = _image('image-0', 'resource-0');
  final changed = _image('image-0', 'replacement', revision: 1);
  final finalEqual = _image('image-0', 'resource-0', revision: 2);

  return StoreSparseCommit(
    revisionDelta: const StoreRevisionDelta.elementBounds(),
    mutations: [
      StoreSparseUpdateElement(
        before: before,
        element: changed,
        elementRevisionDelta: const StoreRevisionDelta.elementBounds(),
      ),
      StoreSparseUpdateElement(
        before: changed,
        element: finalEqual,
        elementRevisionDelta: const StoreRevisionDelta.elementBounds(),
      ),
    ],
  );
}

SchemaV1ImageElementImportEvent _imageImportEvent(
  String id,
  String resourceId,
) {
  return SchemaV1ImageElementImportEvent(
    common: _importCommon(id, CanvasElementKind.image),
    resourceId: CanvasResourceId(resourceId),
    size: const Size(1, 1),
    naturalSize: null,
  );
}

SchemaV1VectorElementImportEvent _vectorImportEvent(
  String id,
  String resourceId,
) {
  return SchemaV1VectorElementImportEvent(
    common: _importCommon(id, CanvasElementKind.vector),
    resourceId: CanvasResourceId(resourceId),
    size: const Size(1, 1),
    naturalSize: null,
  );
}

SchemaV1ElementCommonImport _importCommon(String id, CanvasElementKind kind) {
  return SchemaV1ElementCommonImport(
    id: CanvasElementId(id),
    kind: kind,
    revision: 0,
    transform: CanvasTransform.identity,
    opacity: 1,
    hitPadding: 0,
    isVisible: true,
    isSelectable: true,
    isLocked: false,
    isDeletable: true,
    isTransformable: true,
    metadata: const CanvasMetadata.empty(),
  );
}
