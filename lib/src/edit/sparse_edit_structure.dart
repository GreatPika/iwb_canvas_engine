import 'dart:async';

import 'package:meta/meta.dart' show visibleForTesting;

import '../contracts/public/canvas_ids.dart';
import '../store/element_registry.dart';
import '../store/indexed_order_sequence.dart';

/// Narrow committed structural reads used to seed one sparse session owner.
///
/// The backing retains no copied committed placement map: it asks this port once
/// per ID, then its current-location view owns every later sparse decision.
abstract interface class SparseEditStructureFacts {
  bool hasLayer(CanvasLayerId id);
  Iterable<CanvasElementId> get backgroundElementIds;
  Iterable<CanvasLayerId> get layerIds;
  Iterable<CanvasElementId> elementIdsInLayer(CanvasLayerId id);
  ElementLocationFacts? elementLocationFor(CanvasElementId id);
}

@visibleForTesting
enum SparseEditStructureOrderKind { layer, background, content }

@visibleForTesting
enum SparseEditStructureWorkKind {
  committedLocationRead,
  currentLocationRead,
  orderOpen,
  cleanup,
}

/// Owner-attributed events supplement the indexed-order events without copying
/// its algorithm inventory. Test fixtures aggregate these only under asserts.
@visibleForTesting
final class SparseEditStructureWorkEvent {
  const SparseEditStructureWorkEvent({
    required this.kind,
    this.order,
    this.layerId,
  });

  final SparseEditStructureWorkKind kind;
  final SparseEditStructureOrderKind? order;
  final CanvasLayerId? layerId;
}

final Object _sparseEditStructureWorkZoneKey = Object();

@visibleForTesting
T observeSparseEditStructureWork<T>(
  void Function(SparseEditStructureWorkEvent event) sink,
  T Function() operation,
) {
  return runZoned(
    operation,
    zoneValues: {_sparseEditStructureWorkZoneKey: sink},
  );
}

// This owner keeps all sparse placement state together: each mutable indexed
// sequence is isolated, while the current location map is the sole placement
// authority after its first committed fact read.
// Opening, mutation, traversal, and disposal must share that authority, so
// separating methods would obscure lifecycle edges without reducing ownership.
// ignore: number-of-methods, weighted-methods-per-class
final class SparseEditStructure {
  SparseEditStructure(this._facts);

  final SparseEditStructureFacts _facts;
  final Map<CanvasElementId, ElementLocationFacts?> _currentLocations = {};
  final Map<
    CanvasLayerId,
    IndexedOrderSequence<CanvasElementId, CanvasElementId>
  >
  _contentOrders = {};
  IndexedOrderSequence<CanvasLayerId, CanvasLayerId>? _layerOrder;
  IndexedOrderSequence<CanvasElementId, CanvasElementId>? _backgroundOrder;
  var _isDisposed = false;

  bool hasLayer(CanvasLayerId id) {
    final order = _layerOrder;
    return order?.containsId(id) ?? _facts.hasLayer(id);
  }

  int layerCount({required int committedCount}) {
    return _layerOrder?.length ?? committedCount;
  }

  bool ensureLayer(CanvasLayerId id, {int? index}) {
    if (hasLayer(id)) {
      return false;
    }
    _openLayerOrder().insert(id, index: index);
    return true;
  }

  CanvasLayerId? lastLayerId() => _openLayerOrder().last;

  void addBackground(CanvasElementId id, {int? index}) {
    _openBackgroundOrder().insert(id, index: index);
    _currentLocations[id] = const ElementLocationFacts.background();
  }

  void addContent(
    CanvasElementId id, {
    required CanvasLayerId layerId,
    int? index,
  }) {
    _openContentOrder(layerId).insert(id, index: index);
    _currentLocations[id] = ElementLocationFacts.content(layerId);
  }

  ElementLocationFacts? remove(CanvasElementId id) {
    final location = currentLocationFor(id);
    if (location == null) {
      return null;
    }
    if (location.kind == ElementLocationKind.background) {
      _openBackgroundOrder().remove(id);
    } else {
      final layerId = location.layerId;
      if (layerId == null) {
        throw StateError('Content element location is missing its layer id.');
      }
      _openContentOrder(layerId).remove(id);
    }
    _currentLocations[id] = null;
    return location;
  }

