import 'dart:async';
import 'dart:collection';

import 'package:meta/meta.dart' show visibleForTesting;

import '../contracts/public/canvas_element.dart';
import '../contracts/public/canvas_ids.dart';

abstract interface class SparseEditReferenceFacts {
  int imageResourceReferenceCount(CanvasResourceId id);
  int vectorResourceReferenceCount(CanvasResourceId id);
}

@visibleForTesting
enum SparseEditReferenceWorkKind {
  transition,
  imageCommittedCountRead,
  vectorCommittedCountRead,
  deltaEntryRead,
  deltaEntryWrite,
  deltaEntryRemove,
  deltaEntryVisit,
  deltaEntryClear,
  resourceQuery,
  currentSplitCount,
}

@visibleForTesting
enum SparseEditReferenceFamily { image, vector }

@visibleForTesting
final class SparseEditReferenceWorkEvent {
  const SparseEditReferenceWorkEvent({
    required this.kind,
    this.resourceId,
    this.family,
    this.value,
    this.imageCount,
    this.vectorCount,
  });

  final SparseEditReferenceWorkKind kind;
  final CanvasResourceId? resourceId;
  final SparseEditReferenceFamily? family;
  final int? value;
  final int? imageCount;
  final int? vectorCount;
}

final Object _sparseEditReferenceWorkZoneKey = Object();

/// Observes sparse reference work without changing release-mode execution.
@visibleForTesting
T observeSparseEditReferenceWork<T>(
  void Function(SparseEditReferenceWorkEvent event) sink,
  T Function() operation,
) {
  return runZoned(
    operation,
    zoneValues: {_sparseEditReferenceWorkZoneKey: sink},
  );
}

/// Holds only transaction-local deltas; committed split summaries stay in Store.
final class SparseEditResourceReferences {
  SparseEditResourceReferences(this._facts) {
    _imageDeltas = _SparseEditReferenceDeltaMap(
      owner: this,
      family: SparseEditReferenceFamily.image,
    );
    _vectorDeltas = _SparseEditReferenceDeltaMap(
      owner: this,
      family: SparseEditReferenceFamily.vector,
    );
  }

  final SparseEditReferenceFacts _facts;
  late final _SparseEditReferenceDeltaMap _imageDeltas;
  late final _SparseEditReferenceDeltaMap _vectorDeltas;
  bool _isDisposed = false;

  void recordTransition({CanvasElement? before, CanvasElement? after}) {
    assert(
      _record(SparseEditReferenceWorkKind.transition),
      'sparse reference observation failed',
    );
    final beforeReference = _referenceOf(before);
    final afterReference = _referenceOf(after);
    if (beforeReference == afterReference) {
      return;
    }
    if (beforeReference != null) {
      _adjust(beforeReference, -1);
    }
    if (afterReference != null) {
      _adjust(afterReference, 1);
    }
  }

  bool isReferenced(CanvasResourceId id) {
    assert(
      _record(SparseEditReferenceWorkKind.resourceQuery, resourceId: id),
      'sparse reference observation failed',
    );
    final imageCount = this.imageCount(id);
    final vectorCount = this.vectorCount(id);
    assert(
      _record(
        SparseEditReferenceWorkKind.currentSplitCount,
        resourceId: id,
        imageCount: imageCount,
        vectorCount: vectorCount,
      ),
      'sparse reference observation failed',
    );
    return imageCount + vectorCount > 0;
  }

  int imageCount(CanvasResourceId id) {
    final committed = _facts.imageResourceReferenceCount(id);
    assert(
      _record(
        SparseEditReferenceWorkKind.imageCommittedCountRead,
        resourceId: id,
        family: SparseEditReferenceFamily.image,
        value: committed,
      ),
      'sparse reference observation failed',
    );
    final delta = _imageDeltas.read(id) ?? 0;
    return committed + delta;
  }

  int vectorCount(CanvasResourceId id) {
    final committed = _facts.vectorResourceReferenceCount(id);
    assert(
      _record(
        SparseEditReferenceWorkKind.vectorCommittedCountRead,
        resourceId: id,
        family: SparseEditReferenceFamily.vector,
        value: committed,
      ),
      'sparse reference observation failed',
    );
    final delta = _vectorDeltas.read(id) ?? 0;
    return committed + delta;
  }

