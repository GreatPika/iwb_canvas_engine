import 'dart:ui';

import '../../contract/snapshot.dart';
import '../scene_controller_interactive.dart';
import 'interactive_geometry.dart';

class _SceneControllerInteractiveInternalAccess {
  const _SceneControllerInteractiveInternalAccess({
    required this.readEpoch,
    required this.previewDeltaForNode,
    required this.setBeforePointerDispatchHook,
    required this.runMoveCommitDeltaResolverForTest,
    required this.readActiveEraserPointsLength,
    required this.readEraserSpatialQueryCount,
    required this.readEraserPreciseSegmentCheckCount,
  });

  final int Function() readEpoch;
  final Offset Function(NodeId nodeId) previewDeltaForNode;
  final void Function(VoidCallback? hook) setBeforePointerDispatchHook;
  final Offset Function({
    required SceneSnapshot snapshot,
    required List<NodeSnapshot> movedNodes,
    required Offset proposedDelta,
  })
  runMoveCommitDeltaResolverForTest;
  final int Function() readActiveEraserPointsLength;
  final int Function() readEraserSpatialQueryCount;
  final int Function() readEraserPreciseSegmentCheckCount;
}

final Expando<_SceneControllerInteractiveInternalAccess>
_sceneControllerInteractiveInternalAccess =
    Expando<_SceneControllerInteractiveInternalAccess>(
      'SceneControllerInteractiveInternalAccess',
    );

void registerSceneControllerInteractiveInternalAccess(
  SceneControllerInteractive controller, {
  required int Function() readEpoch,
  required Offset Function(NodeId nodeId) previewDeltaForNode,
  required void Function(VoidCallback? hook) setBeforePointerDispatchHook,
  required Offset Function({
    required SceneSnapshot snapshot,
    required List<NodeSnapshot> movedNodes,
    required Offset proposedDelta,
  })
  runMoveCommitDeltaResolverForTest,
  required int Function() readActiveEraserPointsLength,
  required int Function() readEraserSpatialQueryCount,
  required int Function() readEraserPreciseSegmentCheckCount,
}) {
  _sceneControllerInteractiveInternalAccess[controller] =
      _SceneControllerInteractiveInternalAccess(
        readEpoch: readEpoch,
        previewDeltaForNode: previewDeltaForNode,
        setBeforePointerDispatchHook: setBeforePointerDispatchHook,
        runMoveCommitDeltaResolverForTest: runMoveCommitDeltaResolverForTest,
        readActiveEraserPointsLength: readActiveEraserPointsLength,
        readEraserSpatialQueryCount: readEraserSpatialQueryCount,
        readEraserPreciseSegmentCheckCount: readEraserPreciseSegmentCheckCount,
      );
}

void unregisterSceneControllerInteractiveInternalAccess(
  SceneControllerInteractive controller,
) {
  _sceneControllerInteractiveInternalAccess[controller] = null;
}

_SceneControllerInteractiveInternalAccess
_requireSceneControllerInteractiveInternalAccess(
  SceneControllerInteractive controller,
) {
  final access = _sceneControllerInteractiveInternalAccess[controller];
  if (access != null) {
    return access;
  }
  throw StateError(
    'SceneControllerInteractive internal access is not registered.',
  );
}

int sceneControllerInteractiveInternalEpoch(
  SceneControllerInteractive controller,
) {
  return _requireSceneControllerInteractiveInternalAccess(
    controller,
  ).readEpoch();
}

Offset sceneControllerInteractiveInternalPreviewDeltaForNode(
  SceneControllerInteractive controller,
  NodeId nodeId,
) {
  return _requireSceneControllerInteractiveInternalAccess(
    controller,
  ).previewDeltaForNode(nodeId);
}

void sceneControllerInteractiveInternalSetBeforePointerDispatchHook(
  SceneControllerInteractive controller,
  VoidCallback? hook,
) {
  _requireSceneControllerInteractiveInternalAccess(
    controller,
  ).setBeforePointerDispatchHook(hook);
}

Offset sceneControllerInteractiveInternalRunMoveCommitDeltaResolverForTest(
  SceneControllerInteractive controller, {
  required SceneSnapshot snapshot,
  required List<NodeSnapshot> movedNodes,
  required Offset proposedDelta,
}) {
  return _requireSceneControllerInteractiveInternalAccess(
    controller,
  ).runMoveCommitDeltaResolverForTest(
    snapshot: snapshot,
    movedNodes: movedNodes,
    proposedDelta: proposedDelta,
  );
}

void sceneControllerInteractiveInternalEnforceGestureBufferSoftLimitForTest(
  SceneControllerInteractive _, {
  required List<Offset> points,
  required int softLimit,
  required int trimTo,
}) {
  enforceGestureBufferSoftLimit(points, softLimit: softLimit, trimTo: trimTo);
}

int sceneControllerInteractiveInternalActiveEraserPointsLength(
  SceneControllerInteractive controller,
) {
  return _requireSceneControllerInteractiveInternalAccess(
    controller,
  ).readActiveEraserPointsLength();
}

int sceneControllerInteractiveInternalEraserSpatialQueryCount(
  SceneControllerInteractive controller,
) {
  return _requireSceneControllerInteractiveInternalAccess(
    controller,
  ).readEraserSpatialQueryCount();
}

int sceneControllerInteractiveInternalEraserPreciseSegmentCheckCount(
  SceneControllerInteractive controller,
) {
  return _requireSceneControllerInteractiveInternalAccess(
    controller,
  ).readEraserPreciseSegmentCheckCount();
}
