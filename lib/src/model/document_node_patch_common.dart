import '../contract/node_patch.dart';
import '../contract/patch_field.dart';
import '../core/nodes.dart';

typedef TxnPatchAssignment<TNode, TPatch> =
    bool Function(TNode node, TPatch patch, {required bool dryRun});

bool txnApplyCommonNodePatch(
  SceneNode node,
  CommonNodePatch patch, {
  required bool dryRun,
}) {
  return txnApplyPatchPlan(
    node,
    patch,
    _commonNodePatchAssignments,
    dryRun: dryRun,
  );
}

bool txnPatchSet<T>(
  PatchField<T> patch,
  T current,
  void Function(T value) assign, {
  required bool dryRun,
}) {
  if (patch.isAbsent) {
    return false;
  }
  final next = patch.value;
  if (next == current) {
    return false;
  }
  if (!dryRun) {
    assign(next);
  }
  return true;
}

bool txnPatchSetNullable<T>(
  PatchField<T?> patch,
  T? current,
  void Function(T? value) assign, {
  required bool dryRun,
}) {
  if (patch.isAbsent) {
    return false;
  }
  final next = patch.valueOrNull;
  if (next == current) {
    return false;
  }
  if (!dryRun) {
    assign(next);
  }
  return true;
}

TxnPatchAssignment<TNode, TPatch>
txnPatchValueAssignment<TNode, TPatch, TValue>({
  required PatchField<TValue> Function(TPatch patch) patchField,
  required TValue Function(TNode node) currentValue,
  required void Function(TNode node, TValue value) assign,
}) {
  return (node, patch, {required dryRun}) => txnPatchSet(
    patchField(patch),
    currentValue(node),
    (value) => assign(node, value),
    dryRun: dryRun,
  );
}

TxnPatchAssignment<TNode, TPatch>
txnPatchNullableValueAssignment<TNode, TPatch, TValue>({
  required PatchField<TValue?> Function(TPatch patch) patchField,
  required TValue? Function(TNode node) currentValue,
  required void Function(TNode node, TValue? value) assign,
}) {
  return (node, patch, {required dryRun}) => txnPatchSetNullable(
    patchField(patch),
    currentValue(node),
    (value) => assign(node, value),
    dryRun: dryRun,
  );
}

bool txnApplyPatchPlan<TNode, TPatch>(
  TNode node,
  TPatch patch,
  List<TxnPatchAssignment<TNode, TPatch>> assignments, {
  required bool dryRun,
}) {
  var changed = false;
  for (final applyAssignment in assignments) {
    changed = applyAssignment(node, patch, dryRun: dryRun) || changed;
  }
  return changed;
}

final List<TxnPatchAssignment<SceneNode, CommonNodePatch>>
_commonNodePatchAssignments = <TxnPatchAssignment<SceneNode, CommonNodePatch>>[
  txnPatchValueAssignment(
    patchField: (patch) => patch.transform,
    currentValue: (node) => node.transform,
    assign: (node, value) => node.transform = value,
  ),
  txnPatchValueAssignment(
    patchField: (patch) => patch.opacity,
    currentValue: (node) => node.opacity,
    assign: (node, value) => node.opacity = value,
  ),
  txnPatchValueAssignment(
    patchField: (patch) => patch.hitPadding,
    currentValue: (node) => node.hitPadding,
    assign: (node, value) => node.hitPadding = value,
  ),
  txnPatchValueAssignment(
    patchField: (patch) => patch.isVisible,
    currentValue: (node) => node.isVisible,
    assign: (node, value) => node.isVisible = value,
  ),
  txnPatchValueAssignment(
    patchField: (patch) => patch.isSelectable,
    currentValue: (node) => node.isSelectable,
    assign: (node, value) => node.isSelectable = value,
  ),
  txnPatchValueAssignment(
    patchField: (patch) => patch.isLocked,
    currentValue: (node) => node.isLocked,
    assign: (node, value) => node.isLocked = value,
  ),
  txnPatchValueAssignment(
    patchField: (patch) => patch.isDeletable,
    currentValue: (node) => node.isDeletable,
    assign: (node, value) => node.isDeletable = value,
  ),
  txnPatchValueAssignment(
    patchField: (patch) => patch.isTransformable,
    currentValue: (node) => node.isTransformable,
    assign: (node, value) => node.isTransformable = value,
  ),
];
