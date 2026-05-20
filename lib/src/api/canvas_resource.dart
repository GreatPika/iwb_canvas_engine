import 'dart:ui' as ui;

import 'canvas_contract_limits.dart';
import 'canvas_document.dart';
import 'canvas_errors.dart';
import 'canvas_ids.dart';
import 'canvas_value_validators.dart';

sealed class CanvasResource {
  CanvasResource({
    required this.id,
    required this.source,
    this.contentHash,
    this.byteLength,
    this.metadata = const CanvasMetadata.empty(),
  }) {
    final byteLength = this.byteLength;
    if (byteLength != null) {
      validateNonNegativeInt(byteLength, path: 'resource.byteLength');
      if (byteLength > canvasMaxRawJsonLength) {
        throw const CanvasDataException(
          code: CanvasDataErrorCode.fieldMustBeInRange,
          message: 'resource.byteLength exceeds the maximum length.',
          path: 'resource.byteLength',
          details: {'max': canvasMaxRawJsonLength},
        );
      }
    }
    validateOptionalBoundedString(
      contentHash,
      path: 'resource.contentHash',
      maxLength: canvasMaxResourceContentHashLength,
    );
  }

  final CanvasResourceId id;
  final CanvasResourceSource source;
  final String? contentHash;
  final int? byteLength;
  final CanvasMetadata metadata;
}

final class CanvasImageResource extends CanvasResource {
  CanvasImageResource({
    required super.id,
    required super.source,
    this.mimeType,
    super.contentHash,
    super.byteLength,
    super.metadata,
  }) {
    validateOptionalBoundedString(
      mimeType,
      path: 'resource.mimeType',
      maxLength: canvasMaxResourceMimeTypeLength,
    );
  }

  final String? mimeType;
}

sealed class CanvasResourceSource {
  const CanvasResourceSource();
  factory CanvasResourceSource.appKey(String key) = CanvasAppKeyResourceSource;
}

final class CanvasAppKeyResourceSource extends CanvasResourceSource {
  factory CanvasAppKeyResourceSource(String key) {
    return CanvasAppKeyResourceSource._(
      validateCanvasIdValue(
        key,
        path: 'resource.source.appKey',
        maxLength: canvasMaxResourceAppKeyLength,
      ),
    );
  }

  const CanvasAppKeyResourceSource._(this.key);
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
