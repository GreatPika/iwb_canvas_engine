import 'dart:ui' show Color, Offset, Size, TextDirection;

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine/src/store/committed_document.dart';
import 'package:iwb_canvas_engine/src/store/document_store_kernel.dart';
import 'package:iwb_canvas_engine/src/store/family_tables.dart';
import 'package:iwb_canvas_engine/src/store/sparse_store_commit.dart';
import 'package:iwb_canvas_engine/src/store/store_revision_delta.dart';

import 'family_tables_telemetry.dart';

const _supportedElementCount = 200000;
const _largeUntouchedRectCount = _supportedElementCount - 1;

// The two kernel routes share the all-family transaction budget oracle; keeping
// them together shows the contrast with the supported-size untouched family.
// ignore: halstead-volume, source-lines-of-code
void main() {
  test(
    'kernel editor reuses every touched family across two mixed batches',
    () {
      final base = CommittedDocument(_mixedBaseDocument());
      final store = DocumentStoreKernel.withCommittedDocumentForTesting(base);
      final work = FamilyTablesTelemetry();

      final prepared = FamilyTables.observeTelemetry(
        work.record,
        () => store.prepareSparseCommit(_twoMixedFamilyUpdateBatches()),
      );

      // Both real batches carry all families. The per-batch scope is two, while
      // each family has one transaction lifetime across those applications.
      expect(work.batchReplacementCount, 2);
      for (final kind in CanvasElementKind.values) {
        expect(work.transactionOpenCount(kind), 1, reason: '$kind opens once');
        expect(
          work.transactionBaseEntryCopyCount(kind),
          1,
          reason: '$kind copies its one base row once',
        );
        expect(
          work.transactionFreezeCount(kind),
          1,
          reason: '$kind freezes once',
        );
        expect(
          work.transactionFinalMapRetainsBaseIdentity(kind),
          isFalse,
          reason: '$kind publishes its final changed map',
        );
      }
      expect(work.transactionImmutablePublicationCount, 1);
      expect(work.transactionIntermediateImmutablePublicationCount, 0);
      _expectMixedFinalRows(prepared.document.elements.familyTables);
    },
  );

  test('kernel editor leaves a supported-size untouched family unopened', () {
    // The loading fixture enforces the public JSON-size cap, which would hide
    // this supported-size ownership scenario before the sparse editor is used.
    final base = CommittedDocument(_largeUntouchedBaseDocument());
    final store = DocumentStoreKernel.withCommittedDocumentForTesting(base);
    final work = FamilyTablesTelemetry();

    FamilyTables.observeTelemetry(
      work.record,
      () => store.prepareSparseCommit(_twoBatchPathUpdate()),
    );

    expect(work.batchReplacementCount, 2);
    expect(work.transactionOpenCount(CanvasElementKind.path), 1);
    expect(work.transactionBaseEntryCopyCount(CanvasElementKind.path), 1);
    expect(work.transactionFreezeCount(CanvasElementKind.path), 1);
    expect(work.transactionOpenCount(CanvasElementKind.rect), 0);
    expect(work.transactionBaseEntryCopyCount(CanvasElementKind.rect), 0);
    expect(work.transactionFreezeCount(CanvasElementKind.rect), 0);
    expect(
      work.transactionFinalMapRetainsBaseIdentity(CanvasElementKind.rect),
      isTrue,
    );
    expect(work.transactionImmutablePublicationCount, 1);
    expect(work.transactionIntermediateImmutablePublicationCount, 0);
  });
}

StoreSparseCommit _twoMixedFamilyUpdateBatches() {
  final first = _mixedRows(revision: 1, value: 1);
  final second = _mixedRows(revision: 2, value: 2);

  return StoreSparseCommit(
    revisionDelta: const StoreRevisionDelta.elementBounds(),
    mutations: [
      for (final MapEntry(key: id, value: element) in first.entries)
        StoreSparseUpdateElement(
          before: _mixedRows(revision: 0, value: 0)[id]!,
          element: element,
          elementRevisionDelta: const StoreRevisionDelta.elementBounds(),
        ),
      StoreSparseSetCamera(CanvasCamera()),
      for (final MapEntry(key: id, value: element) in second.entries)
        StoreSparseUpdateElement(
          before: first[id]!,
          element: element,
          elementRevisionDelta: const StoreRevisionDelta.elementBounds(),
        ),
    ],
  );
}

