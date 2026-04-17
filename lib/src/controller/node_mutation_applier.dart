import 'dart:ui' show Rect;

import '../contract/node_spec.dart';
import '../contract/transform2d.dart';
import '../core/hit_test.dart';
import '../core/nodes.dart';
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
    InsertNodeOp() => _insert(
      ctx,
      op,
      textFontFamilyByDefault: textFontFamilyByDefault,
    ),
    PatchNodeOp() => _patch(ctx, op),
    SetNodeTransformOp(:final nodeId, :final transform) => _setNodeTransform(
      ctx,
      nodeId,
      transform,
    ),
    DeleteNodeOp(:final nodeId) => _deleteNode(ctx, nodeId),
    DeleteNodesBulkOp(:final nodeIds) => _deleteNodesBulk(ctx, nodeIds),
  };
}

MutationApplyResult<NodeId> _insert(
  TxnContext ctx,
  InsertNodeOp op, {
  required String? textFontFamilyByDefault,
}) {
  final spec = op.spec;
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
  final targetLayerIndex = ctx.txnResolveInsertLayerIndex(layerId: op.layerId);
  ctx.txnEnsureMutableLayer(targetLayerIndex);
  txnInsertNodeInScene(
    scene: scene,
    nodeLocator: ctx.txnEnsureMutableNodeLocator(),
    node: node,
    layerIndex: targetLayerIndex,
    insertIndex: op.insertIndex,
  );
  ctx.txnRememberNodeId(node.id);
  ctx.changeSet
    ..txnMarkStructuralChanged()
    ..txnTrackAdded(node.id);
  return MutationApplyResult<NodeId>(value: node.id, changed: true);
}

MutationApplyResult<bool> _patch(TxnContext ctx, PatchNodeOp op) {
  final patch = op.patch;
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
  trackUpdatedNodeGeometry(
    ctx,
    nodeId: patch.id,
    beforeCandidate: beforeCandidate,
    afterCandidate: afterCandidate,
  );
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

  txnApplyNodeTransform(ctx, nodeId: nodeId, transform: transform);
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

  ctx.txnForgetNodeId(nodeId);
  ctx.changeSet
    ..txnMarkStructuralChanged()
    ..txnTrackRemoved(nodeId);
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
  }
  if (preparedRemovalsByLayer.isEmpty) {
    return null;
  }
  final sortedLayerIndexes = targetLayerIndexes.toList(growable: false)..sort();
  return _PreparedBulkDelete(
    preparedRemovalsByLayer: preparedRemovalsByLayer,
    targetLayerIndexes: sortedLayerIndexes,
  );
}

void _finalizeDeletedNodes(TxnContext ctx, Iterable<NodeId> deletedNodeIds) {
  ctx.changeSet.txnMarkStructuralChanged();
  for (final nodeId in deletedNodeIds) {
    ctx.txnForgetNodeId(nodeId);
    ctx.changeSet.txnTrackRemoved(nodeId);
  }
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
      textDirection: text.textDirection,
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

void trackUpdatedNodeGeometry(
  TxnContext ctx, {
  required NodeId nodeId,
  required Rect? beforeCandidate,
  required Rect? afterCandidate,
}) {
  ctx.changeSet.txnTrackUpdated(nodeId);
  if (beforeCandidate != afterCandidate) {
    ctx.changeSet
      ..txnMarkBoundsChanged()
      ..txnTrackSpatialGeometryChanged(nodeId);
  } else {
    ctx.changeSet.txnMarkVisualChanged();
  }
}

void txnApplyNodeTransform(
  TxnContext ctx, {
  required NodeId nodeId,
  required Transform2D transform,
}) {
  final found = ctx.txnResolveMutableNode(nodeId);
  final beforeCandidate = nodeHitTestCandidateBoundsWorld(found.node);
  found.node.transform = transform;
  final afterCandidate = nodeHitTestCandidateBoundsWorld(found.node);
  trackUpdatedNodeGeometry(
    ctx,
    nodeId: nodeId,
    beforeCandidate: beforeCandidate,
    afterCandidate: afterCandidate,
  );
}

final class _PreparedBulkDelete {
  const _PreparedBulkDelete({
    required this.preparedRemovalsByLayer,
    required this.targetLayerIndexes,
  });

  final Map<int, List<PreparedNodeRemoval>> preparedRemovalsByLayer;
  final List<int> targetLayerIndexes;
}
