import 'dart:ui';

import '../contracts/internal/frame_facts_port.dart';
import '../contracts/public/canvas_ids.dart';
import 'geometry_policy.dart';
import 'spatial_membership.dart';

final class SpatialEntry {
  const SpatialEntry({
    required this.handle,
    required this.hitMembership,
    required this.paintMembership,
  });

  CanvasElementId get id => handle.id;

  final FrameElementHandle handle;
  final SpatialMembership hitMembership;
  final SpatialMembership paintMembership;
}

SpatialEntry? spatialEntryFor({
  required FrameFactsPort frame,
  required FrameElementHandle handle,
  required GeometryPolicy geometryPolicy,
}) {
  final facts = frame.resolveElement(handle);
  if (facts == null ||
      facts.generation != handle.generation ||
      facts.orderToken != handle.orderToken) {
    return null;
  }
  final bounds = geometryPolicy.boundsFor(facts);

  return SpatialEntry(
    handle: handle,
    hitMembership: _hitMembership(handle, facts, bounds),
    paintMembership: SpatialMembership.fromBounds(
      handle: handle,
      boundsWorld: bounds.paintBoundsWorld,
      indexKind: SpatialIndexKind.paint,
    ),
  );
}

SpatialMembership _hitMembership(
  FrameElementHandle handle,
  FrameElementFacts facts,
  GeometryBounds bounds,
) {
  if (!facts.isVisible ||
      !facts.isSelectable ||
      facts.locationKind == FrameElementLocationKind.background) {
    return SpatialMembership.fromBounds(
      handle: handle,
      boundsWorld: Rect.zero,
      indexKind: SpatialIndexKind.hit,
    );
  }

  return SpatialMembership.fromBounds(
    handle: handle,
    boundsWorld: bounds.hitBoundsWorld,
    indexKind: SpatialIndexKind.hit,
  );
}
