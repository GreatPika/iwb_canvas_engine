import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart' show immutable, visibleForTesting;

import '../contracts/internal/schema_v1_import_events.dart';
import '../contracts/public/canvas_errors.dart';
import '../contracts/public/canvas_ids.dart';
import '../contracts/public/canvas_metadata.dart';
import '../contracts/public/canvas_resource.dart';

@visibleForTesting
enum ResourceTableEnumerationEvent { open, entry, close }

@visibleForTesting
enum ResourceTableEditorWorkPhase { replay, finalization }

@visibleForTesting
enum ResourceTableEditorWorkKind {
  editorOpen,
  currentRead,
  currentWrite,
  currentRemove,
  normalizationRead,
  normalizationWrite,
  clearEntryVisit,
  materializationBaseEntryVisit,
  materializationBaseEntryCopy,
  freeze,
  immutablePublication,
  discard,
  finalIdentity,
  postClosureAccess,
}

// This owner-local event distinguishes the only authorized whole-table work
// from bounded current and normalization work without retaining telemetry.
@immutable
@visibleForTesting
final class ResourceTableSelectiveMutationEvent {
  const ResourceTableSelectiveMutationEvent({
    required this.phase,
    required this.kind,
    this.id,
    this.retainsBaseIdentity,
  });

  final ResourceTableEditorWorkPhase phase;
  final ResourceTableEditorWorkKind kind;
  final CanvasResourceId? id;
  final bool? retainsBaseIdentity;
}

// This immutable table owns the committed descriptor snapshot. Sparse working
// state is deliberately separate so it cannot become a second snapshot path.
// Keep construction, committed reads, projection, and materialized acceptance
// together: forwarding any of them elsewhere would split one snapshot contract
// without removing a responsibility from this immutable owner.
// ignore: number-of-methods
final class ResourceTable {
  const ResourceTable.empty() : descriptors = const {};

  factory ResourceTable(
    Iterable<CanvasResource> resources, {
    required int resourceRevision,
  }) {
    return ResourceTable._(
      descriptors: Map.unmodifiable(
        _ResourceDescriptorConversion.admitResources(
          resources,
          resourceRevision: resourceRevision,
        ),
      ),
    );
  }

  factory ResourceTable.fromSchemaV1Import(
    Iterable<SchemaV1ResourceImportEvent> resources, {
    required int resourceRevision,
  }) {
    return ResourceTable._(
      descriptors: Map.unmodifiable(
        _ResourceDescriptorConversion.admitSchemaResources(
          resources,
          resourceRevision: resourceRevision,
        ),
      ),
    );
  }

  const ResourceTable._({required this.descriptors});
  ResourceTable._owned(Map<CanvasResourceId, StoreResourceDescriptorFacts> rows)
    : descriptors = UnmodifiableMapView(rows);

  final Map<CanvasResourceId, StoreResourceDescriptorFacts> descriptors;

  int get count => descriptors.length;

  // Enumeration work is test-only and assert-gated, retaining neither facts
  // nor telemetry in production.
  @visibleForTesting
  static T observeEnumeration<T>(
    void Function(ResourceTableEnumerationEvent event) sink,
    T Function() operation,
  ) => _ResourceTableEnumeration.observe(sink, operation);

  // Draft mutation retains its established public copy helper; sparse work is
  // deliberately routed through ResourceTableEditor instead.
  static CanvasResource copy(CanvasResource resource) =>
      _ResourceDescriptorConversion.copyResource(resource);

  void enumerateResourceIds(void Function(String) accept) {
    _ResourceTableEnumeration.record(ResourceTableEnumerationEvent.open);
    try {
      for (final id in descriptors.keys) {
        _ResourceTableEnumeration.record(ResourceTableEnumerationEvent.entry);
        accept(id.value);
      }
    } finally {
      _ResourceTableEnumeration.record(ResourceTableEnumerationEvent.close);
    }
  }

