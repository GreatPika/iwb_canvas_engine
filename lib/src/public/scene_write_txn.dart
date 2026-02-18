import 'dart:ui';

import '../core/transform2d.dart';
import 'node_patch.dart';
import 'node_spec.dart';
import 'snapshot.dart';

class ClearSceneResult {
  ClearSceneResult({
    required List<NodeId> removedNodeIds,
    required this.didStructuralClear,
  }) : removedNodeIds = List<NodeId>.unmodifiable(
         List<NodeId>.from(removedNodeIds),
       );

  /// Immutable snapshot of removed ids; callers must treat it as read-only.
  final List<NodeId> removedNodeIds;
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
  NodeId writeNodeInsert(NodeSpec spec, {LayerId? layerId});
  bool writeNodeErase(NodeId nodeId);
  bool writeNodePatch(NodePatch patch);
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
  bool writeSelectionClear();
  int writeSelectionSelectAll({bool onlySelectable = true});

  int writeSelectionTranslate(Offset delta);
  int writeSelectionTransform(Transform2D delta);
  int writeDeleteSelection();

  /// Clears all content layers while keeping a dedicated background layer.
  ///
  /// `didStructuralClear` is `true` when clear causes any structural change,
  /// including canonicalization such as creating a missing background layer.
  /// For structural-only clear, `removedNodeIds` can be empty.
  ClearSceneResult writeClearSceneKeepBackgroundResult();
  List<NodeId> writeClearSceneKeepBackground();

  void writeCameraOffset(Offset offset);
  void writeGridEnable(bool enabled);
  void writeGridCellSize(double cellSize);
  void writeBackgroundColor(Color color);

  void writeDocumentReplace(SceneSnapshot snapshot);

  void writeSignalEnqueue({
    required String type,
    Iterable<NodeId> nodeIds,
    Map<String, Object?>? payload,
  });
}
