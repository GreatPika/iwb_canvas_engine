import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine/src/core/nodes.dart' show RectNode;
import 'package:iwb_canvas_engine/src/core/scene_spatial_index.dart';
import 'package:iwb_canvas_engine/src/controller/scene_controller.dart';
import 'package:iwb_canvas_engine/src/input/slices/signals/signal_event.dart';

// INV:INV-V2-TXN-ATOMIC-COMMIT
// INV:INV-V2-EPOCH-INVALIDATION
// INV:INV-V2-SIGNALS-AFTER-COMMIT
// INV:INV-V2-ID-INDEX-FROM-SCENE

void main() {
  SceneSnapshot twoRectSnapshot() {
    return SceneSnapshot(
      layers: <LayerSnapshot>[
        LayerSnapshot(
          nodes: <NodeSnapshot>[
            const RectNodeSnapshot(id: 'r1', size: Size(10, 10)),
            const RectNodeSnapshot(id: 'r2', size: Size(12, 12)),
          ],
        ),
      ],
    );
  }

  test('write is atomic and notifies once per commit', () {
    final controller = SceneControllerV2(initialSnapshot: twoRectSnapshot());
    addTearDown(controller.dispose);

    var notifications = 0;
    controller.addListener(() {
      notifications = notifications + 1;
    });

    controller.write<void>((writer) {
      writer.writeSelectionReplace(const <NodeId>{'r1'});
      writer.writeSelectionTranslate(const Offset(10, 0));
      writer.writeSignalEnqueue(
        type: 'transform',
        nodeIds: const <NodeId>['r1'],
      );
    });

    final moved =
        controller.snapshot.layers.first.nodes.first as RectNodeSnapshot;
    expect(moved.transform.tx, 10);
    expect(notifications, 1);
    expect(controller.debugLastCommitPhases, const <String>[
      'selection',
      'spatial_index',
      'signals',
      'repaint',
    ]);
  });

  test('no-op write keeps commit/revisions unchanged and does not notify', () {
    final controller = SceneControllerV2(initialSnapshot: twoRectSnapshot());
    addTearDown(controller.dispose);

    final beforeCommit = controller.debugCommitRevision;
    final beforeStructural = controller.structuralRevision;
    final beforeBounds = controller.boundsRevision;
    final beforeVisual = controller.visualRevision;

    var notifications = 0;
    controller.addListener(() {
      notifications = notifications + 1;
    });

    controller.write<void>((_) {});

    expect(controller.debugCommitRevision, beforeCommit);
    expect(controller.structuralRevision, beforeStructural);
    expect(controller.boundsRevision, beforeBounds);
    expect(controller.visualRevision, beforeVisual);
    expect(notifications, 0);
    expect(controller.debugLastCommitPhases, isEmpty);
  });

  test('signals-only write bumps commit only and skips repaint', () async {
    final controller = SceneControllerV2(initialSnapshot: twoRectSnapshot());
    addTearDown(controller.dispose);

    final beforeCommit = controller.debugCommitRevision;
    final beforeStructural = controller.structuralRevision;
    final beforeBounds = controller.boundsRevision;
    final beforeVisual = controller.visualRevision;

    var notifications = 0;
    controller.addListener(() {
      notifications = notifications + 1;
    });

    final emitted = <V2CommittedSignal>[];
    final sub = controller.signals.listen(emitted.add);
    addTearDown(sub.cancel);

    controller.write<void>((writer) {
      writer.writeSignalEnqueue(type: 'signals-only');
    });
    await pumpEventQueue();

    expect(emitted, hasLength(1));
    expect(emitted.single.type, 'signals-only');
    expect(controller.debugCommitRevision, beforeCommit + 1);
    expect(controller.structuralRevision, beforeStructural);
    expect(controller.boundsRevision, beforeBounds);
    expect(controller.visualRevision, beforeVisual);
    expect(notifications, 0);
    expect(controller.debugLastCommitPhases, const <String>['signals']);
  });

  test(
    'write rollback keeps scene/revisions unchanged and emits no signals',
    () async {
      final controller = SceneControllerV2(initialSnapshot: twoRectSnapshot());
      addTearDown(controller.dispose);

      final before = controller.snapshot;
      final beforeEpoch = controller.controllerEpoch;
      final beforeStructural = controller.structuralRevision;
      final beforeBounds = controller.boundsRevision;
      final beforeVisual = controller.visualRevision;

      final signals = <Object>[];
      final sub = controller.signals.listen(signals.add);
      addTearDown(sub.cancel);

      var notifications = 0;
      controller.addListener(() {
        notifications = notifications + 1;
      });

      expect(
        () => controller.write<void>((writer) {
          writer.writeSelectionReplace(const <NodeId>{'r1'});
          writer.writeSignalEnqueue(type: 'selection.changed');
          throw StateError('rollback');
        }),
        throwsStateError,
      );
      await pumpEventQueue();

      expect(
        controller.snapshot.layers.first.nodes.length,
        before.layers.first.nodes.length,
      );
      expect(controller.controllerEpoch, beforeEpoch);
      expect(controller.structuralRevision, beforeStructural);
      expect(controller.boundsRevision, beforeBounds);
      expect(controller.visualRevision, beforeVisual);
      expect(controller.selectedNodeIds, isEmpty);
      expect(signals, isEmpty);
      expect(notifications, 0);
    },
  );

  test('changeset tracks added removed and updated node ids', () {
    final controller = SceneControllerV2(initialSnapshot: twoRectSnapshot());
    addTearDown(controller.dispose);

    controller.write<void>((writer) {
      writer.writeNodeInsert(RectNodeSpec(id: 'r3', size: const Size(8, 8)));
      writer.writeNodePatch(
        const RectNodePatch(id: 'r1', strokeWidth: PatchField<double>.value(2)),
      );
      writer.writeNodeErase('r2');
    });

    final changes = controller.debugLastChangeSet;
    expect(changes.addedNodeIds, <NodeId>{'r3'});
    expect(changes.removedNodeIds, <NodeId>{'r2'});
    expect(changes.updatedNodeIds, <NodeId>{'r1'});
  });

  test('boundsChanged is auto-detected for transform patch', () {
    final controller = SceneControllerV2(initialSnapshot: twoRectSnapshot());
    addTearDown(controller.dispose);

    controller.write<void>((writer) {
      writer.writeNodePatch(
        const RectNodePatch(
          id: 'r1',
          common: CommonNodePatch(
            transform: PatchField<Transform2D>.value(
              Transform2D(a: 1, b: 0, c: 0, d: 1, tx: 100, ty: 0),
            ),
          ),
        ),
      );
    });

    expect(controller.debugLastChangeSet.boundsChanged, isTrue);
    expect(controller.boundsRevision, 1);
  });

  test('node patch that changes selection policy normalizes selected ids', () {
    final controller = SceneControllerV2(initialSnapshot: twoRectSnapshot());
    addTearDown(controller.dispose);

    controller.write<void>((writer) {
      writer.writeSelectionReplace(const <NodeId>{'r1'});
    });
    expect(controller.selectedNodeIds, const <NodeId>{'r1'});

    controller.write<void>((writer) {
      writer.writeNodePatch(
        const RectNodePatch(
          id: 'r1',
          common: CommonNodePatch(isSelectable: PatchField<bool>.value(false)),
        ),
      );
    });

    expect(controller.selectedNodeIds, isEmpty);
    expect(controller.debugLastChangeSet.selectionChanged, isTrue);
  });

  test(
    'writeReplaceScene increments epoch clears selection and has no action signal',
    () async {
      final controller = SceneControllerV2(initialSnapshot: twoRectSnapshot());
      addTearDown(controller.dispose);

      controller.write<void>((writer) {
        writer.writeSelectionReplace(const <NodeId>{'r1'});
      });

      final signals = <Object>[];
      final sub = controller.signals.listen(signals.add);
      addTearDown(sub.cancel);

      var notifications = 0;
      controller.addListener(() {
        notifications = notifications + 1;
      });

      controller.writeReplaceScene(
        SceneSnapshot(
          layers: <LayerSnapshot>[
            LayerSnapshot(
              nodes: const <NodeSnapshot>[
                RectNodeSnapshot(id: 'fresh', size: Size(4, 4)),
              ],
            ),
          ],
        ),
      );
      await pumpEventQueue();

      expect(controller.controllerEpoch, 1);
      expect(controller.selectedNodeIds, isEmpty);
      expect(controller.snapshot.layers.first.nodes.single.id, 'fresh');
      expect(controller.debugLastChangeSet.documentReplaced, isTrue);
      expect(notifications, 1);
      expect(signals, isEmpty);
    },
  );

  test('spatial index invalidates on bounds revision change', () {
    final controller = SceneControllerV2(initialSnapshot: twoRectSnapshot());
    addTearDown(controller.dispose);

    final beforeQuery = controller.querySpatialCandidates(
      const Rect.fromLTWH(0, 0, 0, 0),
    );
    expect(beforeQuery, isNotEmpty);
    expect(controller.debugSpatialIndexBuildCount, 1);

    controller.write<void>((writer) {
      writer.writeSelectionReplace(const <NodeId>{'r1'});
      writer.writeSelectionTranslate(const Offset(80, 0));
    });

    final afterQuery = controller.querySpatialCandidates(
      const Rect.fromLTWH(80, 0, 0, 0),
    );
    expect(afterQuery, isNotEmpty);
    expect(controller.debugSpatialIndexBuildCount, 2);
  });

  test('resolveSpatialCandidateNode accepts valid foreground candidate', () {
    final controller = SceneControllerV2(initialSnapshot: twoRectSnapshot());
    addTearDown(controller.dispose);

    final candidates = controller.querySpatialCandidates(
      const Rect.fromLTWH(0, 0, 0, 0),
    );
    expect(candidates, isNotEmpty);

    final resolved = controller.resolveSpatialCandidateNode(candidates.first);
    expect(resolved, isNotNull);
    expect(identical(resolved, candidates.first.node), isTrue);
  });

  test('resolveSpatialCandidateNode rejects background candidate', () {
    final controller = SceneControllerV2(
      initialSnapshot: SceneSnapshot(
        layers: <LayerSnapshot>[
          LayerSnapshot(
            isBackground: true,
            nodes: const <NodeSnapshot>[
              RectNodeSnapshot(id: 'bg-node', size: Size(10, 10)),
            ],
          ),
          LayerSnapshot(),
        ],
      ),
    );
    addTearDown(controller.dispose);

    final backgroundNode = RectNode(id: 'bg-node', size: const Size(10, 10));
    final backgroundCandidate = SceneSpatialCandidate(
      layerIndex: 0,
      nodeIndex: 0,
      node: backgroundNode,
      candidateBoundsWorld: backgroundNode.boundsWorld,
    );
    expect(controller.resolveSpatialCandidateNode(backgroundCandidate), isNull);
  });

  test('resolveSpatialCandidateNode rejects out-of-range indices', () {
    final controller = SceneControllerV2(initialSnapshot: twoRectSnapshot());
    addTearDown(controller.dispose);

    final node = RectNode(id: 'fake', size: const Size(4, 4));
    final outOfRangeLayer = SceneSpatialCandidate(
      layerIndex: 99,
      nodeIndex: 0,
      node: node,
      candidateBoundsWorld: node.boundsWorld,
    );
    final outOfRangeNode = SceneSpatialCandidate(
      layerIndex: 0,
      nodeIndex: 99,
      node: node,
      candidateBoundsWorld: node.boundsWorld,
    );

    expect(controller.resolveSpatialCandidateNode(outOfRangeLayer), isNull);
    expect(controller.resolveSpatialCandidateNode(outOfRangeNode), isNull);
  });

  test(
    'resolveSpatialCandidateNode rejects stale identity after replaceScene',
    () {
      final controller = SceneControllerV2(initialSnapshot: twoRectSnapshot());
      addTearDown(controller.dispose);

      final stale = controller
          .querySpatialCandidates(const Rect.fromLTWH(0, 0, 0, 0))
          .first;

      controller.writeReplaceScene(
        SceneSnapshot(
          layers: <LayerSnapshot>[
            LayerSnapshot(
              nodes: const <NodeSnapshot>[
                RectNodeSnapshot(id: 'fresh-1', size: Size(10, 10)),
                RectNodeSnapshot(id: 'fresh-2', size: Size(12, 12)),
              ],
            ),
          ],
        ),
      );

      expect(controller.resolveSpatialCandidateNode(stale), isNull);
    },
  );

  test(
    'resolveSpatialCandidateNode accepts non-geometry clone after selection write',
    () {
      final controller = SceneControllerV2(initialSnapshot: twoRectSnapshot());
      addTearDown(controller.dispose);

      final candidate = controller
          .querySpatialCandidates(const Rect.fromLTWH(0, 0, 0, 0))
          .first;

      controller.write<void>((writer) {
        writer.writeSelectionReplace(const <NodeId>{'r1'});
      });

      final resolved = controller.resolveSpatialCandidateNode(candidate);
      expect(resolved, isNotNull);
      expect(resolved!.id, candidate.node.id);
      expect(resolved.type, candidate.node.type);
    },
  );

  test('signals are emitted only after successful commit', () async {
    final controller = SceneControllerV2(initialSnapshot: twoRectSnapshot());
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
    'signal listener observes committed state and can trigger follow-up write',
    () async {
      final controller = SceneControllerV2(initialSnapshot: twoRectSnapshot());
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

  test('committed signals expose immutable payload and nodeIds', () async {
    // INV:INV-V2-EVENTS-IMMUTABLE
    final controller = SceneControllerV2(initialSnapshot: twoRectSnapshot());
    addTearDown(controller.dispose);

    final emitted = <V2CommittedSignal>[];
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
    final controller = SceneControllerV2(initialSnapshot: twoRectSnapshot());
    addTearDown(controller.dispose);

    expect(
      () => controller.write<void>((_) {
        controller.write<void>((_) {});
      }),
      throwsStateError,
    );
  });

  test('commit normalization marks selection/grid changes when normalized', () {
    final controller = SceneControllerV2(initialSnapshot: twoRectSnapshot());
    addTearDown(controller.dispose);

    controller.write<void>((writer) {
      writer.writeSelectionReplace(const <NodeId>{'missing'});
      writer.writeGridEnable(true);
      writer.writeGridCellSize(0.1);
    });

    expect(controller.selectedNodeIds, isEmpty);
    expect(controller.snapshot.background.grid.cellSize, 1.0);
    expect(controller.debugLastChangeSet.selectionChanged, isTrue);
    expect(controller.debugLastChangeSet.gridChanged, isTrue);
  });
}
