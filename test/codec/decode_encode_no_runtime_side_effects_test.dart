import 'package:test/test.dart';

import '../support/flutter_consumer_test_harness.dart';

void main() {
  test('public codec operations do not mutate runtime observations', () async {
    await expectLater(
      runFlutterConsumerTest(
        packageName: 'iwb_canvas_engine_codec_no_runtime_side_effects',
        testFileName: 'decode_encode_no_runtime_side_effects_test.dart',
        testSource: _decodeEncodeNoRuntimeSideEffectsSource,
      ),
      completes,
    );
  });
}

const _decodeEncodeNoRuntimeSideEffectsSource = r'''
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';

void main() {
  test('encode leaves runtime document and state unchanged', () {
    final document = CanvasDocument(
      resources: [
        CanvasImageResource(
          id: CanvasResourceId('resource-a'),
          source: CanvasResourceSource.appKey('resource-a'),
        ),
      ],
      layers: [
        CanvasLayer(
          id: CanvasLayerId('layer-a'),
          elements: [
            CanvasImageElement(
              id: CanvasElementId('image-a'),
              resourceId: CanvasResourceId('resource-a'),
              size: const Size(4, 3),
            ),
          ],
        ),
      ],
    );
    final runtime = CanvasRuntime(config: _acceptDeletionRuntimeConfig());
    runtime.edits.loadDocumentFromJson(encodeCanvasDocumentToJson(document));
    final beforeDocument = runtime.readDocument();
    final beforeState = runtime.state.value;

    final encoded = encodeCanvasDocument(document);
    final encodedJson = encodeCanvasDocumentToJson(document);

    expect(encoded, isA<Map<String, Object?>>());
    expect(encodedJson, isA<String>());
    expect(runtime.readDocument(), same(beforeDocument));
    expect(runtime.state.value, beforeState);
    expect(
      runtime.state.value.summary,
      const CanvasRuntimeSummary(
        elementCount: 1,
        layerCount: 1,
        resourceCount: 1,
        selectedCount: 0,
      ),
    );
    expect(runtime.state.value.revisions, beforeState.revisions);
  });
}
''';
