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
// facts, spatial admission, render records, and render-family cache probes.
// ignore: coupling-between-object-classes
final class OrdinaryPaintPlanner {
  OrdinaryPaintPlanner({
    PaintPlanCache? paintPlanCache,
    TextLayoutCache? textLayoutCache,
    PathGeometryCache? pathGeometryCache,
    StrokePathCache? strokePathCache,
    RenderFamilyCaches? renderFamilyCaches,
    GeometryPolicy geometryPolicy = const GeometryPolicy(),
  }) : _paintPlanCache = paintPlanCache ?? PaintPlanCache(),
       _renderFamilyCaches =
           renderFamilyCaches ??
           RenderFamilyCaches(
             textLayoutCache: textLayoutCache,
             pathGeometryCache: pathGeometryCache,
             strokePathCache: strokePathCache,
           ),
       _geometryPolicy = geometryPolicy;

  final PaintPlanCache _paintPlanCache;
  final RenderFamilyCaches _renderFamilyCaches;
  final GeometryPolicy _geometryPolicy;
  int _rejectedCandidateCount = 0;

  PaintPlanCache get paintPlanCache => _paintPlanCache;
  TextLayoutCache get textLayoutCache => _renderFamilyCaches.textLayoutCache;
  PathGeometryCache get pathGeometryCache {
    return _renderFamilyCaches.pathGeometryCache;
  }

  StrokePathCache get strokePathCache => _renderFamilyCaches.strokePathCache;
  int get rejectedCandidateCount => _rejectedCandidateCount;

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

    final key = paintPlanKeyFor(frame);
    final cached = _paintPlanCache.read(key);
    if (cached != null) {
      return OrdinaryPaintPlanReady(plan: cached, cacheHit: true);
    }

    final records = <RenderElementRecord>[];
    for (final facts in admitted) {
      records.add(
        RenderElementRecord.fromFacts(facts, geometryPolicy: _geometryPolicy),
      );
    }

    for (final facts in admitted) {
      _renderFamilyCaches.bind(facts);
    }
    final plan = PaintPlan(key: key, ordinaryRecords: records);
    _paintPlanCache.write(key, plan);

    return OrdinaryPaintPlanReady(plan: plan, cacheHit: false);
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

  List<FrameElementFacts>? _admittedOrdinaryFacts(
    CapturedFrameSnapshot snapshot,
  ) {
    final facts = <FrameElementFacts>[];
    for (final handle in snapshot.spatialPaintCandidates) {
      final candidateFacts = _capturedCandidateFacts(snapshot, handle);
      if (candidateFacts == null) {
        return null;
      }
      if (candidateFacts.locationKind == FrameElementLocationKind.content) {
        facts.add(candidateFacts);
      }
    }

    return facts;
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
}
