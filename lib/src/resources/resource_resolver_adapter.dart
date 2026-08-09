import 'dart:ui' as ui;

import '../contracts/public/canvas_ids.dart';
import '../contracts/public/canvas_resource.dart';

const int kMaxSyncResourceResolverCallsPerFrame = 128;

final class ResourceAssetResolveRequest {
  ResourceAssetResolveRequest.descriptor({
    required CanvasResource resource,
    required this.resourceRevision,
    required this.placeholderBounds,
  }) : id = resource.id,
       resource = resource;

  const ResourceAssetResolveRequest.missingDescriptor({
    required CanvasResourceId resourceId,
    required this.resourceRevision,
    required this.placeholderBounds,
  }) : id = resourceId,
       resource = null;

  final CanvasResourceId id;
  final CanvasResource? resource;
  final int resourceRevision;
  final ui.Rect placeholderBounds;

  bool get hasDescriptor => resource != null;
}

sealed class ResourceAsset {
  const ResourceAsset();

  int get cacheWeightBytes;
}

final class ImageResourceAsset extends ResourceAsset {
  const ImageResourceAsset(this.image);

  final ui.Image image;

  @override
  int get cacheWeightBytes => image.width * image.height * 4;
}

sealed class ResourceAssetResolveResult {
  const ResourceAssetResolveResult({required this.placeholderBounds});

  final ui.Rect placeholderBounds;
}

final class ResolvedResourceAsset extends ResourceAssetResolveResult {
  const ResolvedResourceAsset({
    required this.asset,
    required super.placeholderBounds,
  });

  final ResourceAsset asset;
}

sealed class ResourceAssetPlaceholderResult extends ResourceAssetResolveResult {
  const ResourceAssetPlaceholderResult({required super.placeholderBounds});
}

final class MissingDescriptorResourceAssetPlaceholder
    extends ResourceAssetPlaceholderResult {
  const MissingDescriptorResourceAssetPlaceholder({
    required super.placeholderBounds,
  });
}

final class NoResolverResourceAssetPlaceholder
    extends ResourceAssetPlaceholderResult {
  const NoResolverResourceAssetPlaceholder({required super.placeholderBounds});
}

final class NullResourceAssetPlaceholder
    extends ResourceAssetPlaceholderResult {
  const NullResourceAssetPlaceholder({required super.placeholderBounds});
}

final class ResolverExceptionResourceAssetPlaceholder
    extends ResourceAssetPlaceholderResult {
  const ResolverExceptionResourceAssetPlaceholder({
    required super.placeholderBounds,
  });
}

final class BudgetExceededResourceAssetPlaceholder
    extends ResourceAssetPlaceholderResult {
  const BudgetExceededResourceAssetPlaceholder({
    required super.placeholderBounds,
  });
}
