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
        cellSize: plan.cellSize,
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
        cellSize: plan.cellSize,
        axisExtent: plan.size.height,
        lineLength: plan.size.width,
        vertical: false,
      ),
      paint: paint,
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
    final lineUpperBound = _visibleLineUpperBound(extent, cell);
    return SceneGridAxisPlan._(
      start: _gridStart(cameraShift, cell),
      stride: _strideForVisibleLineUpperBound(lineUpperBound),
      lineUpperBound: lineUpperBound,
    );
  }

  void _drawAxisLines(
    Canvas canvas,
    SceneGridAxisPlan axis, {
    required _SceneGridAxisDrawFrame frame,
    required Paint paint,
  }) {
    for (
      var position = axis.start, index = 0;
      position <= frame.axisExtent;
      position += frame.cellSize, index++
    ) {
      if (index % axis.stride != 0) {
        continue;
      }
      final start = frame.vertical ? Offset(position, 0) : Offset(0, position);
      final end = frame.vertical
          ? Offset(position, frame.lineLength)
          : Offset(frame.lineLength, position);
      canvas.drawLine(start, end, paint);
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
  double cellSize,
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
    required this.start,
    required this.stride,
    required this.lineUpperBound,
  });

  final double start;
  final int stride;
  final int lineUpperBound;

  int get maxVisibleLines => (lineUpperBound / stride).ceil();
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

int _visibleLineUpperBound(double extent, double cell) {
  if (!extent.isFinite || !cell.isFinite || extent <= 0 || cell <= 0) {
    return 0;
  }
  return (extent / cell).ceil().clamp(0, 1 << 30) + 1;
}

int _strideForVisibleLineUpperBound(int lineUpperBound) {
  if (lineUpperBound <= kMaxGridLinesPerAxis) {
    return 1;
  }
  return (lineUpperBound / kMaxGridLinesPerAxis).ceil().clamp(1, 1 << 30);
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
