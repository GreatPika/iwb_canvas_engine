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
// INV:INV-V2-TXN-COPY-ON-WRITE
// INV:INV-V2-TEXT-SIZE-DERIVED
// INV:INV-V2-DISPOSE-FAIL-FAST

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
      final controller = SceneControllerV2(initialSnapshot: twoRectSnapshot());
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

  test('snapshot getter reuses immutable instance between reads', () {
    final controller = SceneControllerV2(initialSnapshot: twoRectSnapshot());
    addTearDown(controller.dispose);

    final first = controller.snapshot;
    final second = controller.snapshot;

    expect(identical(first, second), isTrue);
  });

  test('selectedNodeIds getter reuses view between reads', () {
    final controller = SceneControllerV2(initialSnapshot: twoRectSnapshot());
    addTearDown(controller.dispose);

    final first = controller.selectedNodeIds;
    final second = controller.selectedNodeIds;

    expect(identical(first, second), isTrue);
  });

  test('selectedNodeIds view survives commits without selection changes', () {
    final controller = SceneControllerV2(initialSnapshot: twoRectSnapshot());
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
    final controller = SceneControllerV2(initialSnapshot: twoRectSnapshot());
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
    final controller = SceneControllerV2(initialSnapshot: twoRectSnapshot());
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
    final controller = SceneControllerV2(initialSnapshot: twoRectSnapshot());
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
      final controller = SceneControllerV2(
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

  test('snapshot cache invalidates after writeReplaceScene', () {
    final controller = SceneControllerV2(initialSnapshot: twoRectSnapshot());
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

  test(
    'write rollback discards repaint request and emits no external effects',
    () async {
      final controller = SceneControllerV2(initialSnapshot: twoRectSnapshot());
      addTearDown(controller.dispose);

      final beforeCommit = controller.debugCommitRevision;
      final beforeSnapshot = controller.snapshot;

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
          writer.writeSignalEnqueue(type: 'will.rollback');
          controller.requestRepaint();
          throw StateError('rollback');
        }),
        throwsStateError,
      );
      await pumpEventQueue(times: 2);

      expect(controller.debugCommitRevision, beforeCommit);
      expect(controller.selectedNodeIds, isEmpty);
      expect(controller.snapshot.layers.length, beforeSnapshot.layers.length);
      expect(signals, isEmpty);
      expect(notifications, 0);
    },
  );

  test(
    'invariant pre-check failure in state-change branch keeps store and effects unchanged',
    () async {
      final controller = SceneControllerV2(initialSnapshot: twoRectSnapshot());
      addTearDown(controller.dispose);

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

      controller.debugBeforeInvariantPrecheckHook = () {
        throw StateError('forced invariant pre-check failure');
      };

      expect(
        () => controller.write<void>((writer) {
          writer.writeSelectionReplace(const <NodeId>{'r1'});
          writer.writeSelectionTranslate(const Offset(10, 0));
          writer.writeSignalEnqueue(type: 'will.not.emit');
        }),
        throwsStateError,
      );
      await pumpEventQueue(times: 2);

      final afterSnapshot = controller.snapshot;
      expect(afterSnapshot.layers.length, beforeSnapshot.layers.length);
      expect(
        afterSnapshot.layers.first.nodes
            .map((node) => node.id)
            .toList(growable: false),
        beforeSnapshot.layers.first.nodes
            .map((node) => node.id)
            .toList(growable: false),
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
    'spatial prepare failure in state-change branch keeps store and effects unchanged',
    () async {
      final controller = SceneControllerV2(initialSnapshot: twoRectSnapshot());
      addTearDown(controller.dispose);

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

      controller.debugBeforeSpatialPrepareCommitHook = () {
        throw StateError('forced spatial prepare failure');
      };

      expect(
        () => controller.write<void>((writer) {
          writer.writeSelectionReplace(const <NodeId>{'r1'});
          writer.writeSelectionTranslate(const Offset(10, 0));
          writer.writeSignalEnqueue(type: 'will.not.emit');
        }),
        throwsStateError,
      );
      await pumpEventQueue(times: 2);

      final afterSnapshot = controller.snapshot;
      expect(afterSnapshot.layers.length, beforeSnapshot.layers.length);
      expect(
        afterSnapshot.layers.first.nodes
            .map((node) => node.id)
            .toList(growable: false),
        beforeSnapshot.layers.first.nodes
            .map((node) => node.id)
            .toList(growable: false),
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
    'invariant pre-check failure in signals-only branch keeps commit and effects unchanged',
    () async {
      final controller = SceneControllerV2(initialSnapshot: twoRectSnapshot());
      addTearDown(controller.dispose);

      final beforeCommit = controller.debugCommitRevision;
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

      controller.debugBeforeInvariantPrecheckHook = () {
        throw StateError('forced invariant pre-check failure');
      };

      expect(
        () => controller.write<void>((writer) {
          writer.writeSignalEnqueue(type: 'signals-only.fail');
        }),
        throwsStateError,
      );
      await pumpEventQueue(times: 2);

      expect(controller.debugCommitRevision, beforeCommit);
      expect(controller.controllerEpoch, beforeEpoch);
      expect(controller.structuralRevision, beforeStructural);
      expect(controller.boundsRevision, beforeBounds);
      expect(controller.visualRevision, beforeVisual);
      expect(signals, isEmpty);
      expect(notifications, 0);
    },
  );

  test(
    'requestRepaint inside successful no-op write schedules one notification',
    () async {
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

  test('node patch changing isSelectable keeps explicitly selected ids', () {
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

    expect(controller.selectedNodeIds, const <NodeId>{'r1'});
    expect(controller.debugLastChangeSet.selectionChanged, isTrue);
  });

  test(
    'selectAll with onlySelectable false preserves non-selectable ids after commit',
    () {
      final controller = SceneControllerV2(
        initialSnapshot: SceneSnapshot(
          layers: <ContentLayerSnapshot>[
            ContentLayerSnapshot(
              nodes: const <NodeSnapshot>[
                RectNodeSnapshot(id: 'selectable', size: Size(10, 10)),
                RectNodeSnapshot(
                  id: 'nonsel',
                  size: Size(10, 10),
                  isSelectable: false,
                ),
              ],
            ),
          ],
        ),
      );
      addTearDown(controller.dispose);

      controller.commands.writeSelectionSelectAll(onlySelectable: false);

      expect(controller.selectedNodeIds, const <NodeId>{
        'selectable',
        'nonsel',
      });
    },
  );

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
          layers: <ContentLayerSnapshot>[
            ContentLayerSnapshot(
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

  test('initialSnapshot rejects malformed snapshots with SceneDataException', () {
    final malformedCases =
        <({SceneSnapshot snapshot, String field, String expectedMessage})>[
          (
            snapshot: SceneSnapshot(
              backgroundLayer: BackgroundLayerSnapshot(
                nodes: const <NodeSnapshot>[
                  RectNodeSnapshot(id: 'dup', size: Size(1, 1)),
                ],
              ),
              layers: <ContentLayerSnapshot>[
                ContentLayerSnapshot(
                  nodes: const <NodeSnapshot>[
                    RectNodeSnapshot(id: 'dup', size: Size(2, 2)),
                  ],
                ),
              ],
            ),
            field: 'layers[0].nodes[0].id',
            expectedMessage: 'Must be unique across scene layers.',
          ),
          (
            snapshot: SceneSnapshot(
              layers: <ContentLayerSnapshot>[
                ContentLayerSnapshot(
                  nodes: const <NodeSnapshot>[
                    PathNodeSnapshot(id: 'p1', svgPathData: 'not-a-path'),
                  ],
                ),
              ],
            ),
            field: 'layers[0].nodes[0].svgPathData',
            expectedMessage:
                'Field layers[0].nodes[0].svgPathData must be valid SVG path data.',
          ),
          (
            snapshot: SceneSnapshot(
              palette: ScenePaletteSnapshot(penColors: const <Color>[]),
            ),
            field: 'palette.penColors',
            expectedMessage: 'Field palette.penColors must not be empty.',
          ),
        ];

    for (final malformed in malformedCases) {
      expect(
        () => SceneControllerV2(initialSnapshot: malformed.snapshot),
        throwsA(
          predicate(
            (e) =>
                e is SceneDataException &&
                e.path == malformed.field &&
                e.message == malformed.expectedMessage,
          ),
        ),
      );
    }
  });

  test(
    'writeReplaceScene rejects malformed snapshot without state changes or effects',
    () async {
      final controller = SceneControllerV2(initialSnapshot: twoRectSnapshot());
      addTearDown(controller.dispose);

      controller.write<void>((writer) {
        writer.writeSelectionReplace(const <NodeId>{'r1'});
      });
      await pumpEventQueue();
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

      final malformed = SceneSnapshot(
        layers: <ContentLayerSnapshot>[
          ContentLayerSnapshot(
            nodes: const <NodeSnapshot>[
              RectNodeSnapshot(
                id: 'bad',
                size: Size(10, 10),
                transform: Transform2D(
                  a: double.infinity,
                  b: 0,
                  c: 0,
                  d: 1,
                  tx: 0,
                  ty: 0,
                ),
              ),
            ],
          ),
        ],
      );

      expect(
        () => controller.writeReplaceScene(malformed),
        throwsA(
          predicate(
            (e) =>
                e is SceneDataException &&
                e.path == 'layers[0].nodes[0].transform.a' &&
                e.message ==
                    'Field layers[0].nodes[0].transform.a must be finite.',
          ),
        ),
      );
      await pumpEventQueue(times: 2);

      expect(controller.snapshot.layers.length, beforeSnapshot.layers.length);
      expect(
        controller.snapshot.layers.first.nodes
            .map((node) => node.id)
            .toList(growable: false),
        beforeSnapshot.layers.first.nodes
            .map((node) => node.id)
            .toList(growable: false),
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

  test('spatial index updates incrementally on bounds revision change', () {
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
    expect(controller.debugSpatialIndexBuildCount, 1);
    expect(controller.debugSpatialIndexIncrementalApplyCount, 1);
  });

  test(
    'single-node transform stays incremental without full materialization',
    () {
      final controller = SceneControllerV2(initialSnapshot: twoRectSnapshot());
      addTearDown(controller.dispose);

      controller.querySpatialCandidates(const Rect.fromLTWH(0, 0, 0, 0));
      expect(controller.debugSpatialIndexBuildCount, 1);

      controller.write<void>((writer) {
        final changed = writer.writeNodeTransformSet(
          'r1',
          Transform2D.translation(const Offset(100, 0)),
        );
        expect(changed, isTrue);
      });

      final moved = controller.querySpatialCandidates(
        const Rect.fromLTWH(100, 0, 0, 0),
      );
      expect(moved.map((candidate) => candidate.node.id), contains('r1'));
      expect(controller.debugSpatialIndexBuildCount, 1);
      expect(controller.debugSpatialIndexIncrementalApplyCount, 1);
      expect(controller.debugNodeIdSetMaterializations, 0);
      expect(controller.debugNodeLocatorMaterializations, 0);
    },
  );

  test('spatial index updates incrementally on hitPadding change', () {
    final controller = SceneControllerV2(initialSnapshot: twoRectSnapshot());
    addTearDown(controller.dispose);

    final beforeQuery = controller.querySpatialCandidates(
      const Rect.fromLTWH(30, 0, 0, 0),
    );
    expect(beforeQuery, isEmpty);
    expect(controller.debugSpatialIndexBuildCount, 1);

    controller.write<void>((writer) {
      writer.writeNodePatch(
        const RectNodePatch(
          id: 'r1',
          common: CommonNodePatch(hitPadding: PatchField<double>.value(22)),
        ),
      );
    });

    final afterQuery = controller.querySpatialCandidates(
      const Rect.fromLTWH(30, 0, 0, 0),
    );
    expect(afterQuery.map((candidate) => candidate.node.id), contains('r1'));
    expect(
      afterQuery.map((candidate) => candidate.node.id),
      isNot(contains('r2')),
    );
    expect(controller.debugSpatialIndexBuildCount, 1);
    expect(controller.debugSpatialIndexIncrementalApplyCount, 1);
  });

  test('spatial index handles huge node and updates incrementally', () {
    final controller = SceneControllerV2(
      initialSnapshot: SceneSnapshot(
        layers: <ContentLayerSnapshot>[
          ContentLayerSnapshot(
            nodes: const <NodeSnapshot>[
              RectNodeSnapshot(id: 'huge', size: Size(10000, 10000)),
            ],
          ),
        ],
      ),
    );
    addTearDown(controller.dispose);

    final initial = controller.querySpatialCandidates(
      const Rect.fromLTWH(0, 0, 10, 10),
    );
    expect(initial.map((candidate) => candidate.node.id), <NodeId>['huge']);
    expect(controller.debugSpatialIndexBuildCount, 1);

    controller.write<void>((writer) {
      writer.writeSelectionReplace(const <NodeId>{'huge'});
      writer.writeSelectionTranslate(const Offset(2e6, 0));
    });

    final oldProbe = controller.querySpatialCandidates(
      const Rect.fromLTWH(0, 0, 10, 10),
    );
    expect(oldProbe, isEmpty);

    final movedProbe = controller.querySpatialCandidates(
      const Rect.fromLTWH(2e6, 0, 10, 10),
    );
    expect(movedProbe.map((candidate) => candidate.node.id), <NodeId>['huge']);
    expect(controller.debugSpatialIndexBuildCount, 1);
    expect(controller.debugSpatialIndexIncrementalApplyCount, 1);
  });

  test('spatial index invalidates and rebuilds after replaceScene', () {
    final controller = SceneControllerV2(initialSnapshot: twoRectSnapshot());
    addTearDown(controller.dispose);

    final beforeQuery = controller.querySpatialCandidates(
      const Rect.fromLTWH(0, 0, 0, 0),
    );
    expect(beforeQuery, isNotEmpty);
    expect(controller.debugSpatialIndexBuildCount, 1);

    controller.writeReplaceScene(
      SceneSnapshot(
        layers: <ContentLayerSnapshot>[
          ContentLayerSnapshot(
            nodes: const <NodeSnapshot>[
              RectNodeSnapshot(id: 'fresh', size: Size(10, 10)),
            ],
          ),
        ],
      ),
    );

    final afterQuery = controller.querySpatialCandidates(
      const Rect.fromLTWH(0, 0, 0, 0),
    );
    expect(afterQuery.map((candidate) => candidate.node.id), <NodeId>['fresh']);
    expect(controller.debugSpatialIndexBuildCount, 2);
    expect(controller.debugSpatialIndexIncrementalApplyCount, 0);
  });

  test(
    'spatial index stays consistent across insert-move-erase-replace-move',
    () {
      final controller = SceneControllerV2(
        initialSnapshot: SceneSnapshot(
          layers: <ContentLayerSnapshot>[ContentLayerSnapshot()],
        ),
      );
      addTearDown(controller.dispose);

      Set<NodeId> queryIds(Rect probe) {
        return controller
            .querySpatialCandidates(probe)
            .map((candidate) => candidate.node.id)
            .toSet();
      }

      void expectStableQuery({
        required Rect probe,
        required Set<NodeId> expectedPresent,
        required Set<NodeId> expectedAbsent,
      }) {
        final first = queryIds(probe);
        final second = queryIds(probe);
        expect(first, expectedPresent);
        expect(second, expectedPresent);
        for (final id in expectedAbsent) {
          expect(first.contains(id), isFalse);
          expect(second.contains(id), isFalse);
        }
      }

      const originProbe = Rect.fromLTWH(0, 0, 12, 12);
      const movedProbe = Rect.fromLTWH(60, 0, 12, 12);
      const replacedProbe = Rect.fromLTWH(200, 0, 12, 12);
      const movedAfterReplaceProbe = Rect.fromLTWH(260, 0, 12, 12);

      // Build index for the initial empty document.
      expectStableQuery(
        probe: originProbe,
        expectedPresent: const <NodeId>{},
        expectedAbsent: const <NodeId>{'r1', 'fresh'},
      );
      expect(controller.debugSpatialIndexBuildCount, 1);
      expect(controller.debugSpatialIndexIncrementalApplyCount, 0);

      controller.write<void>((writer) {
        writer.writeNodeInsert(
          RectNodeSpec(id: 'r1', size: const Size(10, 10)),
        );
      });
      expectStableQuery(
        probe: originProbe,
        expectedPresent: const <NodeId>{'r1'},
        expectedAbsent: const <NodeId>{'fresh'},
      );

      controller.write<void>((writer) {
        writer.writeSelectionReplace(const <NodeId>{'r1'});
        writer.writeSelectionTranslate(const Offset(60, 0));
      });
      expectStableQuery(
        probe: originProbe,
        expectedPresent: const <NodeId>{},
        expectedAbsent: const <NodeId>{'r1', 'fresh'},
      );
      expectStableQuery(
        probe: movedProbe,
        expectedPresent: const <NodeId>{'r1'},
        expectedAbsent: const <NodeId>{'fresh'},
      );

      controller.write<void>((writer) {
        expect(writer.writeNodeErase('r1'), isTrue);
      });
      expectStableQuery(
        probe: movedProbe,
        expectedPresent: const <NodeId>{},
        expectedAbsent: const <NodeId>{'r1', 'fresh'},
      );

      final buildCountBeforeReplace = controller.debugSpatialIndexBuildCount;
      controller.writeReplaceScene(
        SceneSnapshot(
          layers: <ContentLayerSnapshot>[
            ContentLayerSnapshot(
              nodes: <NodeSnapshot>[
                RectNodeSnapshot(
                  id: 'fresh',
                  size: const Size(10, 10),
                  transform: Transform2D.translation(Offset(200, 0)),
                ),
              ],
            ),
          ],
        ),
      );
      expectStableQuery(
        probe: replacedProbe,
        expectedPresent: const <NodeId>{'fresh'},
        expectedAbsent: const <NodeId>{'r1'},
      );
      expect(
        controller.debugSpatialIndexBuildCount,
        buildCountBeforeReplace + 1,
      );

      controller.write<void>((writer) {
        writer.writeSelectionReplace(const <NodeId>{'fresh'});
        writer.writeSelectionTranslate(const Offset(60, 0));
      });
      expectStableQuery(
        probe: replacedProbe,
        expectedPresent: const <NodeId>{},
        expectedAbsent: const <NodeId>{'fresh', 'r1'},
      );
      expectStableQuery(
        probe: movedAfterReplaceProbe,
        expectedPresent: const <NodeId>{'fresh'},
        expectedAbsent: const <NodeId>{'r1'},
      );
    },
  );

  test(
    'spatial index keeps candidate indices after erase in middle of layer',
    () {
      final controller = SceneControllerV2(
        initialSnapshot: SceneSnapshot(
          layers: <ContentLayerSnapshot>[
            ContentLayerSnapshot(
              nodes: const <NodeSnapshot>[
                RectNodeSnapshot(id: 'r1', size: Size(10, 10)),
                RectNodeSnapshot(id: 'r2', size: Size(10, 10)),
                RectNodeSnapshot(id: 'r3', size: Size(10, 10)),
              ],
            ),
          ],
        ),
      );
      addTearDown(controller.dispose);

      controller.querySpatialCandidates(const Rect.fromLTWH(0, 0, 0, 0));
      expect(controller.debugSpatialIndexBuildCount, 1);

      controller.write<void>((writer) {
        writer.writeNodeErase('r2');
      });

      final candidates = controller.querySpatialCandidates(
        const Rect.fromLTWH(0, 0, 0, 0),
      );
      final byId = <NodeId, SceneSpatialCandidate>{
        for (final candidate in candidates) candidate.node.id: candidate,
      };
      expect(byId.containsKey('r1'), isTrue);
      expect(byId.containsKey('r2'), isFalse);
      expect(byId.containsKey('r3'), isTrue);
      expect(byId['r1']!.layerIndex, 0);
      expect(byId['r1']!.nodeIndex, 0);
      expect(byId['r3']!.layerIndex, 0);
      expect(byId['r3']!.nodeIndex, 1);
      expect(controller.resolveSpatialCandidateNode(byId['r1']!), isNotNull);
      expect(controller.resolveSpatialCandidateNode(byId['r3']!), isNotNull);
      expect(controller.debugSpatialIndexBuildCount, 1);
      expect(controller.debugSpatialIndexIncrementalApplyCount, 1);
    },
  );

  test(
    'spatial index stays incremental across bulk draw-erase-redraw cycle',
    () {
      final controller = SceneControllerV2(
        initialSnapshot: SceneSnapshot(
          layers: <ContentLayerSnapshot>[ContentLayerSnapshot()],
        ),
      );
      addTearDown(controller.dispose);

      const batchSize = 120;
      final firstBandProbe = Rect.fromLTWH(-32, -32, batchSize * 16 + 64, 64);
      final allBandsProbe = Rect.fromLTWH(-32, -32, batchSize * 16 + 64, 128);

      controller.querySpatialCandidates(const Rect.fromLTWH(0, 0, 1, 1));
      expect(controller.debugSpatialIndexBuildCount, 1);
      expect(controller.debugSpatialIndexIncrementalApplyCount, 0);

      controller.write<void>((writer) {
        for (var i = 0; i < batchSize; i++) {
          writer.writeNodeInsert(
            RectNodeSpec(
              id: 'a$i',
              size: const Size(8, 8),
              transform: Transform2D.translation(Offset(i * 16, 0)),
            ),
          );
        }
      });

      final afterFirstDraw = controller.querySpatialCandidates(firstBandProbe);
      expect(
        afterFirstDraw.map((candidate) => candidate.node.id).toSet().length,
        batchSize,
      );
      expect(controller.debugSpatialIndexBuildCount, 1);
      expect(controller.debugSpatialIndexIncrementalApplyCount, 1);

      controller.write<void>((writer) {
        for (var i = 0; i < batchSize; i += 2) {
          expect(writer.writeNodeErase('a$i'), isTrue);
        }
      });

      final afterErase = controller.querySpatialCandidates(firstBandProbe);
      final afterEraseIds = afterErase
          .map((candidate) => candidate.node.id)
          .toSet();
      expect(afterEraseIds.length, batchSize ~/ 2);
      expect(afterEraseIds.contains('a0'), isFalse);
      expect(afterEraseIds.contains('a1'), isTrue);
      expect(controller.debugSpatialIndexBuildCount, 1);
      expect(controller.debugSpatialIndexIncrementalApplyCount, 2);

      controller.write<void>((writer) {
        for (var i = 0; i < batchSize; i++) {
          writer.writeNodeInsert(
            RectNodeSpec(
              id: 'b$i',
              size: const Size(8, 8),
              transform: Transform2D.translation(Offset(i * 16, 64)),
            ),
          );
        }
      });

      final afterSecondDraw = controller.querySpatialCandidates(allBandsProbe);
      final idsAfterSecondDraw = afterSecondDraw
          .map((candidate) => candidate.node.id)
          .toSet();
      expect(idsAfterSecondDraw.length, batchSize + batchSize ~/ 2);
      expect(idsAfterSecondDraw.contains('b0'), isTrue);
      expect(idsAfterSecondDraw.contains('a1'), isTrue);
      expect(idsAfterSecondDraw.contains('a0'), isFalse);
      expect(controller.debugSpatialIndexBuildCount, 1);
      expect(controller.debugSpatialIndexIncrementalApplyCount, 3);

      final repeatedQuery = controller.querySpatialCandidates(allBandsProbe);
      expect(repeatedQuery.length, afterSecondDraw.length);
      expect(controller.debugSpatialIndexBuildCount, 1);
      expect(controller.debugSpatialIndexIncrementalApplyCount, 3);
    },
  );

  test('no-op hitPadding patch does not bump bounds revision', () {
    final controller = SceneControllerV2(initialSnapshot: twoRectSnapshot());
    addTearDown(controller.dispose);

    final beforeBounds = controller.boundsRevision;

    controller.write<void>((writer) {
      writer.writeNodePatch(
        const RectNodePatch(
          id: 'r1',
          common: CommonNodePatch(hitPadding: PatchField<double>.value(0)),
        ),
      );
    });

    expect(controller.boundsRevision, beforeBounds);
    expect(controller.debugLastChangeSet.boundsChanged, isFalse);
    expect(controller.debugLastChangeSet.hitGeometryChangedIds, isEmpty);
    expect(controller.debugSceneShallowClones, 0);
    expect(controller.debugLayerShallowClones, 0);
    expect(controller.debugNodeClones, 0);
  });

  test(
    'text layout patch recomputes derived size and bumps bounds revision',
    () {
      final controller = SceneControllerV2(
        initialSnapshot: SceneSnapshot(
          layers: <ContentLayerSnapshot>[
            ContentLayerSnapshot(
              nodes: const <NodeSnapshot>[
                TextNodeSnapshot(
                  id: 't1',
                  text: 'hello',
                  size: Size(1, 1),
                  fontSize: 12,
                  color: Color(0xFF000000),
                ),
              ],
            ),
          ],
        ),
      );
      addTearDown(controller.dispose);

      final beforeNode =
          controller.snapshot.layers.first.nodes.single as TextNodeSnapshot;
      final beforeSize = beforeNode.size;
      final beforeBoundsRevision = controller.boundsRevision;

      controller.write<void>((writer) {
        writer.writeNodePatch(
          const TextNodePatch(id: 't1', fontSize: PatchField<double>.value(36)),
        );
      });

      final afterNode =
          controller.snapshot.layers.first.nodes.single as TextNodeSnapshot;
      expect(afterNode.size.height, greaterThan(beforeSize.height));
      expect(controller.boundsRevision, beforeBoundsRevision + 1);
      expect(controller.debugLastChangeSet.boundsChanged, isTrue);
      expect(
        controller.debugLastChangeSet.hitGeometryChangedIds,
        contains('t1'),
      );
    },
  );

  test('text visual-only patch keeps bounds revision unchanged', () {
    final controller = SceneControllerV2(
      initialSnapshot: SceneSnapshot(
        layers: <ContentLayerSnapshot>[
          ContentLayerSnapshot(
            nodes: const <NodeSnapshot>[
              TextNodeSnapshot(
                id: 't1',
                text: 'hello',
                size: Size(80, 24),
                fontSize: 24,
                color: Color(0xFF000000),
              ),
            ],
          ),
        ],
      ),
    );
    addTearDown(controller.dispose);

    final beforeBoundsRevision = controller.boundsRevision;

    controller.write<void>((writer) {
      writer.writeNodePatch(
        const TextNodePatch(
          id: 't1',
          color: PatchField<Color>.value(Color(0xFF00AA00)),
        ),
      );
    });

    expect(controller.boundsRevision, beforeBoundsRevision);
    expect(controller.debugLastChangeSet.boundsChanged, isFalse);
    expect(controller.debugLastChangeSet.hitGeometryChangedIds, isEmpty);
  });

  test('camera offset write does not clone layers or nodes', () {
    final controller = SceneControllerV2(initialSnapshot: twoRectSnapshot());
    addTearDown(controller.dispose);

    controller.write<void>((writer) {
      writer.writeCameraOffset(const Offset(20, 10));
    });

    expect(controller.debugSceneShallowClones, 1);
    expect(controller.debugLayerShallowClones, 0);
    expect(controller.debugNodeClones, 0);
  });

  test('single node patch clones exactly one layer and one node', () {
    final controller = SceneControllerV2(initialSnapshot: twoRectSnapshot());
    addTearDown(controller.dispose);

    controller.write<void>((writer) {
      writer.writeNodePatch(
        const RectNodePatch(id: 'r1', strokeWidth: PatchField<double>.value(2)),
      );
    });

    expect(controller.debugSceneShallowClones, 1);
    expect(controller.debugLayerShallowClones, 1);
    expect(controller.debugNodeClones, 1);
  });

  test('opacity patch commit does not materialize allNodeIds', () {
    final controller = SceneControllerV2(initialSnapshot: twoRectSnapshot());
    addTearDown(controller.dispose);

    controller.write<void>((writer) {
      writer.writeNodePatch(
        const RectNodePatch(
          id: 'r1',
          common: CommonNodePatch(opacity: PatchField<double>.value(0.5)),
        ),
      );
    });

    expect(controller.debugNodeIdSetMaterializations, 0);
    expect(controller.debugNodeLocatorMaterializations, 0);
  });

  test('structural commit materializes allNodeIds once', () {
    final controller = SceneControllerV2(initialSnapshot: twoRectSnapshot());
    addTearDown(controller.dispose);

    controller.write<void>((writer) {
      writer.writeNodeInsert(RectNodeSpec(size: const Size(8, 8)));
    });

    expect(controller.debugNodeIdSetMaterializations, 1);
    expect(controller.debugNodeLocatorMaterializations, 1);
  });

  test('node id seed stays monotonic after deleting max node-* id', () {
    final controller = SceneControllerV2(
      initialSnapshot: SceneSnapshot(
        layers: <ContentLayerSnapshot>[
          ContentLayerSnapshot(
            nodes: const <NodeSnapshot>[
              RectNodeSnapshot(id: 'node-1', size: Size(10, 10)),
              RectNodeSnapshot(id: 'node-9', size: Size(12, 12)),
            ],
          ),
        ],
      ),
    );
    addTearDown(controller.dispose);

    controller.write<void>((writer) {
      writer.writeNodeErase('node-9');
    });

    late final NodeId generatedId;
    controller.write<void>((writer) {
      generatedId = writer.writeNodeInsert(
        RectNodeSpec(size: const Size(6, 6)),
      );
    });

    expect(generatedId, 'node-10');
  });

  test('nextInstanceRevision stays monotonic across replaceScene', () {
    final controller = SceneControllerV2(
      initialSnapshot: SceneSnapshot(
        layers: <ContentLayerSnapshot>[
          ContentLayerSnapshot(
            nodes: const <NodeSnapshot>[
              RectNodeSnapshot(
                id: 'high',
                instanceRevision: 100,
                size: Size(10, 10),
              ),
            ],
          ),
        ],
      ),
    );
    addTearDown(controller.dispose);

    controller.writeReplaceScene(
      SceneSnapshot(
        layers: <ContentLayerSnapshot>[
          ContentLayerSnapshot(
            nodes: const <NodeSnapshot>[
              RectNodeSnapshot(
                id: 'low',
                instanceRevision: 3,
                size: Size(10, 10),
              ),
            ],
          ),
        ],
      ),
    );

    late final NodeId insertedId;
    controller.write<void>((writer) {
      insertedId = writer.writeNodeInsert(RectNodeSpec(size: const Size(4, 4)));
    });

    final inserted = controller.snapshot.layers
        .expand((layer) => layer.nodes)
        .firstWhere((node) => node.id == insertedId);
    expect(inserted.instanceRevision, greaterThanOrEqualTo(101));
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

  test(
    'resolveSpatialCandidateNode rejects candidate from background locator',
    () {
      final controller = SceneControllerV2(
        initialSnapshot: SceneSnapshot(
          backgroundLayer: BackgroundLayerSnapshot(
            nodes: const <NodeSnapshot>[
              RectNodeSnapshot(id: 'bg-node', size: Size(10, 10)),
            ],
          ),
          layers: <ContentLayerSnapshot>[ContentLayerSnapshot()],
        ),
      );
      addTearDown(controller.dispose);

      final backgroundNode = RectNode(id: 'bg-node', size: const Size(10, 10));
      final backgroundCandidate = SceneSpatialCandidate(
        layerIndex: -1,
        nodeIndex: 0,
        node: backgroundNode,
        candidateBoundsWorld: backgroundNode.boundsWorld,
      );
      expect(
        controller.resolveSpatialCandidateNode(backgroundCandidate),
        isNull,
      );
    },
  );

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
          layers: <ContentLayerSnapshot>[
            ContentLayerSnapshot(
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
    'signals are delivered before repaint listeners for same commit',
    () async {
      final controller = SceneControllerV2(initialSnapshot: twoRectSnapshot());
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

  test(
    'change listener can trigger follow-up write without nested write error',
    () async {
      final controller = SceneControllerV2(initialSnapshot: twoRectSnapshot());
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

  test(
    'write after dispose throws and keeps state/effects unchanged',
    () async {
      final controller = SceneControllerV2(initialSnapshot: twoRectSnapshot());

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
      final controller = SceneControllerV2(initialSnapshot: twoRectSnapshot());

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
      final controller = SceneControllerV2(initialSnapshot: twoRectSnapshot());

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
      final controller = SceneControllerV2(
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
