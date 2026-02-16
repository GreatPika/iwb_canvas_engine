import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine/src/controller/scene_controller.dart';
import 'package:iwb_canvas_engine/src/controller/internal/signal_event.dart';

// INV:INV-ENG-SIGNALS-AFTER-COMMIT
// INV:INV-ENG-TXN-WRITER-LIFETIME
// INV:INV-ENG-DISPOSE-FAIL-FAST

void main() {
  SceneSnapshot twoRectSnapshot() {
    return SceneSnapshot(
      layers: <ContentLayerSnapshot>[
        ContentLayerSnapshot(
          nodes: <NodeSnapshot>[
            const RectNodeSnapshot(id: 'r1', size: Size(10, 10)),
            const RectNodeSnapshot(id: 'r2', size: Size(12, 12)),
          ],
        ),
      ],
    );
  }

  test('signals are emitted only after successful commit', () async {
    final controller = SceneControllerCore(initialSnapshot: twoRectSnapshot());
    addTearDown(controller.dispose);

    final emitted = <String>[];
    final sub = controller.signals.listen((signal) {
      emitted.add(signal.type);
    });
    addTearDown(sub.cancel);

    expect(
      () => controller.write<void>((writer) {
        writer.writeSignalEnqueue(type: 'will.rollback');
        throw StateError('fail');
      }),
      throwsStateError,
    );

    expect(emitted, isEmpty);

    controller.write<void>((writer) {
      writer.writeSignalEnqueue(type: 'committed');
    });
    await pumpEventQueue();

    expect(emitted, <String>['committed']);
  });

  test(
    'signals are delivered before repaint listeners for same commit',
    () async {
      final controller = SceneControllerCore(
        initialSnapshot: twoRectSnapshot(),
      );
      addTearDown(controller.dispose);

      final observed = <String>[];
      final sub = controller.signals.listen((_) {
        observed.add('signal');
      });
      addTearDown(sub.cancel);
      controller.addListener(() {
        observed.add('notify');
      });

      controller.write<void>((writer) {
        writer.writeSelectionReplace(const <NodeId>{'r1'});
        writer.writeSignalEnqueue(type: 'ordered');
      });
      await pumpEventQueue(times: 2);

      expect(observed, const <String>['signal', 'notify']);
    },
  );

  test(
    'signal listener observes committed state and can trigger follow-up write',
    () async {
      final controller = SceneControllerCore(
        initialSnapshot: twoRectSnapshot(),
      );
      addTearDown(controller.dispose);

      final observed =
          <({String type, int signalRevision, int storeRevision})>[];
      Object? nestedWriteError;
      final sub = controller.signals.listen((signal) {
        observed.add((
          type: signal.type,
          signalRevision: signal.commitRevision,
          storeRevision: controller.debugCommitRevision,
        ));
        if (signal.type == 'first') {
          try {
            controller.write<void>((writer) {
              writer.writeSignalEnqueue(type: 'second');
            });
          } catch (error) {
            nestedWriteError = error;
          }
        }
      });
      addTearDown(sub.cancel);

      controller.write<void>((writer) {
        writer.writeSignalEnqueue(type: 'first');
      });
      await pumpEventQueue(times: 2);

      expect(nestedWriteError, isNull);
      expect(
        observed.map((entry) => entry.type).toList(growable: false),
        const <String>['first', 'second'],
      );
      expect(
        observed
            .map((entry) => entry.signalRevision == entry.storeRevision)
            .toList(growable: false),
        everyElement(isTrue),
      );
      expect(controller.debugCommitRevision, 2);
    },
  );

  test(
    'change listener can trigger follow-up write without nested write error',
    () async {
      final controller = SceneControllerCore(
        initialSnapshot: twoRectSnapshot(),
      );
      addTearDown(controller.dispose);

      Object? nestedWriteError;
      var listenerCalls = 0;
      controller.addListener(() {
        listenerCalls = listenerCalls + 1;
        if (listenerCalls != 1) return;
        try {
          controller.write<void>((writer) {
            writer.writeSelectionReplace(const <NodeId>{'r2'});
          });
        } catch (error) {
          nestedWriteError = error;
        }
      });

      controller.write<void>((writer) {
        writer.writeSelectionReplace(const <NodeId>{'r1'});
      });
      await pumpEventQueue(times: 2);

      expect(nestedWriteError, isNull);
      expect(listenerCalls, 2);
      expect(controller.selectedNodeIds, const <NodeId>{'r2'});
    },
  );

  test('committed signals expose immutable payload and nodeIds', () async {
    // INV:INV-ENG-EVENTS-IMMUTABLE
    final controller = SceneControllerCore(initialSnapshot: twoRectSnapshot());
    addTearDown(controller.dispose);

    final emitted = <CommittedSignal>[];
    final sub = controller.signals.listen(emitted.add);
    addTearDown(sub.cancel);

    final nodeIds = <NodeId>['r1'];
    final payload = <String, Object?>{
      'nested': <String, Object?>{'value': 1},
      'items': <Object?>[1, 2],
    };
    controller.write<void>((writer) {
      writer.writeSignalEnqueue(
        type: 'immutable',
        nodeIds: nodeIds,
        payload: payload,
      );
    });

    nodeIds.add('r2');
    (payload['nested'] as Map<String, Object?>)['value'] = 99;
    (payload['items'] as List<Object?>).add(3);
    await pumpEventQueue();

    final signal = emitted.single;
    expect(signal.nodeIds, const <NodeId>['r1']);
    expect((signal.payload!['nested']! as Map<String, Object?>)['value'], 1);
    expect(signal.payload!['items'], const <Object?>[1, 2]);
    expect(() => signal.nodeIds.add('x'), throwsUnsupportedError);
    expect(
      () => (signal.payload!['nested'] as Map<Object?, Object?>)['value'] = 7,
      throwsUnsupportedError,
    );
  });

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

      final beforeCommit = controller.debugCommitRevision;
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

      expect(controller.debugCommitRevision, beforeCommit);
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

      final beforeCommit = controller.debugCommitRevision;
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

      expect(controller.debugCommitRevision, beforeCommit);
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
    expect(controller.debugCommitRevision, 2);
  });

  test(
    'write after dispose throws and keeps state/effects unchanged',
    () async {
      final controller = SceneControllerCore(
        initialSnapshot: twoRectSnapshot(),
      );

      final beforeSnapshot = controller.snapshot;
      final beforeEpoch = controller.controllerEpoch;
      final beforeStructural = controller.structuralRevision;
      final beforeBounds = controller.boundsRevision;
      final beforeVisual = controller.visualRevision;
      final beforeCommit = controller.debugCommitRevision;
      final beforeSelection = controller.selectedNodeIds;

      final signals = <Object>[];
      final sub = controller.signals.listen(signals.add);
      addTearDown(sub.cancel);

      var notifications = 0;
      controller.addListener(() {
        notifications = notifications + 1;
      });

      controller.dispose();

      expect(
        () => controller.write<void>((writer) {
          writer.writeSelectionReplace(const <NodeId>{'r1'});
        }),
        throwsStateError,
      );
      await pumpEventQueue(times: 2);

      final afterSnapshot = controller.snapshot;
      expect(afterSnapshot.layers.length, beforeSnapshot.layers.length);
      expect(
        afterSnapshot.layers.first.nodes.map((node) => node.id).toList(),
        beforeSnapshot.layers.first.nodes.map((node) => node.id).toList(),
      );
      expect(controller.controllerEpoch, beforeEpoch);
      expect(controller.structuralRevision, beforeStructural);
      expect(controller.boundsRevision, beforeBounds);
      expect(controller.visualRevision, beforeVisual);
      expect(controller.debugCommitRevision, beforeCommit);
      expect(controller.selectedNodeIds, beforeSelection);
      expect(signals, isEmpty);
      expect(notifications, 0);
    },
  );

  test(
    'writeReplaceScene after dispose throws and keeps state unchanged',
    () async {
      final controller = SceneControllerCore(
        initialSnapshot: twoRectSnapshot(),
      );

      final beforeSnapshot = controller.snapshot;
      final beforeEpoch = controller.controllerEpoch;
      final beforeStructural = controller.structuralRevision;
      final beforeBounds = controller.boundsRevision;
      final beforeVisual = controller.visualRevision;
      final beforeCommit = controller.debugCommitRevision;
      final beforeSelection = controller.selectedNodeIds;

      final signals = <Object>[];
      final sub = controller.signals.listen(signals.add);
      addTearDown(sub.cancel);

      var notifications = 0;
      controller.addListener(() {
        notifications = notifications + 1;
      });

      controller.dispose();

      expect(
        () => controller.writeReplaceScene(
          SceneSnapshot(
            layers: <ContentLayerSnapshot>[
              ContentLayerSnapshot(
                nodes: const <NodeSnapshot>[
                  RectNodeSnapshot(id: 'new', size: Size(5, 5)),
                ],
              ),
            ],
          ),
        ),
        throwsStateError,
      );
      await pumpEventQueue(times: 2);

      final afterSnapshot = controller.snapshot;
      expect(afterSnapshot.layers.length, beforeSnapshot.layers.length);
      expect(
        afterSnapshot.layers.first.nodes.map((node) => node.id).toList(),
        beforeSnapshot.layers.first.nodes.map((node) => node.id).toList(),
      );
      expect(controller.controllerEpoch, beforeEpoch);
      expect(controller.structuralRevision, beforeStructural);
      expect(controller.boundsRevision, beforeBounds);
      expect(controller.visualRevision, beforeVisual);
      expect(controller.debugCommitRevision, beforeCommit);
      expect(controller.selectedNodeIds, beforeSelection);
      expect(signals, isEmpty);
      expect(notifications, 0);
    },
  );

  test(
    'requestRepaint after dispose throws and does not schedule notification',
    () async {
      final controller = SceneControllerCore(
        initialSnapshot: twoRectSnapshot(),
      );

      final beforeSnapshot = controller.snapshot;
      final beforeEpoch = controller.controllerEpoch;
      final beforeStructural = controller.structuralRevision;
      final beforeBounds = controller.boundsRevision;
      final beforeVisual = controller.visualRevision;
      final beforeCommit = controller.debugCommitRevision;
      final beforeSelection = controller.selectedNodeIds;

      final signals = <Object>[];
      final sub = controller.signals.listen(signals.add);
      addTearDown(sub.cancel);

      var notifications = 0;
      controller.addListener(() {
        notifications = notifications + 1;
      });

      controller.dispose();

      expect(() => controller.requestRepaint(), throwsStateError);
      await pumpEventQueue(times: 2);

      final afterSnapshot = controller.snapshot;
      expect(afterSnapshot.layers.length, beforeSnapshot.layers.length);
      expect(
        afterSnapshot.layers.first.nodes.map((node) => node.id).toList(),
        beforeSnapshot.layers.first.nodes.map((node) => node.id).toList(),
      );
      expect(controller.controllerEpoch, beforeEpoch);
      expect(controller.structuralRevision, beforeStructural);
      expect(controller.boundsRevision, beforeBounds);
      expect(controller.visualRevision, beforeVisual);
      expect(controller.debugCommitRevision, beforeCommit);
      expect(controller.selectedNodeIds, beforeSelection);
      expect(signals, isEmpty);
      expect(notifications, 0);
    },
  );

  test(
    'controller commit handles 1000 mixed selection operations and stays correct',
    () {
      final controller = SceneControllerCore(
        initialSnapshot: SceneSnapshot(
          layers: <ContentLayerSnapshot>[
            ContentLayerSnapshot(
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
      expect(controller.debugLastChangeSet.selectionChanged, isTrue);
      expect(controller.debugLastChangeSet.structuralChanged, isTrue);
      expect(controller.debugCommitRevision, 1);
    },
  );

  test('commit normalization marks selection/grid changes when normalized', () {
    final controller = SceneControllerCore(initialSnapshot: twoRectSnapshot());
    addTearDown(controller.dispose);

    controller.write<void>((writer) {
      writer.writeSelectionReplace(const <NodeId>{'r1'});
      writer.writeNodePatch(
        const RectNodePatch(
          id: 'r1',
          common: CommonNodePatch(isVisible: PatchField<bool>.value(false)),
        ),
      );
      writer.writeGridEnable(true);
      writer.writeGridCellSize(0.1);
    });

    expect(controller.selectedNodeIds, isEmpty);
    expect(controller.snapshot.background.grid.cellSize, 1.0);
    expect(controller.debugLastChangeSet.selectionChanged, isTrue);
    expect(controller.debugLastChangeSet.gridChanged, isTrue);
  });
}
