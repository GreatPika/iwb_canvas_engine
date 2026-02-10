import 'dart:convert';

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

  SceneNode nodeById(Scene scene, NodeId id) {
    for (final layer in scene.layers) {
      for (final node in layer.nodes) {
        if (node.id == id) return node;
      }
    }
    throw StateError('Node not found: $id');
  }

  bool transformEqualsWithinEpsilon(
    Transform2D left,
    Transform2D right, {
    double epsilon = 1e-6,
  }) {
    bool close(double a, double b) => (a - b).abs() <= epsilon;
    return close(left.a, right.a) &&
        close(left.b, right.b) &&
        close(left.c, right.c) &&
        close(left.d, right.d) &&
        close(left.tx, right.tx) &&
        close(left.ty, right.ty);
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

  Future<void> tapByKey(WidgetTester tester, Key key) async {
    final finder = find.byKey(key);
    await tester.ensureVisible(finder);
    await tester.tap(finder);
    await tester.pump();
  }

  Future<void> dragSliderToMax(WidgetTester tester, Key key) async {
    final finder = find.byKey(key);
    await tester.ensureVisible(finder);
    await tester.drag(finder, const Offset(1200, 0));
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

  testWidgets(
    'G3.6: text inline edit saves on tap outside and closes unchanged session',
    (tester) async {
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

      await tapScene(tester, controller, const Offset(220, 220));
      expect(find.byKey(inlineTextEditOverlayKey), findsNothing);
      expect(textNode.isVisible, isTrue);

      await doubleTapScene(
        tester,
        controller,
        const Offset(220, 220),
        pointer: 61,
      );
      await tester.pumpAndSettle();

      expect(find.byKey(inlineTextEditOverlayKey), findsOneWidget);
      expect(find.byKey(inlineTextEditFieldKey), findsOneWidget);
      expect(textNode.isVisible, isFalse);

      await tester.enterText(find.byKey(inlineTextEditFieldKey), 'Edited Note');
      await tester.pump();
      await tapScene(tester, controller, const Offset(30, 30));
      await tester.pumpAndSettle();

      expect(textNode.text, 'Edited Note');
      expect(textNode.isVisible, isTrue);
      expect(find.byKey(inlineTextEditOverlayKey), findsNothing);

      await doubleTapScene(
        tester,
        controller,
        const Offset(220, 220),
        pointer: 62,
      );
      await tester.pumpAndSettle();
      expect(find.byKey(inlineTextEditOverlayKey), findsOneWidget);
      expect(textNode.isVisible, isFalse);

      await tapScene(tester, controller, const Offset(40, 40));
      await tester.pumpAndSettle();

      expect(textNode.text, 'Edited Note');
      expect(textNode.isVisible, isTrue);
      expect(find.byKey(inlineTextEditOverlayKey), findsNothing);
    },
  );

  testWidgets(
    'G3.7: text styling panel applies color/align/size/line-height/style parity',
    (tester) async {
      final textA = TextNode(
        id: 'text-a',
        text: 'Alpha',
        size: const Size(140, 40),
        fontSize: 20,
        color: const Color(0xFF212121),
      )..position = const Offset(220, 220);
      final textB = TextNode(
        id: 'text-b',
        text: 'Beta',
        size: const Size(140, 40),
        fontSize: 20,
        color: const Color(0xFF212121),
      )..position = const Offset(380, 220);
      final controller = await pumpExampleApp(
        tester,
        scene: Scene(
          layers: [
            Layer(nodes: [textA, textB]),
          ],
        ),
      );

      expect(find.byKey(textOptionsPanelKey), findsNothing);

      controller.setSelection(const <NodeId>{'text-a', 'text-b'});
      await tester.pump();
      expect(find.byKey(textOptionsPanelKey), findsOneWidget);

      await tapByKey(tester, textStyleBoldKey);
      await tapByKey(tester, textStyleItalicKey);
      await tapByKey(tester, textStyleUnderlineKey);

      expect(textA.isBold, isTrue);
      expect(textA.isItalic, isTrue);
      expect(textA.isUnderline, isTrue);
      expect(textB.isBold, isTrue);
      expect(textB.isItalic, isTrue);
      expect(textB.isUnderline, isTrue);
      expect(iconButtonByKey(tester, textStyleBoldKey).color, Colors.blue);
      expect(iconButtonByKey(tester, textStyleItalicKey).color, Colors.blue);
      expect(iconButtonByKey(tester, textStyleUnderlineKey).color, Colors.blue);

      await tapByKey(tester, textAlignCenterKey);
      expect(textA.align, TextAlign.center);
      expect(textB.align, TextAlign.center);
      expect(iconButtonByKey(tester, textAlignCenterKey).color, Colors.blue);

      await tapByKey(tester, textAlignRightKey);
      expect(textA.align, TextAlign.right);
      expect(textB.align, TextAlign.right);
      expect(iconButtonByKey(tester, textAlignRightKey).color, Colors.blue);

      await dragSliderToMax(tester, textFontSizeSliderKey);
      expect(textA.fontSize, closeTo(72, 0.001));
      expect(textB.fontSize, closeTo(72, 0.001));

      await dragSliderToMax(tester, textLineHeightSliderKey);
      expect(textA.lineHeight, isNotNull);
      expect(textB.lineHeight, isNotNull);
      expect(textA.lineHeight!, closeTo(216, 0.001));
      expect(textB.lineHeight!, closeTo(216, 0.001));

      final expectedColor = controller.scene.palette.penColors[2];
      await tapByKey(
        tester,
        const ValueKey<String>('${textColorSwatchKeyPrefix}2'),
      );
      expect(textA.color, expectedColor);
      expect(textB.color, expectedColor);
    },
  );

  testWidgets('G3.8: transformations + marquee-selection parity', (
    tester,
  ) async {
    final targetA = RectNode(
      id: 'target-a',
      size: const Size(80, 60),
      fillColor: const Color(0xFF42A5F5),
    )..position = const Offset(180, 200);
    final targetB = RectNode(
      id: 'target-b',
      size: const Size(80, 60),
      fillColor: const Color(0xFF66BB6A),
    )..position = const Offset(280, 200);
    final keep = RectNode(
      id: 'keep',
      size: const Size(80, 60),
      fillColor: const Color(0xFFEF5350),
    )..position = const Offset(500, 200);

    final controller = await pumpExampleApp(
      tester,
      scene: Scene(
        layers: [
          Layer(nodes: [targetA, targetB, keep]),
        ],
      ),
    );

    expect(controller.mode, CanvasMode.move);
    expect(controller.selectedNodeIds, isEmpty);
    expect(iconButtonByKey(tester, actionRotateLeftKey).onPressed, isNull);
    expect(iconButtonByKey(tester, actionRotateRightKey).onPressed, isNull);
    expect(iconButtonByKey(tester, actionFlipVerticalKey).onPressed, isNull);
    expect(iconButtonByKey(tester, actionFlipHorizontalKey).onPressed, isNull);

    final beforeTargetATransform = targetA.transform;
    final beforeTargetBTransform = targetB.transform;
    final beforeKeepTransform = keep.transform;
    final beforeKeepPosition = keep.position;

    await dragScene(
      tester,
      controller,
      from: const Offset(130, 150),
      to: const Offset(340, 250),
    );

    expect(controller.selectedNodeIds, const <NodeId>{'target-a', 'target-b'});
    expect(iconButtonByKey(tester, actionRotateLeftKey).onPressed, isNotNull);
    expect(iconButtonByKey(tester, actionRotateRightKey).onPressed, isNotNull);
    expect(iconButtonByKey(tester, actionFlipVerticalKey).onPressed, isNotNull);
    expect(
      iconButtonByKey(tester, actionFlipHorizontalKey).onPressed,
      isNotNull,
    );

    await tapByKey(tester, actionRotateLeftKey);
    await tapByKey(tester, actionRotateRightKey);
    await tapByKey(tester, actionFlipVerticalKey);
    await tapByKey(tester, actionFlipHorizontalKey);

    final afterTargetA = nodeById(controller.scene, 'target-a');
    final afterTargetB = nodeById(controller.scene, 'target-b');
    final afterKeep = nodeById(controller.scene, 'keep');

    expect(
      transformEqualsWithinEpsilon(
        afterTargetA.transform,
        beforeTargetATransform,
      ),
      isFalse,
    );
    expect(
      transformEqualsWithinEpsilon(
        afterTargetB.transform,
        beforeTargetBTransform,
      ),
      isFalse,
    );
    expect(
      transformEqualsWithinEpsilon(afterKeep.transform, beforeKeepTransform),
      isTrue,
    );
    expect(afterKeep.position.dx, closeTo(beforeKeepPosition.dx, 1e-6));
    expect(afterKeep.position.dy, closeTo(beforeKeepPosition.dy, 1e-6));

    await tapByKey(tester, actionDeleteKey);

    final remainingNodes = annotationLayer(controller.scene).nodes;
    expect(remainingNodes.map((node) => node.id).toList(), <NodeId>['keep']);
    expect(controller.selectedNodeIds, isEmpty);
  });

  testWidgets('G3.9: camera pan controls preserve hit-test parity', (
    tester,
  ) async {
    final target = RectNode(
      id: 'camera-target',
      size: const Size(80, 60),
      fillColor: const Color(0xFF42A5F5),
    )..position = const Offset(220, 220);
    final controller = await pumpExampleApp(
      tester,
      scene: Scene(
        layers: [
          Layer(nodes: [target]),
        ],
      ),
    );

    expect(controller.scene.camera.offset, Offset.zero);
    await tapScene(tester, controller, target.position);
    expect(controller.selectedNodeIds, const <NodeId>{'camera-target'});

    await tapByKey(tester, cameraPanRightKey);
    expect(controller.scene.camera.offset, const Offset(50, 0));
    await tapByKey(tester, cameraPanLeftKey);
    expect(controller.scene.camera.offset, Offset.zero);

    await tapByKey(tester, cameraPanDownKey);
    expect(controller.scene.camera.offset, const Offset(0, 50));
    await tapByKey(tester, cameraPanUpKey);
    expect(controller.scene.camera.offset, Offset.zero);

    final oldVisualGlobal = sceneToGlobal(tester, controller, target.position);
    await tapByKey(tester, cameraPanRightKey);
    await tapByKey(tester, cameraPanDownKey);
    expect(controller.scene.camera.offset, const Offset(50, 50));

    controller.setSelection(const <NodeId>{});
    await tester.pump();

    await tester.tapAt(oldVisualGlobal);
    await tester.pump();
    expect(controller.selectedNodeIds, isEmpty);

    await tester.tapAt(sceneToGlobal(tester, controller, target.position));
    await tester.pump();
    expect(controller.selectedNodeIds, const <NodeId>{'camera-target'});
  });

  testWidgets('G3.10: grid/system actions parity with import replace scene', (
    tester,
  ) async {
    final initialNode = RectNode(
      id: 'initial-node',
      size: const Size(70, 50),
      fillColor: const Color(0xFF42A5F5),
    )..position = const Offset(140, 140);
    final controller = await pumpExampleApp(
      tester,
      scene: Scene(
        layers: [
          Layer(nodes: [initialNode]),
        ],
      ),
    );

    controller.setSelection(const <NodeId>{'initial-node'});
    await tester.pump();
    expect(controller.selectedNodeIds, const <NodeId>{'initial-node'});

    await tapByKey(tester, gridMenuButtonKey);
    expect(controller.scene.background.grid.isEnabled, isFalse);
    await tapByKey(tester, gridEnabledSwitchKey);
    expect(controller.scene.background.grid.isEnabled, isTrue);
    await tapByKey(
      tester,
      const ValueKey<String>('${gridCellSizeOptionKeyPrefix}40'),
    );
    expect(controller.scene.background.grid.cellSize, 40);

    final targetBackgroundColor = controller.scene.palette.backgroundColors[1];
    await openMenuAndTapItem(
      tester,
      menuKey: systemMenuButtonKey,
      itemKey: const ValueKey<String>('${backgroundColorSwatchKeyPrefix}1'),
    );
    expect(controller.scene.background.color, targetBackgroundColor);

    await openMenuAndTapItem(
      tester,
      menuKey: systemMenuButtonKey,
      itemKey: systemExportJsonKey,
    );
    await tester.pumpAndSettle();
    expect(find.text('Scene JSON'), findsOneWidget);
    final exportField = find.byType(TextField).first;
    final exportController = tester.widget<TextField>(exportField).controller;
    expect(exportController, isNotNull);
    final exported = exportController!.text;
    final exportedMap = jsonDecode(exported) as Map<String, dynamic>;
    expect(exportedMap['schemaVersion'], 2);
    expect(find.text('Copy'), findsOneWidget);
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    expect(find.text('Scene JSON'), findsNothing);

    final importedMap = <String, dynamic>{
      ...exportedMap,
      'camera': <String, dynamic>{'offsetX': 120, 'offsetY': -40},
      'background': <String, dynamic>{
        'color': '#fffff59d',
        'grid': <String, dynamic>{
          'enabled': true,
          'cellSize': 40,
          'color': '#ffe0e0e0',
        },
      },
      'layers': <Map<String, dynamic>>[
        <String, dynamic>{
          'isBackground': false,
          'nodes': <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 'imported-rect',
              'type': 'rect',
              'transform': <String, dynamic>{
                'a': 1,
                'b': 0,
                'c': 0,
                'd': 1,
                'tx': 420,
                'ty': 300,
              },
              'hitPadding': 0,
              'opacity': 1,
              'isVisible': true,
              'isSelectable': true,
              'isLocked': false,
              'isDeletable': true,
              'isTransformable': true,
              'size': <String, dynamic>{'w': 100, 'h': 70},
              'fillColor': '#ff66bb6a',
              'strokeColor': '#ff2e7d32',
              'strokeWidth': 2,
            },
          ],
        },
      ],
    };
    final importedJson = jsonEncode(importedMap);

    await openMenuAndTapItem(
      tester,
      menuKey: systemMenuButtonKey,
      itemKey: systemImportJsonKey,
    );
    await tester.pumpAndSettle();
    expect(find.text('Import Scene'), findsOneWidget);
    await tester.enterText(find.byKey(importSceneFieldKey), importedJson);
    await tapByKey(tester, importSceneConfirmKey);
    await tester.pumpAndSettle();

    expect(find.textContaining('Error:'), findsNothing);

    expect(controller.selectedNodeIds, isEmpty);
    expect(controller.scene.camera.offset, const Offset(120, -40));
    expect(controller.scene.background.grid.isEnabled, isTrue);
    expect(controller.scene.background.grid.cellSize, 40);
    expect(controller.scene.background.color, const Color(0xFFFFF59D));
    final importedNodes = annotationLayer(controller.scene).nodes;
    expect(importedNodes.map((node) => node.id).toList(), <NodeId>[
      'imported-rect',
    ]);
    expect(find.text('Camera X: 120'), findsOneWidget);

    await openMenuAndTapItem(
      tester,
      menuKey: systemMenuButtonKey,
      itemKey: systemClearCanvasKey,
    );
    await tester.pumpAndSettle();
    final nonBackgroundNodeCount = controller.scene.layers
        .where((layer) => !layer.isBackground)
        .fold<int>(0, (sum, layer) => sum + layer.nodes.length);
    expect(nonBackgroundNodeCount, 0);
    expect(controller.selectedNodeIds, isEmpty);
  });
}
