import 'dart:collection';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:path_drawing/path_drawing.dart';

import '../core/geometry.dart';
import '../core/local_bounds_policy.dart';
import '../core/numeric_clamp.dart';
import '../core/transform2d.dart';
import '../public/snapshot.dart';

class GeometryEntry {
  const GeometryEntry({
    required this.localBounds,
    required this.worldBounds,
    this.localPath,
  });

  final Rect localBounds;
  final Rect worldBounds;
  final Path? localPath;
}

int _requirePositiveGeometryCacheEntries(int maxEntries) {
  if (maxEntries <= 0) {
    throw ArgumentError.value(maxEntries, 'maxEntries', 'Must be > 0.');
  }
  return maxEntries;
}

/// Per-node geometry cache owned by `ScenePainterV2`.
///
/// Memory is bounded via LRU eviction (`maxEntries`), while `invalidateAll()`
/// remains available for explicit full cache reset.
class RenderGeometryCache {
  RenderGeometryCache({int maxEntries = 512})
    : maxEntries = _requirePositiveGeometryCacheEntries(maxEntries);

  final int maxEntries;
  final LinkedHashMap<_NodeInstanceKey, _GeometryCacheRecord> _entries =
      LinkedHashMap<_NodeInstanceKey, _GeometryCacheRecord>();

  int _debugBuildCount = 0;
  int _debugHitCount = 0;
  int _debugEvictCount = 0;

  @visibleForTesting
  int get debugBuildCount => _debugBuildCount;
  @visibleForTesting
  int get debugHitCount => _debugHitCount;
  @visibleForTesting
  int get debugEvictCount => _debugEvictCount;
  @visibleForTesting
  int get debugSize => _entries.length;

  GeometryEntry get(NodeSnapshot node) {
    final key = _buildValidityKey(node);
    final entryKey = _NodeInstanceKey(
      nodeId: node.id,
      instanceRevision: node.instanceRevision,
    );
    final cached = _entries.remove(entryKey);
    if (cached != null && cached.key == key) {
      _entries[entryKey] = cached;
      _debugHitCount += 1;
      return cached.entry;
    }

    final entry = _buildEntry(node);
    _entries[entryKey] = _GeometryCacheRecord(key: key, entry: entry);
    _debugBuildCount += 1;
    _evictIfNeeded();
    return entry;
  }

  void invalidateAll() => _entries.clear();

  void _evictIfNeeded() {
    while (_entries.length > maxEntries) {
      _entries.remove(_entries.keys.first);
      _debugEvictCount += 1;
    }
  }

  GeometryEntry _buildEntry(NodeSnapshot node) {
    return switch (node) {
      RectNodeSnapshot rectNode => _rectEntry(rectNode),
      ImageNodeSnapshot imageNode => _imageEntry(imageNode),
      TextNodeSnapshot textNode => _textEntry(textNode),
      LineNodeSnapshot lineNode => _lineEntry(lineNode),
      StrokeNodeSnapshot strokeNode => _strokeEntry(strokeNode),
      PathNodeSnapshot pathNode => _pathEntry(pathNode),
    };
  }

  GeometryEntry _rectEntry(RectNodeSnapshot node) {
    final localBounds = strokeAwareCenteredRectLocalBounds(
      size: node.size,
      strokeColor: node.strokeColor,
      strokeWidth: node.strokeWidth,
    );
    return GeometryEntry(
      localBounds: localBounds,
      worldBounds: _toWorldBounds(node.transform, localBounds),
    );
  }

  GeometryEntry _imageEntry(ImageNodeSnapshot node) {
    final localBounds = centeredRectLocalBounds(node.size);
    return GeometryEntry(
      localBounds: localBounds,
      worldBounds: _toWorldBounds(node.transform, localBounds),
    );
  }

  GeometryEntry _textEntry(TextNodeSnapshot node) {
    final localBounds = centeredRectLocalBounds(node.size);
    return GeometryEntry(
      localBounds: localBounds,
      worldBounds: _toWorldBounds(node.transform, localBounds),
    );
  }

  GeometryEntry _lineEntry(LineNodeSnapshot node) {
    if (!_isFiniteOffset(node.start) || !_isFiniteOffset(node.end)) {
      return const GeometryEntry(
        localBounds: Rect.zero,
        worldBounds: Rect.zero,
      );
    }
    final safeThickness = clampNonNegativeFinite(node.thickness);
    final localBounds = Rect.fromPoints(
      node.start,
      node.end,
    ).inflate(safeThickness / 2);
    return GeometryEntry(
      localBounds: sanitizeFiniteRect(localBounds),
      worldBounds: _toWorldBounds(node.transform, localBounds),
    );
  }

  GeometryEntry _strokeEntry(StrokeNodeSnapshot node) {
    if (node.points.isEmpty || !_areFiniteOffsets(node.points)) {
      return const GeometryEntry(
        localBounds: Rect.zero,
        worldBounds: Rect.zero,
      );
    }
    final safeThickness = clampNonNegativeFinite(node.thickness);
    final localBounds = aabbFromPoints(node.points).inflate(safeThickness / 2);
    return GeometryEntry(
      localBounds: sanitizeFiniteRect(localBounds),
      worldBounds: _toWorldBounds(node.transform, localBounds),
    );
  }

