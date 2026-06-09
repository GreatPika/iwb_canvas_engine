// Test bodies are named helpers so DCM metrics stay on each scenario; the
// assertions live in those helpers and DCM does not follow tear-offs.
// ignore_for_file: missing-test-assertion

import 'dart:async';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';

import '../../support/runtime_with_document.dart';

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
}

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
// ignore: halstead-volume
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
// ignore: halstead-volume
Future<void>
_modeChangesClearSelectionByFlagAndDrawPointerPublishesPreview() async {
  final runtime = runtimeWithDocument(
    _document(),
    config: const CanvasRuntimeConfig(clearSelectionOnDrawModeEnter: true),
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
