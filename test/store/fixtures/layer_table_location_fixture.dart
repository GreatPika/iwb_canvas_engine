// This fixture names lifecycle, committed-store, and contract-limit owners
// directly so its supported-size witness stays at the real public boundary.
// ignore_for_file: number-of-imports

import 'dart:ui' show Size;

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine/src/contracts/public/canvas_contract_limits.dart';
import 'package:iwb_canvas_engine/src/contracts/internal/schema_v1_import_events.dart';
import 'package:iwb_canvas_engine/src/store/committed_document.dart';
import 'package:iwb_canvas_engine/src/store/document_store_kernel.dart';
import 'package:iwb_canvas_engine/src/store/element_registry.dart';
import 'package:iwb_canvas_engine/src/store/layer_table.dart';
import 'package:iwb_canvas_engine/src/store/sparse_store_commit.dart';
import 'package:iwb_canvas_engine/src/store/store_revision_delta.dart';

const _supportedLayerCount = 200000;

// This fixture keeps the three admitted owner lifecycle witnesses together:
// splitting the shared literal row oracle or work assertions would make stale
// locations and displaced work harder to audit than the cohesive scenario.
// ignore: halstead-volume, source-lines-of-code, maintainability-index
void main() {
  test('owner construction builds one direct location fact', () {
    final constructionWork = _LayerWork();
    final constructed = LayerTable.observeWork(
      constructionWork.record,
      () => LayerTable(_literalRows()),
    );
    _expectLocationParity(constructed, const [
      _ExpectedLayer('l0', ['e0']),
      _ExpectedLayer('l1', ['e1']),
      _ExpectedLayer('l2', ['e2']),
    ]);
    expect(
      constructionWork.count(LayerTableWorkEvent.constructionInputRowVisit),
      3,
    );
    expect(constructionWork.count(LayerTableWorkEvent.locationUpdate), 3);
    expect(constructionWork.count(LayerTableWorkEvent.locationPublication), 1);
    expect(constructionWork.count(LayerTableWorkEvent.fullLocationMapCopy), 0);
  });

  test('owner import builds one direct location fact', () {
    final importWork = _LayerWork();
    final imported = LayerTable.observeWork(importWork.record, () {
      final builder = LayerTableSchemaV1ImportBuilder()
        ..addLayer(_layerEvent('import-0'))
        ..addLayer(_layerEvent('import-1'))
        ..addLayer(_layerEvent('import-2'));

      return builder.consume();
    });
    _expectLocationParity(imported, const [
      _ExpectedLayer('import-0', []),
      _ExpectedLayer('import-1', []),
      _ExpectedLayer('import-2', []),
    ]);
    expect(importWork.count(LayerTableWorkEvent.schemaImportInputRowVisit), 3);
    expect(importWork.count(LayerTableWorkEvent.locationUpdate), 3);
    expect(importWork.count(LayerTableWorkEvent.locationPublication), 1);
    expect(importWork.count(LayerTableWorkEvent.fullLocationMapCopy), 0);
  });

  test('empty construction publishes no location traversal work', () {
    final work = _LayerWork();
    final table = LayerTable.observeWork(
      work.record,
      () => LayerTable(const <LayerRow>[]),
    );

    _expectLocationParity(table, const []);
    expect(table.locationFor(CanvasLayerId('missing')), isNull);
    expect(work.count(LayerTableWorkEvent.constructionInputRowVisit), 0);
    expect(work.count(LayerTableWorkEvent.locationUpdate), 0);
    expect(work.count(LayerTableWorkEvent.locationFactEntryVisit), 0);
    expect(work.count(LayerTableWorkEvent.fullLocationMapCopy), 0);
    expect(work.count(LayerTableWorkEvent.locationPublication), 1);
  });

  test('supported-size owner lifecycles stay single-pass and direct', () {
    final constructionWork = _LayerWork();
    LayerTable.observeWork(
      constructionWork.record,
      () => LayerTable(_supportedRows()),
    );
    expect(
      constructionWork.count(LayerTableWorkEvent.constructionInputRowVisit),
      _supportedLayerCount,
    );
    expect(
      constructionWork.count(LayerTableWorkEvent.locationUpdate),
      _supportedLayerCount,
    );
    expect(constructionWork.count(LayerTableWorkEvent.locationPublication), 1);
    expect(
      constructionWork.count(LayerTableWorkEvent.constructionPublishedRowVisit),
      0,
    );
    expect(
      constructionWork.count(LayerTableWorkEvent.locationFactEntryVisit),
      0,
    );
    expect(constructionWork.count(LayerTableWorkEvent.fullLocationMapCopy), 0);
    expect(
      constructionWork.count(LayerTableWorkEvent.locationRebuildRowVisit),
      0,
    );

    final store = _storeWithMaximumLayers();
    final iterationWork = _LayerWork();
    final layerIds = LayerTable.observeWork(iterationWork.record, () {
      return store.layerIds.toList(growable: false);
    });
    expect(layerIds, hasLength(canvasMaxContentLayers));
    expect(
      iterationWork.count(LayerTableWorkEvent.intentionalIterationRowVisit),
      canvasMaxContentLayers,
    );

    final importWork = _LayerWork();
    final imported = LayerTable.observeWork(importWork.record, () {
      final builder = LayerTableSchemaV1ImportBuilder();
      for (var index = 0; index < _supportedLayerCount; index += 1) {
        builder.addLayer(_layerEvent('import-supported-$index'));
      }
      return builder.consume();
    });
    expect(imported.rows, hasLength(_supportedLayerCount));
    expect(
      importWork.count(LayerTableWorkEvent.schemaImportInputRowVisit),
      _supportedLayerCount,
    );
    expect(
      importWork.count(LayerTableWorkEvent.locationUpdate),
      _supportedLayerCount,
    );
    expect(importWork.count(LayerTableWorkEvent.locationPublication), 1);
    expect(
      importWork.count(LayerTableWorkEvent.schemaImportPublishedRowVisit),
      0,
    );
    expect(importWork.count(LayerTableWorkEvent.locationFactEntryVisit), 0);
    expect(importWork.count(LayerTableWorkEvent.fullLocationMapCopy), 0);
    expect(importWork.count(LayerTableWorkEvent.locationRebuildRowVisit), 0);
  });

  test(
    'duplicate construction and import publish no partial location facts',
    () {
      final constructionWork = _LayerWork();
      expect(
        () => LayerTable.observeWork(
          constructionWork.record,
          () => LayerTable([
            LayerRow(
              id: CanvasLayerId('duplicate'),
              elementIds: const [],
              metadata: const CanvasMetadata.empty(),
            ),
            LayerRow(
              id: CanvasLayerId('duplicate'),
              elementIds: const [],
              metadata: const CanvasMetadata.empty(),
            ),
          ]),
        ),
        throwsA(isA<CanvasDataException>()),
      );
      expect(
        constructionWork.count(LayerTableWorkEvent.locationPublication),
        0,
      );
      expect(constructionWork.count(LayerTableWorkEvent.discard), 1);
      expect(
        constructionWork.count(LayerTableWorkEvent.fullLocationMapCopy),
        0,
      );

      final importWork = _LayerWork();
      LayerTable.observeWork(importWork.record, () {
        final builder = LayerTableSchemaV1ImportBuilder()
          ..addLayer(_layerEvent('duplicate'));
        expect(
          () => builder.addLayer(_layerEvent('duplicate')),
          throwsA(isA<CanvasDataException>()),
        );
      });
      expect(
        importWork.count(LayerTableWorkEvent.schemaImportInputRowVisit),
        0,
      );
      expect(importWork.count(LayerTableWorkEvent.locationPublication), 0);
      expect(importWork.count(LayerTableWorkEvent.discard), 0);
      expect(importWork.count(LayerTableWorkEvent.fullLocationMapCopy), 0);
    },
  );

  test('element updates share the unchanged layer location fact', () {
    final base = CommittedDocument(_documentWithLiteralLayers());
    final baseLocationFact =
        base.elements.layerTable.layerLocationFacts[CanvasLayerId('l0')];
    final store = DocumentStoreKernel.withCommittedDocumentForTesting(base);

    final prepared = store.prepareSparseCommit(
      StoreSparseCommit(
        revisionDelta: const StoreRevisionDelta.elementBounds(),
        mutations: [
          StoreSparseUpdateElement(
            before: _rect('e0'),
            element: _rect('e0', revision: 1, size: const Size(2, 2)),
            elementRevisionDelta: const StoreRevisionDelta.elementBounds(),
          ),
        ],
      ),
    );

    expect(
      identical(
        prepared.document.elements.layerTable,
        base.elements.layerTable,
      ),
      isTrue,
    );
    expect(
      identical(
        prepared.document.elements.layerTable.layerLocationFacts[CanvasLayerId(
          'l0',
        )],
        baseLocationFact,
      ),
      isTrue,
    );
    _expectLocationParity(prepared.document.elements.layerTable, const [
      _ExpectedLayer('l0', ['e0']),
      _ExpectedLayer('l1', ['e1']),
      _ExpectedLayer('l2', ['e2']),
      _ExpectedLayer('l3', ['e3']),
    ]);
  });

  test(
    'registry routes remove and clear through existing content ownership',
    () {
      final registry = ElementRegistry(
        backgroundElements: [_rect('background')],
        layers: _documentWithLiteralLayers().layers,
      );
      final originalUntouchedFact =
          registry.layerTable.layerLocationFacts[CanvasLayerId('l1')];
      final work = _LayerWork();
      late ElementRegistry removed;
      late ElementRegistry backgroundRemoved;
      late ElementRegistry cleared;
      LayerTable.observeWork(work.record, () {
        removed = ElementRegistry.editSparseStructure(registry, (editor) {
          editor.removeElement(CanvasElementId('e0'));
          return editor.freeze(
            familyTables: registry.familyTables.removeElement(
              CanvasElementId('e0'),
            ),
          );
        });
        backgroundRemoved = ElementRegistry.editSparseStructure(removed, (
          editor,
        ) {
          editor.removeElement(CanvasElementId('background'));
          return editor.freeze(
            familyTables: removed.familyTables.removeElement(
              CanvasElementId('background'),
            ),
          );
        });
        cleared = ElementRegistry.editSparseStructure(backgroundRemoved, (
          editor,
        ) {
          editor.clearContent();
          return editor.freeze(familyTables: backgroundRemoved.familyTables);
        });
      });

      _expectLocationParity(removed.layerTable, const [
        _ExpectedLayer('l0', []),
        _ExpectedLayer('l1', ['e1']),
        _ExpectedLayer('l2', ['e2']),
        _ExpectedLayer('l3', ['e3']),
      ]);
      expect(
        identical(
          originalUntouchedFact,
          removed.layerTable.layerLocationFacts[CanvasLayerId('l1')],
        ),
        isTrue,
      );
      expect(
        identical(backgroundRemoved.layerTable, removed.layerTable),
        isTrue,
      );
      _expectLocationParity(cleared.layerTable, const [
        _ExpectedLayer('l0', []),
        _ExpectedLayer('l1', []),
        _ExpectedLayer('l2', []),
        _ExpectedLayer('l3', []),
      ]);
      // Unit 4 retires the one-call LayerTable rank lifecycle from sparse
      // structure. Transaction-scoped sequence/final-traversal work now has
      // its owner proof in structural_editor_fixture.dart; this compatibility
      // case retains only row/location parity and direct fact guarantees.
      expect(work.count(LayerTableWorkEvent.locationPublication), 2);
      expect(work.count(LayerTableWorkEvent.locationFactEntryVisit), 0);
      expect(work.count(LayerTableWorkEvent.fullLocationMapCopy), 0);
    },
  );

  test('membership uses direct owner reads', () {
    final work = _observeMembershipConsumer();
    expect(work.count(LayerTableWorkEvent.membershipRowVisit), 0);
    expect(work.count(LayerTableWorkEvent.locationFactEntryVisit), 0);
    expect(
      work.count(LayerTableWorkEvent.membershipLookup),
      greaterThanOrEqualTo(2),
    );
    expect(
      work.count(LayerTableWorkEvent.membershipLocationRead),
      greaterThanOrEqualTo(2),
    );
  });

  test('row/index reads use direct owner reads', () {
    final work = _observeRowIndexConsumer();
    expect(work.count(LayerTableWorkEvent.rowIndexRowVisit), 0);
    expect(work.count(LayerTableWorkEvent.locationFactEntryVisit), 0);
    expect(
      work.count(LayerTableWorkEvent.rowIndexLocationRead),
      greaterThan(0),
    );
  });

  test('placement reads use direct owner reads', () {
    final work = _observePlacementConsumer();
    expect(work.count(LayerTableWorkEvent.placementRowVisit), 0);
    expect(work.count(LayerTableWorkEvent.locationFactEntryVisit), 0);
    expect(
      work.count(LayerTableWorkEvent.placementLocationRead),
      greaterThan(0),
    );
  });

  test('per-layer reads use direct owner reads', () {
    final work = _observePerLayerConsumer();
    expect(work.count(LayerTableWorkEvent.perLayerElementRowVisit), 0);
    expect(work.count(LayerTableWorkEvent.locationFactEntryVisit), 0);
    expect(
      work.count(LayerTableWorkEvent.perLayerElementLocationRead),
      greaterThanOrEqualTo(2),
    );
  });
}

