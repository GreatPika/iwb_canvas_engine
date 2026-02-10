import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/basic.dart' hide NodeId;
import 'package:iwb_canvas_engine/src/core/nodes.dart';
import 'package:iwb_canvas_engine/src/core/scene.dart';
import 'package:iwb_canvas_engine/src/controller/change_set.dart';
import 'package:iwb_canvas_engine/src/controller/scene_writer.dart';
import 'package:iwb_canvas_engine/src/controller/store.dart';
import 'package:iwb_canvas_engine/src/controller/txn_context.dart';
import 'package:iwb_canvas_engine/src/input/slices/repaint/repaint_slice.dart';
import 'package:iwb_canvas_engine/src/input/slices/signals/signal_event.dart';
import 'package:iwb_canvas_engine/src/input/slices/spatial_index/spatial_index_slice.dart';

void main() {
  test('ChangeSet tracks and clones change state consistently', () {
    final changeSet = ChangeSet();
    expect(changeSet.txnHasAnyChange, isFalse);

    changeSet.txnMarkSelectionChanged();
    changeSet.txnMarkVisualChanged();
    changeSet.txnMarkGridChanged();
    expect(changeSet.selectionChanged, isTrue);
    expect(changeSet.visualChanged, isTrue);
    expect(changeSet.gridChanged, isTrue);
    expect(changeSet.txnHasAnyChange, isTrue);

    changeSet.txnTrackAdded('n1');
    changeSet.txnTrackUpdated('n1');
    expect(changeSet.updatedNodeIds, isEmpty);

    changeSet.txnTrackRemoved('n1');
    expect(changeSet.addedNodeIds, isEmpty);
    expect(changeSet.removedNodeIds, <NodeId>{'n1'});

    changeSet.txnTrackAdded('n1');
    expect(changeSet.removedNodeIds, isEmpty);
    expect(changeSet.addedNodeIds, <NodeId>{'n1'});

    changeSet.txnTrackUpdated('n2');
    expect(changeSet.updatedNodeIds, <NodeId>{'n2'});
    changeSet.txnTrackAdded('n2');
    expect(changeSet.updatedNodeIds, isEmpty);

    changeSet.txnMarkDocumentReplaced();
    expect(changeSet.documentReplaced, isTrue);
    expect(changeSet.structuralChanged, isTrue);
    expect(changeSet.boundsChanged, isTrue);

    final clone = changeSet.txnClone();
    expect(clone.documentReplaced, changeSet.documentReplaced);
    expect(clone.addedNodeIds, changeSet.addedNodeIds);
    expect(clone, isNot(same(changeSet)));
  });

  test('V2Store initializes selections, id set and id seed from scene', () {
    final scene = Scene(
      layers: <Layer>[
        Layer(
          nodes: <SceneNode>[
            RectNode(id: 'node-2', size: const Size(1, 1)),
            RectNode(id: 'node-9', size: const Size(1, 1)),
            RectNode(id: 'custom', size: const Size(1, 1)),
          ],
        ),
      ],
    );

    final incomingSelection = <NodeId>{'node-2'};
    final storeWithSelection = V2Store(
      sceneDoc: scene,
      selectedNodeIds: incomingSelection,
    );
    incomingSelection.add('custom');

    expect(storeWithSelection.selectedNodeIds, <NodeId>{'node-2'});
    expect(
      storeWithSelection.allNodeIds,
      containsAll(<NodeId>{'node-2', 'node-9', 'custom'}),
    );
    expect(storeWithSelection.nodeIdSeed, 10);

    final storeWithoutSelection = V2Store(sceneDoc: Scene());
    expect(storeWithoutSelection.selectedNodeIds, isEmpty);
    expect(storeWithoutSelection.nodeIdSeed, 0);
  });

  test('SceneWriter handles write operations and updates changeset', () {
    final bufferedSignals = <V2BufferedSignal>[];
    final ctx = TxnContext(
      baseScene: Scene(
        layers: <Layer>[
          Layer(
            nodes: <SceneNode>[RectNode(id: 'r1', size: const Size(10, 10))],
          ),
        ],
      ),
      workingSelection: <NodeId>{'r1'},
      workingNodeIds: <NodeId>{'r1'},
      nodeIdSeed: 0,
    );
    final writer = SceneWriter(ctx, txnSignalSink: bufferedSignals.add);

    expect(writer.snapshot.layers.single.nodes.single.id, 'r1');
    expect(writer.selectedNodeIds, <NodeId>{'r1'});

    expect(
      () => writer.writeNodeInsert(
        RectNodeSpec(id: 'r1', size: const Size(1, 1)),
      ),
      throwsStateError,
    );

    final generatedId = writer.writeNodeInsert(
      RectNodeSpec(size: const Size(2, 2)),
    );
    expect(generatedId, 'node-0');
    expect(ctx.changeSet.structuralChanged, isTrue);
    expect(ctx.changeSet.addedNodeIds, contains('node-0'));

    expect(writer.writeNodePatch(const RectNodePatch(id: 'missing')), isFalse);
    expect(writer.writeNodePatch(const RectNodePatch(id: 'r1')), isFalse);
    expect(
      writer.writeNodePatch(
        const RectNodePatch(id: 'r1', strokeWidth: PatchField<double>.value(2)),
      ),
      isTrue,
    );
    expect(ctx.changeSet.updatedNodeIds, contains('r1'));

    expect(writer.writeNodeErase('missing'), isFalse);
    expect(writer.writeNodeErase('r1'), isTrue);
    expect(ctx.changeSet.removedNodeIds, contains('r1'));
    expect(ctx.workingSelection, isNot(contains('r1')));
    expect(ctx.changeSet.selectionChanged, isTrue);

    writer.writeSelectionReplace(<NodeId>{'node-0'});
    writer.writeSelectionReplace(<NodeId>{'node-0'});
    writer.writeSelectionToggle('node-0');
    writer.writeSelectionToggle('node-0');

    expect(writer.writeSelectionTranslate(Offset.zero), 0);
    expect(writer.writeSelectionTranslate(const Offset(5, 0)), 1);

    writer.writeGridEnable(false);
    writer.writeGridEnable(true);
    writer.writeGridCellSize(20);
    writer.writeGridCellSize(24);
    writer.writeBackgroundColor(writer.snapshot.background.color);
    writer.writeBackgroundColor(const Color(0xFFEEEEEE));

    writer.writeSignalEnqueue(
      type: 'custom.signal',
      nodeIds: <NodeId>{'node-0'},
    );
    expect(bufferedSignals.single.type, 'custom.signal');

    writer.writeDocumentReplace(
      SceneSnapshot(
        layers: <LayerSnapshot>[
          LayerSnapshot(
            nodes: const <NodeSnapshot>[
              RectNodeSnapshot(id: 'fresh', size: Size(1, 1)),
            ],
          ),
        ],
      ),
    );
    expect(ctx.workingScene.layers.single.nodes.single.id, 'fresh');
    expect(ctx.workingSelection, isEmpty);
    expect(ctx.changeSet.documentReplaced, isTrue);
  });

  test('SceneWriter covers node-id helpers and selection branches', () {
    final ctx = TxnContext(
      baseScene: Scene(
        layers: <Layer>[
          Layer(
            nodes: <SceneNode>[
              RectNode(id: 'rect-1', size: const Size(10, 10)),
              RectNode(
                id: 'locked',
                size: const Size(10, 10),
                isSelectable: false,
                isDeletable: false,
              ),
            ],
          ),
        ],
      ),
      workingSelection: <NodeId>{'rect-1'},
      workingNodeIds: <NodeId>{'rect-1', 'locked'},
      nodeIdSeed: 2,
    );
    final bufferedSignals = <V2BufferedSignal>[];
    final writer = SceneWriter(ctx, txnSignalSink: bufferedSignals.add);

    expect(writer.writeNewNodeId(), 'node-2');
    expect(writer.writeContainsNodeId('rect-1'), isTrue);
    writer.writeRegisterNodeId('node-extra');
    expect(writer.writeContainsNodeId('node-extra'), isTrue);
    writer.writeUnregisterNodeId('node-extra');
    expect(writer.writeContainsNodeId('node-extra'), isFalse);

    writer.writeRebuildNodeIdIndex();
    expect(ctx.workingNodeIds, containsAll(<NodeId>{'rect-1', 'locked'}));

    expect(
      writer.writeNodeTransformSet('missing', Transform2D.identity),
      isFalse,
    );
    expect(
      writer.writeNodeTransformSet(
        'rect-1',
        Transform2D.translation(const Offset(3, 4)),
      ),
      isTrue,
    );
    expect(ctx.changeSet.updatedNodeIds, contains('rect-1'));

    expect(writer.writeSelectionClear(), isTrue);
    expect(writer.writeSelectionClear(), isFalse);

    final selectAll = writer.writeSelectionSelectAll();
    expect(selectAll, 1);
    expect(writer.selectedNodeIds, const <NodeId>{'rect-1'});
    expect(writer.writeSelectionSelectAll(), 0);
  });

  test('writeNodeTransformSet marks visual change when bounds stay same', () {
    final ctx = TxnContext(
      baseScene: Scene(
        layers: <Layer>[
          Layer(
            nodes: <SceneNode>[
              LineNode(
                id: 'line-static',
                start: Offset.zero,
                end: Offset.zero,
                thickness: 2,
                color: const Color(0xFF000000),
              ),
            ],
          ),
        ],
      ),
      workingSelection: <NodeId>{},
      workingNodeIds: <NodeId>{'line-static'},
      nodeIdSeed: 0,
    );
    final writer = SceneWriter(ctx, txnSignalSink: (_) {});

    final changed = writer.writeNodeTransformSet(
      'line-static',
      Transform2D.rotationDeg(90),
    );

    expect(changed, isTrue);
    expect(ctx.changeSet.boundsChanged, isFalse);
    expect(ctx.changeSet.visualChanged, isTrue);
  });

  test('SceneWriter covers clear/delete/mark helpers', () {
    final ctx = TxnContext(
      baseScene: Scene(
        layers: <Layer>[
          Layer(isBackground: true),
          Layer(
            nodes: <SceneNode>[
              RectNode(
                id: 'keep',
                size: const Size(10, 10),
                isDeletable: false,
              ),
              RectNode(id: 'del', size: const Size(10, 10)),
            ],
          ),
        ],
      ),
      workingSelection: <NodeId>{'keep', 'del'},
      workingNodeIds: <NodeId>{'keep', 'del'},
      nodeIdSeed: 0,
    );
    final writer = SceneWriter(ctx, txnSignalSink: (_) {});

    expect(writer.writeDeleteSelection(), 1);
    expect(
      ctx.workingScene.layers[1].nodes.map((n) => n.id),
      orderedEquals(<NodeId>['keep']),
    );
    expect(ctx.workingSelection, const <NodeId>{'keep'});
    expect(writer.writeDeleteSelection(), 0);

    final cleared = writer.writeClearSceneKeepBackground();
    expect(cleared, const <NodeId>['keep']);
    expect(ctx.workingScene.layers.length, 1);
    expect(ctx.workingSelection, isEmpty);
    expect(writer.writeClearSceneKeepBackground(), isEmpty);
    expect(ctx.changeSet.structuralChanged, isTrue);
    expect(ctx.changeSet.boundsChanged, isTrue);
    expect(ctx.changeSet.visualChanged, isTrue);
    expect(ctx.changeSet.selectionChanged, isTrue);
  });

  test('SceneWriter clearScene throws on multiple background layers', () {
    final ctx = TxnContext(
      baseScene: Scene(
        layers: <Layer>[Layer(isBackground: true), Layer(isBackground: true)],
      ),
      workingSelection: <NodeId>{},
      workingNodeIds: <NodeId>{},
      nodeIdSeed: 0,
    );
    final writer = SceneWriter(ctx, txnSignalSink: (_) {});

    expect(writer.writeClearSceneKeepBackground, throwsStateError);
  });

  test(
    'V2SpatialIndexSlice caches, invalidates and rebuilds by commit signals',
    () {
      final slice = V2SpatialIndexSlice();
      final scene = Scene(
        layers: <Layer>[
          Layer(
            nodes: <SceneNode>[RectNode(id: 'r1', size: const Size(10, 10))],
          ),
        ],
      );

      final first = slice.writeQueryCandidates(
        scene: scene,
        worldBounds: const Rect.fromLTWH(0, 0, 20, 20),
        controllerEpoch: 0,
        boundsRevision: 0,
      );
      expect(first, isNotEmpty);
      expect(slice.debugBuildCount, 1);

      slice.writeQueryCandidates(
        scene: scene,
        worldBounds: const Rect.fromLTWH(0, 0, 20, 20),
        controllerEpoch: 0,
        boundsRevision: 0,
      );
      expect(slice.debugBuildCount, 1);

      final noChange = ChangeSet();
      slice.writeHandleCommit(
        changeSet: noChange,
        controllerEpoch: 0,
        boundsRevision: 0,
      );
      slice.writeQueryCandidates(
        scene: scene,
        worldBounds: const Rect.fromLTWH(0, 0, 20, 20),
        controllerEpoch: 0,
        boundsRevision: 0,
      );
      expect(slice.debugBuildCount, 1);

      slice.writeHandleCommit(
        changeSet: noChange,
        controllerEpoch: 1,
        boundsRevision: 0,
      );
      slice.writeQueryCandidates(
        scene: scene,
        worldBounds: const Rect.fromLTWH(0, 0, 20, 20),
        controllerEpoch: 1,
        boundsRevision: 0,
      );
      expect(slice.debugBuildCount, 2);
    },
  );

  test('V2RepaintSlice marks/flushes once and can discard pending', () {
    final slice = V2RepaintSlice();

    expect(slice.needsNotify, isFalse);
    expect(slice.writeFlushNotify(() {}), isFalse);

    var notified = 0;
    slice.writeMarkNeedsRepaint();
    expect(slice.needsNotify, isTrue);
    expect(
      slice.writeFlushNotify(() {
        notified = notified + 1;
      }),
      isTrue,
    );
    expect(notified, 1);
    expect(slice.needsNotify, isFalse);

    slice.writeMarkNeedsRepaint();
    slice.writeDiscardPending();
    expect(slice.needsNotify, isFalse);
  });
}
