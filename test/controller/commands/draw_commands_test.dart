import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine/src/core/scene_limits.dart';
import 'package:iwb_canvas_engine/src/controller/scene_controller.dart';

import '../../utils/scene_invariants.dart';

SceneControllerCore buildController() {
  return SceneControllerCore(
    initialSnapshot: SceneSnapshot(
      layers: <ContentLayerSnapshot>[
        ContentLayerSnapshot(
          nodes: const <NodeSnapshot>[
            RectNodeSnapshot(id: 'base', size: Size(20, 10)),
          ],
        ),
      ],
    ),
  );
}

void assertControllerInvariants(SceneControllerCore controller) {
  assertSceneInvariants(
    controller.snapshot,
    selectedNodeIds: controller.selectedNodeIds,
  );
}

void main() {
  test('draw commands create line/stroke and erase removes node ids', () async {
    final controller = buildController();
    addTearDown(controller.dispose);

    final signalTypes = <String>[];
    final sub = controller.signals.listen((signal) {
      signalTypes.add(signal.type);
    });
    addTearDown(sub.cancel);

    final strokeId = controller.draw.writeDrawStroke(
      points: const <Offset>[Offset(0, 0), Offset(10, 0)],
      thickness: 2,
      color: const Color(0xFF000000),
    );
    final lineId = controller.draw.writeDrawLine(
      start: const Offset(0, 0),
      end: const Offset(0, 10),
      thickness: 3,
      color: const Color(0xFF111111),
    );

    final removed = controller.draw.writeEraseNodes(<NodeId>[
      strokeId,
      'missing',
    ]);
    await pumpEventQueue();

    expect(lineId, isNotEmpty);
    expect(removed, 1);
    expect(
      signalTypes,
      containsAll(<String>['draw.stroke', 'draw.line', 'draw.erase']),
    );
    assertControllerInvariants(controller);
  });

  test('draw stroke without layerIndex does not create extra layers', () async {
    final controller = buildController();
    addTearDown(controller.dispose);

    for (var i = 0; i < 100; i++) {
      controller.draw.writeDrawStroke(
        points: <Offset>[Offset(i.toDouble(), 0), Offset(i.toDouble() + 1, 0)],
        thickness: 2,
        color: const Color(0xFF000000),
      );
    }
    await pumpEventQueue();

    expect(controller.snapshot.layers, hasLength(1));
    expect(controller.snapshot.layers.first.nodes, hasLength(101));
    assertControllerInvariants(controller);
  });

  test('erase signal removedIds are sorted', () async {
    final controller = buildController();
    addTearDown(controller.dispose);

    controller.commands.writeAddNode(
      RectNodeSpec(id: 'z-node', size: const Size(6, 6)),
    );
    controller.commands.writeAddNode(
      RectNodeSpec(id: 'a-node', size: const Size(6, 6)),
    );
    await pumpEventQueue();

    List<NodeId>? erasedIds;
    final sub = controller.signals.listen((signal) {
      if (signal.type == 'draw.erase') {
        erasedIds = signal.nodeIds;
      }
    });
    addTearDown(sub.cancel);

    final removedCount = controller.draw.writeEraseNodes(const <NodeId>{
      'z-node',
      'base',
      'a-node',
    });
    await pumpEventQueue();

    expect(removedCount, 3);
    expect(erasedIds, const <NodeId>['a-node', 'base', 'z-node']);
    assertControllerInvariants(controller);
  });

  test('draw stroke resamples when exceeds max points', () async {
    final controller = buildController();
    addTearDown(controller.dispose);

    final points = List<Offset>.generate(
      kMaxStrokePointsPerNode + 500,
      (i) => Offset(i.toDouble(), (i % 11).toDouble()),
      growable: false,
    );

    final strokeId = controller.draw.writeDrawStroke(
      points: points,
      thickness: 2,
      color: const Color(0xFF000000),
    );
    await pumpEventQueue();

    final stroke = controller.snapshot.layers
        .expand((layer) => layer.nodes)
        .whereType<StrokeNodeSnapshot>()
        .firstWhere((node) => node.id == strokeId);

    expect(stroke.points.length, kMaxStrokePointsPerNode);
    expect(stroke.points.first, points.first);
    expect(stroke.points.last, points.last);
    for (final point in stroke.points) {
      expect(point.dx.isFinite, isTrue);
      expect(point.dy.isFinite, isTrue);
    }
    assertControllerInvariants(controller);
  });

  test('draw line with non positive thickness throws ArgumentError', () async {
    final controller = buildController();
    addTearDown(controller.dispose);

    expect(
      () => controller.draw.writeDrawLine(
        start: const Offset(0, 0),
        end: const Offset(10, 10),
        thickness: 0,
        color: const Color(0xFF000000),
      ),
      throwsArgumentError,
    );
    await pumpEventQueue();
    assertControllerInvariants(controller);
  });
}
