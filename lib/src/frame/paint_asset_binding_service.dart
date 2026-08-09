import 'dart:ui';

import '../contracts/internal/frame_facts_port.dart';
import '../contracts/public/canvas_ids.dart';
import '../contracts/public/canvas_resource.dart';
import '../resources/resource_resolver_adapter.dart';
import '../resources/surface_resource_session.dart';
import 'captured_frame.dart';
import 'render_element_record.dart';

final class FrameAssetBindings {
  FrameAssetBindings({
    required Map<CanvasResourceId, ResourceAssetResolveResult> assets,
  }) : assets = Map.unmodifiable(assets);

  static final empty = FrameAssetBindings(assets: const {});

  final Map<CanvasResourceId, ResourceAssetResolveResult> assets;

  FrameAssetBindings withoutResource(CanvasResourceId id) {
    if (!assets.containsKey(id)) {
      return this;
    }

    return FrameAssetBindings(
      assets: {
        for (final entry in assets.entries)
          if (entry.key != id) entry.key: entry.value,
      },
    );
  }

  FrameAssetBindings withoutResources() {
    if (assets.isEmpty) {
      return this;
    }

    return empty;
  }
}

// This frame boundary deliberately joins captured descriptor facts with the
// session-owned typed asset result. Keeping that translation here prevents
// resolver/cache details from leaking into capture, planners, or painters.
// ignore: coupling-between-object-classes
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
    final assets = <CanvasResourceId, ResourceAssetResolveResult>{};
    for (final record in records) {
      final resourceId = record.resourceId;
      if (resourceId == null || assets.containsKey(resourceId)) {
        continue;
      }
      assets[resourceId] = session.resolveResource(
        _requestFor(
          resourceId: resourceId,
          descriptor: descriptors[resourceId],
          fallbackResourceRevision: frame.revisions.resourceRevision,
          placeholderBounds: record.paintBoundsWorld,
        ),
      );
    }

    return FrameAssetBindings(assets: assets);
  }

  ResourceAssetResolveRequest _requestFor({
    required CanvasResourceId resourceId,
    required FrameResourceDescriptorFacts? descriptor,
    required int fallbackResourceRevision,
    required Rect placeholderBounds,
  }) {
    if (descriptor == null) {
      return ResourceAssetResolveRequest.missingDescriptor(
        resourceId: resourceId,
        resourceRevision: fallbackResourceRevision,
        placeholderBounds: placeholderBounds,
      );
    }

    return switch (descriptor) {
      FrameImageResourceDescriptorFacts() =>
        ResourceAssetResolveRequest.descriptor(
          resource: CanvasImageResource(
            id: descriptor.id,
            source: CanvasResourceSource.appKey(descriptor.appKey),
            mimeType: descriptor.mimeType,
            contentHash: descriptor.contentHash,
            byteLength: descriptor.byteLength,
            metadata: descriptor.metadata,
          ),
          resourceRevision: descriptor.resourceRevision,
          placeholderBounds: placeholderBounds,
        ),
    };
  }
}
