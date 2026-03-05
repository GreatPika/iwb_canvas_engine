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

  /// Current selection snapshot for the transaction.
  Set<NodeId> get selectedNodeIds;

  /// Inserts a node into content layers.
  ///
  /// `layerId` addresses only `snapshot.layers` (content layers) and never
  /// the optional background layer.
  /// Throws `ArgumentError` when `spec.id` is explicitly provided and already
  /// exists in the scene.
  NodeId writeNodeInsert(NodeSpec spec, {LayerId? layerId, int? insertIndex});

  /// Ensures a content layer with [layerId] exists.
  ///
  /// Returns `true` only when a new layer is created.
  bool writeLayerEnsure(LayerId layerId, {int? index});

  /// Removes a single node by id.
  bool writeNodeErase(NodeId nodeId);

  /// Applies a partial node update.
  bool writeNodePatch(NodePatch patch);

  /// Replaces a node transform.
  bool writeNodeTransformSet(NodeId id, Transform2D transform);

  /// Replaces selection with normalized visible content ids.
  ///
  /// Returns `true` only when resulting selection differs from current state.
  /// If all input ids are invalid/missing/background/invisible, this is a no-op
  /// and returns `false`.
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
  int writeSelectionTranslate(Offset delta);

  /// Applies [delta] as a transform to the current selection.
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
  List<NodeId> writeClearSceneKeepBackground();

  /// Replaces the camera offset.
  void writeCameraOffset(Offset offset);

  /// Enables or disables the background grid.
  void writeGridEnable(bool enabled);

  /// Replaces the background grid cell size.
  void writeGridCellSize(double cellSize);

  /// Replaces the background color.
  void writeBackgroundColor(Color color);

  /// Replaces the entire document snapshot.
  void writeDocumentReplace(SceneSnapshot snapshot);

  /// Enqueues a committed signal for post-transaction delivery.
  void writeSignalEnqueue({
    required String type,
    Iterable<NodeId> nodeIds,
    Map<String, Object?>? payload,
  });
}
