import 'mutation_op.dart';
import 'node_mutation_applier.dart';
import 'selection_post_apply_finalizer.dart';
import 'selection_state_mutation_applier.dart';
import 'selection_transform_mutation_applier.dart';
import 'scene_mutation_applier.dart';
import 'txn_context.dart';

class MutationExecutor {
  const MutationExecutor({this.textFontFamilyByDefault});

  final String? textFontFamilyByDefault;

  MutationApplyResult<TValue> execute<TValue extends Object?>(
    TxnContext ctx,
    TypedMutationOp<TValue> op,
  ) {
    ctx.txnEnsureActive();
    return switch (op) {
      StructuralDocumentMutationOp() =>
        _executeStructuralDocumentMutation<TValue>(ctx, op),
      NodeMutationOp() => _executeNodeMutation<TValue>(ctx, op),
      SceneSettingsMutationOp() => _castResult<TValue>(
        executeSceneSettingsMutationOp(ctx, op),
      ),
      SelectionStateMutationOp() => _castResult<TValue>(
        executeSelectionStateMutationOp(ctx, op),
      ),
      SelectionTransformMutationOp() => _castResult<TValue>(
        executeSelectionTransformMutationOp(ctx, op),
      ),
    };
  }

  MutationApplyResult<TValue> _executeStructuralDocumentMutation<
    TValue extends Object?
  >(TxnContext ctx, StructuralDocumentMutationOp<TValue> op) {
    final result = executeStructuralDocumentMutationOp(ctx, op);
    if (result.changed && _requiresPostApplySelectionFinalization(op)) {
      finalizePostApplySelection(ctx);
    }
    return _castResult<TValue>(result);
  }

  MutationApplyResult<TValue> _executeNodeMutation<TValue extends Object?>(
    TxnContext ctx,
    NodeMutationOp<TValue> op,
  ) {
    final result = executeNodeMutationOp(
      ctx,
      op,
      textFontFamilyByDefault: textFontFamilyByDefault,
    );
    if (result.changed && _requiresPostApplySelectionFinalization(op)) {
      finalizePostApplySelection(ctx);
    }
    return _castResult<TValue>(result);
  }

  MutationApplyResult<TValue> _castResult<TValue extends Object?>(
    MutationApplyResult<Object?> result,
  ) {
    return MutationApplyResult<TValue>(
      value: result.value as TValue,
      changed: result.changed,
    );
  }
}

bool _requiresPostApplySelectionFinalization(TypedMutationOp<Object?> op) {
  return switch (op) {
    ClearSceneKeepBackgroundOp() => true,
    ReplaceSceneOp() => true,
    PatchNodeOp(:final patch) => !patch.common.isVisible.isAbsent,
    DeleteNodeOp() => true,
    DeleteNodesBulkOp() => true,
    _ => false,
  };
}
