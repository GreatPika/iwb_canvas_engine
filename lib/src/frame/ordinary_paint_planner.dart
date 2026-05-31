import '../contracts/internal/frame_facts_port.dart';
import '../geometry/geometry_policy.dart';
import '../geometry/spatial_query_result.dart';
import 'captured_frame.dart';
import 'frame_cache.dart';
import 'paint_plan.dart';
import 'render_element_record.dart';
import 'render_family_caches.dart';

sealed class OrdinaryPaintPlanResult {
  const OrdinaryPaintPlanResult();
}

final class OrdinaryPaintPlanReady extends OrdinaryPaintPlanResult {
  const OrdinaryPaintPlanReady({required this.plan, required this.cacheHit});

  final PaintPlan plan;
  final bool cacheHit;
}

final class OrdinaryPaintPlanRejected extends OrdinaryPaintPlanResult {
  const OrdinaryPaintPlanRejected({required this.reason});

  final String reason;
}

// Ordinary planning is the single cache-write boundary for captured committed
// facts, spatial admission, reusable render records, and render-family probes.
// ignore: coupling-between-object-classes
final class OrdinaryPaintPlanner {
  OrdinaryPaintPlanner({
    OrdinaryPaintRecordCache? ordinaryPaintRecordCache,
    TextLayoutCache? textLayoutCache,
    PathGeometryCache? pathGeometryCache,
    StrokePathCache? strokePathCache,
    RenderFamilyCaches? renderFamilyCaches,
    GeometryPolicy geometryPolicy = const GeometryPolicy(),
  }) : _ordinaryPaintRecordCache =
           ordinaryPaintRecordCache ?? OrdinaryPaintRecordCache(),
       _renderFamilyCaches =
           renderFamilyCaches ??
           RenderFamilyCaches(
             textLayoutCache: textLayoutCache,
             pathGeometryCache: pathGeometryCache,
             strokePathCache: strokePathCache,
           ),
       _geometryPolicy = geometryPolicy;

  final OrdinaryPaintRecordCache _ordinaryPaintRecordCache;
  final RenderFamilyCaches _renderFamilyCaches;
  final GeometryPolicy _geometryPolicy;
  int _rejectedCandidateCount = 0;

  OrdinaryPaintRecordCache get ordinaryPaintRecordCache =>
      _ordinaryPaintRecordCache;
  TextLayoutCache get textLayoutCache => _renderFamilyCaches.textLayoutCache;
  PathGeometryCache get pathGeometryCache {
    return _renderFamilyCaches.pathGeometryCache;
  }

  StrokePathCache get strokePathCache => _renderFamilyCaches.strokePathCache;
  int get rejectedCandidateCount => _rejectedCandidateCount;

  RenderPrimitiveCacheSnapshot renderPrimitiveSnapshotFor(
    Iterable<RenderElementRecord> records,
  ) {
    return _renderFamilyCaches.bindAll(records);
  }

  OrdinaryPaintPlanResult buildOrdinaryPlan(CapturedMainFrame frame) {
    final admitted = _admittedOrdinaryFacts(frame.snapshot);
    if (admitted == null) {
      _rejectedCandidateCount += 1;

      return const OrdinaryPaintPlanRejected(
        reason: 'ordinary candidate admission failed',
      );
    }
    if (frame.snapshot.spatialPaintResult is! SpatialCandidatesResult) {
      _rejectedCandidateCount += 1;

      return const OrdinaryPaintPlanRejected(
        reason: 'spatial paint candidate admission failed',
      );
    }

    final planKey = paintPlanKeyFor(frame);
    final resolved = _resolvedOrdinaryRecords(
      frame: frame,
      admitted: admitted,
      cachedEntry: _ordinaryPaintRecordCache.read(planKey),
      geometryPolicy: _geometryPolicy,
    );
    renderPrimitiveSnapshotFor([
      for (final resolvedRecord in resolved.records) resolvedRecord.record,
    ]);
    final plan = _paintPlanFrom(planKey, resolved.records);
    _ordinaryPaintRecordCache.write(
      planKey,
      _ordinaryPaintRecordCacheEntryFor(
        cachedEntry: resolved.cachedEntry,
        resolvedRecords: resolved.records,
      ),
    );

    return OrdinaryPaintPlanReady(plan: plan, cacheHit: resolved.cacheHit);
  }

  PaintPlanKey paintPlanKeyFor(CapturedMainFrame frame) {
    final revisions = frame.snapshot.revisions;

    return PaintPlanKey(
      structuralRevision: revisions.structuralRevision,
      boundsRevision: revisions.boundsRevision,
      elementVisualRevision: revisions.elementVisualRevision,
      viewportRect: frame.snapshot.inputs.viewportWorldBounds,
      devicePixelRatio: frame.snapshot.inputs.devicePixelRatio,
    );
  }
}

