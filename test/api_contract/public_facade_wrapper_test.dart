import 'package:test/test.dart';

import '../support/flutter_consumer_test_harness.dart';

void main() {
  test('root barrel reaches wrapper-backed facade declarations', () async {
    await expectLater(
      runFlutterConsumerTest(
        packageName: 'iwb_canvas_engine_facade_wrapper_consumer',
        testFileName: 'facade_wrapper_test.dart',
        testSource: _consumerSource,
      ),
      completes,
    );
  });
}

const _consumerSource = '''
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';

void main() {
  test('json runtime edit load and selection stay root-barrel reachable', () {
    final source = CanvasDocument(
      layers: [
        CanvasLayer(
          id: CanvasLayerId('layer-1'),
          elements: [
            CanvasRectElement(
              id: CanvasElementId('rect-1'),
              size: const Size(10, 20),
            ),
          ],
        ),
      ],
    );
    final runtime = CanvasRuntime(config: _acceptDeletionRuntimeConfig());
    runtime.edits.loadDocumentFromJson(encodeCanvasDocumentToJson(source));

    expect(runtime.state.value.summary.elementCount, 1);
    runtime.selection.setSelection([CanvasElementId('rect-1')]);
    expect(runtime.selection.selectedElementIds, {CanvasElementId('rect-1')});

    runtime.edits.edit((edit) {
      edit.addElement(
        CanvasRectElement(
          id: CanvasElementId('rect-2'),
          size: const Size(5, 5),
        ),
        layerId: CanvasLayerId('layer-1'),
      );
    });
    expect(runtime.state.value.summary.elementCount, 2);

    runtime.edits.loadDocumentFromJson(encodeCanvasDocumentToJson(CanvasDocument()));
    expect(runtime.state.value.summary.elementCount, 0);
    runtime.dispose();
  });
}
''';
