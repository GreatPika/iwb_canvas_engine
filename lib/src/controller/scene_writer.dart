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
    return _execute(
      InsertNodeOp(spec, layerId: layerId, insertIndex: insertIndex),
    ).value;
  }

  @override
  bool writeLayerEnsure(LayerId layerId, {int? index}) {
    return _execute(EnsureLayerOp(layerId, index: index)).value;
  }

  @override
  bool writeNodeErase(NodeId nodeId) {
    return _execute(DeleteNodeOp(nodeId)).value;
  }

  List<NodeId> writeDeleteNodesResult(Iterable<NodeId> nodeIds) {
    final removedIds = _execute(DeleteNodesBulkOp(nodeIds)).value;
    return _sortedRemovedNodeIds(removedIds);
  }

  @override
  bool writeNodePatch(NodePatch patch) {
    return _execute(PatchNodeOp(patch)).value;
  }

  @override
  bool writeNodeTransformSet(NodeId id, Transform2D transform) {
    return _execute(SetNodeTransformOp(id, transform)).value;
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
    return _execute(TranslateSelectionOp(delta)).value;
  }

  @override
  int writeSelectionTransform(Transform2D delta) {
    return _execute(TransformSelectionOp(delta)).value;
  }

  @override
  int writeDeleteSelection() {
    return writeDeleteSelectionResult().length;
  }

  List<NodeId> writeDeleteSelectionResult() {
    final removedIds = _execute(
      DeleteNodesBulkOp.borrowed(_ctx.workingSelection),
    ).value;
    return _sortedRemovedNodeIds(removedIds);
  }

  @override
  List<NodeId> writeClearSceneKeepBackground() {
    return writeClearSceneKeepBackgroundResult().removedNodeIds;
  }

  @override
  ClearSceneResult writeClearSceneKeepBackgroundResult() {
    return _execute(const ClearSceneKeepBackgroundOp()).value;
  }

  @override
  void writeCameraOffset(Offset offset) {
    writeCameraOffsetChanged(offset);
  }

  bool writeCameraOffsetChanged(Offset offset) {
    return _execute(SetCameraOffsetOp(offset)).changed;
  }

  @override
  void writeGridEnable(bool enabled) {
    writeGridEnableChanged(enabled);
  }

  bool writeGridEnableChanged(bool enabled) {
    return _execute(SetGridEnabledOp(enabled)).changed;
  }

  @override
  void writeGridCellSize(double cellSize) {
    writeGridCellSizeChanged(cellSize);
  }

  bool writeGridCellSizeChanged(double cellSize) {
    return _execute(SetGridCellSizeOp(cellSize)).changed;
  }

  @override
  void writeBackgroundColor(Color color) {
    writeBackgroundColorChanged(color);
  }

  bool writeBackgroundColorChanged(Color color) {
    return _execute(SetBackgroundColorOp(color)).changed;
  }

  @override
  void writeDocumentReplace(SceneSnapshot snapshot) {
    _execute(ReplaceSceneOp(snapshot));
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

  MutationApplyResult<TValue> _execute<TValue>(TypedMutationOp<TValue> op) {
    _ensureTxnActive();
    return _mutationExecutor.execute(_ctx, op);
  }

  void _ensureTxnActive() {
    _ctx.txnEnsureActive();
  }
}
