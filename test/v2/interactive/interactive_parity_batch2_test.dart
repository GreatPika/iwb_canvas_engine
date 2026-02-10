// ignore_for_file: avoid_relative_lib_imports

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/basic.dart';
import '../../../example/lib/main.dart';

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

  int nonBackgroundNodeCount(Scene scene) {
    return scene.layers
        .where((layer) => !layer.isBackground)
        .fold<int>(0, (sum, layer) => sum + layer.nodes.length);
  }

  SceneNode nodeById(Scene scene, NodeId id) {
    for (final layer in scene.layers) {
      for (final node in layer.nodes) {
        if (node.id == id) return node;
      }
    }
    throw StateError('Node not found: $id');
  }

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

  Future<void> doubleTapScene(
    WidgetTester tester,
    SceneController controller,
    Offset scenePoint, {
    required int pointer,
    Duration delay = const Duration(milliseconds: 80),
  }) async {
    final globalPoint = sceneToGlobal(tester, controller, scenePoint);
    final firstTap = await tester.startGesture(globalPoint, pointer: pointer);
    await firstTap.up();
    await tester.pump();
    await tester.pump(delay);
    final secondTap = await tester.startGesture(globalPoint, pointer: pointer);
    await secondTap.up();
    await tester.pump();
  }

  Future<void> tapByKey(WidgetTester tester, Key key) async {
    final finder = find.byKey(key);
    await tester.ensureVisible(finder);
    await tester.tap(finder);
    await tester.pump();
  }

  Future<void> openMenuAndTapItem(
    WidgetTester tester, {
    required Key menuKey,
    required Key itemKey,
  }) async {
    Future<void> ensureMenuOpen() async {
      var visibleItem = find.byKey(itemKey).hitTestable();
      if (visibleItem.evaluate().isNotEmpty) return;
      await tapByKey(tester, menuKey);
      await tester.pumpAndSettle();
      visibleItem = find.byKey(itemKey).hitTestable();
      if (visibleItem.evaluate().isNotEmpty) return;
      await tapByKey(tester, menuKey);
      await tester.pumpAndSettle();
    }

    await ensureMenuOpen();
    await tester.tap(find.byKey(itemKey).hitTestable().first);
    await tester.pump();
  }

  testWidgets('G3.12: system menu background flow + clear canvas parity', (
    tester,
  ) async {
    final first = RectNode(
      id: 'rect-1',
      size: const Size(70, 50),
      fillColor: const Color(0xFF42A5F5),
    )..position = const Offset(140, 120);
    final second = RectNode(
      id: 'rect-2',
      size: const Size(80, 60),
      fillColor: const Color(0xFFEF5350),
    )..position = const Offset(250, 180);
    final controller = await pumpExampleApp(
      tester,
      scene: Scene(
        layers: [
          Layer(nodes: [first, second]),
        ],
      ),
    );

    controller.setSelection(const <NodeId>{'rect-1'});
    controller.setGridEnabled(true);
    controller.setGridCellSize(40);
    await tester.pump();

    final targetBackgroundColor = controller.scene.palette.backgroundColors[1];
    await openMenuAndTapItem(
      tester,
      menuKey: systemMenuButtonKey,
      itemKey: const ValueKey<String>('${backgroundColorSwatchKeyPrefix}1'),
    );

    expect(controller.scene.background.color, targetBackgroundColor);
    expect(controller.scene.background.grid.isEnabled, isTrue);
    expect(controller.scene.background.grid.cellSize, 40);

    await openMenuAndTapItem(
      tester,
      menuKey: systemMenuButtonKey,
      itemKey: systemClearCanvasKey,
    );
    await tester.pumpAndSettle();

    expect(nonBackgroundNodeCount(controller.scene), 0);
    expect(controller.selectedNodeIds, isEmpty);
    expect(controller.scene.background.color, targetBackgroundColor);
    expect(controller.scene.background.grid.isEnabled, isTrue);
    expect(controller.scene.background.grid.cellSize, 40);
  });

  testWidgets('G3.13: camera indicator and pending-line marker parity', (
    tester,
  ) async {
    final controller = await pumpExampleApp(tester);

    expect(find.byKey(cameraIndicatorKey), findsOneWidget);
    expect(find.text('Camera X: 0'), findsOneWidget);
    expect(find.byKey(pendingLineMarkerPaintKey), findsOneWidget);
    expect(find.byKey(pendingLineMarkerActiveKey), findsNothing);
    expect(controller.pendingLineStart, isNull);

    await tapByKey(tester, cameraPanRightKey);
    expect(controller.scene.camera.offset, const Offset(50, 0));
    expect(find.text('Camera X: 50'), findsOneWidget);

    controller.setCameraOffset(const Offset(120, -20));
    await tester.pump();
    expect(find.text('Camera X: 120'), findsOneWidget);

    await tapByKey(tester, modeDrawKey);
    await tester.pumpAndSettle();
    await tapByKey(tester, drawToolLineKey);

    await tapScene(tester, controller, const Offset(120, 240));
    expect(controller.pendingLineStart, const Offset(120, 240));
    expect(find.byKey(pendingLineMarkerActiveKey), findsOneWidget);

    await tapScene(tester, controller, const Offset(260, 240));
    expect(controller.pendingLineStart, isNull);
    expect(find.byKey(pendingLineMarkerActiveKey), findsNothing);

    await tapScene(tester, controller, const Offset(180, 280));
    expect(controller.pendingLineStart, const Offset(180, 280));
    expect(find.byKey(pendingLineMarkerActiveKey), findsOneWidget);

    await tapByKey(tester, modeMoveKey);
    await tester.pumpAndSettle();
    expect(controller.pendingLineStart, isNull);
    expect(find.byKey(pendingLineMarkerActiveKey), findsNothing);
  });

  testWidgets('G3.14: text edit commits on tap outside and mode switch', (
    tester,
  ) async {
    final textNode = TextNode(
      id: 'text-1',
      text: 'Start Note',
      size: const Size(180, 40),
      fontSize: 20,
      color: const Color(0xFF212121),
    )..position = const Offset(220, 220);
    final controller = await pumpExampleApp(
      tester,
      scene: Scene(
        layers: [
          Layer(nodes: [textNode]),
        ],
      ),
    );

    expect(find.byKey(inlineTextEditOverlayKey), findsNothing);

    await doubleTapScene(
      tester,
      controller,
      const Offset(220, 220),
      pointer: 71,
    );
    await tester.pumpAndSettle();

    expect(find.byKey(inlineTextEditOverlayKey), findsOneWidget);
    expect(find.byKey(inlineTextEditFieldKey), findsOneWidget);
    expect(
      (nodeById(controller.scene, 'text-1') as TextNode).isVisible,
      isFalse,
    );

    await tester.enterText(
      find.byKey(inlineTextEditFieldKey),
      'Saved by tap outside',
    );
    await tester.pump();
    await tapScene(tester, controller, const Offset(40, 40));
    await tester.pumpAndSettle();

    final afterOutside = nodeById(controller.scene, 'text-1') as TextNode;
    expect(afterOutside.text, 'Saved by tap outside');
    expect(afterOutside.isVisible, isTrue);
    expect(find.byKey(inlineTextEditOverlayKey), findsNothing);

    await doubleTapScene(
      tester,
      controller,
      const Offset(220, 220),
      pointer: 72,
    );
    await tester.pumpAndSettle();

    expect(find.byKey(inlineTextEditOverlayKey), findsOneWidget);
    expect(
      (nodeById(controller.scene, 'text-1') as TextNode).isVisible,
      isFalse,
    );

    await tester.enterText(find.byKey(inlineTextEditFieldKey), 'Saved by mode');
    await tester.pump();
    await tapByKey(tester, modeDrawKey);
    await tester.pumpAndSettle();

    expect(controller.mode, CanvasMode.draw);
    final afterMode = nodeById(controller.scene, 'text-1') as TextNode;
    expect(afterMode.text, 'Saved by mode');
    expect(afterMode.isVisible, isTrue);
    expect(find.byKey(inlineTextEditOverlayKey), findsNothing);
  });
}
