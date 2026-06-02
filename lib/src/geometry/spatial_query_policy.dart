import 'dart:ui';

import 'package:flutter/foundation.dart';

import 'geometry_policy.dart';

const int kCanvasMaxFallbackCandidates = 4096;
const double _tileBoundaryEpsilon = 1e-9;

enum SpatialIndexKind { hit, paint, context }

final class SpatialQueryWindow {
  const SpatialQueryWindow({
    required this.boundsWorld,
    required this.structuralRevision,
  });

  final Rect boundsWorld;
  final int structuralRevision;
}

int spatialTileCountFor(Rect boundsWorld) {
  if (!isFiniteRect(boundsWorld) || boundsWorld.isEmpty) {
    return 0;
  }
  final minColumn = _tileFor(boundsWorld.left);
  final maxColumn = _maxTileFor(boundsWorld.right);
  final minRow = _tileFor(boundsWorld.top);
  final maxRow = _maxTileFor(boundsWorld.bottom);

  return (maxColumn - minColumn + 1) * (maxRow - minRow + 1);
}

Iterable<SpatialTileCoord> spatialTilesFor(Rect boundsWorld) sync* {
  if (!isFiniteRect(boundsWorld) || boundsWorld.isEmpty) {
    return;
  }
  final minColumn = _tileFor(boundsWorld.left);
  final maxColumn = _maxTileFor(boundsWorld.right);
  final minRow = _tileFor(boundsWorld.top);
  final maxRow = _maxTileFor(boundsWorld.bottom);
  for (var row = minRow; row <= maxRow; row += 1) {
    for (var column = minColumn; column <= maxColumn; column += 1) {
      yield SpatialTileCoord(column: column, row: row);
    }
  }
}

int _tileFor(double coordinate) {
  return (coordinate / kCanvasSpatialCellSize).floor();
}

int _maxTileFor(double coordinate) {
  return ((coordinate - _tileBoundaryEpsilon) / kCanvasSpatialCellSize).floor();
}

@immutable
final class SpatialTileCoord implements Comparable<SpatialTileCoord> {
  const SpatialTileCoord({required this.column, required this.row});

  final int column;
  final int row;

  @override
  int compareTo(SpatialTileCoord other) {
    final rowOrder = row.compareTo(other.row);
    if (rowOrder != 0) {
      return rowOrder;
    }

    return column.compareTo(other.column);
  }

  @override
  bool operator ==(Object other) {
    return other is SpatialTileCoord &&
        other.column == column &&
        other.row == row;
  }

  @override
  int get hashCode => Object.hash(column, row);
}
