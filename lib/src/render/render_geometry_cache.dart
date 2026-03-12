import 'dart:collection';
import 'dart:ui';

import 'package:flutter/foundation.dart';

import '../core/geometry.dart';
import '../core/local_bounds_policy.dart' hide isFiniteRect, sanitizeFiniteRect;
import '../core/numeric_clamp.dart';
import '../contract/transform2d.dart';
import '../contract/snapshot.dart';

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

/// Per-node geometry cache injected into `ScenePainter`.
///
/// Memory is bounded via LRU eviction (`maxEntries`), while `invalidateAll()`
/// remains available for explicit full cache reset on owner epoch/document
/// boundaries. `epoch` is intentionally not part of per-entry keys.
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
    if (!isFiniteOffset(node.start) || !isFiniteOffset(node.end)) {
      return const GeometryEntry(
        localBounds: Rect.zero,
        worldBounds: Rect.zero,
      );
    }
    final localBounds = lineLocalBounds(
      start: node.start,
      end: node.end,
      thickness: clampNonNegativeFinite(node.thickness),
    );
    return GeometryEntry(
      localBounds: localBounds,
      worldBounds: _toWorldBounds(node.transform, localBounds),
    );
  }

  GeometryEntry _strokeEntry(StrokeNodeSnapshot node) {
    if (node.points.isEmpty || !areFiniteOffsets(node.points)) {
      return const GeometryEntry(
        localBounds: Rect.zero,
        worldBounds: Rect.zero,
      );
    }
    final localBounds = strokeLocalBounds(
      points: node.points,
      thickness: clampNonNegativeFinite(node.thickness),
    );
    return GeometryEntry(
      localBounds: localBounds,
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
    return buildCenteredSvgPathGeometry(
      node.svgPathData,
      fillType: _fillTypeFromSnapshot(node.fillRule),
    )?.localPath;
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
  final transformKey = _transformKey(node.transform);
  return switch (node) {
    RectNodeSnapshot rectNode => _rectValidityKey(rectNode, transformKey),
    ImageNodeSnapshot imageNode => _imageValidityKey(imageNode, transformKey),
    TextNodeSnapshot textNode => _textValidityKey(textNode, transformKey),
    LineNodeSnapshot lineNode => _lineValidityKey(lineNode, transformKey),
    // Keep stroke key stable across logically equal snapshots:
    // only scalar/revision geometry inputs, never collection identity.
    StrokeNodeSnapshot strokeNode => _strokeValidityKey(
      strokeNode,
      transformKey,
    ),
    PathNodeSnapshot pathNode => _pathValidityKey(pathNode, transformKey),
  };
}

({double a, double b, double c, double d, double tx, double ty}) _transformKey(
  Transform2D transform,
) {
  return (
    a: transform.a,
    b: transform.b,
    c: transform.c,
    d: transform.d,
    tx: transform.tx,
    ty: transform.ty,
  );
}

Object _rectValidityKey(
  RectNodeSnapshot node,
  ({double a, double b, double c, double d, double tx, double ty}) transformKey,
) {
  return (
    'rect',
    transformKey.a,
    transformKey.b,
    transformKey.c,
    transformKey.d,
    transformKey.tx,
    transformKey.ty,
    node.size.width,
    node.size.height,
    effectiveStrokeWidth(
      strokeColor: node.strokeColor,
      strokeWidth: node.strokeWidth,
    ),
  );
}

Object _imageValidityKey(
  ImageNodeSnapshot node,
  ({double a, double b, double c, double d, double tx, double ty}) transformKey,
) {
  return (
    'image',
    transformKey.a,
    transformKey.b,
    transformKey.c,
    transformKey.d,
    transformKey.tx,
    transformKey.ty,
    node.size.width,
    node.size.height,
  );
}

Object _textValidityKey(
  TextNodeSnapshot node,
  ({double a, double b, double c, double d, double tx, double ty}) transformKey,
) {
  return (
    'text',
    transformKey.a,
    transformKey.b,
    transformKey.c,
    transformKey.d,
    transformKey.tx,
    transformKey.ty,
    node.size.width,
    node.size.height,
  );
}

Object _lineValidityKey(
  LineNodeSnapshot node,
  ({double a, double b, double c, double d, double tx, double ty}) transformKey,
) {
  return (
    'line',
    transformKey.a,
    transformKey.b,
    transformKey.c,
    transformKey.d,
    transformKey.tx,
    transformKey.ty,
    node.start.dx,
    node.start.dy,
    node.end.dx,
    node.end.dy,
    clampNonNegativeFinite(node.thickness),
  );
}

Object _strokeValidityKey(
  StrokeNodeSnapshot node,
  ({double a, double b, double c, double d, double tx, double ty}) transformKey,
) {
  return (
    'stroke',
    transformKey.a,
    transformKey.b,
    transformKey.c,
    transformKey.d,
    transformKey.tx,
    transformKey.ty,
    node.pointsRevision,
    clampNonNegativeFinite(node.thickness),
  );
}

Object _pathValidityKey(
  PathNodeSnapshot node,
  ({double a, double b, double c, double d, double tx, double ty}) transformKey,
) {
  return (
    'path',
    transformKey.a,
    transformKey.b,
    transformKey.c,
    transformKey.d,
    transformKey.tx,
    transformKey.ty,
    node.svgPathData,
    node.fillRule,
    effectiveStrokeWidth(
      strokeColor: node.strokeColor,
      strokeWidth: node.strokeWidth,
    ),
  );
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

PathFillType _fillTypeFromSnapshot(PathFillRule rule) {
  return rule == PathFillRule.evenOdd
      ? PathFillType.evenOdd
      : PathFillType.nonZero;
}

bool _isFiniteRect(Rect rect) {
  return isFiniteRect(rect);
}
