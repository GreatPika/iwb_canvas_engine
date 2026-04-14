import 'dart:ui';

import '../../core/scene_limits.dart';
import '../../core/scene_spatial_index.dart';
import '../../contract/snapshot.dart';
import 'interactive_draw_eraser_exact_hit.dart';
import 'interactive_draw_eraser_targets.dart';
import 'interactive_draw_path_buffer.dart';

class InteractiveDrawEraserEngineCallbacks {
  const InteractiveDrawEraserEngineCallbacks({
    required this.onOverlayStateChanged,
    required this.querySpatialCandidates,
    required this.resolveSpatialCandidateSnapshot,
    required this.commitEraseNodes,
  });

  final VoidCallback onOverlayStateChanged;
  final List<SceneSpatialCandidate> Function(Rect bounds)
  querySpatialCandidates;
  final NodeSnapshot? Function(SceneSpatialCandidate candidate)
  resolveSpatialCandidateSnapshot;
  final int Function(Iterable<NodeId> ids) commitEraseNodes;
}

class InteractiveDrawEraserEngine {
  InteractiveDrawEraserEngine({required this.callbacks});

  final InteractiveDrawEraserEngineCallbacks callbacks;
  final InteractiveDrawPathBuffer _pathBuffer = InteractiveDrawPathBuffer(
    softLimit: kInteractiveEraserPointsSoftLimit,
    trimTo: kInteractiveEraserPointsTrimTo,
  );
  late final InteractiveDrawEraserTargets _targets =
      InteractiveDrawEraserTargets(
        callbacks: InteractiveDrawEraserTargetsCallbacks(
          querySpatialCandidates: callbacks.querySpatialCandidates,
          resolveSpatialCandidateSnapshot:
              callbacks.resolveSpatialCandidateSnapshot,
          onSpatialQuery: _incrementSpatialQueryCount,
        ),
      );
  late final InteractiveDrawEraserExactHit _exactHit =
      InteractiveDrawEraserExactHit(
        callbacks: InteractiveDrawEraserExactHitCallbacks(
          onPreciseSegmentCheck: _incrementPreciseSegmentChecks,
        ),
      );

  int _debugEraserSpatialQueryCount = 0;
  int _debugEraserPreciseSegmentChecks = 0;

  int get activeEraserPointsLength => _pathBuffer.length;
  int get debugEraserSpatialQueryCount => _debugEraserSpatialQueryCount;
  int get debugEraserPreciseSegmentChecks => _debugEraserPreciseSegmentChecks;

  void resetGestureState() {
    _pathBuffer.clear();
  }

  void handleDown(Offset scenePoint) {
    _pathBuffer.start(scenePoint);
  }

  void handleMove(Offset scenePoint) {
    if (!_pathBuffer.appendMovePoint(scenePoint)) return;
    callbacks.onOverlayStateChanged();
  }

  List<NodeId> commitOnUp(
    Offset scenePoint, {
    required double eraserThickness,
  }) {
    if (_pathBuffer.isEmpty) return const <NodeId>[];

    _debugEraserSpatialQueryCount = 0;
    _debugEraserPreciseSegmentChecks = 0;

    _pathBuffer.appendTerminalPoint(scenePoint, enforceSoftLimit: true);

    final deletedIds = _eraseAnnotations(
      _pathBuffer.points,
      eraserThickness: eraserThickness,
    );
    _pathBuffer.clear();
    return deletedIds;
  }

  List<NodeId> _eraseAnnotations(
    List<Offset> eraserPoints, {
    required double eraserThickness,
  }) {
    final candidates = _targets.queryDeletableTargets(
      eraserPoints,
      eraserThickness: eraserThickness,
    );
    final ids = <NodeId>[];
    for (final candidate in candidates) {
      final node = candidate.node;
      if (!_exactHit.hitsNode(
        eraserPoints,
        node,
        eraserThickness: eraserThickness,
      )) {
        continue;
      }
      ids.add(node.id);
    }

    if (ids.isEmpty) return const <NodeId>[];

    final removedCount = callbacks.commitEraseNodes(ids);
    if (removedCount <= 0) return const <NodeId>[];

    return ids;
  }

  void _incrementSpatialQueryCount() {
    _debugEraserSpatialQueryCount = _debugEraserSpatialQueryCount + 1;
  }

  void _incrementPreciseSegmentChecks() {
    _debugEraserPreciseSegmentChecks = _debugEraserPreciseSegmentChecks + 1;
  }
}
