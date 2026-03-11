import 'dart:collection';
import 'dart:ui';

import '../contract/node_patch.dart';
import '../contract/node_spec.dart';
import '../contract/scene_write_txn.dart';
import '../contract/snapshot.dart';
import '../contract/transform2d.dart';
import '../core/hit_test.dart';
import '../core/id_generator.dart';
import '../core/revision_policy.dart';
import '../core/scene.dart';
import '../core/selection_policy.dart';
import '../model/document.dart';
import 'change_set.dart';
import 'mutation_op.dart';
import 'txn_context.dart';

class MutationCommitCandidate {
  const MutationCommitCandidate({
    required this.scene,
    required this.selection,
    required this.allNodeIds,
    required this.nodeLocator,
    required this.idGeneratorState,
    required this.revisionState,
  });

  final Scene scene;
  final Set<NodeId> selection;
  final Set<NodeId> allNodeIds;
  final Map<NodeId, NodeLocatorEntry> nodeLocator;
  final IdGeneratorState idGeneratorState;
  final RevisionAllocatorState revisionState;
}

class MutationExecutionResult {
  const MutationExecutionResult({
    required this.applyResult,
    required this.changeSet,
    required this.commitCandidate,
  });

  final MutationApplyResult applyResult;
  final ChangeSet changeSet;
  final MutationCommitCandidate? commitCandidate;
}

class MutationPreparedCommitResult {
  const MutationPreparedCommitResult({
    required this.changeSet,
    required this.commitCandidate,
  });

  final ChangeSet changeSet;
  final MutationCommitCandidate? commitCandidate;
}

class MutationExecutor {
  const MutationExecutor({this.textFontFamilyByDefault});

  final String? textFontFamilyByDefault;

  MutationApplyResult execute(TxnContext ctx, MutationOp op) {
    ctx.txnEnsureActive();
    _runPreconditions(ctx, op);
    final applyResult = _apply(ctx, op);
    _runPostcheck(ctx, op, changed: applyResult.changed);
    return applyResult;
  }

  MutationExecutionResult executeWithPreparedCommit(
    TxnContext ctx,
    MutationOp op,
  ) {
    final applyResult = execute(ctx, op);
    final preparedCommit = prepareCommitResult(ctx);
    return MutationExecutionResult(
      applyResult: applyResult,
      changeSet: preparedCommit.changeSet,
      commitCandidate: preparedCommit.commitCandidate,
    );
  }

  MutationPreparedCommitResult prepareCommitResult(TxnContext ctx) {
    ctx.txnEnsureActive();
    return MutationPreparedCommitResult(
      changeSet: ctx.changeSet.txnClone(),
      commitCandidate: _prepareCommitCandidate(ctx),
    );
  }

  void _runPreconditions(TxnContext ctx, MutationOp op) {
    if (op case InsertNodeOp(:final spec)) {
      final explicitId = spec.id;
      if (explicitId != null && ctx.txnHasNodeId(explicitId)) {
        throw ArgumentError.value(
          explicitId,
          'spec.id',
          'Node id must be unique.',
        );
      }
      return;
    }
    if (op case SetNodeTransformOp(:final transform)) {
      _requireFiniteTransform(transform, name: 'transform');
      return;
    }
    if (op case SetGridCellSizeOp(:final cellSize)) {
      _requireFinitePositive(cellSize, name: 'cellSize');
      return;
    }
    if (op case SetCameraOffsetOp(:final offset)) {
      _requireFiniteOffset(offset, name: 'offset');
      return;
    }
    if (op case TransformSelectionOp(:final delta)) {
      _requireFiniteTransform(delta, name: 'delta');
      return;
    }
    if (op case TranslateSelectionOp(:final delta)) {
      _requireFiniteOffset(delta, name: 'delta');
    }
  }

