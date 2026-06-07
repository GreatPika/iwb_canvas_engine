import 'dart:convert';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine/src/diagnostics/diagnostic_code.dart';
import 'package:iwb_canvas_engine/src/diagnostics/diagnostics_hub.dart';
import 'package:iwb_canvas_engine/src/edit/staged_document_load.dart';
import 'package:iwb_canvas_engine/src/store/document_store_kernel.dart';

import '../../support/document_store_with_document.dart';

void main() {
  test('successful preparation is immutable and consume installs once', () {
    expect(_expectSuccessfulPreparationAndConsume, returnsNormally);
  });

  test('prepared loads cannot be consumed by another pipeline', () {
    expect(_expectWrongPipelineRejected, returnsNormally);
  });

  test('failed preparation leaves store unchanged', () {
    expect(_expectFailedPreparationLeavesStoreUnchanged, returnsNormally);
  });

  test('diagnostics route failures only when recording is enabled', () {
    expect(_expectDiagnosticsRouting, returnsNormally);
  });

  test(
    'public DTO constructors reject invalid metadata and transforms early',
    () {
      expect(_expectPublicDtoInvalidInputRejectedEarly, returnsNormally);
    },
  );

  test('draft replacement freezes mutable source list ownership', () {
    expect(_expectPreparedDtoOwnershipFrozen, returnsNormally);
  });
}

void _expectSuccessfulPreparationAndConsume() {
  final store = documentStoreWithDocument(_initialDocument());
  final pipeline = LoadDocumentPipeline(store: store);

  final prepared = _prepareFromDocument(pipeline, _replacementDocument());

  expect(prepared.summary.elementCount, 2);
  expect(prepared.summary.layerCount, 1);
  expect(prepared.summary.resourceCount, 1);
  expect(prepared.background.color, const Color(0xFF112233));
  expect(prepared.background.grid, CanvasGrid.disabled);
  expect(prepared.elementIds.map((id) => id.value), {'load-bg', 'load-img'});
  expect(prepared.layerIds.map((id) => id.value), {'load-layer'});
  expect(prepared.resourceIds.map((id) => id.value), {'load-resource'});
  expect(() => prepared.elementIds.clear(), throwsUnsupportedError);
  expect(() => prepared.layerIds.clear(), throwsUnsupportedError);
  expect(() => prepared.resourceIds.clear(), throwsUnsupportedError);
  expect(() => prepared.document, throwsStateError);
  _expectInitialStore(store);

  pipeline.consume(prepared);

  _expectReplacementStore(store);
  expect(() => pipeline.consume(prepared), throwsStateError);
  expect(store.documentRevision, 2);
}

void _expectWrongPipelineRejected() {
  final firstStore = documentStoreWithDocument(_initialDocument());
  final secondStore = documentStoreWithDocument(_initialDocument());
  final prepared = LoadDocumentPipeline(
    store: firstStore,
  ).prepareFromJson(encodeCanvasDocumentToJson(_replacementDocument()));
  final secondPipeline = LoadDocumentPipeline(store: secondStore);

  expect(() => secondPipeline.consume(prepared), throwsStateError);
  expect(secondStore.documentSummary.elementCount, 1);
  expect(secondStore.documentRevision, 1);
}

void _expectFailedPreparationLeavesStoreUnchanged() {
  final failures = <CanvasDocument Function()>[
    _documentWithDuplicateResources,
    _documentWithDuplicateLayers,
    _documentWithDuplicateElements,
    _documentWithMissingResourceReference,
  ];

  for (final failure in failures) {
    final store = documentStoreWithDocument(_initialDocument());
    final pipeline = LoadDocumentPipeline(store: store);

    expect(
      () => _prepareFromDocument(pipeline, failure()),
      throwsA(isA<CanvasDataException>()),
    );
    expect(store.readDocument().backgroundElements.single.id.value, 'e0');
    expect(store.documentRevision, 1);
    expect(store.structuralRevision, 1);
    expect(store.resourceRevision, 1);
  }
}

