import '../contracts/internal/frame_facts_port.dart';
import '../contracts/public/canvas_ids.dart';
import 'outlier_index.dart';
import 'spatial_entry.dart';
import 'spatial_query_policy.dart';
import 'spatial_query_result.dart';
import 'tile_index.dart';

final class SpatialIndexSet {
  final TileIndex _hitIndex = TileIndex();
  final TileIndex _paintIndex = TileIndex();
  final TileIndex _contextIndex = TileIndex();
  final OutlierIndex _hitOutliers = OutlierIndex();
  final OutlierIndex _paintOutliers = OutlierIndex();
  final OutlierIndex _contextOutliers = OutlierIndex();
  final Map<CanvasElementId, SpatialEntry> _entriesById = {};

  SpatialIndexSetSnapshot get snapshot {
    return SpatialIndexSetSnapshot(
      entryCount: _entriesById.length,
      hitTilePageCount: _hitIndex.pageCount,
      paintTilePageCount: _paintIndex.pageCount,
      contextTilePageCount: _contextIndex.pageCount,
      hitOutlierCount: _hitOutliers.length,
      paintOutlierCount: _paintOutliers.length,
      contextOutlierCount: _contextOutliers.length,
    );
  }

  void replaceWith(Map<CanvasElementId, SpatialEntry> entries) {
    clear();
    _entriesById.addAll(entries);
    for (final entry in entries.values) {
      _addToIndexes(entry);
    }
  }

  void clear() {
    _hitIndex.clear();
    _paintIndex.clear();
    _contextIndex.clear();
    _hitOutliers.clear();
    _paintOutliers.clear();
    _contextOutliers.clear();
    _entriesById.clear();
  }

  void addEntry(SpatialEntry entry) {
    _entriesById[entry.id] = entry;
    _addToIndexes(entry);
  }

  void removeEntry(CanvasElementId id) {
    final previous = _entriesById.remove(id);
    if (previous == null) {
      return;
    }
    _hitIndex.remove(previous.hitMembership);
    _paintIndex.remove(previous.paintMembership);
    _contextIndex.remove(previous.contextMembership);
    _hitOutliers.remove(id);
    _paintOutliers.remove(id);
    _contextOutliers.remove(id);
  }

  SpatialQueryResult query(
    SpatialIndexKind kind,
    SpatialQueryWindow window,
    TileQueryContext context,
  ) {
    final (index, outliers) = switch (kind) {
      SpatialIndexKind.hit => (_hitIndex, _hitOutliers),
      SpatialIndexKind.paint => (_paintIndex, _paintOutliers),
      SpatialIndexKind.context => (_contextIndex, _contextOutliers),
    };

    return index.query(
      window,
      _contextWithCandidates(context, outliers.candidates()),
    );
  }

  Iterable<FrameElementHandle> get fallbackHandles {
    return _entriesById.values.map((entry) => entry.handle);
  }

  TileQueryContext _contextWithCandidates(
    TileQueryContext context,
    Iterable<FrameElementHandle> outliers,
  ) {
    return TileQueryContext(
      counters: context.counters,
      outlierCandidates: outliers,
      fallbackCandidates: fallbackHandles,
      candidateMapper: context.candidateMapper,
    );
  }

  void _addToIndexes(SpatialEntry entry) {
    _hitIndex.put(entry.hitMembership);
    _paintIndex.put(entry.paintMembership);
    _contextIndex.put(entry.contextMembership);
    _hitOutliers.put(entry.hitMembership);
    _paintOutliers.put(entry.paintMembership);
    _contextOutliers.put(entry.contextMembership);
  }
}

extension SpatialIndexSetQueries on SpatialIndexSet {
  SpatialQueryResult queryHit(
    SpatialQueryWindow window,
    TileQueryContext context,
  ) {
    return query(SpatialIndexKind.hit, window, context);
  }

  SpatialQueryResult queryPaint(
    SpatialQueryWindow window,
    TileQueryContext context,
  ) {
    return query(SpatialIndexKind.paint, window, context);
  }

  SpatialQueryResult queryContext(
    SpatialQueryWindow window,
    TileQueryContext context,
  ) {
    return query(SpatialIndexKind.context, window, context);
  }
}

final class SpatialIndexSetSnapshot {
  const SpatialIndexSetSnapshot({
    required this.entryCount,
    required this.hitTilePageCount,
    required this.paintTilePageCount,
    required this.contextTilePageCount,
    required this.hitOutlierCount,
    required this.paintOutlierCount,
    required this.contextOutlierCount,
  });

  final int entryCount;
  final int hitTilePageCount;
  final int paintTilePageCount;
  final int contextTilePageCount;
  final int hitOutlierCount;
  final int paintOutlierCount;
  final int contextOutlierCount;
}
