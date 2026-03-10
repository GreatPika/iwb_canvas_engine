import 'dart:collection';
import 'dart:ui';

import '../core/selection_policy.dart';
import '../contract/transform2d.dart';
import 'internal/signal_event.dart';
import '../model/document.dart';
import 'mutation_executor.dart';
import 'mutation_op.dart';
import '../contract/node_patch.dart';
import '../contract/node_spec.dart';
import '../contract/scene_write_txn.dart';
import '../contract/snapshot.dart';
import 'txn_context.dart';

class SceneWriter implements SceneWriteTxn {
  SceneWriter(
    this._ctx, {
    required this.txnSignalSink,
    String? textFontFamilyByDefault,
  }) : _mutationExecutor = MutationExecutor(
         textFontFamilyByDefault: textFontFamilyByDefault,
       );

  final TxnContext _ctx;
  final void Function(BufferedSignal signal) txnSignalSink;
  final MutationExecutor _mutationExecutor;

  @override
  SceneSnapshot get snapshot => txnSceneToSnapshot(_ctx.workingScene);

  @override
  Set<NodeId> get selectedNodeIds =>
      Set<NodeId>.unmodifiable(_ctx.workingSelection);

  @override
  NodeId writeNodeInsert(NodeSpec spec, {LayerId? layerId, int? insertIndex}) {
    _ensureTxnActive();
    return _mutationExecutor
            .execute(
              _ctx,
              InsertNodeOp(spec, layerId: layerId, insertIndex: insertIndex),
            )
            .value
        as NodeId;
  }

  @override
  bool writeLayerEnsure(LayerId layerId, {int? index}) {
    _ensureTxnActive();
    return _mutationExecutor
            .execute(_ctx, EnsureLayerOp(layerId, index: index))
            .value
        as bool;
  }

  @override
  bool writeNodeErase(NodeId nodeId) {
    _ensureTxnActive();
    return _mutationExecutor.execute(_ctx, DeleteNodeOp(nodeId)).value as bool;
  }

  @override
  bool writeNodePatch(NodePatch patch) {
    _ensureTxnActive();
    return _mutationExecutor.execute(_ctx, PatchNodeOp(patch)).value as bool;
  }

  @override
  bool writeNodeTransformSet(NodeId id, Transform2D transform) {
    _ensureTxnActive();
    return _mutationExecutor
            .execute(_ctx, SetNodeTransformOp(id, transform))
            .value
        as bool;
  }

  @override
  bool writeSelectionReplace(Iterable<NodeId> ids) {
    _ensureTxnActive();
    final next = txnNormalizeSelection(
      rawSelection: ids.toSet(),
      scene: _ctx.workingScene,
      nodeLocator: _ctx.txnNodeLocatorView(),
    );
    if (next.isEmpty) {
      return false;
    }
    if (_txnSetsEqual(_ctx.workingSelection, next)) {
      return false;
    }
    _ctx.workingSelection
      ..clear()
      ..addAll(next);
    _ctx.changeSet.txnMarkSelectionChanged();
    return true;
  }

  @override
  bool writeSelectionToggle(NodeId id) {
    _ensureTxnActive();
    if (!txnIsSelectionCandidateId(
      scene: _ctx.workingScene,
      nodeId: id,
      nodeLocator: _ctx.txnNodeLocatorView(),
    )) {
      return false;
    }
    if (_ctx.workingSelection.contains(id)) {
      _ctx.workingSelection.remove(id);
    } else {
      _ctx.workingSelection.add(id);
    }
    _ctx.changeSet.txnMarkSelectionChanged();
    return true;
  }

  @override
  bool writeSelectionClear() {
    _ensureTxnActive();
    if (_ctx.workingSelection.isEmpty) {
      return false;
    }
    _ctx.workingSelection.clear();
    _ctx.changeSet.txnMarkSelectionChanged();
    return true;
  }

  @override
  int writeSelectionSelectAll({bool onlySelectable = true}) {
    _ensureTxnActive();
    final ids = HashSet<NodeId>();
    for (final layer in _ctx.workingScene.layers) {
      for (final node in layer.nodes) {
        if (isNodeInteractiveForSelection(
          node,
          onlySelectable: onlySelectable,
        )) {
          ids.add(node.id);
        }
      }
    }
    if (_txnSetsEqual(_ctx.workingSelection, ids)) {
      return 0;
    }
    _ctx.workingSelection
      ..clear()
      ..addAll(ids);
    _ctx.changeSet.txnMarkSelectionChanged();
    return ids.length;
  }

  @override
  int writeSelectionTranslate(Offset delta) {
    _ensureTxnActive();
    return _mutationExecutor.execute(_ctx, TranslateSelectionOp(delta)).value
        as int;
  }

  @override
  int writeSelectionTransform(Transform2D delta) {
    _ensureTxnActive();
    return _mutationExecutor.execute(_ctx, TransformSelectionOp(delta)).value
        as int;
  }

  @override
  int writeDeleteSelection() {
    _ensureTxnActive();
    return _mutationExecutor
            .execute(_ctx, DeleteNodesBulkOp(_ctx.workingSelection))
            .value
        as int;
  }

  @override
  List<NodeId> writeClearSceneKeepBackground() {
    return writeClearSceneKeepBackgroundResult().removedNodeIds;
  }

  @override
  ClearSceneResult writeClearSceneKeepBackgroundResult() {
    _ensureTxnActive();
    return _mutationExecutor
            .execute(_ctx, const ClearSceneKeepBackgroundOp())
            .value
        as ClearSceneResult;
  }

  @override
  void writeCameraOffset(Offset offset) {
    _ensureTxnActive();
    _mutationExecutor.execute(_ctx, SetCameraOffsetOp(offset));
  }

  @override
  void writeGridEnable(bool enabled) {
    _ensureTxnActive();
    _mutationExecutor.execute(_ctx, SetGridEnabledOp(enabled));
  }

  @override
  void writeGridCellSize(double cellSize) {
    _ensureTxnActive();
    _mutationExecutor.execute(_ctx, SetGridCellSizeOp(cellSize));
  }

  @override
  void writeBackgroundColor(Color color) {
    _ensureTxnActive();
    _mutationExecutor.execute(_ctx, SetBackgroundColorOp(color));
  }

  @override
  void writeDocumentReplace(SceneSnapshot snapshot) {
    _ensureTxnActive();
    _mutationExecutor.execute(_ctx, ReplaceSceneOp(snapshot));
  }

  @override
  void writeSignalEnqueue({
    required String type,
    Iterable<NodeId> nodeIds = const <NodeId>[],
    Map<String, Object?>? payload,
  }) {
    _ensureTxnActive();
    txnSignalSink(
      BufferedSignal(
        type: type,
        nodeIds: List<NodeId>.of(nodeIds),
        payload: payload,
      ),
    );
  }

  bool _txnSetsEqual(Set<NodeId> left, Set<NodeId> right) {
    return left.length == right.length && left.containsAll(right);
  }

  void _ensureTxnActive() {
    _ctx.txnEnsureActive();
  }
}