void _expectDiagnosticsRouting() {
  final enabled = LoadDocumentPipeline(
    store: documentStoreWithDocument(_initialDocument()),
    diagnosticPolicy: const CanvasDiagnosticPolicy.summary(),
  );

  expect(enabled.hasDiagnosticsRecordingSurface, isTrue);
  expect(
    () => enabled.prepareFromJson(_jsonWithDuplicateResources()),
    throwsA(isA<CanvasDataException>()),
  );
  expect(enabled.diagnosticRecordCount, 1);
  expect(
    enabled.diagnosticRecords.single.code,
    const DiagnosticCode.data(CanvasDataErrorCode.duplicateResourceId),
  );

  DiagnosticRecord.allocations.reset();
  final disabled = LoadDocumentPipeline(
    store: documentStoreWithDocument(_initialDocument()),
  );
  final before = DiagnosticRecord.allocations.count;

  expect(disabled.hasDiagnosticsRecordingSurface, isFalse);
  expect(
    () => disabled.prepareFromJson(_jsonWithDuplicateResources()),
    throwsA(isA<CanvasDataException>()),
  );
  expect(disabled.diagnosticRecordCount, 0);
  expect(disabled.diagnosticRecords, isEmpty);
  expect(DiagnosticRecord.allocations.count, before);
}

void _expectPublicDtoInvalidInputRejectedEarly() {
  final store = documentStoreWithDocument(_initialDocument());
  final longMetadataValue = 'x' * 65537;
  final singularTransform = CanvasTransform.scale(0, 1);

  expect(
    () => CanvasDocument(
      metadata: CanvasMetadata.fromMap({'tooLong': longMetadataValue}),
    ),
    throwsA(
      isA<CanvasDataException>().having(
        (error) => error.code,
        'code',
        CanvasDataErrorCode.invalidMetadata,
      ),
    ),
  );
  expect(
    () => CanvasRectElement(
      id: CanvasElementId('bad-transform'),
      size: const Size(1, 1),
      transform: singularTransform,
    ),
    throwsA(
      isA<CanvasDataException>().having(
        (error) => error.code,
        'code',
        CanvasDataErrorCode.fieldMustBeInvertible,
      ),
    ),
  );
  expect(store.readDocument().backgroundElements.single.id.value, 'e0');
  expect(store.documentRevision, 1);
}

void _expectPreparedDtoOwnershipFrozen() {
  final parts = _MutableDocumentParts.create();

  final prepared = prepareDraftReplacement(parts.document);
  parts.clearSources();

  expect(prepared.summary.resourceCount, 1);
  expect(prepared.summary.elementCount, 1);
  expect(prepared.summary.layerCount, 1);
  _expectPreparedDocumentCollectionsFrozen(prepared);
}

void _expectPreparedDocumentCollectionsFrozen(PreparedDocumentLoad prepared) {
  expect(() => prepared.document.resources.clear(), throwsUnsupportedError);
  expect(
    () => prepared.document.backgroundElements.clear(),
    throwsUnsupportedError,
  );
  expect(() => prepared.document.layers.clear(), throwsUnsupportedError);
}

PreparedDocumentLoad _prepareFromDocument(
  LoadDocumentPipeline pipeline,
  CanvasDocument document,
) {
  return pipeline.prepareFromJson(encodeCanvasDocumentToJson(document));
}

String _jsonWithDuplicateResources() {
  final resource = CanvasImageResource(
    id: CanvasResourceId('duplicate-resource'),
    source: CanvasResourceSource.appKey('duplicate-resource'),
  );
  final json = encodeCanvasDocument(CanvasDocument(resources: [resource]));
  final encodedResource = (json['resources']! as List<Object?>).single;
  json['resources'] = [encodedResource, encodedResource];

  return jsonEncode(json);
}

final class _MutableDocumentParts {
  _MutableDocumentParts._({
    required this.resources,
    required this.backgroundElements,
    required this.layers,
    required this.document,
  });

  factory _MutableDocumentParts.create() {
    final resources = [
      CanvasImageResource(
        id: CanvasResourceId('load-resource'),
        source: CanvasResourceSource.appKey('load-resource'),
      ),
    ];
    final backgroundElements = [
      CanvasRectElement(id: CanvasElementId('load-bg'), size: const Size(1, 1)),
    ];
    final layers = [CanvasLayer(id: CanvasLayerId('load-layer'))];

    return _MutableDocumentParts._(
      resources: resources,
      backgroundElements: backgroundElements,
      layers: layers,
      document: CanvasDocument(
        resources: resources,
        backgroundElements: backgroundElements,
        layers: layers,
      ),
    );
  }

