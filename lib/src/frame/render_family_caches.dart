import 'package:flutter/painting.dart';
import 'package:path_drawing/path_drawing.dart';

import '../contracts/public/canvas_element.dart';
import 'frame_cache.dart';
import 'paint_plan.dart';
import 'render_element_record.dart';

// These hot caches stay behind one owner so text, path, and stroke cache probes
// share the same ordinary planning lifecycle and capacity policy.
// ignore: coupling-between-object-classes
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

  RenderPrimitiveCacheSnapshot bindAll(Iterable<RenderElementRecord> records) {
    final textLayouts = <TextLayoutCacheKey, TextLayoutCacheEntry>{};
    final paths = <PathGeometryCacheKey, PathGeometryCacheEntry>{};
    final strokes = <StrokePathCacheKey, StrokePathCacheEntry>{};

    for (final record in records) {
      switch (record.row) {
        case final TextRenderRow row:
          textLayouts[row.layoutCacheKey] = _bindTextLayoutCache(record, row);
        case final PathRenderRow row:
          paths[row.geometryCacheKey] = _bindPathGeometryCache(row);
        case final StrokeRenderRow row:
          strokes[row.strokeCacheKey] = _bindStrokePathCache(row);
        case ImageRenderRow() || LineRenderRow() || RectRenderRow():
          continue;
      }
    }

    return RenderPrimitiveCacheSnapshot(
      textLayouts: textLayouts,
      paths: paths,
      strokes: strokes,
    );
  }

  TextLayoutCacheEntry _bindTextLayoutCache(
    RenderElementRecord record,
    TextRenderRow row,
  ) {
    final key = row.layoutCacheKey;
    final cached = textLayoutCache.read(key);
    if (cached != null) {
      return cached;
    }

    final entry = TextLayoutCacheEntry(
      debugLabel: record.id.value,
      painter: _textPainterFor(row),
    );
    textLayoutCache.write(key, entry);

    return entry;
  }

  PathGeometryCacheEntry _bindPathGeometryCache(PathRenderRow row) {
    final key = row.geometryCacheKey;
    final cached = pathGeometryCache.read(key);
    if (cached != null) {
      return cached;
    }

    final path = parseSvgPathData(row.pathDataKey)
      ..fillType = switch (row.fillRule) {
        CanvasPathFillRule.evenOdd => PathFillType.evenOdd,
        CanvasPathFillRule.nonZero => PathFillType.nonZero,
      };
    final entry = PathGeometryCacheEntry(debugLabel: key.pathData, path: path);
    pathGeometryCache.write(key, entry);

    return entry;
  }

  StrokePathCacheEntry _bindStrokePathCache(StrokeRenderRow row) {
    final key = row.strokeCacheKey;
    final cached = strokePathCache.read(key);
    if (cached != null) {
      return cached;
    }

    final entry = StrokePathCacheEntry(
      debugLabel: key.pointsKey,
      path: _strokePathFor(row.points),
    );
    strokePathCache.write(key, entry);

    return entry;
  }
}

TextPainter _textPainterFor(TextRenderRow row) {
  final painter = TextPainter(
    text: TextSpan(
      text: row.text,
      style: TextStyle(
        color: Color(row.layoutCacheKey.colorValue),
        fontSize: row.fontSize,
        fontFamily: row.fontFamily,
        fontWeight: row.isBold ? FontWeight.bold : FontWeight.normal,
        fontStyle: row.isItalic ? FontStyle.italic : FontStyle.normal,
        decoration: row.isUnderline ? TextDecoration.underline : null,
        height: row.lineHeight,
      ),
    ),
    textAlign: row.align,
    textDirection: row.direction,
  )..layout(maxWidth: row.maxWidth ?? double.infinity);

  return painter;
}

Path _strokePathFor(List<Offset> points) {
  final path = Path();
  if (points.isEmpty) {
    return path;
  }
  path.moveTo(points.first.dx, points.first.dy);
  for (final point in points.skip(1)) {
    path.lineTo(point.dx, point.dy);
  }

  return path;
}
