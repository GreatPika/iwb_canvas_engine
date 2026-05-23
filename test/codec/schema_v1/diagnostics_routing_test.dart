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
import 'package:iwb_canvas_engine/src/diagnostics/diagnostics_hub.dart';

void main() {
  test('public decode functions stay parameter-free and preserve failures', () {
    final CanvasDocument Function(Map<String, Object?>) decodeMap =
        decodeCanvasDocument;
    final CanvasDocument Function(String) decodeJson =
        decodeCanvasDocumentFromJson;
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
      message: 'unknown resource kind: video.',
    );
    _expectCodecFailureRecord(
      verboseHub.records.single,
      message: startsWith('unknown resource kind: v'),
    );
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
}) {
  expect(record.source, DiagnosticSource.codec);
  expect(record.severity, DiagnosticSeverity.error);
  expect(record.code, CanvasDataErrorCode.invalidFieldType);
  expect(record.path, 'resource.kind');
  expect(record.details['message'], message);
}
''';
