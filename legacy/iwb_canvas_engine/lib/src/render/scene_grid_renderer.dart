import 'dart:ui';

import 'package:flutter/foundation.dart';

import '../core/grid_safety_limits.dart';
import '../core/numeric_clamp.dart';
import '../contract/snapshot.dart';

/// Stateless owner of grid draw semantics for painter and static cache.
///
/// Density bucketing is deterministic and depends only on current inputs.
/// The stride threshold uses an upper bound of visible lines per axis that is
/// independent from camera phase, which prevents offset jitter from flipping
/// between adjacent stride buckets near `kMaxGridLinesPerAxis`.
class SceneGridRenderer {
  const SceneGridRenderer();

  SceneGridRenderPlan? plan(SceneGridRenderRequest request) {
    if (!_isDrawable(
      request.grid,
      size: request.size,
      cameraOffset: request.cameraOffset,
    )) {
      return null;
    }

    final cellSize = request.grid.cellSize;
    return SceneGridRenderPlan._(
      size: request.size,
      cellSize: cellSize,
      color: request.grid.color,
      strokeWidth: clampNonNegativeFinite(request.gridStrokeWidth),
      xAxis: _axisPlan(request.size.width, -request.cameraOffset.dx, cellSize),
      yAxis: _axisPlan(request.size.height, -request.cameraOffset.dy, cellSize),
    );
  }

  void draw(Canvas canvas, SceneGridRenderRequest request) {
    final plan = this.plan(request);
    if (plan == null) {
      return;
    }
    drawPlan(canvas, plan);
  }

  void drawPlan(Canvas canvas, SceneGridRenderPlan plan) {
    final paint = Paint()
      ..color = plan.color
      ..strokeWidth = plan.strokeWidth;
    _drawAxisLines(
      canvas,
      plan.xAxis,
      frame: (
        axisExtent: plan.size.width,
        lineLength: plan.size.height,
        vertical: true,
      ),
      paint: paint,
    );
    _drawAxisLines(
      canvas,
      plan.yAxis,
      frame: (
        axisExtent: plan.size.height,
        lineLength: plan.size.width,
        vertical: false,
      ),
      paint: paint,
    );
  }

  SceneGridRenderWorkStats debugWorkForPlan(SceneGridRenderPlan plan) {
    return SceneGridRenderWorkStats(
      xAxis: _measureAxisWork(plan.xAxis),
      yAxis: _measureAxisWork(plan.yAxis),
    );
  }

  Offset cameraShiftFor(Offset cameraOffset, double cellSize) {
    if (!_isFiniteOffset(cameraOffset)) {
      return Offset.zero;
    }
    if (!cellSize.isFinite || cellSize <= 0) {
      return Offset.zero;
    }
    return Offset(
      _gridStart(-cameraOffset.dx, cellSize),
      _gridStart(-cameraOffset.dy, cellSize),
    );
  }

  SceneGridAxisPlan _axisPlan(double extent, double cameraShift, double cell) {
    final visibleLineCount = _visibleLineCountUpperBound(extent, cell);
    final stride = _strideForVisibleLineCountUpperBound(visibleLineCount);
    final firstPosition = _gridStart(cameraShift, cell);
    final positionStep = cell * stride;
    return SceneGridAxisPlan._(
      firstPosition: firstPosition,
      stride: stride,
      positionStep: positionStep,
      iterationCount: _iterationCount(
        firstPosition: firstPosition,
        axisExtent: extent,
        positionStep: positionStep,
      ),
    );
  }

  void _drawAxisLines(
    Canvas canvas,
    SceneGridAxisPlan axis, {
    required _SceneGridAxisDrawFrame frame,
    required Paint paint,
  }) {
    _visitAxisLines(
      axis,
      onDrawLine: (position) {
        final start = frame.vertical
            ? Offset(position, 0)
            : Offset(0, position);
        final end = frame.vertical
            ? Offset(position, frame.lineLength)
            : Offset(frame.lineLength, position);
        canvas.drawLine(start, end, paint);
      },
    );
  }

  SceneGridAxisWorkStats _measureAxisWork(SceneGridAxisPlan axis) {
    return SceneGridAxisWorkStats(
      loopIterations: axis.iterationCount,
      drawnLineCount: axis.iterationCount,
    );
  }

