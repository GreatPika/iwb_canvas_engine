import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine/src/controller/scene_store_controller.dart';
import 'package:iwb_canvas_engine/src/controller/internal/signal_event.dart';
import 'package:iwb_canvas_engine/src/render/render_geometry_cache.dart';

// INV:INV-ENG-TXN-ATOMIC-COMMIT
// INV:INV-ENG-EPOCH-INVALIDATION
// INV:INV-ENG-SIGNALS-AFTER-COMMIT
// INV:INV-ENG-ID-INDEX-FROM-SCENE
// INV:INV-ENG-TXN-COPY-ON-WRITE
// INV:INV-ENG-TXN-WRITER-LIFETIME
// INV:INV-ENG-TEXT-SIZE-DERIVED
// INV:INV-ENG-DISPOSE-FAIL-FAST
// INV:INV-ENG-NO-EXTERNAL-MUTATION

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

  SceneSnapshot singleStrokeSnapshot() {
    return SceneSnapshot(
      layers: <ContentLayerSnapshot>[
        ContentLayerSnapshot(
          id: 'layer-auto-1',
          nodes: <NodeSnapshot>[
            StrokeNodeSnapshot(
              id: 's1',
              points: const <Offset>[Offset(0, 0), Offset(1, 1)],
              thickness: 2,
              color: const Color(0xFF000000),
            ),
          ],
        ),
      ],
    );
  }

  test('write is atomic and notifies once per commit', () async {
    final controller = SceneStoreController(initialSnapshot: twoRectSnapshot());
    addTearDown(controller.dispose);

    var notifications = 0;
    controller.addListener(() {
      notifications = notifications + 1;
    });

    controller.writeWithSceneWriter<void>((writer) {
      writer.writeSelectionReplace(const <NodeId>{'r1'});
      writer.writeSelectionTranslate(const Offset(10, 0));
      writer.writeSignalEnqueue(
        type: 'transform',
        nodeIds: const <NodeId>['r1'],
      );
    });
    await pumpEventQueue();

    final moved =
        controller.snapshot.layers.first.nodes.first as RectNodeSnapshot;
    expect(moved.transform.tx, 10);
    expect(notifications, 1);
    expect(controller.debug.lastCommitPhases, const <String>[
      'selection',
      'spatial_index',
      'signals',
      'repaint',
    ]);
  });

  test(
    'commit handles locator shift before delete without leaving stale node',
    () {
      final controller = SceneStoreController(
        initialSnapshot: SceneSnapshot(
          layers: <ContentLayerSnapshot>[
            ContentLayerSnapshot(id: 'layer-auto-0'),
            ContentLayerSnapshot(
              id: 'layer-auto-1',
              nodes: <NodeSnapshot>[
                RectNodeSnapshot(id: 'tail', size: const Size(10, 10)),
              ],
            ),
          ],
        ),
      );
      addTearDown(controller.dispose);

      controller.write<void>((writer) {
        expect(writer.writeLayerEnsure('layer-inserted', index: 1), isTrue);
        expect(writer.writeNodeErase('tail'), isTrue);
      });

      expect(
        controller.snapshot.layers.map((layer) => layer.id).toList(),
        const <LayerId>['layer-auto-0', 'layer-inserted', 'layer-auto-1'],
      );
      expect(controller.snapshot.layers.last.nodes, isEmpty);
      expect(
        controller.queryHitTestCandidates(const Rect.fromLTWH(0, 0, 20, 20)),
        isEmpty,
      );
      expect(controller.debug.lastCommitPhases, const <String>[
        'selection',
        'spatial_index',
        'signals',
        'repaint',
      ]);
    },
  );

  test(
    'structural clear without removed nodes still commits through state path',
    () {
      final controller = SceneStoreController(
        initialSnapshot: SceneSnapshot(
          layers: <ContentLayerSnapshot>[
            ContentLayerSnapshot(id: 'layer-empty'),
          ],
        ),
      );
      addTearDown(controller.dispose);

      late final ClearSceneResult clearResult;
      controller.write<void>((writer) {
        clearResult = writer.writeClearSceneKeepBackgroundResult();
      });

      expect(clearResult.removedNodeIds, isEmpty);
      expect(clearResult.didStructuralClear, isTrue);
      expect(controller.snapshot.layers, isEmpty);
      expect(controller.structuralRevision, 1);
      expect(controller.boundsRevision, 1);
      expect(controller.visualRevision, 1);
      expect(controller.debug.currentCommitRevision, 1);
      expect(controller.debug.lastCommitPhases, const <String>[
        'selection',
        'spatial_index',
        'signals',
        'repaint',
      ]);
    },
  );

  test(
    'repaint notifications are coalesced within the same event-loop tick',
    () async {
      final controller = SceneStoreController(
        initialSnapshot: twoRectSnapshot(),
      );
      addTearDown(controller.dispose);

      var notifications = 0;
      controller.addListener(() {
        notifications = notifications + 1;
      });

      controller.write<void>((writer) {
        writer.writeSelectionReplace(const <NodeId>{'r1'});
      });
      controller.write<void>((writer) {
        writer.writeSelectionReplace(const <NodeId>{'r2'});
      });

      expect(notifications, 0);
      await pumpEventQueue();

      expect(notifications, 1);
    },
  );

  test('requestRepaint outside write is deferred and coalesced', () async {
    final controller = SceneStoreController(initialSnapshot: twoRectSnapshot());
    addTearDown(controller.dispose);

    final beforeCommit = controller.debug.currentCommitRevision;
    final beforeStructural = controller.structuralRevision;
    final beforeBounds = controller.boundsRevision;
    final beforeVisual = controller.visualRevision;

    var notifications = 0;
    controller.addListener(() {
      notifications = notifications + 1;
    });

    controller.requestRepaint();
    controller.requestRepaint();

    expect(notifications, 0);
    await pumpEventQueue();

    expect(notifications, 1);
    expect(controller.debug.currentCommitRevision, beforeCommit);
    expect(controller.structuralRevision, beforeStructural);
    expect(controller.boundsRevision, beforeBounds);
    expect(controller.visualRevision, beforeVisual);
  });

  test('no-op write keeps commit/revisions unchanged and does not notify', () {
    final controller = SceneStoreController(initialSnapshot: twoRectSnapshot());
    addTearDown(controller.dispose);

    final beforeCommit = controller.debug.currentCommitRevision;
    final beforeStructural = controller.structuralRevision;
    final beforeSelection = controller.selectionRevision;
    final beforeBounds = controller.boundsRevision;
    final beforeVisual = controller.visualRevision;

    var notifications = 0;
    controller.addListener(() {
      notifications = notifications + 1;
    });

    controller.write<void>((_) {});

    expect(controller.debug.currentCommitRevision, beforeCommit);
    expect(controller.structuralRevision, beforeStructural);
    expect(controller.selectionRevision, beforeSelection);
    expect(controller.boundsRevision, beforeBounds);
    expect(controller.visualRevision, beforeVisual);
    expect(notifications, 0);
    expect(controller.debug.lastCommitPhases, isEmpty);
  });

  test('snapshot getter reuses immutable instance between reads', () {
    final controller = SceneStoreController(initialSnapshot: twoRectSnapshot());
    addTearDown(controller.dispose);

    final first = controller.snapshot;
    final second = controller.snapshot;

    expect(identical(first, second), isTrue);
  });

  test('selectedNodeIds getter reuses view between reads', () {
    final controller = SceneStoreController(initialSnapshot: twoRectSnapshot());
    addTearDown(controller.dispose);

    final first = controller.selectedNodeIds;
    final second = controller.selectedNodeIds;

    expect(identical(first, second), isTrue);
  });

  test('selectedNodeIds view survives commits without selection changes', () {
    final controller = SceneStoreController(initialSnapshot: twoRectSnapshot());
    addTearDown(controller.dispose);

    controller.write<void>((writer) {
      writer.writeSelectionReplace(const <NodeId>{'r1'});
    });
    final before = controller.selectedNodeIds;

    controller.write<void>((writer) {
      writer.writeSelectionTranslate(const Offset(5, 0));
    });
    final afterBounds = controller.selectedNodeIds;
    expect(identical(before, afterBounds), isTrue);
    expect(controller.selectionRevision, 1);

    controller.writeWithSceneWriter<void>((writer) {
      writer.writeSignalEnqueue(type: 'signals-only.selection-view');
    });
    final afterSignals = controller.selectedNodeIds;
    expect(identical(afterBounds, afterSignals), isTrue);
    expect(controller.selectionRevision, 1);
  });

  test('selectedNodeIds view identity changes after selection mutation', () {
    final controller = SceneStoreController(initialSnapshot: twoRectSnapshot());
    addTearDown(controller.dispose);

    final before = controller.selectedNodeIds;
    controller.write<void>((writer) {
      writer.writeSelectionReplace(const <NodeId>{'r1'});
    });
    final after = controller.selectedNodeIds;

    expect(identical(before, after), isFalse);
    expect(after, const <NodeId>{'r1'});
    expect(controller.selectionRevision, 1);
  });

  test(
    'selectionRevision increments only for committed selection membership changes',
    () {
      final controller = SceneStoreController(
        initialSnapshot: twoRectSnapshot(),
      );
      addTearDown(controller.dispose);

      expect(controller.selectionRevision, 0);

      controller.write<void>((writer) {
        writer.writeSelectionReplace(const <NodeId>{'r1'});
      });
      expect(controller.selectionRevision, 1);

      controller.write<void>((writer) {
        writer.writeSelectionTranslate(const Offset(5, 0));
      });
      expect(controller.selectionRevision, 1);

      controller.write<void>((writer) {
        writer.writeSelectionReplace(const <NodeId>{'r2'});
      });
      expect(controller.selectionRevision, 2);

      controller.write<void>((writer) {
        writer.writeNodePatch(
          RectNodePatch(
            id: 'r2',
            fillColor: PatchField<Color>.value(const Color(0xFF00FF00)),
          ),
        );
      });
      expect(controller.selectionRevision, 2);
    },
  );

  test('snapshot cache survives selection-only and signals-only commits', () {
    final controller = SceneStoreController(initialSnapshot: twoRectSnapshot());
    addTearDown(controller.dispose);

    final before = controller.snapshot;
    controller.write<void>((writer) {
      writer.writeSelectionReplace(const <NodeId>{'r1'});
    });
    final afterSelection = controller.snapshot;
    expect(identical(before, afterSelection), isTrue);

    controller.writeWithSceneWriter<void>((writer) {
      writer.writeSignalEnqueue(type: 'signals-only.cache');
    });
    final afterSignals = controller.snapshot;
    expect(identical(afterSelection, afterSignals), isTrue);
  });

  test('snapshot cache invalidates on scene identity change', () {
    final controller = SceneStoreController(initialSnapshot: twoRectSnapshot());
    addTearDown(controller.dispose);

    final before = controller.snapshot;
    controller.write<void>((writer) {
      writer.writeSelectionReplace(const <NodeId>{'r1'});
      writer.writeSelectionTranslate(const Offset(10, 0));
    });
    final after = controller.snapshot;

    expect(identical(before, after), isFalse);
    final moved = after.layers.first.nodes.first as RectNodeSnapshot;
    expect(moved.transform.tx, 10);
  });

  test(
    'stroke geometry commit invalidates the public render geometry cache entry',
    () {
      final controller = SceneStoreController(
        initialSnapshot: singleStrokeSnapshot(),
      );
      addTearDown(controller.dispose);
      final cache = RenderGeometryCache();

      final beforeStroke =
          controller.snapshot.layers.first.nodes.first as StrokeNodeSnapshot;
      final beforeEntry = cache.get(beforeStroke);

      controller.write<void>((writer) {
        writer.writeNodePatch(
          StrokeNodePatch(
            id: 's1',
            points: PatchField<List<Offset>>.value(<Offset>[
              Offset(0, 0),
              Offset(2, 2),
            ]),
          ),
        );
      });
      final afterStroke =
          controller.snapshot.layers.first.nodes.first as StrokeNodeSnapshot;
      final afterEntry = cache.get(afterStroke);

      expect(afterStroke.points, const <Offset>[Offset(0, 0), Offset(2, 2)]);
      expect(identical(beforeEntry, afterEntry), isFalse);
      expect(cache.debugBuildCount, 2);
      expect(cache.debugHitCount, 0);
    },
  );

  test(
    'stroke patch points are copied on commit and do not alias input list',
    () {
      final controller = SceneStoreController(
        initialSnapshot: singleStrokeSnapshot(),
      );
      addTearDown(controller.dispose);

      final points = <Offset>[const Offset(0, 0), const Offset(4, 4)];
      controller.write<void>((writer) {
        writer.writeNodePatch(
          StrokeNodePatch(
            id: 's1',
            points: PatchField<List<Offset>>.value(points),
          ),
        );
      });

      points[1] = const Offset(100, 100);
      final stroke =
          controller.snapshot.layers.first.nodes.first as StrokeNodeSnapshot;
      expect(stroke.points[1], const Offset(4, 4));
    },
  );

  test('no-op stroke point patch keeps commit state and snapshot cache', () {
    final controller = SceneStoreController(
      initialSnapshot: singleStrokeSnapshot(),
    );
    addTearDown(controller.dispose);

    final beforeSnapshot = controller.snapshot;
    final beforeCommit = controller.debug.currentCommitRevision;
    final beforeStructural = controller.structuralRevision;
    final beforeBounds = controller.boundsRevision;
    final beforeVisual = controller.visualRevision;
    final beforeStroke =
        beforeSnapshot.layers.first.nodes.first as StrokeNodeSnapshot;

    controller.write<void>((writer) {
      writer.writeNodePatch(
        StrokeNodePatch(
          id: 's1',
          points: PatchField<List<Offset>>.value(<Offset>[
            const Offset(0, 0),
            const Offset(1, 1),
          ]),
        ),
      );
    });

    final afterSnapshot = controller.snapshot;
    final afterStroke =
        afterSnapshot.layers.first.nodes.first as StrokeNodeSnapshot;
    expect(controller.debug.currentCommitRevision, beforeCommit);
    expect(controller.structuralRevision, beforeStructural);
    expect(controller.boundsRevision, beforeBounds);
    expect(controller.visualRevision, beforeVisual);
    expect(afterStroke.points, beforeStroke.points);
    expect(identical(afterSnapshot, beforeSnapshot), isTrue);
  });

  test('snapshot cache invalidates after writeReplaceScene', () {
    final controller = SceneStoreController(initialSnapshot: twoRectSnapshot());
    addTearDown(controller.dispose);

    final before = controller.snapshot;
    controller.writeReplaceScene(
      SceneSnapshot(
        layers: <ContentLayerSnapshot>[
          ContentLayerSnapshot(
            id: 'layer-auto-2',
            nodes: <NodeSnapshot>[
              RectNodeSnapshot(id: 'fresh', size: Size(4, 4)),
            ],
          ),
        ],
      ),
    );
    final after = controller.snapshot;

    expect(identical(before, after), isFalse);
    expect(after.layers.first.nodes.single.id, 'fresh');
  });

  test('signals-only write bumps commit only and skips repaint', () async {
    final controller = SceneStoreController(initialSnapshot: twoRectSnapshot());
    addTearDown(controller.dispose);

    final beforeCommit = controller.debug.currentCommitRevision;
    final beforeStructural = controller.structuralRevision;
    final beforeBounds = controller.boundsRevision;
    final beforeVisual = controller.visualRevision;

    var notifications = 0;
    controller.addListener(() {
      notifications = notifications + 1;
    });

    final emitted = <CommittedSignal>[];
    final sub = controller.signals.listen(emitted.add);
    addTearDown(sub.cancel);

    controller.writeWithSceneWriter<void>((writer) {
      writer.writeSignalEnqueue(type: 'signals-only');
    });
    await pumpEventQueue();

    expect(emitted, hasLength(1));
    expect(emitted.single.type, 'signals-only');
    expect(controller.debug.currentCommitRevision, beforeCommit + 1);
    expect(controller.structuralRevision, beforeStructural);
    expect(controller.boundsRevision, beforeBounds);
    expect(controller.visualRevision, beforeVisual);
    expect(notifications, 0);
    expect(controller.debug.lastCommitPhases, const <String>['signals']);
  });

  test(
    'requestRepaint inside successful no-op write schedules one notification',
    () async {
      final controller = SceneStoreController(
        initialSnapshot: twoRectSnapshot(),
      );
      addTearDown(controller.dispose);

      final beforeCommit = controller.debug.currentCommitRevision;
      final beforeStructural = controller.structuralRevision;
      final beforeBounds = controller.boundsRevision;
      final beforeVisual = controller.visualRevision;

      var notifications = 0;
      controller.addListener(() {
        notifications = notifications + 1;
      });

      controller.write<void>((_) {
        controller.requestRepaint();
      });

      expect(notifications, 0);
      await pumpEventQueue();

      expect(notifications, 1);
      expect(controller.debug.currentCommitRevision, beforeCommit);
      expect(controller.structuralRevision, beforeStructural);
      expect(controller.boundsRevision, beforeBounds);
      expect(controller.visualRevision, beforeVisual);
      expect(controller.debug.lastCommitPhases, const <String>['repaint']);
    },
  );
}