  ElementLocationFacts? currentLocationFor(CanvasElementId id) {
    _record(SparseEditStructureWorkKind.currentLocationRead);
    if (_currentLocations.containsKey(id)) {
      return _currentLocations[id];
    }
    _record(SparseEditStructureWorkKind.committedLocationRead);
    final location = _facts.elementLocationFor(id);
    _currentLocations[id] = location;
    return location;
  }

  bool isBackgroundElement(CanvasElementId id) {
    return currentLocationFor(id)?.kind == ElementLocationKind.background;
  }

  Iterable<CanvasElementId> backgroundElementIds() {
    return _openBackgroundOrder().orderedValues;
  }

  List<CanvasElementId> clearContent() {
    final removed = <CanvasElementId>[];
    for (final layerId in _openLayerOrder().orderedValues) {
      final order = _openContentOrder(layerId);
      for (final id in order.orderedValues) {
        removed.add(id);
        _currentLocations[id] = null;
      }
      order.clear();
    }
    return List.unmodifiable(removed);
  }

  void dispose() {
    if (_isDisposed) {
      return;
    }
    _isDisposed = true;
    _discard(_layerOrder, SparseEditStructureOrderKind.layer);
    _discard(_backgroundOrder, SparseEditStructureOrderKind.background);
    for (final entry in _contentOrders.entries) {
      _discard(
        entry.value,
        SparseEditStructureOrderKind.content,
        layerId: entry.key,
      );
    }
    _layerOrder = null;
    _backgroundOrder = null;
    _contentOrders.clear();
    _currentLocations.clear();
  }

  IndexedOrderSequence<CanvasLayerId, CanvasLayerId> _openLayerOrder() {
    _ensureOpen();
    return _layerOrder ??= _openOrder(
      SparseEditStructureOrderKind.layer,
      _facts.layerIds,
    );
  }

  IndexedOrderSequence<CanvasElementId, CanvasElementId>
  _openBackgroundOrder() {
    _ensureOpen();
    return _backgroundOrder ??= _openOrder(
      SparseEditStructureOrderKind.background,
      _facts.backgroundElementIds,
    );
  }

  IndexedOrderSequence<CanvasElementId, CanvasElementId> _openContentOrder(
    CanvasLayerId layerId,
  ) {
    _ensureOpen();
    return _contentOrders.putIfAbsent(
      layerId,
      () => _openOrder(
        SparseEditStructureOrderKind.content,
        _facts.elementIdsInLayer(layerId),
        layerId: layerId,
      ),
    );
  }

  IndexedOrderSequence<T, T> _openOrder<T>(
    SparseEditStructureOrderKind kind,
    Iterable<T> values, {
    CanvasLayerId? layerId,
  }) {
    _record(
      SparseEditStructureWorkKind.orderOpen,
      order: kind,
      layerId: layerId,
    );
    return IndexedOrderSequence<T, T>(values, idOf: (value) => value);
  }

  void _discard<T>(
    IndexedOrderSequence<T, T>? order,
    SparseEditStructureOrderKind kind, {
    CanvasLayerId? layerId,
  }) {
    if (order == null) {
      return;
    }
    _record(SparseEditStructureWorkKind.cleanup, order: kind, layerId: layerId);
    order.discard();
  }

  void _ensureOpen() {
    if (_isDisposed) {
      throw StateError('Sparse edit structure was already disposed.');
    }
  }

  void _record(
    SparseEditStructureWorkKind kind, {
    SparseEditStructureOrderKind? order,
    CanvasLayerId? layerId,
  }) {
    assert(() {
      final sink = Zone.current[_sparseEditStructureWorkZoneKey];
      if (sink is void Function(SparseEditStructureWorkEvent)) {
        sink(
          SparseEditStructureWorkEvent(
            kind: kind,
            order: order,
            layerId: layerId,
          ),
        );
      }
      return true;
    }(), 'sparse edit structure work observation failed');
  }
}
