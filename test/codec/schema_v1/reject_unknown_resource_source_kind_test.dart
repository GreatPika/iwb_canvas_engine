import 'package:test/test.dart';

import 'schema_v1_consumer_harness.dart';

void main() {
  test('schema v1 rejects unknown resource source kinds', () async {
    await expectLater(
      runSchemaV1ConsumerTest(
        packageName: 'iwb_canvas_engine_schema_v1_resource_source',
        testFileName: 'reject_unknown_resource_source_kind_test.dart',
        testSource: _rejectUnknownResourceSourceKindSource,
      ),
      completes,
    );
  });
}

const _rejectUnknownResourceSourceKindSource = r'''
import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';

void main() {
  test('unknown resource source kind fails before DTO exposure', () {
    expect(
      () => decodeCanvasDocument({
        'schemaVersion': 1,
        'resources': [
          {
            'id': 'image-1',
            'kind': 'image',
            'source': {'kind': 'url', 'url': 'https://example.invalid/a.png'},
          },
        ],
      }),
      throwsA(
        isA<CanvasDataException>()
            .having((error) => error.code, 'code', CanvasDataErrorCode.invalidFieldType)
            .having((error) => error.path, 'path', 'resource.source.kind'),
      ),
    );
  });
}
''';