_LayerWork _observeMembershipConsumer() {
  final store = DocumentStoreKernel.withCommittedDocumentForTesting(
    CommittedDocument(_documentWithLiteralLayers()),
  );
  final work = _LayerWork();

  LayerTable.observeWork(work.record, () {
    expect(store.hasLayer(CanvasLayerId('l3')), isTrue);
    expect(store.hasLayer(CanvasLayerId('missing')), isFalse);
  });

  return work;
}

_LayerWork _observeRowIndexConsumer() {
  final store = DocumentStoreKernel.withCommittedDocumentForTesting(
    CommittedDocument(_documentWithLiteralLayers()),
  );
  final work = _LayerWork();

  LayerTable.observeWork(work.record, () {
    final prepared = store.prepareMaterializedCommit(
      _documentWithUpdatedFirstLayer(),
      const StoreRevisionDelta.elementBounds(),
    );
    expect(prepared.revisionDelta.bounds, isTrue);
  });

  return work;
}

_LayerWork _observePlacementConsumer() {
  final registry = ElementRegistry(
    backgroundElements: const [],
    layers: _documentWithLiteralLayers().layers,
  );
  final work = _LayerWork();

  LayerTable.observeWork(work.record, () {
    ElementRegistry.editSparseStructure(registry, (editor) {
      editor.addContentElement(
        CanvasElementId('placement'),
        layerId: CanvasLayerId('l3'),
      );
      return editor.freeze(
        familyTables: registry.familyTables.addElement(_rect('placement')),
      );
    });
  });

  return work;
}

