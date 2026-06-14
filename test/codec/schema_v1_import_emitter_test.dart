import 'dart:io';

import 'package:test/test.dart';

import '../support/flutter_consumer_test_harness.dart';

// The harness owns an embedded consumer fixture so the public compile proof and
// structural seam assertion stay in the same executable API-contract test.
// ignore: halstead-volume
void main() {
  test('schema v1 import emitter validates codec-owned load inputs', () async {
    await expectLater(
      runFlutterConsumerTest(
        packageName: 'iwb_canvas_engine_schema_v1_import_emitter',
        testFileName: 'schema_v1_import_emitter_test.dart',
        testSource: _schemaV1ImportEmitterSource,
      ),
      completes,
    );
  });

  test('schema v1 import emitter delegates to canonical reader seam', () {
    final emitterSource = File(
      'lib/src/codec/schema_v1_import_emitter.dart',
    ).readAsStringSync();
    final readerSource = File(
      'lib/src/codec/schema_v1_reader.dart',
    ).readAsStringSync();

    expect(emitterSource, isNotEmpty);
    expect(readerSource, isNotEmpty);
    _expectEmitterFacadeDelegatesToCanonicalReader(emitterSource);
    _expectCanonicalReaderSeamIsNamed(readerSource);
    _expectCodecReaderSourceIsOwnedAndNonRetained(emitterSource);
    _expectCodecReaderSourceIsOwnedAndNonRetained(readerSource);
  });
}

void _expectEmitterFacadeDelegatesToCanonicalReader(String source) {
  expect(source, contains(RegExp(r"import 'schema_v1_reader\.dart';")));
  _expectEmitterFacadeEntryPoints(source);
  _expectEmitterFacadeReaderCalls(source);
  _expectEmitterFacadeHasNoTraversalHelpers(source);
}

void _expectEmitterFacadeEntryPoints(String source) {
  expect(source, contains(RegExp(r'void importSchemaV1DocumentFromJson\(')));
  expect(
    source,
    contains(RegExp(r'void importSchemaV1DocumentFromJsonIntoIsolatedSink\(')),
  );
  expect(source, contains(RegExp(r'void importSchemaV1Document\(')));
  expect(
    source,
    contains(RegExp(r'void importSchemaV1DocumentIntoIsolatedSink\(')),
  );
}

void _expectEmitterFacadeReaderCalls(String source) {
  _expectDelegatingCall(source, 'readSchemaV1DocumentFromJson');
  _expectDelegatingCall(source, 'readSchemaV1DocumentFromJsonIntoIsolatedSink');
  _expectDelegatingCall(source, 'readSchemaV1Document');
  _expectDelegatingCall(source, 'readSchemaV1DocumentIntoIsolatedSink');
}

void _expectDelegatingCall(String source, String functionName) {
  expect(
    source,
    contains(
      RegExp(
        '$functionName'
        r'\(\s*json,\s*sink,\s*diagnostics: diagnostics,?\s*\)',
        multiLine: true,
      ),
    ),
  );
}

void _expectEmitterFacadeHasNoTraversalHelpers(String source) {
  expect(source, isNot(contains('jsonDecode')));
  expect(source, isNot(contains('_decodeRoot')));
  expect(source, isNot(contains(RegExp(r'_read[A-Za-z0-9_]*\('))));
  expect(source, isNot(contains(RegExp(r'_emit[A-Za-z0-9_]*\('))));
  expect(source, isNot(contains(RegExp(r'_validateSchema[A-Za-z0-9_]*\('))));
}

void _expectCanonicalReaderSeamIsNamed(String source) {
  expect(source, contains(RegExp(r'void readSchemaV1DocumentFromJson\(')));
  expect(
    source,
    contains(RegExp(r'void readSchemaV1DocumentFromJsonIntoIsolatedSink\(')),
  );
  expect(source, contains(RegExp(r'void readSchemaV1Document\(')));
}

void _expectCodecReaderSourceIsOwnedAndNonRetained(String source) {
  expect(source, isNot(contains('CanvasDocument')));
  expect(source, isNot(contains('CanvasImageResource')));
  expect(source, isNot(contains('../store/')));
  expect(source, isNot(contains('../runtime/')));
  expect(source, isNot(contains('../edit/')));
  expect(source, isNot(contains('../frame/')));
  expect(source, isNot(contains('package:flutter/widgets.dart')));
  expect(source, isNot(contains('decodeCanvasDocument')));
  expect(source, isNot(contains('decodeSchemaV1Document')));
  expect(source, isNot(contains('List<SchemaV1')));
  expect(source, isNot(contains('Map<CanvasElementId')));
  for (final retainedPayloadPattern in _retainedImportPayloadPatterns) {
    expect(source, isNot(contains(retainedPayloadPattern)));
  }
}

