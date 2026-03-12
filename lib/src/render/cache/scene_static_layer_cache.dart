import 'dart:ui';

import 'package:flutter/foundation.dart';

import '../../core/numeric_clamp.dart';
import '../../contract/snapshot.dart';
import '../scene_grid_renderer.dart';

const _gridRenderer = SceneGridRenderer();

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

  /// Owner-level invalidation for controller epoch/document boundaries.
  ///
  /// The recorded picture key stays local to grid inputs and does not include
  /// document lifecycle fields such as `epoch`.
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
    final plan = _gridRenderer.plan(
      background.grid,
      size: size,
      cameraOffset: Offset.zero,
      gridStrokeWidth: gridStrokeWidth,
    );
    if (plan == null) {
      _disposeGridPictureIfNeeded();
      _key = null;
      return;
    }

    final key = _StaticLayerKey(
      size: size,
      gridEnabled: true,
      gridCellSize: plan.cellSize,
      gridColor: plan.color,
      gridStrokeWidth: plan.strokeWidth,
    );

    if (_gridPicture == null || _key != key) {
      _disposeGridPictureIfNeeded();
      _key = key;
      _gridPicture = _recordGridPicture(plan);
      _debugBuildCount += 1;
    }

    final picture = _gridPicture;
    if (picture == null) {
      return;
    }
    final shift = _gridRenderer.cameraShiftFor(safeOffset, key.gridCellSize);
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.translate(shift.dx, shift.dy);
    canvas.drawPicture(picture);
    canvas.restore();
  }

  Picture _recordGridPicture(SceneGridRenderPlan plan) {
    final recorder = PictureRecorder();
    final canvas = Canvas(recorder);
    _gridRenderer.drawPlan(canvas, plan);
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
