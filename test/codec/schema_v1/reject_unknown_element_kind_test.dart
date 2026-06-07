import 'package:test/test.dart';

import '../../support/flutter_consumer_test_harness.dart';

void main() {
  test('schema v1 rejects unknown element kinds', () async {
    await expectLater(
      runFlutterConsumerTest(
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
import 'package:iwb_canvas_engine/src/codec/schema_v1_decoder.dart';

void main() {
  test('unknown element kind fails before DTO exposure', () {
    expect(
      () => decodeSchemaV1Document({
        'schemaVersion': 1,
        'backgroundLayer': {
          'elements': [
            {
              'id': 'video-1',
              'kind': 'video',
            },
          ],
        },
      }),
      throwsA(
        isA<CanvasDataException>()
            .having((error) => error.code, 'code', CanvasDataErrorCode.invalidFieldType)
            .having((error) => error.path, 'path', 'element.kind'),
      ),
    );
  });

  test('legacy root backgroundElements is ignored as an unknown field', () {
    final document = decodeSchemaV1Document({
      'schemaVersion': 1,
      'backgroundElements': [
        {
          'id': 'rect-legacy',
          'kind': 'rect',
          'size': {'w': 1, 'h': 1},
        },
      ],
      'backgroundLayer': {'elements': []},
    });

    expect(document.backgroundElements, isEmpty);
  });
}
''';
