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

final class StoreResourceDescriptorImportBuilder {
  Map<CanvasResourceId, _PendingStoreResourceDescriptor>? _descriptors = {};
  final Set<String> _admittedIds = {};
  late final Set<String> _admittedIdsView = UnmodifiableSetView(_admittedIds);

  Set<String> get admittedIds {
    _ensureNotConsumed();

    return _admittedIdsView;
  }

  void addSchemaV1Import(SchemaV1ImageResourceImportEvent event) {
    final descriptors = _liveDescriptors;
    _admitPendingDescriptor(
      descriptors,
      _PendingStoreResourceDescriptor(
        id: event.id,
        appKey: event.appKey,
        mimeType: event.mimeType,
        contentHash: event.contentHash,
        byteLength: event.byteLength,
        metadata: event.metadata,
      ),
    );
    _admittedIds.add(event.id.value);
  }

  ResourceTable consume({required int resourceRevision}) {
    final pending = _liveDescriptors;
    _descriptors = null;
    final descriptors = <CanvasResourceId, StoreResourceDescriptorFacts>{};
    for (final descriptor in pending.values) {
      descriptors[descriptor.id] = descriptor.toFacts(
        resourceRevision: resourceRevision,
      );
    }

    return ResourceTable._owned(descriptors);
  }

  Map<CanvasResourceId, _PendingStoreResourceDescriptor> get _liveDescriptors {
    final descriptors = _descriptors;
    if (descriptors == null) {
      throw StateError('StoreResourceDescriptorImportBuilder was consumed.');
    }

    return descriptors;
  }

  void _ensureNotConsumed() {
    _liveDescriptors;
  }
}

final class _PendingStoreResourceDescriptor {
  const _PendingStoreResourceDescriptor({
    required this.id,
    required this.appKey,
    required this.mimeType,
    required this.contentHash,
    required this.byteLength,
    required this.metadata,
  });

  final CanvasResourceId id;
  final String appKey;
  final String? mimeType;
  final String? contentHash;
  final int? byteLength;
  final CanvasMetadata metadata;

  StoreResourceDescriptorFacts toFacts({required int resourceRevision}) {
    return StoreResourceDescriptorFacts(
      id: id,
      appKey: appKey,
      mimeType: mimeType,
      contentHash: contentHash,
      byteLength: byteLength,
      resourceRevision: resourceRevision,
      metadata: metadata,
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

void _admitPendingDescriptor(
  Map<CanvasResourceId, _PendingStoreResourceDescriptor> descriptors,
  _PendingStoreResourceDescriptor descriptor,
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
