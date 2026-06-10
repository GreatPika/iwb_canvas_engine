import 'dart:async';
import 'dart:ui';

import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';

import '../../support/runtime_with_document.dart';
import 'package:iwb_canvas_engine/src/surface/pointer_adapter.dart';

void main() {
  testWidgets('adapter maps finite Flutter pointer phases to public samples', (
    tester,
  ) async {
    await _expectAdapterInputMapping(tester);
    expect(_inputs, hasLength(6));
  });

  testWidgets('CanvasSurface routes through runtime normalization only', (
    tester,
  ) async {
    await _expectSurfaceRuntimeWorldNormalization(tester);
    expect(_paintHosts(), findsOneWidget);
  });

  testWidgets('interactive false and stale callbacks do not route pointers', (
    tester,
  ) async {
    await _expectNoRouteWhenInteractiveFalse(tester);
    await _expectStaleCallbackNoOpsAfterRuntimeSwap(tester);
    await _expectStaleCallbackNoOpsAfterDispose(tester);
    await _expectNonFiniteSurfaceEventHasNoRuntimeEffects(tester);
    await _expectNonFiniteTerminalSurfaceEventCleansRuntime(tester);
    expect(tester.takeException(), isNull);
  });
}

final List<CanvasPointerInput> _inputs = [];

Future<void> _expectAdapterInputMapping(WidgetTester tester) async {
  _inputs.clear();
  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: CanvasSurfacePointerAdapter(
        routeInput: _inputs.add,
        child: const SizedBox(width: 40, height: 40),
      ),
    ),
  );
  final listener = tester.widget<Listener>(find.byType(Listener));

  _routeFiniteEvents(listener);
  _expectMappedSamples();
  _routeNonFiniteEvents(listener);
  _expectMappedTerminalCleanups();
}

void _routeFiniteEvents(Listener listener) {
  _onPointerDown(listener)(
    const PointerDownEvent(
      pointer: 42,
      position: Offset(1, 2),
      kind: PointerDeviceKind.stylus,
      timeStamp: Duration(milliseconds: 7),
    ),
  );
  _onPointerMove(listener)(
    const PointerMoveEvent(
      pointer: 42,
      position: Offset(3, 4),
      kind: PointerDeviceKind.stylus,
      timeStamp: Duration(milliseconds: 8),
    ),
  );
  _onPointerUp(listener)(
    const PointerUpEvent(
      pointer: 42,
      position: Offset(5, 6),
      kind: PointerDeviceKind.stylus,
      timeStamp: Duration(microseconds: -1),
    ),
  );
  _onPointerCancel(listener)(
    const PointerCancelEvent(
      pointer: 42,
      position: Offset(7, 8),
      kind: PointerDeviceKind.stylus,
      timeStamp: Duration(milliseconds: 9),
    ),
  );
}

void _expectMappedSamples() {
  final samples = _inputs.whereType<CanvasPointerSample>().toList();
  expect(samples.map((sample) => sample.phase), [
    CanvasPointerLifecyclePhase.down,
    CanvasPointerLifecyclePhase.move,
    CanvasPointerLifecyclePhase.up,
    CanvasPointerLifecyclePhase.cancel,
  ]);
  expect(samples.map((sample) => sample.pointerId).toSet(), {42});
  expect(samples.map((sample) => sample.kind).toSet(), {
    PointerDeviceKind.stylus,
  });
  expect(samples.map((sample) => sample.position), const [
    Offset(1, 2),
    Offset(3, 4),
    Offset(5, 6),
    Offset(7, 8),
  ]);
  expect(samples.map((sample) => sample.timestampMs), [7, 8, null, 9]);
}

void _routeNonFiniteEvents(Listener listener) {
  _onPointerDown(listener)(
    const PointerDownEvent(
      pointer: 42,
      position: Offset(double.nan, 9),
      kind: PointerDeviceKind.stylus,
      timeStamp: Duration(milliseconds: 10),
    ),
  );
  _onPointerMove(listener)(
    const PointerMoveEvent(
      pointer: 42,
      position: Offset(double.nan, 9),
      kind: PointerDeviceKind.stylus,
      timeStamp: Duration(milliseconds: 10),
    ),
  );
  _onPointerMove(listener)(
    const PointerMoveEvent(
      pointer: 42,
      position: Offset(9, double.infinity),
      kind: PointerDeviceKind.stylus,
      timeStamp: Duration(milliseconds: 11),
    ),
  );
  _onPointerUp(listener)(
    const PointerUpEvent(
      pointer: 42,
      position: Offset(double.nan, 9),
      kind: PointerDeviceKind.stylus,
      timeStamp: Duration(milliseconds: 12),
    ),
  );
  _onPointerCancel(listener)(
    const PointerCancelEvent(
      pointer: 42,
      position: Offset(9, double.infinity),
      kind: PointerDeviceKind.stylus,
      timeStamp: Duration(microseconds: -1),
    ),
  );
}

