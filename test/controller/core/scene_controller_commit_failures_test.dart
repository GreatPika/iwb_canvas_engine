import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine/src/controller/scene_controller.dart';

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
          id: 'layer-auto-0',
          nodes: <NodeSnapshot>[
            const RectNodeSnapshot(id: 'r1', size: Size(10, 10)),
            const RectNodeSnapshot(id: 'r2', size: Size(12, 12)),
          ],
        ),
      ],
    );
  }

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
                  id: 'layer-auto-1',
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
                  id: 'layer-auto-2',
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
            id: 'layer-auto-3',
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
