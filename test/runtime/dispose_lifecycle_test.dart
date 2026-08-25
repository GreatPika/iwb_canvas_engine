import 'package:test/test.dart';

import '../support/flutter_consumer_test_harness.dart';

void main() {
  test('dispose is idempotent and leaves final state readable', () async {
    await expectLater(
      runFlutterConsumerTest(
        packageName: 'iwb_canvas_engine_dispose_lifecycle_consumer',
        testFileName: 'dispose_lifecycle_test.dart',
        testSource: _disposeLifecycleSource,
      ),
      completes,
    );
  });
}

const _disposeLifecycleSource = '''
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';

CanvasRuntimeConfig _acceptDeletionRuntimeConfig() {
  return CanvasRuntimeConfig(
    deletionCommitResolver: (_) => CanvasDeletionDecision.accept,
  );
}

void main() {
  test('dispose is idempotent and leaves final state readable', () {
    final runtime = _runtimeWithDocument(_document());
    var notifications = 0;
    runtime.state.addListener(() {
      notifications += 1;
    });

    final beforeDispose = runtime.state.value;

    runtime.dispose();
    runtime.dispose();

    expect(runtime.state.value, beforeDispose);
    expect(
      runtime.state.value.revisions.document,
      beforeDispose.revisions.document,
    );
    expect(notifications, 0);
  });
}

CanvasRuntime _runtimeWithDocument(CanvasDocument document) {
  final runtime = CanvasRuntime(config: _acceptDeletionRuntimeConfig());
  runtime.edits.loadDocumentFromJson(encodeCanvasDocumentToJson(document));

  return runtime;
}

CanvasDocument _document() {
  return CanvasDocument(
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
            size: const Size(1, 1),
          ),
        ],
      ),
    ],
  );
}
''';
