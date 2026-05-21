import 'package:test/test.dart';

import 'schema_v1_consumer_harness.dart';

void main() {
  test('schema v1 image resources use only appKey sources', () async {
    await expectLater(
      runSchemaV1ConsumerTest(
        packageName: 'iwb_canvas_engine_schema_v1_resources_appkey',
        testFileName: 'resources_appkey_only_test.dart',
        testSource: _resourcesAppKeyOnlySource,
      ),
      completes,
    );
  });
}

const _resourcesAppKeyOnlySource = r'''
import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';

void main() {
  test('appKey source is accepted and required for image resources', () {
    final document = decodeCanvasDocument({
      'schemaVersion': 1,
      'resources': [
        {
          'id': 'image-1',
          'kind': 'image',
          'source': {'kind': 'appKey', 'key': 'image-1'},
          'mimeType': 'image/png',
          'contentHash': null,
          'byteLength': null,
          'metadata': {},
        },
      ],
    });

    expect(document.resources, hasLength(1));
    expect(document.resources.single, isA<CanvasImageResource>());
    final image = document.resources.single as CanvasImageResource;
    expect(image.source, isA<CanvasAppKeyResourceSource>());
    expect((image.source as CanvasAppKeyResourceSource).key, 'image-1');

    expect(
      () => decodeCanvasDocument({
        'schemaVersion': 1,
        'resources': [
          {
            'id': 'image-2',
            'kind': 'image',
            'source': {'kind': 'appKey'},
          },
        ],
      }),
      throwsA(isA<CanvasDataException>()),
    );
  });
}
''';
