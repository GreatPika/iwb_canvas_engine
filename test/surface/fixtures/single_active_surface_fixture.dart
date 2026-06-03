import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';

void main() {
  testWidgets('same runtime admits one active CanvasSurface', (tester) async {
    await _testSameRuntimeActiveGate(tester);
    expect(_paintHosts(), findsOneWidget);
  });

  testWidgets('different runtimes admit independent active surfaces', (
    tester,
  ) async {
    await _testIndependentRuntimeSurfaces(tester);
    expect(_paintHosts(), findsNWidgets(2));
  });
}

Future<void> _testSameRuntimeActiveGate(WidgetTester tester) async {
  final runtime = CanvasRuntime(initialDocument: _document('rect-a'));
  final resolver = _RecordingResolver();
  addTearDown(runtime.dispose);

  await _mountFirstSurface(tester, runtime: runtime, resolver: resolver);

  final notificationCounter = _RuntimeNotificationCounter(runtime);
  addTearDown(notificationCounter.dispose);

  await _expectSecondSurfaceRejected(
    tester,
    runtime: runtime,
    resolver: resolver,
    notificationCounter: notificationCounter,
  );

  await _expectFirstSurfaceStillUsable(tester, runtime, resolver);
  await _expectAttachAfterDetach(tester, runtime, resolver);
}

Future<void> _mountFirstSurface(
  WidgetTester tester, {
  required CanvasRuntime runtime,
  required _RecordingResolver resolver,
}) async {
  await tester.pumpWidget(
    _surfaceHost(
      _sameRuntimeSlots(
        runtime: runtime,
        resolver: resolver,
        secondSlot: const SizedBox.shrink(),
      ),
    ),
  );

  expect(_paintHosts(), findsOneWidget);
  expect(resolver.calls, 0);
}

Future<void> _expectSecondSurfaceRejected(
  WidgetTester tester, {
  required CanvasRuntime runtime,
  required _RecordingResolver resolver,
  required _RuntimeNotificationCounter notificationCounter,
}) async {
  await tester.pumpWidget(
    _surfaceHost(
      _sameRuntimeSlots(
        runtime: runtime,
        resolver: resolver,
        secondSlot: CanvasSurface(
          key: const ValueKey<String>('surface-b'),
          runtime: runtime,
          resourceResolver: resolver,
          interactive: false,
        ),
      ),
    ),
  );

  final error = tester.takeException();
  expect(error, isStateError);
  expect(
    (error as StateError).message,
    'CanvasRuntime already has an active CanvasSurface.',
  );
  expect(_paintHosts(), findsOneWidget);
  expect(resolver.calls, 0);
  expect(notificationCounter.count, 0);
}

Future<void> _expectFirstSurfaceStillUsable(
  WidgetTester tester,
  CanvasRuntime runtime,
  _RecordingResolver resolver,
) async {
  await tester.pumpWidget(
    _surfaceHost(
      _sameRuntimeSlots(
        runtime: runtime,
        resolver: resolver,
        secondSlot: const SizedBox.shrink(),
      ),
    ),
  );
  expect(_paintHosts(), findsOneWidget);

  runtime.edits.edit((edit) {
    edit.addElement(
      CanvasRectElement(id: CanvasElementId('rect-b'), size: const Size(8, 8)),
      layerId: CanvasLayerId('layer-a'),
    );
  });
  await tester.pump();
  expect(_paintHosts(), findsOneWidget);
  expect(runtime.readDocument().layers.single.elements, hasLength(2));
}

Future<void> _expectAttachAfterDetach(
  WidgetTester tester,
  CanvasRuntime runtime,
  _RecordingResolver resolver,
) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpWidget(
    _surfaceHost(
      CanvasSurface(
        key: const ValueKey<String>('surface-c'),
        runtime: runtime,
        resourceResolver: resolver,
        interactive: false,
      ),
    ),
  );
  expect(_paintHosts(), findsOneWidget);
  expect(tester.takeException(), isNull);
  expect(resolver.calls, 0);
}

Future<void> _testIndependentRuntimeSurfaces(WidgetTester tester) async {
  final runtimeA = CanvasRuntime(initialDocument: _document('rect-a'));
  final runtimeB = CanvasRuntime(initialDocument: _document('rect-b'));
  addTearDown(runtimeA.dispose);
  addTearDown(runtimeB.dispose);

  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: Row(
        children: [
          Expanded(
            child: CanvasSurface(
              key: const ValueKey<String>('surface-a'),
              runtime: runtimeA,
              interactive: false,
            ),
          ),
          Expanded(
            child: CanvasSurface(
              key: const ValueKey<String>('surface-b'),
              runtime: runtimeB,
              interactive: false,
            ),
          ),
        ],
      ),
    ),
  );

  expect(_paintHosts(), findsNWidgets(2));
  expect(tester.takeException(), isNull);
}

Widget _sameRuntimeSlots({
  required CanvasRuntime runtime,
  required CanvasResourceResolver resolver,
  required Widget secondSlot,
}) {
  return Column(
    children: [
      Expanded(
        child: CanvasSurface(
          key: const ValueKey<String>('surface-a'),
          runtime: runtime,
          resourceResolver: resolver,
          interactive: false,
        ),
      ),
      Expanded(child: secondSlot),
    ],
  );
}

Finder _paintHosts() {
  return find.byKey(const ValueKey<String>('iwb_canvas_surface.paint_host'));
}

Widget _surfaceHost(Widget child) {
  return Directionality(
    textDirection: TextDirection.ltr,
    child: SizedBox(width: 160, height: 120, child: child),
  );
}

CanvasDocument _document(String elementId) {
  return CanvasDocument(
    layers: [
      CanvasLayer(
        id: CanvasLayerId('layer-a'),
        elements: [
          CanvasRectElement(
            id: CanvasElementId(elementId),
            size: const Size(10, 10),
            fillColor: const Color(0xFF336699),
          ),
        ],
      ),
    ],
  );
}

final class _RecordingResolver implements CanvasResourceResolver {
  int calls = 0;

  @override
  ui.Image? resolveImage(CanvasImageResource resource) {
    calls += 1;

    return null;
  }
}

final class _RuntimeNotificationCounter {
  _RuntimeNotificationCounter(this._runtime) {
    _runtime.state.addListener(_count);
  }

  final CanvasRuntime _runtime;
  int count = 0;

  void dispose() {
    _runtime.state.removeListener(_count);
  }

  void _count() {
    count += 1;
  }
}
