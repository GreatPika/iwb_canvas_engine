import 'dart:ui' show Color, Offset, Size, TextDirection;

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine/src/store/committed_document.dart';
import 'package:iwb_canvas_engine/src/store/document_store_kernel.dart';
import 'package:iwb_canvas_engine/src/store/family_tables.dart';
import 'package:iwb_canvas_engine/src/store/sparse_store_commit.dart';
import 'package:iwb_canvas_engine/src/store/store_revision_delta.dart';

import 'family_tables_telemetry.dart';

// This fixture keeps the accepted, no-op, failure, and clear lifecycle matrix
// together, so the all-family freeze invariant remains reviewable in one view.
// ignore: halstead-volume, source-lines-of-code, maintainability-index
void main() {
  test('normalizes a final-equal row before one freeze', () {
    final base = CommittedDocument(_baseDocument());
    final store = DocumentStoreKernel.withCommittedDocumentForTesting(base);
    final work = FamilyTablesTelemetry();

    final prepared = FamilyTables.observeTelemetry(
      work.record,
      () => store.prepareSparseCommit(_changedAndFinalEqualRows()),
    );
    final frozen = prepared.document.elements.familyTables;

    expect(work.transactionNormalizationWriteCount(CanvasElementKind.rect), 1);
    expect(work.transactionFreezeCount(CanvasElementKind.rect), 1);
    expect(work.transactionImmutablePublicationCount, 1);
    expect(work.transactionIntermediateImmutablePublicationCount, 0);
    expect(work.transactionDiscardCount, 0);
    expect(work.postFreezeWriteCount, 0);
    expect(work.postFreezeCopyCount, 0);
    expect(work.postFreezeNormalizationCount, 0);
    expect(work.postFreezeImmutablePublicationCount, 0);
    expect(
      identical(
        frozen.rectRows['equal'],
        base.elements.familyTables.rectRows['equal'],
      ),
      isTrue,
    );
    expect(
      identical(
        frozen.rectRows['changed'],
        base.elements.familyTables.rectRows['changed'],
      ),
      isFalse,
    );
  });

  // Each helper asserts a distinct pre-publication exit; grouping preserves
  // the shared zero-freeze lifecycle guarantee without test-shape duplication.
  // ignore: missing-test-assertion
  test('final no-op and coverage failure discard without freezing', () {
    _expectZeroFreeze(_compensatingRows());
    _expectCoverageFailureDiscards();
  });

  test(
    'clear does not copy base entries and retains already empty family maps',
    () {
      final base = CommittedDocument(_baseDocument());
      final store = DocumentStoreKernel.withCommittedDocumentForTesting(base);
      final work = FamilyTablesTelemetry();

      FamilyTables.observeTelemetry(
        work.record,
        () => store.prepareSparseCommit(
          StoreSparseCommit(
            revisionDelta: const StoreRevisionDelta.structural(),
            mutations: const [StoreSparseClearContent()],
          ),
        ),
      );

      for (final kind in CanvasElementKind.values) {
        expect(work.transactionOpenCount(kind), 1);
        expect(work.transactionBaseEntryCopyCount(kind), 0);
        expect(
          work.transactionFreezeCount(kind),
          kind == CanvasElementKind.rect ? 1 : 0,
        );
        expect(
          work.transactionFinalMapRetainsBaseIdentity(kind),
          kind != CanvasElementKind.rect,
        );
      }
    },
  );

  test('clear and exact family restore retain base maps and summaries', () {
    final base = CommittedDocument(_allFamilyBaseDocument());
    final store = DocumentStoreKernel.withCommittedDocumentForTesting(base);
    final work = FamilyTablesTelemetry();

    final prepared = FamilyTables.observeTelemetry(
      work.record,
      () => store.prepareSparseCommit(_clearAndRestoreAllFamilies()),
    );
    final frozen = prepared.document.elements.familyTables;
    final baseTables = base.elements.familyTables;

    expect(prepared.hasChanges, isTrue);
    expect(
      prepared.document.background,
      const CanvasBackground(color: Color(0xFF112233)),
    );
    expect(identical(frozen.imageRows, baseTables.imageRows), isTrue);
    expect(identical(frozen.vectorRows, baseTables.vectorRows), isTrue);
    expect(identical(frozen.pathRows, baseTables.pathRows), isTrue);
    expect(identical(frozen.textRows, baseTables.textRows), isTrue);
    expect(identical(frozen.strokeRows, baseTables.strokeRows), isTrue);
    expect(identical(frozen.lineRows, baseTables.lineRows), isTrue);
    expect(identical(frozen.rectRows, baseTables.rectRows), isTrue);
    expect(
      identical(
        frozen.imageResourceReferenceCounts,
        baseTables.imageResourceReferenceCounts,
      ),
      isTrue,
    );
    expect(
      identical(
        frozen.vectorResourceReferenceCounts,
        baseTables.vectorResourceReferenceCounts,
      ),
      isTrue,
    );
    for (final kind in CanvasElementKind.values) {
      expect(work.transactionOpenCount(kind), 1);
      expect(work.transactionBaseEntryCopyCount(kind), 0);
      expect(work.transactionFreezeCount(kind), 0);
    }
    expect(work.transactionImmutablePublicationCount, 0);
    expect(work.transactionIntermediateImmutablePublicationCount, 0);
    expect(work.postFreezeWriteCount, 0);
    expect(work.postFreezeCopyCount, 0);
    expect(work.postFreezeNormalizationCount, 0);
    expect(work.postFreezeImmutablePublicationCount, 0);
  });
}

