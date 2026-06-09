import 'package:test/test.dart';

import '../../support/flutter_consumer_test_harness.dart';

void main() {
  test('schema v1 rejects unknown resource source kinds', () async {
    await expectLater(
      runFlutterConsumerTest(
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
import 'package:iwb_canvas_engine/src/codec/schema_v1_decoder.dart';

void main() {
  test('unknown resource source kind fails before DTO exposure', () {
    final rawKind = 'url-${'x' * 512}';
    final expectedDetail = '${'url-' + ('x' * 252)}<truncated>';

    expect(
      () => decodeSchemaV1Document({
        'schemaVersion': 1,
        'resources': [
          {
            'id': 'image-1',
            'kind': 'image',
            'source': {'kind': rawKind, 'url': 'https://example.invalid/a.png'},
          },
        ],
      }),
      throwsA(
        isA<CanvasDataException>()
            .having((error) => error.code, 'code', CanvasDataErrorCode.invalidFieldType)
            .having((error) => error.message, 'message', isNot(contains(rawKind)))
            .having((error) => error.path, 'path', 'resource.source.kind')
            .having((error) => error.details['kind'], 'kind detail', expectedDetail),
      ),
    );
  });
}
''';
