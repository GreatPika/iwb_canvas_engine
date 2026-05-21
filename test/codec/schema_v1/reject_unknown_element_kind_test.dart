import 'package:test/test.dart';

import 'schema_v1_consumer_harness.dart';

void main() {
  test('schema v1 rejects unknown element kinds', () async {
    await expectLater(
      runSchemaV1ConsumerTest(
        packageName: 'iwb_canvas_engine_schema_v1_element_kind',
        testFileName: 'reject_unknown_element_kind_test.dart',
        testSource: _rejectUnknownElementKindSource,
      ),
      completes,
    );
  });
}

const _rejectUnknownElementKindSource = r'''
import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';

void main() {
  test('unknown element kind fails before DTO exposure', () {
    expect(
      () => decodeCanvasDocument({
        'schemaVersion': 1,
        'backgroundElements': [
          {
            'id': 'video-1',
            'kind': 'video',
          },
        ],
      }),
      throwsA(
        isA<CanvasDataException>()
            .having((error) => error.code, 'code', CanvasDataErrorCode.invalidFieldType)
            .having((error) => error.path, 'path', 'element.kind'),
      ),
    );
  });
}
''';