  List<CanvasResource> projectResources() => List.unmodifiable(
    descriptors.values.map(_ResourceDescriptorConversion.resourceFor),
  );

  CanvasResource? projectResource(CanvasResourceId id) {
    final descriptor = descriptors[id];
    return descriptor == null
        ? null
        : _ResourceDescriptorConversion.resourceFor(descriptor);
  }

  bool contains(CanvasResourceId id) => descriptors.containsKey(id);

  ResourceTable withAcceptedResourceRevisions(
    ResourceTable previous, {
    required int acceptedRevision,
  }) => _ResourceTableAcceptance.withAcceptedResourceRevisions(
    current: this,
    previous: previous,
    acceptedRevision: acceptedRevision,
  );
}

final class _ResourceTableEnumeration {
  const _ResourceTableEnumeration._();

  static final Object _zoneKey = Object();

  static T observe<T>(
    void Function(ResourceTableEnumerationEvent event) sink,
    T Function() operation,
  ) => runZoned(operation, zoneValues: {_zoneKey: sink});

  static void record(ResourceTableEnumerationEvent event) {
    assert(() {
      final sink = Zone.current[_zoneKey];
      if (sink is void Function(ResourceTableEnumerationEvent)) {
        sink(event);
      }
      return true;
    }(), 'resource table enumeration observation failed');
  }
}

// The editor owns transaction lifetime only. Its descriptor working view keeps
// all mutable resource facts separate from the committed immutable table.
final class ResourceTableEditor {
  ResourceTableEditor._(this._base) {
    descriptors = ResourceTableWorkingDescriptors._(
      _base,
      checkOpen: _checkOpen,
      record: _record,
    );
    _record(ResourceTableEditorWorkKind.editorOpen);
  }

  final ResourceTable _base;
  late final ResourceTableWorkingDescriptors descriptors;
  var _isOpen = true;
  var _phase = ResourceTableEditorWorkPhase.replay;

  static T editSparse<T>(
    ResourceTable base,
    T Function(ResourceTableEditor editor) operation,
  ) {
    final editor = ResourceTableEditor._(base);
    try {
      return operation(editor);
    } finally {
      editor.discard();
    }
  }

  @visibleForTesting
  static T observeWork<T>(
    void Function(ResourceTableSelectiveMutationEvent event) sink,
    T Function() operation,
  ) => _ResourceTableEditorObservations.observe(sink, operation);

  void enterFinalization() {
    _checkOpen();
    _phase = ResourceTableEditorWorkPhase.finalization;
  }

  void normalizeFinalFacts({required int acceptedRevision}) {
    enterFinalization();
    _normalizeResourceDescriptorOverlay(
      descriptors._overlay,
      acceptedRevision: acceptedRevision,
      record: _record,
    );
  }

  ResourceTable freeze() {
    enterFinalization();
    _isOpen = false;
    return _freezeResourceTable(_base, descriptors._overlay, _record);
  }

  void discard() {
    if (!_isOpen) {
      return;
    }
    _isOpen = false;
    _record(
      ResourceTableEditorWorkKind.finalIdentity,
      retainsBaseIdentity: true,
    );
    _record(ResourceTableEditorWorkKind.discard);
  }

  void _checkOpen() {
    if (!_isOpen) {
      _closedAccess();
    }
  }

  Never _closedAccess() {
    _record(ResourceTableEditorWorkKind.postClosureAccess);
    throw StateError('ResourceTableEditor was already consumed.');
  }

  void _record(
    ResourceTableEditorWorkKind kind, {
    CanvasResourceId? id,
    bool? retainsBaseIdentity,
  }) => _ResourceTableEditorObservations.record(
    _phase,
    kind,
    id: id,
    retainsBaseIdentity: retainsBaseIdentity,
  );
}

typedef _ResourceEditorEventRecorder =
    void Function(
      ResourceTableEditorWorkKind kind, {
      CanvasResourceId? id,
      bool? retainsBaseIdentity,
    });

