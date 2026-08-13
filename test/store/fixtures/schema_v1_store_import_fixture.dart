// Store import fixtures name row/table owners directly so one test proves the
// import handoff without hiding ownership behind helper-only imports.
// ignore_for_file: number-of-imports

import 'dart:ui' show Color, Size;

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine/src/codec/schema_v1_import_emitter.dart';
import 'package:iwb_canvas_engine/src/contracts/internal/schema_v1_import_events.dart';
import 'package:iwb_canvas_engine/src/edit/staged_document_load.dart';
import 'package:iwb_canvas_engine/src/store/document_store_kernel.dart';
import 'package:iwb_canvas_engine/src/store/family_tables.dart';
import 'package:iwb_canvas_engine/src/store/layer_table.dart';
import 'package:iwb_canvas_engine/src/store/resource_table.dart';
import 'package:iwb_canvas_engine/src/store/schema_v1_store_import.dart';
import 'package:iwb_canvas_engine/src/store/store_revision_delta.dart';

void main() {
  _testValidImportPreparesAndInstallsRows();
  _testPreparedSummaryIsOneImmutableSnapshot();
  _testPreparedSummaryCapturesBeforeItsFirstRead();
  _testPreparedSummaryIsScalarAtSupportedSize();
  _testDraftPreparedSummaryDoesNotEnumerateOwners();
  _testStorePreparationRejectsInvalidRows();
  _testPreparedImportsAreConsumeOnceAndStaleGuarded();
  _testImportBuildersAreConsumeOnce();
  _testStoreImportBuilderIsOneShot();
}

void _testPreparedSummaryIsOneImmutableSnapshot() {
  test(
    'prepared import retains one exact summary snapshot through consume',
    () {
      final store = DocumentStoreKernel();
      final prepared = _prepare(store, _validDocument());

      final first = prepared.summary;
      final second = prepared.summary;

      expect(
        first,
        const CanvasDocumentSummary(
          elementCount: 2,
          layerCount: 1,
          resourceCount: 1,
        ),
      );
      expect(second, same(first));

      store.installPreparedSchemaV1Import(prepared);

      expect(prepared.summary, same(first));
    },
  );
}

void _testPreparedSummaryCapturesBeforeItsFirstRead() {
  test('prepared import captures summary before its first read', () {
    final captureEvents = <PreparedSummaryWorkEvent>[];
    late PreparedStoreDocumentImport prepared;

    PreparedStoreDocumentImport.observeSummaryWork(captureEvents.add, () {
      prepared = _prepare(DocumentStoreKernel(), _validDocument());
    });

    expect(captureEvents, [PreparedSummaryWorkEvent.capture]);

    final readEvents = <PreparedSummaryWorkEvent>[];
    PreparedStoreDocumentImport.observeSummaryWork(readEvents.add, () {
      expect(prepared.summary.elementCount, 2);
    });

    expect(readEvents, [PreparedSummaryWorkEvent.storeSummaryRead]);
  });
}

void _testPreparedSummaryIsScalarAtSupportedSize() {
  test(
    'supported-size prepared import captures and reads scalar summary only',
    () {
      final events = <PreparedSummaryWorkEvent>[];
      final enumeration = _OwnerEnumerationTrace();
      final store = DocumentStoreKernel();

      final prepared = _prepareObservedSupportedImport(
        store,
        events: events,
        enumeration: enumeration,
        expectedSummary: _maximumSupportedPreparedSummary,
      );
      final first = _readObservedSummary(
        events,
        enumeration,
        () => prepared.summary,
      );

      expect(first, _maximumSupportedPreparedSummary);
      expect(
        _readObservedSummary(events, enumeration, () => prepared.summary),
        same(first),
      );
      expect(
        _readObservedSummary(events, enumeration, () => prepared.summary),
        same(first),
      );

      expect(events, [
        PreparedSummaryWorkEvent.capture,
        PreparedSummaryWorkEvent.storeSummaryRead,
        PreparedSummaryWorkEvent.storeSummaryRead,
        PreparedSummaryWorkEvent.storeSummaryRead,
      ]);
      enumeration.expectNoOwnerEnumeration();

      _expectSummaryRemainsScalarAfterInstallAttempts(store, prepared, first);
    },
  );
}

