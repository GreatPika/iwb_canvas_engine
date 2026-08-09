import 'dart:collection';

import '../contracts/internal/schema_v1_import_events.dart';
import '../contracts/public/canvas_errors.dart';
import '../contracts/public/canvas_ids.dart';
import '../contracts/public/canvas_metadata.dart';
import '../contracts/public/canvas_resource.dart';

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
    Iterable<SchemaV1ResourceImportEvent> resources, {
    required int resourceRevision,
  }) {
    final descriptors = <CanvasResourceId, StoreResourceDescriptorFacts>{};
    for (final resource in resources) {
      _admitDescriptor(
        descriptors,
        _descriptorForSchemaV1Import(
          resource,
          resourceRevision: resourceRevision,
        ),
      );
    }

    return ResourceTable._(descriptors: Map.unmodifiable(descriptors));
  }

  const ResourceTable._({required this.descriptors});
  ResourceTable._owned(Map<CanvasResourceId, StoreResourceDescriptorFacts> rows)
    : descriptors = UnmodifiableMapView(rows);

  final Map<CanvasResourceId, StoreResourceDescriptorFacts> descriptors;

  int get count => descriptors.length;
  Set<String> get admittedIds {
    return {for (final id in descriptors.keys) id.value};
  }

  List<CanvasResource> projectResources() {
    return List.unmodifiable(descriptors.values.map(_resourceForDescriptor));
  }

  CanvasResource? projectResource(CanvasResourceId id) {
    final descriptor = descriptors[id];
    if (descriptor == null) {
      return null;
    }

    return _resourceForDescriptor(descriptor);
  }

  bool contains(CanvasResourceId id) => descriptors.containsKey(id);

  ResourceTable withAcceptedResourceRevisions(
    ResourceTable previous, {
    required int acceptedRevision,
  }) {
    if (descriptors.isEmpty ||
        descriptors.values.every(
          (descriptor) =>
              descriptor.resourceRevision ==
              _acceptedResourceRevisionFor(
                descriptor,
                previous: previous,
                acceptedRevision: acceptedRevision,
              ),
        )) {
      return this;
    }
    final nextDescriptors = <CanvasResourceId, StoreResourceDescriptorFacts>{};
    for (final descriptor in descriptors.values) {
      final revision = _acceptedResourceRevisionFor(
        descriptor,
        previous: previous,
        acceptedRevision: acceptedRevision,
      );
      nextDescriptors[descriptor.id] = descriptor.withResourceRevision(
        revision,
      );
    }

    return ResourceTable._(descriptors: Map.unmodifiable(nextDescriptors));
  }

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
      CanvasVectorResource() => CanvasVectorResource(
        id: resource.id,
        source: resource.source,
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
    if (resource.source is! CanvasAppKeyResourceSource) {
      return null;
    }

    final appKey = (resource.source as CanvasAppKeyResourceSource).key;
    return switch (resource) {
      CanvasImageResource() => StoreImageResourceDescriptorFacts(
        id: resource.id,
        appKey: appKey,
        mimeType: resource.mimeType,
        contentHash: resource.contentHash,
        byteLength: resource.byteLength,
        resourceRevision: resourceRevision,
        metadata: resource.metadata,
      ),
      CanvasVectorResource() => StoreVectorResourceDescriptorFacts(
        id: resource.id,
        appKey: appKey,
        contentHash: resource.contentHash,
        byteLength: resource.byteLength,
        resourceRevision: resourceRevision,
        metadata: resource.metadata,
      ),
    };
  }
}

StoreResourceDescriptorFacts _descriptorForSchemaV1Import(
  SchemaV1ResourceImportEvent resource, {
  required int resourceRevision,
}) {
  return switch (resource) {
    SchemaV1ImageResourceImportEvent() => StoreImageResourceDescriptorFacts(
      id: resource.id,
      appKey: resource.appKey,
      mimeType: resource.mimeType,
      contentHash: resource.contentHash,
      byteLength: resource.byteLength,
      resourceRevision: resourceRevision,
      metadata: resource.metadata,
    ),
    SchemaV1VectorResourceImportEvent() => StoreVectorResourceDescriptorFacts(
      id: resource.id,
      appKey: resource.appKey,
      contentHash: resource.contentHash,
      byteLength: resource.byteLength,
      resourceRevision: resourceRevision,
      metadata: resource.metadata,
    ),
  };
}

int _acceptedResourceRevisionFor(
  StoreResourceDescriptorFacts descriptor, {
  required ResourceTable previous,
  required int acceptedRevision,
}) {
  final previousDescriptor = previous.descriptors[descriptor.id];
  if (previousDescriptor != null &&
      descriptor.hasSameResourceFacts(previousDescriptor)) {
    return previousDescriptor.resourceRevision;
  }

  return acceptedRevision;
}

