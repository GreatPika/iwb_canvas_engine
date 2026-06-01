// Test bodies are named helpers so DCM metrics stay on each scenario; the
// assertions live in those helpers and DCM does not follow tear-offs.
// ignore_for_file: missing-test-assertion

import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';

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
    'mode changes clear selection by flag and draw pointer remains no-op',
    _modeChangesClearSelectionByFlagAndDrawPointerRemainsNoop,
  );

  test(
    'mode flag false and double tap compatibility stay bounded',
    _modeFlagFalseAndDoubleTapCompatibilityStayBounded,
  );
}

void _configuredInitialToolSettingsAreVisibleWithoutRevisionBump() {
  final style = CanvasDrawStyle(
    tool: CanvasDrawTool.marker,
    color: const Color(0xFF112233),
    markerOpacity: 0.5,
  );
  final policy = CanvasPointerPolicy(tapSlop: 3, deferSingleTap: false);
  final runtime = CanvasRuntime(
    initialDocument: _document(),
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
  final runtime = CanvasRuntime(initialDocument: _document());
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

// Selection clearing and draw-mode pointer silence must be observed in the same
// public state to prove the configured mode-change contract.
// ignore: halstead-volume
Future<void> _modeChangesClearSelectionByFlagAndDrawPointerRemainsNoop() async {
  final runtime = CanvasRuntime(
    initialDocument: _document(),
    config: const CanvasRuntimeConfig(clearSelectionOnDrawModeEnter: true),
  );
  final actions = <CanvasActionCommitted>[];
  final subscription = runtime.actions.listen(actions.add);
  addTearDown(() async {
    await subscription.cancel();
    runtime.dispose();
  });
  runtime.selection.setSelection([CanvasElementId('rect-a')]);

  runtime.tools.setMode(CanvasInteractionMode.draw);
  expect(runtime.tools.mode, CanvasInteractionMode.draw);
  expect(runtime.selection.selectedElementIds, isEmpty);
  expect(runtime.state.value.revisions.selection, 2);
  expect(runtime.state.value.revisions.interaction, 1);

  final before = runtime.state.value;
  _sendDrawModePointer(runtime);
  await Future<void>.delayed(Duration.zero);

  expect(runtime.state.value, before);
  expect(actions, isEmpty);
}

Future<void> _modeFlagFalseAndDoubleTapCompatibilityStayBounded() async {
  final runtime = CanvasRuntime(initialDocument: _document());
  final requestStream = runtime.contextActionRequests;
  final firstSubscription = requestStream.listen(
    expectAsync1((_) {}, count: 0),
  );
  final secondSubscription = requestStream.listen(
    expectAsync1((_) {}, count: 0),
  );
  runtime.selection.setSelection([CanvasElementId('rect-a')]);

  runtime.tools.setMode(CanvasInteractionMode.draw);
  expect(runtime.selection.selectedElementIds, {CanvasElementId('rect-a')});
  _expectDoubleTapUnsupported(runtime);

  await firstSubscription.cancel();
  var closed = false;
  secondSubscription.onDone(() {
    closed = true;
  });
  runtime.dispose();
  await Future<void>.delayed(Duration.zero);
  expect(closed, isTrue);
  await secondSubscription.cancel();
}

void _sendDrawModePointer(CanvasRuntime runtime) {
  runtime.tools.handlePointer(
    _pointer(CanvasPointerLifecyclePhase.down, const Offset(1, 1)),
  );
  runtime.tools.handlePointer(
    _pointer(CanvasPointerLifecyclePhase.move, const Offset(4, 4)),
  );
  runtime.tools.handlePointer(
    _pointer(CanvasPointerLifecyclePhase.up, const Offset(4, 4)),
  );
}

void _expectDoubleTapUnsupported(CanvasRuntime runtime) {
  for (final call in [
    () => runtime.tools.handleDoubleTap(position: const Offset(1, 1)),
    () => runtime.tools.handleDoubleTap(
      position: const Offset(double.nan, 1),
      timestampMs: -1,
    ),
  ]) {
    expect(
      call,
      throwsA(
        isA<UnsupportedError>().having(
          (error) => error.message,
          'message',
          contains('P12 context action'),
        ),
      ),
    );
  }
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
