import 'dart:collection';

import '../contract/ids.dart';
import '../core/selection_policy.dart';
import '../model/document.dart';
import 'mutation_op.dart';
import 'scene_writer_support.dart';
import 'txn_context.dart';

MutationApplyResult<Object?> executeSelectionStateMutationOp(
  TxnContext ctx,
  SelectionStateMutationOp<Object?> op,
) {
  return switch (op) {
    ReplaceSelectionOp(:final nodeIds) => _replaceSelection(ctx, nodeIds),
    ToggleSelectionOp(:final nodeId) => _toggleSelection(ctx, nodeId),
    ClearSelectionOp() => _clearSelection(ctx),
    SelectAllSelectionOp(:final onlySelectable) => _selectAllSelection(
      ctx,
      onlySelectable: onlySelectable,
    ),
  };
}

MutationApplyResult<List<NodeId>?> _replaceSelection(
  TxnContext ctx,
  Set<NodeId> nodeIds,
) {
  final nextSelection = txnNormalizeSelection(
    rawSelection: nodeIds,
    scene: ctx.workingScene,
    nodeLocator: ctx.txnNodeLocatorView(),
    layerIndexById: ctx.txnLayerIndexByIdView(),
  );
  if (nextSelection.isEmpty ||
      _selectionSetsEqual(ctx.workingSelection, nextSelection)) {
    return const MutationApplyResult<List<NodeId>?>(
      value: null,
      changed: false,
    );
  }

  _replaceWorkingSelection(ctx, nextSelection);
  return MutationApplyResult<List<NodeId>?>(
    value: sortWriterNodeIds(nextSelection),
    changed: true,
  );
}

MutationApplyResult<bool> _toggleSelection(TxnContext ctx, NodeId nodeId) {
  if (!txnIsSelectionCandidateId(
    scene: ctx.workingScene,
    nodeId: nodeId,
    nodeLocator: ctx.txnNodeLocatorView(),
    layerIndexById: ctx.txnLayerIndexByIdView(),
  )) {
    return const MutationApplyResult<bool>(value: false, changed: false);
  }

  if (ctx.workingSelection.contains(nodeId)) {
    ctx.workingSelection.remove(nodeId);
  } else {
    ctx.workingSelection.add(nodeId);
  }
  ctx.changeSet.txnMarkSelectionChanged();
  return const MutationApplyResult<bool>(value: true, changed: true);
}

MutationApplyResult<bool> _clearSelection(TxnContext ctx) {
  if (ctx.workingSelection.isEmpty) {
    return const MutationApplyResult<bool>(value: false, changed: false);
  }

  ctx.workingSelection.clear();
  ctx.changeSet.txnMarkSelectionChanged();
  return const MutationApplyResult<bool>(value: true, changed: true);
}

MutationApplyResult<({int selectedCount, bool changed})> _selectAllSelection(
  TxnContext ctx, {
  required bool onlySelectable,
}) {
  final targetSelection = HashSet<NodeId>();
  for (final layer in ctx.workingScene.layers) {
    for (final node in layer.nodes) {
      if (isNodeInteractiveForSelection(node, onlySelectable: onlySelectable)) {
        targetSelection.add(node.id);
      }
    }
  }

  if (_selectionSetsEqual(ctx.workingSelection, targetSelection)) {
    return const MutationApplyResult<({int selectedCount, bool changed})>(
      value: (selectedCount: 0, changed: false),
      changed: false,
    );
  }

  _replaceWorkingSelection(ctx, targetSelection);
  return MutationApplyResult<({int selectedCount, bool changed})>(
    value: (selectedCount: targetSelection.length, changed: true),
    changed: true,
  );
}

void _replaceWorkingSelection(TxnContext ctx, Set<NodeId> nextSelection) {
  ctx.workingSelection
    ..clear()
    ..addAll(nextSelection);
  ctx.changeSet.txnMarkSelectionChanged();
}

bool _selectionSetsEqual(Set<NodeId> left, Set<NodeId> right) {
  return left.length == right.length && left.containsAll(right);
}