void _expectZeroFreeze(StoreSparseCommit commit) {
  final base = CommittedDocument(_baseDocument());
  final store = DocumentStoreKernel.withCommittedDocumentForTesting(base);
  final work = FamilyTablesTelemetry();

  final prepared = FamilyTables.observeTelemetry(
    work.record,
    () => store.prepareSparseCommit(commit),
  );

  expect(prepared.hasChanges, isFalse);
  expect(work.transactionImmutablePublicationCount, 0);
  expect(work.transactionFreezeCount(CanvasElementKind.rect), 0);
  expect(work.transactionDiscardCount, 1);
  expect(work.postFreezeWriteCount, 0);
  expect(work.postFreezeCopyCount, 0);
  expect(work.postFreezeNormalizationCount, 0);
  expect(work.postFreezeImmutablePublicationCount, 0);
}

void _expectCoverageFailureDiscards() {
  final base = CommittedDocument(_baseDocument());
  final store = DocumentStoreKernel.withCommittedDocumentForTesting(base);
  final work = FamilyTablesTelemetry();

  expect(
    () => FamilyTables.observeTelemetry(
      work.record,
      () => store.prepareSparseCommit(
        StoreSparseCommit(
          revisionDelta: const StoreRevisionDelta.elementBoundsOnly(),
          mutations: [_change('changed', const Color(0xFF00FF00))],
        ),
      ),
    ),
    throwsA(isA<ArgumentError>()),
  );
  expect(work.transactionOpenCount(CanvasElementKind.rect), 1);
  expect(work.transactionFreezeCount(CanvasElementKind.rect), 0);
  expect(work.transactionImmutablePublicationCount, 0);
  expect(work.transactionDiscardCount, 1);
  expect(work.postFreezeWriteCount, 0);
  expect(work.postFreezeCopyCount, 0);
  expect(work.postFreezeNormalizationCount, 0);
  expect(work.postFreezeImmutablePublicationCount, 0);
}

StoreSparseCommit _changedAndFinalEqualRows() {
  return StoreSparseCommit(
    revisionDelta: const StoreRevisionDelta.elementVisual(),
    mutations: [
      _change('equal', const Color(0xFF00FF00)),
      StoreSparseUpdateElement(
        before: _rect('equal', const Color(0xFF00FF00), revision: 1),
        element: _rect('equal', const Color(0xFFFF0000), revision: 2),
        elementRevisionDelta: const StoreRevisionDelta.elementVisual(),
      ),
      _change('changed', const Color(0xFF0000FF)),
    ],
  );
}

