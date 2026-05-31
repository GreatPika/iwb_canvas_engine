import 'dart:ui';

import 'package:flutter/foundation.dart';

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
  StaticBackgroundPicture({required this.debugLabel});

  final String debugLabel;
  bool isDisposed = false;

  void dispose() {
    isDisposed = true;
  }
}

final class StaticBackgroundPlan {
  const StaticBackgroundPlan({required this.key, required this.picture});

  final StaticBackgroundKey key;
  final StaticBackgroundPicture picture;
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

  StaticBackgroundPlan readOrBuild(StaticBackgroundKey key) {
    final current = _current;
    if (current != null && current.key == key) {
      return current;
    }
    current?.picture.dispose();
    final plan = StaticBackgroundPlan(
      key: key,
      picture: StaticBackgroundPicture(debugLabel: 'static-background'),
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
    );
  }
}
