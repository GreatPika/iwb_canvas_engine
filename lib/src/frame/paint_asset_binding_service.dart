import 'dart:ui';

import '../contracts/internal/frame_facts_port.dart';
import '../contracts/public/canvas_ids.dart';
import '../contracts/public/canvas_prepared_vector.dart';
import '../contracts/public/canvas_resource.dart';
import '../resources/resource_resolver_adapter.dart';
import '../resources/surface_resource_session.dart';
import 'captured_frame.dart';
import 'render_element_record.dart';

final class FrameAssetBindings {
  FrameAssetBindings({required Map<CanvasResourceId, FrameAssetBinding> assets})
    : assets = Map.unmodifiable(assets);

  static final empty = FrameAssetBindings(assets: const {});

  final Map<CanvasResourceId, FrameAssetBinding> assets;

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

// Frame bindings retain only paint inputs. Resolver/cache result categories stay
// in resources, so painters have no dependency on the resource-session owner.
sealed class FrameAssetBinding {
  const FrameAssetBinding();
}

final class FrameImageAssetBinding extends FrameAssetBinding {
  const FrameImageAssetBinding(this.image);

  final Image image;
}

final class FrameVectorAssetBinding extends FrameAssetBinding {
  const FrameVectorAssetBinding(this.prepared);

  final CanvasPreparedVector prepared;
}

final class FrameAssetPlaceholderBinding extends FrameAssetBinding {
  const FrameAssetPlaceholderBinding();
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
    final assets = <CanvasResourceId, FrameAssetBinding>{};
    for (final record in records) {
      final resourceId = record.resourceId;
      if (resourceId == null || assets.containsKey(resourceId)) {
        continue;
      }
      final result = session.resolveResource(
        _requestFor(
          resourceId: resourceId,
          descriptor: descriptors[resourceId],
          fallbackResourceRevision: frame.revisions.resourceRevision,
          placeholderBounds: record.paintBoundsWorld,
        ),
      );
      assets[resourceId] = _bindingFor(result);
    }

    return FrameAssetBindings(assets: assets);
  }

  FrameAssetBinding _bindingFor(ResourceAssetResolveResult result) {
    return switch (result) {
      ResolvedResourceAsset(:final asset) => switch (asset) {
        ImageResourceAsset(:final image) => FrameImageAssetBinding(image),
        VectorResourceAsset(:final prepared) => FrameVectorAssetBinding(
          prepared,
        ),
      },
      ResourceAssetPlaceholderResult() => const FrameAssetPlaceholderBinding(),
    };
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
      FrameVectorResourceDescriptorFacts() =>
        ResourceAssetResolveRequest.descriptor(
          resource: CanvasVectorResource(
            id: descriptor.id,
            source: CanvasResourceSource.appKey(descriptor.appKey),
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
