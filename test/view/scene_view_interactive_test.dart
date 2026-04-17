import 'dart:ui';

import 'package:flutter/material.dart' hide Image;
import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/src/contract/internal/snapshot_fast_path.dart';
import 'package:iwb_canvas_engine/src/contract/canvas_pointer_input.dart';
import 'package:iwb_canvas_engine/src/contract/pointer_input.dart';
import 'package:iwb_canvas_engine/src/contract/scene_view_render_state.dart';
import 'package:iwb_canvas_engine/src/contract/scene_view_runtime.dart';
import 'package:iwb_canvas_engine/src/contract/snapshot.dart';
import 'package:iwb_canvas_engine/src/core/interaction_types.dart';
import 'package:iwb_canvas_engine/src/interactive/scene_controller.dart';
import 'package:iwb_canvas_engine/src/interactive/internal/scene_controller_internal_access.dart';
import 'package:iwb_canvas_engine/src/interactive/internal/pointer_session_token.dart';
import 'package:iwb_canvas_engine/src/interactive/internal/scene_controller_pointer_session.dart';
import 'package:iwb_canvas_engine/src/interactive/scene_controller_interaction.dart';
import 'package:iwb_canvas_engine/src/core/scene_snapshot_paint_candidates.dart';
import 'package:iwb_canvas_engine/src/render/scene_painter.dart';
import 'package:iwb_canvas_engine/src/view/scene_view_interactive_overlay_painter.dart';
import 'package:iwb_canvas_engine/src/view/scene_view_interactive.dart';
import 'package:iwb_canvas_engine/src/view/scene_view_runtime_host.dart';

// INV:INV-ENG-VIEW-POINTER-SETTINGS-LIVE-APPLY
// INV:INV-ENG-VIEW-RUNTIME-HOST-DEBUG-PROBES
// INV:INV-ENG-VIEW-POINTER-SESSION-DETACH

SceneSnapshot _snapshot({required String text, bool includeImage = false}) {
  return SceneSnapshot(
    layers: <ContentLayerSnapshot>[
      ContentLayerSnapshot(id: 'layer-auto-0', nodes: <NodeSnapshot>[]),
      ContentLayerSnapshot(
        id: 'layer-auto-1',
        nodes: <NodeSnapshot>[
          TextNodeSnapshot(
            id: 'txt',
            text: text,
            color: const Color(0xFF000000),
            textDirection: TextDirection.ltr,
          ),
          if (includeImage)
            ImageNodeSnapshot(
              id: 'img',
              imageId: 'missing',
              size: Size(20, 20),
            ),
        ],
      ),
    ],
  );
}

TextNodeSnapshot _textNode(SceneController controller) {
  return controller.snapshot.layers
      .expand((layer) => layer.nodes)
      .whereType<TextNodeSnapshot>()
      .single;
}

Widget _host(
  SceneController controller, {
  Image? Function(String imageId)? imageResolver,
}) {
  return Directionality(
    textDirection: TextDirection.ltr,
    child: SizedBox(
      width: 120,
      height: 120,
      child: SceneViewInteractive(
        controller: controller,
        imageResolver: imageResolver,
      ),
    ),
  );
}

Widget _runtimeHost(
  SceneViewRuntime runtime, {
  Image? Function(String imageId)? imageResolver,
}) {
  return Directionality(
    textDirection: TextDirection.ltr,
    child: SizedBox(
      width: 120,
      height: 120,
      child: SceneViewRuntimeHost(
        runtime: runtime,
        imageResolver: imageResolver,
      ),
    ),
  );
}

CustomPaint _sceneViewInteractiveCustomPaint(
  WidgetTester tester, {
  required bool Function(CustomPaint paint) matches,
}) {
  return tester.widget<CustomPaint>(
    find.byWidgetPredicate(
      (widget) => widget is CustomPaint && matches(widget),
    ),
  );
}

int _paintInvocationCount(
  CustomPainter painter,
  Symbol memberName, {
  int width = 120,
  int height = 120,
}) {
  final canvas = TestRecordingCanvas();
  painter.paint(canvas, Size(width.toDouble(), height.toDouble()));
  return canvas.invocations
      .where((invocation) => invocation.invocation.memberName == memberName)
      .length;
}

