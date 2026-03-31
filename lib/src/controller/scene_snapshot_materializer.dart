import 'dart:ui' hide Scene;

import '../contract/snapshot.dart';
import '../core/revision_policy.dart';
import '../core/scene.dart' show Scene;
import '../model/document.dart';

final class PreparedSceneReplacement {
  const PreparedSceneReplacement({
    required this.scene,
    required this.nextInstanceRevision,
  });

  final Scene scene;
  final int nextInstanceRevision;
}

PreparedSceneReplacement materializeSceneReplacement({
  required SceneSnapshot snapshot,
  required int nextInstanceRevisionSeed,
}) {
  var nextInstanceRevision = requireRevisionCounter(
    nextInstanceRevisionSeed,
    name: 'nextInstanceRevisionSeed',
  );
  final scene = txnSceneFromSnapshot(
    snapshot,
    nextInstanceRevision: () => nextInstanceRevision++,
  );
  return PreparedSceneReplacement(
    scene: scene,
    nextInstanceRevision: nextInstanceRevision,
  );
}

Rect boundsWorldForNodeSnapshot(NodeSnapshot snapshot) {
  return txnNodeFromSnapshot(snapshot).boundsWorld;
}

Offset centerWorldForNodeSnapshotsMaterialized(
  Iterable<NodeSnapshot> snapshots,
) {
  Rect? bounds;
  for (final snapshot in snapshots) {
    final nodeBounds = boundsWorldForNodeSnapshot(snapshot);
    bounds = bounds == null ? nodeBounds : bounds.expandToInclude(nodeBounds);
  }
  return bounds?.center ?? Offset.zero;
}
