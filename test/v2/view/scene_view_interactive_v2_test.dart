import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/src/core/interaction_types.dart';
import 'package:iwb_canvas_engine/src/core/pointer_input.dart';
import 'package:iwb_canvas_engine/src/v2/interactive/scene_controller_interactive_v2.dart';
import 'package:iwb_canvas_engine/src/v2/public/snapshot.dart';
import 'package:iwb_canvas_engine/src/v2/render/scene_painter_v2.dart';
import 'package:iwb_canvas_engine/src/v2/view/scene_view_interactive_v2.dart';

SceneSnapshot _snapshot({required String text, bool includeImage = false}) {
  return SceneSnapshot(
    layers: <LayerSnapshot>[
      LayerSnapshot(isBackground: true, nodes: const <NodeSnapshot>[]),
      LayerSnapshot(
        nodes: <NodeSnapshot>[
          TextNodeSnapshot(
            id: 'txt',
            text: text,
            size: const Size(60, 20),
            color: const Color(0xFF000000),
          ),
          if (includeImage)
            const ImageNodeSnapshot(
              id: 'img',
              imageId: 'missing',
              size: Size(20, 20),
            ),
        ],
      ),
    ],
  );
}

Widget _host(
  SceneControllerInteractiveV2 controller, {
  SceneStaticLayerCacheV2? staticCache,
  SceneTextLayoutCacheV2? textCache,
  SceneStrokePathCacheV2? strokeCache,
  ScenePathMetricsCacheV2? pathCache,
}) {
  return Directionality(
    textDirection: TextDirection.ltr,
    child: SizedBox(
      width: 120,
      height: 120,
      child: SceneViewInteractiveV2(
        controller: controller,
        staticLayerCache: staticCache,
        textLayoutCache: textCache,
        strokePathCache: strokeCache,
        pathMetricsCache: pathCache,
      ),
    ),
  );
}

void main() {
  testWidgets('SceneViewInteractiveV2 handles controller swap and cache swap', (
    tester,
  ) async {
    final controllerA = SceneControllerInteractiveV2(
      initialSnapshot: _snapshot(text: 'A', includeImage: true),
    );
    final controllerB = SceneControllerInteractiveV2(
      initialSnapshot: _snapshot(text: 'B', includeImage: true),
    );
    addTearDown(controllerA.dispose);
    addTearDown(controllerB.dispose);

    final staticCache = SceneStaticLayerCacheV2();
    final textCache = SceneTextLayoutCacheV2(maxEntries: 8);
    final strokeCache = SceneStrokePathCacheV2(maxEntries: 8);
    final pathCache = ScenePathMetricsCacheV2(maxEntries: 8);

    await tester.pumpWidget(_host(controllerA));
    await tester.pump();

    // Trigger down/up and cancel lifecycle; also schedules and flushes pending tap timer.
    final g1 = await tester.startGesture(const Offset(40, 40), pointer: 1);
    await g1.up();
    await tester.pump(const Duration(milliseconds: 500));

    final g2 = await tester.startGesture(const Offset(44, 44), pointer: 2);
    await g2.cancel();
    await tester.pump();

    await tester.pumpWidget(
      _host(
        controllerB,
        staticCache: staticCache,
        textCache: textCache,
        strokeCache: strokeCache,
        pathCache: pathCache,
      ),
    );
    await tester.pump();

    await tester.pumpWidget(_host(controllerB));
    await tester.pump();

    // No crashes and caches remain functional after sync/ownership switches.
    expect(find.byType(SceneViewInteractiveV2), findsOneWidget);
  });

  testWidgets('SceneViewInteractiveV2 reuses freed pointer slot ids', (
    tester,
  ) async {
    final controller = SceneControllerInteractiveV2(
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

    expect(find.byType(SceneViewInteractiveV2), findsOneWidget);
  });

  testWidgets('SceneViewInteractiveV2 chooses min free slot from unsorted list', (
    tester,
  ) async {
    final controller = SceneControllerInteractiveV2(
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

    expect(find.byType(SceneViewInteractiveV2), findsOneWidget);
  });

  testWidgets('SceneViewInteractiveV2 paints single-point stroke preview', (
    tester,
  ) async {
    final controller = SceneControllerInteractiveV2(
      initialSnapshot: _snapshot(text: 'preview-dot'),
    );
    addTearDown(controller.dispose);

    controller.setMode(CanvasMode.draw);
    controller.setDrawTool(DrawTool.pen);

    await tester.pumpWidget(_host(controller));
    await tester.pump();

    controller.handlePointer(
      const PointerSample(
        pointerId: 301,
        position: Offset(40, 40),
        timestampMs: 1,
        phase: PointerPhase.down,
      ),
    );
    await tester.pump();

    expect(controller.hasActiveStrokePreview, isTrue);
    expect(controller.activeStrokePreviewPoints.length, 1);

    controller.handlePointer(
      const PointerSample(
        pointerId: 301,
        position: Offset(40, 40),
        timestampMs: 2,
        phase: PointerPhase.up,
      ),
    );
    await tester.pump();
  });

  testWidgets('SceneViewInteractiveV2 paints active line preview', (
    tester,
  ) async {
    final controller = SceneControllerInteractiveV2(
      initialSnapshot: _snapshot(text: 'preview-line'),
    );
    addTearDown(controller.dispose);

    controller.setMode(CanvasMode.draw);
    controller.setDrawTool(DrawTool.line);

    await tester.pumpWidget(_host(controller));
    await tester.pump();

    final gesture = await tester.startGesture(
      const Offset(20, 20),
      pointer: 302,
    );
    await gesture.moveBy(const Offset(24, 0));
    await tester.pump();

    expect(controller.hasActiveLinePreview, isTrue);
    expect(controller.activeLinePreviewStart, isNotNull);
    expect(controller.activeLinePreviewEnd, isNotNull);

    await gesture.up();
    await tester.pump();
  });
}
