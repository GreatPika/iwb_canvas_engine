import 'dart:async';
import 'dart:collection';

import 'package:meta/meta.dart' show visibleForTesting;

import '../contracts/public/canvas_element.dart';
import '../contracts/public/canvas_ids.dart';
import '../contracts/public/canvas_resource.dart';
import '../store/resource_table.dart';
import 'resource_edit_policy.dart';

enum DraftResourceWorkKind {
  constructionDescriptorVisit,
  constructionElementVisit,
  descriptorRead,
  descriptorWrite,
  descriptorRemove,
  descriptorMaterialization,
  imageCountTransition,
  vectorCountTransition,
  referenceQuery,
  countEntryVisit,
}

final class DraftResourceWorkEvent {
  const DraftResourceWorkEvent(
    this.kind, {
    this.resourceId,
    this.imageCount,
    this.vectorCount,
  });

  final DraftResourceWorkKind kind;
  final CanvasResourceId? resourceId;
  final int? imageCount;
  final int? vectorCount;
}

final Object _draftResourceWorkZoneKey = Object();

/// Observes semantic resource-owner operations under asserts only.
@visibleForTesting
T observeDraftResourceWork<T>(
  void Function(DraftResourceWorkEvent event) sink,
  T Function() operation,
) {
  return runZoned(operation, zoneValues: {_draftResourceWorkZoneKey: sink});
}

/// Owns descriptor insertion order and exact split references for one Draft.
///
/// The insertion-ordered map is the only descriptor membership, lookup, and
/// output-order state. Count maps are derived reference facts, not a second
/// descriptor inventory.
// Descriptor order and its split counts must mutate together; splitting this
// owner would reintroduce synchronization at every element transition.
// ignore: number-of-methods, weighted-methods-per-class
final class DraftResources {
  DraftResources({
    required Iterable<CanvasResource> descriptors,
    required void Function(void Function(CanvasElement)) visitRows,
  }) {
    for (final descriptor in descriptors) {
      assert(
        _record(DraftResourceWorkKind.constructionDescriptorVisit),
        'draft resource work observation failed',
      );
      _descriptors[descriptor.id] = ResourceTable.copy(descriptor);
    }
    visitRows((row) {
      assert(
        _record(DraftResourceWorkKind.constructionElementVisit),
        'draft resource work observation failed',
      );
      _addReference(row);
    });
  }

  final Map<CanvasResourceId, CanvasResource> _descriptors = {};
  final _DraftResourceReferenceCounts _referenceCounts =
      _DraftResourceReferenceCounts();

  int get length => _descriptors.length;

  bool upsert(CanvasResource descriptor) {
    assert(
      _record(DraftResourceWorkKind.descriptorRead),
      'draft resource work observation failed',
    );
    final current = _descriptors[descriptor.id];
    if (current != null && hasSameResourceFacts(current, descriptor)) {
      return false;
    }
    assert(
      _record(DraftResourceWorkKind.descriptorWrite),
      'draft resource work observation failed',
    );
    _descriptors[descriptor.id] = ResourceTable.copy(descriptor);
    return true;
  }

  bool removeUnused(CanvasResourceId id) {
    assert(
      _record(DraftResourceWorkKind.descriptorRead),
      'draft resource work observation failed',
    );
    if (!_descriptors.containsKey(id) || isReferenced(id)) {
      return false;
    }
    assert(
      _record(DraftResourceWorkKind.descriptorRemove),
      'draft resource work observation failed',
    );
    _descriptors.remove(id);
    return true;
  }

  void addElement(CanvasElement element) => _addReference(element);

  void removeElement(CanvasElement element) => _removeReference(element);

  void replaceElement({
    required CanvasElement before,
    required CanvasElement after,
  }) {
    final beforeReference = _referenceOf(before);
    final afterReference = _referenceOf(after);
    if (_sameReference(beforeReference, afterReference)) {
      return;
    }
    if (beforeReference != null) {
      _adjustReference(beforeReference, -1);
    }
    if (afterReference != null) {
      _adjustReference(afterReference, 1);
    }
  }

  List<CanvasResourceId> removeAllUnused() {
    final removed = <CanvasResourceId>[];
    _descriptors.removeWhere((id, _) {
      if (isReferenced(id)) {
        return false;
      }
      assert(
        _record(DraftResourceWorkKind.descriptorRemove),
        'draft resource work observation failed',
      );
      removed.add(id);
      return true;
    });
    return List.unmodifiable(removed);
  }

  bool isReferenced(CanvasResourceId id) {
    final imageCount = _referenceCounts.imageCount(id);
    final vectorCount = _referenceCounts.vectorCount(id);
    assert(
      _record(
        DraftResourceWorkKind.referenceQuery,
        resourceId: id,
        imageCount: imageCount,
        vectorCount: vectorCount,
      ),
      'draft resource work observation failed',
    );
    return imageCount + vectorCount > 0;
  }

