import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine/src/controller/scene_controller.dart';
import 'package:iwb_canvas_engine/src/controller/internal/signal_event.dart';

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
          nodes: <NodeSnapshot>[
            const RectNodeSnapshot(id: 'r1', size: Size(10, 10)),
            const RectNodeSnapshot(id: 'r2', size: Size(12, 12)),
          ],
        ),
      ],
    );
  }

  SceneSnapshot singleStrokeSnapshot() {
    return SceneSnapshot(
      layers: <ContentLayerSnapshot>[
        ContentLayerSnapshot(
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
    final controller = SceneControllerCore(initialSnapshot: twoRectSnapshot());
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
    await pumpEventQueue();

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

  test(
    'repaint notifications are coalesced within the same event-loop tick',
    () async {
      final controller = SceneControllerCore(
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
    final controller = SceneControllerCore(initialSnapshot: twoRectSnapshot());
    addTearDown(controller.dispose);

    final beforeCommit = controller.debugCommitRevision;
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
    expect(controller.debugCommitRevision, beforeCommit);
    expect(controller.structuralRevision, beforeStructural);
    expect(controller.boundsRevision, beforeBounds);
    expect(controller.visualRevision, beforeVisual);
  });

  test('no-op write keeps commit/revisions unchanged and does not notify', () {
    final controller = SceneControllerCore(initialSnapshot: twoRectSnapshot());
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

  test('snapshot getter reuses immutable instance between reads', () {
    final controller = SceneControllerCore(initialSnapshot: twoRectSnapshot());
    addTearDown(controller.dispose);

    final first = controller.snapshot;
    final second = controller.snapshot;

    expect(identical(first, second), isTrue);
  });

  test('selectedNodeIds getter reuses view between reads', () {
    final controller = SceneControllerCore(initialSnapshot: twoRectSnapshot());
    addTearDown(controller.dispose);

    final first = controller.selectedNodeIds;
    final second = controller.selectedNodeIds;

    expect(identical(first, second), isTrue);
  });

  test('selectedNodeIds view survives commits without selection changes', () {
    final controller = SceneControllerCore(initialSnapshot: twoRectSnapshot());
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

    controller.write<void>((writer) {
      writer.writeSignalEnqueue(type: 'signals-only.selection-view');
    });
    final afterSignals = controller.selectedNodeIds;
    expect(identical(afterBounds, afterSignals), isTrue);
  });

  test('selectedNodeIds view identity changes after selection mutation', () {
    final controller = SceneControllerCore(initialSnapshot: twoRectSnapshot());
    addTearDown(controller.dispose);

    final before = controller.selectedNodeIds;
    controller.write<void>((writer) {
      writer.writeSelectionReplace(const <NodeId>{'r1'});
    });
    final after = controller.selectedNodeIds;

    expect(identical(before, after), isFalse);
    expect(after, const <NodeId>{'r1'});
  });

  test('snapshot cache survives selection-only and signals-only commits', () {
    final controller = SceneControllerCore(initialSnapshot: twoRectSnapshot());
    addTearDown(controller.dispose);

    final before = controller.snapshot;
    controller.write<void>((writer) {
      writer.writeSelectionReplace(const <NodeId>{'r1'});
    });
    final afterSelection = controller.snapshot;
    expect(identical(before, afterSelection), isTrue);

    controller.write<void>((writer) {
      writer.writeSignalEnqueue(type: 'signals-only.cache');
    });
    final afterSignals = controller.snapshot;
    expect(identical(afterSelection, afterSignals), isTrue);
  });

  test('snapshot cache invalidates on scene identity change', () {
    final controller = SceneControllerCore(initialSnapshot: twoRectSnapshot());
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
    'stroke pointsRevision stays monotonic across sequential geometry commits',
    () {
      final controller = SceneControllerCore(
        initialSnapshot: singleStrokeSnapshot(),
      );
      addTearDown(controller.dispose);

      final rev0 =
          (controller.snapshot.layers.first.nodes.first as StrokeNodeSnapshot)
              .pointsRevision;
      expect(rev0, 0);

      controller.write<void>((writer) {
        writer.writeNodePatch(
          const StrokeNodePatch(
            id: 's1',
            points: PatchField<List<Offset>>.value(<Offset>[
              Offset(0, 0),
              Offset(2, 2),
            ]),
          ),
        );
      });
      final rev1 =
          (controller.snapshot.layers.first.nodes.first as StrokeNodeSnapshot)
              .pointsRevision;

      controller.write<void>((writer) {
        writer.writeNodePatch(
          const StrokeNodePatch(
            id: 's1',
            points: PatchField<List<Offset>>.value(<Offset>[
              Offset(0, 0),
              Offset(3, 3),
            ]),
          ),
        );
      });
      final rev2 =
          (controller.snapshot.layers.first.nodes.first as StrokeNodeSnapshot)
              .pointsRevision;

      expect(rev1, greaterThan(rev0));
      expect(rev2, greaterThan(rev1));
    },
  );

  test(
    'stroke patch points are copied on commit and do not alias input list',
    () {
      final controller = SceneControllerCore(
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

  test('snapshot cache invalidates after writeReplaceScene', () {
    final controller = SceneControllerCore(initialSnapshot: twoRectSnapshot());
    addTearDown(controller.dispose);

    final before = controller.snapshot;
    controller.writeReplaceScene(
      SceneSnapshot(
        layers: <ContentLayerSnapshot>[
          ContentLayerSnapshot(
            nodes: const <NodeSnapshot>[
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
    final controller = SceneControllerCore(initialSnapshot: twoRectSnapshot());
    addTearDown(controller.dispose);

    final beforeCommit = controller.debugCommitRevision;
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
    'requestRepaint inside successful no-op write schedules one notification',
    () async {
      final controller = SceneControllerCore(
        initialSnapshot: twoRectSnapshot(),
      );
      addTearDown(controller.dispose);

      final beforeCommit = controller.debugCommitRevision;
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
      expect(controller.debugCommitRevision, beforeCommit);
      expect(controller.structuralRevision, beforeStructural);
      expect(controller.boundsRevision, beforeBounds);
      expect(controller.visualRevision, beforeVisual);
      expect(controller.debugLastCommitPhases, const <String>['repaint']);
    },
  );
}