List<FrameElementFacts>? _admittedOrdinaryFacts(
  CapturedFrameSnapshot snapshot,
) {
  final facts = <FrameElementFacts>[];
  for (final handle in snapshot.spatialPaintCandidates) {
    final candidateFacts = _capturedCandidateFacts(snapshot, handle);
    if (candidateFacts == null) {
      return null;
    }
    if (_isCommittedPaintLocation(candidateFacts.locationKind)) {
      facts.add(candidateFacts);
    }
  }

  return facts;
}

bool _isCommittedPaintLocation(FrameElementLocationKind locationKind) {
  return switch (locationKind) {
    FrameElementLocationKind.background ||
    FrameElementLocationKind.content => true,
  };
}

FrameElementFacts? _capturedCandidateFacts(
  CapturedFrameSnapshot snapshot,
  FrameElementHandle handle,
) {
  if (handle.structuralRevision != snapshot.revisions.structuralRevision) {
    return null;
  }

  return snapshot.elementFactsFor(handle);
}

_ResolvedOrdinaryRecords _resolvedOrdinaryRecords({
  required CapturedMainFrame frame,
  required Iterable<FrameElementFacts> admitted,
  required OrdinaryPaintRecordCacheEntry? cachedEntry,
  required GeometryPolicy geometryPolicy,
}) {
  final records = <_ResolvedOrdinaryRecord>[];
  var cacheHit = true;
  for (final facts in admitted) {
    final resolved = _resolvedOrdinaryRecord(
      frame: frame,
      facts: facts,
      cachedEntry: cachedEntry,
      geometryPolicy: geometryPolicy,
    );
    records.add(resolved);
    cacheHit = cacheHit && resolved.cacheHit;
  }

  return _ResolvedOrdinaryRecords(
    records: records,
    cacheHit: records.isNotEmpty && cacheHit,
    cachedEntry: cachedEntry,
  );
}

_ResolvedOrdinaryRecord _resolvedOrdinaryRecord({
  required CapturedMainFrame frame,
  required FrameElementFacts facts,
  required OrdinaryPaintRecordCacheEntry? cachedEntry,
  required GeometryPolicy geometryPolicy,
}) {
  final key = _ordinaryPaintRecordKeyFor(frame, facts);
  final cached = cachedEntry?.readRecord(key);
  if (cached != null) {
    return _ResolvedOrdinaryRecord(
      facts: facts,
      cacheKey: key,
      record: cached,
      cacheHit: true,
    );
  }

  return _ResolvedOrdinaryRecord(
    facts: facts,
    cacheKey: key,
    record: RenderElementRecord.fromFacts(
      facts,
      geometryPolicy: geometryPolicy,
    ),
    cacheHit: false,
  );
}

PaintPlan _paintPlanFrom(
  PaintPlanKey key,
  Iterable<_ResolvedOrdinaryRecord> records,
) {
  return PaintPlan(
    key: key,
    ordinaryRecords: [
      for (final resolvedRecord in records) resolvedRecord.record,
    ],
  );
}

OrdinaryPaintRecordCacheEntry _ordinaryPaintRecordCacheEntryFor({
  required OrdinaryPaintRecordCacheEntry? cachedEntry,
  required Iterable<_ResolvedOrdinaryRecord> resolvedRecords,
}) {
  return OrdinaryPaintRecordCacheEntry(
    records: [
      if (cachedEntry != null) ...cachedEntry.records,
      for (final resolvedRecord in resolvedRecords)
        MapEntry(resolvedRecord.cacheKey, resolvedRecord.record),
    ],
  );
}

OrdinaryPaintRecordKey _ordinaryPaintRecordKeyFor(
  CapturedMainFrame frame,
  FrameElementFacts facts,
) {
  final revisions = frame.snapshot.revisions;

  return OrdinaryPaintRecordKey(
    id: facts.id,
    structuralRevision: revisions.structuralRevision,
    boundsRevision: revisions.boundsRevision,
    elementVisualRevision: revisions.elementVisualRevision,
    generation: facts.generation,
    orderToken: facts.orderToken,
  );
}

final class _ResolvedOrdinaryRecords {
  _ResolvedOrdinaryRecords({
    required Iterable<_ResolvedOrdinaryRecord> records,
    required this.cacheHit,
    required this.cachedEntry,
  }) : records = List.unmodifiable(records);

  final List<_ResolvedOrdinaryRecord> records;
  final bool cacheHit;
  final OrdinaryPaintRecordCacheEntry? cachedEntry;
}

final class _ResolvedOrdinaryRecord {
  const _ResolvedOrdinaryRecord({
    required this.facts,
    required this.cacheKey,
    required this.record,
    required this.cacheHit,
  });

  final FrameElementFacts facts;
  final OrdinaryPaintRecordKey cacheKey;
  final RenderElementRecord record;
  final bool cacheHit;
}
