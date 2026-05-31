import 'dart:ui';

import '../contracts/internal/frame_facts_port.dart';
import '../contracts/public/canvas_ids.dart';
import '../resources/resource_resolver_adapter.dart';
import '../resources/surface_resource_session.dart';
import 'captured_frame.dart';
import 'render_element_record.dart';

final class FrameAssetBindings {
  FrameAssetBindings({
    required Map<CanvasResourceId, ResourceImageResolveResult> images,
  }) : images = Map.unmodifiable(images);

  static final empty = FrameAssetBindings(images: const {});

  final Map<CanvasResourceId, ResourceImageResolveResult> images;
}

final class PaintAssetBindingService {
  const PaintAssetBindingService();

  FrameAssetBindings bind({
    required CapturedFrameSnapshot frame,
    required Iterable<RenderElementRecord> records,
    required SurfaceResourceSession session,
  }) {
    session.beginFrameResourcePass();
    final descriptors = {
      for (final descriptor in frame.resourceDescriptors)
        descriptor.id: descriptor,
    };
    final images = <CanvasResourceId, ResourceImageResolveResult>{};
    for (final record in records) {
      final resourceId = record.resourceId;
      if (resourceId == null || images.containsKey(resourceId)) {
        continue;
      }
      images[resourceId] = session.resolveImage(
        _requestFor(
          resourceId: resourceId,
          descriptor: descriptors[resourceId],
          fallbackResourceRevision: frame.revisions.resourceRevision,
          placeholderBounds: record.paintBoundsWorld,
        ),
      );
    }

    return FrameAssetBindings(images: images);
  }

  ResourceImageResolveRequest _requestFor({
    required CanvasResourceId resourceId,
    required FrameResourceDescriptorFacts? descriptor,
    required int fallbackResourceRevision,
    required Rect placeholderBounds,
  }) {
    if (descriptor == null) {
      return ResourceImageResolveRequest.missingDescriptor(
        resourceId: resourceId,
        resourceRevision: fallbackResourceRevision,
        placeholderBounds: placeholderBounds,
      );
    }

    return ResourceImageResolveRequest.descriptor(
      resourceId: descriptor.id,
      appKey: descriptor.appKey,
      mimeType: descriptor.mimeType,
      contentHash: descriptor.contentHash,
      byteLength: descriptor.byteLength,
      metadata: descriptor.metadata,
      resourceRevision: descriptor.resourceRevision,
      placeholderBounds: placeholderBounds,
    );
  }
}
