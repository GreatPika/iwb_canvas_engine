import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine/src/contract/internal/snapshot_fast_path.dart';
import 'package:iwb_canvas_engine/src/contract/internal/unsafe_snapshot_materialization.dart';
import 'package:iwb_canvas_engine/src/controller/change_set.dart';
import 'package:iwb_canvas_engine/src/controller/committed_store_state.dart';
import 'package:iwb_canvas_engine/src/controller/internal/repaint_flag.dart';
import 'package:iwb_canvas_engine/src/controller/internal/signals_buffer.dart';
import 'package:iwb_canvas_engine/src/controller/internal/spatial_index_cache.dart';
import 'package:iwb_canvas_engine/src/controller/scene_controller_commit_debug.dart';
import 'package:iwb_canvas_engine/src/controller/scene_controller_commit_execution.dart';
import 'package:iwb_canvas_engine/src/controller/scene_controller_commit_plan.dart';
import 'package:iwb_canvas_engine/src/controller/scene_store_controller.dart';
import 'package:iwb_canvas_engine/src/controller/store.dart';
import 'package:iwb_canvas_engine/src/core/nodes.dart';
import 'package:iwb_canvas_engine/src/core/scene.dart';
import 'package:iwb_canvas_engine/src/core/scene_limits.dart'
    show kMaxContentLayersPerScene, sceneThicknessMax;
import 'package:iwb_canvas_engine/src/model/document.dart';
import 'package:iwb_canvas_engine/src/model/document_clone.dart';

// INV:INV-ENG-TXN-ATOMIC-COMMIT
// INV:INV-ENG-EPOCH-INVALIDATION
// INV:INV-ENG-SIGNALS-AFTER-COMMIT
// INV:INV-ENG-ID-INDEX-FROM-SCENE
// INV:INV-ENG-TXN-COPY-ON-WRITE
// INV:INV-ENG-TXN-WRITER-LIFETIME
// INV:INV-ENG-TEXT-SIZE-DERIVED
// INV:INV-ENG-DISPOSE-FAIL-FAST
// INV:INV-ENG-RUNTIME-SCENE-VALIDITY-BACKSTOP