  final List<CanvasResource> resources;
  final List<CanvasElement> backgroundElements;
  final List<CanvasLayer> layers;
  final CanvasDocument document;

  void clearSources() {
    resources.clear();
    backgroundElements.clear();
    layers.clear();
  }
}

void _expectInitialStore(DocumentStoreKernel store) {
  expect(store.documentSummary.elementCount, 1);
  expect(store.documentRevision, 1);
  expect(store.structuralRevision, 1);
  expect(store.boundsRevision, 1);
  expect(store.elementVisualRevision, 1);
  expect(store.backgroundRevision, 1);
  expect(store.gridRevision, 1);
  expect(store.resourceRevision, 1);
}

void _expectReplacementStore(DocumentStoreKernel store) {
  expect(store.documentSummary.elementCount, 2);
  expect(store.documentSummary.layerCount, 1);
  expect(store.documentSummary.resourceCount, 1);
  expect(store.readDocument().backgroundElements.single.id.value, 'load-bg');
  expect(store.generateElementId(), CanvasElementId('e0'));
  expect(store.documentRevision, 2);
  expect(store.structuralRevision, 2);
  expect(store.boundsRevision, 2);
  expect(store.elementVisualRevision, 2);
  expect(store.backgroundRevision, 2);
  expect(store.gridRevision, 2);
  expect(store.resourceRevision, 2);
}

CanvasDocument _initialDocument() {
  return CanvasDocument(
    backgroundElements: [
      CanvasRectElement(id: CanvasElementId('e0'), size: const Size(1, 1)),
    ],
  );
}

CanvasDocument _replacementDocument() {
  return CanvasDocument(
    background: const CanvasBackground(
      color: Color(0xFF112233),
      grid: CanvasGrid.disabled,
    ),
    resources: [
      CanvasImageResource(
        id: CanvasResourceId('load-resource'),
        source: CanvasResourceSource.appKey('load-resource'),
      ),
    ],
    backgroundElements: [
      CanvasRectElement(id: CanvasElementId('load-bg'), size: const Size(1, 1)),
    ],
    layers: [
      CanvasLayer(
        id: CanvasLayerId('load-layer'),
        elements: [
          CanvasImageElement(
            id: CanvasElementId('load-img'),
            resourceId: CanvasResourceId('load-resource'),
            size: const Size(2, 2),
          ),
        ],
      ),
    ],
  );
}

CanvasDocument _documentWithDuplicateResources() {
  return CanvasDocument(
    resources: [
      CanvasImageResource(
        id: CanvasResourceId('duplicate-resource'),
        source: CanvasResourceSource.appKey('first'),
      ),
      CanvasImageResource(
        id: CanvasResourceId('duplicate-resource'),
        source: CanvasResourceSource.appKey('second'),
      ),
    ],
  );
}

CanvasDocument _documentWithDuplicateLayers() {
  return CanvasDocument(
    layers: [
      CanvasLayer(id: CanvasLayerId('duplicate-layer')),
      CanvasLayer(id: CanvasLayerId('duplicate-layer')),
    ],
  );
}

CanvasDocument _documentWithDuplicateElements() {
  return CanvasDocument(
    backgroundElements: [
      CanvasRectElement(
        id: CanvasElementId('duplicate-element'),
        size: const Size(1, 1),
      ),
    ],
    layers: [
      CanvasLayer(
        id: CanvasLayerId('layer-a'),
        elements: [
          CanvasRectElement(
            id: CanvasElementId('duplicate-element'),
            size: const Size(1, 1),
          ),
        ],
      ),
    ],
  );
}

CanvasDocument _documentWithMissingResourceReference() {
  return CanvasDocument(
    backgroundElements: [
      CanvasImageElement(
        id: CanvasElementId('missing-image'),
        resourceId: CanvasResourceId('missing-resource'),
        size: const Size(1, 1),
      ),
    ],
  );
}