void _expectSummaryRemainsScalarAfterInstallAttempts(
  DocumentStoreKernel store,
  PreparedStoreDocumentImport prepared,
  CanvasDocumentSummary summary,
) {
  store.installPreparedSchemaV1Import(prepared);
  _expectFreshScalarSummaryRead(prepared, summary);

  expect(() => store.installPreparedSchemaV1Import(prepared), throwsStateError);
  _expectFreshScalarSummaryRead(prepared, summary);
}

void _expectFreshScalarSummaryRead(
  PreparedStoreDocumentImport prepared,
  CanvasDocumentSummary summary,
) {
  final events = <PreparedSummaryWorkEvent>[];
  final enumeration = _OwnerEnumerationTrace();

  expect(
    _readObservedSummary(events, enumeration, () => prepared.summary),
    same(summary),
  );
  expect(events, [PreparedSummaryWorkEvent.storeSummaryRead]);
  enumeration.expectNoOwnerEnumeration();
}

PreparedStoreDocumentImport _prepareObservedSupportedImport(
  DocumentStoreKernel store, {
  required List<PreparedSummaryWorkEvent> events,
  required _OwnerEnumerationTrace enumeration,
  required CanvasDocumentSummary expectedSummary,
}) {
  return enumeration.observe(
    () => PreparedStoreDocumentImport.observeSummaryWork(
      events.add,
      () => _prepareMaximumSupportedImport(
        store,
        elementCount: expectedSummary.elementCount,
        layerCount: expectedSummary.layerCount,
        resourceCount: expectedSummary.resourceCount,
      ),
    ),
  );
}

const _maximumSupportedPreparedSummary = CanvasDocumentSummary(
  elementCount: 200000,
  layerCount: 4096,
  resourceCount: 4096,
);

CanvasDocumentSummary _readObservedSummary(
  List<PreparedSummaryWorkEvent> events,
  _OwnerEnumerationTrace enumeration,
  CanvasDocumentSummary Function() read,
) {
  return enumeration.observe(
    () => PreparedStoreDocumentImport.observeSummaryWork(events.add, read),
  );
}

// This cross-owner witness belongs with the direct table observers that prove
// summary capture and reads do not open an authoritative owner enumeration.
void _testDraftPreparedSummaryDoesNotEnumerateOwners() {
  test('supported-size draft prepared summary does not enumerate owners', () {
    final events = <PreparedSummaryWorkEvent>[];
    final enumeration = _OwnerEnumerationTrace();
    final rejectingPipeline = LoadDocumentPipeline(
      store: DocumentStoreKernel(),
    );
    final document = _draftDocumentForSummaryOwnerWitness(
      _maximumSupportedPreparedSummary,
    );
    final prepared = enumeration.observe(
      () => PreparedStoreDocumentImport.observeSummaryWork(
        events.add,
        () => prepareDraftReplacement(document),
      ),
    );
    final first = _readObservedSummary(
      events,
      enumeration,
      () => prepared.summary,
    );

    expect(first, _maximumSupportedPreparedSummary);
    expect(
      _readObservedSummary(events, enumeration, () => prepared.summary),
      same(first),
    );
    expect(() => rejectingPipeline.consume(prepared), throwsStateError);
    expect(
      _readObservedSummary(events, enumeration, () => prepared.summary),
      same(first),
    );
    expect(events, [
      PreparedSummaryWorkEvent.capture,
      PreparedSummaryWorkEvent.loadSummaryRead,
      PreparedSummaryWorkEvent.loadSummaryRead,
      PreparedSummaryWorkEvent.loadSummaryRead,
    ]);
    enumeration.expectNoOwnerEnumeration();
  });
}

final class _OwnerEnumerationTrace {
  int familyOpenCount = 0;
  int layerOpenCount = 0;
  int resourceOpenCount = 0;