List<Rect> _paintedRects(
  CustomPainter painter, {
  int width = 120,
  int height = 120,
}) {
  final canvas = TestRecordingCanvas();
  painter.paint(canvas, Size(width.toDouble(), height.toDouble()));
  return canvas.invocations
      .where((entry) => entry.invocation.memberName == #drawRect)
      .map((entry) => entry.invocation.positionalArguments.first as Rect)
      .toList(growable: false);
}

List<Paint> _drawRectPaints(
  CustomPainter painter, {
  int width = 120,
  int height = 120,
}) {
  final canvas = TestRecordingCanvas();
  painter.paint(canvas, Size(width.toDouble(), height.toDouble()));
  return canvas.invocations
      .where((entry) => entry.invocation.memberName == #drawRect)
      .map((entry) => entry.invocation.positionalArguments[1] as Paint)
      .toList(growable: false);
}

List<Paint> _drawLinePaints(
  CustomPainter painter, {
  int width = 120,
  int height = 120,
}) {
  final canvas = TestRecordingCanvas();
  painter.paint(canvas, Size(width.toDouble(), height.toDouble()));
  return canvas.invocations
      .where((entry) => entry.invocation.memberName == #drawLine)
      .map((entry) => entry.invocation.positionalArguments[2] as Paint)
      .toList(growable: false);
}

BuildContext _sceneViewRuntimeHostContext(WidgetTester tester) {
  return tester.element(find.byType(SceneViewRuntimeHost));
}

void _dispatchHostPointerEvent(WidgetTester tester, PointerEvent event) {
  final listener = tester.widget<Listener>(find.byType(Listener));
  switch (event) {
    case PointerDownEvent():
      listener.onPointerDown?.call(event);
    case PointerMoveEvent():
      listener.onPointerMove?.call(event);
    case PointerUpEvent():
      listener.onPointerUp?.call(event);
    case PointerCancelEvent():
      listener.onPointerCancel?.call(event);
    default:
      fail('Unsupported test pointer event: ${event.runtimeType}.');
  }
}

SceneSnapshot _cacheSnapshot({
  required String text,
  required String pathSvg,
  required double strokeY,
}) {
  return SceneSnapshot(
    layers: <ContentLayerSnapshot>[
      ContentLayerSnapshot(
        id: 'layer-auto-0',
        nodes: <NodeSnapshot>[
          TextNodeSnapshot(
            id: 'txt',
            text: text,
            color: const Color(0xFF000000),
            textDirection: TextDirection.ltr,
          ),
          StrokeNodeSnapshot(
            id: 'stroke',
            points: <Offset>[Offset(8, strokeY), Offset(72, strokeY)],
            thickness: 3,
            color: const Color(0xFF000000),
          ),
          PathNodeSnapshot(
            id: 'path',
            svgPathData: pathSvg,
            fillColor: const Color(0x22000000),
            strokeColor: const Color(0xFF000000),
            strokeWidth: 1,
          ),
        ],
      ),
    ],
    background: BackgroundSnapshot(
      grid: GridSnapshot(isEnabled: true, cellSize: 12),
    ),
  );
}

void main() {
  testWidgets('SceneViewInteractive handles controller swap', (tester) async {
    final controllerA = SceneController(
      initialSnapshot: _snapshot(text: 'A', includeImage: true),
    );
    final controllerB = SceneController(
      initialSnapshot: _snapshot(text: 'B', includeImage: true),
    );
    addTearDown(controllerA.dispose);
    addTearDown(controllerB.dispose);

    await tester.pumpWidget(_host(controllerA));
    await tester.pump();

    // Trigger down/up and cancel lifecycle; also schedules and flushes pending tap timer.
    final g1 = await tester.startGesture(const Offset(40, 40), pointer: 1);
    await g1.up();
    await tester.pump(const Duration(milliseconds: 500));

    final g2 = await tester.startGesture(const Offset(44, 44), pointer: 2);
    await g2.cancel();
    await tester.pump();

    await tester.pumpWidget(_host(controllerB));
    await tester.pump();
    controllerB.interaction.setMode(CanvasMode.draw);
    await tester.pump();

    // No crashes after controller swap.
    expect(find.byType(SceneViewInteractive), findsOneWidget);
  });

  testWidgets('SceneViewInteractive handles replaceScene', (tester) async {
    final controller = SceneController(
      initialSnapshot: _snapshot(text: 'epoch'),
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(_host(controller));
    await tester.pump();

    controller.scene.replaceScene(_snapshot(text: 'epoch-2'));
    await tester.pump();
    await tester.pump();

    expect(find.byType(SceneViewInteractive), findsOneWidget);
  });

  testWidgets(
    'SceneViewInteractive active gesture blocks scene.write until terminal release',
    (tester) async {
      // INV:INV-ENG-INTERACTIVE-PUBLIC-MUTATION-EXCLUSIVITY
      final controller = SceneController(
        initialSnapshot: _snapshot(text: 'write-lock'),
        dragStartSlop: 0.001,
      );
      addTearDown(controller.dispose);
      controller.interaction.setMode(CanvasMode.draw);
      controller.interaction.setDrawTool(DrawTool.line);

      await tester.pumpWidget(_host(controller));
      await tester.pump();

      final gesture = await tester.startGesture(
        const Offset(20, 20),
        pointer: 7,
      );
      await tester.pump();

      expect(
        () => controller.scene.write<void>((txn) {
          txn.writeCameraOffset(const Offset(5, 6));
        }),
        throwsStateError,
      );

      await gesture.cancel();
      await tester.pump();

      expect(
        () => controller.scene.write<void>((txn) {
          txn.writeCameraOffset(const Offset(5, 6));
        }),
        returnsNormally,
      );
      expect(controller.snapshot.camera.offset, const Offset(5, 6));
    },
  );

  testWidgets('SceneViewInteractive clears render caches on epoch change', (
    tester,
  ) async {
    // INV:INV-ENG-EPOCH-INVALIDATION
    final controller = SceneController(
      initialSnapshot: _cacheSnapshot(
        text: 'epoch-a',
        pathSvg: 'M0 0 H10 V10 H0 Z',
        strokeY: 20,
      ),
    );
    addTearDown(controller.dispose);
    controller.selection.setSelection(const <String>{'path'});

    await tester.pumpWidget(_host(controller));
    await tester.pump();

    final caches = debugSceneViewInteractiveRenderCachesOf(
      _sceneViewRuntimeHostContext(tester),
    );
    expect(caches.staticLayerCache.debugBuildCount, 1);
    expect(caches.textLayoutCache.debugBuildCount, 1);
    expect(caches.strokePathCache.debugBuildCount, 1);
    expect(caches.pathMetricsCache.debugBuildCount, 1);
    expect(caches.geometryCache.debugBuildCount, 3);

    controller.scene.replaceScene(
      _cacheSnapshot(
        text: 'epoch-a',
        pathSvg: 'M0 0 H10 V10 H0 Z',
        strokeY: 20,
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(caches.staticLayerCache.debugBuildCount, 2);
    expect(caches.textLayoutCache.debugBuildCount, 2);
    expect(caches.strokePathCache.debugBuildCount, 2);
    expect(caches.pathMetricsCache.debugBuildCount, 1);
    expect(caches.pathMetricsCache.debugSize, 0);
    expect(caches.geometryCache.debugBuildCount, 6);
    expect(caches.textLayoutCache.debugHitCount, 0);
    expect(caches.strokePathCache.debugHitCount, 0);
    expect(caches.pathMetricsCache.debugHitCount, 0);
  });

  testWidgets(
    'debugSceneViewInteractiveRenderCachesOf supports runtime owner contexts',
    (tester) async {
      // INV:INV-ENG-VIEW-RUNTIME-HOST-DEBUG-PROBES
      final controller = SceneController(
        initialSnapshot: _cacheSnapshot(
          text: 'runtime-ctx',
          pathSvg: 'M0 0 H10',
          strokeY: 16,
        ),
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(_host(controller));
      await tester.pump();

      final runtimeContext = tester.element(find.byType(SceneViewRuntimeHost));
      final caches = debugSceneViewInteractiveRenderCachesOf(runtimeContext);

      expect(caches.staticLayerCache, isNotNull);
      expect(caches.textLayoutCache, isNotNull);
      expect(caches.strokePathCache, isNotNull);
      expect(caches.pathMetricsCache, isNotNull);
      expect(caches.geometryCache, isNotNull);
    },
  );

  testWidgets(
    'debugSceneViewInteractiveRenderCachesOf supports descendant contexts',
    (tester) async {
      final controller = SceneController(
        initialSnapshot: _cacheSnapshot(
          text: 'ctx',
          pathSvg: 'M0 0 H10',
          strokeY: 12,
        ),
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(_host(controller));
      await tester.pump();

      final descendantContext = tester.element(
        find.byWidgetPredicate(
          (widget) => widget is CustomPaint && widget.painter is ScenePainter,
        ),
      );
      final caches = debugSceneViewInteractiveRenderCachesOf(descendantContext);

      expect(caches.staticLayerCache, isNotNull);
      expect(caches.textLayoutCache, isNotNull);
      expect(caches.strokePathCache, isNotNull);
      expect(caches.pathMetricsCache, isNotNull);
      expect(caches.geometryCache, isNotNull);
    },
  );

  testWidgets(
    'debugSceneViewInteractiveRenderCachesOf throws without SceneViewInteractive',
    (tester) async {
      // INV:INV-ENG-VIEW-RUNTIME-HOST-DEBUG-PROBES
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: SizedBox(width: 40, height: 40),
        ),
      );

      expect(
        () => debugSceneViewInteractiveRenderCachesOf(
          tester.element(find.byType(SizedBox)),
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            'No SceneViewRuntimeHost state found for the provided BuildContext.',
          ),
        ),
      );
    },
  );

  testWidgets(
    'debugSceneViewInteractiveRenderCachesOf rejects public shell contexts',
    (tester) async {
      final controller = SceneController(
        initialSnapshot: _cacheSnapshot(
          text: 'shell-ctx',
          pathSvg: 'M0 0 H10',
          strokeY: 14,
        ),
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(_host(controller));
      await tester.pump();

      expect(
        () => debugSceneViewInteractiveRenderCachesOf(
          tester.element(find.byType(SceneViewInteractive)),
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            'No SceneViewRuntimeHost state found for the provided BuildContext.',
          ),
        ),
      );
    },
  );

  testWidgets('debugRenderCaches throws after render surface unmount', (
    tester,
  ) async {
    final controller = SceneController(
      initialSnapshot: _snapshot(text: 'mounted'),
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(_host(controller));
    await tester.pump();

    final state = tester.state<State<StatefulWidget>>(
      find.byType(SceneViewRuntimeHost),
    );

    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox.shrink(),
      ),
    );
    await tester.pump();

    // The private state getter is intentionally exercised here after unmount.
    // ignore: avoid-dynamic
    expect(() => (state as dynamic).debugRenderCaches, throwsStateError);
  });

  testWidgets('SceneViewInteractive flushes pending tap timer callback', (
    tester,
  ) async {
    // INV:INV-ENG-VIEW-RUNTIME-HOST-DEBUG-PROBES
    final runtime = _RecordingSceneViewRuntime(
      snapshot: _snapshot(text: 'timer'),
      pointerSettings: const PointerInputSettings(doubleTapMaxDelayMs: 1),
    );
    addTearDown(runtime.dispose);

    await tester.pumpWidget(_runtimeHost(runtime));
    await tester.pump();

    final gesture = await tester.startGesture(const Offset(50, 50), pointer: 8);
    await gesture.up();
    await tester.pump();

    expect(
      debugSceneViewInteractivePendingTapFlushTimestampMsOf(
        _sceneViewRuntimeHostContext(tester),
      ),
      isNotNull,
    );
    expect(
      runtime.recordedInputs
          .map((input) => (input.pointerId, input.phase))
          .toList(),
      <(int, CanvasPointerPhase)>[
        (1, CanvasPointerPhase.down),
        (1, CanvasPointerPhase.up),
      ],
    );

    await tester.pump(const Duration(milliseconds: 16));

    expect(
      debugSceneViewInteractivePendingTapFlushTimestampMsOf(
        _sceneViewRuntimeHostContext(tester),
      ),
      isNull,
    );
    expect(
      runtime.recordedInputs
          .map((input) => (input.pointerId, input.phase))
          .toList(),
      <(int, CanvasPointerPhase)>[
        (1, CanvasPointerPhase.down),
        (1, CanvasPointerPhase.up),
      ],
    );
  });

  testWidgets(
    'SceneViewInteractive drops invalid down and move before host side effects',
    (tester) async {
      final runtime = _RecordingSceneViewRuntime(
        snapshot: _snapshot(text: 'invalid-host-admission'),
      );
      addTearDown(runtime.dispose);

      await tester.pumpWidget(_runtimeHost(runtime));
      await tester.pump();

      _dispatchHostPointerEvent(
        tester,
        const PointerDownEvent(
          pointer: 8101,
          position: Offset(double.nan, 12),
          kind: PointerDeviceKind.touch,
        ),
      );
      await tester.pump();

      expect(runtime.recordedInputs, isEmpty);
      expect(
        debugSceneViewInteractiveLiveRawPointerCountOf(
          _sceneViewRuntimeHostContext(tester),
        ),
        0,
      );
      expect(
        debugSceneViewInteractivePendingTapFlushTimestampMsOf(
          _sceneViewRuntimeHostContext(tester),
        ),
        isNull,
      );

      _dispatchHostPointerEvent(
        tester,
        const PointerDownEvent(
          pointer: 8101,
          position: Offset(12, 12),
          kind: PointerDeviceKind.touch,
        ),
      );
      _dispatchHostPointerEvent(
        tester,
        const PointerMoveEvent(
          pointer: 8101,
          position: Offset(double.infinity, 20),
          kind: PointerDeviceKind.touch,
        ),
      );
      await tester.pump();

      expect(
        runtime.recordedInputs
            .map((input) => (input.pointerId, input.phase))
            .toList(),
        <(int, CanvasPointerPhase)>[(1, CanvasPointerPhase.down)],
      );
      expect(
        debugSceneViewInteractiveLiveRawPointerCountOf(
          _sceneViewRuntimeHostContext(tester),
        ),
        1,
      );
      expect(
        debugSceneViewInteractivePendingTapFlushTimestampMsOf(
          _sceneViewRuntimeHostContext(tester),
        ),
        isNull,
      );
    },
  );

  testWidgets(
    'SceneViewInteractive forwards invalid terminal events without rewriting terminal phase',
    (tester) async {
      final runtime = _RecordingSceneViewRuntime(
        snapshot: _snapshot(text: 'invalid-terminal-cleanup'),
      );
      addTearDown(runtime.dispose);

      await tester.pumpWidget(_runtimeHost(runtime));
      await tester.pump();

      _dispatchHostPointerEvent(
        tester,
        const PointerDownEvent(
          pointer: 8201,
          position: Offset(16, 16),
          kind: PointerDeviceKind.touch,
        ),
      );
      _dispatchHostPointerEvent(
        tester,
        const PointerUpEvent(
          pointer: 8201,
          position: Offset(16, double.nan),
          kind: PointerDeviceKind.touch,
        ),
      );
      await tester.pump();

      expect(
        runtime.recordedInputs
            .map((input) => (input.pointerId, input.phase))
            .toList(),
        <(int, CanvasPointerPhase)>[
          (1, CanvasPointerPhase.down),
          (1, CanvasPointerPhase.up),
        ],
      );
      expect(
        debugSceneViewInteractiveLiveRawPointerCountOf(
          _sceneViewRuntimeHostContext(tester),
        ),
        0,
      );

      _dispatchHostPointerEvent(
        tester,
        const PointerDownEvent(
          pointer: 8202,
          position: Offset(20, 20),
          kind: PointerDeviceKind.touch,
        ),
      );
      await tester.pump();

      expect(
        runtime.recordedInputs
            .map((input) => (input.pointerId, input.phase))
            .toList(),
        <(int, CanvasPointerPhase)>[
          (1, CanvasPointerPhase.down),
          (1, CanvasPointerPhase.up),
          (1, CanvasPointerPhase.down),
        ],
      );
    },
  );

  testWidgets(
    'SceneViewInteractive keeps remaining raw pointers alive after invalid terminal cleanup',
    (tester) async {
      final runtime = _RecordingSceneViewRuntime(
        snapshot: _snapshot(text: 'invalid-terminal-non-idle'),
      );
      addTearDown(runtime.dispose);

      await tester.pumpWidget(_runtimeHost(runtime));
      await tester.pump();

      _dispatchHostPointerEvent(
        tester,
        const PointerDownEvent(
          pointer: 8251,
          position: Offset(16, 16),
          kind: PointerDeviceKind.touch,
        ),
      );
      _dispatchHostPointerEvent(
        tester,
        const PointerDownEvent(
          pointer: 8252,
          position: Offset(18, 18),
          kind: PointerDeviceKind.touch,
        ),
      );
      _dispatchHostPointerEvent(
        tester,
        const PointerCancelEvent(
          pointer: 8251,
          position: Offset(double.nan, 16),
          kind: PointerDeviceKind.touch,
        ),
      );
      await tester.pump();

      expect(
        debugSceneViewInteractiveLiveRawPointerCountOf(
          _sceneViewRuntimeHostContext(tester),
        ),
        1,
      );
      expect(
        runtime.recordedInputs
            .map((input) => (input.pointerId, input.phase))
            .toList(),
        <(int, CanvasPointerPhase)>[
          (1, CanvasPointerPhase.down),
          (2, CanvasPointerPhase.down),
          (1, CanvasPointerPhase.cancel),
        ],
      );
    },
  );

  testWidgets(
    'SceneViewInteractive cancels stale pending tap timer on controller swap',
    (tester) async {
      final runtimeA = _RecordingSceneViewRuntime(
        snapshot: _snapshot(text: 'swap-a'),
        pointerSettings: const PointerInputSettings(doubleTapMaxDelayMs: 100),
      );
      final runtimeB = _RecordingSceneViewRuntime(
        snapshot: _snapshot(text: 'swap-b'),
        pointerSettings: const PointerInputSettings(doubleTapMaxDelayMs: 100),
      );
      addTearDown(runtimeA.dispose);
      addTearDown(runtimeB.dispose);

      await tester.pumpWidget(_runtimeHost(runtimeA));
      await tester.pump();

      final gesture = await tester.startGesture(
        const Offset(24, 24),
        pointer: 8301,
      );
      await gesture.up();
      await tester.pump();

      expect(
        debugSceneViewInteractivePendingTapFlushTimestampMsOf(
          _sceneViewRuntimeHostContext(tester),
        ),
        isNotNull,
      );

      await tester.pumpWidget(_runtimeHost(runtimeB));
      await tester.pump();
      expect(
        debugSceneViewInteractivePendingTapFlushTimestampMsOf(
          _sceneViewRuntimeHostContext(tester),
        ),
        isNull,
      );

      await tester.pump(const Duration(milliseconds: 150));
      expect(
        debugSceneViewInteractivePendingTapFlushTimestampMsOf(
          _sceneViewRuntimeHostContext(tester),
        ),
        isNull,
      );
      expect(runtimeB.recordedInputs, isEmpty);
    },
  );

  testWidgets(
    'SceneViewRuntimeHost detaches old session before dispose and router reset',
    (tester) async {
      final runtimeA = _HostLifecycleRecordingRuntime(
        snapshot: _snapshot(text: 'host-a'),
      );
      final runtimeB = _HostLifecycleRecordingRuntime(
        snapshot: _snapshot(text: 'host-b'),
      );
      addTearDown(runtimeA.dispose);
      addTearDown(runtimeB.dispose);

      await tester.pumpWidget(_runtimeHost(runtimeA));
      await tester.pump();

      _dispatchHostPointerEvent(
        tester,
        const PointerDownEvent(
          pointer: 9101,
          position: Offset(20, 20),
          kind: PointerDeviceKind.touch,
        ),
      );

      expect(
        debugSceneViewRuntimeHostLiveRawPointerCountOf(
          _sceneViewRuntimeHostContext(tester),
        ),
        1,
      );

      await tester.pumpWidget(_runtimeHost(runtimeB));
      await tester.pump();

      expect(runtimeA.lifecycleLog, <String>[
        'session-1.detach',
        'session-1.dispose',
      ]);
      expect(
        debugSceneViewRuntimeHostLiveRawPointerCountOf(
          _sceneViewRuntimeHostContext(tester),
        ),
        0,
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();

      expect(runtimeB.lifecycleLog, <String>[
        'session-1.detach',
        'session-1.dispose',
      ]);
    },
  );

  testWidgets(
    'SceneViewRuntimeHost retries failed swaps and compares rebuilds against the installed runtime',
    (tester) async {
      final runtimeA = _HostLifecycleRecordingRuntime(
        snapshot: _snapshot(text: 'host-a'),
      );
      final runtimeB = _FlakyCreatePointerSessionRuntime(
        snapshot: _snapshot(text: 'host-b'),
        failAttemptCount: 1,
      );
      addTearDown(runtimeA.dispose);
      addTearDown(runtimeB.dispose);

      await tester.pumpWidget(_runtimeHost(runtimeA));
      await tester.pump();
      final hostContext = _sceneViewRuntimeHostContext(tester);

      _dispatchHostPointerEvent(
        tester,
        const PointerDownEvent(
          pointer: 9201,
          position: Offset(28, 28),
          kind: PointerDeviceKind.touch,
        ),
      );

      await tester.pumpWidget(_runtimeHost(runtimeB));
      expect(tester.takeException(), isA<StateError>());
      while (tester.takeException() != null) {}
      expect(runtimeA.lifecycleLog, isEmpty);
      expect(
        runtimeA.recordedSamples.map((sample) => sample.phase).toList(),
        <PointerPhase>[PointerPhase.down],
      );
      expect(
        debugSceneViewRuntimeHostActiveRuntimeOf(hostContext),
        same(runtimeA),
      );
      expect(debugSceneViewRuntimeHostLiveRawPointerCountOf(hostContext), 1);
      expect(runtimeB.createPointerSessionAttemptCount, 1);

      await tester.pumpWidget(_runtimeHost(runtimeB));
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(runtimeB.createPointerSessionAttemptCount, 2);
      final installedHostContext = _sceneViewRuntimeHostContext(tester);
      expect(
        debugSceneViewRuntimeHostActiveRuntimeOf(installedHostContext),
        same(runtimeB),
      );
      expect(
        debugSceneViewRuntimeHostLiveRawPointerCountOf(installedHostContext),
        0,
      );

      _dispatchHostPointerEvent(
        tester,
        const PointerDownEvent(
          pointer: 9202,
          position: Offset(18, 22),
          kind: PointerDeviceKind.touch,
        ),
      );

      expect(
        runtimeB.recordedSamples.map((sample) => sample.phase).toList(),
        <PointerPhase>[PointerPhase.down],
      );
    },
  );

  testWidgets('SceneViewInteractive ignores pending tap timer after dispose', (
    tester,
  ) async {
    final controller = SceneController(
      initialSnapshot: _snapshot(text: 'dispose-timer'),
      pointerSettings: const PointerInputSettings(doubleTapMaxDelayMs: 100),
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(_host(controller));
    await tester.pump();

    final gesture = await tester.startGesture(
      const Offset(30, 30),
      pointer: 8401,
    );
    await gesture.up();
    await tester.pump();

    expect(
      debugSceneViewInteractivePendingTapFlushTimestampMsOf(
        _sceneViewRuntimeHostContext(tester),
      ),
      isNotNull,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 150));

    expect(find.byType(SceneViewInteractive), findsNothing);
  });

  testWidgets('SceneViewInteractive applies pointer settings updates live', (
    tester,
  ) async {
    final controller = SceneController(
      initialSnapshot: _snapshot(text: 'double-tap'),
      pointerSettings: const PointerInputSettings(doubleTapMaxDelayMs: 300),
    );
    addTearDown(controller.dispose);
    final editRequests = <Object>[];
    final editSub = controller.editTextRequests.listen(editRequests.add);
    addTearDown(editSub.cancel);

    await tester.pumpWidget(_host(controller));
    await tester.pump();

    Future<void> doubleTapWithGap(Duration gap) async {
      final first = await tester.startGesture(const Offset(8, 8), pointer: 31);
      await first.up();
      await tester.pump(gap);
      final second = await tester.startGesture(const Offset(8, 8), pointer: 31);
      await second.up();
      await tester.pump();
      await tester.pump();
    }

    await doubleTapWithGap(const Duration(milliseconds: 20));
    expect(editRequests.length, 1);

    controller.interaction.setPointerSettings(
      const PointerInputSettings(doubleTapMaxDelayMs: 1),
    );
    await tester.pump();

    await doubleTapWithGap(const Duration(milliseconds: 20));
    expect(editRequests.length, 1);
  });

  testWidgets(
    'SceneViewInteractive defers pointer settings update until active pointer ends',
    (tester) async {
      // INV:INV-ENG-VIEW-POINTER-SETTINGS-LIVE-APPLY
      final controller = SceneController(
        initialSnapshot: _snapshot(text: 'deferred'),
        pointerSettings: const PointerInputSettings(doubleTapMaxDelayMs: 300),
      );
      addTearDown(controller.dispose);
      final editRequests = <Object>[];
      final editSub = controller.editTextRequests.listen(editRequests.add);
      addTearDown(editSub.cancel);

      controller.selection.setSelection(const <String>{'txt'});
      await tester.pumpWidget(_host(controller));
      await tester.pump();

      final gesture = await tester.startGesture(
        const Offset(10, 10),
        pointer: 55,
      );
      await gesture.moveTo(const Offset(24, 10));
      await tester.pump();

      controller.interaction.setPointerSettings(
        const PointerInputSettings(doubleTapMaxDelayMs: 1),
      );
      await tester.pump();

      await gesture.moveTo(const Offset(40, 10));
      await gesture.up();
      await tester.pump();
      await tester.pump();

      expect(_textNode(controller).transform.tx, closeTo(30, 1e-6));

      Future<void> doubleTapWithGap(Duration gap) async {
        final first = await tester.startGesture(
          const Offset(8, 8),
          pointer: 56,
        );
        await first.up();
        await tester.pump(gap);
        final second = await tester.startGesture(
          const Offset(8, 8),
          pointer: 56,
        );
        await second.up();
        await tester.pump();
        await tester.pump();
      }

      await doubleTapWithGap(const Duration(milliseconds: 20));
      expect(editRequests, isEmpty);
    },
  );

  testWidgets(
    'SceneViewInteractive keeps only the last pending pointer settings value',
    (tester) async {
      // INV:INV-ENG-VIEW-POINTER-SETTINGS-LIVE-APPLY
      final controller = SceneController(
        initialSnapshot: _snapshot(text: 'last-write-wins'),
        pointerSettings: const PointerInputSettings(doubleTapMaxDelayMs: 300),
      );
      addTearDown(controller.dispose);
      final editRequests = <Object>[];
      final editSub = controller.editTextRequests.listen(editRequests.add);
      addTearDown(editSub.cancel);

      await tester.pumpWidget(_host(controller));
      await tester.pump();

      final hold = await tester.startGesture(const Offset(10, 10), pointer: 57);
      await tester.pump();

      controller.interaction.setPointerSettings(
        const PointerInputSettings(doubleTapMaxDelayMs: 1),
      );
      controller.interaction.setPointerSettings(
        const PointerInputSettings(doubleTapMaxDelayMs: 300),
      );
      controller.interaction.setPointerSettings(
        const PointerInputSettings(doubleTapMaxDelayMs: 1),
      );
      await tester.pump();

      await hold.up();
      await tester.pump();

      Future<void> doubleTapWithGap(Duration gap) async {
        final first = await tester.startGesture(
          const Offset(8, 8),
          pointer: 58,
        );
        await first.up();
        await tester.pump(gap);
        final second = await tester.startGesture(
          const Offset(8, 8),
          pointer: 58,
        );
        await second.up();
        await tester.pump();
        await tester.pump();
      }

      await doubleTapWithGap(const Duration(milliseconds: 20));
      expect(editRequests, isEmpty);
    },
  );

  testWidgets('SceneViewInteractive reuses freed pointer slot ids', (
    tester,
  ) async {
    // INV:INV-ENG-VIEW-POINTER-SLOT-LIFECYCLE
    final controller = SceneController(
      initialSnapshot: _snapshot(text: 'slots'),
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(_host(controller));
    await tester.pump();

    final g1 = await tester.startGesture(const Offset(20, 20), pointer: 10);
    await g1.up();
    await tester.pump();

    final g2 = await tester.startGesture(const Offset(24, 24), pointer: 11);
    await g2.up();
    await tester.pump();

    // Reuse after up/cancel should not leak slots; this path exercises free-list min reuse.
    final g3 = await tester.startGesture(const Offset(28, 28), pointer: 12);
    await g3.up();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(SceneViewInteractive), findsOneWidget);
  });

  testWidgets('SceneViewInteractive chooses min free slot from unsorted list', (
    tester,
  ) async {
    // INV:INV-ENG-VIEW-POINTER-SLOT-LIFECYCLE
    final controller = SceneController(
      initialSnapshot: _snapshot(text: 'slots-2'),
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(_host(controller));
    await tester.pump();

    final gA = await tester.startGesture(const Offset(10, 10), pointer: 101);
    final gB = await tester.startGesture(const Offset(20, 10), pointer: 102);
    final gC = await tester.startGesture(const Offset(30, 10), pointer: 103);

    await gC.up();
    await tester.pump();
    await gA.up();
    await tester.pump();
    await gB.up();
    await tester.pump();

    // After releases, free list can be non-sorted. Next allocation must pick min.
    final gNext = await tester.startGesture(const Offset(12, 12), pointer: 201);
    await gNext.up();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(SceneViewInteractive), findsOneWidget);
  });

  testWidgets(
    'SceneViewInteractive keeps slot allocator healthy after cancel release',
    (tester) async {
      // INV:INV-ENG-VIEW-POINTER-SLOT-LIFECYCLE
      final controller = SceneController(
        initialSnapshot: _snapshot(text: 'slots-cancel'),
      );
      addTearDown(controller.dispose);
      controller.selection.setSelection(const <String>{'txt'});

      await tester.pumpWidget(_host(controller));
      await tester.pump();

      final gA = await tester.startGesture(const Offset(10, 10), pointer: 401);
      final gB = await tester.startGesture(const Offset(20, 10), pointer: 402);

      await gB.cancel();
      await tester.pump();
      await gA.up();
      await tester.pump();

      final gNext = await tester.startGesture(
        const Offset(10, 10),
        pointer: 403,
      );
      await gNext.moveBy(const Offset(18, 0));
      await gNext.up();
      await tester.pump();

      expect(_textNode(controller).transform.tx, closeTo(18, 1e-6));
    },
  );

  testWidgets(
    'SceneViewInteractive parallel pointer lifecycle does not keep active lock',
    (tester) async {
      // INV:INV-ENG-VIEW-ACTIVE-POINTER-GATE
      final controller = SceneController(
        initialSnapshot: _snapshot(text: 'parallel-lock'),
      );
      addTearDown(controller.dispose);
      controller.selection.setSelection(const <String>{'txt'});

      await tester.pumpWidget(_host(controller));
      await tester.pump();

      final g1 = await tester.startGesture(const Offset(10, 10), pointer: 501);
      final g2 = await tester.startGesture(const Offset(12, 10), pointer: 502);
      await g2.moveBy(const Offset(40, 0));
      await g2.up();
      await tester.pump();

      expect(_textNode(controller).transform.tx, closeTo(0, 1e-6));

      await g1.moveBy(const Offset(20, 0));
      await g1.up();
      await tester.pump();
      expect(_textNode(controller).transform.tx, closeTo(20, 1e-6));

      final g3 = await tester.startGesture(const Offset(30, 10), pointer: 503);
      await g3.moveBy(const Offset(10, 0));
      await g3.up();
      await tester.pump();

      expect(_textNode(controller).transform.tx, closeTo(30, 1e-6));
    },
  );

  testWidgets(
    'SceneViewInteractive drops stray non-down host events before controller routing',
    (tester) async {
      final runtime = _RecordingSceneViewRuntime(
        snapshot: _snapshot(text: 'stray'),
      );
      addTearDown(runtime.dispose);

      await tester.pumpWidget(_runtimeHost(runtime));
      await tester.pump();

      await tester.sendEventToBinding(
        const PointerMoveEvent(
          pointer: 9001,
          position: Offset(20, 20),
          kind: PointerDeviceKind.touch,
        ),
      );
      await tester.sendEventToBinding(
        const PointerUpEvent(
          pointer: 9001,
          position: Offset(20, 20),
          kind: PointerDeviceKind.touch,
        ),
      );
      await tester.pump();

      expect(runtime.recordedInputs, isEmpty);
    },
  );

  testWidgets(
    'SceneViewInteractive delays pointer reset until all raw pointers are released',
    (tester) async {
      // INV:INV-ENG-VIEW-POINTER-SLOT-LIFECYCLE
      // INV:INV-ENG-VIEW-ACTIVE-POINTER-GATE
      final runtime = _RecordingSceneViewRuntime(
        snapshot: _snapshot(text: 'idle-gate'),
        pointerSettings: const PointerInputSettings(doubleTapMaxDelayMs: 300),
      );
      addTearDown(runtime.dispose);

      await tester.pumpWidget(_runtimeHost(runtime));
      await tester.pump();

      final first = await tester.startGesture(
        const Offset(10, 10),
        pointer: 701,
      );
      final second = await tester.startGesture(
        const Offset(12, 10),
        pointer: 702,
      );
      runtime.updatePointerSettings(
        const PointerInputSettings(doubleTapMaxDelayMs: 1),
      );
      await tester.pump();

      await first.up();
      await tester.pump();
      await second.moveBy(const Offset(8, 0));
      await second.up();
      await tester.pump();

      final third = await tester.startGesture(
        const Offset(14, 10),
        pointer: 703,
      );
      await third.up();
      await tester.pump();

      expect(
        runtime.recordedInputs
            .map((input) => (input.pointerId, input.phase))
            .toList(),
        <(int, CanvasPointerPhase)>[
          (1, CanvasPointerPhase.down),
          (2, CanvasPointerPhase.down),
          (1, CanvasPointerPhase.up),
          (2, CanvasPointerPhase.move),
          (2, CanvasPointerPhase.up),
          (1, CanvasPointerPhase.down),
          (1, CanvasPointerPhase.up),
        ],
      );
    },
  );

  testWidgets('SceneViewInteractive paints single-point stroke preview', (
    tester,
  ) async {
    final controller = SceneController(
      initialSnapshot: _snapshot(text: 'preview-dot'),
    );
    addTearDown(controller.dispose);

    controller.interaction.setMode(CanvasMode.draw);
    controller.interaction.setDrawTool(DrawTool.pen);

    await tester.pumpWidget(_host(controller));
    await tester.pump();

    controller.interaction.handlePointer(
      const CanvasPointerInput(
        pointerId: 301,
        position: Offset(40, 40),
        timestampMs: 1,
        phase: CanvasPointerPhase.down,
        kind: PointerDeviceKind.touch,
      ),
    );
    await tester.pump();

    expect(controller.interaction.hasActiveStrokePreview, isTrue);
    expect(controller.interaction.activeStrokePreviewPoints.length, 1);

    controller.interaction.handlePointer(
      const CanvasPointerInput(
        pointerId: 301,
        position: Offset(40, 40),
        timestampMs: 2,
        phase: CanvasPointerPhase.up,
        kind: PointerDeviceKind.touch,
      ),
    );
    await tester.pump();
  });

  testWidgets('SceneViewInteractive paints active line preview', (
    tester,
  ) async {
    final controller = SceneController(
      initialSnapshot: _snapshot(text: 'preview-line'),
    );
    addTearDown(controller.dispose);

    controller.interaction.setMode(CanvasMode.draw);
    controller.interaction.setDrawTool(DrawTool.line);

    await tester.pumpWidget(_host(controller));
    await tester.pump();

    final gesture = await tester.startGesture(
      const Offset(20, 20),
      pointer: 302,
    );
    await gesture.moveBy(const Offset(24, 0));
    await tester.pump();

    expect(controller.interaction.hasActiveLinePreview, isTrue);
    expect(controller.interaction.activeLinePreviewStart, isNotNull);
    expect(controller.interaction.activeLinePreviewEnd, isNotNull);

    await gesture.up();
    await tester.pump();
  });

  testWidgets('SceneViewInteractive routes image ids to imageResolver', (
    tester,
  ) async {
    final controller = SceneController(
      initialSnapshot: _snapshot(text: 'img', includeImage: true),
    );
    addTearDown(controller.dispose);

    final requestedImageIds = <String>[];
    await tester.pumpWidget(
      _host(
        controller,
        imageResolver: (imageId) {
          requestedImageIds.add(imageId);
          return null;
        },
      ),
    );
    await tester.pump();

    expect(requestedImageIds, contains('missing'));
  });

  testWidgets('SceneViewInteractive overlay painter covers preview branches', (
    tester,
  ) async {
    final controller = _OverlayTestController(
      initialSnapshot: _snapshot(text: 'overlay'),
    );
    addTearDown(controller.dispose);

    Future<void> paintOverlay() async {
      await tester.pumpWidget(_host(controller));
      await tester.pump();
      final customPaint = tester.widget<CustomPaint>(
        find.byWidgetPredicate(
          (widget) =>
              widget is CustomPaint &&
              widget.foregroundPainter is SceneViewInteractiveOverlayPainter,
        ),
      );
      final overlay = customPaint.foregroundPainter;
      if (overlay == null) {
        fail('Expected overlay foreground painter.');
      }
      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      overlay.paint(canvas, const Size(120, 120));
      recorder.endRecording();
    }

    controller.strokeActive = true;
    controller.strokePoints = const <Offset>[];
    await paintOverlay();
    expect(controller.strokePoints, isEmpty);

    controller.strokePoints = const <Offset>[Offset(10, 10)];
    controller.strokeThickness = 0;
    await paintOverlay();

    controller.strokeThickness = 4;
    controller.strokeOpacity = 2;
    await paintOverlay();
    expect(controller.strokeOpacity, 2);

    controller.strokePoints = const <Offset>[Offset(10, 10), Offset(20, 20)];
    await paintOverlay();

    controller.lineActive = true;
    controller.lineStart = null;
    controller.lineEnd = null;
    await paintOverlay();

    controller.lineStart = const Offset(5, 5);
    controller.lineEnd = const Offset(25, 25);
    controller.linePreviewThickness = 0;
    await paintOverlay();

    controller.linePreviewThickness = 2;
    await paintOverlay();

    controller.snapshotOverride = materializeSceneSnapshot(
      SceneSnapshotBacking(
        camera: const CameraSnapshotBacking(
          offset: Offset(double.nan, double.infinity),
        ),
        layers: const <ContentLayerSnapshotBacking>[],
      ),
    );
    await paintOverlay();
    controller.snapshotOverride = null;
  });

  testWidgets(
    'SceneViewInteractive marquee painter reads live selectionRect without rebuild inputs',
    (tester) async {
      final controller = SceneController(
        initialSnapshot: SceneSnapshot(
          layers: <ContentLayerSnapshot>[
            ContentLayerSnapshot(id: 'layer-empty'),
          ],
        ),
        dragStartSlop: 0.001,
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(_host(controller));
      await tester.pump();

      final overlayPaint = _sceneViewInteractiveCustomPaint(
        tester,
        matches: (paint) =>
            paint.foregroundPainter is SceneViewInteractiveOverlayPainter,
      );
      final painter = overlayPaint.foregroundPainter;
      if (painter == null) {
        fail('Expected overlay painter.');
      }

      final baselineRectCount = _paintInvocationCount(painter, #drawRect);
      expect(controller.interaction.selectionRect, isNull);

      final gesture = await tester.startGesture(const Offset(12, 12));
      await gesture.moveTo(const Offset(76, 54));
      await tester.pump();

      expect(controller.interaction.selectionRect, isNotNull);

      final marqueeRectCount = _paintInvocationCount(painter, #drawRect);
      expect(marqueeRectCount, greaterThan(baselineRectCount));

      await gesture.up();
      await tester.pump();
    },
  );

  testWidgets(
    'SceneViewInteractive overlay painter normalizes reversed marquee bounds',
    (tester) async {
      final painter = SceneViewInteractiveOverlayPainter(
        renderState: _MutableSceneViewRenderState(
          snapshot: _snapshot(text: 'normalized-marquee'),
          selectionRectOverride: const Rect.fromLTRB(76, 54, 12, 18),
        ),
        selectionColor: const Color(0xFF00AAFF),
        selectionStrokeWidth: 2,
      );

      final rects = _paintedRects(painter);
      expect(rects, hasLength(2));
      expect(rects.first, const Rect.fromLTRB(12, 18, 76, 54));
      expect(rects.last, const Rect.fromLTRB(12, 18, 76, 54));
    },
  );

  testWidgets(
    'SceneViewInteractive overlay painter clamps invalid marquee stroke width',
    (tester) async {
      final painter = SceneViewInteractiveOverlayPainter(
        renderState: _MutableSceneViewRenderState(
          snapshot: _snapshot(text: 'clamped-marquee'),
          selectionRectOverride: const Rect.fromLTRB(12, 18, 76, 54),
        ),
        selectionColor: const Color(0xFF00AAFF),
        selectionStrokeWidth: double.nan,
      );

      final paints = _drawRectPaints(painter);
      expect(paints, hasLength(2));
      expect(paints.last.strokeWidth, 0);
    },
  );

  testWidgets(
    'SceneViewInteractive overlay clears live preview after reset mutations',
    (tester) async {
      final controller = SceneController(
        initialSnapshot: _snapshot(text: 'overlay-reset'),
        dragStartSlop: 0.001,
      );
      addTearDown(controller.dispose);
      controller.interaction.setMode(CanvasMode.draw);
      controller.interaction.setDrawTool(DrawTool.line);

      await tester.pumpWidget(_host(controller));
      await tester.pump();

      final overlayPaint = _sceneViewInteractiveCustomPaint(
        tester,
        matches: (paint) =>
            paint.foregroundPainter is SceneViewInteractiveOverlayPainter,
      );
      final overlay = overlayPaint.foregroundPainter;
      if (overlay == null) {
        fail('Expected overlay foreground painter.');
      }

      int overlayLineCount() {
        return _paintInvocationCount(overlay, #drawLine);
      }

      final gestureA = await tester.startGesture(const Offset(20, 20));
      await gestureA.moveTo(const Offset(72, 64));
      await tester.pump();

      expect(controller.interaction.hasActiveLinePreview, isTrue);
      final beforeCameraReset = overlayLineCount();
      expect(beforeCameraReset, greaterThan(0));

      controller.scene.setCameraOffset(const Offset(8, 6));
      await tester.pump();

      expect(controller.interaction.hasActiveLinePreview, isFalse);
      final afterCameraReset = overlayLineCount();
      expect(afterCameraReset, 0);
      await gestureA.up();
      await tester.pump();

      final gestureB = await tester.startGesture(const Offset(24, 24));
      await gestureB.moveTo(const Offset(80, 60));
      await tester.pump();

      expect(controller.interaction.hasActiveLinePreview, isTrue);
      final beforeReplaceScene = overlayLineCount();
      expect(beforeReplaceScene, greaterThan(0));

      controller.scene.replaceScene(_snapshot(text: 'overlay-reset-next'));
      await tester.pump();

      expect(controller.interaction.hasActiveLinePreview, isFalse);
      final afterReplaceScene = overlayLineCount();
      expect(afterReplaceScene, 0);
      await gestureB.up();
      await tester.pump();
    },
  );

  testWidgets(
    'SceneViewInteractive keeps overlay outside shared render surface',
    (tester) async {
      final controller = SceneController(
        initialSnapshot: _snapshot(text: 'surface-owner'),
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(_host(controller));
      await tester.pump();

      final customPaints = tester.widgetList<CustomPaint>(
        find.byType(CustomPaint),
      );
      expect(customPaints.length, greaterThanOrEqualTo(2));

      final overlayPaint = customPaints.firstWhere(
        (paint) =>
            paint.foregroundPainter is SceneViewInteractiveOverlayPainter,
      );
      expect(
        overlayPaint.foregroundPainter,
        isA<SceneViewInteractiveOverlayPainter>(),
      );

      final caches = debugSceneViewInteractiveRenderCachesOf(
        _sceneViewRuntimeHostContext(tester),
      );
      final innerPaint = customPaints.firstWhere(
        (paint) =>
            paint.painter is ScenePainter &&
            identical(
              (paint.painter as ScenePainter).staticLayerCache,
              caches.staticLayerCache,
            ),
      );
      expect(innerPaint.foregroundPainter, isNull);
    },
  );

  test('SceneController facade forwards runtime-backed render getters', () {
    final controller = _OverlayTestController(
      initialSnapshot: _snapshot(text: 'facade-getters'),
    );
    addTearDown(controller.dispose);

    controller.strokeActive = true;
    controller.strokePoints = const <Offset>[Offset(1, 2), Offset(3, 4)];
    controller.strokeThickness = 6;
    controller.strokeColor = const Color(0xFFAA5500);
    controller.strokeOpacity = 0.4;
    controller.lineActive = true;
    controller.lineStart = const Offset(10, 20);
    controller.lineEnd = const Offset(30, 40);
    controller.linePreviewThickness = 5;
    controller.lineColor = const Color(0xFF0055AA);

    expect(controller.selectionRect, isNull);
    expect(controller.cameraOffset, Offset.zero);
    expect(controller.previewDeltaResolver('node-1'), Offset.zero);
    expect(controller.hasActiveStrokePreview, isTrue);
    expect(controller.activeStrokePreviewPoints, const <Offset>[
      Offset(1, 2),
      Offset(3, 4),
    ]);
    expect(controller.activeStrokePreviewThickness, 6);
    expect(controller.activeStrokePreviewColor, const Color(0xFFAA5500));
    expect(controller.activeStrokePreviewOpacity, 0.4);
    expect(controller.hasActiveLinePreview, isTrue);
    expect(controller.activeLinePreviewStart, const Offset(10, 20));
    expect(controller.activeLinePreviewEnd, const Offset(30, 40));
    expect(controller.activeLinePreviewThickness, 5);
    expect(controller.activeLinePreviewColor, const Color(0xFF0055AA));
  });

  test(
    'SceneController render getters expose captured draw style during active preview',
    () {
      final controller = SceneController(
        initialSnapshot: _snapshot(text: 'captured-preview'),
        dragStartSlop: 0.001,
      );
      addTearDown(controller.dispose);

      controller.interaction.setMode(CanvasMode.draw);
      controller.interaction.setDrawTool(DrawTool.line);
      controller.interaction.lineThickness = 4;
      controller.interaction.setDrawColor(const Color(0xFF3366AA));

      controller.interaction.handlePointer(
        const CanvasPointerInput(
          pointerId: 1,
          position: Offset(10, 10),
          timestampMs: 1,
          phase: CanvasPointerPhase.down,
          kind: PointerDeviceKind.touch,
        ),
      );
      controller.interaction.handlePointer(
        const CanvasPointerInput(
          pointerId: 1,
          position: Offset(30, 10),
          timestampMs: 2,
          phase: CanvasPointerPhase.move,
          kind: PointerDeviceKind.touch,
        ),
      );

      controller.interaction.lineThickness = 9;
      controller.interaction.setDrawColor(const Color(0xFFAA5500));

      expect(controller.hasActiveLinePreview, isTrue);
      expect(controller.activeLinePreviewStart, const Offset(10, 10));
      expect(controller.activeLinePreviewEnd, const Offset(30, 10));
      expect(controller.activeLinePreviewThickness, 4);
      expect(controller.activeLinePreviewColor, const Color(0xFF3366AA));
    },
  );

  testWidgets(
    'SceneViewInteractive overlay painter keeps captured line preview style after config changes',
    (tester) async {
      final controller = SceneController(
        initialSnapshot: _snapshot(text: 'captured-overlay-preview'),
        dragStartSlop: 0.001,
      );
      addTearDown(controller.dispose);

      controller.interaction.setMode(CanvasMode.draw);
      controller.interaction.setDrawTool(DrawTool.line);
      controller.interaction.lineThickness = 4;
      controller.interaction.setDrawColor(const Color(0xFF3366AA));

      await tester.pumpWidget(_host(controller));
      await tester.pump();

      controller.interaction.handlePointer(
        const CanvasPointerInput(
          pointerId: 1,
          position: Offset(10, 10),
          timestampMs: 1,
          phase: CanvasPointerPhase.down,
          kind: PointerDeviceKind.touch,
        ),
      );
      controller.interaction.handlePointer(
        const CanvasPointerInput(
          pointerId: 1,
          position: Offset(30, 10),
          timestampMs: 2,
          phase: CanvasPointerPhase.move,
          kind: PointerDeviceKind.touch,
        ),
      );
      await tester.pump();

      final initialOverlayPaint = _sceneViewInteractiveCustomPaint(
        tester,
        matches: (paint) =>
            paint.foregroundPainter is SceneViewInteractiveOverlayPainter,
      );
      final initialPainter = initialOverlayPaint.foregroundPainter;
      if (initialPainter == null) {
        fail('Expected overlay painter.');
      }

      final initialLinePaints = _drawLinePaints(initialPainter);
      expect(initialLinePaints, hasLength(1));
      expect(initialLinePaints.single.strokeWidth, 4);
      expect(
        initialLinePaints.single.color.toARGB32(),
        const Color(0xFF3366AA).toARGB32(),
      );

      controller.interaction.lineThickness = 9;
      controller.interaction.setDrawColor(const Color(0xFFAA5500));
      await tester.pump();

      final updatedOverlayPaint = _sceneViewInteractiveCustomPaint(
        tester,
        matches: (paint) =>
            paint.foregroundPainter is SceneViewInteractiveOverlayPainter,
      );
      final updatedPainter = updatedOverlayPaint.foregroundPainter;
      if (updatedPainter == null) {
        fail('Expected overlay painter.');
      }

      final updatedLinePaints = _drawLinePaints(updatedPainter);
      expect(updatedLinePaints, hasLength(1));
      expect(updatedLinePaints.single.strokeWidth, 4);
      expect(
        updatedLinePaints.single.color.toARGB32(),
        const Color(0xFF3366AA).toARGB32(),
      );
    },
  );
}

class _OverlayTestController extends SceneController {
  _OverlayTestController({required super.initialSnapshot});

  late final SceneControllerInteraction _interaction = _OverlayTestInteraction(
    sceneControllerInternalInteractionAccessForTest(this),
    this,
  );

  SceneSnapshot? snapshotOverride;

  bool strokeActive = false;
  List<Offset> strokePoints = const <Offset>[];
  double strokeThickness = 2;
  Color strokeColor = const Color(0xFF123456);
  double strokeOpacity = 1;

  bool lineActive = false;
  Offset? lineStart;
  Offset? lineEnd;
  double linePreviewThickness = 1;
  Color lineColor = const Color(0xFF654321);

  @override
  SceneSnapshot get snapshot => snapshotOverride ?? super.snapshot;

  @override
  SceneControllerInteraction get interaction => _interaction;
}

class _OverlayTestInteraction extends SceneControllerInteractionOwner {
  _OverlayTestInteraction(super.access, this.controller);

  final _OverlayTestController controller;

  @override
  bool get hasActiveStrokePreview => controller.strokeActive;

  @override
  List<Offset> get activeStrokePreviewPoints => controller.strokePoints;

  @override
  double get activeStrokePreviewThickness => controller.strokeThickness;

  @override
  Color get activeStrokePreviewColor => controller.strokeColor;

  @override
  double get activeStrokePreviewOpacity => controller.strokeOpacity;

  @override
  bool get hasActiveLinePreview => controller.lineActive;

  @override
  Offset? get activeLinePreviewStart => controller.lineStart;

  @override
  Offset? get activeLinePreviewEnd => controller.lineEnd;

  @override
  double get activeLinePreviewThickness => controller.linePreviewThickness;

  @override
  Color get activeLinePreviewColor => controller.lineColor;
}

class _RecordingSceneViewRuntime implements SceneViewRuntime {
  _RecordingSceneViewRuntime({
    required SceneSnapshot snapshot,
    PointerInputSettings pointerSettings = const PointerInputSettings(),
  }) : _renderState = _StaticSceneViewRenderState(snapshot),
       _pointerSettings = pointerSettings;

  final ChangeNotifier _ownerListenable = ChangeNotifier();
  final _StaticSceneViewRenderState _renderState;
  final List<CanvasPointerInput> recordedInputs = <CanvasPointerInput>[];
  final List<(Offset position, int? timestampMs)> recordedDoubleTaps =
      <(Offset position, int? timestampMs)>[];
  PointerInputSettings _pointerSettings;

  void updatePointerSettings(PointerInputSettings value) {
    _pointerSettings = value;
    _ownerListenable.notifyListeners();
  }

  void dispose() {
    _ownerListenable.dispose();
  }

  @override
  SceneViewRenderState get renderState => _renderState;

  @override
  SceneViewPointerSession createPointerSession({
    required bool Function() isMounted,
    required bool Function() hasLiveRawPointers,
  }) {
    return _RecordingSceneViewPointerSession(
      SceneControllerPointerSession(
        ownerListenable: _ownerListenable,
        token: PointerSessionToken(),
        readPointerSettings: () => _pointerSettings,
        isMounted: isMounted,
        hasLiveRawPointers: hasLiveRawPointers,
        detachPointerSession: (_) {},
        releasePointerSessionToken: (_) {},
        handlePointerFromSession:
            (CanvasPointerInput input, {required PointerSessionToken token}) {
              recordedInputs.add(input);
            },
        handleDoubleTapFromSession:
            ({
              required Offset position,
              int? timestampMs,
              required PointerSessionToken token,
            }) {
              recordedDoubleTaps.add((position, timestampMs));
            },
      ),
    );
  }
}

class _RecordingSceneViewPointerSession implements SceneViewPointerSession {
  _RecordingSceneViewPointerSession(this._delegate);

  final SceneViewPointerSession _delegate;

  @override
  int? get pendingTapFlushTimestampMs => _delegate.pendingTapFlushTimestampMs;

  @override
  void detach() {
    _delegate.detach();
  }

  @override
  void dispose() {
    _delegate.dispose();
  }

  @override
  void handleInvalidTerminalSample({
    required CanvasPointerInput input,
    required int pointerId,
    required int referenceTimestampMs,
  }) {
    _delegate.handleInvalidTerminalSample(
      input: input,
      pointerId: pointerId,
      referenceTimestampMs: referenceTimestampMs,
    );
  }

  @override
  void handleRawPointerRelease({required bool isIdleAfterRelease}) {
    _delegate.handleRawPointerRelease(isIdleAfterRelease: isIdleAfterRelease);
  }

  @override
  void handleRoutedSample(
    PointerSample sample, {
    required bool shouldTrackSignals,
  }) {
    _delegate.handleRoutedSample(
      sample,
      shouldTrackSignals: shouldTrackSignals,
    );
  }
}

class _HostLifecycleRecordingRuntime implements SceneViewRuntime {
  _HostLifecycleRecordingRuntime({required SceneSnapshot snapshot})
    : _renderState = _StaticSceneViewRenderState(snapshot);

  final _StaticSceneViewRenderState _renderState;
  final List<String> lifecycleLog = <String>[];
  final List<PointerSample> recordedSamples = <PointerSample>[];
  int _sessionCounter = 0;

  void dispose() {}

  @override
  SceneViewRenderState get renderState => _renderState;

  @override
  SceneViewPointerSession createPointerSession({
    required bool Function() isMounted,
    required bool Function() hasLiveRawPointers,
  }) {
    _sessionCounter++;
    return _HostLifecycleRecordingSession(
      label: 'session-$_sessionCounter',
      lifecycleLog: lifecycleLog,
      recordedSamples: recordedSamples,
    );
  }
}

class _HostLifecycleRecordingSession implements SceneViewPointerSession {
  _HostLifecycleRecordingSession({
    required this.label,
    required this.lifecycleLog,
    required this.recordedSamples,
  });

  final String label;
  final List<String> lifecycleLog;
  final List<PointerSample> recordedSamples;

  @override
  int? get pendingTapFlushTimestampMs => null;

  @override
  void detach() {
    lifecycleLog.add('$label.detach');
  }

  @override
  void dispose() {
    lifecycleLog.add('$label.dispose');
  }

  @override
  void handleInvalidTerminalSample({
    required CanvasPointerInput input,
    required int pointerId,
    required int referenceTimestampMs,
  }) {}

  @override
  void handleRawPointerRelease({required bool isIdleAfterRelease}) {}

  @override
  void handleRoutedSample(
    PointerSample sample, {
    required bool shouldTrackSignals,
  }) {
    recordedSamples.add(sample);
  }
}

class _FlakyCreatePointerSessionRuntime implements SceneViewRuntime {
  _FlakyCreatePointerSessionRuntime({
    required SceneSnapshot snapshot,
    required this.failAttemptCount,
  }) : _renderState = _StaticSceneViewRenderState(snapshot);

  final _StaticSceneViewRenderState _renderState;
  final List<String> lifecycleLog = <String>[];
  final List<PointerSample> recordedSamples = <PointerSample>[];
  final int failAttemptCount;
  int createPointerSessionAttemptCount = 0;
  int _sessionCounter = 0;

  void dispose() {}

  @override
  SceneViewRenderState get renderState => _renderState;

  @override
  SceneViewPointerSession createPointerSession({
    required bool Function() isMounted,
    required bool Function() hasLiveRawPointers,
  }) {
    createPointerSessionAttemptCount += 1;
    if (createPointerSessionAttemptCount <= failAttemptCount) {
      throw StateError('replacement session creation failed');
    }
    _sessionCounter++;
    return _HostLifecycleRecordingSession(
      label: 'session-$_sessionCounter',
      lifecycleLog: lifecycleLog,
      recordedSamples: recordedSamples,
    );
  }
}

class _StaticSceneViewRenderState extends ChangeNotifier
    implements SceneViewRenderState {
  _StaticSceneViewRenderState(this._snapshot);

  final SceneSnapshot _snapshot;

  @override
  SceneSnapshot get snapshot => _snapshot;

  @override
  Set<NodeId> get selectedNodeIds => const <NodeId>{};

  @override
  int get controllerEpoch => 0;

  @override
  Listenable get overlayRepaintListenable => this;

  @override
  Rect? get selectionRect => null;

  @override
  Offset get cameraOffset => _snapshot.camera.offset;

  @override
  Offset Function(NodeId nodeId) get previewDeltaResolver =>
      (_) => Offset.zero;

  @override
  SceneViewFrameRead captureFrameRead() {
    return SceneViewFrameRead(
      snapshot: _snapshot,
      selectedNodeIds: selectedNodeIds,
      previewDeltaResolver: previewDeltaResolver,
    );
  }

  @override
  Iterable<ScenePaintCandidate> enumeratePaintCandidates(
    SceneViewFrameRead frameRead,
    ScenePaintCandidateQuery query,
  ) {
    return enumerateSnapshotPaintCandidates(
      snapshot: frameRead.snapshot,
      query: query,
      selectedNodeIds: frameRead.selectedNodeIds,
      previewDeltaResolver: frameRead.previewDeltaResolver,
    );
  }

  @override
  bool get hasActiveStrokePreview => false;

  @override
  List<Offset> get activeStrokePreviewPoints => const <Offset>[];

  @override
  double get activeStrokePreviewThickness => 1;

  @override
  Color get activeStrokePreviewColor => const Color(0xFF000000);

  @override
  double get activeStrokePreviewOpacity => 1;

  @override
  bool get hasActiveLinePreview => false;

  @override
  Offset? get activeLinePreviewStart => null;

  @override
  Offset? get activeLinePreviewEnd => null;

  @override
  double get activeLinePreviewThickness => 1;

  @override
  Color get activeLinePreviewColor => const Color(0xFF000000);
}

class _MutableSceneViewRenderState extends _StaticSceneViewRenderState {
  _MutableSceneViewRenderState({
    required SceneSnapshot snapshot,
    this.selectionRectOverride,
  }) : super(snapshot);

  final Rect? selectionRectOverride;

  @override
  Rect? get selectionRect => selectionRectOverride;
}
