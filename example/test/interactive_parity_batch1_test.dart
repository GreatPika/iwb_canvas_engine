import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/advanced.dart';
import 'package:iwb_canvas_engine_example/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<SceneController> pumpExampleApp(
    WidgetTester tester, {
    Scene? scene,
  }) async {
    final controller = SceneController(
      scene: scene ?? Scene(layers: [Layer()]),
      clearSelectionOnDrawModeEnter: true,
      pointerSettings: const PointerInputSettings(
        tapSlop: 16,
        doubleTapSlop: 32,
        doubleTapMaxDelayMs: 450,
      ),
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(CanvasExampleApp(controller: controller));
    await tester.pumpAndSettle();
    return controller;
  }

  Layer annotationLayer(Scene scene) =>
      scene.layers.firstWhere((layer) => !layer.isBackground);

  Offset sceneToGlobal(
    WidgetTester tester,
    SceneController controller,
    Offset scenePoint,
  ) {
    final canvasTopLeft = tester.getTopLeft(find.byKey(canvasHostKey));
    return canvasTopLeft + toView(scenePoint, controller.scene.camera.offset);
  }

  Future<void> tapScene(
    WidgetTester tester,
    SceneController controller,
    Offset scenePoint,
  ) async {
    await tester.tapAt(sceneToGlobal(tester, controller, scenePoint));
    await tester.pump();
  }

  Future<void> dragScene(
    WidgetTester tester,
    SceneController controller, {
    required Offset from,
    required Offset to,
  }) async {
    final gesture = await tester.startGesture(
      sceneToGlobal(tester, controller, from),
    );
    await tester.pump();
    await gesture.moveTo(sceneToGlobal(tester, controller, to));
    await tester.pump();
    await gesture.up();
    await tester.pump();
  }

  IconButton iconButtonByKey(WidgetTester tester, Key key) =>
      tester.widget<IconButton>(find.byKey(key));

  testWidgets('G3.1: mode switch keeps selection semantics parity', (
    tester,
  ) async {
    final node = RectNode(
      id: 'rect-1',
      size: const Size(80, 60),
      fillColor: const Color(0xFF42A5F5),
    )..position = const Offset(200, 200);
    final controller = await pumpExampleApp(
      tester,
      scene: Scene(
        layers: [
          Layer(nodes: [node]),
        ],
      ),
    );
    controller.setSelection(const <NodeId>{'rect-1'});
    await tester.pump();

    expect(controller.mode, CanvasMode.move);
    expect(find.byKey(drawToolPenKey), findsNothing);
    expect(iconButtonByKey(tester, actionDeleteKey).onPressed, isNotNull);

    await tester.tap(find.byKey(modeDrawKey));
    await tester.pumpAndSettle();

    expect(controller.mode, CanvasMode.draw);
    expect(controller.selectedNodeIds, isEmpty);
    expect(find.byKey(drawToolPenKey), findsOneWidget);

    await tester.tap(find.byKey(modeMoveKey));
    await tester.pumpAndSettle();

    expect(controller.mode, CanvasMode.move);
    expect(controller.selectedNodeIds, isEmpty);
    expect(find.byKey(drawToolPenKey), findsNothing);
    expect(iconButtonByKey(tester, actionDeleteKey).onPressed, isNull);
  });

  testWidgets('G3.2: tap/marquee/clear selection parity', (tester) async {
    final bottom = RectNode(
      id: 'bottom',
      size: const Size(70, 70),
      fillColor: const Color(0xFFBDBDBD),
    )..position = const Offset(200, 200);
    final top = RectNode(
      id: 'top',
      size: const Size(70, 70),
      fillColor: const Color(0xFF66BB6A),
    )..position = const Offset(200, 200);
    final second = RectNode(
      id: 'second',
      size: const Size(70, 70),
      fillColor: const Color(0xFFEF5350),
    )..position = const Offset(300, 200);
    final controller = await pumpExampleApp(
      tester,
      scene: Scene(
        layers: [
          Layer(nodes: [bottom, top, second]),
        ],
      ),
    );

    await tapScene(tester, controller, const Offset(200, 200));
    expect(controller.selectedNodeIds, const <NodeId>{'top'});
    expect(iconButtonByKey(tester, actionDeleteKey).onPressed, isNotNull);

    await dragScene(
      tester,
      controller,
      from: const Offset(120, 120),
      to: const Offset(360, 260),
    );
    expect(controller.selectedNodeIds, const <NodeId>{
      'bottom',
      'top',
      'second',
    });

    await tapScene(tester, controller, const Offset(20, 20));
    expect(controller.selectedNodeIds, isEmpty);
    expect(iconButtonByKey(tester, actionDeleteKey).onPressed, isNull);
  });

  testWidgets('G3.3: draw tools create expected nodes and clear pending line', (
    tester,
  ) async {
    final controller = await pumpExampleApp(tester);

    await tester.tap(find.byKey(modeDrawKey));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(drawToolPenKey));
    await tester.pump();
    expect(iconButtonByKey(tester, drawToolPenKey).color, Colors.blue);
    await dragScene(
      tester,
      controller,
      from: const Offset(120, 180),
      to: const Offset(220, 180),
    );

    final firstStroke =
        annotationLayer(controller.scene).nodes.last as StrokeNode;
    expect(firstStroke.opacity, 1);
    expect(firstStroke.thickness, controller.penThickness);

    await tester.tap(find.byKey(drawToolHighlighterKey));
    await tester.pump();
    expect(iconButtonByKey(tester, drawToolHighlighterKey).color, Colors.blue);
    await dragScene(
      tester,
      controller,
      from: const Offset(120, 220),
      to: const Offset(220, 220),
    );

    final secondStroke =
        annotationLayer(controller.scene).nodes.last as StrokeNode;
    expect(secondStroke.opacity, controller.highlighterOpacity);
    expect(secondStroke.thickness, controller.highlighterThickness);

    await tester.tap(find.byKey(drawToolLineKey));
    await tester.pump();
    await tapScene(tester, controller, const Offset(120, 260));
    expect(controller.pendingLineStart, isNotNull);

    await tester.tap(find.byKey(modeMoveKey));
    await tester.pumpAndSettle();
    expect(controller.pendingLineStart, isNull);

    await tester.tap(find.byKey(modeDrawKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(drawToolEraserKey));
    await tester.pump();
    expect(iconButtonByKey(tester, drawToolEraserKey).color, Colors.blue);

    final beforeEraseCount = annotationLayer(controller.scene).nodes.length;
    await dragScene(
      tester,
      controller,
      from: const Offset(100, 180),
      to: const Offset(240, 180),
    );
    final afterEraseCount = annotationLayer(controller.scene).nodes.length;
    expect(afterEraseCount, lessThan(beforeEraseCount));
  });

  testWidgets('G3.4: line two-tap flow commits and reset clears pending', (
    tester,
  ) async {
    final controller = await pumpExampleApp(tester);

    await tester.tap(find.byKey(modeDrawKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(drawToolLineKey));
    await tester.pump();
    expect(iconButtonByKey(tester, drawToolLineKey).color, Colors.blue);

    const start = Offset(140, 200);
    const end = Offset(260, 200);

    await tapScene(tester, controller, start);
    expect(controller.pendingLineStart, start);
    expect(
      annotationLayer(controller.scene).nodes.whereType<LineNode>(),
      isEmpty,
    );

    await tapScene(tester, controller, end);
    expect(controller.pendingLineStart, isNull);
    final lines = annotationLayer(controller.scene).nodes.whereType<LineNode>();
    expect(lines.length, 1);
    final line = lines.single;
    final worldStart = line.transform.applyToPoint(line.start);
    final worldEnd = line.transform.applyToPoint(line.end);
    expect((worldStart - start).distance, lessThan(0.001));
    expect((worldEnd - end).distance, lessThan(0.001));

    await tapScene(tester, controller, const Offset(300, 260));
    expect(controller.pendingLineStart, const Offset(300, 260));

    await tester.tap(find.byKey(modeMoveKey));
    await tester.pumpAndSettle();
    expect(controller.pendingLineStart, isNull);
    expect(
      annotationLayer(controller.scene).nodes.whereType<LineNode>(),
      hasLength(1),
    );
  });

  testWidgets(
    'G3.5: eraser deletes intersected nodes and normalizes selection',
    (tester) async {
      final stroke = StrokeNode(
        id: 'stroke-kill',
        points: const [Offset(120, 260), Offset(240, 260)],
        thickness: 6,
        color: const Color(0xFF000000),
      );
      final line = LineNode(
        id: 'line-kill',
        start: const Offset(180, 220),
        end: const Offset(180, 300),
        thickness: 6,
        color: const Color(0xFF000000),
      );
      final rect = RectNode(
        id: 'rect-keep',
        size: const Size(60, 60),
        fillColor: const Color(0xFF42A5F5),
      )..position = const Offset(340, 320);
      final controller = await pumpExampleApp(
        tester,
        scene: Scene(
          layers: [
            Layer(nodes: [stroke, line, rect]),
          ],
        ),
      );

      await tester.tap(find.byKey(modeDrawKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(drawToolEraserKey));
      await tester.pump();
      expect(iconButtonByKey(tester, drawToolEraserKey).color, Colors.blue);

      controller.setSelection(const <NodeId>{
        'stroke-kill',
        'line-kill',
        'rect-keep',
      });
      await tester.pump();

      await dragScene(
        tester,
        controller,
        from: const Offset(180, 210),
        to: const Offset(180, 310),
      );

      final remainingIds = annotationLayer(
        controller.scene,
      ).nodes.map((node) => node.id).toSet();
      expect(remainingIds, const <NodeId>{'rect-keep'});
      expect(controller.selectedNodeIds, const <NodeId>{'rect-keep'});
    },
  );
}