  void _visitAxisLines(
    SceneGridAxisPlan axis, {
    required void Function(double position) onDrawLine,
  }) {
    for (
      var position = axis.firstPosition, iteration = 0;
      iteration < axis.iterationCount;
      position += axis.positionStep, iteration++
    ) {
      onDrawLine(position);
    }
  }
}

@immutable
class SceneGridRenderRequest {
  const SceneGridRenderRequest({
    required this.grid,
    required this.size,
    required this.cameraOffset,
    required this.gridStrokeWidth,
  });

  final GridSnapshot grid;
  final Size size;
  final Offset cameraOffset;
  final double gridStrokeWidth;
}

typedef _SceneGridAxisDrawFrame = ({
  double axisExtent,
  double lineLength,
  bool vertical,
});

@immutable
class SceneGridRenderPlan {
  const SceneGridRenderPlan._({
    required this.size,
    required this.cellSize,
    required this.color,
    required this.strokeWidth,
    required this.xAxis,
    required this.yAxis,
  });

  final Size size;
  final double cellSize;
  final Color color;
  final double strokeWidth;
  final SceneGridAxisPlan xAxis;
  final SceneGridAxisPlan yAxis;
}

@immutable
class SceneGridAxisPlan {
  const SceneGridAxisPlan._({
    required this.firstPosition,
    required this.stride,
    required this.positionStep,
    required this.iterationCount,
  });

  final double firstPosition;
  final int stride;
  final double positionStep;
  final int iterationCount;

  int get maxVisibleLines => iterationCount;
}

@immutable
class SceneGridRenderWorkStats {
  const SceneGridRenderWorkStats({required this.xAxis, required this.yAxis});

  final SceneGridAxisWorkStats xAxis;
  final SceneGridAxisWorkStats yAxis;

  int get loopIterations => xAxis.loopIterations + yAxis.loopIterations;
  int get drawnLineCount => xAxis.drawnLineCount + yAxis.drawnLineCount;

  Map<String, Object?> toJson() => <String, Object?>{
    'loopIterations': loopIterations,
    'drawnLineCount': drawnLineCount,
    'xAxis': xAxis.toJson(),
    'yAxis': yAxis.toJson(),
  };
}

@immutable
class SceneGridAxisWorkStats {
  const SceneGridAxisWorkStats({
    required this.loopIterations,
    required this.drawnLineCount,
  });

  final int loopIterations;
  final int drawnLineCount;

  Map<String, int> toJson() => <String, int>{
    'loopIterations': loopIterations,
    'drawnLineCount': drawnLineCount,
  };
}

bool _isDrawable(
  GridSnapshot grid, {
  required Size size,
  required Offset cameraOffset,
}) {
  if (!grid.isEnabled) {
    return false;
  }
  if (!size.width.isFinite || !size.height.isFinite) {
    return false;
  }
  if (size.width <= 0 || size.height <= 0) {
    return false;
  }
  if (!_isFiniteOffset(cameraOffset)) {
    return false;
  }
  if (!grid.cellSize.isFinite || grid.cellSize < kMinGridCellSize) {
    return false;
  }
  return true;
}

int _visibleLineCountUpperBound(double extent, double cell) {
  if (!extent.isFinite || !cell.isFinite || extent <= 0 || cell <= 0) {
    return 0;
  }
  return (extent / cell).ceil().clamp(0, 1 << 30) + 1;
}

int _strideForVisibleLineCountUpperBound(int visibleLineCount) {
  if (visibleLineCount <= kMaxGridLinesPerAxis) {
    return 1;
  }
  return (visibleLineCount / kMaxGridLinesPerAxis).ceil().clamp(1, 1 << 30);
}

int _iterationCount({
  required double firstPosition,
  required double axisExtent,
  required double positionStep,
}) {
  if (!firstPosition.isFinite ||
      !axisExtent.isFinite ||
      !positionStep.isFinite ||
      positionStep <= 0 ||
      firstPosition > axisExtent) {
    return 0;
  }
  return (((axisExtent - firstPosition) / positionStep).floor() + 1).clamp(
    0,
    1 << 30,
  );
}

double _gridStart(double offset, double cell) {
  if (!offset.isFinite || !cell.isFinite || cell <= 0) {
    return 0;
  }
  final rem = offset % cell;
  return rem > 0 ? rem - cell : rem;
}

bool _isFiniteOffset(Offset offset) {
  return offset.dx.isFinite && offset.dy.isFinite;
}
