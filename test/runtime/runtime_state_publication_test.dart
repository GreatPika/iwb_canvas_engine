import 'package:test/test.dart';

import '../support/flutter_consumer_test_harness.dart';
import '../support/flutter_in_package_test_harness.dart';

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

  test('RuntimeRoot delivers complete guarded common commit delivery', () {
    return expectLater(
      runFlutterInPackageTest(
        'test/runtime/fixtures/common_commit_delivery_fixture.dart',
      ),
      completes,
    );
  });
}

const _runtimeStateSource = '''
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';

CanvasRuntimeConfig _acceptDeletionRuntimeConfig() {
  return CanvasRuntimeConfig(
    deletionCommitResolver: (_) => CanvasDeletionDecision.accept,
  );
}

void main() {
  test('state.value is readable immediately after construction', () {
    final runtime = CanvasRuntime(config: _acceptDeletionRuntimeConfig());

    expect(runtime.state.value, isA<CanvasRuntimeState>());
    expect(runtime.state.value.revisions, _zeroRevisions());
    expect(
      runtime.state.value.summary,
      const CanvasRuntimeSummary(
        elementCount: 0,
        layerCount: 0,
        resourceCount: 0,
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

  test('document edits publish exactly one coherent state snapshot', () {
    final runtime = _runtimeWithDocument(_document());
    final beforeDocumentRevision = runtime.state.value.revisions.document;
    final snapshots = <CanvasRuntimeState>[];
    runtime.state.addListener(() {
      snapshots.add(runtime.state.value);
    });

    runtime.edits.edit((edit) {
      edit.addElement(
        CanvasRectElement(
          id: CanvasElementId('element-2'),
          size: const Size(3, 3),
        ),
        layerId: CanvasLayerId('layer-1'),
      );
    });

    expect(snapshots, hasLength(1));
    expect(snapshots.single.revisions.document, beforeDocumentRevision + 1);
    expect(snapshots.single.summary.elementCount, 3);

    runtime.edits.edit((edit) {});
    expect(snapshots, hasLength(1));
  });

  test('persisted camera edits do not mutate runtime view camera', () {
    final runtime = _runtimeWithDocument(_document());
    final beforeDocumentRevision = runtime.state.value.revisions.document;
    final beforeViewCameraRevision = runtime.state.value.revisions.viewCamera;

    runtime.edits.edit((edit) {
      edit.setCameraOffset(const Offset(10, 20));
    });

    expect(runtime.readDocument().camera.offset, const Offset(10, 20));
    expect(runtime.camera.offset, Offset.zero);
    expect(runtime.state.value.revisions.document, beforeDocumentRevision + 1);
    expect(runtime.state.value.revisions.viewCamera, beforeViewCameraRevision);
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

CanvasDocument _document() {
  return CanvasDocument(
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
}

CanvasRuntime _runtimeWithDocument(CanvasDocument document) {
  final runtime = CanvasRuntime(config: _acceptDeletionRuntimeConfig());
  runtime.edits.loadDocumentFromJson(encodeCanvasDocumentToJson(document));

  return runtime;
}
''';
