import 'dart:ui' as ui;

import 'canvas_document.dart';
import 'canvas_ids.dart';

sealed class CanvasResource {
  const CanvasResource({
    required this.id,
    required this.source,
    this.contentHash,
    this.byteLength,
    this.metadata = const CanvasMetadata.empty(),
  });

  final CanvasResourceId id;
  final CanvasResourceSource source;
  final String? contentHash;
  final int? byteLength;
  final CanvasMetadata metadata;
}

final class CanvasImageResource extends CanvasResource {
  const CanvasImageResource({
    required super.id,
    required super.source,
    this.mimeType,
    super.contentHash,
    super.byteLength,
    super.metadata,
  });

  final String? mimeType;
}

sealed class CanvasResourceSource {
  const CanvasResourceSource();
  factory CanvasResourceSource.appKey(String key) = CanvasAppKeyResourceSource;
}

final class CanvasAppKeyResourceSource extends CanvasResourceSource {
  const CanvasAppKeyResourceSource(this.key);
  final String key;
}

abstract interface class CanvasResourceResolver {
  ui.Image? resolveImage(CanvasImageResource resource);
}

abstract interface class CanvasResourcePort {
  List<CanvasResource> get resources;
  CanvasResource? resourceById(CanvasResourceId id);
  void markResourceDirty(CanvasResourceId id);
  void markAllResourcesDirty();
}
