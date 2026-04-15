import 'dart:ui' hide Scene;

import '../contract/ids.dart';
import '../contract/scene_write_txn.dart';
import '../core/scene.dart' show Scene;
import '../model/document.dart';
import 'mutation_input_guards.dart';
import 'mutation_op.dart';
import 'scene_snapshot_materializer.dart';
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
    ReplaceSceneOp(:final replacement, :final owner) => _replaceScene(
      ctx,
      replacement,
      owner,
    ),
  };
}

MutationApplyResult<Object?> executeSceneSettingsMutationOp(
  TxnContext ctx,
  SceneSettingsMutationOp<Object?> op,
) {
  return switch (op) {
    SetBackgroundColorOp(:final color) => _applySceneSettingUpdate<Color>(
      ctx,
      kind: _SceneSettingKind.backgroundColor,
      value: color,
    ),
    SetGridEnabledOp(:final enabled) => _applySceneSettingUpdate<bool>(
      ctx,
      kind: _SceneSettingKind.gridEnabled,
      value: enabled,
    ),
    SetGridCellSizeOp(:final cellSize) => _applySceneSettingUpdate<double>(
      ctx,
      kind: _SceneSettingKind.gridCellSize,
      value: cellSize,
      validate: (value) =>
          requireFinitePositiveMutationInput(value, name: 'cellSize'),
    ),
    SetCameraOffsetOp(:final offset) => _applySceneSettingUpdate<Offset>(
      ctx,
      kind: _SceneSettingKind.cameraOffset,
      value: offset,
      validate: (value) =>
          requireFiniteOffsetMutationInput(value, name: 'offset'),
    ),
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
  PreparedSceneReplacement replacement,
  PreparedSceneReplacementOwner owner,
) {
  final hadSelection = ctx.workingSelection.isNotEmpty;
  adoptPreparedSceneReplacement(
    ctx: ctx,
    replacement: replacement,
    owner: owner,
  );
  ctx.workingSelection.clear();
  ctx.changeSet.txnMarkDocumentReplaced();
  if (hadSelection) {
    ctx.changeSet.txnMarkSelectionChanged();
  }
  return const MutationApplyResult<Object?>(value: null, changed: true);
}

MutationApplyResult<Object?> _applySceneSettingUpdate<T>(
  TxnContext ctx, {
  required _SceneSettingKind kind,
  required T value,
  void Function(T value)? validate,
}) {
  validate?.call(value);
  if (_isSceneSettingNoop(ctx.workingScene, kind: kind, value: value)) {
    return const MutationApplyResult<Object?>(value: null, changed: false);
  }
  _applySceneSettingChange(ctx, kind: kind, value: value);
  return const MutationApplyResult<Object?>(value: null, changed: true);
}

bool _isSceneSettingNoop<T>(
  Scene scene, {
  required _SceneSettingKind kind,
  required T value,
}) {
  return switch (kind) {
    _SceneSettingKind.backgroundColor => scene.background.color == value,
    _SceneSettingKind.gridEnabled => scene.background.grid.isEnabled == value,
    _SceneSettingKind.gridCellSize => scene.background.grid.cellSize == value,
    _SceneSettingKind.cameraOffset => scene.camera.offset == value,
  };
}

void _applySceneSettingChange<T>(
  TxnContext ctx, {
  required _SceneSettingKind kind,
  required T value,
}) {
  final mutableScene = ctx.txnEnsureMutableScene();
  switch (kind) {
    case _SceneSettingKind.backgroundColor:
      mutableScene.background.color = value as Color;
      ctx.changeSet.txnMarkVisualChanged();
    case _SceneSettingKind.gridEnabled:
      mutableScene.background.grid.isEnabled = value as bool;
      ctx.changeSet.txnMarkGridChanged();
    case _SceneSettingKind.gridCellSize:
      mutableScene.background.grid.cellSize = value as double;
      ctx.changeSet.txnMarkGridChanged();
    case _SceneSettingKind.cameraOffset:
      mutableScene.camera.offset = value as Offset;
      ctx.changeSet.txnMarkVisualChanged();
  }
}

enum _SceneSettingKind {
  backgroundColor,
  gridEnabled,
  gridCellSize,
  cameraOffset,
}
