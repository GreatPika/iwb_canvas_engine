import 'dart:ui';

import '../core/transform2d.dart';
import 'node_patch.dart';
import 'node_spec.dart';
import 'snapshot.dart';

/// Safe transactional write contract exposed by public controllers.
///
/// This API intentionally avoids exposing mutable scene internals.
abstract interface class SceneWriteTxn {
  /// Immutable read view of the transaction state.
  SceneSnapshot get snapshot;

  /// Current selection snapshot for the transaction.
  Set<NodeId> get selectedNodeIds;

  /// Inserts a node into content layers.
  ///
  /// `layerIndex` addresses only `snapshot.layers` (content layers) and never
  /// the optional background layer.
  String writeNodeInsert(NodeSpec spec, {int? layerIndex});
  bool writeNodeErase(NodeId nodeId);
  bool writeNodePatch(NodePatch patch);
  bool writeNodeTransformSet(NodeId id, Transform2D transform);

  void writeSelectionReplace(Iterable<NodeId> ids);
  void writeSelectionToggle(NodeId id);
  bool writeSelectionClear();
  int writeSelectionSelectAll({bool onlySelectable = true});

  int writeSelectionTranslate(Offset delta);
  int writeSelectionTransform(Transform2D delta);
  int writeDeleteSelection();
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