  GeometryEntry _pathEntry(PathNodeSnapshot node) {
    final localPath = _buildLocalPath(node);
    if (localPath == null) {
      return const GeometryEntry(
        localBounds: Rect.zero,
        worldBounds: Rect.zero,
      );
    }

    final localBounds = strokeAwareLocalBounds(
      baseBounds: localPath.getBounds(),
      strokeColor: node.strokeColor,
      strokeWidth: node.strokeWidth,
    );
    return GeometryEntry(
      localBounds: localBounds,
      worldBounds: _toWorldBounds(node.transform, localBounds),
      localPath: localPath,
    );
  }

  Path? _buildLocalPath(PathNodeSnapshot node) {
    if (node.svgPathData.trim().isEmpty) {
      return null;
    }
    try {
      final path = parseSvgPathData(node.svgPathData);
      var hasNonZeroLength = false;
      for (final metric in path.computeMetrics()) {
        if (metric.length > 0) {
          hasNonZeroLength = true;
          break;
        }
      }
      if (!hasNonZeroLength) {
        return null;
      }
      final bounds = path.getBounds();
      final centered = path.shift(-bounds.center);
      centered.fillType = _fillTypeFromSnapshot(node.fillRule);
      if (!_isFiniteRect(centered.getBounds())) {
        return null;
      }
      return centered;
    } catch (_) {
      return null;
    }
  }
}

class _GeometryCacheRecord {
  const _GeometryCacheRecord({required this.key, required this.entry});

  final Object key;
  final GeometryEntry entry;
}

class _NodeInstanceKey {
  const _NodeInstanceKey({
    required this.nodeId,
    required this.instanceRevision,
  });

  final NodeId nodeId;
  final int instanceRevision;

  @override
  bool operator ==(Object other) {
    return other is _NodeInstanceKey &&
        other.nodeId == nodeId &&
        other.instanceRevision == instanceRevision;
  }

  @override
  int get hashCode => Object.hash(nodeId, instanceRevision);
}

Object _buildValidityKey(NodeSnapshot node) {
  final t = node.transform;
  final ta = t.a;
  final tb = t.b;
  final tc = t.c;
  final td = t.d;
  final ttx = t.tx;
  final tty = t.ty;
  return switch (node) {
    RectNodeSnapshot rectNode => (
      'rect',
      ta,
      tb,
      tc,
      td,
      ttx,
      tty,
      rectNode.size.width,
      rectNode.size.height,
      effectiveStrokeWidth(
        strokeColor: rectNode.strokeColor,
        strokeWidth: rectNode.strokeWidth,
      ),
    ),
    ImageNodeSnapshot imageNode => (
      'image',
      ta,
      tb,
      tc,
      td,
      ttx,
      tty,
      imageNode.size.width,
      imageNode.size.height,
    ),
    TextNodeSnapshot textNode => (
      'text',
      ta,
      tb,
      tc,
      td,
      ttx,
      tty,
      textNode.size.width,
      textNode.size.height,
    ),
    LineNodeSnapshot lineNode => (
      'line',
      ta,
      tb,
      tc,
      td,
      ttx,
      tty,
      lineNode.start.dx,
      lineNode.start.dy,
      lineNode.end.dx,
      lineNode.end.dy,
      clampNonNegativeFinite(lineNode.thickness),
    ),
    // Keep stroke key stable across logically equal snapshots:
    // only scalar/revision geometry inputs, never collection identity.
    StrokeNodeSnapshot strokeNode => (
      'stroke',
      ta,
      tb,
      tc,
      td,
      ttx,
      tty,
      strokeNode.pointsRevision,
      clampNonNegativeFinite(strokeNode.thickness),
    ),
    PathNodeSnapshot pathNode => (
      'path',
      ta,
      tb,
      tc,
      td,
      ttx,
      tty,
      pathNode.svgPathData,
      pathNode.fillRule,
      effectiveStrokeWidth(
        strokeColor: pathNode.strokeColor,
        strokeWidth: pathNode.strokeWidth,
      ),
    ),
  };
}

Rect _toWorldBounds(Transform2D transform, Rect localBounds) {
  if (!transform.isFinite || !_isFiniteRect(localBounds)) {
    return Rect.zero;
  }
  final worldBounds = transform.applyToRect(localBounds);
  if (!_isFiniteRect(worldBounds)) {
    return Rect.zero;
  }
  return worldBounds;
}

PathFillType _fillTypeFromSnapshot(V2PathFillRule rule) {
  return rule == V2PathFillRule.evenOdd
      ? PathFillType.evenOdd
      : PathFillType.nonZero;
}

bool _isFiniteRect(Rect rect) {
  return rect.left.isFinite &&
      rect.top.isFinite &&
      rect.right.isFinite &&
      rect.bottom.isFinite;
}

bool _isFiniteOffset(Offset offset) {
  return offset.dx.isFinite && offset.dy.isFinite;
}

bool _areFiniteOffsets(List<Offset> offsets) {
  for (final offset in offsets) {
    if (!_isFiniteOffset(offset)) {
      return false;
    }
  }
  return true;
}
