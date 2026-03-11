import 'dart:collection';
import 'dart:ui';

import '../contract/node_patch.dart';
import '../contract/node_spec.dart';
import '../contract/snapshot.dart';
import '../contract/transform2d.dart';

sealed class MutationOp {
  const MutationOp();
}

sealed class StructuralDocumentMutationOp extends MutationOp {
  const StructuralDocumentMutationOp();
}

sealed class NodeMutationOp extends MutationOp {
  const NodeMutationOp();
}

sealed class SceneSettingsMutationOp extends MutationOp {
  const SceneSettingsMutationOp();
}

sealed class SelectionTransformMutationOp extends MutationOp {
  const SelectionTransformMutationOp();
}

final class EnsureLayerOp extends StructuralDocumentMutationOp {
  const EnsureLayerOp(this.layerId, {this.index});

  final LayerId layerId;
  final int? index;
}

final class InsertNodeOp extends NodeMutationOp {
  const InsertNodeOp(this.spec, {this.layerId, this.insertIndex});

  final NodeSpec spec;
  final LayerId? layerId;
  final int? insertIndex;
}

final class PatchNodeOp extends NodeMutationOp {
  const PatchNodeOp(this.patch);

  final NodePatch patch;
}

final class SetNodeTransformOp extends NodeMutationOp {
  const SetNodeTransformOp(this.nodeId, this.transform);

  final NodeId nodeId;
  final Transform2D transform;
}

final class DeleteNodeOp extends NodeMutationOp {
  const DeleteNodeOp(this.nodeId);

  final NodeId nodeId;
}

final class DeleteNodesBulkOp extends NodeMutationOp {
  DeleteNodesBulkOp(Iterable<NodeId> nodeIds)
    : nodeIds = Set<NodeId>.unmodifiable(nodeIds.toSet());

  DeleteNodesBulkOp.borrowed(this.nodeIds);

  final Set<NodeId> nodeIds;
}

final class ClearSceneKeepBackgroundOp extends StructuralDocumentMutationOp {
  const ClearSceneKeepBackgroundOp();
}

final class ReplaceSceneOp extends StructuralDocumentMutationOp {
  const ReplaceSceneOp(this.snapshot);

  final SceneSnapshot snapshot;
}

final class SetBackgroundColorOp extends SceneSettingsMutationOp {
  const SetBackgroundColorOp(this.color);

  final Color color;
}

final class SetGridEnabledOp extends SceneSettingsMutationOp {
  const SetGridEnabledOp(this.enabled);

  final bool enabled;
}

final class SetGridCellSizeOp extends SceneSettingsMutationOp {
  const SetGridCellSizeOp(this.cellSize);

  final double cellSize;
}

final class SetCameraOffsetOp extends SceneSettingsMutationOp {
  const SetCameraOffsetOp(this.offset);

  final Offset offset;
}

final class TransformSelectionOp extends SelectionTransformMutationOp {
  const TransformSelectionOp(this.delta);

  final Transform2D delta;
}

final class TranslateSelectionOp extends SelectionTransformMutationOp {
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
  TransformSelectionOp,
  TranslateSelectionOp,
];

UnmodifiableListView<Type> canonicalMutationOpTypesView() {
  return UnmodifiableListView<Type>(kCanonicalMutationOpTypes);
}
