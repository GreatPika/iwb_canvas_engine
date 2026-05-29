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
  final OutlierIndex _hitOutliers = OutlierIndex();
  final OutlierIndex _paintOutliers = OutlierIndex();
  final Map<CanvasElementId, SpatialEntry> _entriesById = {};

  SpatialIndexSetSnapshot get snapshot {
    return SpatialIndexSetSnapshot(
      entryCount: _entriesById.length,
      hitTilePageCount: _hitIndex.pageCount,
      paintTilePageCount: _paintIndex.pageCount,
      hitOutlierCount: _hitOutliers.length,
      paintOutlierCount: _paintOutliers.length,
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
    _hitOutliers.clear();
    _paintOutliers.clear();
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
    _hitOutliers.remove(id);
    _paintOutliers.remove(id);
  }

  SpatialQueryResult queryHit(
    SpatialQueryWindow window,
    TileQueryContext context,
  ) {
    return _hitIndex.query(
      window,
      _contextWithCandidates(context, _hitOutliers.candidates()),
    );
  }

  SpatialQueryResult queryPaint(
    SpatialQueryWindow window,
    TileQueryContext context,
  ) {
    return _paintIndex.query(
      window,
      _contextWithCandidates(context, _paintOutliers.candidates()),
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
    _hitOutliers.put(entry.hitMembership);
    _paintOutliers.put(entry.paintMembership);
  }
}

final class SpatialIndexSetSnapshot {
  const SpatialIndexSetSnapshot({
    required this.entryCount,
    required this.hitTilePageCount,
    required this.paintTilePageCount,
    required this.hitOutlierCount,
    required this.paintOutlierCount,
  });

  final int entryCount;
  final int hitTilePageCount;
  final int paintTilePageCount;
  final int hitOutlierCount;
  final int paintOutlierCount;
}
