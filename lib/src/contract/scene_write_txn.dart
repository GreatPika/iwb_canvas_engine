import 'dart:ui';

import 'node_patch.dart';
import 'node_spec.dart';
import 'snapshot.dart';
import 'transform2d.dart';

/// Result of clearing content layers while preserving the background layer.
class ClearSceneResult {
  /// Creates an immutable clear-scene result snapshot.
  ClearSceneResult({
    required List<NodeId> removedNodeIds,
    required this.didStructuralClear,
  }) : removedNodeIds = List<NodeId>.unmodifiable(
         List<NodeId>.from(removedNodeIds),
       );

  /// Immutable snapshot of removed ids; callers must treat it as read-only.
  final List<NodeId> removedNodeIds;

  /// Whether the clear caused any structural change to the document.
  final bool didStructuralClear;
}

/// Safe transactional write contract exposed by public controllers.
///
/// This API intentionally avoids exposing mutable scene internals.
/// A `SceneWriteTxn` instance is valid only inside the active
/// `controller.write((txn) { ... })` callback.
/// Calling any `write*` method after that callback returns throws `StateError`.
abstract interface class SceneWriteTxn {
  /// Immutable read view of the transaction state.
  SceneSnapshot get snapshot;

  /// Current immutable selection view for the transaction.
  Set<NodeId> get selectedNodeIds;

  /// Inserts a node into content layers.
  ///
  /// `layerId` addresses only `snapshot.layers` (content layers) and never
  /// the optional background layer.
  /// Throws [ArgumentError] when:
  /// - `spec.id` is explicitly provided and already exists in the scene;
  /// - `layerId` does not address an existing content layer.
  ///
  /// Throws [RangeError] when `insertIndex` is outside the target layer bounds.
  NodeId writeNodeInsert(NodeSpec spec, {LayerId? layerId, int? insertIndex});

  /// Ensures a content layer with [layerId] exists.
  ///
  /// Returns `true` only when a new layer is created.
  ///
  /// Throws [RangeError] when `index` is outside the content-layer bounds.
  bool writeLayerEnsure(LayerId layerId, {int? index});

  /// Removes a single node by id.
  bool writeNodeErase(NodeId nodeId);

  /// Applies a partial node update.
  ///
  /// Returns `false` when the target node does not exist or the patch is a
  /// semantic no-op for the current node state.
  ///
  /// Throws [ArgumentError] when [patch] does not match the target node type.
  bool writeNodePatch(NodePatch patch);

  /// Replaces a node transform.
  ///
  /// Throws [ArgumentError] when [transform] contains non-finite fields or is
  /// non-invertible.
  bool writeNodeTransformSet(NodeId id, Transform2D transform);

  /// Replaces selection with normalized visible content ids.
  ///
  /// Returns `true` only when resulting selection differs from current state.
  /// If all input ids are invalid/missing/background/invisible, this is a no-op
  /// and returns `false`; use [writeSelectionClear] to clear selection
  /// explicitly.
  bool writeSelectionReplace(Iterable<NodeId> ids);

  /// Toggles a single selection id when it points to a visible content node.
  ///
  /// Returns `true` only when selection changes.
  /// Invalid/missing/background/invisible ids are ignored and return `false`.
  bool writeSelectionToggle(NodeId id);

  /// Clears the current selection.
  bool writeSelectionClear();

  /// Selects all visible content nodes according to [onlySelectable].
  int writeSelectionSelectAll({bool onlySelectable = true});

  /// Translates the current selection by [delta].
  ///
  /// Throws [ArgumentError] when [delta] is not finite.
  int writeSelectionTranslate(Offset delta);

  /// Applies [delta] as a transform to the current selection.
  ///
  /// Composition uses pre-multiply semantics:
  /// `nextTransform = delta.multiply(existingTransform)`.
  ///
  /// Throws [ArgumentError] when [delta] contains non-finite fields or is
  /// non-invertible.
  int writeSelectionTransform(Transform2D delta);

  /// Deletes deletable nodes in the current selection.
  int writeDeleteSelection();

  /// Clears all content layers while keeping a dedicated background layer.
  ///
  /// `didStructuralClear` is `true` when clear causes any structural change,
  /// including canonicalization such as creating a missing background layer.
  /// For structural-only clear, `removedNodeIds` can be empty.
  ClearSceneResult writeClearSceneKeepBackgroundResult();

  /// Clears all content layers and returns removed node ids only.
  ///
  /// The returned list is an immutable snapshot detached from writer internals.
  List<NodeId> writeClearSceneKeepBackground();

  /// Replaces the camera offset.
  ///
  /// Throws [ArgumentError] when [offset] is not finite.
  void writeCameraOffset(Offset offset);

  /// Enables or disables the background grid.
  void writeGridEnable(bool enabled);

  /// Replaces the background grid cell size.
  ///
  /// Throws [ArgumentError] when [cellSize] is non-finite or not positive.
  void writeGridCellSize(double cellSize);

  /// Replaces the background color.
  void writeBackgroundColor(Color color);

  /// Replaces the entire document snapshot.
  void writeDocumentReplace(SceneSnapshot snapshot);
}
