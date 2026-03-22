import 'dart:ui';

import '../contract/ids.dart';
import '../contract/node_patch.dart';
import '../contract/node_spec.dart';
import '../contract/transform2d.dart';
import '../core/hit_test.dart';
import '../core/selection_policy.dart';
import '../model/document.dart';
import 'mutation_input_guards.dart';
import 'mutation_op.dart';
import 'txn_context.dart';

MutationApplyResult<Object?> executeNodeMutationOp(
  TxnContext ctx,
  NodeMutationOp<Object?> op, {
  required String? textFontFamilyByDefault,
}) {
  return switch (op) {
    InsertNodeOp(:final spec, :final layerId, :final insertIndex) => _insert(
      ctx,
      spec,
      textFontFamilyByDefault: textFontFamilyByDefault,
      layerId: layerId,
      insertIndex: insertIndex,
    ),
    PatchNodeOp(:final patch) => _patch(ctx, patch),
    SetNodeTransformOp(:final nodeId, :final transform) => _setNodeTransform(
      ctx,
      nodeId,
      transform,
    ),
    DeleteNodeOp(:final nodeId) => _deleteNode(ctx, nodeId),
    DeleteNodesBulkOp(:final nodeIds) => _deleteNodesBulk(ctx, nodeIds),
  };
}

MutationApplyResult<Object?> executeSelectionTransformMutationOp(
  TxnContext ctx,
  SelectionTransformMutationOp<Object?> op,
) {
  return switch (op) {
    TransformSelectionOp(:final delta) => _transformSelection(ctx, delta),
    TranslateSelectionOp(:final delta) => _translateSelection(ctx, delta),
  };
}

MutationApplyResult<NodeId> _insert(
  TxnContext ctx,
  NodeSpec spec, {
  required String? textFontFamilyByDefault,
  LayerId? layerId,
  int? insertIndex,
}) {
  final explicitId = spec.id;
  if (explicitId != null && ctx.txnHasNodeId(explicitId)) {
    throw ArgumentError.value(explicitId, 'spec.id', 'Node id must be unique.');
  }
  final resolvedId = spec.id ?? ctx.txnNextNodeId();
  final node = txnNodeFromSpec(
    _normalizeInsertSpec(
      spec,
      textFontFamilyByDefault: textFontFamilyByDefault,
    ),
    fallbackId: resolvedId,
    nextInstanceRevision: ctx.txnNextInstanceRevision,
  );
  final scene = ctx.txnEnsureMutableScene();
  final targetLayerIndex = ctx.txnResolveInsertLayerIndex(layerId: layerId);
  ctx.txnEnsureMutableLayer(targetLayerIndex);
  txnInsertNodeInScene(
    scene: scene,
    nodeLocator: ctx.txnEnsureMutableNodeLocator(),
    node: node,
    layerIndex: targetLayerIndex,
    insertIndex: insertIndex,
  );
  ctx.txnRememberNodeId(node.id);
  ctx.changeSet
    ..txnMarkStructuralChanged()
    ..txnTrackAdded(node.id);
  return MutationApplyResult<NodeId>(value: node.id, changed: true);
}

MutationApplyResult<bool> _patch(TxnContext ctx, NodePatch patch) {
  final existing = ctx.txnFindNodeById(patch.id);
  if (existing == null) {
    return const MutationApplyResult<bool>(value: false, changed: false);
  }
  if (!txnApplyNodePatch(existing.node, patch, dryRun: true)) {
    return const MutationApplyResult<bool>(value: false, changed: false);
  }

  final found = ctx.txnResolveMutableNode(patch.id);
  final beforeCandidate = nodeHitTestCandidateBoundsWorld(found.node);
  txnApplyNodePatch(found.node, patch);
  final afterCandidate = nodeHitTestCandidateBoundsWorld(found.node);
  _trackUpdatedNodeGeometry(
    ctx,
    nodeId: patch.id,
    beforeCandidate: beforeCandidate,
    afterCandidate: afterCandidate,
  );
  if (ctx.workingSelection.contains(patch.id) &&
      _patchTouchesSelectionPolicy(patch)) {
    ctx.changeSet.txnMarkSelectionChanged();
  }
  return const MutationApplyResult<bool>(value: true, changed: true);
}