  void _adjust(_SparseResourceReference reference, int change) {
    final deltas = reference.isImage ? _imageDeltas : _vectorDeltas;
    final next = (deltas.read(reference.id) ?? 0) + change;
    if (next == 0) {
      deltas.removeEntry(reference.id);
    } else {
      deltas.write(reference.id, next);
    }
  }

  void dispose() {
    if (_isDisposed) {
      return;
    }
    _isDisposed = true;
    _imageDeltas.clear();
    _vectorDeltas.clear();
  }

  _SparseResourceReference? _referenceOf(CanvasElement? element) {
    return switch (element) {
      CanvasImageElement(:final resourceId) => (id: resourceId, isImage: true),
      CanvasVectorElement(:final resourceId) => (
        id: resourceId,
        isImage: false,
      ),
      _ => null,
    };
  }

  // The complete test-only semantic event stays explicit here, so release
  // builds neither allocate an event nor execute observation work.
  // ignore: number-of-parameters
  bool _record(
    SparseEditReferenceWorkKind kind, {
    CanvasResourceId? resourceId,
    SparseEditReferenceFamily? family,
    int? value,
    int? imageCount,
    int? vectorCount,
  }) {
    final sink = Zone.current[_sparseEditReferenceWorkZoneKey];
    if (sink is void Function(SparseEditReferenceWorkEvent)) {
      sink(
        SparseEditReferenceWorkEvent(
          kind: kind,
          resourceId: resourceId,
          family: family,
          value: value,
          imageCount: imageCount,
          vectorCount: vectorCount,
        ),
      );
    }
    return true;
  }
}

typedef _SparseResourceReference = ({CanvasResourceId id, bool isImage});

/// Owns local delta entry access so scans and snapshots cannot be silent.
// MapBase requires the direct collection overrides to remain alongside the
// observed helpers; splitting them would let an access path bypass events.
// ignore: number-of-methods
final class _SparseEditReferenceDeltaMap
    extends MapBase<CanvasResourceId, int> {
  _SparseEditReferenceDeltaMap({required this.owner, required this.family});

  final SparseEditResourceReferences owner;
  final SparseEditReferenceFamily family;
  final Map<CanvasResourceId, int> _backing = {};

  int? read(CanvasResourceId id) {
    return _read(id);
  }

  void write(CanvasResourceId id, int value) {
    _write(id, value);
  }

  void removeEntry(CanvasResourceId id) {
    _remove(id);
  }

  @override
  int? operator [](Object? key) {
    return key is CanvasResourceId ? _read(key) : null;
  }

  @override
  void operator []=(CanvasResourceId key, int value) {
    _write(key, value);
  }

  @override
  int? remove(Object? key) {
    return key is CanvasResourceId ? _remove(key) : null;
  }

  @override
  void clear() {
    _backing.clear();
    _record(SparseEditReferenceWorkKind.deltaEntryClear);
  }

  @override
  Iterable<CanvasResourceId> get keys sync* {
    for (final id in _backing.keys) {
      _record(SparseEditReferenceWorkKind.deltaEntryVisit, resourceId: id);
      yield id;
    }
  }

  int? _read(CanvasResourceId id) {
    final value = _backing[id];
    _record(
      SparseEditReferenceWorkKind.deltaEntryRead,
      resourceId: id,
      value: value,
    );
    return value;
  }

  void _write(CanvasResourceId id, int value) {
    _backing[id] = value;
    _record(
      SparseEditReferenceWorkKind.deltaEntryWrite,
      resourceId: id,
      value: value,
    );
  }

  int? _remove(CanvasResourceId id) {
    final value = _backing.remove(id);
    _record(
      SparseEditReferenceWorkKind.deltaEntryRemove,
      resourceId: id,
      value: value,
    );
    return value;
  }

  void _record(
    SparseEditReferenceWorkKind kind, {
    CanvasResourceId? resourceId,
    int? value,
  }) {
    assert(
      owner._record(kind, resourceId: resourceId, family: family, value: value),
      'sparse delta entry observation failed',
    );
  }
}