final _retainedImportPayloadPatterns = [
  RegExp(r'List<\s*SchemaV1[A-Za-z0-9_]*ImportEvent\b'),
  RegExp(r'<\s*SchemaV1[A-Za-z0-9_]*ImportEvent\s*>\s*\[\]'),
  RegExp(r'List<\s*SchemaV1[A-Za-z0-9_]*Fact\b'),
  RegExp(r'<\s*SchemaV1[A-Za-z0-9_]*Fact\s*>\s*\[\]'),
  RegExp(r'\b(?:events|facts|eventGraph|factGraph|eventBuffer|factBuffer)\s*='),
  RegExp(
    r'\b(?:retained|buffered|pending)(?:Events|Facts|EventGraph|FactGraph)\b',
  ),
];

const _schemaV1ImportEmitterSource = r'''
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine/src/codec/schema_v1_import_emitter.dart';
import 'package:iwb_canvas_engine/src/contracts/internal/schema_v1_import_events.dart';
import 'package:iwb_canvas_engine/src/contracts/public/canvas_contract_limits.dart';

void main() {
  _registerValidImportEventTests();
  _registerCodecFailureTests();
  _registerPartialEventTests();
  _registerTextValidationTests();
  _registerCodecOwnershipTests();
}

void _registerValidImportEventTests() {
  test('valid schema v1 JSON emits dependency-neutral import events', () {
    final sink = _CollectingImportSink();

    importSchemaV1DocumentFromJson(jsonEncode(_validDocument()), sink);

    expect(sink.events, [
      'begin',
      'resource:resource-a',
      'background:rect:bg-rect',
      'layer:layer-a',
      'layerElement:layer-a:image:image-a',
      'end',
    ]);
    expect(sink.resources.single.appKey, 'asset/resource-a');
    expect(sink.layerElements.single.$2, isA<SchemaV1ImageElementImportEvent>());
    expect(sink.backgroundElements.single, isA<SchemaV1RectElementImportEvent>());
  });
}

void _registerCodecFailureTests() {
  test('codec rejects malformed, oversized, schema, enum, metadata, and transform failures', () {
    _expectImportFailure(
      () => importSchemaV1DocumentFromJson('{', _CollectingImportSink()),
      CanvasDataErrorCode.invalidJson,
      r'$',
    );
    _expectImportFailure(
      () => importSchemaV1DocumentFromJson(
        ' ' * (canvasMaxRawJsonLength + 1),
        _CollectingImportSink(),
      ),
      CanvasDataErrorCode.maxRawJsonLength,
      r'$',
    );
    _expectImportFailure(
      () => importSchemaV1Document(
        {..._validDocument(), 'schemaVersion': 2},
        _CollectingImportSink(),
      ),
      CanvasDataErrorCode.unsupportedSchemaVersion,
      r'$.schemaVersion',
    );
    _expectImportFailure(
      () => importSchemaV1Document(
        {
          ..._validDocument(),
          'resources': [
            {
              'kind': 'video',
              'id': 'resource-a',
              'source': {'kind': 'appKey', 'key': 'asset/resource-a'},
            },
          ],
        },
        _CollectingImportSink(),
      ),
      CanvasDataErrorCode.invalidFieldType,
      'resource.kind',
    );
    _expectImportFailure(
      () => importSchemaV1Document(
        {
          ..._validDocument(),
          'resources': [
            {
              'kind': 'image',
              'id': 'resource-a',
              'source': {'kind': 'appKey', 'key': ' asset/resource-a '},
            },
          ],
        },
        _CollectingImportSink(),
      ),
      CanvasDataErrorCode.invalidFieldType,
      'resource.source.key',
    );
    _expectImportFailure(
      () => importSchemaV1Document(
        {
          ..._validDocument(),
          'backgroundLayer': {
            'elements': [
              {'id': 'video-a', 'kind': 'video'},
            ],
          },
        },
        _CollectingImportSink(),
      ),
      CanvasDataErrorCode.invalidFieldType,
      'element.kind',
    );
    _expectImportFailure(
      () => importSchemaV1Document(
        {
          ..._validDocument(),
          'backgroundLayer': {
            'elements': [
              {
                'id': 'path-a',
                'kind': 'path',
                'svgPathData': 'M 0 0',
                'strokeWidth': 0,
                'fillRule': 'diagonal',
              },
            ],
          },
        },
        _CollectingImportSink(),
      ),
      CanvasDataErrorCode.invalidFieldType,
      'path.fillRule',
    );
    _expectImportFailure(
      () => importSchemaV1Document(
        {
          ..._validDocument(),
          'metadata': {'tooLong': 'x' * (canvasMetadataMaxStringLength + 1)},
        },
        _CollectingImportSink(),
      ),
      CanvasDataErrorCode.invalidMetadata,
      'metadata.<value>',
    );
    _expectImportFailure(
      () => importSchemaV1Document(
        {
          ..._validDocument(),
          'backgroundLayer': {
            'elements': [
              {
                'id': 'rect-bad-transform',
                'kind': 'rect',
                'size': {'w': 1, 'h': 1},
                'transform': {
                  'a': 0,
                  'b': 0,
                  'c': 0,
                  'd': 0,
                  'tx': 0,
                  'ty': 0,
                },
              },
            ],
          },
        },
        _CollectingImportSink(),
      ),
      CanvasDataErrorCode.fieldMustBeInvertible,
      'element.transform',
    );
  });
}

void _registerPartialEventTests() {
  test('invalid documents emit no partial import events', () {
    final sink = _CollectingImportSink();

    _expectImportFailure(
      () => importSchemaV1Document(
        {
          ..._validDocument(),
          'layers': [
            {
              'id': 'layer-a',
              'elements': [
                {
                  'id': 'bad-text',
                  'kind': 'text',
                  'text': 'missing font size',
                  'color': '#FF000000',
                },
              ],
            },
          ],
        },
        sink,
      ),
      CanvasDataErrorCode.missingField,
      'text.fontSize',
    );
    expect(sink.events, isEmpty);
  });

  test('isolated sinks clear partial import events after invalid documents', () {
    final sink = _CollectingImportSink();

    _expectImportFailure(
      () => importSchemaV1DocumentIntoIsolatedSink(
        {
          ..._validDocument(),
          'layers': [
            {
              'id': 'layer-a',
              'elements': [
                {
                  'id': 'bad-text',
                  'kind': 'text',
                  'text': 'missing font size',
                  'color': '#FF000000',
                },
              ],
            },
          ],
        },
        sink,
      ),
      CanvasDataErrorCode.missingField,
      'text.fontSize',
    );
    expect(sink.events, isEmpty);
    expect(sink.resources, isEmpty);
    expect(sink.layers, isEmpty);
    expect(sink.layerElements, isEmpty);
  });

  test('isolated aggregate metadata overflow aborts accepted stream state', () {
    final sink = _CollectingImportSink();

    _expectImportFailure(
      () => importSchemaV1DocumentIntoIsolatedSink(
        _aggregateMetadataLimitDocument(),
        sink,
      ),
      CanvasDataErrorCode.invalidMetadata,
      'metadata',
    );

    expect(sink.wasAborted, isTrue);
    expect(
      sink.eventsBeforeAbort,
      containsAllInOrder([
        'begin',
        'resource:resource-a',
        'background:rect:bg-rect',
        'layer:layer-a',
        'layerElement:layer-a:rect:element-0',
      ]),
    );
    expect(sink.events, isEmpty);
    expect(sink.resources, isEmpty);
    expect(sink.backgroundElements, isEmpty);
    expect(sink.layers, isEmpty);
    expect(sink.layerElements, isEmpty);
  });

  test('isolated sinks abort on decode and root validation failures', () {
    final invalidJsonSink = _CollectingImportSink();
    _expectImportFailure(
      () => importSchemaV1DocumentFromJsonIntoIsolatedSink('{', invalidJsonSink),
      CanvasDataErrorCode.invalidJson,
      r'$',
    );
    expect(invalidJsonSink.wasAborted, isTrue);

    final invalidSchemaSink = _CollectingImportSink();
    _expectImportFailure(
      () => importSchemaV1DocumentIntoIsolatedSink(
        {..._validDocument(), 'schemaVersion': 2},
        invalidSchemaSink,
      ),
      CanvasDataErrorCode.unsupportedSchemaVersion,
      r'$.schemaVersion',
    );
    expect(invalidSchemaSink.wasAborted, isTrue);
  });
}

void _registerTextValidationTests() {
  test('text schema import preserves required field and null enum validation', () {
    _expectImportFailure(
      () => importSchemaV1Document(
        _documentWithText({'fontSize': null}),
        _CollectingImportSink(),
      ),
      CanvasDataErrorCode.missingField,
      'text.fontSize',
    );
    _expectImportFailure(
      () => importSchemaV1Document(
        _documentWithText({'textDirection': null}),
        _CollectingImportSink(),
      ),
      CanvasDataErrorCode.invalidFieldType,
      'text.textDirection',
    );
  });
}

void _registerCodecOwnershipTests() {
  test('duplicate ids and missing resource references are not codec-owned policy', () {
    final sink = _CollectingImportSink();

    importSchemaV1Document(
      {
        ..._validDocument(),
        'resources': [],
        'layers': [
          {
            'id': 'layer-a',
            'elements': [
              {
                'id': 'duplicate-id',
                'kind': 'rect',
                'size': {'w': 1, 'h': 1},
                'strokeWidth': 0,
              },
              {
                'id': 'duplicate-id',
                'kind': 'image',
                'resourceId': 'missing-resource',
                'size': {'w': 2, 'h': 2},
              },
            ],
          },
        ],
      },
      sink,
    );

    expect(sink.resources, isEmpty);
    expect(sink.layerElements, hasLength(2));
    expect(sink.layerElements.last.$2, isA<SchemaV1ImageElementImportEvent>());
  });
}

void _expectImportFailure(
  void Function() action,
  CanvasDataErrorCode code,
  String path,
) {
  expect(
    action,
    throwsA(
      isA<CanvasDataException>()
          .having((error) => error.code, 'code', code)
          .having((error) => error.path, 'path', path),
    ),
  );
}

Map<String, Object?> _documentWithText(Map<String, Object?> overrides) {
  return {
    ..._validDocument(),
    'layers': [
      {
        'id': 'layer-a',
        'metadata': {'owner': 'layer'},
        'elements': [
          {
            'id': 'text-a',
            'kind': 'text',
            'text': 'hello',
            'fontSize': 16,
            'color': '#FF000000',
            'textDirection': 'ltr',
            ...overrides,
          },
        ],
      },
    ],
  };
}

Map<String, Object?> _validDocument() {
  return {
    'schemaVersion': 1,
    'camera': {
      'offset': {'x': 2, 'y': 3},
    },
    'background': {
      'color': '#FFFFFFFF',
      'grid': {
        'enabled': false,
        'cellSize': 10,
        'color': '#1F000000',
      },
    },
    'palette': {
      'penColors': ['#FF000000'],
      'backgroundColors': ['#FFFFFFFF'],
      'gridSizes': [8],
    },
    'resources': [
      {
        'kind': 'image',
        'id': 'resource-a',
        'source': {'kind': 'appKey', 'key': 'asset/resource-a'},
        'mimeType': 'image/png',
        'contentHash': 'hash-a',
        'byteLength': 12,
        'metadata': {'owner': 'resource'},
      },
    ],
    'metadata': {'owner': 'document'},
    'backgroundLayer': {
      'elements': [
        {
          'id': 'bg-rect',
          'kind': 'rect',
          'size': {'w': 3, 'h': 4},
          'fillColor': '#FF0000FF',
          'strokeWidth': 0,
          'metadata': {'owner': 'background'},
        },
      ],
    },
    'layers': [
      {
        'id': 'layer-a',
        'metadata': {'owner': 'layer'},
        'elements': [
          {
            'id': 'image-a',
            'kind': 'image',
            'resourceId': 'resource-a',
            'size': {'w': 5, 'h': 6},
            'naturalSize': {'w': 10, 'h': 12},
          },
        ],
      },
    ],
  };
}

Map<String, Object?> _aggregateMetadataLimitDocument() {
  final largeValue = 'x' * 60000;

  return {
    ..._validDocument(),
    'layers': [
      {
        'id': 'layer-a',
        'elements': [
          for (var index = 0; index < 18; index += 1)
            {
              'id': 'element-' + index.toString(),
              'kind': 'rect',
              'size': {'w': 1, 'h': 1},
              'strokeWidth': 0,
              'metadata': {'chunk': largeValue},
            },
        ],
      },
    ],
  };
}

final class _CollectingImportSink implements IsolatedSchemaV1ImportSink {
  final events = <String>[];
  final resources = <SchemaV1ImageResourceImportEvent>[];
  final backgroundElements = <SchemaV1ElementImportEvent>[];
  final layers = <SchemaV1LayerImportEvent>[];
  final layerElements =
      <(CanvasLayerId, SchemaV1ElementImportEvent)>[];
  List<String> eventsBeforeAbort = const [];
  bool wasAborted = false;

  @override
  void beginDocument(SchemaV1DocumentImportEvent event) {
    events.add('begin');
  }

  @override
  void imageResource(SchemaV1ImageResourceImportEvent event) {
    resources.add(event);
    events.add('resource:${event.id.value}');
  }

  @override
  void backgroundElement(SchemaV1ElementImportEvent event) {
    backgroundElements.add(event);
    events.add('background:${event.common.kind.name}:${event.common.id.value}');
  }

  @override
  void layer(SchemaV1LayerImportEvent event) {
    layers.add(event);
    events.add('layer:${event.id.value}');
  }

  @override
  void layerElement(CanvasLayerId layerId, SchemaV1ElementImportEvent event) {
    layerElements.add((layerId, event));
    events.add(
      'layerElement:${layerId.value}:${event.common.kind.name}:${event.common.id.value}',
    );
  }

  @override
  void endDocument() {
    events.add('end');
  }

  @override
  void abortDocument() {
    wasAborted = true;
    eventsBeforeAbort = List.unmodifiable(events);
    events.clear();
    resources.clear();
    backgroundElements.clear();
    layers.clear();
    layerElements.clear();
  }
}
''';