_LayerWork _observePerLayerConsumer() {
  final store = DocumentStoreKernel.withCommittedDocumentForTesting(
    CommittedDocument(_documentWithLiteralLayers()),
  );
  final work = _LayerWork();

  LayerTable.observeWork(work.record, () {
    expect(store.elementIdsInLayer(CanvasLayerId('l3')).map((id) => id.value), [
      'e3',
    ]);
    expect(store.elementIdsInLayer(CanvasLayerId('missing')).toList(), isEmpty);
  });

  return work;
}

List<LayerRow> _literalRows() {
  return [
    LayerRow(
      id: CanvasLayerId('l0'),
      elementIds: [CanvasElementId('e0')],
      metadata: const CanvasMetadata.empty(),
    ),
    LayerRow(
      id: CanvasLayerId('l1'),
      elementIds: [CanvasElementId('e1')],
      metadata: const CanvasMetadata.empty(),
    ),
    LayerRow(
      id: CanvasLayerId('l2'),
      elementIds: [CanvasElementId('e2')],
      metadata: const CanvasMetadata.empty(),
    ),
  ];
}

Iterable<LayerRow> _supportedRows() sync* {
  for (var index = 0; index < _supportedLayerCount; index += 1) {
    yield LayerRow(
      id: CanvasLayerId('supported-$index'),
      elementIds: const [],
      metadata: const CanvasMetadata.empty(),
    );
  }
}

