import 'dart:ui';

import '../contracts/internal/frame_facts_port.dart';
import '../contracts/public/canvas_element.dart';
import 'frame_cache.dart';

final class RenderFamilyCaches {
  RenderFamilyCaches({
    TextLayoutCache? textLayoutCache,
    PathGeometryCache? pathGeometryCache,
    StrokePathCache? strokePathCache,
  }) : textLayoutCache = textLayoutCache ?? TextLayoutCache(),
       pathGeometryCache = pathGeometryCache ?? PathGeometryCache(),
       strokePathCache = strokePathCache ?? StrokePathCache();

  final TextLayoutCache textLayoutCache;
  final PathGeometryCache pathGeometryCache;
  final StrokePathCache strokePathCache;

  void bind(FrameElementFacts facts) {
    switch (facts.kind) {
      case CanvasElementKind.text:
        _bindTextLayoutCache(facts);
      case CanvasElementKind.path:
        _bindPathGeometryCache(facts);
      case CanvasElementKind.stroke:
        _bindStrokePathCache(facts);
      case CanvasElementKind.image ||
          CanvasElementKind.line ||
          CanvasElementKind.rect:
        return;
    }
  }

  void _bindTextLayoutCache(FrameElementFacts facts) {
    final text = facts.text;
    if (text == null) {
      return;
    }
    final key = TextLayoutCacheKey(
      text: text,
      fontSize: facts.fontSize ?? 24,
      colorValue: (facts.textColor ?? const Color(0xFF000000)).toARGB32(),
      alignName: (facts.textAlign ?? TextAlign.left).name,
      directionName: (facts.textDirection ?? TextDirection.ltr).name,
      isBold: facts.isBold ?? false,
      isItalic: facts.isItalic ?? false,
      isUnderline: facts.isUnderline ?? false,
      fontFamily: facts.fontFamily,
      maxWidth: facts.maxWidth,
      lineHeight: facts.lineHeight,
    );
    if (textLayoutCache.read(key) == null) {
      textLayoutCache.write(
        key,
        TextLayoutCacheEntry(debugLabel: facts.id.value),
      );
    }
  }

  void _bindPathGeometryCache(FrameElementFacts facts) {
    final pathData = facts.svgPathData;
    if (pathData == null) {
      return;
    }
    final key = PathGeometryCacheKey(
      pathData: pathData,
      fillRuleName: (facts.fillRule ?? CanvasPathFillRule.nonZero).name,
      strokeWidth: facts.strokeWidth ?? 0,
    );
    if (pathGeometryCache.read(key) == null) {
      pathGeometryCache.write(
        key,
        PathGeometryCacheEntry(debugLabel: facts.id.value),
      );
    }
  }

  void _bindStrokePathCache(FrameElementFacts facts) {
    final key = StrokePathCacheKey(
      pointsKey: facts.points
          .map((point) => '${point.dx},${point.dy}')
          .join(';'),
      thickness: facts.thickness ?? 1,
      transformScaleKey: _strokeTransformScaleKey(facts),
    );
    if (strokePathCache.read(key) == null) {
      strokePathCache.write(
        key,
        StrokePathCacheEntry(debugLabel: facts.id.value),
      );
    }
  }
}

String _strokeTransformScaleKey(FrameElementFacts facts) {
  final transform = facts.transform;

  return '${transform.a},${transform.b},${transform.c},${transform.d}';
}