  T observe<T>(T Function() operation) {
    return FamilyTables.observeEnumeration(
      (event) {
        if (event == FamilyTablesEnumerationEvent.open) {
          familyOpenCount += 1;
        }
      },
      () => LayerTable.observeWork(
        (event) {
          if (event == LayerTableWorkEvent.admissionEnumerationOpen) {
            layerOpenCount += 1;
          }
        },
        () => ResourceTable.observeEnumeration((event) {
          if (event == ResourceTableEnumerationEvent.open) {
            resourceOpenCount += 1;
          }
        }, operation),
      ),
    );
  }

  void expectNoOwnerEnumeration() {
    expect(familyOpenCount, 0);
    expect(layerOpenCount, 0);
    expect(resourceOpenCount, 0);
  }
}

void _testValidImportPreparesAndInstallsRows() {
  test(
    'valid import prepares and installs committed rows without projection',
    () {
      final store = DocumentStoreKernel();
      final beforeProjectionBuilds = store.projectionBuildCount;
      final prepared = _prepare(store, _validDocument());

      _expectPreparedImportFacts(prepared);
      expect(store.projectionBuildCount, beforeProjectionBuilds);

      store.installPreparedSchemaV1Import(prepared);

      _expectInstalledImportFacts(store);
      expect(store.projectionBuildCount, beforeProjectionBuilds);
      _expectExplicitReadBuildsFirstProjection(store, beforeProjectionBuilds);
    },
  );
}

void _testStorePreparationRejectsInvalidRows() {
  test('store preparation owns duplicate and reference rejection', () {
    final failures = _prepareFailureCases();
    expect(failures, hasLength(4));
    for (final failure in failures) {
      _expectPrepareFailure(failure.document, failure.code, failure.path);
    }
  });
}

void _expectPreparedImportFacts(PreparedStoreDocumentImport prepared) {
  final summary = prepared.summary;
  expect(summary.elementCount, 2);
  expect(summary.layerCount, 1);
  expect(summary.resourceCount, 1);
  expect(prepared.summary, same(summary));
}

// Installed import facts stay in one assertion block so the fixture proves the
// committed document, resource, metadata, and projection boundaries together.
// ignore: halstead-volume
void _expectInstalledImportFacts(DocumentStoreKernel store) {
  expect(store.documentSummary.elementCount, 2);
  expect(store.documentSummary.layerCount, 1);
  expect(store.documentSummary.resourceCount, 1);
  expect(store.camera.offset, const Offset(2, 3));
  expect(store.background.color, const Color(0xFF112233));
  expect(store.background.grid.enabled, isTrue);
  expect(store.background.grid.cellSize, 17);
  expect(store.background.grid.color, const Color(0xFF445566));
  expect(store.palette.penColors, [const Color(0xFF102030)]);
  expect(store.palette.backgroundColors, [const Color(0xFF405060)]);
  expect(store.palette.gridSizes, [17]);
  expect(store.resourceRevision, 1);
  expect(
    store.resourceDescriptor(CanvasResourceId('resource-a'))?.appKey,
    'asset/resource-a',
  );
  expect(
    store.resourceDescriptor(CanvasResourceId('resource-a'))?.metadata['owner'],
    'resource',
  );
  expect(
    store.elementFactsById(CanvasElementId('image-a'))?.resourceId,
    CanvasResourceId('resource-a'),
  );
  expect(
    store.elementById(CanvasElementId('bg-rect'))?.metadata['owner'],
    'rect',
  );
  expect(store.resources.single, isA<CanvasImageResource>());
}

void _expectExplicitReadBuildsFirstProjection(
  DocumentStoreKernel store,
  int beforeProjectionBuilds,
) {
  final projected = store.readDocument();
  expect(projected.metadata['owner'], 'document');
  expect(projected.layers.single.metadata['owner'], 'layer');
  expect(projected.background.color, const Color(0xFF112233));
  expect(projected.palette.penColors, [const Color(0xFF102030)]);
  expect(projected.resources.single, isA<CanvasImageResource>());
  expect(store.projectionBuildCount, beforeProjectionBuilds + 1);
}

void _testPreparedImportsAreConsumeOnceAndStaleGuarded() {
  _testStalePreparedSummaryRemainsSnapshot();
  _testConsumedPreparedSummaryRemainsSnapshot();
}

