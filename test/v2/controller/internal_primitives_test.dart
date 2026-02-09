import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/basic_v2.dart' hide NodeId;
import 'package:iwb_canvas_engine/src/core/nodes.dart';
import 'package:iwb_canvas_engine/src/core/scene.dart';
import 'package:iwb_canvas_engine/src/v2/controller/change_set.dart';
import 'package:iwb_canvas_engine/src/v2/controller/scene_writer.dart';
import 'package:iwb_canvas_engine/src/v2/controller/store.dart';
import 'package:iwb_canvas_engine/src/v2/controller/txn_context.dart';
import 'package:iwb_canvas_engine/src/v2/input/slices/repaint/repaint_slice.dart';
import 'package:iwb_canvas_engine/src/v2/input/slices/signals/signal_event.dart';
import 'package:iwb_canvas_engine/src/v2/input/slices/spatial_index/spatial_index_slice.dart';

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
      workingScene: Scene(
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

    expect(writer.scene.layers.single.nodes.single.id, 'r1');
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
    writer.writeBackgroundColor(writer.scene.background.color);
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