final class StoreResourceDescriptorImportBuilder {
  Map<CanvasResourceId, SchemaV1ResourceImportEvent>? _descriptors = {};

  void addSchemaV1Import(SchemaV1ResourceImportEvent event) {
    final descriptors = _liveDescriptors;
    _admitPendingDescriptor(
      descriptors,
      event,
    );
  }

  ResourceTable consume({required int resourceRevision}) {
    final pending = _liveDescriptors;
    _descriptors = null;
    final descriptors = <CanvasResourceId, StoreResourceDescriptorFacts>{};
    for (final descriptor in pending.values) {
      descriptors[descriptor.id] = _descriptorForSchemaV1Import(
        descriptor,
        resourceRevision: resourceRevision,
      );
    }

    return ResourceTable._owned(descriptors);
  }

  Map<CanvasResourceId, SchemaV1ResourceImportEvent> get _liveDescriptors {
    final descriptors = _descriptors;
    if (descriptors == null) {
      throw StateError('StoreResourceDescriptorImportBuilder was consumed.');
    }

    return descriptors;
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

void _admitPendingDescriptor(
  Map<CanvasResourceId, SchemaV1ResourceImportEvent> descriptors,
  SchemaV1ResourceImportEvent descriptor,
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

CanvasResource _resourceForDescriptor(StoreResourceDescriptorFacts facts) {
  return switch (facts) {
    StoreImageResourceDescriptorFacts() => CanvasImageResource(
      id: facts.id,
      source: CanvasResourceSource.appKey(facts.appKey),
      mimeType: facts.mimeType,
      contentHash: facts.contentHash,
      byteLength: facts.byteLength,
      metadata: facts.metadata,
    ),
    StoreVectorResourceDescriptorFacts() => CanvasVectorResource(
      id: facts.id,
      source: CanvasResourceSource.appKey(facts.appKey),
      contentHash: facts.contentHash,
      byteLength: facts.byteLength,
      metadata: facts.metadata,
    ),
  };
}

sealed class StoreResourceDescriptorFacts {
  const StoreResourceDescriptorFacts({
    required this.id,
    required this.appKey,
    required this.contentHash,
    required this.byteLength,
    required this.resourceRevision,
    required this.metadata,
  });

  final CanvasResourceId id;
  final String appKey;
  final String? contentHash;
  final int? byteLength;
  final int resourceRevision;
  final CanvasMetadata metadata;

  StoreResourceDescriptorFacts withResourceRevision(int revision);

  bool hasSameResourceFacts(StoreResourceDescriptorFacts other);
}

final class StoreImageResourceDescriptorFacts
    extends StoreResourceDescriptorFacts {
  const StoreImageResourceDescriptorFacts({
    required super.id,
    required super.appKey,
    required this.mimeType,
    required super.contentHash,
    required super.byteLength,
    required super.resourceRevision,
    required super.metadata,
  });

  final String? mimeType;

  @override
  StoreImageResourceDescriptorFacts withResourceRevision(int revision) {
    if (resourceRevision == revision) {
      return this;
    }

    return StoreImageResourceDescriptorFacts(
      id: id,
      appKey: appKey,
      mimeType: mimeType,
      contentHash: contentHash,
      byteLength: byteLength,
      resourceRevision: revision,
      metadata: metadata,
    );
  }

  @override
  bool hasSameResourceFacts(StoreResourceDescriptorFacts other) {
    return other is StoreImageResourceDescriptorFacts &&
        id == other.id &&
        appKey == other.appKey &&
        mimeType == other.mimeType &&
        contentHash == other.contentHash &&
        byteLength == other.byteLength &&
        metadata == other.metadata;
  }
}

final class StoreVectorResourceDescriptorFacts
    extends StoreResourceDescriptorFacts {
  const StoreVectorResourceDescriptorFacts({
    required super.id,
    required super.appKey,
    required super.contentHash,
    required super.byteLength,
    required super.resourceRevision,
    required super.metadata,
  });

  @override
  StoreVectorResourceDescriptorFacts withResourceRevision(int revision) {
    if (resourceRevision == revision) {
      return this;
    }

    return StoreVectorResourceDescriptorFacts(
      id: id,
      appKey: appKey,
      contentHash: contentHash,
      byteLength: byteLength,
      resourceRevision: revision,
      metadata: metadata,
    );
  }

  @override
  bool hasSameResourceFacts(StoreResourceDescriptorFacts other) {
    return other is StoreVectorResourceDescriptorFacts &&
        id == other.id &&
        appKey == other.appKey &&
        contentHash == other.contentHash &&
        byteLength == other.byteLength &&
        metadata == other.metadata;
  }
}
