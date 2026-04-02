import 'dart:ui';

import '../core/geometry.dart';
import '../core/local_bounds_policy.dart' hide isFiniteRect;
import '../core/numeric_clamp.dart';
import '../core/text_layout.dart';
import '../contract/snapshot.dart';
import '../contract/transform2d.dart';
import 'render_geometry_entry.dart';

const _zeroGeometryEntry = GeometryEntry(
  localBounds: Rect.zero,
  worldBounds: Rect.zero,
);

GeometryEntry buildRenderGeometryEntry(NodeSnapshot node) {
  return switch (node) {
    RectNodeSnapshot rectNode => _rectEntry(rectNode),
    ImageNodeSnapshot imageNode => _imageEntry(imageNode),
    TextNodeSnapshot textNode => _textEntry(textNode),
    LineNodeSnapshot lineNode => _lineEntry(lineNode),
    StrokeNodeSnapshot strokeNode => _strokeEntry(strokeNode),
    PathNodeSnapshot pathNode => _pathEntry(pathNode),
    _ => throw StateError(
      'Unsupported NodeSnapshot subtype: ${node.runtimeType}',
    ),
  };
}

Object buildRenderGeometryValidityKey(NodeSnapshot node) {
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
    _ => throw StateError(
      'Unsupported NodeSnapshot subtype: ${node.runtimeType}',
    ),
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
  return _centeredRectEntry(node.size, node.transform);
}

GeometryEntry _textEntry(TextNodeSnapshot node) {
  final localBounds = centeredRectLocalBounds(_measureTextNodeSnapshot(node));
  return GeometryEntry(
    localBounds: localBounds,
    worldBounds: _toWorldBounds(node.transform, localBounds),
  );
}

GeometryEntry _lineEntry(LineNodeSnapshot node) {
  if (!isFiniteOffset(node.start) || !isFiniteOffset(node.end)) {
    return _zeroGeometryEntry;
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
    return _zeroGeometryEntry;
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
    return _zeroGeometryEntry;
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

GeometryEntry _centeredRectEntry(Size size, Transform2D transform) {
  final localBounds = centeredRectLocalBounds(size);
  return GeometryEntry(
    localBounds: localBounds,
    worldBounds: _toWorldBounds(transform, localBounds),
  );
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
  final request = _textLayoutRequest(node);
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
    pointsRevision: node.pointsRevision,
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

Rect _toWorldBounds(Transform2D transform, Rect localBounds) {
  if (!transform.isFinite || !isFiniteRect(localBounds)) {
    return Rect.zero;
  }
  final worldBounds = transform.applyToRect(localBounds);
  if (!isFiniteRect(worldBounds)) {
    return Rect.zero;
  }
  return worldBounds;
}

PathFillType _fillTypeFromSnapshot(PathFillRule rule) {
  return rule == PathFillRule.evenOdd
      ? PathFillType.evenOdd
      : PathFillType.nonZero;
}

TextLayoutRequest _textLayoutRequest(TextNodeSnapshot node) {
  return TextLayoutRequest(
    text: node.text,
    color: node.color,
    fontSize: node.fontSize,
    isBold: node.isBold,
    isItalic: node.isItalic,
    isUnderline: node.isUnderline,
    textAlign: node.align,
    fontFamily: node.fontFamily,
    lineHeight: node.lineHeight,
    maxWidth: node.maxWidth,
    textDirection: node.textDirection,
  );
}

Size _measureTextNodeSnapshot(TextNodeSnapshot node) {
  return _textLayoutRequest(node).measure();
}
