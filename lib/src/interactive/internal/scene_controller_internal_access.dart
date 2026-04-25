import 'dart:ui';

import '../../contract/snapshot.dart';
import '../scene_controller.dart';
import '../scene_controller_interaction.dart';
import 'interactive_geometry.dart';
import 'interactive_move_preview_read.dart';
import 'scene_controller_interaction_runtime.dart';

class _SceneControllerInternalAccess {
  const _SceneControllerInternalAccess({
    required this.readEpoch,
    required this.movePreviewRead,
    required this.setBeforePointerDispatchHook,
    required this.runMoveCommitDeltaResolverForTest,
    required this.readInteractionRuntimeForTest,
    required this.readCommittedSnapshotForTest,
    required this.readActiveEraserPointsLength,
    required this.readEraserSpatialQueryCount,
    required this.readEraserPreciseSegmentCheckCount,
  });

  final int Function() readEpoch;
  final InteractiveMovePreviewRead movePreviewRead;
  final void Function(VoidCallback? hook) setBeforePointerDispatchHook;
  final Offset Function(MoveCommitDeltaRequest request)
  runMoveCommitDeltaResolverForTest;
  final SceneControllerInteractionRuntime Function()
  readInteractionRuntimeForTest;
  final SceneSnapshot Function() readCommittedSnapshotForTest;
  final int Function() readActiveEraserPointsLength;
  final int Function() readEraserSpatialQueryCount;
  final int Function() readEraserPreciseSegmentCheckCount;
}

final Expando<_SceneControllerInternalAccess> _sceneControllerInternalAccess =
    Expando<_SceneControllerInternalAccess>('SceneControllerInternalAccess');

final class SceneControllerInternalAccessRegistration {
  const SceneControllerInternalAccessRegistration({
    required this.readEpoch,
    required this.movePreviewRead,
    required this.setBeforePointerDispatchHook,
    required this.runMoveCommitDeltaResolverForTest,
    required this.readInteractionRuntimeForTest,
    required this.readCommittedSnapshotForTest,
    required this.readActiveEraserPointsLength,
    required this.readEraserSpatialQueryCount,
    required this.readEraserPreciseSegmentCheckCount,
  });

  final int Function() readEpoch;
  final InteractiveMovePreviewRead movePreviewRead;
  final void Function(VoidCallback? hook) setBeforePointerDispatchHook;
  final Offset Function(MoveCommitDeltaRequest request)
  runMoveCommitDeltaResolverForTest;
  final SceneControllerInteractionRuntime Function()
  readInteractionRuntimeForTest;
  final SceneSnapshot Function() readCommittedSnapshotForTest;
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
    movePreviewRead: registration.movePreviewRead,
    setBeforePointerDispatchHook: registration.setBeforePointerDispatchHook,
    runMoveCommitDeltaResolverForTest:
        registration.runMoveCommitDeltaResolverForTest,
    readInteractionRuntimeForTest: registration.readInteractionRuntimeForTest,
    readCommittedSnapshotForTest: registration.readCommittedSnapshotForTest,
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
  ).movePreviewRead.previewDeltaForNode(nodeId);
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

SceneControllerInteractionRuntime
sceneControllerInternalInteractionRuntimeForTest(SceneController controller) {
  return _requireSceneControllerInternalAccess(
    controller,
  ).readInteractionRuntimeForTest();
}

SceneSnapshot sceneControllerInternalCommittedSnapshotForTest(
  SceneController controller,
) {
  return _requireSceneControllerInternalAccess(
    controller,
  ).readCommittedSnapshotForTest();
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
