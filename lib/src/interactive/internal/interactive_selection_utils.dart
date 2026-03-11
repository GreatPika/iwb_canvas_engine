import 'dart:ui';

import '../../contract/snapshot.dart';
import '../interaction_eligibility_policy.dart' as eligibility_policy;

// Transitional compatibility wrappers for move/draw session code paths.
// Step 11.3 moves ownership of interactive admissibility to
// interaction_eligibility_policy.dart; session-local adoption stays with 11.4
// and 11.5.
List<NodeSnapshot> selectedTransformableNodesInSnapshotOrder({
  required SceneSnapshot snapshot,
  required Set<NodeId> selected,
}) {
  return eligibility_policy.selectedTransformableNodesInSnapshotOrder(
    snapshot: snapshot,
    selected: selected,
  );
}

List<NodeId> deletableSelectedNodeIdsInSnapshot({
  required SceneSnapshot snapshot,
  required Set<NodeId> selected,
}) {
  return eligibility_policy.deletableSelectedNodeIdsInSnapshot(
    snapshot: snapshot,
    selected: selected,
  );
}

Offset centerWorldForNodeSnapshots(List<NodeSnapshot> nodes) {
  return eligibility_policy.centerWorldForNodeSnapshots(nodes);
}
