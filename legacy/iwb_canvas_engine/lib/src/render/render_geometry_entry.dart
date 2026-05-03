import 'dart:ui';

class GeometryEntry {
  const GeometryEntry({
    required this.localBounds,
    required this.worldBounds,
    this.localPath,
  });

  final Rect localBounds;
  final Rect worldBounds;
  final Path? localPath;
}
