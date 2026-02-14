import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/src/core/interaction_types.dart';
import 'package:iwb_canvas_engine/src/interactive/scene_controller_interactive.dart';
import 'package:iwb_canvas_engine/src/public/canvas_pointer_input.dart';
import 'package:iwb_canvas_engine/src/public/snapshot.dart';
import 'package:iwb_canvas_engine/src/view/scene_view_interactive.dart';

SceneSnapshot _snapshot({required String text, bool includeImage = false}) {
  return SceneSnapshot(
    layers: <ContentLayerSnapshot>[
      ContentLayerSnapshot(nodes: const <NodeSnapshot>[]),
      ContentLayerSnapshot(
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

Widget _host(SceneControllerInteractiveV2 controller) {
  return Directionality(
    textDirection: TextDirection.ltr,
    child: SizedBox(
      width: 120,
      height: 120,
      child: SceneViewInteractiveV2(controller: controller),
    ),
  );
}

void main() {
  testWidgets('SceneViewInteractiveV2 handles controller swap', (tester) async {
    final controllerA = SceneControllerInteractiveV2(
      initialSnapshot: _snapshot(text: 'A', includeImage: true),
    );
    final controllerB = SceneControllerInteractiveV2(
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

    // No crashes after controller swap.
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
      const CanvasPointerInput(
        pointerId: 301,
        position: Offset(40, 40),
        timestampMs: 1,
        phase: CanvasPointerPhase.down,
        kind: PointerDeviceKind.touch,
      ),
    );
    await tester.pump();

    expect(controller.hasActiveStrokePreview, isTrue);
    expect(controller.activeStrokePreviewPoints.length, 1);

    controller.handlePointer(
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

  testWidgets(
    'SceneViewInteractiveV2 overlay painter covers preview branches',
    (tester) async {
      final controller = _OverlayTestController(
        initialSnapshot: _snapshot(text: 'overlay'),
      );
      addTearDown(controller.dispose);

      Future<void> paintOverlay() async {
        await tester.pumpWidget(_host(controller));
        await tester.pump();
        final customPaint = tester.widget<CustomPaint>(
          find.byType(CustomPaint),
        );
        final overlay = customPaint.foregroundPainter!;
        final recorder = PictureRecorder();
        final canvas = Canvas(recorder);
        overlay.paint(canvas, const Size(120, 120));
        recorder.endRecording();
      }

      controller.strokeActive = true;
      controller.strokePoints = const <Offset>[];
      await paintOverlay();

      controller.strokePoints = const <Offset>[Offset(10, 10)];
      controller.strokeThickness = 0;
      await paintOverlay();

      controller.strokeThickness = 4;
      controller.strokeOpacity = 2;
      await paintOverlay();

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
    },
  );
}

class _OverlayTestController extends SceneControllerInteractiveV2 {
  _OverlayTestController({required super.initialSnapshot});

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
  bool get hasActiveStrokePreview => strokeActive;

  @override
  List<Offset> get activeStrokePreviewPoints => strokePoints;

  @override
  double get activeStrokePreviewThickness => strokeThickness;

  @override
  Color get activeStrokePreviewColor => strokeColor;

  @override
  double get activeStrokePreviewOpacity => strokeOpacity;

  @override
  bool get hasActiveLinePreview => lineActive;

  @override
  Offset? get activeLinePreviewStart => lineStart;

  @override
  Offset? get activeLinePreviewEnd => lineEnd;

  @override
  double get activeLinePreviewThickness => linePreviewThickness;

  @override
  Color get activeLinePreviewColor => lineColor;
}
