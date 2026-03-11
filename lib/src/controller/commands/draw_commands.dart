import 'dart:ui';

import '../../core/nodes.dart';
import '../../core/scene_limits.dart';
import '../../contract/node_spec.dart';
import '../../contract/scene_write_txn.dart';
import '../scene_writer.dart';

class DrawCommands {
  DrawCommands(this._writeRunner);

  final T Function<T>(T Function(SceneWriteTxn writer) fn) _writeRunner;

  SceneWriter _sceneWriter(SceneWriteTxn writer) {
    return writer as SceneWriter;
  }

  List<Offset> _resampleStrokePointsToLimit(
    List<Offset> points, {
    required int limit,
  }) {
    if (points.length <= limit) {
      return points;
    }
    final sourceCount = points.length;
    return List<Offset>.generate(limit, (i) {
      final sourceIndex = (i * (sourceCount - 1)) ~/ (limit - 1);
      return points[sourceIndex];
    }, growable: false);
  }

  NodeId writeDrawStroke({
    required List<Offset> points,
    required double thickness,
    required Color color,
    double opacity = 1,
  }) {
    return _writeRunner((writer) {
      final committedPoints = _resampleStrokePointsToLimit(
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
      _sceneWriter(
        writer,
      ).writeOwnedSignalEnqueue(type: 'draw.stroke', nodeIds: <NodeId>[nodeId]);
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
      _sceneWriter(
        writer,
      ).writeOwnedSignalEnqueue(type: 'draw.line', nodeIds: <NodeId>[nodeId]);
      return nodeId;
    });
  }

  int writeEraseNodes(Iterable<NodeId> nodeIds) {
    return _writeRunner((writer) {
      var removedCount = 0;
      final removedIds = <NodeId>[];
      for (final nodeId in nodeIds) {
        final removed = writer.writeNodeErase(nodeId);
        if (!removed) continue;
        removedCount = removedCount + 1;
        removedIds.add(nodeId);
      }

      if (removedCount > 0) {
        removedIds.sort((a, b) => a.compareTo(b));
        _sceneWriter(
          writer,
        ).writeOwnedSignalEnqueue(type: 'draw.erase', nodeIds: removedIds);
      }
      return removedCount;
    });
  }
}
