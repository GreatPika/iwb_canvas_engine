import 'dart:ui';

import '../../../core/nodes.dart';
import '../../../controller/scene_writer.dart';
import '../../../public/node_spec.dart';

class V2DrawSlice {
  V2DrawSlice(this._writeRunner);

  final T Function<T>(T Function(SceneWriter writer) fn) _writeRunner;

  String writeDrawStroke({
    required List<Offset> points,
    required double thickness,
    required Color color,
    double opacity = 1,
  }) {
    return _writeRunner((writer) {
      final nodeId = writer.writeNodeInsert(
        StrokeNodeSpec(
          points: points,
          thickness: thickness,
          color: color,
          opacity: opacity,
        ),
      );
      writer.writeSignalEnqueue(type: 'draw.stroke', nodeIds: <NodeId>[nodeId]);
      return nodeId;
    });
  }

  String writeDrawLine({
    required Offset start,
    required Offset end,
    required double thickness,
    required Color color,
    double opacity = 1,
  }) {
    return _writeRunner((writer) {
      final nodeId = writer.writeNodeInsert(
        LineNodeSpec(
          start: start,
          end: end,
          thickness: thickness,
          color: color,
          opacity: opacity,
        ),
      );
      writer.writeSignalEnqueue(type: 'draw.line', nodeIds: <NodeId>[nodeId]);
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
        writer.writeSignalEnqueue(type: 'draw.erase', nodeIds: removedIds);
      }
      return removedCount;
    });
  }
}
