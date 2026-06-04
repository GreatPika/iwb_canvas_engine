import 'dart:ui';

import 'frame_cache.dart';
import 'frame_text_layout_measurer.dart';
import 'render_element_record.dart';
import 'render_primitive_cache_snapshot.dart';

// These hot caches stay behind one owner so text, path, and stroke cache probes
// share the same ordinary planning lifecycle and capacity policy.
// ignore: coupling-between-object-classes
final class RenderFamilyCaches {
  RenderFamilyCaches({
    TextLayoutCache? textLayoutCache,
    PathGeometryCache? pathGeometryCache,
    StrokePathCache? strokePathCache,
    FrameTextLayoutMeasurer? textLayoutMeasurer,
  }) : textLayoutMeasurer =
           textLayoutMeasurer ??
           FrameTextLayoutMeasurer(cache: textLayoutCache),
       pathGeometryCache = pathGeometryCache ?? PathGeometryCache(),
       strokePathCache = strokePathCache ?? StrokePathCache(),
       assert(
         textLayoutCache == null || textLayoutMeasurer == null,
         'Pass either textLayoutCache or textLayoutMeasurer, not both.',
       );

  TextLayoutCache get textLayoutCache => textLayoutMeasurer.cache;
  final PathGeometryCache pathGeometryCache;
  final StrokePathCache strokePathCache;
  final FrameTextLayoutMeasurer textLayoutMeasurer;

  RenderPrimitiveCacheSnapshot bindAll(Iterable<RenderElementRecord> records) {
    final textLayouts = <TextLayoutCacheKey, TextLayoutCacheEntry>{};
    final paths = <PathGeometryCacheKey, PathGeometryCacheEntry>{};
    final strokes = <StrokePathCacheKey, StrokePathCacheEntry>{};

    for (final record in records) {
      switch (record.row) {
        case final TextRenderRow row:
          textLayouts[row.layoutCacheKey] = _bindTextLayoutCache(record, row);
        case final PathRenderRow row:
          final path = _bindPathGeometryCache(row);
          if (path != null) {
            paths[row.geometryCacheKey] = path;
          }
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
    return textLayoutMeasurer.bindTextLayout(
      row.layoutInput,
      debugLabel: record.id.value,
    );
  }

  PathGeometryCacheEntry? _bindPathGeometryCache(PathRenderRow row) {
    final key = row.geometryCacheKey;
    final cached = pathGeometryCache.read(key);
    if (cached != null) {
      return cached;
    }

    final path = row.normalizedPath;
    if (path == null) {
      return null;
    }
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
