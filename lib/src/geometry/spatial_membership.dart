import 'dart:ui';

import '../contracts/internal/frame_facts_port.dart';
import '../contracts/public/canvas_ids.dart';
import 'geometry_policy.dart';
import 'spatial_query_policy.dart';

final class SpatialMembership {
  SpatialMembership._({
    required this.handle,
    required this.boundsWorld,
    required this.indexKind,
    required this.tiles,
    required this.isOutlier,
  });

  factory SpatialMembership.fromBounds({
    required FrameElementHandle handle,
    required Rect boundsWorld,
    required SpatialIndexKind indexKind,
  }) {
    final safeBounds = sanitizeFiniteRect(boundsWorld);
    if (safeBounds == Rect.zero || safeBounds.isEmpty) {
      return SpatialMembership._(
        handle: handle,
        boundsWorld: Rect.zero,
        indexKind: indexKind,
        tiles: const {},
        isOutlier: false,
      );
    }
    if (spatialTileCountFor(safeBounds) > kCanvasMaxCellsPerElement) {
      return SpatialMembership._(
        handle: handle,
        boundsWorld: safeBounds,
        indexKind: indexKind,
        tiles: const {},
        isOutlier: true,
      );
    }

    return SpatialMembership._(
      handle: handle,
      boundsWorld: safeBounds,
      indexKind: indexKind,
      tiles: Set.unmodifiable(spatialTilesFor(safeBounds)),
      isOutlier: false,
    );
  }

  CanvasElementId get id => handle.id;

  final FrameElementHandle handle;
  final Rect boundsWorld;
  final SpatialIndexKind indexKind;
  final Set<SpatialTileCoord> tiles;
  final bool isOutlier;
}
