import 'dart:ui';

import 'package:flutter/foundation.dart';

import '../contracts/public/canvas_document.dart';
import 'captured_frame.dart';

@immutable
final class StaticBackgroundKey {
  const StaticBackgroundKey({
    required this.backgroundRevision,
    required this.gridRevision,
    required this.gridStrokeWidth,
    required this.viewCameraBucket,
    required this.viewportRect,
    required this.devicePixelRatio,
  });

  final int backgroundRevision;
  final int gridRevision;
  final double gridStrokeWidth;
  final int viewCameraBucket;
  final Rect viewportRect;
  final double devicePixelRatio;

  @override
  bool operator ==(Object other) {
    return other is StaticBackgroundKey &&
        other.backgroundRevision == backgroundRevision &&
        other.gridRevision == gridRevision &&
        other.gridStrokeWidth == gridStrokeWidth &&
        other.viewCameraBucket == viewCameraBucket &&
        other.viewportRect == viewportRect &&
        other.devicePixelRatio == devicePixelRatio;
  }

  @override
  int get hashCode {
    return Object.hash(
      backgroundRevision,
      gridRevision,
      gridStrokeWidth,
      viewCameraBucket,
      viewportRect,
      devicePixelRatio,
    );
  }
}

final class StaticBackgroundPicture {
  StaticBackgroundPicture({required this.debugLabel, required this.picture});

  final String debugLabel;
  final Picture picture;
  bool isDisposed = false;

  void dispose() {
    picture.dispose();
    isDisposed = true;
  }
}

final class StaticBackgroundPrimitive {
  const StaticBackgroundPrimitive({
    required this.viewportRect,
    required this.backgroundColor,
    required this.gridEnabled,
    required this.gridCellSize,
    required this.gridColor,
    required this.gridStrokeWidth,
  });

  final Rect viewportRect;
  final Color backgroundColor;
  final bool gridEnabled;
  final double gridCellSize;
  final Color gridColor;
  final double gridStrokeWidth;
}

final class StaticBackgroundPlan {
  const StaticBackgroundPlan({
    required this.key,
    required this.picture,
    required this.primitive,
  });

  final StaticBackgroundKey key;
  final StaticBackgroundPicture picture;
  final StaticBackgroundPrimitive primitive;
}

final class StaticBackgroundCacheProbe {
  const StaticBackgroundCacheProbe({
    required this.pictureCount,
    required this.rebuildCount,
  });

  final int pictureCount;
  final int rebuildCount;
}

final class StaticBackgroundCache {
  StaticBackgroundPlan? _current;
  int _rebuildCount = 0;

  StaticBackgroundPlan readOrBuild(
    StaticBackgroundKey key, {
    required CanvasBackground background,
    required Rect primitiveViewportRect,
  }) {
    final current = _current;
    if (current != null && current.key == key) {
      return current;
    }
    current?.picture.dispose();
    final plan = StaticBackgroundPlan(
      key: key,
      picture: StaticBackgroundPicture(
        debugLabel: 'static-background',
        picture: _recordStaticBackgroundPicture(
          viewport: primitiveViewportRect,
          background: background,
          gridStrokeWidth: key.gridStrokeWidth,
        ),
      ),
      primitive: StaticBackgroundPrimitive(
        viewportRect: primitiveViewportRect,
        backgroundColor: background.color,
        gridEnabled: background.grid.enabled,
        gridCellSize: background.grid.cellSize,
        gridColor: background.grid.color,
        gridStrokeWidth: key.gridStrokeWidth,
      ),
    );
    _current = plan;
    _rebuildCount += 1;

    return plan;
  }

  void invalidate() {
    _current?.picture.dispose();
    _current = null;
  }

  StaticBackgroundCacheProbe get probe {
    return StaticBackgroundCacheProbe(
      pictureCount: _current == null ? 0 : 1,
      rebuildCount: _rebuildCount,
    );
  }
}

Picture _recordStaticBackgroundPicture({
  required Rect viewport,
  required CanvasBackground background,
  required double gridStrokeWidth,
}) {
  final recorder = PictureRecorder();
  final canvas = Canvas(recorder);
  _paintStaticBackground(canvas, viewport, background, gridStrokeWidth);

  return recorder.endRecording();
}

void _paintStaticBackground(
  Canvas canvas,
  Rect viewport,
  CanvasBackground background,
  double gridStrokeWidth,
) {
  canvas.drawRect(viewport, Paint()..color = background.color);
  final grid = background.grid;
  if (!grid.enabled || gridStrokeWidth <= 0) {
    return;
  }
  final paint = Paint()
    ..color = grid.color
    ..strokeWidth = gridStrokeWidth;
  final firstX =
      (viewport.left / grid.cellSize).floorToDouble() * grid.cellSize;
  for (var x = firstX; x <= viewport.right; x += grid.cellSize) {
    canvas.drawLine(Offset(x, viewport.top), Offset(x, viewport.bottom), paint);
  }
  final firstY = (viewport.top / grid.cellSize).floorToDouble() * grid.cellSize;
  for (var y = firstY; y <= viewport.bottom; y += grid.cellSize) {
    canvas.drawLine(Offset(viewport.left, y), Offset(viewport.right, y), paint);
  }
}

final class StaticBackgroundPlanner {
  StaticBackgroundPlanner({StaticBackgroundCache? cache})
    : _cache = cache ?? StaticBackgroundCache();

  final StaticBackgroundCache _cache;
  StaticBackgroundCache get cache => _cache;

  StaticBackgroundPlan build(
    CapturedMainFrame frame, {
    required int viewCameraBucket,
  }) {
    final revisions = frame.snapshot.revisions;

    return _cache.readOrBuild(
      StaticBackgroundKey(
        backgroundRevision: revisions.backgroundRevision,
        gridRevision: revisions.gridRevision,
        gridStrokeWidth: frame.snapshot.inputs.gridStyle.strokeWidth,
        viewCameraBucket: viewCameraBucket,
        viewportRect: frame.snapshot.inputs.viewportWorldBounds,
        devicePixelRatio: frame.snapshot.inputs.devicePixelRatio,
      ),
      background: frame.snapshot.background,
      primitiveViewportRect: frame.snapshot.inputs.effectiveWorldBounds,
    );
  }
}