DocumentStoreKernel _storeWithMaximumLayers() {
  return DocumentStoreKernel.withCommittedDocumentForTesting(
    CommittedDocument(
      CanvasDocument(
        layers: [
          for (var index = 0; index < canvasMaxContentLayers; index += 1)
            CanvasLayer(id: CanvasLayerId('public-$index')),
        ],
      ),
    ),
  );
}

CanvasDocument _documentWithLiteralLayers() {
  return CanvasDocument(
    layers: [
      CanvasLayer(id: CanvasLayerId('l0'), elements: [_rect('e0')]),
      CanvasLayer(id: CanvasLayerId('l1'), elements: [_rect('e1')]),
      CanvasLayer(id: CanvasLayerId('l2'), elements: [_rect('e2')]),
      CanvasLayer(id: CanvasLayerId('l3'), elements: [_rect('e3')]),
    ],
  );
}

CanvasDocument _documentWithUpdatedFirstLayer() {
  return CanvasDocument(
    layers: [
      CanvasLayer(
        id: CanvasLayerId('l0'),
        elements: [_rect('e0', revision: 1, size: const Size(2, 2))],
      ),
      CanvasLayer(id: CanvasLayerId('l1'), elements: [_rect('e1')]),
      CanvasLayer(id: CanvasLayerId('l2'), elements: [_rect('e2')]),
      CanvasLayer(id: CanvasLayerId('l3'), elements: [_rect('e3')]),
    ],
  );
}

