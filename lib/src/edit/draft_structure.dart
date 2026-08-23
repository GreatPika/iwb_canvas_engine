import 'dart:async';

import 'package:meta/meta.dart' show visibleForTesting;

import '../contracts/public/canvas_document.dart';
import '../contracts/public/canvas_element.dart';
import '../contracts/public/canvas_ids.dart';
import '../contracts/public/canvas_metadata.dart';
import '../store/indexed_order_sequence.dart';

@visibleForTesting
enum DraftStructureOrderKind { layer, background, content }

@visibleForTesting
enum DraftStructureWorkKind {
  orderOpen,
  constructionLayerVisit,
  constructionElementVisit,
  materialization,
}

@visibleForTesting
enum DraftStructureMapKind { layerRows, elementRows, placements, contentOrders }

@visibleForTesting
enum DraftStructureMapOperation { contains, read, write, remove }

/// Semantic owner events for Draft structural work. They deliberately describe
/// only owner phases, leaving AVL traversal facts to [IndexedOrderSequence].
@visibleForTesting
final class DraftStructureWorkEvent {
  const DraftStructureWorkEvent({
    this.kind,
    this.order,
    this.layerId,
    this.mapKind,
    this.mapOperation,
  });

  final DraftStructureWorkKind? kind;
  final DraftStructureOrderKind? order;
  final CanvasLayerId? layerId;
  final DraftStructureMapKind? mapKind;
  final DraftStructureMapOperation? mapOperation;
}

final Object _draftStructureWorkZoneKey = Object();

@visibleForTesting
T observeDraftStructureWork<T>(
  void Function(DraftStructureWorkEvent event) sink,
  T Function() operation,
) {
  return runZoned(operation, zoneValues: {_draftStructureWorkZoneKey: sink});
}

/// The Draft structural source of truth. Element rows, current placement, and
/// owner-local orders are updated together, so mutations never need a list
/// shift or a layer-by-layer lookup to find their current row.
// Structure mutations must update the direct rows, placement, and affected
// indexed order together; splitting them would reintroduce synchronization and
// hide their shared structural invariant behind forwarding helpers.
// ignore: coupling-between-object-classes, number-of-methods, response-for-class, weighted-methods-per-class
final class DraftStructure {
  DraftStructure(CanvasDocument document) {
    _backgroundOrder = _openOrder(
      DraftStructureOrderKind.background,
      _ingestBackground(document.backgroundElements),
    );
    _layerOrder = _openOrder(
      DraftStructureOrderKind.layer,
      _ingestLayers(document.layers),
    );
  }

  final _DraftDirectMap<CanvasLayerId, _DraftStructureLayer> _layersById =
      _DraftDirectMap(DraftStructureMapKind.layerRows);
  final _DraftDirectMap<CanvasElementId, CanvasElement> _elementsById =
      _DraftDirectMap(DraftStructureMapKind.elementRows);
  final _DraftDirectMap<CanvasElementId, _DraftElementPlacement>
  _placementsByElementId = _DraftDirectMap(DraftStructureMapKind.placements);
  final _DraftDirectMap<
    CanvasLayerId,
    IndexedOrderSequence<CanvasElementId, CanvasElementId>
  >
  _contentOrders = _DraftDirectMap(DraftStructureMapKind.contentOrders);
  late final IndexedOrderSequence<CanvasLayerId, CanvasLayerId> _layerOrder;
  late final IndexedOrderSequence<CanvasElementId, CanvasElementId>
  _backgroundOrder;
  var _contentElementCount = 0;

  int get layerCount => _layerOrder.length;
  int get backgroundElementCount => _backgroundOrder.length;
  int get contentElementCount => _contentElementCount;
  bool hasLayer(CanvasLayerId id) => _layersById.containsKey(id);

  bool hasElement(CanvasElementId id) => _elementsById.containsKey(id);

  CanvasLayerId? get lastLayerId => _layerOrder.last;

  bool ensureLayer(
    CanvasLayerId id, {
    int? index,
    CanvasMetadata metadata = const CanvasMetadata.empty(),
  }) {
    if (hasLayer(id)) {
      return false;
    }
    _layersById.write(id, _DraftStructureLayer(id: id, metadata: metadata));
    _contentOrders.write(
      id,
      _openOrder(
        DraftStructureOrderKind.content,
        const <CanvasElementId>[],
        layerId: id,
      ),
    );
    _layerOrder.insert(id, index: index);
    return true;
  }

  void addBackground(CanvasElement element, {int? index}) {
    _backgroundOrder.insert(element.id, index: index);
    _elementsById.write(element.id, element);
    _placementsByElementId.write(
      element.id,
      const _DraftElementPlacement.background(),
    );
  }