void main() {
  SceneSnapshot duplicateNodeSnapshotFromInternalBypass() {
    return unsafeMaterializeSceneSnapshot(
      sceneSnapshotBackingFromValidated(
        backgroundLayer: backgroundLayerSnapshotBackingFromValidated(
          nodes: <NodeSnapshotBacking>[
            nodeSnapshotBackingOf(
              RectNodeSnapshot(id: 'dup', size: const Size(1, 1)),
            ),
          ],
        ),
        layers: <ContentLayerSnapshotBacking>[
          contentLayerSnapshotBackingFromValidated(
            id: 'layer-auto-1',
            nodes: <NodeSnapshotBacking>[
              nodeSnapshotBackingOf(
                RectNodeSnapshot(id: 'dup', size: const Size(2, 2)),
              ),
            ],
          ),
        ],
      ),
    );
  }

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

  test(
    'write rollback keeps scene/revisions unchanged and emits no signals',
    () async {
      final controller = SceneStoreController(
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
        () => controller.writeWithSceneWriter<void>((writer) {
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
      final controller = SceneStoreController(
        initialSnapshot: twoRectSnapshot(),
      );
      addTearDown(controller.dispose);

      final beforeCommit = controller.debug.currentCommitRevision;
      final beforeSnapshot = controller.snapshot;

      final signals = <Object>[];
      final sub = controller.signals.listen(signals.add);
      addTearDown(sub.cancel);

      var notifications = 0;
      controller.addListener(() {
        notifications = notifications + 1;
      });

      expect(
        () => controller.writeWithSceneWriter<void>((writer) {
          writer.writeSelectionReplace(const <NodeId>{'r1'});
          writer.writeSignalEnqueue(type: 'will.rollback');
          controller.requestRepaint();
          throw StateError('rollback');
        }),
        throwsStateError,
      );
      await pumpEventQueue(times: 2);

      expect(controller.debug.currentCommitRevision, beforeCommit);
      expect(controller.selectedNodeIds, isEmpty);
      expect(controller.snapshot.layers.length, beforeSnapshot.layers.length);
      expect(signals, isEmpty);
      expect(notifications, 0);
    },
  );

  test('debug hook accessors proxy runtime debug state', () {
    final controller = SceneStoreController(initialSnapshot: twoRectSnapshot());
    addTearDown(controller.dispose);

    expect(controller.debug.beforeInvariantPrecheckHook, isNull);
    expect(controller.debug.beforeSpatialPrepareCommitHook, isNull);
    expect(controller.debug.beforeTxnContextCreateHook, isNull);

    void invariantHook() {}
    void spatialHook() {}
    void txnCreateHook() {}

    controller.debug.beforeInvariantPrecheckHook = invariantHook;
    controller.debug.beforeSpatialPrepareCommitHook = spatialHook;
    controller.debug.beforeTxnContextCreateHook = txnCreateHook;

    expect(controller.debug.beforeInvariantPrecheckHook, same(invariantHook));
    expect(controller.debug.beforeSpatialPrepareCommitHook, same(spatialHook));
    expect(controller.debug.beforeTxnContextCreateHook, same(txnCreateHook));

    controller.debug.beforeInvariantPrecheckHook = null;
    controller.debug.beforeSpatialPrepareCommitHook = null;
    controller.debug.beforeTxnContextCreateHook = null;

    expect(controller.debug.beforeInvariantPrecheckHook, isNull);
    expect(controller.debug.beforeSpatialPrepareCommitHook, isNull);
    expect(controller.debug.beforeTxnContextCreateHook, isNull);
  });

  test(
    'invariant pre-check failure in state-change branch keeps store and effects unchanged',
    () async {
      final controller = SceneStoreController(
        initialSnapshot: twoRectSnapshot(),
      );
      addTearDown(controller.dispose);

      final beforeSnapshot = controller.snapshot;
      final beforeEpoch = controller.controllerEpoch;
      final beforeStructural = controller.structuralRevision;
      final beforeBounds = controller.boundsRevision;
      final beforeVisual = controller.visualRevision;
      final beforeCommit = controller.debug.currentCommitRevision;
      final beforeSelection = controller.selectedNodeIds;

      final signals = <Object>[];
      final sub = controller.signals.listen(signals.add);
      addTearDown(sub.cancel);

      var notifications = 0;
      controller.addListener(() {
        notifications = notifications + 1;
      });

      controller.debug.beforeInvariantPrecheckHook = () {
        throw StateError('forced invariant pre-check failure');
      };

      expect(
        () => controller.writeWithSceneWriter<void>((writer) {
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
      expect(controller.debug.currentCommitRevision, beforeCommit);
      expect(controller.selectedNodeIds, beforeSelection);
      expect(signals, isEmpty);
      expect(notifications, 0);
    },
  );

  test(
    'spatial prepare failure in state-change branch keeps store and effects unchanged',
    () async {
      final controller = SceneStoreController(
        initialSnapshot: twoRectSnapshot(),
      );
      addTearDown(controller.dispose);

      final beforeSnapshot = controller.snapshot;
      final beforeEpoch = controller.controllerEpoch;
      final beforeStructural = controller.structuralRevision;
      final beforeBounds = controller.boundsRevision;
      final beforeVisual = controller.visualRevision;
      final beforeCommit = controller.debug.currentCommitRevision;
      final beforeSelection = controller.selectedNodeIds;

      final signals = <Object>[];
      final sub = controller.signals.listen(signals.add);
      addTearDown(sub.cancel);

      var notifications = 0;
      controller.addListener(() {
        notifications = notifications + 1;
      });

      controller.debug.beforeSpatialPrepareCommitHook = () {
        throw StateError('forced spatial prepare failure');
      };

      expect(
        () => controller.writeWithSceneWriter<void>((writer) {
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
      expect(controller.debug.currentCommitRevision, beforeCommit);
      expect(controller.selectedNodeIds, beforeSelection);
      expect(signals, isEmpty);
      expect(notifications, 0);
    },
  );

  test(
    'invariant pre-check failure in signals-only branch keeps commit and effects unchanged',
    () async {
      final controller = SceneStoreController(
        initialSnapshot: twoRectSnapshot(),
      );
      addTearDown(controller.dispose);

      final beforeCommit = controller.debug.currentCommitRevision;
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

      controller.debug.beforeInvariantPrecheckHook = () {
        throw StateError('forced invariant pre-check failure');
      };

      expect(
        () => controller.writeWithSceneWriter<void>((writer) {
          writer.writeSignalEnqueue(type: 'signals-only.fail');
        }),
        throwsStateError,
      );
      await pumpEventQueue(times: 2);

      expect(controller.debug.currentCommitRevision, beforeCommit);
      expect(controller.controllerEpoch, beforeEpoch);
      expect(controller.structuralRevision, beforeStructural);
      expect(controller.boundsRevision, beforeBounds);
      expect(controller.visualRevision, beforeVisual);
      expect(signals, isEmpty);
      expect(notifications, 0);
    },
  );

  test(
    'commit plan rejects invalid runtime node state before applying committed store',
    () {
      final store = SceneStore(
        sceneDoc: txnSceneFromSnapshot(twoRectSnapshot()),
      );
      final originalScene = store.sceneDoc;
      final originalCommitRevision = store.commitRevision;
      final invalidScene = txnCloneScene(store.sceneDoc);
      invalidScene.layers.single.nodes[0] = _RawTransformRectNode(
        id: 'r1',
        rawTransform: const Transform2D(
          a: double.infinity,
          b: 0,
          c: 0,
          d: 1,
          tx: 0,
          ty: 0,
        ),
      );

      final plan = ControllerStateCommitPlan(
        changeSet: ChangeSet()
          ..txnMarkBoundsChanged()
          ..txnTrackUpdated('r1'),
        initialPhases: const <String>[],
        committedStoreState: CommittedStoreState(
          scene: invalidScene,
          selectedNodeIds: store.selectedNodeIds,
          allNodeIds: txnCollectNodeIds(invalidScene),
          nodeLocator: txnBuildNodeLocator(invalidScene),
          layerIndexById: txnBuildLayerIndexById(invalidScene),
          idGeneratorState: store.idGeneratorState,
          revisionState: store.revisionState,
          controllerEpoch: store.controllerEpoch,
          structuralRevision: store.structuralRevision,
          selectionRevision: store.selectionRevision,
          boundsRevision: store.boundsRevision + 1,
          visualRevision: store.visualRevision + 1,
          commitRevision: store.commitRevision + 1,
        ),
      );

      expect(
        () => executeControllerCommitPlan(
          plan: plan,
          context: SceneControllerCommitExecutionContext(
            store: store,
            signalsBuffer: SignalsBuffer(),
            repaintFlag: RepaintFlag(),
            spatialIndexCache: SpatialIndexCache(),
            debugState: SceneControllerCommitDebugState(),
          ),
        ),
        throwsStateError,
      );

      expect(identical(store.sceneDoc, originalScene), isTrue);
      expect(store.commitRevision, originalCommitRevision);
    },
  );

  test(
    'commit plan rejects structural overflow before applying committed store',
    () {
      final store = SceneStore(
        sceneDoc: txnSceneFromSnapshot(twoRectSnapshot()),
      );
      final originalScene = store.sceneDoc;
      final originalCommitRevision = store.commitRevision;
      final invalidScene = txnCloneScene(store.sceneDoc);
      invalidScene.layers.add(ContentLayer(id: 'layer-overflow'));
      for (
        var index = invalidScene.layers.length;
        index <= kMaxContentLayersPerScene;
        index++
      ) {
        invalidScene.layers.add(ContentLayer(id: 'layer-overflow-$index'));
      }

      final plan = ControllerStateCommitPlan(
        changeSet: ChangeSet()..structuralChanged = true,
        initialPhases: const <String>[],
        committedStoreState: CommittedStoreState(
          scene: invalidScene,
          selectedNodeIds: store.selectedNodeIds,
          allNodeIds: txnCollectNodeIds(invalidScene),
          nodeLocator: txnBuildNodeLocator(invalidScene),
          layerIndexById: txnBuildLayerIndexById(invalidScene),
          idGeneratorState: store.idGeneratorState,
          revisionState: store.revisionState,
          controllerEpoch: store.controllerEpoch,
          structuralRevision: store.structuralRevision + 1,
          selectionRevision: store.selectionRevision,
          boundsRevision: store.boundsRevision,
          visualRevision: store.visualRevision + 1,
          commitRevision: store.commitRevision + 1,
        ),
      );

      expect(
        () => executeControllerCommitPlan(
          plan: plan,
          context: SceneControllerCommitExecutionContext(
            store: store,
            signalsBuffer: SignalsBuffer(),
            repaintFlag: RepaintFlag(),
            spatialIndexCache: SpatialIndexCache(),
            debugState: SceneControllerCommitDebugState(),
          ),
        ),
        throwsStateError,
      );

      expect(identical(store.sceneDoc, originalScene), isTrue);
      expect(store.commitRevision, originalCommitRevision);
    },
  );

  test(
    'public stroke insert rejects oversized thickness before committing store',
    () {
      final controller = SceneController(
        initialSnapshot: SceneSnapshot(
          layers: <ContentLayerSnapshot>[ContentLayerSnapshot(id: 'layer-0')],
        ),
      );
      addTearDown(controller.dispose);

      final beforeSnapshot = controller.snapshot;
      final beforeEpoch = controller.controllerEpoch;

      expect(
        () => controller.scene.addNode(
          StrokeNodeSpec(
            id: 'stroke-too-wide',
            points: const <Offset>[Offset(0, 0), Offset(1, 1)],
            thickness: sceneThicknessMax + 1,
            color: const Color(0xFF000000),
          ),
        ),
        throwsStateError,
      );

      expect(controller.snapshot, same(beforeSnapshot));
      expect(controller.controllerEpoch, beforeEpoch);
      expect(controller.snapshot.layers.single.nodes, isEmpty);
    },
  );

  test(
    'public stroke patch rejects oversized thickness before committing store',
    () {
      final controller = SceneController(
        initialSnapshot: SceneSnapshot(
          layers: <ContentLayerSnapshot>[
            ContentLayerSnapshot(
              id: 'layer-0',
              nodes: <NodeSnapshot>[
                StrokeNodeSnapshot(
                  id: 'stroke-0',
                  points: const <Offset>[Offset(0, 0), Offset(1, 1)],
                  thickness: 1,
                  color: const Color(0xFF000000),
                ),
              ],
            ),
          ],
        ),
      );
      addTearDown(controller.dispose);

      final beforeSnapshot = controller.snapshot;
      final beforeEpoch = controller.controllerEpoch;

      expect(
        () => controller.scene.patchNode(
          StrokeNodePatch(
            id: 'stroke-0',
            thickness: PatchField<double>.value(sceneThicknessMax + 1),
          ),
        ),
        throwsStateError,
      );

      final stroke =
          controller.snapshot.layers.single.nodes.single as StrokeNodeSnapshot;
      expect(controller.snapshot, same(beforeSnapshot));
      expect(controller.controllerEpoch, beforeEpoch);
      expect(stroke.thickness, 1);
    },
  );

  test('public line insert still rejects oversized thickness', () {
    final controller = SceneController(
      initialSnapshot: SceneSnapshot(
        layers: <ContentLayerSnapshot>[ContentLayerSnapshot(id: 'layer-0')],
      ),
    );
    addTearDown(controller.dispose);

    final beforeSnapshot = controller.snapshot;

    expect(
      () => controller.scene.addNode(
        LineNodeSpec(
          id: 'line-too-wide',
          start: const Offset(0, 0),
          end: const Offset(1, 1),
          thickness: sceneThicknessMax + 1,
          color: const Color(0xFF000000),
        ),
      ),
      throwsStateError,
    );

    expect(controller.snapshot, same(beforeSnapshot));
  });

  test('initialSnapshot rejects malformed snapshots with SceneDataException', () {
    final malformedCases =
        <({SceneSnapshot snapshot, String field, String expectedMessage})>[
          (
            snapshot: duplicateNodeSnapshotFromInternalBypass(),
            field: 'layers[0].nodes[0].id',
            expectedMessage: 'Must be unique across scene layers.',
          ),
          (
            snapshot: sceneSnapshotFromValidated(
              layers: <ContentLayerSnapshot>[
                contentLayerSnapshotFromValidated(
                  id: 'layer-auto-2',
                  nodes: <NodeSnapshot>[
                    pathNodeSnapshotFromValidated(
                      common: nodeSnapshotCommonFieldsFromValidated(id: 'p1'),
                      fields: (
                        svgPathData: 'not-a-path',
                        fillColor: null,
                        strokeColor: null,
                        strokeWidth: 0,
                        fillRule: PathFillRule.nonZero,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            field: 'layers[0].nodes[0].svgPathData',
            expectedMessage:
                'Field layers[0].nodes[0].svgPathData must be valid SVG path data.',
          ),
          (
            snapshot: unsafeMaterializeSceneSnapshot(
              SceneSnapshotBacking(
                palette: ScenePaletteSnapshotBacking(
                  penColors: const <Color>[],
                ),
              ),
            ),
            field: 'palette.penColors',
            expectedMessage: 'Field palette.penColors must not be empty.',
          ),
        ];

    for (final malformed in malformedCases) {
      expect(
        () => SceneStoreController(initialSnapshot: malformed.snapshot),
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
      final controller = SceneStoreController(
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
      final beforeCommit = controller.debug.currentCommitRevision;
      final beforeSelection = controller.selectedNodeIds;

      final signals = <Object>[];
      final sub = controller.signals.listen(signals.add);
      addTearDown(sub.cancel);

      var notifications = 0;
      controller.addListener(() {
        notifications = notifications + 1;
      });

      final malformed = sceneSnapshotFromValidated(
        layers: <ContentLayerSnapshot>[
          contentLayerSnapshotFromValidated(
            id: 'layer-auto-3',
            nodes: <NodeSnapshot>[
              rectNodeSnapshotFromValidated(
                common: nodeSnapshotCommonFieldsFromValidated(
                  id: 'bad',
                  transform: const Transform2D(
                    a: double.infinity,
                    b: 0,
                    c: 0,
                    d: 1,
                    tx: 0,
                    ty: 0,
                  ),
                ),
                fields: (
                  size: const Size(10, 10),
                  fillColor: null,
                  strokeColor: null,
                  strokeWidth: 0,
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
      expect(controller.debug.currentCommitRevision, beforeCommit);
      expect(controller.selectedNodeIds, beforeSelection);
      expect(signals, isEmpty);
      expect(notifications, 0);
    },
  );
}

final class _RawTransformRectNode extends RectNode {
  _RawTransformRectNode({required super.id, required Transform2D rawTransform})
    : _rawTransform = rawTransform,
      super(size: const Size(10, 10));

  final Transform2D _rawTransform;

  @override
  Transform2D get transform => _rawTransform;
}