void _expectMappedTerminalCleanups() {
  final cleanups = _inputs.whereType<CanvasPointerTerminalCleanup>().toList();
  expect(cleanups.map((cleanup) => cleanup.phase), [
    CanvasPointerLifecyclePhase.up,
    CanvasPointerLifecyclePhase.cancel,
  ]);
  expect(cleanups.map((cleanup) => cleanup.pointerId).toSet(), {42});
  expect(cleanups.map((cleanup) => cleanup.kind).toSet(), {
    PointerDeviceKind.stylus,
  });
  expect(cleanups.map((cleanup) => cleanup.timestampMs), [12, null]);
}

Future<void> _expectSurfaceRuntimeWorldNormalization(
  WidgetTester tester,
) async {
  final runtime = runtimeWithDocument(CanvasDocument());
  addTearDown(runtime.dispose);
  runtime.tools.setMode(CanvasInteractionMode.draw);
  runtime.camera.setOffset(const Offset(20, 30));

  await tester.pumpWidget(_SurfaceHost(runtime: runtime, interactive: true));
  final topLeft = tester.getTopLeft(_paintHosts());
  final gesture = await tester.createGesture(kind: PointerDeviceKind.touch);
  await gesture.down(topLeft + const Offset(5, 6));
  await tester.pump();

  final preview = runtime.preview as CanvasPencilStrokePreview;
  expect(preview.points, const [Offset(25, 36)]);
  expect(runtime.state.value.revisions.preview, 1);
}

Future<void> _expectNoRouteWhenInteractiveFalse(WidgetTester tester) async {
  final runtime = runtimeWithDocument(CanvasDocument());
  addTearDown(runtime.dispose);
  runtime.tools.setMode(CanvasInteractionMode.draw);
  await tester.pumpWidget(_SurfaceHost(runtime: runtime, interactive: false));

  expect(find.byType(CanvasSurfacePointerAdapter), findsNothing);
  final before = runtime.state.value;
  await tester.tap(_paintHosts());
  await tester.pump();

  expect(runtime.preview, isA<CanvasNoPreview>());
  expect(runtime.state.value, same(before));
}

Future<void> _expectStaleCallbackNoOpsAfterRuntimeSwap(
  WidgetTester tester,
) async {
  final oldRuntime = runtimeWithDocument(CanvasDocument());
  final newRuntime = runtimeWithDocument(CanvasDocument());
  addTearDown(oldRuntime.dispose);
  addTearDown(newRuntime.dispose);
  oldRuntime.tools.setMode(CanvasInteractionMode.draw);
  newRuntime.tools.setMode(CanvasInteractionMode.draw);

  await tester.pumpWidget(_SurfaceHost(runtime: oldRuntime, interactive: true));
  final staleListener = tester.widget<Listener>(find.byType(Listener));
  _startPencilPreviewThroughTools(oldRuntime, pointerId: 7);
  expect(oldRuntime.preview, isA<CanvasPencilStrokePreview>());
  await tester.pumpWidget(_SurfaceHost(runtime: newRuntime, interactive: true));
  final oldStateBeforeStaleCallback = oldRuntime.state.value;
  final oldPreviewBeforeStaleCallback = oldRuntime.preview;

  _routeNonFinitePointerUp(staleListener, pointerId: 7);
  expect(oldRuntime.state.value, same(oldStateBeforeStaleCallback));
  expect(oldRuntime.preview, same(oldPreviewBeforeStaleCallback));
  expect(newRuntime.preview, isA<CanvasNoPreview>());
}

Future<void> _expectStaleCallbackNoOpsAfterDispose(WidgetTester tester) async {
  final runtime = runtimeWithDocument(CanvasDocument());
  addTearDown(runtime.dispose);
  runtime.tools.setMode(CanvasInteractionMode.draw);

  await tester.pumpWidget(_SurfaceHost(runtime: runtime, interactive: true));
  final staleListener = tester.widget<Listener>(find.byType(Listener));
  await tester.pumpWidget(const SizedBox.shrink());

  _onPointerDown(staleListener)(
    const PointerDownEvent(
      pointer: 8,
      position: Offset(1, 1),
      kind: PointerDeviceKind.touch,
    ),
  );
  expect(runtime.preview, isA<CanvasNoPreview>());
}

