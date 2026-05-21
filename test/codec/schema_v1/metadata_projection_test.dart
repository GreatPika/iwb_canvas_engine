import 'package:test/test.dart';

import 'schema_v1_consumer_harness.dart';

void main() {
  test('schema v1 metadata projects through CanvasMetadata only', () async {
    await expectLater(
      runSchemaV1ConsumerTest(
        packageName: 'iwb_canvas_engine_schema_v1_metadata_projection',
        testFileName: 'metadata_projection_test.dart',
        testSource: _metadataProjectionSource,
      ),
      completes,
    );
  });
}

const _metadataProjectionSource = r'''
import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';

void main() {
  test('metadata decodes to CanvasMetadata and encodes as JSON object', () {
    final source = <String, Object?>{
      'schemaVersion': 1,
      'metadata': {
        'owner': 'whiteboard',
        'nested': {
          'labels': ['alpha', 'beta'],
        },
      },
      'unknownNonMetadata': {'discard': true},
    };

    final document = decodeCanvasDocument(source);
    expect(document.metadata, isA<CanvasMetadata>());
    expect(document.metadata['owner'], 'whiteboard');

    final encoded = encodeCanvasDocument(document);
    expect(encoded.containsKey('unknownNonMetadata'), isFalse);
    expect(encoded['metadata'], {
      'owner': 'whiteboard',
      'nested': {
        'labels': ['alpha', 'beta'],
      },
    });

    final metadata = encoded['metadata'] as Map<String, Object?>;
    expect(() => metadata['new'] = true, throwsUnsupportedError);
    final nested = metadata['nested'] as Map<String, Object?>;
    expect(() => nested['labels'] = const [], throwsUnsupportedError);
  });
}
''';