// This is the editor's exclusive descriptor authority during sparse replay and
// finalization. It deliberately has no immutable publication operation.
final class ResourceTableWorkingDescriptors {
  ResourceTableWorkingDescriptors._(
    ResourceTable base, {
    required void Function() checkOpen,
    required _ResourceEditorEventRecorder record,
  }) : _overlay = _ResourceDescriptorOverlay(base),
       _checkOpen = checkOpen,
       _record = record;

  final _ResourceDescriptorOverlay _overlay;
  final _ResourceClearInvalidation _clearInvalidation =
      _ResourceClearInvalidation();
  final void Function() _checkOpen;
  final _ResourceEditorEventRecorder _record;

  Set<CanvasResourceId> get changedIds {
    _checkOpen();
    return _overlay.changedIds;
  }

  StoreResourceDescriptorFacts? descriptor(CanvasResourceId id) {
    _checkOpen();
    _record(ResourceTableEditorWorkKind.currentRead, id: id);
    return _overlay.descriptor(id);
  }

  bool contains(CanvasResourceId id) => descriptor(id) != null;

  void upsert(CanvasResource resource, {required int resourceRevision}) {
    _checkOpen();
    final id = _overlay.upsert(resource, resourceRevision: resourceRevision);
    if (id == null) {
      return;
    }
    _clearInvalidation.markDescriptor(id);
    _record(ResourceTableEditorWorkKind.currentWrite, id: id);
  }

  bool remove(CanvasResourceId id) {
    _checkOpen();
    _record(ResourceTableEditorWorkKind.currentRead, id: id);
    final removed = _overlay.remove(id);
    if (removed) {
      _record(ResourceTableEditorWorkKind.currentRemove, id: id);
    }
    return removed;
  }

  void recordResourceReferenceTransition(CanvasResourceId? id) {
    _checkOpen();
    _clearInvalidation.markReference(id);
  }

  bool removeUnreferenced(bool Function(CanvasResourceId id) isReferenced) {
    _checkOpen();
    // Clear is the one authorized descriptor traversal. Snapshot its ordered
    // candidates before removals so tail tombstones cannot invalidate the pass.
    final ids = _clearInvalidation
        .candidates(_overlay, _record)
        .toList(growable: false);
    var removed = false;
    for (final id in ids) {
      if (contains(id) && !isReferenced(id)) {
        removed = remove(id) || removed;
      }
    }
    _clearInvalidation.completeClear();
    return removed;
  }

  bool hasSameFactsAsBase(Iterable<CanvasResourceId>? ids) {
    _checkOpen();
    return _overlay.hasSameFactsAsBase(ids);
  }
}

final class _ResourceDescriptorOverlay {
  _ResourceDescriptorOverlay(this._base) : _count = _base.count;

  final ResourceTable _base;
  final Map<CanvasResourceId, StoreResourceDescriptorFacts?> _overrides = {};
  final LinkedHashSet<CanvasResourceId> _tailIds = LinkedHashSet();
  int _count;

  int get count => _count;
  Set<CanvasResourceId> get changedIds => Set.unmodifiable(_overrides.keys);

  StoreResourceDescriptorFacts? descriptor(CanvasResourceId id) =>
      _overrides.containsKey(id) ? _overrides[id] : _base.descriptors[id];

  CanvasResourceId? upsert(
    CanvasResource resource, {
    required int resourceRevision,
  }) {
    final descriptor = _ResourceDescriptorConversion.descriptorFor(
      resource,
      resourceRevision: resourceRevision,
    );
    if (descriptor == null) {
      return null;
    }
    if (this.descriptor(descriptor.id) == null) {
      _count += 1;
      _tailIds.add(descriptor.id);
    }
    _overrides[descriptor.id] = descriptor;
    return descriptor.id;
  }

  bool remove(CanvasResourceId id) {
    if (descriptor(id) == null) {
      return false;
    }
    _count -= 1;
    _overrides[id] = null;
    _tailIds.remove(id);
    return true;
  }