Future<void> _expectNonFiniteSurfaceEventHasNoRuntimeEffects(
  WidgetTester tester,
) async {
  final runtime = runtimeWithDocument(CanvasDocument());
  addTearDown(runtime.dispose);
  runtime.tools.setMode(CanvasInteractionMode.draw);
  final observer = _RuntimeSideEffectObserver(runtime);
  addTearDown(observer.dispose);

  await tester.pumpWidget(_SurfaceHost(runtime: runtime, interactive: true));
  final listener = tester.widget<Listener>(find.byType(Listener));
  _routeNonFiniteSurfaceEvents(listener);
  await tester.pump();

  observer.expectNoEffects(runtime);
  expect(_paintHosts(), findsOneWidget);
}

Future<void> _expectNonFiniteTerminalSurfaceEventCleansRuntime(
  WidgetTester tester,
) async {
  await _expectNonFiniteTerminalSurfaceCleanup(
    tester,
    routeTerminal: (listener) {
      _onPointerUp(listener)(
        const PointerUpEvent(
          pointer: 10,
          position: Offset(double.nan, 1),
          kind: PointerDeviceKind.touch,
          timeStamp: Duration(milliseconds: 25),
        ),
      );
    },
  );
  await _expectNonFiniteTerminalSurfaceCleanup(
    tester,
    routeTerminal: (listener) {
      _onPointerCancel(listener)(
        const PointerCancelEvent(
          pointer: 10,
          position: Offset(1, double.infinity),
          kind: PointerDeviceKind.touch,
          timeStamp: Duration(milliseconds: 26),
        ),
      );
    },
  );
}

Future<void> _expectNonFiniteTerminalSurfaceCleanup(
  WidgetTester tester, {
  required void Function(Listener listener) routeTerminal,
}) async {
  final runtime = runtimeWithDocument(CanvasDocument());
  addTearDown(runtime.dispose);
  runtime.tools.setMode(CanvasInteractionMode.draw);
  runtime.tools.setDrawStyle(CanvasDrawStyle.defaultStyle);
  final observer = _RuntimeSideEffectObserver(runtime);
  addTearDown(observer.dispose);

  await tester.pumpWidget(_SurfaceHost(runtime: runtime, interactive: true));
  final listener = tester.widget<Listener>(find.byType(Listener));
  _routeSurfacePencilDown(listener);
  await tester.pump();
  expect(runtime.preview, isA<CanvasPencilStrokePreview>());
  final beforeTerminalState = runtime.state.value;
  final beforeTerminalStateTicks = observer.stateTicks;

  routeTerminal(listener);
  await tester.pump();

  observer.expectNoOutputsAndSameDocument(runtime);
  expect(runtime.preview, isA<CanvasNoPreview>());
  observer.expectPublishedPreviewCleanup(
    runtime,
    previousState: beforeTerminalState,
    previousStateTicks: beforeTerminalStateTicks,
  );
  _expectNextLineFirstTapTimestampZero(runtime, listener);
  observer.expectNoOutputsAndSameDocument(runtime);
}

void _routeSurfacePencilDown(Listener listener) {
  _onPointerDown(listener)(
    const PointerDownEvent(
      pointer: 10,
      position: Offset(4, 5),
      kind: PointerDeviceKind.touch,
    ),
  );
}

void _expectNextLineFirstTapTimestampZero(
  CanvasRuntime runtime,
  Listener listener,
) {
  runtime.tools.setDrawStyle(
    CanvasDrawStyle(tool: CanvasDrawTool.line, lineThickness: 4),
  );
  _routeLineFirstTap(listener);

  final preview = runtime.preview as CanvasPendingLineStartPreview;
  expect(preview.timestampMs, 0);
}

void _routeLineFirstTap(Listener listener) {
  _onPointerDown(listener)(
    const PointerDownEvent(
      pointer: 11,
      position: Offset(2, 3),
      kind: PointerDeviceKind.touch,
    ),
  );
  _onPointerUp(listener)(
    const PointerUpEvent(
      pointer: 11,
      position: Offset(2, 3),
      kind: PointerDeviceKind.touch,
    ),
  );
}