MutationApplyResult<bool> _setNodeTransform(
  TxnContext ctx,
  NodeId nodeId,
  Transform2D transform,
) {
  requireFiniteTransformMutationInput(transform, name: 'transform');
  final existing = ctx.txnFindNodeById(nodeId);
  if (existing == null || existing.node.transform == transform) {
    return const MutationApplyResult<bool>(value: false, changed: false);
  }

  final found = ctx.txnResolveMutableNode(nodeId);
  final beforeCandidate = nodeHitTestCandidateBoundsWorld(found.node);
  found.node.transform = transform;
  final afterCandidate = nodeHitTestCandidateBoundsWorld(found.node);
  _trackUpdatedNodeGeometry(
    ctx,
    nodeId: nodeId,
    beforeCandidate: beforeCandidate,
    afterCandidate: afterCandidate,
  );
  return const MutationApplyResult<bool>(value: true, changed: true);
}

MutationApplyResult<bool> _deleteNode(TxnContext ctx, NodeId nodeId) {
  final existing = ctx.txnFindNodeById(nodeId);
  if (existing == null ||
      existing.layerIndex == -1 ||
      !isNodeDeletableInLayer(existing.node)) {
    return const MutationApplyResult<bool>(value: false, changed: false);
  }
  ctx.txnEnsureMutableLayer(existing.layerIndex);
  final removedNodeIds = txnErasePreparedNodesFromScene(
    scene: ctx.txnEnsureMutableScene(),
    nodeLocator: ctx.txnEnsureMutableNodeLocator(),
    removalsByLayer: <int, List<PreparedNodeRemoval>>{
      existing.layerIndex: <PreparedNodeRemoval>[
        (nodeId: nodeId, nodeIndex: existing.nodeIndex),
      ],
    },
  );
  if (removedNodeIds.isEmpty) {
    return const MutationApplyResult<bool>(value: false, changed: false);
  }

  final hadSelection = ctx.workingSelection.remove(nodeId);
  ctx.txnForgetNodeId(nodeId);
  ctx.changeSet
    ..txnMarkStructuralChanged()
    ..txnTrackRemoved(nodeId);
  if (hadSelection) {
    ctx.changeSet.txnMarkSelectionChanged();
  }
  return const MutationApplyResult<bool>(value: true, changed: true);
}

MutationApplyResult<List<NodeId>> _deleteNodesBulk(
  TxnContext ctx,
  Set<NodeId> nodeIds,
) {
  final plan = _prepareBulkDelete(ctx, nodeIds);
  if (plan == null) {
    return const MutationApplyResult<List<NodeId>>(
      value: <NodeId>[],
      changed: false,
    );
  }
  for (final layerIndex in plan.targetLayerIndexes) {
    ctx.txnEnsureMutableLayer(layerIndex);
  }

  final deleted = txnErasePreparedNodesFromScene(
    scene: ctx.txnEnsureMutableScene(),
    nodeLocator: ctx.txnEnsureMutableNodeLocator(),
    removalsByLayer: plan.preparedRemovalsByLayer,
  );
  if (deleted.isEmpty) {
    return const MutationApplyResult<List<NodeId>>(
      value: <NodeId>[],
      changed: false,
    );
  }

  _finalizeDeletedNodes(ctx, deleted);
  if (plan.selectionMayChange) {
    ctx.workingSelection.removeAll(deleted);
    ctx.changeSet.txnMarkSelectionChanged();
  }
  return MutationApplyResult<List<NodeId>>(
    value: List<NodeId>.unmodifiable(deleted),
    changed: true,
  );
}