  List<CanvasResource> materialize() {
    assert(
      _record(DraftResourceWorkKind.descriptorMaterialization),
      'draft resource work observation failed',
    );
    return [
      for (final descriptor in _descriptors.values)
        ResourceTable.copy(descriptor),
    ];
  }

  void _addReference(CanvasElement element) {
    final reference = _referenceOf(element);
    if (reference != null) {
      _adjustReference(reference, 1);
    }
  }

  void _removeReference(CanvasElement element) {
    final reference = _referenceOf(element);
    if (reference != null) {
      _adjustReference(reference, -1);
    }
  }

  void _adjustReference(_DraftResourceReference reference, int delta) {
    _referenceCounts.adjust(reference, delta);
    assert(
      _record(
        reference.isImage
            ? DraftResourceWorkKind.imageCountTransition
            : DraftResourceWorkKind.vectorCountTransition,
        resourceId: reference.id,
        imageCount: _referenceCounts.imageCount(reference.id),
        vectorCount: _referenceCounts.vectorCount(reference.id),
      ),
      'draft resource work observation failed',
    );
  }

  static _DraftResourceReference? _referenceOf(CanvasElement element) {
    return switch (element) {
      CanvasImageElement(:final resourceId) => _DraftResourceReference(
        resourceId,
        isImage: true,
      ),
      CanvasVectorElement(:final resourceId) => _DraftResourceReference(
        resourceId,
        isImage: false,
      ),
      _ => null,
    };
  }

  static bool _sameReference(
    _DraftResourceReference? left,
    _DraftResourceReference? right,
  ) {
    return left?.id == right?.id && left?.isImage == right?.isImage;
  }

  static bool _record(
    DraftResourceWorkKind kind, {
    CanvasResourceId? resourceId,
    int? imageCount,
    int? vectorCount,
  }) {
    final sink = Zone.current[_draftResourceWorkZoneKey];
    if (sink is void Function(DraftResourceWorkEvent)) {
      sink(
        DraftResourceWorkEvent(
          kind,
          resourceId: resourceId,
          imageCount: imageCount,
          vectorCount: vectorCount,
        ),
      );
    }
    return true;
  }
}

final class _DraftResourceReference {
  const _DraftResourceReference(this.id, {required this.isImage});

  final CanvasResourceId id;
  final bool isImage;
}

/// Keeps split count maps private to direct reads and point transitions.
/// No enumeration or snapshot escapes this owner, so a mutation cannot clone
/// or scan global reference facts while deciding one descriptor.
final class _DraftResourceReferenceCounts {
  final _DraftResourceReferenceCountMap _images =
      _DraftResourceReferenceCountMap();
  final _DraftResourceReferenceCountMap _vectors =
      _DraftResourceReferenceCountMap();

  int imageCount(CanvasResourceId id) => _images[id] ?? 0;

  int vectorCount(CanvasResourceId id) => _vectors[id] ?? 0;

  void adjust(_DraftResourceReference reference, int delta) {
    final counts = reference.isImage ? _images : _vectors;
    final next = (counts[reference.id] ?? 0) + delta;
    if (next < 0) {
      throw StateError('Draft resource reference count became negative.');
    }
    if (next == 0) {
      counts.remove(reference.id);
    } else {
      counts[reference.id] = next;
    }
  }
}

/// Keeps count backing private while making actual count-map enumeration
/// observable in debug work evidence. Point reads and writes never enumerate.
final class _DraftResourceReferenceCountMap
    extends MapBase<CanvasResourceId, int> {
  final Map<CanvasResourceId, int> _backing = {};

  @override
  int? operator [](Object? key) => _backing[key];

  @override
  void operator []=(CanvasResourceId key, int value) {
    _backing[key] = value;
  }

  @override
  void clear() => _backing.clear();

  @override
  Iterable<CanvasResourceId> get keys => _observed(_backing.keys);

  @override
  int? remove(Object? key) => _backing.remove(key);

  @override
  Iterable<MapEntry<CanvasResourceId, int>> get entries sync* {
    for (final entry in _backing.entries) {
      assert(
        DraftResources._record(
          DraftResourceWorkKind.countEntryVisit,
          resourceId: entry.key,
        ),
        'draft resource work observation failed',
      );
      yield entry;
    }
  }

  @override
  void forEach(void Function(CanvasResourceId key, int value) action) {
    for (final entry in _backing.entries) {
      assert(
        DraftResources._record(
          DraftResourceWorkKind.countEntryVisit,
          resourceId: entry.key,
        ),
        'draft resource work observation failed',
      );
      action(entry.key, entry.value);
    }
  }

  Iterable<CanvasResourceId> _observed(
    Iterable<CanvasResourceId> entries,
  ) sync* {
    for (final id in entries) {
      assert(
        DraftResources._record(
          DraftResourceWorkKind.countEntryVisit,
          resourceId: id,
        ),
        'draft resource work observation failed',
      );
      yield id;
    }
  }
}