void _startPencilPreviewThroughTools(
  CanvasRuntime runtime, {
  required int pointerId,
}) {
  runtime.tools.handlePointer(
    CanvasPointerSample(
      pointerId: pointerId,
      position: const Offset(1, 1),
      phase: CanvasPointerLifecyclePhase.down,
      kind: PointerDeviceKind.touch,
    ),
  );
}

void _routeNonFinitePointerUp(Listener listener, {required int pointerId}) {
  _onPointerUp(listener)(
    PointerUpEvent(
      pointer: pointerId,
      position: const Offset(double.nan, 1),
      kind: PointerDeviceKind.touch,
    ),
  );
}

void _routeNonFiniteSurfaceEvents(Listener listener) {
  _onPointerDown(listener)(
    const PointerDownEvent(
      pointer: 9,
      position: Offset(double.nan, 1),
      kind: PointerDeviceKind.touch,
    ),
  );
  _onPointerMove(listener)(
    const PointerMoveEvent(
      pointer: 9,
      position: Offset(1, double.infinity),
      kind: PointerDeviceKind.touch,
    ),
  );
}

PointerDownEventListener _onPointerDown(Listener listener) {
  final callback = listener.onPointerDown;
  if (callback != null) {
    return callback;
  }

  throw StateError('CanvasSurfacePointerAdapter has no down listener.');
}

PointerMoveEventListener _onPointerMove(Listener listener) {
  final callback = listener.onPointerMove;
  if (callback != null) {
    return callback;
  }

  throw StateError('CanvasSurfacePointerAdapter has no move listener.');
}

PointerUpEventListener _onPointerUp(Listener listener) {
  final callback = listener.onPointerUp;
  if (callback != null) {
    return callback;
  }

  throw StateError('CanvasSurfacePointerAdapter has no up listener.');
}

PointerCancelEventListener _onPointerCancel(Listener listener) {
  final callback = listener.onPointerCancel;
  if (callback != null) {
    return callback;
  }

  throw StateError('CanvasSurfacePointerAdapter has no cancel listener.');
}

Finder _paintHosts() {
  return find.byKey(const ValueKey<String>('iwb_canvas_surface.paint_host'));
}

final class _SurfaceHost extends StatelessWidget {
  const _SurfaceHost({required this.runtime, required this.interactive});

  final CanvasRuntime runtime;
  final bool interactive;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: SizedBox(
        width: 100,
        height: 100,
        child: CanvasSurface(runtime: runtime, interactive: interactive),
      ),
    );
  }
}

final class _RuntimeSideEffectObserver {
  _RuntimeSideEffectObserver(this._runtime)
    : beforeDocument = _runtime.readDocument(),
      beforeState = _runtime.state.value {
    _subscription = _runtime.actions.listen(actions.add);
    _requestSubscription = _runtime.contextActionRequests.listen(requests.add);
    _runtime.state.addListener(_countStateTick);
  }

  final CanvasRuntime _runtime;
  final CanvasDocument beforeDocument;
  final CanvasRuntimeState beforeState;
  final List<CanvasActionCommitted> actions = [];
  final List<CanvasContextActionRequested> requests = [];
  late final StreamSubscription<CanvasActionCommitted> _subscription;
  late final StreamSubscription<CanvasContextActionRequested>
  _requestSubscription;
  int stateTicks = 0;

  void expectNoEffects(CanvasRuntime runtime) {
    expect(runtime.preview, isA<CanvasNoPreview>());
    expect(runtime.state.value, same(beforeState));
    expect(runtime.readDocument(), same(beforeDocument));
    expect(stateTicks, 0);
    expect(actions, isEmpty);
    expect(requests, isEmpty);
  }

  void expectNoOutputsAndSameDocument(CanvasRuntime runtime) {
    expect(runtime.readDocument(), same(beforeDocument));
    expect(actions, isEmpty);
    expect(requests, isEmpty);
  }

  void expectPublishedPreviewCleanup(
    CanvasRuntime runtime, {
    required CanvasRuntimeState previousState,
    required int previousStateTicks,
  }) {
    expect(
      runtime.state.value.revisions.preview,
      previousState.revisions.preview + 1,
    );
    expect(
      runtime.state.value.revisions.document,
      previousState.revisions.document,
    );
    expect(stateTicks, previousStateTicks + 1);
  }

  Future<void> dispose() async {
    _runtime.state.removeListener(_countStateTick);
    await _subscription.cancel();
    await _requestSubscription.cancel();
  }

  void _countStateTick() {
    stateTicks += 1;
  }
}