void _testStalePreparedSummaryRemainsSnapshot() {
  test('prepared imports are consume-once and stale guarded', () {
    final store = DocumentStoreKernel();
    final stale = _prepare(store, _validDocument(resourceId: 'resource-a'));
    final fresh = _prepare(store, _validDocument(resourceId: 'resource-b'));
    final staleSummary = stale.summary;

    store.installPreparedSchemaV1Import(fresh);

    expect(
      () => store.installPreparedSchemaV1Import(stale),
      throwsA(isA<StateError>()),
    );
    expect(stale.summary, same(staleSummary));
  });
}

void _testConsumedPreparedSummaryRemainsSnapshot() {
  test('consumed prepared import retains its summary snapshot', () {
    final store = DocumentStoreKernel();
    final next = _prepare(store, _validDocument(resourceId: 'resource-c'));
    store.installPreparedSchemaV1Import(next);
    final nextSummary = next.summary;
    expect(
      () => store.installPreparedSchemaV1Import(next),
      throwsA(isA<StateError>()),
    );
    expect(next.summary, same(nextSummary));

    final noOp = _prepare(
      store,
      _validDocument(resourceId: 'resource-d'),
      delta: const StoreRevisionDelta(),
    );
    store.installPreparedSchemaV1Import(noOp);
    expect(
      () => store.installPreparedSchemaV1Import(noOp),
      throwsA(isA<StateError>()),
    );
  });
}

void _testImportBuildersAreConsumeOnce() {
  test('store import row builders are consume-once', () {
    expect(() {
      _expectResourceImportBuilderConsumeOnce();
      _expectFamilyImportBuilderConsumeOnce();
      _expectLayerImportBuilderConsumeOnce();
    }, returnsNormally);
  });
}

void _expectResourceImportBuilderConsumeOnce() {
  final resourceBuilder = StoreResourceDescriptorImportBuilder()
    ..addSchemaV1Import(_resourceEvent('resource-a'));
  resourceBuilder.consume(resourceRevision: 1);
  expect(
    () => resourceBuilder.addSchemaV1Import(_resourceEvent('resource-b')),
    throwsA(isA<StateError>()),
  );
  expect(
    () => resourceBuilder.consume(resourceRevision: 1),
    throwsA(isA<StateError>()),
  );
}

void _expectFamilyImportBuilderConsumeOnce() {
  final familyBuilder = FamilyTablesSchemaV1ImportBuilder()
    ..add(_rectEvent('rect-a'));
  familyBuilder.consume();
  expect(
    () => familyBuilder.add(_rectEvent('rect-b')),
    throwsA(isA<StateError>()),
  );
  expect(() => familyBuilder.consume(), throwsA(isA<StateError>()));
}

void _expectLayerImportBuilderConsumeOnce() {
  final layerBuilder = LayerTableSchemaV1ImportBuilder()
    ..addLayer(_layerEvent('layer-a'));
  layerBuilder.addElement(CanvasLayerId('layer-a'), CanvasElementId('rect-a'));
  layerBuilder.consume();
  expect(
    () => layerBuilder.addLayer(_layerEvent('layer-b')),
    throwsA(isA<StateError>()),
  );
  expect(() => layerBuilder.consume(), throwsA(isA<StateError>()));
}

void _testStoreImportBuilderIsOneShot() {
  test(
    'store schema import builder rejects stream reuse and append after end',
    () {
      final restartBuilder = StoreSchemaV1ImportBuilder();
      importSchemaV1Document(_validDocument(), restartBuilder);
      expect(
        () => importSchemaV1Document(_validDocument(), restartBuilder),
        throwsA(isA<StateError>()),
      );

      final appendBuilder = StoreSchemaV1ImportBuilder();
      importSchemaV1Document(_validDocument(), appendBuilder);
      expect(
        () => appendBuilder.resource(_resourceEvent('late-resource')),
        throwsA(isA<StateError>()),
      );

      _expectMissingRelationshipRejectedDuringStorePreparation();
    },
  );
}

