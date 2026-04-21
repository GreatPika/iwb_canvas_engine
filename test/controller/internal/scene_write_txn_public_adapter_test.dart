import 'dart:ui';

// INV:INV-ENG-SCENE-WRITE-TXN-ADAPTER-BOUNDARY

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart' hide NodeId;
import 'package:iwb_canvas_engine/src/controller/internal/signal_event.dart';
import 'package:iwb_canvas_engine/src/controller/mutation_executor.dart';
import 'package:iwb_canvas_engine/src/controller/scene_write_txn_public_adapter.dart';
import 'package:iwb_canvas_engine/src/controller/scene_writer.dart';
import 'package:iwb_canvas_engine/src/controller/scene_writer_runtime.dart';
import 'package:iwb_canvas_engine/src/controller/txn_context.dart';
import 'package:iwb_canvas_engine/src/core/nodes.dart';
import 'package:iwb_canvas_engine/src/core/scene.dart';

void main() {
  SceneWriteTxnPublicAdapter newAdapter(
    TxnContext ctx, {
    required void Function(BufferedSignal signal) txnSignalSink,
  }) {
    final writer = SceneWriter(
      SceneWriterRuntime(
        ctx: ctx,
        mutationExecutor: MutationExecutor(),
        txnSignalSink: txnSignalSink,
      ),
    );
    return SceneWriteTxnPublicAdapter(writer);
  }

  test('SceneWriteTxnPublicAdapter delegates the public write surface', () {
    final bufferedSignals = <BufferedSignal>[];
    final ctx = TxnContext(
      baseScene: Scene(
        layers: <ContentLayer>[
          ContentLayer(
            id: 'layer-1',
            nodes: <SceneNode>[RectNode(id: 'r1', size: const Size(10, 10))],
          ),
        ],
      ),
      workingSelection: <NodeId>{'r1'},
      baseAllNodeIds: <NodeId>{'r1'},
      nodeIdSeed: 0,
      nextInstanceRevision: 1,
    );
    final adapter = newAdapter(ctx, txnSignalSink: bufferedSignals.add);

    expect(adapter.snapshot.layers.single.id, 'layer-1');
    expect(adapter.selectedNodeIds, const <NodeId>{'r1'});

    expect(
      adapter.writeNodeInsert(
        RectNodeSpec(id: 'r2', size: const Size(3, 4)),
        insertIndex: 1,
      ),
      'r2',
    );
    expect(adapter.writeLayerEnsure('layer-2', index: 1), isTrue);
    expect(
      adapter.writeNodePatch(
        RectNodePatch(id: 'r1', strokeWidth: PatchField<double>.value(2)),
      ),
      isTrue,
    );
    expect(
      adapter.writeNodeTransformSet(
        'r1',
        Transform2D.translation(const Offset(5, 6)),
      ),
      isTrue,
    );
    expect(adapter.writeSelectionReplace(const <NodeId>{'r1', 'r2'}), isTrue);
    expect(adapter.writeSelectionToggle('r2'), isTrue);
    expect(adapter.writeSelectionClear(), isTrue);
    expect(adapter.writeSelectionSelectAll(onlySelectable: false), 2);
    expect(adapter.writeSelectionTranslate(const Offset(1, 0)), 2);
    expect(
      adapter.writeSelectionTransform(
        Transform2D.translation(const Offset(0, 2)),
      ),
      2,
    );
    expect(adapter.writeDeleteSelection(), 2);
    expect(adapter.writeNodeErase('missing'), isFalse);

    final clearResult = adapter.writeClearSceneKeepBackgroundResult();
    expect(clearResult.removedNodeIds, isEmpty);
    expect(adapter.writeClearSceneKeepBackground(), isEmpty);

    adapter.writeCameraOffset(const Offset(7, 8));
    adapter.writeGridEnable(true);
    adapter.writeGridCellSize(32);
    adapter.writeBackgroundColor(const Color(0xFFABCDEF));

    expect(ctx.workingScene.camera.offset, const Offset(7, 8));
    expect(ctx.workingScene.background.grid.isEnabled, isTrue);
    expect(ctx.workingScene.background.grid.cellSize, 32);
    expect(ctx.workingScene.background.color, const Color(0xFFABCDEF));

    adapter.writeDocumentReplace(
      SceneSnapshot(
        layers: <ContentLayerSnapshot>[
          ContentLayerSnapshot(
            id: 'layer-replaced',
            nodes: <NodeSnapshot>[
              RectNodeSnapshot(id: 'fresh', size: const Size(9, 9)),
            ],
          ),
        ],
      ),
    );

    expect(ctx.workingScene.layers.single.id, 'layer-replaced');
    expect(ctx.workingScene.layers.single.nodes.single.id, 'fresh');
  });
}
