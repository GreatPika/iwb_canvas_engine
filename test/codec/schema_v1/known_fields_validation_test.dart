import 'package:test/test.dart';

import '../../support/flutter_consumer_test_harness.dart';

void main() {
  test('schema v1 exactness and known fields are validated', () async {
    await expectLater(
      runFlutterConsumerTest(
        packageName: 'iwb_canvas_engine_schema_v1_known_fields',
        testFileName: 'known_fields_validation_test.dart',
        testSource: _knownFieldsValidationSource,
      ),
      completes,
    );
  });
}

const _knownFieldsValidationSource = r'''
import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine/src/codec/schema_v1_decoder.dart';

void main() {
  test('public constants expose only schema v1', () {
    expect(canvasSchemaVersionWrite, 1);
    expect(canvasSchemaVersionsRead, {1});
  });

  test('schemaVersion must be the exact integer v1', () {
    expect(
      decodeSchemaV1Document({'schemaVersion': 1, 'unknownRootField': true}),
      isA<CanvasDocument>(),
    );
    expect(
      () => decodeSchemaV1Document({'schemaVersion': 2}),
      throwsA(isA<CanvasDataException>()),
    );
    expect(
      () => decodeSchemaV1Document({'schemaVersion': 1.0}),
      throwsA(isA<CanvasDataException>()),
    );
    expect(
      () => decodeSchemaV1Document({'schemaVersion': '1'}),
      throwsA(isA<CanvasDataException>()),
    );
  });

  test('known root and nested fields reject invalid shapes', () {
    expect(
      () => decodeSchemaV1Document({'schemaVersion': 1, 'camera': null}),
      throwsA(isA<CanvasDataException>()),
    );
    expect(
      () => decodeSchemaV1Document({
        'schemaVersion': 1,
        'background': {'grid': {'enabled': 'yes'}},
      }),
      throwsA(isA<CanvasDataException>()),
    );
    expect(
      () => decodeSchemaV1Document({
        'schemaVersion': 1,
        'layers': [
          {'id': 'layer-1', 'elements': null},
        ],
      }),
      throwsA(isA<CanvasDataException>()),
    );
  });
}
''';
