import 'dart:collection';
import 'dart:ui';

import '../contract/node_patch.dart';
import '../contract/node_spec.dart';
import '../contract/snapshot.dart';
import '../contract/transform2d.dart';

sealed class MutationOp {
  const MutationOp();
}

final class EnsureLayerOp extends MutationOp {
  const EnsureLayerOp(this.layerId, {this.index});

  final LayerId layerId;
  final int? index;
}

final class InsertNodeOp extends MutationOp {
  const InsertNodeOp(this.spec, {this.layerId, this.insertIndex});

  final NodeSpec spec;
  final LayerId? layerId;
  final int? insertIndex;
}

final class PatchNodeOp extends MutationOp {
  const PatchNodeOp(this.patch);

  final NodePatch patch;
}

final class SetNodeTransformOp extends MutationOp {
  const SetNodeTransformOp(this.nodeId, this.transform);

  final NodeId nodeId;
  final Transform2D transform;
}

final class DeleteNodeOp extends MutationOp {
  const DeleteNodeOp(this.nodeId);

  final NodeId nodeId;
}

final class DeleteNodesBulkOp extends MutationOp {
  DeleteNodesBulkOp(Iterable<NodeId> nodeIds)
    : nodeIds = Set<NodeId>.unmodifiable(nodeIds.toSet());

  final Set<NodeId> nodeIds;
}

final class ClearSceneKeepBackgroundOp extends MutationOp {
  const ClearSceneKeepBackgroundOp();
}

final class ReplaceSceneOp extends MutationOp {
  const ReplaceSceneOp(this.snapshot);

  final SceneSnapshot snapshot;
}

final class SetBackgroundColorOp extends MutationOp {
  const SetBackgroundColorOp(this.color);

  final Color color;
}

final class SetGridEnabledOp extends MutationOp {
  const SetGridEnabledOp(this.enabled);

  final bool enabled;
}

final class SetGridCellSizeOp extends MutationOp {
  const SetGridCellSizeOp(this.cellSize);

  final double cellSize;
}

final class SetCameraOffsetOp extends MutationOp {
  const SetCameraOffsetOp(this.offset);

  final Offset offset;
}

final class TransformSelectionOp extends MutationOp {
  const TransformSelectionOp(this.delta);

  final Transform2D delta;
}

final class TranslateSelectionOp extends MutationOp {
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