StoreSparseCommit _compensatingRows() {
  return StoreSparseCommit(
    revisionDelta: const StoreRevisionDelta.elementVisual(),
    mutations: [
      _change('equal', const Color(0xFF00FF00)),
      StoreSparseUpdateElement(
        before: _rect('equal', const Color(0xFF00FF00), revision: 1),
        element: _rect('equal', const Color(0xFFFF0000), revision: 2),
        elementRevisionDelta: const StoreRevisionDelta.elementVisual(),
      ),
    ],
  );
}

StoreSparseUpdateElement _change(String id, Color color) {
  return StoreSparseUpdateElement(
    before: _rect(id, const Color(0xFFFF0000)),
    element: _rect(id, color, revision: 1),
    elementRevisionDelta: const StoreRevisionDelta.elementVisual(),
  );
}

CanvasRectElement _rect(String id, Color fillColor, {int revision = 0}) {
  return CanvasRectElement(
    id: CanvasElementId(id),
    size: const Size(2, 3),
    fillColor: fillColor,
    revision: revision,
  );
}

CanvasDocument _baseDocument() {
  return CanvasDocument(
    layers: [
      CanvasLayer(
        id: CanvasLayerId('layer'),
        elements: [
          _rect('equal', const Color(0xFFFF0000)),
          _rect('changed', const Color(0xFFFF0000)),
        ],
      ),
    ],
  );
}

CanvasDocument _allFamilyBaseDocument() {
  return CanvasDocument(
    resources: [
      CanvasImageResource(
        id: CanvasResourceId('image-resource'),
        source: CanvasResourceSource.appKey('image-resource'),
      ),
      CanvasVectorResource(
        id: CanvasResourceId('vector-resource'),
        source: CanvasResourceSource.appKey('vector-resource'),
      ),
    ],
    layers: [
      CanvasLayer(id: CanvasLayerId('layer'), elements: _allFamilyRows()),
    ],
  );
}

StoreSparseCommit _clearAndRestoreAllFamilies() {
  return StoreSparseCommit(
    revisionDelta: const StoreRevisionDelta(
      document: true,
      projection: true,
      structural: true,
      bounds: true,
      elementVisual: true,
      background: true,
    ),
    mutations: [
      const StoreSparseClearContent(),
      for (final element in _allFamilyRows())
        StoreSparseAddElement(
          element: element,
          layerId: CanvasLayerId('layer'),
        ),
      const StoreSparseSetBackground(
        CanvasBackground(color: Color(0xFF112233)),
      ),
    ],
  );
}

List<CanvasElement> _allFamilyRows() {
  return [
    CanvasImageElement(
      id: CanvasElementId('image'),
      resourceId: CanvasResourceId('image-resource'),
      size: const Size(2, 3),
    ),
    CanvasVectorElement(
      id: CanvasElementId('vector'),
      resourceId: CanvasResourceId('vector-resource'),
      size: const Size(2, 3),
    ),
    CanvasPathElement(id: CanvasElementId('path'), svgPathData: 'M0 0'),
    CanvasTextElement(
      id: CanvasElementId('text'),
      text: 'text',
      color: const Color(0xFF000000),
      textDirection: TextDirection.ltr,
    ),
    CanvasStrokeElement(
      id: CanvasElementId('stroke'),
      points: const [Offset.zero],
      thickness: 1,
      color: const Color(0xFF000000),
    ),
    CanvasLineElement(
      id: CanvasElementId('line'),
      start: Offset.zero,
      end: const Offset(1, 1),
      thickness: 1,
      color: const Color(0xFF000000),
    ),
    CanvasRectElement(id: CanvasElementId('rect'), size: const Size(2, 3)),
  ];
}
