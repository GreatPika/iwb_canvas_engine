import '../contracts/public/canvas_errors.dart';
import '../contracts/public/canvas_ids.dart';
import '../contracts/public/canvas_metadata.dart';
import '../contracts/public/canvas_resource.dart';
import '../contracts/internal/schema_v1_import_events.dart';

// ResourceTable owns descriptor admission, mutation, and public projection for
// one table; splitting these methods would duplicate descriptor invariants.
// ignore: number-of-methods
final class ResourceTable {
  const ResourceTable.empty() : descriptors = const {};

  factory ResourceTable(
    Iterable<CanvasResource> resources, {
    required int resourceRevision,
  }) {
    final descriptors = <CanvasResourceId, StoreResourceDescriptorFacts>{};

    for (final resource in resources) {
      final descriptor = descriptorFor(
        resource,
        resourceRevision: resourceRevision,
      );
      if (descriptor != null) {
        _admitDescriptor(descriptors, descriptor);
      }
    }

    return ResourceTable._(descriptors: Map.unmodifiable(descriptors));
  }

  factory ResourceTable.fromSchemaV1Import(
    Iterable<SchemaV1ImageResourceImportEvent> resources, {
    required int resourceRevision,
  }) {
    final descriptors = <CanvasResourceId, StoreResourceDescriptorFacts>{};
    for (final resource in resources) {
      _admitDescriptor(
        descriptors,
        StoreResourceDescriptorFacts(
          id: resource.id,
          appKey: resource.appKey,
          mimeType: resource.mimeType,
          contentHash: resource.contentHash,
          byteLength: resource.byteLength,
          resourceRevision: resourceRevision,
          metadata: resource.metadata,
        ),
      );
    }

    return ResourceTable._(descriptors: Map.unmodifiable(descriptors));
  }

  const ResourceTable._({required this.descriptors});

  final Map<CanvasResourceId, StoreResourceDescriptorFacts> descriptors;

  int get count => descriptors.length;
  Set<String> get admittedIds {
    return {for (final id in descriptors.keys) id.value};
  }

  List<CanvasResource> projectResources() {
    return List.unmodifiable(descriptors.values.map(_resourceForDescriptor));
  }

  bool contains(CanvasResourceId id) => admittedIds.contains(id.value);

  ResourceTable upsert(CanvasResource resource, {required int revision}) {
    final descriptor = descriptorFor(resource, resourceRevision: revision);
    if (descriptor == null) {
      return this;
    }
    final nextDescriptors =
        Map<CanvasResourceId, StoreResourceDescriptorFacts>.of(descriptors);
    nextDescriptors[descriptor.id] = descriptor;

    return ResourceTable._(descriptors: Map.unmodifiable(nextDescriptors));
  }

  ResourceTable remove(CanvasResourceId id) {
    final nextDescriptors =
        Map<CanvasResourceId, StoreResourceDescriptorFacts>.of(descriptors)
          ..remove(id);

    return ResourceTable._(descriptors: Map.unmodifiable(nextDescriptors));
  }

  ResourceTable clear() {
    return const ResourceTable._(descriptors: {});
  }

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

void _admitDescriptor(
  Map<CanvasResourceId, StoreResourceDescriptorFacts> descriptors,
  StoreResourceDescriptorFacts descriptor,
) {
  if (descriptors.containsKey(descriptor.id)) {
    throw CanvasDataException(
      code: CanvasDataErrorCode.duplicateResourceId,
      message: 'duplicate resource id.',
      path: 'resources.id',
    );
  }
  descriptors[descriptor.id] = descriptor;
}

CanvasImageResource _resourceForDescriptor(StoreResourceDescriptorFacts facts) {
  return CanvasImageResource(
    id: facts.id,
    source: CanvasResourceSource.appKey(facts.appKey),
    mimeType: facts.mimeType,
    contentHash: facts.contentHash,
    byteLength: facts.byteLength,
    metadata: facts.metadata,
  );
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