  MutationApplyResult _apply(TxnContext ctx, MutationOp op) {
    return switch (op) {
      EnsureLayerOp(:final layerId, :final index) => _ensureLayer(
        ctx,
        layerId,
        index: index,
      ),
      InsertNodeOp(:final spec, :final layerId, :final insertIndex) => _insert(
        ctx,
        spec,
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
      ClearSceneKeepBackgroundOp() => _clearSceneKeepBackground(ctx),
      ReplaceSceneOp(:final snapshot) => _replaceScene(ctx, snapshot),
      SetBackgroundColorOp(:final color) => _setBackgroundColor(ctx, color),
      SetGridEnabledOp(:final enabled) => _setGridEnabled(ctx, enabled),
      SetGridCellSizeOp(:final cellSize) => _setGridCellSize(ctx, cellSize),
      SetCameraOffsetOp(:final offset) => _setCameraOffset(ctx, offset),
      TransformSelectionOp(:final delta) => _transformSelection(ctx, delta),
      TranslateSelectionOp(:final delta) => _translateSelection(ctx, delta),
    };
  }

  void _runPostcheck(TxnContext ctx, MutationOp op, {required bool changed}) {
    if (!changed) {
      return;
    }
    switch (op) {
      case EnsureLayerOp():
      case InsertNodeOp():
      case PatchNodeOp():
      case SetNodeTransformOp():
      case DeleteNodeOp():
      case DeleteNodesBulkOp():
      case ClearSceneKeepBackgroundOp():
      case ReplaceSceneOp():
      case SetBackgroundColorOp():
      case SetGridEnabledOp():
      case SetGridCellSizeOp():
      case SetCameraOffsetOp():
      case TransformSelectionOp():
      case TranslateSelectionOp():
        ctx.txnEnsureActive();
    }
  }

  MutationCommitCandidate? _prepareCommitCandidate(TxnContext ctx) {
    if (!ctx.changeSet.txnHasAnyChange) {
      return null;
    }
    return MutationCommitCandidate(
      scene: ctx.txnSceneForCommit(),
      selection: HashSet<NodeId>.of(ctx.workingSelection),
      allNodeIds: ctx.txnAllNodeIdsForCommit(
        structuralChanged: ctx.changeSet.structuralChanged,
      ),
      nodeLocator: ctx.txnNodeLocatorForCommit(
        structuralChanged: ctx.changeSet.structuralChanged,
      ),
      idGeneratorState: ctx.idGeneratorState.copy(),
      revisionState: ctx.revisionState.copy(),
    );
  }

  MutationApplyResult _ensureLayer(
    TxnContext ctx,
    LayerId layerId, {
    int? index,
  }) {
    final created = ctx.txnEnsureContentLayer(layerId, index: index);
    if (!created) {
      return const MutationApplyResult(value: false, changed: false);
    }
    ctx.changeSet.txnMarkStructuralChanged();
    return const MutationApplyResult(value: true, changed: true);
  }

  MutationApplyResult _insert(
    TxnContext ctx,
    NodeSpec spec, {
    LayerId? layerId,
    int? insertIndex,
  }) {
    final resolvedId = spec.id ?? ctx.txnNextNodeId();
    final node = txnNodeFromSpec(
      _normalizeInsertSpec(spec),
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
    return MutationApplyResult(value: node.id, changed: true);
  }

  MutationApplyResult _patch(TxnContext ctx, NodePatch patch) {
    final existing = ctx.txnFindNodeById(patch.id);
    if (existing == null) {
      return const MutationApplyResult(value: false, changed: false);
    }
    if (!txnApplyNodePatch(existing.node, patch, dryRun: true)) {
      return const MutationApplyResult(value: false, changed: false);
    }

    final found = ctx.txnResolveMutableNode(patch.id);
    final oldCandidate = nodeHitTestCandidateBoundsWorld(found.node);
    txnApplyNodePatch(found.node, patch);

    ctx.changeSet.txnTrackUpdated(patch.id);
    final newCandidate = nodeHitTestCandidateBoundsWorld(found.node);
    if (oldCandidate != newCandidate) {
      ctx.changeSet
        ..txnMarkBoundsChanged()
        ..txnTrackHitGeometryChanged(patch.id);
    } else {
      ctx.changeSet.txnMarkVisualChanged();
    }
    if (ctx.workingSelection.contains(patch.id) &&
        _patchTouchesSelectionPolicy(patch)) {
      ctx.changeSet.txnMarkSelectionChanged();
    }
    return const MutationApplyResult(value: true, changed: true);
  }

  MutationApplyResult _setNodeTransform(
    TxnContext ctx,
    NodeId nodeId,
    Transform2D transform,
  ) {
    final existing = ctx.txnFindNodeById(nodeId);
    if (existing == null || existing.node.transform == transform) {
      return const MutationApplyResult(value: false, changed: false);
    }

    final found = ctx.txnResolveMutableNode(nodeId);
    final oldCandidate = nodeHitTestCandidateBoundsWorld(found.node);
    found.node.transform = transform;
    ctx.changeSet.txnTrackUpdated(nodeId);
    final newCandidate = nodeHitTestCandidateBoundsWorld(found.node);
    if (oldCandidate != newCandidate) {
      ctx.changeSet
        ..txnMarkBoundsChanged()
        ..txnTrackHitGeometryChanged(nodeId);
    } else {
      ctx.changeSet.txnMarkVisualChanged();
    }
    return const MutationApplyResult(value: true, changed: true);
  }

  MutationApplyResult _deleteNode(TxnContext ctx, NodeId nodeId) {
    final existing = ctx.txnFindNodeById(nodeId);
    if (existing == null ||
        existing.layerIndex == -1 ||
        !isNodeDeletableInLayer(existing.node)) {
      return const MutationApplyResult(value: false, changed: false);
    }
    ctx.txnEnsureMutableLayer(existing.layerIndex);
    final removedNodeIds = txnEraseNodesFromScene(
      scene: ctx.txnEnsureMutableScene(),
      nodeLocator: ctx.txnEnsureMutableNodeLocator(),
      nodeIds: <NodeId>{nodeId},
    );
    if (removedNodeIds.isEmpty) {
      return const MutationApplyResult(value: false, changed: false);
    }

    final hadSelection = ctx.workingSelection.remove(nodeId);
    ctx.txnForgetNodeId(nodeId);
    ctx.changeSet
      ..txnMarkStructuralChanged()
      ..txnTrackRemoved(nodeId);
    if (hadSelection) {
      ctx.changeSet.txnMarkSelectionChanged();
    }
    return const MutationApplyResult(value: true, changed: true);
  }

  MutationApplyResult _deleteNodesBulk(TxnContext ctx, Set<NodeId> nodeIds) {
    if (nodeIds.isEmpty) {
      return const MutationApplyResult(value: 0, changed: false);
    }

    final targetLayerIndexes = <int>{};
    for (final nodeId in nodeIds) {
      final existing = ctx.txnFindNodeById(nodeId);
      if (existing == null ||
          existing.layerIndex == -1 ||
          !isNodeDeletableInLayer(existing.node)) {
        continue;
      }
      targetLayerIndexes.add(existing.layerIndex);
    }
    if (targetLayerIndexes.isEmpty) {
      return const MutationApplyResult(value: 0, changed: false);
    }
    final sortedLayerIndexes = targetLayerIndexes.toList(growable: false)
      ..sort();
    for (final layerIndex in sortedLayerIndexes) {
      ctx.txnEnsureMutableLayer(layerIndex);
    }

    final deleted = txnEraseNodesFromScene(
      scene: ctx.txnEnsureMutableScene(),
      nodeLocator: ctx.txnEnsureMutableNodeLocator(),
      nodeIds: nodeIds,
    );
    if (deleted.isEmpty) {
      return const MutationApplyResult(value: 0, changed: false);
    }

    for (final id in deleted) {
      ctx.txnForgetNodeId(id);
    }
    ctx.changeSet.txnMarkStructuralChanged();
    for (final id in deleted) {
      ctx.changeSet.txnTrackRemoved(id);
    }
    final hadSelection = deleted.any(ctx.workingSelection.contains);
    ctx.workingSelection.removeAll(deleted);
    if (hadSelection) {
      ctx.changeSet.txnMarkSelectionChanged();
    }
    return MutationApplyResult(value: deleted.length, changed: true);
  }

  MutationApplyResult _clearSceneKeepBackground(TxnContext ctx) {
    final result = txnClearSceneKeepBackground(
      scene: ctx.txnEnsureMutableScene(),
      nodeLocator: ctx.txnEnsureMutableNodeLocator(),
    );
    for (final id in result.removedNodeIds) {
      ctx.txnForgetNodeId(id);
    }
    if (!result.didStructuralClear) {
      return MutationApplyResult(
        value: ClearSceneResult(
          removedNodeIds: result.removedNodeIds,
          didStructuralClear: false,
        ),
        changed: false,
      );
    }

    ctx.changeSet.txnMarkStructuralChanged();
    for (final id in result.removedNodeIds) {
      ctx.changeSet.txnTrackRemoved(id);
    }
    if (ctx.workingSelection.isNotEmpty) {
      ctx.workingSelection.clear();
      ctx.changeSet.txnMarkSelectionChanged();
    }
    return MutationApplyResult(
      value: ClearSceneResult(
        removedNodeIds: result.removedNodeIds,
        didStructuralClear: true,
      ),
      changed: true,
    );
  }

  MutationApplyResult _replaceScene(TxnContext ctx, SceneSnapshot snapshot) {
    final hadSelection = ctx.workingSelection.isNotEmpty;
    final nextScene = txnSceneFromSnapshot(
      snapshot,
      nextInstanceRevision: ctx.txnNextInstanceRevision,
    );
    ctx.txnAdoptScene(nextScene);
    ctx.workingSelection.clear();
    ctx.changeSet.txnMarkDocumentReplaced();
    if (hadSelection) {
      ctx.changeSet.txnMarkSelectionChanged();
    }
    return const MutationApplyResult(value: null, changed: true);
  }

  MutationApplyResult _setBackgroundColor(TxnContext ctx, Color color) {
    if (ctx.workingScene.background.color == color) {
      return const MutationApplyResult(value: null, changed: false);
    }
    final scene = ctx.txnEnsureMutableScene();
    scene.background.color = color;
    ctx.changeSet.txnMarkVisualChanged();
    return const MutationApplyResult(value: null, changed: true);
  }

  MutationApplyResult _setGridEnabled(TxnContext ctx, bool enabled) {
    if (ctx.workingScene.background.grid.isEnabled == enabled) {
      return const MutationApplyResult(value: null, changed: false);
    }
    final scene = ctx.txnEnsureMutableScene();
    scene.background.grid.isEnabled = enabled;
    ctx.changeSet.txnMarkGridChanged();
    return const MutationApplyResult(value: null, changed: true);
  }

  MutationApplyResult _setGridCellSize(TxnContext ctx, double cellSize) {
    if (ctx.workingScene.background.grid.cellSize == cellSize) {
      return const MutationApplyResult(value: null, changed: false);
    }
    final scene = ctx.txnEnsureMutableScene();
    scene.background.grid.cellSize = cellSize;
    ctx.changeSet.txnMarkGridChanged();
    return const MutationApplyResult(value: null, changed: true);
  }

  MutationApplyResult _setCameraOffset(TxnContext ctx, Offset offset) {
    if (ctx.workingScene.camera.offset == offset) {
      return const MutationApplyResult(value: null, changed: false);
    }
    final scene = ctx.txnEnsureMutableScene();
    scene.camera.offset = offset;
    ctx.changeSet.txnMarkVisualChanged();
    return const MutationApplyResult(value: null, changed: true);
  }

  MutationApplyResult _transformSelection(TxnContext ctx, Transform2D delta) {
    final selected = ctx.workingSelection;
    if (selected.isEmpty) {
      return const MutationApplyResult(value: 0, changed: false);
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
      ctx.changeSet.txnTrackUpdated(nodeId);
      if (beforeCandidate != afterCandidate) {
        ctx.changeSet
          ..txnMarkBoundsChanged()
          ..txnTrackHitGeometryChanged(nodeId);
      } else {
        ctx.changeSet.txnMarkVisualChanged();
      }
      affected = affected + 1;
    }
    return MutationApplyResult(value: affected, changed: affected > 0);
  }

  MutationApplyResult _translateSelection(TxnContext ctx, Offset delta) {
    if (delta == Offset.zero || ctx.workingSelection.isEmpty) {
      return const MutationApplyResult(value: 0, changed: false);
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
      return const MutationApplyResult(value: 0, changed: false);
    }

    for (final nodeId in moved) {
      ctx.changeSet
        ..txnTrackUpdated(nodeId)
        ..txnTrackHitGeometryChanged(nodeId);
    }
    ctx.changeSet.txnMarkBoundsChanged();
    return MutationApplyResult(value: moved.length, changed: true);
  }

  NodeSpec _normalizeInsertSpec(NodeSpec spec) {
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

  bool _patchTouchesSelectionPolicy(NodePatch patch) {
    final common = patch.common;
    return !common.isVisible.isAbsent || !common.isSelectable.isAbsent;
  }

  void _requireFiniteOffset(Offset value, {required String name}) {
    if (value.dx.isFinite && value.dy.isFinite) {
      return;
    }
    throw ArgumentError.value(value, name, 'Offset must be finite.');
  }

  void _requireFiniteTransform(Transform2D value, {required String name}) {
    if (!value.isFinite) {
      throw ArgumentError.value(
        value,
        name,
        'Transform2D fields must be finite.',
      );
    }
    if (value.invert() == null) {
      throw ArgumentError.value(
        value.toJsonMap(),
        name,
        'Transform2D must be invertible (non-singular).',
      );
    }
  }

  void _requireFinitePositive(double value, {required String name}) {
    if (value.isFinite && value > 0) {
      return;
    }
    throw ArgumentError.value(value, name, 'Must be a finite number > 0.');
  }
}

class MutationApplyResult {
  const MutationApplyResult({required this.value, required this.changed});

  final Object? value;
  final bool changed;
}
