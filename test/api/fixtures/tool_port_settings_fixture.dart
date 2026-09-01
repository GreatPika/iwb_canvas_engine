// Public test scenarios stay named while shared setup and assertions remain in
// cohesive helpers; DCM does not follow tear-offs across those boundaries.
// The lifecycle observer imports are explicit so the public port route keeps
// the actual cleanup owners visible.
// ignore_for_file: missing-test-assertion, number-of-imports

import 'dart:async';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine/src/geometry/geometry_policy.dart';
import 'package:iwb_canvas_engine/src/geometry/hit_test_policy.dart';
import 'package:iwb_canvas_engine/src/geometry/spatial_kernel.dart';
import 'package:iwb_canvas_engine/src/interaction/eraser_machine.dart';
import 'package:iwb_canvas_engine/src/interaction/interaction_engine.dart';
import 'package:iwb_canvas_engine/src/runtime/runtime_interaction_read_adapter.dart';
import 'package:iwb_canvas_engine/src/runtime/runtime_interaction_read_mapping.dart';
import 'package:iwb_canvas_engine/src/store/document_store_kernel.dart';
import '../../support/runtime_with_document.dart';
import '../../support/accept_commit.dart';
import '../../support/runtime_root_with_committed_document_seed.dart';

void main() {
  test(
    'configured initial tool settings are visible without revision bump',
    _configuredInitialToolSettingsAreVisibleWithoutRevisionBump,
  );

  test(
    'setter no-ops are silent and effective changes publish interaction state',
    _setterNoopsAreSilentAndEffectiveChangesPublishInteractionState,
  );

  test(
    'mode changes clear selection by flag and draw pointer publishes preview',
    _modeChangesClearSelectionByFlagAndDrawPointerPublishesPreview,
  );

  test(
    'mode flag false and direct double tap stay bounded',
    _modeFlagFalseAndDirectDoubleTapStayBounded,
  );
  test(
    'tool change releases an active eraser without corridor work',
    _toolChangeReleasesActiveEraserWithoutCorridorWork,
  );
  test(
    'mode change releases an active eraser without corridor work',
    _modeChangeReleasesActiveEraserWithoutCorridorWork,
  );
}

void _toolChangeReleasesActiveEraserWithoutCorridorWork() =>
    _settingsChangeReleasesActiveEraserWithoutCorridorWork(
      (tools) => tools.setDrawTool(CanvasDrawTool.marker),
    );

void _modeChangeReleasesActiveEraserWithoutCorridorWork() =>
    _settingsChangeReleasesActiveEraserWithoutCorridorWork(
      (tools) => tools.setMode(CanvasInteractionMode.move),
    );

// The tool-port routes share the same lifecycle boundary. Keeping their full
// observer stack and oracle together makes drift between equivalent cleanup
// exits visible while each public operation remains a separately named test.
// The setup, owner observers, and final oracle must stay together to prove the
// complete cleanup boundary; splitting them to satisfy metrics would hide that
// invariant behind helpers with no independent meaning.
// ignore: halstead-volume, source-lines-of-code
void _settingsChangeReleasesActiveEraserWithoutCorridorWork(
  void Function(CanvasToolPort tools) changeSetting,
) {
  final runtime = runtimeRootWithCommittedDocumentSeed(_document());
  addTearDown(runtime.dispose);
  runtime.tools.setMode(CanvasInteractionMode.draw);
  runtime.tools.setDrawTool(CanvasDrawTool.eraser);
  runtime.tools.handlePointer(
    _pointer(CanvasPointerLifecyclePhase.down, const Offset(1, 1)),
  );
  runtime.tools.handlePointer(
    _pointer(CanvasPointerLifecyclePhase.move, const Offset(4, 4)),
  );
  final retained = runtime.interactionEngine.activeSession?.eraserCapture;
  if (retained == null) {
    fail('settings cleanup did not begin with an eraser capture');
  }
  final captureEvents = <PointerEraserCaptureWorkEvent>[];
  final routeEvents = <InteractionEraserRouteWorkEvent>[];
  final cleanupEvents = <InteractionCleanupWorkEvent>[];
  final geometryEvents = <GeometryPolicyEraserWorkEvent>[];
  final spatialEvents = <SpatialKernelEraserWorkEvent>[];
  final candidateEvents = <Object>[];
  final exactEvents = <Object>[];
  final projectionEvents = <Object>[];
  final readEvents = <Object>[];

  _observeDownstreamCleanupWork(
    candidateEvents: candidateEvents,
    exactEvents: exactEvents,
    projectionEvents: projectionEvents,
    readEvents: readEvents,
    operation: () => GeometryPolicy.observeEraserWork(
      geometryEvents.add,
      () => SpatialKernel.observeEraserWork(
        spatialEvents.add,
        () => InteractionEngine.observeCleanupWork(
          cleanupEvents.add,
          () => PointerEraserCapture.observeWork(
            captureEvents.add,
            () => InteractionEngine.observeEraserRouteWork(
              routeEvents.add,
              () => changeSetting(runtime.tools),
            ),
          ),
        ),
      ),
    ),
  );

  expect(runtime.interactionEngine.activeSession, isNull);
  expect(retained.points, const [Offset(1, 1), Offset(4, 4)]);
  expect(runtime.preview, isA<CanvasNoPreview>());
  expect(captureEvents, isEmpty);
  expect(routeEvents, isEmpty);
  expect(geometryEvents, isEmpty);
  expect(spatialEvents, isEmpty);
  expect(candidateEvents, isEmpty);
  expect(exactEvents, isEmpty);
  expect(projectionEvents, isEmpty);
  expect(readEvents, isEmpty);
  expect(cleanupEvents, contains(InteractionCleanupWorkEvent.sessionReleased));
}

