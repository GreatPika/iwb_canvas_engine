import 'dart:ui';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';

// INV:INV-ENG-NO-EXTERNAL-MUTATION
// INV:INV-G-PUBLIC-ENTRYPOINTS

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'iwb_canvas_engine.dart exports representative symbols across layers',
    () {
      final scene = SceneSnapshot(
        layers: <ContentLayerSnapshot>[ContentLayerSnapshot(id: 'layer-api-0')],
      );
      final json = encodeSceneToJson(scene);
      final canonicalFromSnapshot = SceneBuilder.buildFromSnapshot(scene);
      final canonicalFromJson = SceneBuilder.buildFromJson(encodeScene(scene));
      final controller = SceneController(initialSnapshot: scene);

      addTearDown(controller.dispose);

      expect(Transform2D.identity.translation, Offset.zero);
      expect(PathFillRule.evenOdd.name, 'evenOdd');
      expect(CanvasMode.move, CanvasMode.move);
      expect(DrawTool.pen, DrawTool.pen);
      expect(parseNodeId('node-api-0'), 'node-api-0');
      expect(parseLayerId('layer-api-0'), 'layer-api-0');
      expect(json, contains('"schemaVersion":$schemaVersionWrite'));
      expect(decodeSceneFromJson(json).layers.single.id, 'layer-api-0');
      expect(canonicalFromSnapshot.layers.single.id, 'layer-api-0');
      expect(canonicalFromJson.layers.single.id, 'layer-api-0');

      controller.scene.write((txn) {
        expect(txn, isA<SceneWriteTxn>());
        expect(txn.snapshot.layers.single.id, 'layer-api-0');
        return null;
      });
    },
  );

  test('iwb_canvas_engine.dart exports immutable snapshots/specs/patches', () {
    final scene = SceneSnapshot(
      layers: <ContentLayerSnapshot>[
        ContentLayerSnapshot(
          id: 'layer-auto-0',
          nodes: <NodeSnapshot>[
            RectNodeSnapshot(id: 'rect-1', size: Size(40, 20)),
          ],
        ),
      ],
    );

    expect(scene.layers.single.nodes.single.id, 'rect-1');

    final patch = RectNodePatch(
      id: 'rect-1',
      size: PatchField<Size>.value(Size(50, 30)),
    );
    expect(patch.size.value, const Size(50, 30));
  });

  test('iwb_canvas_engine.dart exports snapshot json codec helpers', () {
    final scene = SceneSnapshot(
      layers: <ContentLayerSnapshot>[
        ContentLayerSnapshot(
          id: 'layer-auto-1',
          nodes: <NodeSnapshot>[
            RectNodeSnapshot(id: 'rect-json-1', size: Size(2, 3)),
          ],
        ),
      ],
    );
    final encoded = encodeScene(scene);
    final decoded = decodeScene(encoded);
    final decodedNode = decoded.layers.first.nodes.single;

    expect(encoded['schemaVersion'], schemaVersionWrite);
    expect(decodedNode.id, 'rect-json-1');
  });

  test('iwb_canvas_engine.dart exports pointer input contracts', () {
    const settings = PointerInputSettings(
      tapSlop: 10,
      doubleTapSlop: 24,
      doubleTapMaxDelayMs: 500,
      deferSingleTap: true,
    );
    const input = CanvasPointerInput(
      pointerId: 1,
      position: Offset(10, 20),
      timestampMs: 100,
      phase: CanvasPointerPhase.down,
      kind: PointerDeviceKind.touch,
    );
    const inputWithoutTimestamp = CanvasPointerInput(
      pointerId: 2,
      position: Offset(30, 40),
      phase: CanvasPointerPhase.move,
      kind: PointerDeviceKind.mouse,
    );

    expect(settings.tapSlop, 10);
    expect(settings.doubleTapSlop, 24);
    expect(settings.doubleTapMaxDelayMs, 500);
    expect(settings.deferSingleTap, isTrue);
    expect(input.phase, CanvasPointerPhase.down);
    expect(inputWithoutTimestamp.timestampMs, isNull);
  });

  test('iwb_canvas_engine.dart exports validated boundary values', () {
    expect(NodeIdValue.parse('node-public-1').value, 'node-public-1');
    expect(LayerIdValue.parse('layer-public-2').value, 'layer-public-2');
    expect(
      FiniteOffsetValue.of(const Offset(12, 24)).value,
      const Offset(12, 24),
    );
  });

  test('advanced.dart entrypoint is removed', () {
    expect(File('lib/advanced.dart').existsSync(), isFalse);
  });

  testWidgets(
    'public entrypoint is enough for SceneView + controller + handlePointer',
    (tester) async {
      final controller = SceneController(
        initialSnapshot: SceneSnapshot(
          layers: <ContentLayerSnapshot>[
            ContentLayerSnapshot(id: 'layer-auto-2'),
          ],
        ),
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: SizedBox.expand(child: SceneView(controller: controller)),
        ),
      );
      await tester.pump();

      controller.interaction.handlePointer(
        const CanvasPointerInput(
          pointerId: 1,
          position: Offset(32, 32),
          phase: CanvasPointerPhase.down,
          kind: PointerDeviceKind.touch,
        ),
      );
      controller.interaction.handlePointer(
        const CanvasPointerInput(
          pointerId: 1,
          position: Offset(40, 40),
          phase: CanvasPointerPhase.up,
          kind: PointerDeviceKind.touch,
        ),
      );

      expect(find.byType(SceneView), findsOneWidget);
    },
  );
}
