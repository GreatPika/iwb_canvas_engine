import 'dart:ui';

import '../../core/input_sampling.dart';
import '../../core/nodes.dart';
import '../../core/scene_limits.dart';
import '../../contract/node_spec.dart';
import '../../contract/transform2d.dart';
import '../scene_writer_command_results.dart';
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

  NodeId _writeDrawNode(NodeSpec spec, {required String signalType}) {
    return _writeRunner((writer) {
      final nodeId = writer.writeNodeInsert(spec);
      sceneWriterWriteOwnedSignalExactEnqueue(
        writer,
        type: signalType,
        nodeIds: <NodeId>[nodeId],
      );
      return nodeId;
    });
  }

  NodeId writeDrawStroke({
    required List<Offset> points,
    required double thickness,
    required Color color,
    double opacity = 1,
  }) {
    final committedPoints = _committedStrokePoints(
      points,
      limit: kMaxStrokePointsPerNode,
    );
    return _writeDrawNode(
      StrokeNodeSpec(
        points: committedPoints,
        thickness: thickness,
        color: color,
        opacity: opacity,
      ),
      signalType: 'draw.stroke',
    );
  }

  NodeId writeDrawLine({
    required ({Offset start, Offset end}) segment,
    required double thickness,
    required Color color,
    double opacity = 1,
  }) {
    return _writeDrawNode(
      LineNodeSpec(
        start: segment.start,
        end: segment.end,
        thickness: thickness,
        color: color,
        opacity: opacity,
      ),
      signalType: 'draw.line',
    );
  }

  NodeId writeDrawLineFromWorldSegment({
    required Offset start,
    required Offset end,
    required double thickness,
    required Color color,
    double opacity = 1,
  }) {
    final bounds = Rect.fromPoints(start, end);
    final center = bounds.center;
    return _writeDrawNode(
      LineNodeSpec(
        start: start - center,
        end: end - center,
        thickness: thickness,
        color: color,
        opacity: opacity,
        transform: Transform2D.translation(center),
      ),
      signalType: 'draw.line',
    );
  }

  int writeEraseNodes(Iterable<NodeId> nodeIds) {
    return _writeRunner((writer) {
      final removedIds = sceneWriterWriteDeleteNodesResult(writer, nodeIds);
      if (removedIds.isNotEmpty) {
        sceneWriterWriteOwnedSignalExactEnqueue(
          writer,
          type: 'draw.erase',
          nodeIds: removedIds,
        );
      }
      return removedIds.length;
    });
  }
}