void _expectLocationParity(
  LayerTable table,
  List<_ExpectedLayer> expectedLayers,
) {
  expect(table.rows, hasLength(expectedLayers.length));
  expect(table.layerLocationFacts, hasLength(expectedLayers.length));
  for (var index = 0; index < expectedLayers.length; index += 1) {
    final expected = expectedLayers[index];
    final row = table.rows[index];
    final location = table.locationFor(CanvasLayerId(expected.id));
    expect(row.id.value, expected.id);
    expect(row.elementIds.map((id) => id.value), expected.elementIds);
    expect(location, isNotNull);
    if (location == null) {
      return;
    }
    expect(location.index, index);
    expect(identical(location.row, row), isTrue);
    expect(location.row.id.value, expected.id);
  }
  expect(table.locationFor(CanvasLayerId('absent')), isNull);
}

final class _ExpectedLayer {
  const _ExpectedLayer(this.id, this.elementIds);

  final String id;
  final List<String> elementIds;
}

final class _LayerWork {
  final _counts = <LayerTableWorkEvent, int>{};

  void record(LayerTableWorkEvent event) {
    _counts.update(event, (count) => count + 1, ifAbsent: () => 1);
  }

  int count(LayerTableWorkEvent event) => _counts[event] ?? 0;
}

SchemaV1LayerImportEvent _layerEvent(String id) {
  return SchemaV1LayerImportEvent(
    id: CanvasLayerId(id),
    metadata: const CanvasMetadata.empty(),
  );
}

CanvasRectElement _rect(
  String id, {
  int revision = 0,
  Size size = const Size(1, 1),
}) {
  return CanvasRectElement(
    id: CanvasElementId(id),
    revision: revision,
    size: size,
  );
}