void _expectMissingRelationshipRejectedDuringStorePreparation() {
  final builder = StoreSchemaV1ImportBuilder();
  importSchemaV1Document(_documentWithMissingResourceReference(), builder);
  expect(
    () => builder.resource(_resourceEvent('late-resource')),
    throwsA(isA<StateError>()),
  );
  final store = DocumentStoreKernel();
  final beforeSummary = store.documentSummary;
  final beforeProjectionBuilds = store.projectionBuildCount;
  expect(
    () => store.prepareSchemaV1Import(builder, _replacementDelta),
    throwsA(
      isA<CanvasDataException>()
          .having(
            (error) => error.code,
            'code',
            CanvasDataErrorCode.missingResourceReference,
          )
          .having((error) => error.path, 'path', 'image.resourceId'),
    ),
  );
  expect(store.documentSummary, beforeSummary);
  expect(store.projectionBuildCount, beforeProjectionBuilds);
}

PreparedStoreDocumentImport _prepare(
  DocumentStoreKernel store,
  Map<String, Object?> document, {
  StoreRevisionDelta delta = _replacementDelta,
}) {
  final sink = StoreSchemaV1ImportBuilder();
  importSchemaV1Document(document, sink);

  return store.prepareSchemaV1Import(sink, delta);
}

PreparedStoreDocumentImport _prepareMaximumSupportedImport(
  DocumentStoreKernel store, {
  required int elementCount,
  required int layerCount,
  required int resourceCount,
}) {
  final sink = StoreSchemaV1ImportBuilder()
    ..beginDocument(
      const SchemaV1DocumentImportEvent(
        camera: CanvasCamera.origin,
        background: CanvasBackground(),
        palette: CanvasPalette.defaults(),
        metadata: CanvasMetadata.empty(),
      ),
    );
  for (var index = 0; index < resourceCount; index += 1) {
    sink.resource(_resourceEvent('r$index'));
  }
  for (var index = 0; index < elementCount; index += 1) {
    sink.backgroundElement(_rectEvent('e$index'));
  }
  for (var index = 0; index < layerCount; index += 1) {
    sink.layer(_layerEvent('l$index'));
  }
  sink.endDocument();

  return store.prepareSchemaV1Import(sink, _replacementDelta);
}

void _expectPrepareFailure(
  Map<String, Object?> document,
  CanvasDataErrorCode code,
  String path,
) {
  final store = DocumentStoreKernel();
  final before = store.documentSummary;
  final beforeProjectionBuilds = store.projectionBuildCount;

  expect(
    () => _prepare(store, document),
    throwsA(
      isA<CanvasDataException>()
          .having((error) => error.code, 'code', code)
          .having((error) => error.path, 'path', path),
    ),
  );
  expect(store.documentSummary, before);
  expect(store.projectionBuildCount, beforeProjectionBuilds);
}

List<_PrepareFailureCase> _prepareFailureCases() {
  return [
    _PrepareFailureCase(
      document: _documentWithDuplicateResources(),
      code: CanvasDataErrorCode.duplicateResourceId,
      path: 'resources.id',
    ),
    _PrepareFailureCase(
      document: _documentWithDuplicateLayers(),
      code: CanvasDataErrorCode.duplicateLayerId,
      path: 'layers.id',
    ),
    _PrepareFailureCase(
      document: _documentWithDuplicateElements(),
      code: CanvasDataErrorCode.duplicateElementId,
      path: 'elements.id',
    ),
    _PrepareFailureCase(
      document: _documentWithMissingResourceReference(),
      code: CanvasDataErrorCode.missingResourceReference,
      path: 'image.resourceId',
    ),
  ];
}

Map<String, Object?> _documentWithDuplicateResources() {
  return {
    ..._validDocument(),
    'resources': [_resource('resource-a'), _resource('resource-a')],
  };
}

Map<String, Object?> _documentWithDuplicateLayers() {
  return {
    ..._validDocument(),
    'layers': [
      {'id': 'layer-a', 'elements': <Object?>[]},
      {'id': 'layer-a', 'elements': <Object?>[]},
    ],
  };
}

Map<String, Object?> _documentWithDuplicateElements() {
  return {
    ..._validDocument(),
    'backgroundLayer': {
      'elements': [_rect('duplicate-id')],
    },
    'layers': [
      {
        'id': 'layer-a',
        'elements': [_rect('duplicate-id')],
      },
    ],
  };
}

