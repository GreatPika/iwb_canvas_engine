import 'dart:ui';

import '../../core/input_sampling.dart';
import '../../core/nodes.dart';
import '../../core/scene_limits.dart';
import '../../contract/node_spec.dart';
import '../scene_writer.dart';

typedef DrawCommandRunner = T Function<T>(T Function(SceneWriter writer) fn);

class DrawCommands {
  DrawCommands(this._writeRunner);

  final DrawCommandRunner _writeRunner;

  List<Offset> _committedStrokePoints(
    List<Offset> points, {
    required int limit,
  }) {
    return resamplePointsToLimit(points, limit: limit);
  }

  NodeId writeDrawStroke({
    required List<Offset> points,
    required double thickness,
    required Color color,
    double opacity = 1,
  }) {
    return _writeRunner((writer) {
      final committedPoints = _committedStrokePoints(
        points,
        limit: kMaxStrokePointsPerNode,
      );
      final nodeId = writer.writeNodeInsert(
        StrokeNodeSpec(
          points: committedPoints,
          thickness: thickness,
          color: color,
          opacity: opacity,
        ),
      );
      writer.writeOwnedSignalEnqueue(
        type: 'draw.stroke',
        nodeIds: <NodeId>[nodeId],
      );
      return nodeId;
    });
  }

  NodeId writeDrawLine({
    required ({Offset start, Offset end}) segment,
    required double thickness,
    required Color color,
    double opacity = 1,
  }) {
    return _writeRunner((writer) {
      final nodeId = writer.writeNodeInsert(
        LineNodeSpec(
          start: segment.start,
          end: segment.end,
          thickness: thickness,
          color: color,
          opacity: opacity,
        ),
      );
      writer.writeOwnedSignalEnqueue(
        type: 'draw.line',
        nodeIds: <NodeId>[nodeId],
      );
      return nodeId;
    });
  }

  int writeEraseNodes(Iterable<NodeId> nodeIds) {
    return _writeRunner((writer) {
      final removedIds = writer.writeDeleteNodesResult(nodeIds);
      if (removedIds.isNotEmpty) {
        writer.writeOwnedSignalEnqueue(type: 'draw.erase', nodeIds: removedIds);
      }
      return removedIds.length;
    });
  }
}
