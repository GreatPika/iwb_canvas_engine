import 'dart:collection';
import 'dart:ui';

import '../contract/snapshot.dart';
import '../contract/transform2d.dart';
import 'local_bounds_policy.dart';
import 'node_geometry.dart';
import 'numeric_clamp.dart';
import 'text_layout.dart';

abstract interface class SnapshotPaintAdmissionBoundsSource {
  Rect resolveBasePaintBounds(NodeSnapshot node);
}

final class SnapshotPaintAdmissionBoundsCache
    implements SnapshotPaintAdmissionBoundsSource {
  SnapshotPaintAdmissionBoundsCache({int maxEntries = 512})
    : maxEntries = _requirePositiveMaxEntries(maxEntries);

  final int maxEntries;
  final LinkedHashMap<_SnapshotNodeInstanceKey, _SnapshotBoundsRecord>
  _entries = LinkedHashMap<_SnapshotNodeInstanceKey, _SnapshotBoundsRecord>();

  int _debugBuildCount = 0;
  int _debugHitCount = 0;
  int _debugEvictCount = 0;

  int get debugBuildCount => _debugBuildCount;
  int get debugHitCount => _debugHitCount;
  int get debugEvictCount => _debugEvictCount;
  int get debugSize => _entries.length;

  ({int buildCount, int hitCount, int evictCount}) captureProbe() {
    return (
      buildCount: debugBuildCount,
      hitCount: debugHitCount,
      evictCount: debugEvictCount,
    );
  }

  void clear() {
    _entries.clear();
  }

  @override
  Rect resolveBasePaintBounds(NodeSnapshot node) {
    requireSnapshotPaintAdmissionBoundsSupport(node);
    final entryKey = _SnapshotNodeInstanceKey(
      nodeId: node.id,
      instanceRevision: node.instanceRevision,
    );
    final validityKey = buildSnapshotPaintAdmissionBoundsValidityKey(node);
    final cached = _entries.remove(entryKey);
    if (cached != null && cached.validityKey == validityKey) {
      _entries[entryKey] = cached;
      _debugHitCount += 1;
      return cached.paintBoundsWorld;
    }

    final paintBoundsWorld = nodeSnapshotPaintBoundsWorld(node);
    _entries[entryKey] = _SnapshotBoundsRecord(
      validityKey: validityKey,
      paintBoundsWorld: paintBoundsWorld,
    );
    _debugBuildCount += 1;
    _evictIfNeeded();
    return paintBoundsWorld;
  }

  void _evictIfNeeded() {
    while (_entries.length > maxEntries) {
      _entries.remove(_entries.keys.first);
      _debugEvictCount += 1;
    }
  }
}

void requireSnapshotPaintAdmissionBoundsSupport(NodeSnapshot node) {
  switch (node) {
    case ImageNodeSnapshot():
    case TextNodeSnapshot():
    case RectNodeSnapshot():
    case LineNodeSnapshot():
    case StrokeNodeSnapshot():
    case PathNodeSnapshot():
      return;
    default:
      throw StateError(
        'Unsupported NodeSnapshot subtype at admission: ${node.runtimeType}',
      );
  }
}

Object buildSnapshotPaintAdmissionBoundsValidityKey(NodeSnapshot node) {
  final transformKey = _transformKey(node.transform);
  return switch (node) {
    ImageNodeSnapshot imageNode => _imageValidityKey(imageNode, transformKey),
    TextNodeSnapshot textNode => _textValidityKey(textNode, transformKey),
    RectNodeSnapshot rectNode => _rectValidityKey(rectNode, transformKey),
    LineNodeSnapshot lineNode => _lineValidityKey(lineNode, transformKey),
    StrokeNodeSnapshot strokeNode => _strokeValidityKey(
      strokeNode,
      transformKey,
    ),
    PathNodeSnapshot pathNode => _pathValidityKey(pathNode, transformKey),
    _ => throw StateError(
      'Unsupported NodeSnapshot subtype at admission: ${node.runtimeType}',
    ),
  };
}

Object _imageValidityKey(
  ImageNodeSnapshot node,
  ({double a, double b, double c, double d, double tx, double ty}) transformKey,
) {
  return _transformScopedValidityKey('image', transformKey, (
    width: node.size.width,
    height: node.size.height,
  ));
}

Object _textValidityKey(
  TextNodeSnapshot node,
  ({double a, double b, double c, double d, double tx, double ty}) transformKey,
) {
  final request = TextLayoutRequest.forSnapshot(node);
  return _transformScopedValidityKey('text', transformKey, (
    text: request.text,
    fontSize: request.normalizedFontSize,
    align: request.textAlign,
    textDirection: request.textDirection,
    isBold: request.isBold,
    isItalic: request.isItalic,
    isUnderline: request.isUnderline,
    fontFamily: request.fontFamily,
    lineHeight: request.normalizedLineHeight,
    maxWidth: request.normalizedMaxWidth,
  ));
}

Object _rectValidityKey(
  RectNodeSnapshot node,
  ({double a, double b, double c, double d, double tx, double ty}) transformKey,
) {
  return _transformScopedValidityKey('rect', transformKey, (
    width: node.size.width,
    height: node.size.height,
    strokeWidth: effectiveStrokeWidth(
      strokeColor: node.strokeColor,
      strokeWidth: node.strokeWidth,
    ),
  ));
}

Object _lineValidityKey(
  LineNodeSnapshot node,
  ({double a, double b, double c, double d, double tx, double ty}) transformKey,
) {
  return _transformScopedValidityKey('line', transformKey, (
    startDx: node.start.dx,
    startDy: node.start.dy,
    endDx: node.end.dx,
    endDy: node.end.dy,
    thickness: clampNonNegativeFinite(node.thickness),
  ));
}

Object _strokeValidityKey(
  StrokeNodeSnapshot node,
  ({double a, double b, double c, double d, double tx, double ty}) transformKey,
) {
  return _transformScopedValidityKey('stroke', transformKey, (
    points: Object.hashAll(node.points),
    thickness: clampNonNegativeFinite(node.thickness),
  ));
}

Object _pathValidityKey(
  PathNodeSnapshot node,
  ({double a, double b, double c, double d, double tx, double ty}) transformKey,
) {
  return _transformScopedValidityKey('path', transformKey, (
    svgPathData: node.svgPathData,
    fillRule: node.fillRule,
    strokeWidth: effectiveStrokeWidth(
      strokeColor: node.strokeColor,
      strokeWidth: node.strokeWidth,
    ),
  ));
}

Object _transformScopedValidityKey(
  String kind,
  ({double a, double b, double c, double d, double tx, double ty}) transformKey,
  Object payload,
) {
  return (kind: kind, transform: transformKey, payload: payload);
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

int _requirePositiveMaxEntries(int maxEntries) {
  if (maxEntries <= 0) {
    throw ArgumentError.value(maxEntries, 'maxEntries', 'Must be > 0.');
  }
  return maxEntries;
}

final class _SnapshotBoundsRecord {
  const _SnapshotBoundsRecord({
    required this.validityKey,
    required this.paintBoundsWorld,
  });

  final Object validityKey;
  final Rect paintBoundsWorld;
}

final class _SnapshotNodeInstanceKey {
  const _SnapshotNodeInstanceKey({
    required this.nodeId,
    required this.instanceRevision,
  });

  final NodeId nodeId;
  final int instanceRevision;

  @override
  bool operator ==(Object other) {
    return other is _SnapshotNodeInstanceKey &&
        other.nodeId == nodeId &&
        other.instanceRevision == instanceRevision;
  }

  @override
  int get hashCode => Object.hash(nodeId, instanceRevision);
}