// Five parameters keep independently owned event streams inside the same
// cleanup phase, which makes displaced work observable without split traces.
// ignore: number-of-parameters
T _observeDownstreamCleanupWork<T>({
  required List<Object> candidateEvents,
  required List<Object> exactEvents,
  required List<Object> projectionEvents,
  required List<Object> readEvents,
  required T Function() operation,
}) => observeRuntimeCandidateResolutionWork(
  candidateEvents.add,
  () => HitTestPolicy.observeExactEraserWork(
    exactEvents.add,
    () => DocumentStoreKernel.observeDeletionEntryProjection(
      projectionEvents.add,
      () => RuntimeInteractionReadAdapter.observeEraserEntryRouteWork(
        readEvents.add,
        operation,
      ),
    ),
  ),
);

void _configuredInitialToolSettingsAreVisibleWithoutRevisionBump() {
  final style = CanvasDrawStyle(
    tool: CanvasDrawTool.marker,
    color: const Color(0xFF112233),
    markerOpacity: 0.5,
  );
  final policy = CanvasPointerPolicy(tapSlop: 3, deferSingleTap: false);
  final runtime = runtimeWithDocument(
    _document(),
    config: CanvasRuntimeConfig(
      commitResolver: acceptCommit,
      initialMode: CanvasInteractionMode.draw,
      initialDrawStyle: style,
      pointerPolicy: policy,
    ),
  );
  addTearDown(runtime.dispose);

  expect(runtime.tools.mode, CanvasInteractionMode.draw);
  expect(runtime.tools.drawStyle, style);
  expect(runtime.tools.pointerPolicy, policy);
  expect(runtime.state.value.revisions.interaction, 0);
}

// The no-op and effective-setter checks share one revision timeline, so keeping
// them together is clearer than splitting the same state progression.
// The explicit required resolver is part of the same public construction
// witness; splitting the setup would obscure the mode-to-preview contract.
// ignore: halstead-volume, source-lines-of-code
void _setterNoopsAreSilentAndEffectiveChangesPublishInteractionState() {
  final runtime = runtimeWithDocument(_document());
  addTearDown(runtime.dispose);
  final notifications = <CanvasRuntimeState>[];
  runtime.state.addListener(() {
    notifications.add(runtime.state.value);
  });

  runtime.tools.setMode(CanvasInteractionMode.move);
  runtime.tools.setDrawStyle(CanvasDrawStyle.defaultStyle);
  runtime.tools.setPointerPolicy(CanvasPointerPolicy.defaultPolicy);
  expect(notifications, isEmpty);
  expect(runtime.state.value.revisions.interaction, 0);

  runtime.tools.setDrawTool(CanvasDrawTool.marker);
  runtime.tools.setDrawColor(const Color(0xFF445566));
  runtime.tools.setPointerPolicy(CanvasPointerPolicy(tapSlop: 4));
  expect(runtime.tools.drawStyle.tool, CanvasDrawTool.marker);
  expect(runtime.tools.drawStyle.color, const Color(0xFF445566));
  expect(runtime.tools.pointerPolicy, CanvasPointerPolicy(tapSlop: 4));
  expect(runtime.state.value.revisions.interaction, 3);
  expect(notifications.map((state) => state.revisions.interaction), [1, 2, 3]);
}

