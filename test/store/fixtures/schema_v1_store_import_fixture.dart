import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine/src/codec/schema_v1_import_events.dart';
import 'package:iwb_canvas_engine/src/store/document_store_kernel.dart';
import 'package:iwb_canvas_engine/src/store/schema_v1_store_import.dart';
import 'package:iwb_canvas_engine/src/store/store_revision_delta.dart';

void main() {
  _testValidImportPreparesAndInstallsRows();
  _testStorePreparationRejectsInvalidRows();
  _testPreparedImportsAreConsumeOnceAndStaleGuarded();
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
  expect(prepared.summary.elementCount, 2);
  expect(prepared.summary.layerCount, 1);
  expect(prepared.summary.resourceCount, 1);
  expect(prepared.resourceIds, {CanvasResourceId('resource-a')});
  expect(prepared.layerIds, {CanvasLayerId('layer-a')});
  expect(prepared.elementIds, {
    CanvasElementId('bg-rect'),
    CanvasElementId('image-a'),
  });
}

void _expectInstalledImportFacts(DocumentStoreKernel store) {
  expect(store.documentSummary.elementCount, 2);
  expect(store.documentSummary.layerCount, 1);
  expect(store.documentSummary.resourceCount, 1);
  expect(store.camera.offset, const Offset(2, 3));
  expect(store.resourceRevision, 1);
  expect(
    store.resourceDescriptor(CanvasResourceId('resource-a'))?.appKey,
    'asset/resource-a',
  );
  expect(
    store.elementFactsById(CanvasElementId('image-a'))?.resourceId,
    CanvasResourceId('resource-a'),
  );
  expect(store.resources.single, isA<CanvasImageResource>());
}

void _expectExplicitReadBuildsFirstProjection(
  DocumentStoreKernel store,
  int beforeProjectionBuilds,
) {
  final projected = store.readDocument();
  expect(projected.resources.single, isA<CanvasImageResource>());
  expect(store.projectionBuildCount, beforeProjectionBuilds + 1);
}

void _testPreparedImportsAreConsumeOnceAndStaleGuarded() {
  test('prepared imports are consume-once and stale guarded', () {
    final store = DocumentStoreKernel();
    final stale = _prepare(store, _validDocument(resourceId: 'resource-a'));
    final fresh = _prepare(store, _validDocument(resourceId: 'resource-b'));

    store.installPreparedSchemaV1Import(fresh);

    expect(
      () => store.installPreparedSchemaV1Import(stale),
      throwsA(isA<StateError>()),
    );

    final next = _prepare(store, _validDocument(resourceId: 'resource-c'));
    store.installPreparedSchemaV1Import(next);
    expect(
      () => store.installPreparedSchemaV1Import(next),
      throwsA(isA<StateError>()),
    );

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

PreparedStoreDocumentImport _prepare(
  DocumentStoreKernel store,
  Map<String, Object?> document, {
  StoreRevisionDelta delta = _replacementDelta,
}) {
  final sink = StoreSchemaV1ImportBuilder();
  importSchemaV1Document(document, sink);

  return store.prepareSchemaV1Import(sink, delta);
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
      'color': '#FFFFFFFF',
      'grid': {'enabled': false, 'cellSize': 10, 'color': '#1F000000'},
    },
    'palette': {
      'penColors': ['#FF000000'],
      'backgroundColors': ['#FFFFFFFF'],
      'gridSizes': [8],
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
