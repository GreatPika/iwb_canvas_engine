import 'dart:async';
import 'dart:ui';

import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine/src/surface/pointer_adapter.dart';

void main() {
  testWidgets('adapter maps finite Flutter pointer phases to public samples', (
    tester,
  ) async {
    await _expectAdapterSampleMapping(tester);
    expect(_samples, hasLength(4));
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
    expect(tester.takeException(), isNull);
  });
}

final List<CanvasPointerSample> _samples = [];

Future<void> _expectAdapterSampleMapping(WidgetTester tester) async {
  _samples.clear();
  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: CanvasSurfacePointerAdapter(
        routeSample: _samples.add,
        child: const SizedBox(width: 40, height: 40),
      ),
    ),
  );
  final listener = tester.widget<Listener>(find.byType(Listener));

  _routeFiniteEvents(listener);
  _expectMappedSamples();
  _routeNonFiniteEvents(listener);
  expect(_samples, hasLength(4));
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
  expect(_samples.map((sample) => sample.phase), [
    CanvasPointerLifecyclePhase.down,
    CanvasPointerLifecyclePhase.move,
    CanvasPointerLifecyclePhase.up,
    CanvasPointerLifecyclePhase.cancel,
  ]);
  expect(_samples.map((sample) => sample.pointerId).toSet(), {42});
  expect(_samples.map((sample) => sample.kind).toSet(), {
    PointerDeviceKind.stylus,
  });
  expect(_samples.map((sample) => sample.position), const [
    Offset(1, 2),
    Offset(3, 4),
    Offset(5, 6),
    Offset(7, 8),
  ]);
  expect(_samples.map((sample) => sample.timestampMs), [7, 8, null, 9]);
}

void _routeNonFiniteEvents(Listener listener) {
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
}

Future<void> _expectSurfaceRuntimeWorldNormalization(
  WidgetTester tester,
) async {
  final runtime = CanvasRuntime(initialDocument: CanvasDocument());
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
  final runtime = CanvasRuntime(initialDocument: CanvasDocument());
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
  final oldRuntime = CanvasRuntime(initialDocument: CanvasDocument());
  final newRuntime = CanvasRuntime(initialDocument: CanvasDocument());
  addTearDown(oldRuntime.dispose);
  addTearDown(newRuntime.dispose);
  oldRuntime.tools.setMode(CanvasInteractionMode.draw);
  newRuntime.tools.setMode(CanvasInteractionMode.draw);

  await tester.pumpWidget(_SurfaceHost(runtime: oldRuntime, interactive: true));
  final staleListener = tester.widget<Listener>(find.byType(Listener));
  await tester.pumpWidget(_SurfaceHost(runtime: newRuntime, interactive: true));

  _onPointerDown(staleListener)(
    const PointerDownEvent(
      pointer: 7,
      position: Offset(1, 1),
      kind: PointerDeviceKind.touch,
    ),
  );
  expect(oldRuntime.preview, isA<CanvasNoPreview>());
  expect(newRuntime.preview, isA<CanvasNoPreview>());
}

Future<void> _expectStaleCallbackNoOpsAfterDispose(WidgetTester tester) async {
  final runtime = CanvasRuntime(initialDocument: CanvasDocument());
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
  final runtime = CanvasRuntime(initialDocument: CanvasDocument());
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
    _runtime.state.addListener(_countStateTick);
  }

  final CanvasRuntime _runtime;
  final CanvasDocument beforeDocument;
  final CanvasRuntimeState beforeState;
  final List<CanvasActionCommitted> actions = [];
  late final StreamSubscription<CanvasActionCommitted> _subscription;
  int stateTicks = 0;

  void expectNoEffects(CanvasRuntime runtime) {
    expect(runtime.preview, isA<CanvasNoPreview>());
    expect(runtime.state.value, same(beforeState));
    expect(runtime.readDocument(), same(beforeDocument));
    expect(stateTicks, 0);
    expect(actions, isEmpty);
  }

  Future<void> dispose() async {
    _runtime.state.removeListener(_countStateTick);
    await _subscription.cancel();
  }

  void _countStateTick() {
    stateTicks += 1;
  }
}