  void addContent(
    CanvasElement element, {
    required CanvasLayerId layerId,
    int? index,
  }) {
    final order = _contentOrders.read(layerId);
    if (order == null) {
      throw StateError('Draft content layer is missing its order.');
    }
    order.insert(element.id, index: index);
    _elementsById.write(element.id, element);
    _placementsByElementId.write(
      element.id,
      _DraftElementPlacement.content(layerId),
    );
    _contentElementCount += 1;
  }

  DraftStructureElement? elementForId(CanvasElementId id) {
    final element = _readElementRow(id);
    if (element == null) {
      return null;
    }
    final placement = _placementsByElementId.read(id);
    if (placement == null) {
      throw StateError('Draft element is missing its current placement.');
    }
    return DraftStructureElement(
      element: element,
      isBackground: placement.isBackground,
    );
  }

  void replaceElement(CanvasElement element) {
    if (!hasElement(element.id)) {
      throw StateError('Cannot replace a missing Draft element.');
    }
    _elementsById.write(element.id, element);
  }

  DraftStructureElement? remove(CanvasElementId id) {
    final target = elementForId(id);
    if (target == null) {
      return null;
    }
    final placement = _placementsByElementId.remove(id);
    if (placement == null) {
      throw StateError('Draft element is missing its current placement.');
    }
    if (placement.isBackground) {
      if (_backgroundOrder.remove(id) == null) {
        throw StateError('Draft background placement is missing its order id.');
      }
    } else {
      final layerId = placement.layerId;
      if (layerId == null) {
        throw StateError('Draft content placement is missing its layer id.');
      }
      final order = _contentOrders.read(layerId);
      if (order == null || order.remove(id) == null) {
        throw StateError('Draft content placement is missing its order id.');
      }
      _contentElementCount -= 1;
    }
    _elementsById.remove(id);
    return target;
  }

  List<CanvasElementId> clearContent({
    required void Function(CanvasElementId id) onElementRemoved,
  }) {
    final removedIds = <CanvasElementId>[];
    for (final layerId in _layerOrder.orderedValues) {
      final order = _contentOrders.read(layerId);
      if (order == null) {
        throw StateError('Draft layer is missing its content order.');
      }
      for (final id in order.orderedValues) {
        removedIds.add(id);
        onElementRemoved(id);
        _elementsById.remove(id);
        _placementsByElementId.remove(id);
      }
      order.clear();
    }
    _contentElementCount = 0;
    return List.unmodifiable(removedIds);
  }

  DraftStructureProjection materialize() {
    final backgroundElements = _materializeElements(
      _backgroundOrder,
      DraftStructureOrderKind.background,
    );
    final layers = <CanvasLayer>[];
    _record(
      DraftStructureWorkKind.materialization,
      order: DraftStructureOrderKind.layer,
    );
    for (final layerId in _layerOrder.orderedValues) {
      final layer = _layersById.read(layerId);
      final order = _contentOrders.read(layerId);
      if (layer == null || order == null) {
        throw StateError('Draft layer is missing its structural facts.');
      }
      layers.add(
        CanvasLayer(
          id: layer.id,
          elements: _materializeElements(
            order,
            DraftStructureOrderKind.content,
            layerId: layer.id,
          ),
          metadata: layer.metadata,
        ),
      );
    }
    return DraftStructureProjection(
      backgroundElements: backgroundElements,
      layers: List.unmodifiable(layers),
    );
  }

  Iterable<CanvasElement> orderedBackgroundElements() sync* {
    for (final id in _backgroundOrder.orderedValues) {
      yield _readRequiredElementRow(
        id,
        'Draft background order is missing an element row.',
      );
    }
  }

  Iterable<CanvasElement> orderedContentElements() sync* {
    for (final layerId in _layerOrder.orderedValues) {
      final order = _contentOrders.read(layerId);
      if (order == null) {
        throw StateError('Draft layer is missing its content order.');
      }
      for (final id in order.orderedValues) {
        yield _readRequiredElementRow(
          id,
          'Draft content order is missing an element row.',
        );
      }
    }
  }

  Iterable<CanvasElement> orderedElements() sync* {
    yield* orderedBackgroundElements();
    yield* orderedContentElements();
  }

  List<CanvasElement> _materializeElements(
    IndexedOrderSequence<CanvasElementId, CanvasElementId> order,
    DraftStructureOrderKind kind, {
    CanvasLayerId? layerId,
  }) {
    _record(
      DraftStructureWorkKind.materialization,
      order: kind,
      layerId: layerId,
    );
    return [
      for (final id in order.orderedValues)
        _readRequiredElementRow(id, 'Draft order is missing an element row.'),
    ];
  }

  CanvasElement? _readElementRow(CanvasElementId id) {
    return _elementsById.read(id);
  }

  CanvasElement _readRequiredElementRow(CanvasElementId id, String message) {
    return _readElementRow(id) ?? (throw StateError(message));
  }