// Selection clearing and draw-mode pointer preview stay in one scenario to
// prove the configured mode-change contract and preview-only draw behavior.
// The explicit required resolver is part of the same public construction
// witness; splitting the setup would obscure the mode-to-preview contract.
// ignore: halstead-volume, source-lines-of-code
Future<void>
_modeChangesClearSelectionByFlagAndDrawPointerPublishesPreview() async {
  final runtime = runtimeWithDocument(
    _document(),
    config: const CanvasRuntimeConfig(
      commitResolver: acceptCommit,
      clearSelectionOnDrawModeEnter: true,
    ),
  );
  final actions = <CanvasActionCommitted>[];
  final subscription = runtime.actions.listen(actions.add);
  addTearDown(() async {
    await subscription.cancel();
    runtime.dispose();
  });
  final beforeSelectionSetRevision = runtime.state.value.revisions.selection;
  runtime.selection.setSelection([CanvasElementId('rect-a')]);
  expect(
    runtime.state.value.revisions.selection,
    beforeSelectionSetRevision + 1,
  );

  final beforeModeChange = runtime.state.value;

  runtime.tools.setMode(CanvasInteractionMode.draw);
  expect(runtime.tools.mode, CanvasInteractionMode.draw);
  expect(runtime.selection.selectedElementIds, isEmpty);
  expect(
    runtime.state.value.revisions.selection,
    beforeModeChange.revisions.selection + 1,
  );
  expect(
    runtime.state.value.revisions.interaction,
    beforeModeChange.revisions.interaction + 1,
  );
  expect(
    runtime.state.value.revisions.document,
    beforeModeChange.revisions.document,
  );

  final before = runtime.state.value;
  _sendDrawModePreviewPointer(runtime);
  await Future<void>.delayed(Duration.zero);

  _expectOnlyPointerPreviewChanged(before, runtime.state.value);
  _expectPencilPreview(runtime.preview);
  expect(actions, isEmpty);
}

void _expectOnlyPointerPreviewChanged(
  CanvasRuntimeState before,
  CanvasRuntimeState after,
) {
  expect(after.revisions.document, before.revisions.document);
  expect(after.revisions.selection, before.revisions.selection);
  expect(after.revisions.resourceVisual, before.revisions.resourceVisual);
  expect(after.revisions.viewCamera, before.revisions.viewCamera);
  expect(after.revisions.epoch, before.revisions.epoch);
  expect(after.revisions.preview, before.revisions.preview + 2);
  expect(after.revisions.interaction, before.revisions.interaction);
  expect(after.summary, before.summary);
}

void _expectPencilPreview(CanvasPreviewState preview) {
  final pencil = preview as CanvasPencilStrokePreview;
  expect(pencil.points, const [Offset(1, 1), Offset(4, 4)]);
  expect(pencil.color, CanvasDrawStyle.defaultStyle.color);
  expect(pencil.thickness, CanvasDrawStyle.defaultStyle.pencilThickness);
  expect(pencil.opacity, 1);
}

Future<void> _modeFlagFalseAndDirectDoubleTapStayBounded() async {
  final runtime = runtimeWithDocument(_document());
  final requests = <CanvasContextActionRequested>[];
  final subscriptions = _listenToContextRequests(runtime, requests);
  runtime.selection.setSelection([CanvasElementId('rect-a')]);

  runtime.tools.setMode(CanvasInteractionMode.draw);
  expect(runtime.selection.selectedElementIds, {CanvasElementId('rect-a')});
  runtime.tools.handleDoubleTap(position: const Offset(1, 1));
  await Future<void>.delayed(Duration.zero);
  expect(requests, hasLength(1));

  await _expectContextRequestStreamCloses(runtime, subscriptions);
}

({
  StreamSubscription<CanvasContextActionRequested> first,
  StreamSubscription<CanvasContextActionRequested> second,
})
_listenToContextRequests(
  CanvasRuntime runtime,
  List<CanvasContextActionRequested> requests,
) {
  final requestStream = runtime.contextActionRequests;

  return (
    first: requestStream.listen(requests.add),
    second: requestStream.listen(expectAsync1(_ignoreContextRequest, count: 1)),
  );
}

int _ignoreContextRequest(CanvasContextActionRequested request) {
  return Object.hash(request, null);
}

Future<void> _expectContextRequestStreamCloses(
  CanvasRuntime runtime,
  ({
    StreamSubscription<CanvasContextActionRequested> first,
    StreamSubscription<CanvasContextActionRequested> second,
  })
  subscriptions,
) async {
  await subscriptions.first.cancel();
  var closed = false;
  subscriptions.second.onDone(() {
    closed = true;
  });
  runtime.dispose();
  await Future<void>.delayed(Duration.zero);
  expect(closed, isTrue);
  await subscriptions.second.cancel();
}

void _sendDrawModePreviewPointer(CanvasRuntime runtime) {
  runtime.tools.handlePointer(
    _pointer(CanvasPointerLifecyclePhase.down, const Offset(1, 1)),
  );
  runtime.tools.handlePointer(
    _pointer(CanvasPointerLifecyclePhase.move, const Offset(4, 4)),
  );
}

CanvasDocument _document() {
  return CanvasDocument(
    layers: [
      CanvasLayer(
        id: CanvasLayerId('layer-a'),
        elements: [
          CanvasRectElement(
            id: CanvasElementId('rect-a'),
            size: const Size(2, 2),
          ),
        ],
      ),
    ],
  );
}

CanvasPointerSample _pointer(
  CanvasPointerLifecyclePhase phase,
  Offset position,
) {
  return CanvasPointerSample(
    pointerId: 1,
    position: position,
    phase: phase,
    kind: PointerDeviceKind.touch,
  );
}
