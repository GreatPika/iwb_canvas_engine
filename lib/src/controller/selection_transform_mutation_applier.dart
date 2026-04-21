import 'dart:ui';

import '../contract/transform2d.dart';
import '../core/nodes.dart';
import 'mutation_input_guards.dart';
import 'mutation_op.dart';
import 'node_mutation_applier.dart';
import 'txn_context.dart';

MutationApplyResult<Object?> executeSelectionTransformMutationOp(
  TxnContext ctx,
  SelectionTransformMutationOp<Object?> op,
) {
  return switch (op) {
    TransformSelectionOp(:final delta) => _transformSelection(ctx, delta),
    TranslateSelectionOp(:final delta) => _translateSelection(ctx, delta),
  };
}

MutationApplyResult<int> _transformSelection(
  TxnContext ctx,
  Transform2D delta,
) {
  requireFiniteTransformMutationInput(delta, name: 'delta');
  final selected = ctx.workingSelection;
  if (selected.isEmpty) {
    return const MutationApplyResult<int>(value: 0, changed: false);
  }

  var affected = 0;
  final selectedIds = selected.toList(growable: false);
  for (final nodeId in selectedIds) {
    final existing = ctx.txnFindNodeById(nodeId);
    if (existing == null ||
        existing.layerIndex == -1 ||
        !existing.node.isTransformable ||
        existing.node.isLocked) {
      continue;
    }

    final nextTransform = delta.multiply(existing.node.transform);
    if (nextTransform == existing.node.transform) {
      continue;
    }

    txnApplyNodeTransform(ctx, nodeId: nodeId, transform: nextTransform);
    affected = affected + 1;
  }
  return MutationApplyResult<int>(value: affected, changed: affected > 0);
}

MutationApplyResult<int> _translateSelection(TxnContext ctx, Offset delta) {
  requireFiniteOffsetMutationInput(delta, name: 'delta');
  if (delta == Offset.zero || ctx.workingSelection.isEmpty) {
    return const MutationApplyResult<int>(value: 0, changed: false);
  }

  final moved = <NodeId>{};
  final selectedIds = ctx.workingSelection.toList(growable: false);
  for (final nodeId in selectedIds) {
    final existing = ctx.txnFindNodeById(nodeId);
    if (existing == null ||
        existing.layerIndex == -1 ||
        existing.node.isLocked ||
        !existing.node.isTransformable) {
      continue;
    }

    final mutable = ctx.txnResolveMutableNode(nodeId);
    mutable.node.position = mutable.node.position + delta;
    moved.add(nodeId);
  }
  if (moved.isEmpty) {
    return const MutationApplyResult<int>(value: 0, changed: false);
  }

  for (final nodeId in moved) {
    ctx.changeSet
      ..txnTrackUpdated(nodeId)
      ..txnTrackSpatialGeometryChanged(nodeId);
  }
  ctx.changeSet.txnMarkBoundsChanged();
  return MutationApplyResult<int>(value: moved.length, changed: true);
}
