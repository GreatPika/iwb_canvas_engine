import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine/src/controller/commands/scene_commands.dart';
import 'package:iwb_canvas_engine/src/controller/scene_controller.dart';
import 'package:iwb_canvas_engine/src/controller/scene_writer.dart';
import 'package:iwb_canvas_engine/src/controller/txn_context.dart';
import 'package:iwb_canvas_engine/src/controller/internal/signal_event.dart';
import 'package:iwb_canvas_engine/src/core/scene.dart';

import '../../utils/scene_invariants.dart';

// INV:INV-ENG-TXN-ATOMIC-COMMIT
// INV:INV-ENG-SIGNALS-AFTER-COMMIT

SceneControllerCore buildController() {
  return SceneControllerCore(
    initialSnapshot: SceneSnapshot(
      layers: <ContentLayerSnapshot>[
        ContentLayerSnapshot(
          id: 'layer-auto-0',
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
  test(
    'writeClearScene emits scene.cleared on structural clear-side effect',
    () {
      final bufferedSignals = <BufferedSignal>[];
      final ctx = TxnContext(
        baseScene: Scene(
          layers: <ContentLayer>[ContentLayer(id: 'layer-auto-1')],
        ),
        workingSelection: <NodeId>{},
        baseAllNodeIds: <NodeId>{},
        nodeIdSeed: 0,
        nextInstanceRevision: 1,
      );
      T writeRunner<T>(T Function(SceneWriteTxn writer) fn) {
        final writer = SceneWriter(ctx, txnSignalSink: bufferedSignals.add);
        return fn(writer);
      }

      final commands = SceneCommands(writeRunner);

      final removedCount = commands.writeClearScene();

      expect(removedCount, 0);
      expect(bufferedSignals, hasLength(1));
      expect(bufferedSignals.single.type, 'scene.cleared');
      expect(bufferedSignals.single.nodeIds, isEmpty);
    },
  );

  test('writeClearScene no-op does not emit scene.cleared', () {
    final bufferedSignals = <BufferedSignal>[];
    final ctx = TxnContext(
      baseScene: Scene(
        backgroundLayer: BackgroundLayer(),
        layers: <ContentLayer>[ContentLayer(id: 'layer-auto-2')],
      ),
      workingSelection: <NodeId>{},
      baseAllNodeIds: <NodeId>{},
      nodeIdSeed: 0,
      nextInstanceRevision: 1,
    );
    T writeRunner<T>(T Function(SceneWriteTxn writer) fn) {
      final writer = SceneWriter(ctx, txnSignalSink: bufferedSignals.add);
      return fn(writer);
    }

    final commands = SceneCommands(writeRunner);

    final removedCount = commands.writeClearScene();

    expect(removedCount, 0);
    expect(bufferedSignals, isEmpty);
  });

  test('scene commands route structural updates through write', () async {
    final controller = buildController();
    addTearDown(controller.dispose);

    var notifications = 0;
    controller.addListener(() {
      notifications = notifications + 1;
    });

    final created = controller.commands.writeAddNode(
      RectNodeSpec(id: 'cmd-added', size: const Size(6, 6)),
    );
    await pumpEventQueue();

    expect(created, 'cmd-added');
    expect(controller.snapshot.layers, hasLength(1));
    expect(controller.snapshot.layers.first.nodes, hasLength(2));
    expect(controller.snapshot.layers.first.nodes.last.id, 'cmd-added');
    expect(controller.structuralRevision, 1);
    expect(notifications, 1);
    assertControllerInvariants(controller);
  });

  test('add node without layerIndex does not create extra layers', () async {
    final controller = buildController();
    addTearDown(controller.dispose);

    for (var i = 0; i < 100; i++) {
      controller.commands.writeAddNode(
        RectNodeSpec(id: 'auto-$i', size: const Size(6, 6)),
      );
    }
    await pumpEventQueue();

    expect(controller.snapshot.layers, hasLength(1));
    expect(controller.snapshot.layers.first.nodes, hasLength(101));
    assertControllerInvariants(controller);
  });

  test('add node with unknown layerId throws ArgumentError', () async {
    final controller = buildController();
    addTearDown(controller.dispose);

    expect(
      () => controller.commands.writeAddNode(
        RectNodeSpec(id: 'bad-index', size: const Size(8, 8)),
        layerId: 'missing-layer',
      ),
      throwsArgumentError,
    );
    await pumpEventQueue();
    assertControllerInvariants(controller);
  });

  test(
    'scene commands handle missing patch/delete and selection commands',
    () async {
      final controller = buildController();
      addTearDown(controller.dispose);

      final signalTypes = <String>[];
      final sub = controller.signals.listen((signal) {
        signalTypes.add(signal.type);
      });
      addTearDown(sub.cancel);

      final patchMissing = controller.commands.writePatchNode(
        const RectNodePatch(
          id: 'missing',
          strokeWidth: PatchField<double>.value(2),
        ),
      );
      final patchExisting = controller.commands.writePatchNode(
        const RectNodePatch(
          id: 'base',
          strokeWidth: PatchField<double>.value(3),
        ),
      );
      final deleteMissing = controller.commands.writeDeleteNode('missing');
      final deleteExisting = controller.commands.writeDeleteNode('base');
      controller.commands.writeAddNode(
        RectNodeSpec(id: 'selected', size: const Size(8, 8)),
      );

      controller.commands.writeSelectionReplace(const <NodeId>{'selected'});
      controller.commands.writeSelectionToggle('selected');
      await pumpEventQueue();

      expect(patchMissing, isFalse);
      expect(patchExisting, isTrue);
      expect(deleteMissing, isFalse);
      expect(deleteExisting, isTrue);
      expect(
        signalTypes,
        containsAll(<String>[
          'node.updated',
          'node.removed',
          'selection.replaced',
          'selection.toggled',
        ]),
      );
      assertControllerInvariants(controller);
    },
  );

  test(
    'scene commands cover selection transform/delete/clear helpers',
    () async {
      final controller = buildController();
      addTearDown(controller.dispose);

      final signalTypes = <String>[];
      final sub = controller.signals.listen((signal) {
        signalTypes.add(signal.type);
      });
      addTearDown(sub.cancel);

      controller.commands.writeSelectionReplace(const <NodeId>{'base'});
      controller.commands.writeSelectionClear();
      await pumpEventQueue();
      expect(signalTypes, contains('selection.cleared'));

      final selectNone = controller.commands.writeSelectionSelectAll(
        onlySelectable: false,
      );
      await pumpEventQueue();
      expect(selectNone, 1);
      expect(signalTypes, contains('selection.all'));
      expect(controller.selectedNodeIds, const <NodeId>{'base'});

      final transformed = controller.commands.writeSelectionTransform(
        Transform2D.translation(const Offset(4, 6)),
      );
      await pumpEventQueue();
      expect(transformed, 1);
      expect(signalTypes, contains('selection.transformed'));

      final deleted = controller.commands.writeDeleteSelection();
      await pumpEventQueue();
      expect(deleted, 1);
      expect(signalTypes, contains('selection.deleted'));

      controller.commands.writeAddNode(
        RectNodeSpec(id: 'temp', size: const Size(4, 4)),
      );
      final cleared = controller.commands.writeClearScene();
      await pumpEventQueue();
      expect(cleared, 1);
      expect(signalTypes, contains('scene.cleared'));

      controller.commands.writeBackgroundColorSet(const Color(0xFFAA5500));
      controller.commands.writeGridEnabledSet(true);
      controller.commands.writeGridCellSizeSet(42);
      controller.commands.writeCameraOffsetSet(const Offset(10, -4));
      await pumpEventQueue();
      expect(
        signalTypes,
        containsAll(<String>[
          'background.updated',
          'grid.enabled.updated',
          'grid.cell.updated',
          'camera.updated',
        ]),
      );
      assertControllerInvariants(controller);
    },
  );

  test('selection clear on empty emits no signal', () async {
    final controller = buildController();
    addTearDown(controller.dispose);

    final signalTypes = <String>[];
    final sub = controller.signals.listen((signal) {
      signalTypes.add(signal.type);
    });
    addTearDown(sub.cancel);

    controller.commands.writeSelectionClear();
    await pumpEventQueue();

    expect(signalTypes, isNot(contains('selection.cleared')));
    assertControllerInvariants(controller);
  });

  test(
    'selection selectAll emits signal when selection changes to empty',
    () async {
      final controller = buildController();
      addTearDown(controller.dispose);

      controller.commands.writeSelectionReplace(const <NodeId>{'base'});
      await pumpEventQueue();
      expect(controller.selectedNodeIds, const <NodeId>{'base'});

      controller.commands.writePatchNode(
        const RectNodePatch(
          id: 'base',
          common: CommonNodePatch(isSelectable: PatchField<bool>.value(false)),
        ),
      );
      await pumpEventQueue();
      expect(controller.selectedNodeIds, const <NodeId>{'base'});

      var selectionAllSignals = 0;
      final sub = controller.signals.listen((signal) {
        if (signal.type == 'selection.all') {
          selectionAllSignals = selectionAllSignals + 1;
        }
      });
      addTearDown(sub.cancel);

      final selectedCount = controller.commands.writeSelectionSelectAll();
      await pumpEventQueue();

      expect(selectedCount, 0);
      expect(selectionAllSignals, 1);
      expect(controller.selectedNodeIds, isEmpty);
      assertControllerInvariants(controller);
    },
  );

  test('selection replace same set emits no signal', () async {
    final controller = buildController();
    addTearDown(controller.dispose);

    final signalTypes = <String>[];
    final sub = controller.signals.listen((signal) {
      signalTypes.add(signal.type);
    });
    addTearDown(sub.cancel);

    controller.commands.writeSelectionReplace(const <NodeId>{'base'});
    await pumpEventQueue();
    expect(signalTypes.where((type) => type == 'selection.replaced').length, 1);

    controller.commands.writeSelectionReplace(const <NodeId>{'base'});
    await pumpEventQueue();
    expect(signalTypes.where((type) => type == 'selection.replaced').length, 1);
    assertControllerInvariants(controller);
  });

  test('selection signal ids equal committed selection', () async {
    final controller = buildController();
    addTearDown(controller.dispose);

    List<NodeId>? replacedIds;
    final sub = controller.signals.listen((signal) {
      if (signal.type == 'selection.replaced') {
        replacedIds = signal.nodeIds;
      }
    });
    addTearDown(sub.cancel);

    controller.commands.writeSelectionReplace(const <NodeId>{
      'base',
      'missing',
    });
    await pumpEventQueue();

    expect(replacedIds, isNotNull);
    expect(replacedIds, const <NodeId>['base']);
    expect(controller.selectedNodeIds, const <NodeId>{'base'});
    expect(controller.selectedNodeIds, equals(replacedIds!.toSet()));
    assertControllerInvariants(controller);
  });

  test('selection signal ids are sorted', () async {
    final controller = buildController();
    addTearDown(controller.dispose);

    controller.commands.writeAddNode(
      RectNodeSpec(id: 'z-node', size: const Size(8, 8)),
    );
    controller.commands.writeAddNode(
      RectNodeSpec(id: 'a-node', size: const Size(8, 8)),
    );
    await pumpEventQueue();

    List<NodeId>? replacedIds;
    final sub = controller.signals.listen((signal) {
      if (signal.type == 'selection.replaced') {
        replacedIds = signal.nodeIds;
      }
    });
    addTearDown(sub.cancel);

    controller.commands.writeSelectionReplace(const <NodeId>{
      'z-node',
      'base',
      'a-node',
    });
    await pumpEventQueue();

    expect(replacedIds, const <NodeId>['a-node', 'base', 'z-node']);
    expect(controller.selectedNodeIds, equals(replacedIds!.toSet()));
    assertControllerInvariants(controller);
  });

  test('selection replace filters invisible or background nodes', () async {
    final controller = SceneControllerCore(
      initialSnapshot: SceneSnapshot(
        backgroundLayer: BackgroundLayerSnapshot(
          nodes: const <NodeSnapshot>[
            RectNodeSnapshot(id: 'bg', size: Size(20, 10)),
          ],
        ),
        layers: <ContentLayerSnapshot>[
          ContentLayerSnapshot(
            id: 'layer-auto-1',
            nodes: const <NodeSnapshot>[
              RectNodeSnapshot(id: 'visible', size: Size(20, 10)),
              RectNodeSnapshot(
                id: 'hidden',
                size: Size(20, 10),
                isVisible: false,
              ),
            ],
          ),
        ],
      ),
    );
    addTearDown(controller.dispose);

    List<NodeId>? replacedIds;
    final sub = controller.signals.listen((signal) {
      if (signal.type == 'selection.replaced') {
        replacedIds = signal.nodeIds;
      }
    });
    addTearDown(sub.cancel);

    controller.commands.writeSelectionReplace(const <NodeId>{
      'visible',
      'hidden',
      'bg',
      'missing',
    });
    await pumpEventQueue();

    expect(replacedIds, const <NodeId>['visible']);
    expect(controller.selectedNodeIds, const <NodeId>{'visible'});
    assertControllerInvariants(controller);
  });

  test(
    'selection replace only missing ids emits no signal and keeps selection',
    () async {
      final controller = buildController();
      addTearDown(controller.dispose);

      var replacedSignals = 0;
      final sub = controller.signals.listen((signal) {
        if (signal.type == 'selection.replaced') {
          replacedSignals = replacedSignals + 1;
        }
      });
      addTearDown(sub.cancel);

      controller.commands.writeSelectionReplace(const <NodeId>{'base'});
      await pumpEventQueue();
      expect(controller.selectedNodeIds, const <NodeId>{'base'});
      expect(replacedSignals, 1);

      controller.commands.writeSelectionReplace(const <NodeId>{'missing'});
      await pumpEventQueue();
      expect(controller.selectedNodeIds, const <NodeId>{'base'});
      expect(replacedSignals, 1);
      assertControllerInvariants(controller);
    },
  );

  test('selection toggle missing id emits no signal', () async {
    final controller = buildController();
    addTearDown(controller.dispose);

    final signalTypes = <String>[];
    final sub = controller.signals.listen((signal) {
      signalTypes.add(signal.type);
    });
    addTearDown(sub.cancel);

    controller.commands.writeSelectionToggle('missing');
    await pumpEventQueue();

    expect(signalTypes, isNot(contains('selection.toggled')));
    expect(controller.selectedNodeIds, isEmpty);
    assertControllerInvariants(controller);
  });

  test(
    'no-op background/grid/camera setters emit no signal and keep commit revision',
    () async {
      final controller = buildController();
      addTearDown(controller.dispose);

      final initialRevision = controller.debugCommitRevision;
      final snapshot = controller.snapshot;
      final signalTypes = <String>[];
      final sub = controller.signals.listen((signal) {
        signalTypes.add(signal.type);
      });
      addTearDown(sub.cancel);

      controller.commands.writeBackgroundColorSet(snapshot.background.color);
      controller.commands.writeGridEnabledSet(
        snapshot.background.grid.isEnabled,
      );
      controller.commands.writeGridCellSizeSet(
        snapshot.background.grid.cellSize,
      );
      controller.commands.writeCameraOffsetSet(snapshot.camera.offset);
      await pumpEventQueue();

      final trackedSignalTypes = signalTypes
          .where(
            (type) =>
                type == 'background.updated' ||
                type == 'grid.enabled.updated' ||
                type == 'grid.cell.updated' ||
                type == 'camera.updated',
          )
          .toList(growable: false);
      expect(trackedSignalTypes, isEmpty);
      expect(controller.debugCommitRevision, initialRevision);
      assertControllerInvariants(controller);
    },
  );

  test(
    'changed background/grid/camera setters emit signals and bump commit revision',
    () async {
      final controller = buildController();
      addTearDown(controller.dispose);

      final initialRevision = controller.debugCommitRevision;
      final signalTypes = <String>[];
      final sub = controller.signals.listen((signal) {
        signalTypes.add(signal.type);
      });
      addTearDown(sub.cancel);

      controller.commands.writeBackgroundColorSet(const Color(0xFFAA5500));
      controller.commands.writeGridEnabledSet(true);
      controller.commands.writeGridCellSizeSet(42);
      controller.commands.writeCameraOffsetSet(const Offset(10, -4));
      await pumpEventQueue();

      expect(
        signalTypes,
        containsAll(<String>[
          'background.updated',
          'grid.enabled.updated',
          'grid.cell.updated',
          'camera.updated',
        ]),
      );
      expect(controller.debugCommitRevision, initialRevision + 4);
      assertControllerInvariants(controller);
    },
  );

  test('grid cell size non positive throws ArgumentError', () async {
    final controller = buildController();
    addTearDown(controller.dispose);

    expect(
      () => controller.commands.writeGridCellSizeSet(0),
      throwsArgumentError,
    );
    await pumpEventQueue();
    assertControllerInvariants(controller);
  });
}
