import 'dart:ui' hide Scene;

import '../contract/snapshot.dart';
import '../core/node_geometry.dart';
import '../core/revision_policy.dart';
import '../core/scene.dart' show Scene;
import '../model/document.dart';
import 'txn_context.dart';

final class PreparedSceneReplacement {
  const PreparedSceneReplacement._(this._backing);

  final _PreparedSceneReplacementBacking _backing;
}

final class PreparedSceneReplacementOwner {
  PreparedSceneReplacementOwner._() : _token = Object();

  final Object _token;
}

PreparedSceneReplacementOwner createPreparedSceneReplacementOwner() {
  return PreparedSceneReplacementOwner._();
}

final class _PreparedSceneReplacementBacking {
  _PreparedSceneReplacementBacking({
    required this.scene,
    required this.nextInstanceRevision,
    required this.ownerToken,
  });

  final Scene scene;
  final int nextInstanceRevision;
  final Object ownerToken;
  bool isConsumed = false;
}

PreparedSceneReplacement materializeSceneReplacement({
  required SceneSnapshot snapshot,
  required int nextInstanceRevisionSeed,
  required PreparedSceneReplacementOwner owner,
}) {
  var nextInstanceRevision = requireRevisionCounter(
    nextInstanceRevisionSeed,
    name: 'nextInstanceRevisionSeed',
  );
  final scene = txnSceneFromSnapshot(
    snapshot,
    nextInstanceRevision: () => nextInstanceRevision++,
  );
  return PreparedSceneReplacement._(
    _PreparedSceneReplacementBacking(
      scene: scene,
      nextInstanceRevision: nextInstanceRevision,
      ownerToken: owner._token,
    ),
  );
}

void adoptPreparedSceneReplacement({
  required TxnContext ctx,
  required PreparedSceneReplacement replacement,
  required PreparedSceneReplacementOwner owner,
}) {
  final backing = replacement._backing;
  if (!identical(backing.ownerToken, owner._token)) {
    throw StateError('Prepared scene replacement owner mismatch.');
  }
  if (backing.isConsumed) {
    throw StateError('Prepared scene replacement was already consumed.');
  }
  ctx.txnAdoptScene(backing.scene);
  ctx.nextInstanceRevision = backing.nextInstanceRevision;
  backing.isConsumed = true;
}

Rect boundsWorldForNodeSnapshot(NodeSnapshot snapshot) {
  return nodeSnapshotBoundsWorld(snapshot);
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
