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
    required MutationExecutor mutationExecutor,
    required this.txnSignalSink,
  }) : _mutationExecutor = mutationExecutor,
       _selectedNodeIdsView = UnmodifiableSetView<NodeId>(
         _ctx.workingSelection,
       );

  final TxnContext _ctx;
  final void Function(BufferedSignal signal) txnSignalSink;
  final MutationExecutor _mutationExecutor;
  final UnmodifiableSetView<NodeId> _selectedNodeIdsView;

  @override
  SceneSnapshot get snapshot => txnSceneToSnapshot(_ctx.workingScene);

  @override
  Set<NodeId> get selectedNodeIds => _selectedNodeIdsView;

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

  List<NodeId> writeDeleteNodesResult(Iterable<NodeId> nodeIds) {
    _ensureTxnActive();
    final removedIds =
        _mutationExecutor.execute(_ctx, DeleteNodesBulkOp(nodeIds)).value
            as List<NodeId>;
    return _sortedRemovedNodeIds(removedIds);
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
    return writeSelectionReplaceResult(ids) != null;
  }

  List<NodeId>? writeSelectionReplaceResult(Iterable<NodeId> ids) {
    _ensureTxnActive();
    final next = txnNormalizeSelection(
      rawSelection: ids.toSet(),
      scene: _ctx.workingScene,
      nodeLocator: _ctx.txnNodeLocatorView(),
    );
    if (next.isEmpty) {
      return null;
    }
    if (_txnSetsEqual(_ctx.workingSelection, next)) {
      return null;
    }
    _ctx.workingSelection
      ..clear()
      ..addAll(next);
    _ctx.changeSet.txnMarkSelectionChanged();
    return _sortedSelectionNodeIds();
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
    return writeSelectionSelectAllResult(
      onlySelectable: onlySelectable,
    ).selectedCount;
  }

  ({int selectedCount, bool changed}) writeSelectionSelectAllResult({
    bool onlySelectable = true,
  }) {
    _ensureTxnActive();
    final targetSelection = HashSet<NodeId>();
    for (final layer in _ctx.workingScene.layers) {
      for (final node in layer.nodes) {
        if (isNodeInteractiveForSelection(
          node,
          onlySelectable: onlySelectable,
        )) {
          targetSelection.add(node.id);
        }
      }
    }
    if (_txnSetsEqual(_ctx.workingSelection, targetSelection)) {
      return (selectedCount: 0, changed: false);
    }
    _ctx.workingSelection
      ..clear()
      ..addAll(targetSelection);
    _ctx.changeSet.txnMarkSelectionChanged();
    return (selectedCount: targetSelection.length, changed: true);
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
    return writeDeleteSelectionResult().length;
  }

  List<NodeId> writeDeleteSelectionResult() {
    _ensureTxnActive();
    final removedIds =
        _mutationExecutor
                .execute(
                  _ctx,
                  DeleteNodesBulkOp.borrowed(_ctx.workingSelection),
                )
                .value
            as List<NodeId>;
    return _sortedRemovedNodeIds(removedIds);
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
    writeCameraOffsetChanged(offset);
  }

  bool writeCameraOffsetChanged(Offset offset) {
    _ensureTxnActive();
    return _mutationExecutor.execute(_ctx, SetCameraOffsetOp(offset)).changed;
  }

  @override
  void writeGridEnable(bool enabled) {
    writeGridEnableChanged(enabled);
  }

  bool writeGridEnableChanged(bool enabled) {
    _ensureTxnActive();
    return _mutationExecutor.execute(_ctx, SetGridEnabledOp(enabled)).changed;
  }

  @override
  void writeGridCellSize(double cellSize) {
    writeGridCellSizeChanged(cellSize);
  }

  bool writeGridCellSizeChanged(double cellSize) {
    _ensureTxnActive();
    return _mutationExecutor.execute(_ctx, SetGridCellSizeOp(cellSize)).changed;
  }

  @override
  void writeBackgroundColor(Color color) {
    writeBackgroundColorChanged(color);
  }

  bool writeBackgroundColorChanged(Color color) {
    _ensureTxnActive();
    return _mutationExecutor.execute(_ctx, SetBackgroundColorOp(color)).changed;
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
    writeOwnedSignalEnqueue(
      type: type,
      nodeIds: List<NodeId>.of(nodeIds),
      payload: payload,
    );
  }

  void writeOwnedSignalEnqueue({
    required String type,
    List<NodeId> nodeIds = const <NodeId>[],
    Map<String, Object?>? payload,
  }) {
    _ensureTxnActive();
    txnSignalSink(
      BufferedSignal(type: type, nodeIds: nodeIds, payload: payload),
    );
  }

  List<NodeId> _sortedSelectionNodeIds() {
    final ids = _ctx.workingSelection.toList(growable: false);
    ids.sort((a, b) => a.compareTo(b));
    return ids;
  }

  List<NodeId> _sortedRemovedNodeIds(List<NodeId> removedIds) {
    if (removedIds.length < 2) {
      return removedIds;
    }
    final sortedIds = removedIds.toList(growable: false);
    sortedIds.sort((a, b) => a.compareTo(b));
    return sortedIds;
  }

  bool _txnSetsEqual(Set<NodeId> left, Set<NodeId> right) {
    return left.length == right.length && left.containsAll(right);
  }

  void _ensureTxnActive() {
    _ctx.txnEnsureActive();
  }
}
