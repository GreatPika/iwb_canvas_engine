import 'dart:ui' as ui;

import '../contracts/public/canvas_ids.dart';
import '../contracts/public/canvas_metadata.dart';
import '../contracts/public/canvas_resource.dart';

const int kMaxSyncResourceResolverCallsPerFrame = 128;

final class ResourceImageResolveRequest {
  ResourceImageResolveRequest.descriptor({
    required CanvasResourceId resourceId,
    required String appKey,
    required String? mimeType,
    required String? contentHash,
    required int? byteLength,
    required CanvasMetadata metadata,
    required this.resourceRevision,
    required this.placeholderBounds,
  }) : id = resourceId,
       appKey = appKey,
       mimeType = mimeType,
       contentHash = contentHash,
       byteLength = byteLength,
       metadata = metadata,
       imageResource = CanvasImageResource(
         id: resourceId,
         source: CanvasResourceSource.appKey(appKey),
         mimeType: mimeType,
         contentHash: contentHash,
         byteLength: byteLength,
         metadata: metadata,
       );

  const ResourceImageResolveRequest.missingDescriptor({
    required CanvasResourceId resourceId,
    required this.resourceRevision,
    required this.placeholderBounds,
  }) : id = resourceId,
       appKey = null,
       mimeType = null,
       contentHash = null,
       byteLength = null,
       metadata = const CanvasMetadata.empty(),
       imageResource = null;

  final CanvasResourceId id;
  final String? appKey;
  final String? mimeType;
  final String? contentHash;
  final int? byteLength;
  final CanvasMetadata metadata;
  final int resourceRevision;
  final ui.Rect placeholderBounds;
  final CanvasImageResource? imageResource;

  bool get hasDescriptor => imageResource != null;
}

sealed class ResourceImageResolveResult {
  const ResourceImageResolveResult({required this.placeholderBounds});

  final ui.Rect placeholderBounds;
}

final class ResolvedResourceImage extends ResourceImageResolveResult {
  const ResolvedResourceImage({
    required this.image,
    required super.placeholderBounds,
  });

  final ui.Image image;
}

sealed class ResourceImagePlaceholderResult extends ResourceImageResolveResult {
  const ResourceImagePlaceholderResult({required super.placeholderBounds});
}

final class MissingDescriptorResourceImagePlaceholder
    extends ResourceImagePlaceholderResult {
  const MissingDescriptorResourceImagePlaceholder({
    required super.placeholderBounds,
  });
}

final class NoResolverResourceImagePlaceholder
    extends ResourceImagePlaceholderResult {
  const NoResolverResourceImagePlaceholder({required super.placeholderBounds});
}

final class NullResourceImagePlaceholder
    extends ResourceImagePlaceholderResult {
  const NullResourceImagePlaceholder({required super.placeholderBounds});
}

final class ResolverExceptionResourceImagePlaceholder
    extends ResourceImagePlaceholderResult {
  const ResolverExceptionResourceImagePlaceholder({
    required super.placeholderBounds,
  });
}

final class BudgetExceededResourceImagePlaceholder
    extends ResourceImagePlaceholderResult {
  const BudgetExceededResourceImagePlaceholder({
    required super.placeholderBounds,
  });
}
