import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/advanced.dart';

// INV:INV-COMMANDS-STRUCTURAL-NOTIFYSCENECHANGED
// INV:INV-COMMANDS-MUTATE-STRUCTURAL-EXPLICIT
// INV:INV-INPUT-BACKGROUND-NONINTERACTIVE-NONDELETABLE
// INV:INV-SELECTION-STRICT-INTERACTIVE-IDS
// INV:INV-INPUT-NODEID-INDEX-CONSISTENT

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Layer firstNonBackgroundLayer(Scene scene) =>
      scene.layers.firstWhere((layer) => !layer.isBackground);

  test('addNode notifies immediately (structural mutation)', () {
    final controller = SceneController(scene: Scene());
    addTearDown(controller.dispose);

    var notifications = 0;
    controller.addListener(() => notifications++);

    controller.addNode(
      RectNode(
        id: 'r1',
        size: const Size(10, 10),
        fillColor: const Color(0xFF000000),
      ),
    );

    expect(notifications, 1);
  });

  testWidgets('addNode defaults to first non-background layer and notifies', (
    tester,
  ) async {
    // INV:INV-COMMANDS-ADDNODE-DEFAULT-NONBACKGROUND
    final controller = SceneController(scene: Scene());
    addTearDown(controller.dispose);

    var notifications = 0;
    controller.addListener(() => notifications++);

    controller.addNode(
      RectNode(
        id: 'r1',
        size: const Size(10, 10),
        fillColor: const Color(0xFF000000),
      )..position = const Offset(0, 0),
    );

    await tester.pump();

    expect(controller.scene.layers, hasLength(2));
    expect(controller.scene.layers.first.isBackground, isTrue);
    expect(firstNonBackgroundLayer(controller.scene).nodes.single.id, 'r1');
    expect(notifications, 1);
  });

  test(
    'addNode default creates non-background layer when scene is background-only',
    () {
      final controller = SceneController(
        scene: Scene(layers: [Layer(isBackground: true)]),
      );
      addTearDown(controller.dispose);

      controller.addNode(
        RectNode(
          id: 'r1',
          size: const Size(10, 10),
          fillColor: const Color(0xFF000000),
        )..position = const Offset(0, 0),
      );

      expect(controller.scene.layers, hasLength(2));
      expect(controller.scene.layers.first.isBackground, isTrue);
      expect(firstNonBackgroundLayer(controller.scene).nodes.single.id, 'r1');
    },
  );

  test('addNode recreates layer when scene layers are externally cleared', () {
    final controller = SceneController(scene: Scene());
    addTearDown(controller.dispose);
    controller.scene.layers.clear();

    controller.addNode(
      RectNode(
        id: 'r1',
        size: const Size(10, 10),
        fillColor: const Color(0xFF000000),
      )..position = const Offset(0, 0),
    );

    expect(controller.scene.layers, hasLength(1));
    expect(controller.scene.layers.single.nodes.single.id, 'r1');
  });

  test(
    'addNode throws for non-zero layerIndex when scene layers are externally cleared',
    () {
      final controller = SceneController(scene: Scene());
      addTearDown(controller.dispose);
      controller.scene.layers.clear();

      expect(
        () => controller.addNode(
          RectNode(
            id: 'r1',
            size: const Size(10, 10),
            fillColor: const Color(0xFF000000),
          )..position = const Offset(0, 0),
          layerIndex: 1,
        ),
        throwsRangeError,
      );
    },
  );

  test('addNode throws for invalid layerIndex', () {
    final controller = SceneController(scene: Scene());
    addTearDown(controller.dispose);

    expect(
      () => controller.addNode(
        RectNode(
          id: 'r0',
          size: const Size(10, 10),
          fillColor: const Color(0xFF000000),
        )..position = const Offset(0, 0),
        layerIndex: -1,
      ),
      throwsRangeError,
    );

    expect(
      () => controller.addNode(
        RectNode(
          id: 'r1',
          size: const Size(10, 10),
          fillColor: const Color(0xFF000000),
        )..position = const Offset(0, 0),
        layerIndex: 1,
      ),
      throwsRangeError,
    );
  });

  test('addNode throws for out-of-range index on non-empty scene', () {
    final controller = SceneController(scene: Scene(layers: [Layer()]));
    addTearDown(controller.dispose);

    expect(
      () => controller.addNode(
        RectNode(
          id: 'r1',
          size: const Size(10, 10),
          fillColor: const Color(0xFF000000),
        )..position = const Offset(0, 0),
        layerIndex: 2,
      ),
      throwsRangeError,
    );
  });

  test('addNode throws when node id already exists in scene', () {
    // INV:INV-G-NODEID-UNIQUE
    final controller = SceneController(
      scene: Scene(
        layers: [
          Layer(
            nodes: [
              RectNode(
                id: 'r1',
                size: const Size(10, 10),
                fillColor: const Color(0xFF000000),
              ),
            ],
          ),
        ],
      ),
    );
    addTearDown(controller.dispose);

    expect(
      () => controller.addNode(
        RectNode(
          id: 'r1',
          size: const Size(20, 20),
          fillColor: const Color(0xFF00FF00),
        ),
      ),
      throwsA(
        isA<ArgumentError>().having(
          (error) => error.message,
          'message',
          contains('Node id must be unique'),
        ),
      ),
    );
  });

  testWidgets(
    'removeNode removes node, clears selection, emits delete action',
    (tester) async {
      final node = RectNode(
        id: 'r1',
        size: const Size(10, 10),
        fillColor: const Color(0xFF000000),
      )..position = const Offset(0, 0);
      final controller = SceneController(
        scene: Scene(
          layers: [
            Layer(nodes: [node]),
          ],
        ),
      );
      addTearDown(controller.dispose);

      controller.handlePointer(
        const PointerSample(
          pointerId: 1,
          position: Offset(0, 0),
          timestampMs: 0,
          phase: PointerPhase.down,
        ),
      );
      controller.handlePointer(
        const PointerSample(
          pointerId: 1,
          position: Offset(0, 0),
          timestampMs: 10,
          phase: PointerPhase.up,
        ),
      );

      expect(controller.selectedNodeIds, contains('r1'));

      final actions = <ActionCommitted>[];
      final sub = controller.actions.listen(actions.add);
      addTearDown(sub.cancel);

      var notifications = 0;
      controller.addListener(() => notifications++);

      controller.removeNode('r1', timestampMs: 123);

      await tester.pump();

      expect(firstNonBackgroundLayer(controller.scene).nodes, isEmpty);
      expect(controller.selectedNodeIds, isNot(contains('r1')));
      expect(actions, hasLength(1));
      expect(actions.single.type, ActionType.delete);
      expect(actions.single.nodeIds, ['r1']);
      expect(actions.single.timestampMs, 123);
      expect(notifications, 1);
    },
  );

  test(
    'removeNode default timestamp starts from 0 without pointer history',
    () {
      final node = RectNode(
        id: 'r1',
        size: const Size(10, 10),
        fillColor: const Color(0xFF000000),
      )..position = const Offset(0, 0);
      final controller = SceneController(
        scene: Scene(
          layers: [
            Layer(nodes: [node]),
          ],
        ),
      );
      addTearDown(controller.dispose);

      final actions = <ActionCommitted>[];
      final sub = controller.actions.listen(actions.add);
      addTearDown(sub.cancel);

      controller.removeNode('r1');

      expect(actions, hasLength(1));
      expect(actions.single.type, ActionType.delete);
      expect(actions.single.timestampMs, 0);
    },
  );

  testWidgets('removeNode is a no-op for unknown id', (tester) async {
    final controller = SceneController(scene: Scene(layers: [Layer()]));
    addTearDown(controller.dispose);

    final actions = <ActionCommitted>[];
    final sub = controller.actions.listen(actions.add);
    addTearDown(sub.cancel);

    var notifications = 0;
    controller.addListener(() => notifications++);

    controller.removeNode('missing', timestampMs: 1);

    await tester.pump();

    expect(actions, isEmpty);
    expect(notifications, 0);
  });

  test('notifySceneChanged drops selection for externally removed nodes', () {
    final node = RectNode(
      id: 'r1',
      size: const Size(10, 10),
      fillColor: const Color(0xFF000000),
    )..position = const Offset(0, 0);
    final controller = SceneController(
      scene: Scene(
        layers: [
          Layer(nodes: [node]),
        ],
      ),
    );
    addTearDown(controller.dispose);

    controller.handlePointer(
      const PointerSample(
        pointerId: 1,
        position: Offset(0, 0),
        timestampMs: 0,
        phase: PointerPhase.down,
      ),
    );
    controller.handlePointer(
      const PointerSample(
        pointerId: 1,
        position: Offset(0, 0),
        timestampMs: 10,
        phase: PointerPhase.up,
      ),
    );

    expect(controller.selectedNodeIds, contains('r1'));

    firstNonBackgroundLayer(controller.scene).nodes.clear();
    controller.notifySceneChanged();

    expect(controller.selectedNodeIds, isEmpty);
  });

  test('notifySceneChanged keeps selection for existing nodes', () {
    final node = RectNode(
      id: 'r1',
      size: const Size(10, 10),
      fillColor: const Color(0xFF000000),
    )..position = const Offset(0, 0);
    final controller = SceneController(
      scene: Scene(
        layers: [
          Layer(nodes: [node]),
        ],
      ),
    );
    addTearDown(controller.dispose);

    controller.handlePointer(
      const PointerSample(
        pointerId: 1,
        position: Offset(0, 0),
        timestampMs: 0,
        phase: PointerPhase.down,
      ),
    );
    controller.handlePointer(
      const PointerSample(
        pointerId: 1,
        position: Offset(0, 0),
        timestampMs: 10,
        phase: PointerPhase.up,
      ),
    );

    controller.notifySceneChanged();

    expect(controller.selectedNodeIds, contains('r1'));
  });

  test('notifySceneChanged rebuilds node id index after external mutation', () {
    final controller = SceneController(scene: Scene(layers: [Layer()]));
    addTearDown(controller.dispose);

    final externalNode = RectNode(
      id: 'external',
      size: const Size(10, 10),
      fillColor: const Color(0xFF000000),
    )..position = const Offset(0, 0);
    firstNonBackgroundLayer(controller.scene).nodes.add(externalNode);

    controller.notifySceneChanged();

    expect(
      () => controller.addNode(
        RectNode(
          id: 'external',
          size: const Size(20, 20),
          fillColor: const Color(0xFF00FF00),
        ),
      ),
      throwsA(
        isA<ArgumentError>().having(
          (error) => error.message,
          'message',
          contains('Node id must be unique'),
        ),
      ),
    );
  });

  testWidgets('setSelection keeps only interactive node ids', (tester) async {
    final visibleSelectable = RectNode(
      id: 'interactive',
      size: const Size(10, 10),
      fillColor: const Color(0xFF000000),
      isSelectable: true,
      isVisible: true,
    )..position = const Offset(10, 0);
    final backgroundNode = RectNode(
      id: 'background',
      size: const Size(10, 10),
      fillColor: const Color(0xFF000000),
      isSelectable: true,
      isVisible: true,
    )..position = const Offset(0, 0);
    final hidden = RectNode(
      id: 'hidden',
      size: const Size(10, 10),
      fillColor: const Color(0xFF000000),
      isSelectable: true,
      isVisible: false,
    )..position = const Offset(20, 0);
    final nonSelectable = RectNode(
      id: 'not-selectable',
      size: const Size(10, 10),
      fillColor: const Color(0xFF000000),
      isSelectable: false,
      isVisible: true,
    )..position = const Offset(30, 0);

    final controller = SceneController(
      scene: Scene(
        layers: [
          Layer(isBackground: true, nodes: [backgroundNode]),
          Layer(nodes: [visibleSelectable, hidden, nonSelectable]),
        ],
      ),
    );
    addTearDown(controller.dispose);

    controller.setSelection(const <NodeId>[
      'background',
      'hidden',
      'not-selectable',
      'unknown',
      'interactive',
      'interactive',
    ]);
    await tester.pump();

    expect(controller.selectedNodeIds, const <NodeId>{'interactive'});
  });

  testWidgets('toggleSelection ignores non-interactive ids', (tester) async {
    final backgroundNode = RectNode(
      id: 'background',
      size: const Size(10, 10),
      fillColor: const Color(0xFF000000),
      isSelectable: true,
      isVisible: true,
    )..position = const Offset(0, 0);
    final hidden = RectNode(
      id: 'hidden',
      size: const Size(10, 10),
      fillColor: const Color(0xFF000000),
      isSelectable: true,
      isVisible: false,
    )..position = const Offset(20, 0);

    final controller = SceneController(
      scene: Scene(
        layers: [
          Layer(isBackground: true, nodes: [backgroundNode]),
          Layer(nodes: [hidden]),
        ],
      ),
    );
    addTearDown(controller.dispose);

    controller.toggleSelection('background');
    controller.toggleSelection('hidden');
    controller.toggleSelection('unknown');
    await tester.pump();

    expect(controller.selectedNodeIds, isEmpty);
  });

  test('notifySceneChanged drops ids that become non-interactive', () {
    final node = RectNode(
      id: 'r1',
      size: const Size(10, 10),
      fillColor: const Color(0xFF000000),
      isSelectable: true,
      isVisible: true,
    )..position = const Offset(0, 0);
    final controller = SceneController(
      scene: Scene(
        layers: [
          Layer(nodes: [node]),
        ],
      ),
    );
    addTearDown(controller.dispose);

    controller.setSelection(const <NodeId>{'r1'});
    expect(controller.selectedNodeIds, const <NodeId>{'r1'});

    node.isSelectable = false;
    controller.notifySceneChanged();

    expect(controller.selectedNodeIds, isEmpty);
  });

  testWidgets('toggleSelection toggles selection for a node', (tester) async {
    final node = RectNode(
      id: 'r1',
      size: const Size(10, 10),
      fillColor: const Color(0xFF000000),
    )..position = const Offset(0, 0);
    final controller = SceneController(
      scene: Scene(
        layers: [
          Layer(nodes: [node]),
        ],
      ),
    );
    addTearDown(controller.dispose);

    var notifications = 0;
    controller.addListener(() => notifications++);

    expect(controller.selectedNodeIds, isEmpty);

    controller.toggleSelection('r1');
    await tester.pump();
    expect(controller.selectedNodeIds, contains('r1'));

    controller.toggleSelection('r1');
    await tester.pump();
    expect(controller.selectedNodeIds, isEmpty);

    expect(notifications, 2);
  });

  testWidgets('selectAll keeps only interactive nodes under strict policy', (
    tester,
  ) async {
    final selectableVisible = RectNode(
      id: 'n1',
      size: const Size(10, 10),
      fillColor: const Color(0xFF000000),
      isSelectable: true,
      isVisible: true,
    )..position = const Offset(0, 0);
    final notSelectableVisible = RectNode(
      id: 'n2',
      size: const Size(10, 10),
      fillColor: const Color(0xFF000000),
      isSelectable: false,
      isVisible: true,
    )..position = const Offset(20, 0);
    final selectableHidden = RectNode(
      id: 'n3',
      size: const Size(10, 10),
      fillColor: const Color(0xFF000000),
      isSelectable: true,
      isVisible: false,
    )..position = const Offset(40, 0);

    final controller = SceneController(
      scene: Scene(
        layers: [
          Layer(nodes: [selectableVisible, notSelectableVisible]),
          Layer(nodes: [selectableHidden]),
        ],
      ),
    );
    addTearDown(controller.dispose);

    controller.selectAll();
    await tester.pump();
    expect(controller.selectedNodeIds, {'n1'});

    controller.selectAll(onlySelectable: false);
    await tester.pump();
    expect(controller.selectedNodeIds, {'n1'});
  });

  testWidgets('selectAll never includes background layer nodes', (
    tester,
  ) async {
    final backgroundNode = RectNode(
      id: 'bg',
      size: const Size(10, 10),
      fillColor: const Color(0xFF000000),
      isSelectable: true,
      isVisible: true,
    )..position = const Offset(0, 0);
    final foregroundNode = RectNode(
      id: 'fg',
      size: const Size(10, 10),
      fillColor: const Color(0xFF000000),
      isSelectable: true,
      isVisible: true,
    )..position = const Offset(10, 0);

    final controller = SceneController(
      scene: Scene(
        layers: [
          Layer(nodes: [backgroundNode], isBackground: true),
          Layer(nodes: [foregroundNode]),
        ],
      ),
    );
    addTearDown(controller.dispose);

    controller.selectAll();
    await tester.pump();
    expect(controller.selectedNodeIds, {'fg'});

    controller.selectAll(onlySelectable: false);
    await tester.pump();
    expect(controller.selectedNodeIds, {'fg'});
  });

  test(
    'moveNode moves node across layers, keeps selection, emits move action',
    () {
      final node = RectNode(
        id: 'r1',
        size: const Size(10, 10),
        fillColor: const Color(0xFF000000),
      )..position = const Offset(0, 0);
      final controller = SceneController(
        scene: Scene(
          layers: [
            Layer(nodes: [node]),
            Layer(),
          ],
        ),
      );
      addTearDown(controller.dispose);

      controller.handlePointer(
        const PointerSample(
          pointerId: 1,
          position: Offset(0, 0),
          timestampMs: 0,
          phase: PointerPhase.down,
        ),
      );
      controller.handlePointer(
        const PointerSample(
          pointerId: 1,
          position: Offset(0, 0),
          timestampMs: 10,
          phase: PointerPhase.up,
        ),
      );

      final actions = <ActionCommitted>[];
      final sub = controller.actions.listen(actions.add);
      addTearDown(sub.cancel);

      controller.moveNode('r1', targetLayerIndex: 2, timestampMs: 77);

      expect(controller.scene.layers[1].nodes, isEmpty);
      expect(controller.scene.layers[2].nodes.single.id, 'r1');
      expect(controller.selectedNodeIds, contains('r1'));

      expect(actions, hasLength(1));
      expect(actions.single.type, ActionType.move);
      expect(actions.single.nodeIds, ['r1']);
      expect(actions.single.timestampMs, 77);
      expect(actions.single.payload, <String, Object?>{
        'sourceLayerIndex': 1,
        'targetLayerIndex': 2,
      });
    },
  );

  test('moveNode throws when target layer index is invalid', () {
    final controller = SceneController(scene: Scene());
    addTearDown(controller.dispose);

    expect(
      () => controller.moveNode('r1', targetLayerIndex: 1),
      throwsRangeError,
    );
  });

  test('moveNode throws when scene layers are externally cleared', () {
    final controller = SceneController(scene: Scene());
    addTearDown(controller.dispose);
    controller.scene.layers.clear();

    expect(
      () => controller.moveNode('r1', targetLayerIndex: 0),
      throwsRangeError,
    );
  });

  test('moveNode default timestamp follows pointer monotonic timeline', () {
    final node = RectNode(
      id: 'r1',
      size: const Size(10, 10),
      fillColor: const Color(0xFF000000),
    )..position = const Offset(0, 0);
    final controller = SceneController(
      scene: Scene(
        layers: [
          Layer(nodes: [node]),
          Layer(),
        ],
      ),
    );
    addTearDown(controller.dispose);

    final actions = <ActionCommitted>[];
    final sub = controller.actions.listen(actions.add);
    addTearDown(sub.cancel);

    controller.handlePointer(
      const PointerSample(
        pointerId: 1,
        position: Offset(0, 0),
        timestampMs: 0,
        phase: PointerPhase.down,
      ),
    );
    controller.handlePointer(
      const PointerSample(
        pointerId: 1,
        position: Offset(0, 0),
        timestampMs: 10,
        phase: PointerPhase.up,
      ),
    );

    controller.moveNode('r1', targetLayerIndex: 2);

    expect(actions, hasLength(1));
    expect(actions.single.type, ActionType.move);
    expect(actions.single.timestampMs, 11);
  });

  test('moveNode throws for invalid target layer index', () {
    final controller = SceneController(scene: Scene(layers: [Layer()]));
    addTearDown(controller.dispose);

    expect(
      () => controller.moveNode('r1', targetLayerIndex: 2, timestampMs: 0),
      throwsRangeError,
    );
  });

  test('findNode and getNode locate nodes in layers', () {
    final nodeA = RectNode(
      id: 'a',
      size: const Size(10, 10),
      fillColor: const Color(0xFF000000),
    );
    final nodeB = RectNode(
      id: 'b',
      size: const Size(10, 10),
      fillColor: const Color(0xFF000000),
    );
    final controller = SceneController(
      scene: Scene(
        layers: [
          Layer(nodes: [nodeA]),
          Layer(nodes: [nodeB]),
        ],
      ),
    );
    addTearDown(controller.dispose);

    final foundA = controller.findNode('a');
    expect(foundA, isNotNull);
    expect(foundA!.layerIndex, 1);
    expect(foundA.nodeIndex, 0);
    expect(foundA.node.id, 'a');

    final foundB = controller.findNode('b');
    expect(foundB, isNotNull);
    expect(foundB!.layerIndex, 2);
    expect(foundB.nodeIndex, 0);
    expect(controller.getNode('b'), same(nodeB));
    expect(controller.getNode('missing'), isNull);
  });

  testWidgets('mutateStructural uses notifySceneChanged', (tester) async {
    final controller = SceneController(scene: Scene(layers: [Layer()]));
    addTearDown(controller.dispose);

    var notifications = 0;
    controller.addListener(() => notifications += 1);
    final sceneRevisionBefore = controller.debugSceneRevision;

    controller.mutateStructural((scene) {
      firstNonBackgroundLayer(scene).nodes.add(
        RectNode(
          id: 'r1',
          size: const Size(10, 10),
          fillColor: const Color(0xFF000000),
        )..position = const Offset(0, 0),
      );
    });

    await tester.pump();

    expect(firstNonBackgroundLayer(controller.scene).nodes.single.id, 'r1');
    expect(notifications, greaterThan(0));
    expect(controller.debugSceneRevision, greaterThan(sceneRevisionBefore));
  });

  testWidgets('mutate geometry-only schedules repaint', (tester) async {
    final node = RectNode(
      id: 'r1',
      size: const Size(10, 10),
      fillColor: const Color(0xFF000000),
    )..position = const Offset(0, 0);
    final controller = SceneController(
      scene: Scene(
        layers: [
          Layer(nodes: [node]),
        ],
      ),
    );
    addTearDown(controller.dispose);

    var notifications = 0;
    controller.addListener(() => notifications += 1);
    final sceneRevisionBefore = controller.debugSceneRevision;

    controller.mutate((scene) {
      final rect = firstNonBackgroundLayer(scene).nodes.single as RectNode;
      rect.position = const Offset(10, 0);
    });
    expect(tester.binding.hasScheduledFrame, isTrue);

    await tester.pump();
    expect(notifications, greaterThan(0));
    expect(controller.debugSceneRevision, sceneRevisionBefore);
  });

  test('mutate asserts on structural changes', () {
    final controller = SceneController(scene: Scene(layers: [Layer()]));
    addTearDown(controller.dispose);

    expect(
      () => controller.mutate((scene) {
        firstNonBackgroundLayer(scene).nodes.add(
          RectNode(
            id: 'r1',
            size: const Size(10, 10),
            fillColor: const Color(0xFF000000),
          ),
        );
      }),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('Use mutateStructural(...)'),
        ),
      ),
    );
  });
}
