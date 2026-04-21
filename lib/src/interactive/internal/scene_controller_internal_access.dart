import 'dart:ui';

import '../../contract/snapshot.dart';
import '../scene_controller.dart';
import '../scene_controller_interaction.dart';
import 'scene_controller_interaction_access.dart';
import 'interactive_geometry.dart';

class _SceneControllerInternalAccess {
  const _SceneControllerInternalAccess({
    required this.readEpoch,
    required this.previewDeltaForNode,
    required this.setBeforePointerDispatchHook,
    required this.runMoveCommitDeltaResolverForTest,
    required this.readInteractionAccessForTest,
    required this.readActiveEraserPointsLength,
    required this.readEraserSpatialQueryCount,
    required this.readEraserPreciseSegmentCheckCount,
  });

  final int Function() readEpoch;
  final Offset Function(NodeId nodeId) previewDeltaForNode;
  final void Function(VoidCallback? hook) setBeforePointerDispatchHook;
  final Offset Function(MoveCommitDeltaRequest request)
  runMoveCommitDeltaResolverForTest;
  final SceneControllerInteractionAccess Function()
  readInteractionAccessForTest;
  final int Function() readActiveEraserPointsLength;
  final int Function() readEraserSpatialQueryCount;
  final int Function() readEraserPreciseSegmentCheckCount;
}

final Expando<_SceneControllerInternalAccess> _sceneControllerInternalAccess =
    Expando<_SceneControllerInternalAccess>('SceneControllerInternalAccess');

final class SceneControllerInternalAccessRegistration {
  const SceneControllerInternalAccessRegistration({
    required this.readEpoch,
    required this.previewDeltaForNode,
    required this.setBeforePointerDispatchHook,
    required this.runMoveCommitDeltaResolverForTest,
    required this.readInteractionAccessForTest,
    required this.readActiveEraserPointsLength,
    required this.readEraserSpatialQueryCount,
    required this.readEraserPreciseSegmentCheckCount,
  });

  final int Function() readEpoch;
  final Offset Function(NodeId nodeId) previewDeltaForNode;
  final void Function(VoidCallback? hook) setBeforePointerDispatchHook;
  final Offset Function(MoveCommitDeltaRequest request)
  runMoveCommitDeltaResolverForTest;
  final SceneControllerInteractionAccess Function()
  readInteractionAccessForTest;
  final int Function() readActiveEraserPointsLength;
  final int Function() readEraserSpatialQueryCount;
  final int Function() readEraserPreciseSegmentCheckCount;
}

void registerSceneControllerInternalAccess(
  SceneController controller,
  SceneControllerInternalAccessRegistration registration,
) {
  _sceneControllerInternalAccess[controller] = _SceneControllerInternalAccess(
    readEpoch: registration.readEpoch,
    previewDeltaForNode: registration.previewDeltaForNode,
    setBeforePointerDispatchHook: registration.setBeforePointerDispatchHook,
    runMoveCommitDeltaResolverForTest:
        registration.runMoveCommitDeltaResolverForTest,
    readInteractionAccessForTest: registration.readInteractionAccessForTest,
    readActiveEraserPointsLength: registration.readActiveEraserPointsLength,
    readEraserSpatialQueryCount: registration.readEraserSpatialQueryCount,
    readEraserPreciseSegmentCheckCount:
        registration.readEraserPreciseSegmentCheckCount,
  );
}

void unregisterSceneControllerInternalAccess(SceneController controller) {
  _sceneControllerInternalAccess[controller] = null;
}

_SceneControllerInternalAccess _requireSceneControllerInternalAccess(
  SceneController controller,
) {
  final access = _sceneControllerInternalAccess[controller];
  if (access != null) {
    return access;
  }
  throw StateError('SceneController internal access is not registered.');
}

int sceneControllerInternalEpoch(SceneController controller) {
  return _requireSceneControllerInternalAccess(controller).readEpoch();
}

Offset sceneControllerInternalPreviewDeltaForNode(
  SceneController controller,
  NodeId nodeId,
) {
  return _requireSceneControllerInternalAccess(
    controller,
  ).previewDeltaForNode(nodeId);
}

void sceneControllerInternalSetBeforePointerDispatchHook(
  SceneController controller,
  VoidCallback? hook,
) {
  _requireSceneControllerInternalAccess(
    controller,
  ).setBeforePointerDispatchHook(hook);
}

Offset sceneControllerInternalRunMoveCommitDeltaResolverForTest(
  SceneController controller,
  MoveCommitDeltaRequest request,
) {
  return _requireSceneControllerInternalAccess(
    controller,
  ).runMoveCommitDeltaResolverForTest(request);
}

SceneControllerInteractionAccess
sceneControllerInternalInteractionAccessForTest(SceneController controller) {
  return _requireSceneControllerInternalAccess(
    controller,
  ).readInteractionAccessForTest();
}

void sceneControllerInternalEnforceGestureBufferSoftLimitForTest(
  SceneController _, {
  required List<Offset> points,
  required int softLimit,
  required int trimTo,
}) {
  enforceGestureBufferSoftLimit(points, softLimit: softLimit, trimTo: trimTo);
}

int sceneControllerInternalActiveEraserPointsLength(
  SceneController controller,
) {
  return _requireSceneControllerInternalAccess(
    controller,
  ).readActiveEraserPointsLength();
}

int sceneControllerInternalEraserSpatialQueryCount(SceneController controller) {
  return _requireSceneControllerInternalAccess(
    controller,
  ).readEraserSpatialQueryCount();
}

int sceneControllerInternalEraserPreciseSegmentCheckCount(
  SceneController controller,
) {
  return _requireSceneControllerInternalAccess(
    controller,
  ).readEraserPreciseSegmentCheckCount();
}