Map<String, Object?> _documentWithMissingResourceReference() {
  return {
    ..._validDocument(),
    'resources': <Object?>[],
    'layers': [
      {
        'id': 'layer-a',
        'elements': [
          {
            'id': 'image-a',
            'kind': 'image',
            'resourceId': 'missing-resource',
            'size': {'w': 5, 'h': 6},
          },
        ],
      },
    ],
  };
}

final class _PrepareFailureCase {
  const _PrepareFailureCase({
    required this.document,
    required this.code,
    required this.path,
  });

  final Map<String, Object?> document;
  final CanvasDataErrorCode code;
  final String path;
}

Map<String, Object?> _validDocument({String resourceId = 'resource-a'}) {
  return {
    'schemaVersion': 1,
    'camera': {
      'offset': {'x': 2, 'y': 3},
    },
    'background': {
      'color': '#FF112233',
      'grid': {'enabled': true, 'cellSize': 17, 'color': '#FF445566'},
    },
    'palette': {
      'penColors': ['#FF102030'],
      'backgroundColors': ['#FF405060'],
      'gridSizes': [17],
    },
    'resources': [_resource(resourceId)],
    'metadata': {'owner': 'document'},
    'backgroundLayer': {
      'elements': [_rect('bg-rect')],
    },
    'layers': [
      {
        'id': 'layer-a',
        'metadata': {'owner': 'layer'},
        'elements': [
          {
            'id': 'image-a',
            'kind': 'image',
            'resourceId': resourceId,
            'size': {'w': 5, 'h': 6},
            'naturalSize': {'w': 10, 'h': 12},
          },
        ],
      },
    ],
  };
}

CanvasDocument _draftDocumentForSummaryOwnerWitness(
  CanvasDocumentSummary expectedSummary,
) {
  return CanvasDocument(
    resources: List.generate(expectedSummary.resourceCount, (index) {
      final id = CanvasResourceId('draft-resource-$index');
      return CanvasImageResource(
        id: id,
        source: CanvasResourceSource.appKey(id.value),
      );
    }),
    backgroundElements: List.generate(
      expectedSummary.elementCount,
      (index) => CanvasRectElement(
        id: CanvasElementId('draft-element-$index'),
        size: const Size(1, 1),
      ),
    ),
    layers: List.generate(
      expectedSummary.layerCount,
      (index) => CanvasLayer(id: CanvasLayerId('draft-layer-$index')),
    ),
  );
}

Map<String, Object?> _resource(String id) {
  return {
    'kind': 'image',
    'id': id,
    'source': {'kind': 'appKey', 'key': 'asset/$id'},
    'mimeType': 'image/png',
    'contentHash': 'hash-$id',
    'byteLength': 12,
    'metadata': {'owner': 'resource'},
  };
}

SchemaV1ImageResourceImportEvent _resourceEvent(String id) {
  return SchemaV1ImageResourceImportEvent(
    id: CanvasResourceId(id),
    appKey: 'asset/$id',
    mimeType: 'image/png',
    contentHash: 'hash-$id',
    byteLength: 12,
    metadata: const CanvasMetadata.empty(),
  );
}

SchemaV1LayerImportEvent _layerEvent(String id) {
  return SchemaV1LayerImportEvent(
    id: CanvasLayerId(id),
    metadata: const CanvasMetadata.empty(),
  );
}

SchemaV1RectElementImportEvent _rectEvent(String id) {
  return SchemaV1RectElementImportEvent(
    common: SchemaV1ElementCommonImport(
      id: CanvasElementId(id),
      kind: CanvasElementKind.rect,
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
    ),
    size: const Size(3, 4),
    fillColor: const Color(0xFF0000FF),
    strokeColor: null,
    strokeWidth: 0,
  );
}

Map<String, Object?> _rect(String id) {
  return {
    'id': id,
    'kind': 'rect',
    'size': {'w': 3, 'h': 4},
    'fillColor': '#FF0000FF',
    'strokeWidth': 0,
    'metadata': {'owner': 'rect'},
  };
}

const _replacementDelta = StoreRevisionDelta(
  document: true,
  projection: true,
  structural: true,
  bounds: true,
  elementVisual: true,
  background: true,
  grid: true,
  resource: true,
);
