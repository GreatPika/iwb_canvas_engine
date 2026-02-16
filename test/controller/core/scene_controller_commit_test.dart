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
    'write rollback keeps scene/revisions unchanged and emits no signals',
    () async {
      final controller = SceneControllerCore(
        initialSnapshot: twoRectSnapshot(),
      );
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
      final controller = SceneControllerCore(
        initialSnapshot: twoRectSnapshot(),
      );
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
      final controller = SceneControllerCore(
        initialSnapshot: twoRectSnapshot(),
      );
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
      final controller = SceneControllerCore(
        initialSnapshot: twoRectSnapshot(),
      );
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
      final controller = SceneControllerCore(
        initialSnapshot: twoRectSnapshot(),
      );
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

  test('changeset tracks added removed and updated node ids', () {
    final controller = SceneControllerCore(initialSnapshot: twoRectSnapshot());
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
    final controller = SceneControllerCore(initialSnapshot: twoRectSnapshot());
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
    final controller = SceneControllerCore(initialSnapshot: twoRectSnapshot());
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
      final controller = SceneControllerCore(
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
      final controller = SceneControllerCore(
        initialSnapshot: twoRectSnapshot(),
      );
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
        () => SceneControllerCore(initialSnapshot: malformed.snapshot),
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
      final controller = SceneControllerCore(
        initialSnapshot: twoRectSnapshot(),
      );
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
}
