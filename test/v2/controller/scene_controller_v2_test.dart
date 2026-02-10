import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/basic.dart';
import 'package:iwb_canvas_engine/src/core/scene_spatial_index.dart';
import 'package:iwb_canvas_engine/src/v2/controller/scene_controller_v2.dart';

// INV:INV-V2-TXN-ATOMIC-COMMIT
// INV:INV-V2-EPOCH-INVALIDATION

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
      'grid',
      'spatial_index',
      'signals',
      'repaint',
    ]);
  });

  test(
    'write rollback keeps scene/revisions unchanged and emits no signals',
    () {
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

  test(
    'writeReplaceScene increments epoch clears selection and has no action signal',
    () {
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

  test('signals are emitted only after successful commit', () {
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

    expect(emitted, <String>['committed']);
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