  Iterable<CanvasElementId> _ingestBackground(
    Iterable<CanvasElement> elements,
  ) sync* {
    for (final element in _observedSeedRows(
      elements,
      DraftStructureWorkKind.constructionElementVisit,
    )) {
      _elementsById.write(element.id, element);
      _placementsByElementId.write(
        element.id,
        const _DraftElementPlacement.background(),
      );
      yield element.id;
    }
  }

  Iterable<CanvasLayerId> _ingestLayers(Iterable<CanvasLayer> layers) sync* {
    for (final layer in _observedSeedRows(
      layers,
      DraftStructureWorkKind.constructionLayerVisit,
    )) {
      final draftLayer = _DraftStructureLayer(
        id: layer.id,
        metadata: layer.metadata,
      );
      _layersById.write(layer.id, draftLayer);
      _contentOrders.write(
        layer.id,
        _openOrder(
          DraftStructureOrderKind.content,
          _ingestContent(layer),
          layerId: layer.id,
        ),
      );
      yield layer.id;
    }
  }

  Iterable<CanvasElementId> _ingestContent(CanvasLayer layer) sync* {
    for (final element in _observedSeedRows(
      layer.elements,
      DraftStructureWorkKind.constructionElementVisit,
    )) {
      _elementsById.write(element.id, element);
      _placementsByElementId.write(
        element.id,
        _DraftElementPlacement.content(layer.id),
      );
      _contentElementCount += 1;
      yield element.id;
    }
  }

  /// The construction input is observed at its iterable boundary, so a second
  /// traversal is visible as a second set of source-row visits.
  static Iterable<T> _observedSeedRows<T>(
    Iterable<T> rows,
    DraftStructureWorkKind event,
  ) sync* {
    for (final row in rows) {
      _record(event);
      yield row;
    }
  }

  static IndexedOrderSequence<T, T> _openOrder<T>(
    DraftStructureOrderKind kind,
    Iterable<T> values, {
    CanvasLayerId? layerId,
  }) {
    _record(DraftStructureWorkKind.orderOpen, order: kind, layerId: layerId);
    return IndexedOrderSequence<T, T>(values, idOf: (value) => value);
  }

  static void _record(
    DraftStructureWorkKind kind, {
    DraftStructureOrderKind? order,
    CanvasLayerId? layerId,
  }) {
    assert(() {
      final sink = Zone.current[_draftStructureWorkZoneKey];
      if (sink is void Function(DraftStructureWorkEvent)) {
        sink(
          DraftStructureWorkEvent(kind: kind, order: order, layerId: layerId),
        );
      }
      return true;
    }(), 'draft structure work observation failed');
  }

  static void _recordMap(
    DraftStructureMapKind mapKind,
    DraftStructureMapOperation mapOperation,
  ) {
    assert(() {
      final sink = Zone.current[_draftStructureWorkZoneKey];
      if (sink is void Function(DraftStructureWorkEvent)) {
        sink(
          DraftStructureWorkEvent(mapKind: mapKind, mapOperation: mapOperation),
        );
      }
      return true;
    }(), 'draft structure map observation failed');
  }
}

/// A private direct-map owner. Its deliberately narrow surface keeps structural
/// paths to direct keyed operations; no map snapshot or entry iteration exists.
final class _DraftDirectMap<K, V> {
  _DraftDirectMap(this._kind);

  final DraftStructureMapKind _kind;
  final Map<K, V> _values = {};

  bool containsKey(K key) {
    DraftStructure._recordMap(_kind, DraftStructureMapOperation.contains);
    return _values.containsKey(key);
  }

  V? read(K key) {
    DraftStructure._recordMap(_kind, DraftStructureMapOperation.read);
    return _values[key];
  }

  void write(K key, V value) {
    DraftStructure._recordMap(_kind, DraftStructureMapOperation.write);
    _values[key] = value;
  }

  V? remove(K key) {
    DraftStructure._recordMap(_kind, DraftStructureMapOperation.remove);
    return _values.remove(key);
  }
}

final class DraftStructureProjection {
  const DraftStructureProjection({
    required this.backgroundElements,
    required this.layers,
  });

  final List<CanvasElement> backgroundElements;
  final List<CanvasLayer> layers;
}

final class DraftStructureElement {
  const DraftStructureElement({
    required this.element,
    required this.isBackground,
  });

  final CanvasElement element;
  final bool isBackground;
}

final class _DraftStructureLayer {
  const _DraftStructureLayer({required this.id, required this.metadata});

  final CanvasLayerId id;
  final CanvasMetadata metadata;
}

final class _DraftElementPlacement {
  const _DraftElementPlacement.background()
    : isBackground = true,
      layerId = null;

  const _DraftElementPlacement.content(this.layerId) : isBackground = false;

  final bool isBackground;
  final CanvasLayerId? layerId;
}