  bool hasSameFactsAsBase(Iterable<CanvasResourceId>? ids) {
    if (_count != _base.count) {
      return false;
    }
    for (final id in ids ?? _overrides.keys) {
      final before = _base.descriptors[id];
      final after = descriptor(id);
      if (before == null || after == null) {
        if (before != after) {
          return false;
        }
      } else if (!after.hasSameResourceFacts(before)) {
        return false;
      }
    }
    return true;
  }

  Iterable<CanvasResourceId> orderedCurrentIds(
    void Function(ResourceTableEditorWorkKind kind, {CanvasResourceId? id})
    record,
  ) sync* {
    for (final id in _base.descriptors.keys) {
      record(ResourceTableEditorWorkKind.clearEntryVisit, id: id);
      if (descriptor(id) != null && !_tailIds.contains(id)) {
        yield id;
      }
    }
    for (final id in _tailIds) {
      record(ResourceTableEditorWorkKind.clearEntryVisit, id: id);
      if (descriptor(id) != null) {
        yield id;
      }
    }
  }
}

void _normalizeResourceDescriptorOverlay(
  _ResourceDescriptorOverlay overlay, {
  required int acceptedRevision,
  required _ResourceEditorEventRecorder record,
}) {
  for (final id in List<CanvasResourceId>.of(overlay._overrides.keys)) {
    record(ResourceTableEditorWorkKind.normalizationRead, id: id);
    final before = overlay._base.descriptors[id];
    final after = overlay.descriptor(id);
    if (before != null && after != null && after.hasSameResourceFacts(before)) {
      overlay._overrides.remove(id);
      overlay._tailIds.remove(id);
      record(ResourceTableEditorWorkKind.normalizationWrite, id: id);
    } else if (after != null && after.resourceRevision != acceptedRevision) {
      overlay._overrides[id] = after.withResourceRevision(acceptedRevision);
      record(ResourceTableEditorWorkKind.normalizationWrite, id: id);
    }
  }
}

final class _ResourceClearInvalidation {
  final LinkedHashSet<CanvasResourceId> _ids = LinkedHashSet();
  var _hasCleared = false;

  void markDescriptor(CanvasResourceId id) {
    if (_hasCleared) {
      _ids.add(id);
    }
  }

  void markReference(CanvasResourceId? id) {
    if (_hasCleared && id != null) {
      _ids.add(id);
    }
  }

  Iterable<CanvasResourceId> candidates(
    _ResourceDescriptorOverlay overlay,
    void Function(ResourceTableEditorWorkKind kind, {CanvasResourceId? id})
    record,
  ) sync* {
    if (!_hasCleared) {
      yield* overlay.orderedCurrentIds(record);
      return;
    }
    for (final id in _ids) {
      record(ResourceTableEditorWorkKind.clearEntryVisit, id: id);
      yield id;
    }
  }

  void completeClear() {
    _hasCleared = true;
    _ids.clear();
  }
}

ResourceTable _freezeResourceTable(
  ResourceTable base,
  _ResourceDescriptorOverlay overlay,
  _ResourceEditorEventRecorder record,
) {
  if (overlay.hasSameFactsAsBase(null)) {
    record(
      ResourceTableEditorWorkKind.finalIdentity,
      retainsBaseIdentity: true,
    );
    return base;
  }
  final table = _materializeResourceTable(overlay, record);
  record(ResourceTableEditorWorkKind.freeze);
  record(ResourceTableEditorWorkKind.immutablePublication);
  record(ResourceTableEditorWorkKind.finalIdentity, retainsBaseIdentity: false);
  return table;
}

