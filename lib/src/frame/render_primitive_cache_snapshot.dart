import 'frame_cache.dart';

final class RenderPrimitiveCacheSnapshot {
  RenderPrimitiveCacheSnapshot({
    required Map<TextLayoutCacheKey, TextLayoutCacheEntry> textLayouts,
    required Map<PathGeometryCacheKey, PathGeometryCacheEntry> paths,
    required Map<StrokePathCacheKey, StrokePathCacheEntry> strokes,
  }) : textLayouts = Map.unmodifiable(textLayouts),
       paths = Map.unmodifiable(paths),
       strokes = Map.unmodifiable(strokes);

  static final empty = RenderPrimitiveCacheSnapshot(
    textLayouts: const {},
    paths: const {},
    strokes: const {},
  );

  final Map<TextLayoutCacheKey, TextLayoutCacheEntry> textLayouts;
  final Map<PathGeometryCacheKey, PathGeometryCacheEntry> paths;
  final Map<StrokePathCacheKey, StrokePathCacheEntry> strokes;
}
