import 'dart:ui';

import '../../contract/canvas_pointer_input.dart';
import '../../contract/snapshot.dart';
import '../../core/pointer_input.dart';
import '../scene_controller.dart';
import 'scene_controller_interaction_access.dart';
import 'interactive_geometry.dart';

abstract interface class SceneControllerPointerSemanticsBridge {
  int? get pendingTapFlushTimestampMs;

  void handleControllerChanged({required bool routerHasLiveRawPointers});

  void handleRoutedSample(
    PointerSample sample, {
    required bool shouldTrackSignals,
  });

  void handleInvalidTerminalSample({
    required CanvasPointerInput input,
    required int pointerId,
    required int referenceTimestampMs,
  });

  void handleRawPointerRelease({required bool isIdleAfterRelease});

  void dispose();
}

class _SceneControllerInternalAccess {
  const _SceneControllerInternalAccess({
    required this.readEpoch,
    required this.previewDeltaForNode,
    required this.setBeforePointerDispatchHook,
    required this.createPointerSemanticsBridge,
    required this.runMoveCommitDeltaResolverForTest,
    required this.readInteractionAccessForTest,
    required this.readActiveEraserPointsLength,
    required this.readEraserSpatialQueryCount,
    required this.readEraserPreciseSegmentCheckCount,
  });

  final int Function() readEpoch;
  final Offset Function(NodeId nodeId) previewDeltaForNode;
  final void Function(VoidCallback? hook) setBeforePointerDispatchHook;
  final SceneControllerPointerSemanticsBridge Function({
    required bool Function() isMounted,
  })
  createPointerSemanticsBridge;
  final Offset Function({
    required SceneSnapshot snapshot,
    required List<NodeSnapshot> movedNodes,
    required Offset proposedDelta,
  })
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
    required this.createPointerSemanticsBridge,
    required this.runMoveCommitDeltaResolverForTest,
    required this.readInteractionAccessForTest,
    required this.readActiveEraserPointsLength,
    required this.readEraserSpatialQueryCount,
    required this.readEraserPreciseSegmentCheckCount,
  });

  final int Function() readEpoch;
  final Offset Function(NodeId nodeId) previewDeltaForNode;
  final void Function(VoidCallback? hook) setBeforePointerDispatchHook;
  final SceneControllerPointerSemanticsBridge Function({
    required bool Function() isMounted,
  })
  createPointerSemanticsBridge;
  final Offset Function({
    required SceneSnapshot snapshot,
    required List<NodeSnapshot> movedNodes,
    required Offset proposedDelta,
  })
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
    createPointerSemanticsBridge: registration.createPointerSemanticsBridge,
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

SceneControllerPointerSemanticsBridge
sceneControllerInternalCreatePointerSemanticsBridge(
  SceneController controller, {
  required bool Function() isMounted,
}) {
  return _requireSceneControllerInternalAccess(
    controller,
  ).createPointerSemanticsBridge(isMounted: isMounted);
}

Offset sceneControllerInternalRunMoveCommitDeltaResolverForTest(
  SceneController controller, {
  required SceneSnapshot snapshot,
  required List<NodeSnapshot> movedNodes,
  required Offset proposedDelta,
}) {
  return _requireSceneControllerInternalAccess(
    controller,
  ).runMoveCommitDeltaResolverForTest(
    snapshot: snapshot,
    movedNodes: movedNodes,
    proposedDelta: proposedDelta,
  );
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
