import 'mutation_op.dart';
import 'node_mutation_applier.dart';
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
      StructuralDocumentMutationOp() => _castResult<TValue>(
        executeStructuralDocumentMutationOp(ctx, op),
      ),
      NodeMutationOp() => _castResult<TValue>(
        executeNodeMutationOp(
          ctx,
          op,
          textFontFamilyByDefault: textFontFamilyByDefault,
        ),
      ),
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

  MutationApplyResult<TValue> _castResult<TValue extends Object?>(
    MutationApplyResult<Object?> result,
  ) {
    return MutationApplyResult<TValue>(
      value: result.value as TValue,
      changed: result.changed,
    );
  }
}
