// The direct owner imports keep the public dispose proof coupled to the exact
// cleanup work seams; hiding them behind a helper would weaken that evidence.
// ignore_for_file: number-of-imports

import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine/src/api/canvas_runtime_frame_bridge.dart';
import 'package:iwb_canvas_engine/src/geometry/geometry_policy.dart';
import 'package:iwb_canvas_engine/src/geometry/hit_test_policy.dart';
import 'package:iwb_canvas_engine/src/geometry/spatial_kernel.dart';
import 'package:iwb_canvas_engine/src/interaction/eraser_machine.dart';
import 'package:iwb_canvas_engine/src/interaction/interaction_engine.dart';
import 'package:iwb_canvas_engine/src/runtime/runtime_interaction_read_adapter.dart';
import 'package:iwb_canvas_engine/src/runtime/runtime_interaction_read_mapping.dart';
import 'package:iwb_canvas_engine/src/store/document_store_kernel.dart';
import '../support/flutter_consumer_test_harness.dart';
import '../support/accept_commit.dart';

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
  // DCM does not follow the named helper, whose assertions intentionally keep
  // the public route and its owner-level lifecycle observations together.
  // ignore: missing-test-assertion
  test(
    'public dispose releases active eraser without displaced corridor work',
    _publicDisposeReleasesActiveEraserWithoutDisplacedCorridorWork,
  );
}

// This is intentionally an in-package companion to the external-consumer
// contract: public disposal owns the lifecycle exit, while the attached root
// is only the established oracle for capture reachability and owner work.
// ignore: halstead-volume, maintainability-index, source-lines-of-code
void _publicDisposeReleasesActiveEraserWithoutDisplacedCorridorWork() {
  final runtime = CanvasRuntime(
    config: const CanvasRuntimeConfig(commitResolver: acceptCommit),
  );
  addTearDown(runtime.dispose);
  runtime.tools.setMode(CanvasInteractionMode.draw);
  runtime.tools.setDrawTool(CanvasDrawTool.eraser);
  runtime.tools.handlePointer(
    _eraserPointer(CanvasPointerLifecyclePhase.down, const Offset(1, 1)),
  );
  runtime.tools.handlePointer(
    _eraserPointer(CanvasPointerLifecyclePhase.move, const Offset(4, 4)),
  );
  final root = canvasRuntimeFrameRootForSurface(runtime);
  if (root == null) {
    fail('CanvasRuntime did not attach its runtime frame root.');
  }
  final retained = root.interactionEngine.activeSession?.eraserCapture;
  if (retained == null) {
    fail('dispose did not begin with an eraser capture.');
  }
  final captureEvents = <PointerEraserCaptureWorkEvent>[];
  final routeEvents = <InteractionEraserRouteWorkEvent>[];
  final readEvents = <RuntimeEraserEntryRouteWorkEvent>[];
  final cleanupEvents = <InteractionCleanupWorkEvent>[];
  final geometryEvents = <GeometryPolicyEraserWorkEvent>[];
  final spatialEvents = <SpatialKernelEraserWorkEvent>[];
  final candidateEvents = <Object>[];
  final exactEvents = <Object>[];
  final projectionEvents = <Object>[];

  observeRuntimeCandidateResolutionWork(
    candidateEvents.add,
    () => HitTestPolicy.observeExactEraserWork(
      exactEvents.add,
      () => DocumentStoreKernel.observeDeletionEntryProjection(
        projectionEvents.add,
        () => GeometryPolicy.observeEraserWork(
          geometryEvents.add,
          () => SpatialKernel.observeEraserWork(
            spatialEvents.add,
            () => InteractionEngine.observeCleanupWork(
              cleanupEvents.add,
              () => PointerEraserCapture.observeWork(
                captureEvents.add,
                () => InteractionEngine.observeEraserRouteWork(
                  routeEvents.add,
                  () =>
                      RuntimeInteractionReadAdapter.observeEraserEntryRouteWork(
                        readEvents.add,
                        runtime.dispose,
                      ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );

  expect(root.interactionEngine.activeSession, isNull);
  expect(retained.points, const [Offset(1, 1), Offset(4, 4)]);
  expect(runtime.preview, isA<CanvasNoPreview>());
  expect(captureEvents, isEmpty);
  expect(routeEvents, isEmpty);
  expect(readEvents, isEmpty);
  expect(geometryEvents, isEmpty);
  expect(spatialEvents, isEmpty);
  expect(candidateEvents, isEmpty);
  expect(exactEvents, isEmpty);
  expect(projectionEvents, isEmpty);
  expect(cleanupEvents, contains(InteractionCleanupWorkEvent.sessionReleased));
  expect(runtime.dispose, returnsNormally);
}

CanvasPointerSample _eraserPointer(
  CanvasPointerLifecyclePhase phase,
  Offset position,
) => CanvasPointerSample(
  pointerId: 1,
  position: position,
  phase: phase,
  kind: PointerDeviceKind.touch,
);

const _disposeLifecycleSource = '''
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';

CanvasRuntimeConfig _acceptDeletionRuntimeConfig() {
  return CanvasRuntimeConfig(
    commitResolver: _acceptCommit,
  );
}

const _commitLease = _CommitLease();

CanvasCommitResolution _acceptCommit(CanvasCommitRequest request) =>
    switch (request) {
      CanvasMoveCommitRequest(:final proposedDelta) => CanvasMoveCommitAccept(
        delta: proposedDelta,
        lease: _commitLease,
      ),
      _ => const CanvasCommitAccept(lease: _commitLease),
    };

final class _CommitLease implements CanvasCommitLease {
  const _CommitLease();
  @override
  void aborted() {}
  @override
  void committed() {}
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