ResourceTable _materializeResourceTable(
  _ResourceDescriptorOverlay overlay,
  _ResourceEditorEventRecorder record,
) {
  final rows = <CanvasResourceId, StoreResourceDescriptorFacts>{};
  for (final entry in overlay._base.descriptors.entries) {
    record(
      ResourceTableEditorWorkKind.materializationBaseEntryVisit,
      id: entry.key,
    );
    final current = overlay.descriptor(entry.key);
    if (current != null && !overlay._tailIds.contains(entry.key)) {
      rows[entry.key] = current;
      record(
        ResourceTableEditorWorkKind.materializationBaseEntryCopy,
        id: entry.key,
      );
    }
  }
  for (final id in overlay._tailIds) {
    final current = overlay.descriptor(id);
    if (current != null) {
      rows[id] = current;
    }
  }
  return ResourceTable._owned(rows);
}

final class _ResourceTableEditorObservations {
  const _ResourceTableEditorObservations._();

  static final Object _zoneKey = Object();

  static T observe<T>(
    void Function(ResourceTableSelectiveMutationEvent event) sink,
    T Function() operation,
  ) => runZoned(operation, zoneValues: {_zoneKey: sink});

  static void record(
    ResourceTableEditorWorkPhase phase,
    ResourceTableEditorWorkKind kind, {
    CanvasResourceId? id,
    bool? retainsBaseIdentity,
  }) {
    assert(() {
      final sink = Zone.current[_zoneKey];
      if (sink is void Function(ResourceTableSelectiveMutationEvent)) {
        sink(
          ResourceTableSelectiveMutationEvent(
            phase: phase,
            kind: kind,
            id: id,
            retainsBaseIdentity: retainsBaseIdentity,
          ),
        );
      }
      return true;
    }(), 'resource table editor observation failed');
  }
}

final class _ResourceTableAcceptance {
  const _ResourceTableAcceptance._();
  static ResourceTable withAcceptedResourceRevisions({
    required ResourceTable current,
    required ResourceTable previous,
    required int acceptedRevision,
  }) {
    if (current.descriptors.isEmpty ||
        current.descriptors.values.every(
          (descriptor) =>
              descriptor.resourceRevision ==
              _acceptedResourceRevisionFor(
                descriptor,
                previous: previous,
                acceptedRevision: acceptedRevision,
              ),
        )) {
      return current;
    }
    final normalized = <CanvasResourceId, StoreResourceDescriptorFacts>{};
    for (final descriptor in current.descriptors.values) {
      normalized[descriptor.id] = descriptor.withResourceRevision(
        _acceptedResourceRevisionFor(
          descriptor,
          previous: previous,
          acceptedRevision: acceptedRevision,
        ),
      );
    }
    return ResourceTable._(descriptors: Map.unmodifiable(normalized));
  }
}

final class _ResourceDescriptorConversion {
  const _ResourceDescriptorConversion._();
  static Map<CanvasResourceId, StoreResourceDescriptorFacts> admitResources(
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
    return descriptors;
  }

  static Map<CanvasResourceId, StoreResourceDescriptorFacts>
  admitSchemaResources(
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
    return descriptors;
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

  static CanvasResource resourceFor(StoreResourceDescriptorFacts facts) {
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

  static CanvasResource copyResource(CanvasResource resource) {
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
}

StoreResourceDescriptorFacts _descriptorForSchemaV1Import(
  SchemaV1ResourceImportEvent resource, {
  required int resourceRevision,
}) => switch (resource) {
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

int _acceptedResourceRevisionFor(
  StoreResourceDescriptorFacts descriptor, {
  required ResourceTable previous,
  required int acceptedRevision,
}) {
  final before = previous.descriptors[descriptor.id];
  return before != null && descriptor.hasSameResourceFacts(before)
      ? before.resourceRevision
      : acceptedRevision;
}

final class StoreResourceDescriptorImportBuilder {
  Map<CanvasResourceId, SchemaV1ResourceImportEvent>? _descriptors = {};

  void addSchemaV1Import(SchemaV1ResourceImportEvent event) {
    final descriptors = _liveDescriptors;
    _admitPendingDescriptor(descriptors, event);
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
