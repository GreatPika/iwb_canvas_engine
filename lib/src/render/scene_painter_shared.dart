import 'dart:typed_data';
import 'dart:ui';

import '../contract/transform2d.dart';
import '../contract/snapshot.dart';
import '../core/numeric_clamp.dart';
import 'cache/scene_stroke_path_cache.dart';

Rect scenePainterCenterRect(Size size) {
  final safe = clampNonNegativeSizeFinite(size);
  return Rect.fromCenter(
    center: Offset.zero,
    width: safe.width,
    height: safe.height,
  );
}

Rect scenePainterNormalizeRect(Rect rect) {
  final left = rect.left < rect.right ? rect.left : rect.right;
  final right = rect.left < rect.right ? rect.right : rect.left;
  final top = rect.top < rect.bottom ? rect.top : rect.bottom;
  final bottom = rect.top < rect.bottom ? rect.bottom : rect.top;
  return Rect.fromLTRB(left, top, right, bottom);
}

Color scenePainterApplyOpacity(Color color, double opacity) {
  final alpha = (scenePainterAlpha01(opacity) * 255.0).round().clamp(0, 255);
  return color.withAlpha(alpha);
}

double scenePainterAlpha01(double opacity) {
  return clampNonNegativeFinite(opacity).clamp(0.0, 1.0);
}

double scenePainterTextAlignOffset(
  TextAlign align,
  double boxWidth,
  double textWidth,
  TextDirection textDirection,
) {
  switch (align) {
    case TextAlign.right:
      return boxWidth - textWidth;
    case TextAlign.end:
      return textDirection == TextDirection.rtl ? 0 : boxWidth - textWidth;
    case TextAlign.center:
      return (boxWidth - textWidth) / 2;
    case TextAlign.left:
      return 0;
    case TextAlign.start:
    case TextAlign.justify:
      return textDirection == TextDirection.rtl ? boxWidth - textWidth : 0;
  }
}

bool scenePainterIsFiniteRect(Rect rect) {
  return rect.left.isFinite &&
      rect.top.isFinite &&
      rect.right.isFinite &&
      rect.bottom.isFinite;
}

bool scenePainterIsFiniteOffset(Offset offset) {
  return offset.dx.isFinite && offset.dy.isFinite;
}

bool scenePainterCanPaintStrokeNode(StrokeNodeSnapshot node) {
  return node.points.isNotEmpty &&
      node.transform.isFinite &&
      _areFiniteOffsets(node.points);
}

Path scenePainterResolveStrokePath(
  StrokeNodeSnapshot node,
  SceneStrokePathCache? strokePathCache,
) {
  return strokePathCache != null
      ? strokePathCache.getOrBuild(node)
      : buildStrokePath(node.points);
}

Float64List scenePainterToViewTransform(
  Float64List transformBuffer,
  Transform2D transform,
  Offset cameraOffset,
) {
  transformBuffer[0] = transform.a;
  transformBuffer[1] = transform.b;
  transformBuffer[2] = 0;
  transformBuffer[3] = 0;
  transformBuffer[4] = transform.c;
  transformBuffer[5] = transform.d;
  transformBuffer[6] = 0;
  transformBuffer[7] = 0;
  transformBuffer[8] = 0;
  transformBuffer[9] = 0;
  transformBuffer[10] = 1;
  transformBuffer[11] = 0;
  transformBuffer[12] = transform.tx - cameraOffset.dx;
  transformBuffer[13] = transform.ty - cameraOffset.dy;
  transformBuffer[14] = 0;
  transformBuffer[15] = 1;
  return transformBuffer;
}

bool _areFiniteOffsets(List<Offset> offsets) {
  for (final offset in offsets) {
    if (!scenePainterIsFiniteOffset(offset)) {
      return false;
    }
  }
  return true;
}
