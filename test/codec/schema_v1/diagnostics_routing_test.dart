import 'dart:io';

import 'package:test/test.dart';

import '../../support/flutter_consumer_test_harness.dart';

void main() {
  test('schema v1 routes decode failures to diagnostics internally', () async {
    await expectLater(
      runFlutterConsumerTest(
        packageName: 'iwb_canvas_engine_schema_v1_diagnostics',
        testFileName: 'diagnostics_routing_test.dart',
        testSource: _diagnosticsRoutingSource,
      ),
      completes,
    );
  });

  test('schema codec diagnostics route has no runtime or store dependency', () {
    for (final path in [
      'lib/src/codec/schema_v1_decoder.dart',
      'lib/src/codec/schema_v1_diagnostics.dart',
      'lib/src/codec/schema_v1_import_emitter.dart',
      'lib/src/codec/schema_v1_validation.dart',
    ]) {
      final source = File(path).readAsStringSync();

      expect(source, isNot(contains('../runtime/')));
      expect(source, isNot(contains('../store/')));
      expect(source, isNot(contains('/src/runtime/')));
      expect(source, isNot(contains('/src/store/')));
    }
  });
}

const _diagnosticsRoutingSource = r'''
import 'package:flutter_test/flutter_test.dart';
	import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
	import 'package:iwb_canvas_engine/src/codec/schema_v1_decoder.dart';
	import 'package:iwb_canvas_engine/src/codec/schema_v1_encoder.dart';
	import 'package:iwb_canvas_engine/src/codec/schema_v1_import_emitter.dart';
	import 'package:iwb_canvas_engine/src/contracts/internal/schema_v1_import_events.dart';
	import 'package:iwb_canvas_engine/src/diagnostics/diagnostic_code.dart';
	import 'package:iwb_canvas_engine/src/diagnostics/diagnostics_hub.dart';

void main() {
  test('internal decode functions stay parameter-free and preserve failures', () {
    final CanvasDocument Function(Map<String, Object?>) decodeMap =
        decodeSchemaV1Document;
    final CanvasDocument Function(String) decodeJson =
        decodeSchemaV1DocumentFromJson;
    final invalid = _invalidResourceKindDocument();

    final publicFailure = _captureFailure(() => decodeMap(invalid));
    final internalFailure = _captureFailure(
      () => decodeSchemaV1Document(invalid),
    );
    final jsonFailure = _captureFailure(
      () => decodeJson('{"schemaVersion":2}'),
    );

    _expectSameFailure(publicFailure, internalFailure);
    expect(jsonFailure.code, CanvasDataErrorCode.unsupportedSchemaVersion);
    expect(jsonFailure.path, r'$.schemaVersion');
  });

  test('internal decode records sanitized schema failures when enabled', () {
    final summaryHub = DiagnosticsHub(
      policy: const CanvasDiagnosticPolicy.summary(),
    );
    final verboseHub = DiagnosticsHub(
      policy: CanvasDiagnosticPolicy.verbose(
        maxPreviewLength: 24,
        maxListEntries: 2,
      ),
    );

    expect(
      () => decodeSchemaV1Document(
        _invalidResourceKindDocument(),
        diagnostics: summaryHub,
      ),
      throwsA(isA<CanvasDataException>()),
    );
    expect(
      () => decodeSchemaV1Document(
        _invalidResourceKindDocument(),
        diagnostics: verboseHub,
      ),
      throwsA(isA<CanvasDataException>()),
    );

    _expectCodecFailureRecord(
      summaryHub.records.single,
      message: 'unknown resource kind.',
      kind: 'video',
    );
    _expectCodecFailureRecord(
      verboseHub.records.single,
      message: 'unknown resource kind.',
      kind: 'video',
    );
  });

  test('internal decode records constructor materialization failures', () {
    final hub = DiagnosticsHub(policy: const CanvasDiagnosticPolicy.summary());

    expect(
      () => decodeSchemaV1Document(
        {
          'schemaVersion': 1,
          'camera': {
            'offset': {'x': double.nan, 'y': 0},
          },
        },
        diagnostics: hub,
      ),
      throwsA(
        isA<CanvasDataException>()
            .having(
              (error) => error.code,
              'code',
              CanvasDataErrorCode.fieldMustBeFinite,
            )
            .having((error) => error.path, 'path', 'camera.offset.dx'),
      ),
    );

    expect(hub.recordCount, 1);
    expect(
      hub.records.single.code,
      DiagnosticCode.data(CanvasDataErrorCode.fieldMustBeFinite),
    );
    expect(hub.records.single.path, 'camera.offset.dx');
  });

  test('internal decode records resource id materialization failures', () {
    final hub = DiagnosticsHub(policy: const CanvasDiagnosticPolicy.summary());

    expect(
      () => decodeSchemaV1Document(
        {
          'schemaVersion': 1,
          'resources': [
            {
              'kind': 'image',
              'id': '',
              'source': {'kind': 'appKey', 'key': 'resource-1'},
            },
          ],
        },
        diagnostics: hub,
      ),
      throwsA(
        isA<CanvasDataException>()
            .having(
              (error) => error.code,
              'code',
              CanvasDataErrorCode.fieldMustNotBeEmpty,
            )
            .having((error) => error.path, 'path', 'resource.id'),
      ),
    );

    expect(hub.recordCount, 1);
    expect(
      hub.records.single.code,
      DiagnosticCode.data(CanvasDataErrorCode.fieldMustNotBeEmpty),
    );
    expect(hub.records.single.path, 'resource.id');
  });

  test('internal decode reports appKey value failures at JSON key path', () {
    final blankHub = DiagnosticsHub(
      policy: const CanvasDiagnosticPolicy.summary(),
    );
    final newlineHub = DiagnosticsHub(
      policy: const CanvasDiagnosticPolicy.summary(),
    );
    final lengthHub = DiagnosticsHub(
      policy: const CanvasDiagnosticPolicy.summary(),
    );
    final controlHub = DiagnosticsHub(
      policy: const CanvasDiagnosticPolicy.summary(),
    );

    expect(
      () => decodeSchemaV1Document(
        _resourceAppKeyDocument(' asset-a '),
        diagnostics: blankHub,
      ),
      throwsA(
        isA<CanvasDataException>()
            .having(
              (error) => error.code,
              'code',
              CanvasDataErrorCode.invalidFieldType,
            )
            .having((error) => error.path, 'path', 'resource.source.key'),
      ),
    );
    expect(blankHub.recordCount, 1);
    expect(
      blankHub.records.single.code,
      DiagnosticCode.data(CanvasDataErrorCode.invalidFieldType),
    );
    expect(blankHub.records.single.path, 'resource.source.key');

    expect(
      () => decodeSchemaV1Document(
        _resourceAppKeyDocument('asset-a\n'),
        diagnostics: newlineHub,
      ),
      throwsA(
        isA<CanvasDataException>()
            .having(
              (error) => error.code,
              'code',
              CanvasDataErrorCode.invalidFieldType,
            )
            .having((error) => error.path, 'path', 'resource.source.key'),
      ),
    );
    expect(newlineHub.recordCount, 1);
    expect(
      newlineHub.records.single.code,
      DiagnosticCode.data(CanvasDataErrorCode.invalidFieldType),
    );
    expect(newlineHub.records.single.path, 'resource.source.key');

    final oversizedKey = ' ${List.filled(1023, 'a').join()} ';
    expect(
      () => decodeSchemaV1Document(
        _resourceAppKeyDocument(oversizedKey),
        diagnostics: lengthHub,
      ),
      throwsA(
        isA<CanvasDataException>()
            .having(
              (error) => error.code,
              'code',
              CanvasDataErrorCode.fieldMaxLength,
            )
            .having((error) => error.path, 'path', 'resource.source.key')
            .having(
              (error) => error.details,
              'details',
              containsPair('actualLength', 1025),
            ),
      ),
    );
    expect(lengthHub.recordCount, 1);
    expect(
      lengthHub.records.single.code,
      DiagnosticCode.data(CanvasDataErrorCode.fieldMaxLength),
    );
    expect(lengthHub.records.single.path, 'resource.source.key');

    expect(
      () => decodeSchemaV1Document(
        _resourceAppKeyDocument('asset-\u0001'),
        diagnostics: controlHub,
      ),
      throwsA(
        isA<CanvasDataException>()
            .having(
              (error) => error.code,
              'code',
              CanvasDataErrorCode.invalidFieldType,
            )
            .having((error) => error.path, 'path', 'resource.source.key'),
      ),
    );
    expect(controlHub.recordCount, 1);
    expect(
      controlHub.records.single.code,
      DiagnosticCode.data(CanvasDataErrorCode.invalidFieldType),
    );
    expect(controlHub.records.single.path, 'resource.source.key');
  });

  test('internal decode and encode preserve valid appKey exactly', () {
    final decoded = decodeSchemaV1Document(_resourceAppKeyDocument('asset a'));

    expect(_decodedResourceAppKey(decoded), 'asset a');
    expect(_encodedResourceAppKey(encodeSchemaV1Document(decoded)), 'asset a');
  });

  test('internal encode records schema validation failures when enabled', () {
    final hub = DiagnosticsHub(policy: const CanvasDiagnosticPolicy.summary());
    final document = CanvasDocument(
      resources: [
        CanvasImageResource(
          id: CanvasResourceId('resource-1'),
          source: CanvasResourceSource.appKey('resource-1'),
        ),
        CanvasImageResource(
          id: CanvasResourceId('resource-1'),
          source: CanvasResourceSource.appKey('resource-1-copy'),
        ),
      ],
    );

    expect(
      () => encodeSchemaV1Document(document, diagnostics: hub),
      throwsA(
        isA<CanvasDataException>()
            .having(
              (error) => error.code,
              'code',
              CanvasDataErrorCode.duplicateResourceId,
            )
            .having((error) => error.path, 'path', 'resources.id'),
      ),
    );

    expect(hub.recordCount, 1);
    expect(
      hub.records.single.code,
      DiagnosticCode.data(CanvasDataErrorCode.duplicateResourceId),
    );
    expect(hub.records.single.path, 'resources.id');
  });

  test('schema v1 import emitter records each data failure exactly once', () {
    final readFailureHub = DiagnosticsHub(
      policy: const CanvasDiagnosticPolicy.summary(),
    );
    final materializeFailureHub = DiagnosticsHub(
      policy: const CanvasDiagnosticPolicy.summary(),
    );

    expect(
      () => importSchemaV1Document(
        _importDocumentWithTransform({'a': 'bad'}),
        _NoopImportSink(),
        diagnostics: readFailureHub,
      ),
      throwsA(
        isA<CanvasDataException>()
            .having(
              (error) => error.code,
              'code',
              CanvasDataErrorCode.invalidFieldType,
            )
            .having((error) => error.path, 'path', 'transform.a'),
      ),
    );
    expect(readFailureHub.recordCount, 1);
    expect(
      readFailureHub.records.single.code,
      DiagnosticCode.data(CanvasDataErrorCode.invalidFieldType),
    );
    expect(readFailureHub.records.single.path, 'transform.a');

    expect(
      () => importSchemaV1Document(
        _importDocumentWithTransform({
          'a': 0,
          'b': 0,
          'c': 0,
          'd': 0,
          'tx': 0,
          'ty': 0,
        }),
        _NoopImportSink(),
        diagnostics: materializeFailureHub,
      ),
      throwsA(
        isA<CanvasDataException>()
            .having(
              (error) => error.code,
              'code',
              CanvasDataErrorCode.fieldMustBeInvertible,
            )
            .having((error) => error.path, 'path', 'element.transform'),
      ),
    );
    expect(materializeFailureHub.recordCount, 1);
    expect(
      materializeFailureHub.records.single.code,
      DiagnosticCode.data(CanvasDataErrorCode.fieldMustBeInvertible),
    );
    expect(materializeFailureHub.records.single.path, 'element.transform');
  });

  test('internal decode without enabled diagnostics records nothing', () {
    final disabledHub = DiagnosticsHub(
      policy: const CanvasDiagnosticPolicy.disabled(),
    );

    expect(
      () => decodeSchemaV1Document(_invalidResourceKindDocument()),
      throwsA(isA<CanvasDataException>()),
    );
    expect(
      () => decodeSchemaV1Document(
        _invalidResourceKindDocument(),
        diagnostics: disabledHub,
      ),
      throwsA(isA<CanvasDataException>()),
    );

    expect(disabledHub.recordCount, 0);
  });
}

Map<String, Object?> _invalidResourceKindDocument() {
  return {
    'schemaVersion': 1,
    'resources': [
      {
        'kind': 'video',
        'id': 'resource-1',
        'source': {'kind': 'appKey', 'key': 'resource-1'},
      },
    ],
  };
}

Map<String, Object?> _resourceAppKeyDocument(String key) {
  return {
    'schemaVersion': 1,
    'resources': [
      {
        'kind': 'image',
        'id': 'resource-1',
        'source': {'kind': 'appKey', 'key': key},
      },
    ],
  };
}

Map<String, Object?> _importDocumentWithTransform(
  Map<String, Object?> transformPatch,
) {
  return {
    'schemaVersion': 1,
    'backgroundLayer': {
      'elements': [
        {
          'id': 'rect-a',
          'kind': 'rect',
          'size': {'w': 1, 'h': 1},
          'transform': {
            'a': 1,
            'b': 0,
            'c': 0,
            'd': 1,
            'tx': 0,
            'ty': 0,
            ...transformPatch,
          },
        },
      ],
    },
  };
}

final class _NoopImportSink implements SchemaV1ImportSink {
  @override
  void beginDocument(SchemaV1DocumentImportEvent event) {}

  @override
  void imageResource(SchemaV1ImageResourceImportEvent event) {}

  @override
  void backgroundElement(SchemaV1ElementImportEvent event) {}

  @override
  void layer(SchemaV1LayerImportEvent event) {}

  @override
  void layerElement(CanvasLayerId layerId, SchemaV1ElementImportEvent event) {}

  @override
  void endDocument() {}
}

String _decodedResourceAppKey(CanvasDocument document) {
  final source = document.resources.single.source;
  if (source is CanvasAppKeyResourceSource) {
    return source.key;
  }

  fail('expected CanvasAppKeyResourceSource');
}

String _encodedResourceAppKey(Map<String, Object?> document) {
  final resources = document['resources'] as List<Object?>;
  final resource = resources.single as Map<String, Object?>;
  final source = resource['source'] as Map<String, Object?>;

  return source['key'] as String;
}

CanvasDataException _captureFailure(void Function() run) {
  try {
    run();
  } on CanvasDataException catch (error) {
    return error;
  }
  fail('expected CanvasDataException');
}

void _expectSameFailure(
  CanvasDataException actual,
  CanvasDataException expected,
) {
  expect(actual.code, expected.code);
  expect(actual.message, expected.message);
  expect(actual.path, expected.path);
  expect(actual.details, expected.details);
}

void _expectCodecFailureRecord(
  DiagnosticRecord record, {
  required Object message,
  required Object kind,
}) {
  expect(record.source, DiagnosticSource.codec);
  expect(record.severity, DiagnosticSeverity.error);
  expect(record.code, DiagnosticCode.data(CanvasDataErrorCode.invalidFieldType));
  expect(record.path, 'resource.kind');
  expect(record.details['message'], message);
  final details = record.details['details'] as Map<String, Object?>;
  expect(details['kind'], kind);
}
''';
