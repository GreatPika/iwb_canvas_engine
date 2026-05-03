import 'dart:collection';
import 'dart:ui';

import '../contract/node_patch.dart';
import '../contract/node_spec.dart';
import '../contract/snapshot.dart';
import '../contract/scene_write_txn.dart';
import '../contract/transform2d.dart';
import 'scene_snapshot_materializer.dart';

sealed class MutationOp {
  const MutationOp();
}

sealed class TypedMutationOp<TValue extends Object?> extends MutationOp {
  const TypedMutationOp();
}

sealed class StructuralDocumentMutationOp<TValue extends Object?>
    extends TypedMutationOp<TValue> {
  const StructuralDocumentMutationOp();
}

sealed class NodeMutationOp<TValue extends Object?>
    extends TypedMutationOp<TValue> {
  const NodeMutationOp();
}

sealed class SceneSettingsMutationOp<TValue extends Object?>
    extends TypedMutationOp<TValue> {
  const SceneSettingsMutationOp();
}

sealed class SelectionStateMutationOp<TValue extends Object?>
    extends TypedMutationOp<TValue> {
  const SelectionStateMutationOp();
}

sealed class SelectionTransformMutationOp<TValue extends Object?>
    extends TypedMutationOp<TValue> {
  const SelectionTransformMutationOp();
}

final class EnsureLayerOp extends StructuralDocumentMutationOp<bool> {
  const EnsureLayerOp(this.layerId, {this.index});

  final LayerId layerId;
  final int? index;
}

final class InsertNodeOp extends NodeMutationOp<NodeId> {
  const InsertNodeOp(this.spec, {this.layerId, this.insertIndex});

  final NodeSpec spec;
  final LayerId? layerId;
  final int? insertIndex;
}

final class PatchNodeOp extends NodeMutationOp<bool> {
  const PatchNodeOp(this.patch);

  final NodePatch patch;
}

final class SetNodeTransformOp extends NodeMutationOp<bool> {
  const SetNodeTransformOp(this.nodeId, this.transform);

  final NodeId nodeId;
  final Transform2D transform;
}

final class DeleteNodeOp extends NodeMutationOp<bool> {
  const DeleteNodeOp(this.nodeId);

  final NodeId nodeId;
}

final class DeleteNodesBulkOp extends NodeMutationOp<List<NodeId>> {
  DeleteNodesBulkOp(Iterable<NodeId> nodeIds)
    : nodeIds = Set<NodeId>.unmodifiable(nodeIds.toSet());

  DeleteNodesBulkOp.borrowed(this.nodeIds);

  final Set<NodeId> nodeIds;
}

final class ClearSceneKeepBackgroundOp
    extends StructuralDocumentMutationOp<ClearSceneResult> {
  const ClearSceneKeepBackgroundOp();
}

final class ReplaceSceneOp extends StructuralDocumentMutationOp<Object?> {
  const ReplaceSceneOp(this.replacement, this.owner);

  final PreparedSceneReplacement replacement;
  final PreparedSceneReplacementOwner owner;
}

final class SetBackgroundColorOp extends SceneSettingsMutationOp<Object?> {
  const SetBackgroundColorOp(this.color);

  final Color color;
}

final class SetGridEnabledOp extends SceneSettingsMutationOp<Object?> {
  const SetGridEnabledOp(this.enabled);

  final bool enabled;
}

final class SetGridCellSizeOp extends SceneSettingsMutationOp<Object?> {
  const SetGridCellSizeOp(this.cellSize);

  final double cellSize;
}

final class SetCameraOffsetOp extends SceneSettingsMutationOp<Object?> {
  const SetCameraOffsetOp(this.offset);

  final Offset offset;
}

final class ReplaceSelectionOp extends SelectionStateMutationOp<List<NodeId>?> {
  ReplaceSelectionOp(Iterable<NodeId> nodeIds)
    : nodeIds = Set<NodeId>.unmodifiable(nodeIds.toSet());

  final Set<NodeId> nodeIds;
}

final class ToggleSelectionOp extends SelectionStateMutationOp<bool> {
  const ToggleSelectionOp(this.nodeId);

  final NodeId nodeId;
}

final class ClearSelectionOp extends SelectionStateMutationOp<bool> {
  const ClearSelectionOp();
}

final class SelectAllSelectionOp
    extends SelectionStateMutationOp<({int selectedCount, bool changed})> {
  const SelectAllSelectionOp({this.onlySelectable = true});

  final bool onlySelectable;
}

final class TransformSelectionOp extends SelectionTransformMutationOp<int> {
  const TransformSelectionOp(this.delta);

  final Transform2D delta;
}

final class TranslateSelectionOp extends SelectionTransformMutationOp<int> {
  const TranslateSelectionOp(this.delta);

  final Offset delta;
}

const List<Type> kCanonicalMutationOpTypes = <Type>[
  EnsureLayerOp,
  InsertNodeOp,
  PatchNodeOp,
  SetNodeTransformOp,
  DeleteNodeOp,
  DeleteNodesBulkOp,
  ClearSceneKeepBackgroundOp,
  ReplaceSceneOp,
  SetBackgroundColorOp,
  SetGridEnabledOp,
  SetGridCellSizeOp,
  SetCameraOffsetOp,
  ReplaceSelectionOp,
  ToggleSelectionOp,
  ClearSelectionOp,
  SelectAllSelectionOp,
  TransformSelectionOp,
  TranslateSelectionOp,
];

UnmodifiableListView<Type> canonicalMutationOpTypesView() {
  return UnmodifiableListView<Type>(kCanonicalMutationOpTypes);
}

class MutationApplyResult<TValue extends Object?> {
  const MutationApplyResult({required this.value, required this.changed});

  final TValue value;
  final bool changed;
}
