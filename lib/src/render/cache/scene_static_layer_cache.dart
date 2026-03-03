import 'dart:ui';

import 'package:flutter/foundation.dart';

import '../../core/grid_safety_limits.dart';
import '../../core/numeric_clamp.dart';
import '../../public/snapshot.dart';

class SceneStaticLayerCache {
  _StaticLayerKey? _key;
  Picture? _gridPicture;

  int _debugBuildCount = 0;
  int _debugDisposeCount = 0;

  @visibleForTesting
  int get debugBuildCount => _debugBuildCount;
  @visibleForTesting
  int get debugDisposeCount => _debugDisposeCount;
  @visibleForTesting
  int? get debugKeyHashCode => _key?.hashCode;

  void clear() {
    _disposeGridPictureIfNeeded();
    _key = null;
  }

  void dispose() => clear();

  void draw(
    Canvas canvas,
    Size size, {
    required BackgroundSnapshot background,
    required Offset cameraOffset,
    required double gridStrokeWidth,
  }) {
    _drawBackground(canvas, size, background.color);

    final safeOffset = sanitizeFiniteOffset(cameraOffset);
    final safeGridStrokeWidth = clampNonNegativeFinite(gridStrokeWidth);
    final grid = background.grid;
    final enabled = _isGridDrawable(
      grid,
      size: size,
      cameraOffset: Offset.zero,
    );
    if (!enabled) {
      _disposeGridPictureIfNeeded();
      _key = null;
      return;
    }

    final key = _StaticLayerKey(
      size: size,
      gridEnabled: true,
      gridCellSize: grid.cellSize,
      gridColor: grid.color,
      gridStrokeWidth: safeGridStrokeWidth,
    );

    if (_gridPicture == null || _key != key) {
      _disposeGridPictureIfNeeded();
      _key = key;
      _gridPicture = _recordGridPicture(size, grid, safeGridStrokeWidth);
      _debugBuildCount += 1;
    }

    final picture = _gridPicture;
    if (picture == null) {
      return;
    }
    final shift = _gridShiftForCameraOffset(safeOffset, key.gridCellSize);
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.translate(shift.dx, shift.dy);
    canvas.drawPicture(picture);
    canvas.restore();
  }

  Picture _recordGridPicture(
    Size size,
    GridSnapshot grid,
    double gridStrokeWidth,
  ) {
    final recorder = PictureRecorder();
    final canvas = Canvas(recorder);
    _drawGrid(canvas, size, grid, Offset.zero, gridStrokeWidth);
    return recorder.endRecording();
  }

  void _disposeGridPictureIfNeeded() {
    final picture = _gridPicture;
    if (picture == null) {
      return;
    }
    _gridPicture = null;
    picture.dispose();
    _debugDisposeCount += 1;
  }
}

class _StaticLayerKey {
  const _StaticLayerKey({
    required this.size,
    required this.gridEnabled,
    required this.gridCellSize,
    required this.gridColor,
    required this.gridStrokeWidth,
  });

  final Size size;
  final bool gridEnabled;
  final double gridCellSize;
  final Color gridColor;
  final double gridStrokeWidth;

  @override
  bool operator ==(Object other) {
    return other is _StaticLayerKey &&
        other.size == size &&
        other.gridEnabled == gridEnabled &&
        other.gridCellSize == gridCellSize &&
        other.gridColor == gridColor &&
        other.gridStrokeWidth == gridStrokeWidth;
  }

  @override
  int get hashCode =>
      Object.hash(size, gridEnabled, gridCellSize, gridColor, gridStrokeWidth);
}

void _drawBackground(Canvas canvas, Size size, Color color) {
  canvas.drawRect(Offset.zero & size, Paint()..color = color);
}

void _drawGrid(
  Canvas canvas,
  Size size,
  GridSnapshot grid,
  Offset cameraOffset,
  double gridStrokeWidth,
) {
  if (!_isGridDrawable(grid, size: size, cameraOffset: cameraOffset)) {
    return;
  }

  final cell = grid.cellSize;
  final paint = Paint()
    ..color = grid.color
    ..strokeWidth = clampNonNegativeFinite(gridStrokeWidth);

  final startX = _gridStart(-cameraOffset.dx, cell);
  final startY = _gridStart(-cameraOffset.dy, cell);

  final strideX = _gridStrideForLineCount(
    _gridLineCount(startX, size.width, cell),
  );
  final strideY = _gridStrideForLineCount(
    _gridLineCount(startY, size.height, cell),
  );

  for (var x = startX, index = 0; x <= size.width; x += cell, index++) {
    if (index % strideX != 0) {
      continue;
    }
    canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
  }

  for (var y = startY, index = 0; y <= size.height; y += cell, index++) {
    if (index % strideY != 0) {
      continue;
    }
    canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
  }
}

bool _isGridDrawable(
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

int _gridLineCount(double start, double extent, double cell) {
  if (!start.isFinite || !extent.isFinite || !cell.isFinite || cell <= 0) {
    return 0;
  }
  return ((extent - start) / cell).ceil().clamp(0, 1 << 30) + 1;
}

int _gridStrideForLineCount(int lineCount) {
  if (lineCount <= kMaxGridLinesPerAxis) {
    return 1;
  }
  return (lineCount / kMaxGridLinesPerAxis).ceil().clamp(1, 1 << 30);
}

double _gridStart(double offset, double cell) {
  if (!offset.isFinite || !cell.isFinite || cell <= 0) {
    return 0;
  }
  final rem = offset % cell;
  return rem > 0 ? rem - cell : rem;
}

Offset _gridShiftForCameraOffset(Offset cameraOffset, double cellSize) {
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

bool _isFiniteOffset(Offset offset) {
  return offset.dx.isFinite && offset.dy.isFinite;
}
