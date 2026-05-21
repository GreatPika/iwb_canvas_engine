import 'package:test/test.dart';

import '../support/flutter_consumer_test_harness.dart';

void main() {
  test('CanvasRuntime publishes initial public state', () async {
    await expectLater(
      runFlutterConsumerTest(
        packageName: 'iwb_canvas_engine_runtime_state_consumer',
        testFileName: 'runtime_state_test.dart',
        testSource: _runtimeStateSource,
      ),
      completes,
    );
  });
}

const _runtimeStateSource = '''
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';

void main() {
  test('state.value is readable immediately after construction', () {
    final document = CanvasDocument(
      resources: [
        CanvasImageResource(
          id: CanvasResourceId('resource-1'),
          source: CanvasResourceSource.appKey('resource-1'),
        ),
      ],
      backgroundElements: [
        CanvasRectElement(
          id: CanvasElementId('background-1'),
          size: const Size(1, 1),
        ),
      ],
      layers: [
        CanvasLayer(
          id: CanvasLayerId('layer-1'),
          elements: [
            CanvasRectElement(
              id: CanvasElementId('element-1'),
              size: const Size(2, 2),
            ),
          ],
        ),
      ],
    );
    final runtime = CanvasRuntime(initialDocument: document);

    expect(runtime.state.value, isA<CanvasRuntimeState>());
    expect(runtime.state.value.revisions, _zeroRevisions());
    expect(
      runtime.state.value.summary,
      const CanvasRuntimeSummary(
        elementCount: 2,
        layerCount: 1,
        resourceCount: 1,
        selectedCount: 0,
      ),
    );
  });

  test('snapshot DTOs compare by public values', () {
    expect(_zeroRevisions(), _zeroRevisions());
    expect(
      const CanvasRuntimeSummary(
        elementCount: 1,
        layerCount: 2,
        resourceCount: 3,
        selectedCount: 4,
      ),
      const CanvasRuntimeSummary(
        elementCount: 1,
        layerCount: 2,
        resourceCount: 3,
        selectedCount: 4,
      ),
    );
    expect(
      CanvasRuntimeState(
        revisions: _zeroRevisions(),
        summary: const CanvasRuntimeSummary(
          elementCount: 1,
          layerCount: 2,
          resourceCount: 3,
          selectedCount: 4,
        ),
      ),
      CanvasRuntimeState(
        revisions: _zeroRevisions(),
        summary: const CanvasRuntimeSummary(
          elementCount: 1,
          layerCount: 2,
          resourceCount: 3,
          selectedCount: 4,
        ),
      ),
    );
  });
}

CanvasRuntimeRevisions _zeroRevisions() {
  return const CanvasRuntimeRevisions(
    document: 0,
    selection: 0,
    preview: 0,
    viewCamera: 0,
    resourceVisual: 0,
    interaction: 0,
    epoch: 0,
  );
}
''';
