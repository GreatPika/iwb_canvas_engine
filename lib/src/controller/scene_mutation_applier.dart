import 'dart:ui';

import '../contract/snapshot.dart';
import '../contract/scene_write_txn.dart';
import '../model/document.dart';
import 'mutation_input_guards.dart';
import 'mutation_op.dart';
import 'txn_context.dart';

MutationApplyResult<Object?> executeStructuralDocumentMutationOp(
  TxnContext ctx,
  StructuralDocumentMutationOp<Object?> op,
) {
  return switch (op) {
    EnsureLayerOp(:final layerId, :final index) => _ensureLayer(
      ctx,
      layerId,
      index: index,
    ),
    ClearSceneKeepBackgroundOp() => _clearSceneKeepBackground(ctx),
    ReplaceSceneOp(:final snapshot) => _replaceScene(ctx, snapshot),
  };
}

MutationApplyResult<Object?> executeSceneSettingsMutationOp(
  TxnContext ctx,
  SceneSettingsMutationOp<Object?> op,
) {
  return switch (op) {
    SetBackgroundColorOp(:final color) => _setBackgroundColor(ctx, color),
    SetGridEnabledOp(:final enabled) => _setGridEnabled(ctx, enabled),
    SetGridCellSizeOp(:final cellSize) => _setGridCellSize(ctx, cellSize),
    SetCameraOffsetOp(:final offset) => _setCameraOffset(ctx, offset),
  };
}

MutationApplyResult<bool> _ensureLayer(
  TxnContext ctx,
  LayerId layerId, {
  int? index,
}) {
  final created = ctx.txnEnsureContentLayer(layerId, index: index);
  if (!created) {
    return const MutationApplyResult<bool>(value: false, changed: false);
  }
  ctx.changeSet.txnMarkStructuralChanged();
  return const MutationApplyResult<bool>(value: true, changed: true);
}

MutationApplyResult<ClearSceneResult> _clearSceneKeepBackground(
  TxnContext ctx,
) {
  final result = txnClearSceneKeepBackground(
    scene: ctx.txnEnsureMutableScene(),
    nodeLocator: ctx.txnEnsureMutableNodeLocator(),
  );
  for (final id in result.removedNodeIds) {
    ctx.txnForgetNodeId(id);
  }
  if (!result.didStructuralClear) {
    return MutationApplyResult<ClearSceneResult>(
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
  return MutationApplyResult<ClearSceneResult>(
    value: ClearSceneResult(
      removedNodeIds: result.removedNodeIds,
      didStructuralClear: true,
    ),
    changed: true,
  );
}

MutationApplyResult<Object?> _replaceScene(
  TxnContext ctx,
  SceneSnapshot snapshot,
) {
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
  return const MutationApplyResult<Object?>(value: null, changed: true);
}

MutationApplyResult<Object?> _setBackgroundColor(TxnContext ctx, Color color) {
  if (ctx.workingScene.background.color == color) {
    return const MutationApplyResult<Object?>(value: null, changed: false);
  }
  final scene = ctx.txnEnsureMutableScene();
  scene.background.color = color;
  ctx.changeSet.txnMarkVisualChanged();
  return const MutationApplyResult<Object?>(value: null, changed: true);
}

MutationApplyResult<Object?> _setGridEnabled(TxnContext ctx, bool enabled) {
  if (ctx.workingScene.background.grid.isEnabled == enabled) {
    return const MutationApplyResult<Object?>(value: null, changed: false);
  }
  final scene = ctx.txnEnsureMutableScene();
  scene.background.grid.isEnabled = enabled;
  ctx.changeSet.txnMarkGridChanged();
  return const MutationApplyResult<Object?>(value: null, changed: true);
}

MutationApplyResult<Object?> _setGridCellSize(TxnContext ctx, double cellSize) {
  requireFinitePositiveMutationInput(cellSize, name: 'cellSize');
  if (ctx.workingScene.background.grid.cellSize == cellSize) {
    return const MutationApplyResult<Object?>(value: null, changed: false);
  }
  final scene = ctx.txnEnsureMutableScene();
  scene.background.grid.cellSize = cellSize;
  ctx.changeSet.txnMarkGridChanged();
  return const MutationApplyResult<Object?>(value: null, changed: true);
}

MutationApplyResult<Object?> _setCameraOffset(TxnContext ctx, Offset offset) {
  requireFiniteOffsetMutationInput(offset, name: 'offset');
  if (ctx.workingScene.camera.offset == offset) {
    return const MutationApplyResult<Object?>(value: null, changed: false);
  }
  final scene = ctx.txnEnsureMutableScene();
  scene.camera.offset = offset;
  ctx.changeSet.txnMarkVisualChanged();
  return const MutationApplyResult<Object?>(value: null, changed: true);
}
