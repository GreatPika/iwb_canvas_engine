import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine/src/controller/scene_controller.dart';

// INV:INV-ENG-TXN-WRITER-LIFETIME

void main() {
  SceneSnapshot twoRectSnapshot() {
    return SceneSnapshot(
      layers: <ContentLayerSnapshot>[
        ContentLayerSnapshot(
          id: 'layer-auto-0',
          nodes: <NodeSnapshot>[
            RectNodeSnapshot(id: 'r1', size: Size(10, 10)),
            RectNodeSnapshot(id: 'r2', size: Size(12, 12)),
          ],
        ),
      ],
    );
  }

  test('nested write throws and does not commit', () {
    final controller = SceneControllerCore(initialSnapshot: twoRectSnapshot());
    addTearDown(controller.dispose);

    expect(
      () => controller.write<void>((_) {
        controller.write<void>((_) {});
      }),
      throwsStateError,
    );
  });

  test('pre-context failure does not lock future writes', () {
    final controller = SceneControllerCore(initialSnapshot: twoRectSnapshot());
    addTearDown(controller.dispose);

    controller.debug.beforeTxnContextCreateHook = () {
      throw StateError('forced pre-context failure');
    };

    expect(() => controller.write<void>((_) {}), throwsStateError);

    controller.debug.beforeTxnContextCreateHook = null;
    expect(
      () => controller.write<void>((writer) {
        writer.writeSelectionReplace(const <NodeId>{'r1'});
      }),
      returnsNormally,
    );
    expect(controller.selectedNodeIds, const <NodeId>{'r1'});
    expect(controller.debug.currentCommitRevision, 1);
  });

  test(
    'async write callback fails fast and rolls back state/effects',
    () async {
      final controller = SceneControllerCore(
        initialSnapshot: twoRectSnapshot(),
      );
      addTearDown(controller.dispose);

      final beforeCommit = controller.debug.currentCommitRevision;
      final beforeSelection = controller.selectedNodeIds;

      final emitted = <String>[];
      final sub = controller.signals.listen((signal) {
        emitted.add(signal.type);
      });
      addTearDown(sub.cancel);

      var notifications = 0;
      controller.addListener(() {
        notifications = notifications + 1;
      });

      expect(
        () => controller.write<Future<void>>((writer) async {
          writer.writeSelectionReplace(const <NodeId>{'r1'});
          writer.writeSignalEnqueue(type: 'must.rollback');
        }),
        throwsStateError,
      );
      await pumpEventQueue(times: 2);

      expect(controller.debug.currentCommitRevision, beforeCommit);
      expect(controller.selectedNodeIds, beforeSelection);
      expect(emitted, isEmpty);
      expect(notifications, 0);
    },
  );

  test(
    'stale txn handle after commit throws and does not emit effects',
    () async {
      final controller = SceneControllerCore(
        initialSnapshot: twoRectSnapshot(),
      );
      addTearDown(controller.dispose);

      final emitted = <String>[];
      final sub = controller.signals.listen((signal) {
        emitted.add(signal.type);
      });
      addTearDown(sub.cancel);

      var notifications = 0;
      controller.addListener(() {
        notifications = notifications + 1;
      });

      late final SceneWriteTxn staleTxn;
      controller.write<void>((writer) {
        staleTxn = writer;
        writer.writeSelectionReplace(const <NodeId>{'r1'});
        writer.writeSignalEnqueue(type: 'initial.commit');
      });
      await pumpEventQueue(times: 2);

      final beforeCommit = controller.debug.currentCommitRevision;
      final beforeEpoch = controller.controllerEpoch;
      final beforeStructural = controller.structuralRevision;
      final beforeBounds = controller.boundsRevision;
      final beforeVisual = controller.visualRevision;
      final beforeSelection = controller.selectedNodeIds;
      final beforeSnapshot = controller.snapshot;

      expect(
        () => staleTxn.writeSelectionReplace(const <NodeId>{'r2'}),
        throwsStateError,
      );
      expect(
        () => staleTxn.writeSignalEnqueue(type: 'stale.signal'),
        throwsStateError,
      );
      await pumpEventQueue(times: 2);

      expect(controller.debug.currentCommitRevision, beforeCommit);
      expect(controller.controllerEpoch, beforeEpoch);
      expect(controller.structuralRevision, beforeStructural);
      expect(controller.boundsRevision, beforeBounds);
      expect(controller.visualRevision, beforeVisual);
      expect(controller.selectedNodeIds, beforeSelection);
      expect(controller.snapshot.layers.length, beforeSnapshot.layers.length);
      expect(
        controller.snapshot.layers.first.nodes.map((node) => node.id).toList(),
        beforeSnapshot.layers.first.nodes.map((node) => node.id).toList(),
      );
      expect(emitted, const <String>['initial.commit']);
      expect(notifications, 1);
    },
  );

  test(
    'stale txn handle after rollback throws and keeps state unchanged',
    () async {
      final controller = SceneControllerCore(
        initialSnapshot: twoRectSnapshot(),
      );
      addTearDown(controller.dispose);

      final beforeCommit = controller.debug.currentCommitRevision;
      final beforeEpoch = controller.controllerEpoch;
      final beforeStructural = controller.structuralRevision;
      final beforeBounds = controller.boundsRevision;
      final beforeVisual = controller.visualRevision;
      final beforeSelection = controller.selectedNodeIds;
      final beforeSnapshot = controller.snapshot;

      final emitted = <String>[];
      final sub = controller.signals.listen((signal) {
        emitted.add(signal.type);
      });
      addTearDown(sub.cancel);

      var notifications = 0;
      controller.addListener(() {
        notifications = notifications + 1;
      });

      late final SceneWriteTxn staleTxn;
      expect(
        () => controller.write<void>((writer) {
          staleTxn = writer;
          writer.writeSelectionReplace(const <NodeId>{'r1'});
          writer.writeSignalEnqueue(type: 'will.rollback');
          throw StateError('rollback');
        }),
        throwsStateError,
      );

      expect(
        () => staleTxn.writeSelectionReplace(const <NodeId>{'r2'}),
        throwsStateError,
      );
      expect(() => staleTxn.writeNodeErase('r1'), throwsStateError);
      await pumpEventQueue(times: 2);

      expect(controller.debug.currentCommitRevision, beforeCommit);
      expect(controller.controllerEpoch, beforeEpoch);
      expect(controller.structuralRevision, beforeStructural);
      expect(controller.boundsRevision, beforeBounds);
      expect(controller.visualRevision, beforeVisual);
      expect(controller.selectedNodeIds, beforeSelection);
      expect(controller.snapshot.layers.length, beforeSnapshot.layers.length);
      expect(
        controller.snapshot.layers.first.nodes.map((node) => node.id).toList(),
        beforeSnapshot.layers.first.nodes.map((node) => node.id).toList(),
      );
      expect(emitted, isEmpty);
      expect(notifications, 0);
    },
  );

  test('normal write still works after stale txn handle rejection', () async {
    final controller = SceneControllerCore(initialSnapshot: twoRectSnapshot());
    addTearDown(controller.dispose);

    final emitted = <String>[];
    final sub = controller.signals.listen((signal) {
      emitted.add(signal.type);
    });
    addTearDown(sub.cancel);

    late final SceneWriteTxn staleTxn;
    controller.write<void>((writer) {
      staleTxn = writer;
      writer.writeSignalEnqueue(type: 'first');
    });

    expect(() => staleTxn.writeSignalEnqueue(type: 'stale'), throwsStateError);

    controller.write<void>((writer) {
      writer.writeSignalEnqueue(type: 'follow-up');
    });
    await pumpEventQueue(times: 2);

    expect(emitted, const <String>['first', 'follow-up']);
    expect(controller.debug.currentCommitRevision, 2);
  });

  test(
    'controller commit handles 1000 mixed selection operations and stays correct',
    () {
      final controller = SceneControllerCore(
        initialSnapshot: SceneSnapshot(
          layers: <ContentLayerSnapshot>[
            ContentLayerSnapshot(
              id: 'layer-auto-1',
              nodes: <NodeSnapshot>[
                for (var i = 0; i < 1000; i++)
                  RectNodeSnapshot(id: 'n$i', size: const Size(10, 10)),
              ],
            ),
          ],
        ),
      );
      addTearDown(controller.dispose);

      final expectedSelection = <NodeId>{};
      controller.write<void>((writer) {
        for (var i = 0; i < 1000; i++) {
          final id = 'n$i';
          switch (i % 3) {
            case 0:
              writer.writeSelectionToggle(id);
              if (!expectedSelection.remove(id)) {
                expectedSelection.add(id);
              }
              break;
            case 1:
              writer.writeSelectionReplace(<NodeId>{id});
              expectedSelection
                ..clear()
                ..add(id);
              break;
            case 2:
              expect(writer.writeNodeErase(id), isTrue);
              expectedSelection.remove(id);
              break;
          }
        }
      });

      final remainingNodeIds = <NodeId>{
        for (final layer in controller.snapshot.layers)
          for (final node in layer.nodes) node.id,
      };
      expect(controller.selectedNodeIds, expectedSelection);
      expect(remainingNodeIds.containsAll(controller.selectedNodeIds), isTrue);
      expect(controller.debug.lastChangeSet.selectionChanged, isTrue);
      expect(controller.debug.lastChangeSet.structuralChanged, isTrue);
      expect(controller.debug.currentCommitRevision, 1);
    },
  );

  test('commit normalization marks selection/grid changes when normalized', () {
    final controller = SceneControllerCore(initialSnapshot: twoRectSnapshot());
    addTearDown(controller.dispose);

    controller.write<void>((writer) {
      writer.writeSelectionReplace(const <NodeId>{'r1'});
      writer.writeNodePatch(
        RectNodePatch(
          id: 'r1',
          common: CommonNodePatch(isVisible: PatchField<bool>.value(false)),
        ),
      );
      writer.writeGridEnable(true);
      writer.writeGridCellSize(0.1);
    });

    expect(controller.selectedNodeIds, isEmpty);
    expect(controller.snapshot.background.grid.cellSize, 1.0);
    expect(controller.debug.lastChangeSet.selectionChanged, isTrue);
    expect(controller.debug.lastChangeSet.gridChanged, isTrue);
  });
}