// Seven literal rows are intentionally adjacent so this independent journal
// oracle remains readable without reusing editor logic.
// ignore: halstead-volume, source-lines-of-code
Map<String, CanvasElement> _mixedRows({
  required int revision,
  required int value,
}) {
  return {
    'image': CanvasImageElement(
      id: CanvasElementId('image'),
      resourceId: CanvasResourceId('image-resource'),
      size: Size(value + 1, value + 1),
      revision: revision,
    ),
    'vector': CanvasVectorElement(
      id: CanvasElementId('vector'),
      resourceId: CanvasResourceId('vector-resource'),
      size: Size(value + 1, value + 1),
      revision: revision,
    ),
    'path': CanvasPathElement(
      id: CanvasElementId('path'),
      svgPathData: 'M$value $value',
      revision: revision,
    ),
    'text': CanvasTextElement(
      id: CanvasElementId('text'),
      text: 'text-$value',
      color: const Color(0xFF000000),
      textDirection: TextDirection.ltr,
      revision: revision,
    ),
    'stroke': CanvasStrokeElement(
      id: CanvasElementId('stroke'),
      points: [Offset(value.toDouble(), value.toDouble())],
      thickness: 1,
      color: const Color(0xFF000000),
      revision: revision,
    ),
    'line': CanvasLineElement(
      id: CanvasElementId('line'),
      start: Offset.zero,
      end: Offset(value + 1, value + 1),
      thickness: 1,
      color: const Color(0xFF000000),
      revision: revision,
    ),
    'rect': CanvasRectElement(
      id: CanvasElementId('rect'),
      size: Size(value + 1, value + 1),
      revision: revision,
    ),
  };
}

// Each literal final row protects a separate family against a kernel route
// regression; grouping avoids hiding a missing family behind shared helpers.
// ignore: halstead-volume
void _expectMixedFinalRows(FamilyTables tables) {
  expect(tables.imageRows['image']!.size, const Size(3, 3));
  expect(tables.imageRows['image']!.common.revision, 2);
  expect(tables.vectorRows['vector']!.size, const Size(3, 3));
  expect(tables.vectorRows['vector']!.common.revision, 2);
  expect(tables.pathRows['path']!.svgPathData, 'M2 2');
  expect(tables.pathRows['path']!.common.revision, 2);
  expect(tables.textRows['text']!.text, 'text-2');
  expect(tables.textRows['text']!.common.revision, 2);
  expect(tables.strokeRows['stroke']!.points, [const Offset(2, 2)]);
  expect(tables.strokeRows['stroke']!.common.revision, 2);
  expect(tables.lineRows['line']!.end, const Offset(3, 3));
  expect(tables.lineRows['line']!.common.revision, 2);
  expect(tables.rectRows['rect']!.size, const Size(3, 3));
  expect(tables.rectRows['rect']!.common.revision, 2);
}

StoreSparseCommit _twoBatchPathUpdate() {
  final base = CanvasPathElement(
    id: CanvasElementId('path'),
    svgPathData: 'M0 0',
  );
  final first = CanvasPathElement(
    id: base.id,
    svgPathData: 'M1 1',
    revision: 1,
  );
  final second = CanvasPathElement(
    id: base.id,
    svgPathData: 'M2 2',
    revision: 2,
  );

  return StoreSparseCommit(
    revisionDelta: const StoreRevisionDelta.elementBounds().merge(
      const StoreRevisionDelta.projectionOnly(),
    ),
    mutations: [
      StoreSparseUpdateElement(
        before: base,
        element: first,
        elementRevisionDelta: const StoreRevisionDelta.elementBounds(),
      ),
      StoreSparseSetCamera(CanvasCamera()),
      StoreSparseUpdateElement(
        before: first,
        element: second,
        elementRevisionDelta: const StoreRevisionDelta.elementBounds(),
      ),
    ],
  );
}

CanvasDocument _mixedBaseDocument() {
  return CanvasDocument(
    resources: [
      CanvasImageResource(
        id: CanvasResourceId('image-resource'),
        source: CanvasResourceSource.appKey('image'),
      ),
      CanvasVectorResource(
        id: CanvasResourceId('vector-resource'),
        source: CanvasResourceSource.appKey('vector'),
      ),
    ],
    layers: [
      CanvasLayer(
        id: CanvasLayerId('layer'),
        elements: _mixedRows(revision: 0, value: 0).values.toList(),
      ),
    ],
  );
}

CanvasDocument _largeUntouchedBaseDocument() {
  return CanvasDocument(
    layers: [
      CanvasLayer(
        id: CanvasLayerId('layer'),
        elements: [
          CanvasPathElement(id: CanvasElementId('path'), svgPathData: 'M0 0'),
          for (var index = 0; index < _largeUntouchedRectCount; index += 1)
            CanvasRectElement(
              id: CanvasElementId('rect-$index'),
              size: const Size(4, 5),
            ),
        ],
      ),
    ],
  );
}
