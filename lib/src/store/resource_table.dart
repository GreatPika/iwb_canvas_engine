import '../contracts/public/canvas_errors.dart';
import '../contracts/public/canvas_ids.dart';
import '../contracts/public/canvas_metadata.dart';
import '../contracts/public/canvas_resource.dart';

final class ResourceTable {
  factory ResourceTable(
    Iterable<CanvasResource> resources, {
    required int resourceRevision,
  }) {
    final admittedIds = <String>{};
    final admittedResources = <CanvasResource>[];
    final descriptors = <CanvasResourceId, StoreResourceDescriptorFacts>{};

    for (final resource in resources) {
      if (!admittedIds.add(resource.id.value)) {
        throw CanvasDataException(
          code: CanvasDataErrorCode.duplicateResourceId,
          message: 'duplicate resource id.',
          path: 'resources.id',
        );
      }
      final admitted = copy(resource);
      admittedResources.add(admitted);
      final descriptor = descriptorFor(
        admitted,
        resourceRevision: resourceRevision,
      );
      if (descriptor != null) {
        descriptors[descriptor.id] = descriptor;
      }
    }

    return ResourceTable._(
      rows: List.unmodifiable(admittedResources),
      admittedIds: Set.unmodifiable(admittedIds),
      descriptors: Map.unmodifiable(descriptors),
    );
  }

  const ResourceTable._({
    required this.rows,
    required this.admittedIds,
    required this.descriptors,
  });

  final List<CanvasResource> rows;
  final Set<String> admittedIds;
  final Map<CanvasResourceId, StoreResourceDescriptorFacts> descriptors;

  static CanvasResource copy(CanvasResource resource) {
    return switch (resource) {
      CanvasImageResource() => CanvasImageResource(
        id: resource.id,
        source: resource.source,
        mimeType: resource.mimeType,
        contentHash: resource.contentHash,
        byteLength: resource.byteLength,
        metadata: resource.metadata,
      ),
    };
  }

  static StoreResourceDescriptorFacts? descriptorFor(
    CanvasResource resource, {
    required int resourceRevision,
  }) {
    if (resource is! CanvasImageResource ||
        resource.source is! CanvasAppKeyResourceSource) {
      return null;
    }

    return StoreResourceDescriptorFacts(
      id: resource.id,
      appKey: (resource.source as CanvasAppKeyResourceSource).key,
      mimeType: resource.mimeType,
      contentHash: resource.contentHash,
      byteLength: resource.byteLength,
      resourceRevision: resourceRevision,
      metadata: resource.metadata,
    );
  }
}

final class StoreResourceDescriptorFacts {
  const StoreResourceDescriptorFacts({
    required this.id,
    required this.appKey,
    required this.mimeType,
    required this.contentHash,
    required this.byteLength,
    required this.resourceRevision,
    required this.metadata,
  });

  final CanvasResourceId id;
  final String appKey;
  final String? mimeType;
  final String? contentHash;
  final int? byteLength;
  final int resourceRevision;
  final CanvasMetadata metadata;
}