_PreparedBulkDelete? _prepareBulkDelete(TxnContext ctx, Set<NodeId> nodeIds) {
  if (nodeIds.isEmpty) {
    return null;
  }

  final preparedRemovalsByLayer = <int, List<PreparedNodeRemoval>>{};
  final targetLayerIndexes = <int>{};
  var selectionMayChange = false;
  for (final nodeId in nodeIds) {
    final existing = ctx.txnFindNodeById(nodeId);
    if (existing == null ||
        existing.layerIndex == -1 ||
        !isNodeDeletableInLayer(existing.node)) {
      continue;
    }
    targetLayerIndexes.add(existing.layerIndex);
    preparedRemovalsByLayer
        .putIfAbsent(existing.layerIndex, () => <PreparedNodeRemoval>[])
        .add((nodeId: nodeId, nodeIndex: existing.nodeIndex));
    if (!selectionMayChange && ctx.workingSelection.contains(nodeId)) {
      selectionMayChange = true;
    }
  }
  if (preparedRemovalsByLayer.isEmpty) {
    return null;
  }
  final sortedLayerIndexes = targetLayerIndexes.toList(growable: false)..sort();
  return _PreparedBulkDelete(
    preparedRemovalsByLayer: preparedRemovalsByLayer,
    targetLayerIndexes: sortedLayerIndexes,
    selectionMayChange: selectionMayChange,
  );
}

void _finalizeDeletedNodes(TxnContext ctx, Iterable<NodeId> deletedNodeIds) {
  ctx.changeSet.txnMarkStructuralChanged();
  for (final nodeId in deletedNodeIds) {
    ctx.txnForgetNodeId(nodeId);
    ctx.changeSet.txnTrackRemoved(nodeId);
  }
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

    final mutable = ctx.txnResolveMutableNode(nodeId);
    final beforeCandidate = nodeHitTestCandidateBoundsWorld(mutable.node);
    mutable.node.transform = nextTransform;
    final afterCandidate = nodeHitTestCandidateBoundsWorld(mutable.node);
    _trackUpdatedNodeGeometry(
      ctx,
      nodeId: nodeId,
      beforeCandidate: beforeCandidate,
      afterCandidate: afterCandidate,
    );
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
      ..txnTrackHitGeometryChanged(nodeId);
  }
  ctx.changeSet.txnMarkBoundsChanged();
  return MutationApplyResult<int>(value: moved.length, changed: true);
}

NodeSpec _normalizeInsertSpec(
  NodeSpec spec, {
  required String? textFontFamilyByDefault,
}) {
  final defaultFontFamily = textFontFamilyByDefault;
  if (defaultFontFamily == null) {
    return spec;
  }
  if (spec case TextNodeSpec text when text.fontFamily == null) {
    return TextNodeSpec(
      id: text.id,
      text: text.text,
      fontSize: text.fontSize,
      color: text.color,
      align: text.align,
      isBold: text.isBold,
      isItalic: text.isItalic,
      isUnderline: text.isUnderline,
      fontFamily: defaultFontFamily,
      maxWidth: text.maxWidth,
      lineHeight: text.lineHeight,
      transform: text.transform,
      opacity: text.opacity,
      hitPadding: text.hitPadding,
      isVisible: text.isVisible,
      isSelectable: text.isSelectable,
      isLocked: text.isLocked,
      isDeletable: text.isDeletable,
      isTransformable: text.isTransformable,
    );
  }
  return spec;
}

void _trackUpdatedNodeGeometry(
  TxnContext ctx, {
  required NodeId nodeId,
  required Rect? beforeCandidate,
  required Rect? afterCandidate,
}) {
  ctx.changeSet.txnTrackUpdated(nodeId);
  if (beforeCandidate != afterCandidate) {
    ctx.changeSet
      ..txnMarkBoundsChanged()
      ..txnTrackHitGeometryChanged(nodeId);
  } else {
    ctx.changeSet.txnMarkVisualChanged();
  }
}

bool _patchTouchesSelectionPolicy(NodePatch patch) {
  final common = patch.common;
  return !common.isVisible.isAbsent || !common.isSelectable.isAbsent;
}

final class _PreparedBulkDelete {
  const _PreparedBulkDelete({
    required this.preparedRemovalsByLayer,
    required this.targetLayerIndexes,
    required this.selectionMayChange,
  });

  final Map<int, List<PreparedNodeRemoval>> preparedRemovalsByLayer;
  final List<int> targetLayerIndexes;
  final bool selectionMayChange;
}
