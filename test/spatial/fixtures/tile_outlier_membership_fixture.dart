import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/src/contracts/internal/frame_facts_port.dart';
import 'package:iwb_canvas_engine/src/contracts/public/canvas_ids.dart';
import 'package:iwb_canvas_engine/src/geometry/geometry_policy.dart';
import 'package:iwb_canvas_engine/src/geometry/outlier_index.dart';
import 'package:iwb_canvas_engine/src/geometry/spatial_membership.dart';
import 'package:iwb_canvas_engine/src/geometry/spatial_query_policy.dart';
import 'package:iwb_canvas_engine/src/geometry/tile_index.dart';

void main() {
  _testBoundaryAlignedTiles();
  _testOutlierMembership();
  _testOrdinaryMembership();
}

void _testBoundaryAlignedTiles() {
  test('tile membership uses half-open right and bottom bounds', () {
    final oneCell = SpatialMembership.fromBounds(
      handle: _handle('one-cell', 1),
      boundsWorld: const Rect.fromLTRB(
        0,
        0,
        kCanvasSpatialCellSize * 1.0,
        kCanvasSpatialCellSize * 1.0,
      ),
      indexKind: SpatialIndexKind.hit,
    );
    final maxTiled = SpatialMembership.fromBounds(
      handle: _handle('max-tiled', 1),
      boundsWorld: const Rect.fromLTWH(
        0,
        0,
        kCanvasSpatialCellSize * 32,
        kCanvasSpatialCellSize * 32,
      ),
      indexKind: SpatialIndexKind.hit,
    );

    expect(oneCell.tiles, {const SpatialTileCoord(column: 0, row: 0)});
    expect(maxTiled.tiles, hasLength(kCanvasMaxCellsPerElement));
    expect(maxTiled.isOutlier, isFalse);
  });
}

void _testOutlierMembership() {
  test('oversized elements are outlier-only', () {
    final membership = SpatialMembership.fromBounds(
      handle: _handle('oversized', 2),
      boundsWorld: const Rect.fromLTWH(
        0,
        0,
        kCanvasSpatialCellSize * 33,
        kCanvasSpatialCellSize * 33,
      ),
      indexKind: SpatialIndexKind.hit,
    );
    final tiles = TileIndex();
    final outliers = OutlierIndex();

    tiles.put(membership);
    outliers.put(membership);

    expect(membership.isOutlier, isTrue);
    expect(membership.tiles, isEmpty);
    expect(tiles.contains(CanvasElementId('oversized')), isFalse);
    expect(outliers.contains(CanvasElementId('oversized')), isTrue);
  });
}

void _testOrdinaryMembership() {
  test('ordinary elements are tile-only and not duplicated as outliers', () {
    final membership = SpatialMembership.fromBounds(
      handle: _handle('ordinary', 1),
      boundsWorld: const Rect.fromLTRB(0, 0, 100, 100),
      indexKind: SpatialIndexKind.paint,
    );
    final tiles = TileIndex();
    final outliers = OutlierIndex();

    tiles.put(membership);
    outliers.put(membership);

    expect(membership.isOutlier, isFalse);
    expect(membership.tiles, {const SpatialTileCoord(column: 0, row: 0)});
    expect(tiles.contains(CanvasElementId('ordinary')), isTrue);
    expect(outliers.contains(CanvasElementId('ordinary')), isFalse);
  });
}

FrameElementHandle _handle(String id, int orderToken) {
  return FrameElementHandle(
    id: CanvasElementId(id),
    structuralRevision: 1,
    generation: 0,
    orderToken: orderToken,
  );
}
