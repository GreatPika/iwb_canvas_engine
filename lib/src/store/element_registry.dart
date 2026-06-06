import 'dart:collection';

import '../contracts/public/canvas_document.dart';
import '../contracts/public/canvas_element.dart';
import '../contracts/public/canvas_ids.dart';
import 'family_tables.dart';
import 'layer_table.dart';

// ElementRegistry is the committed element table aggregate; keeping sparse row
// operations with lookup/order facts prevents a second source of truth.
// Sparse append overlays also belong here so order, location, and admission
// facts stay one atomic registry snapshot instead of drifting across helpers.
// ignore: coupling-between-object-classes, number-of-methods, response-for-class, weighted-methods-per-class
final class ElementRegistry {
  // The constructor materializes one committed element registry snapshot:
  // family rows, layer rows, content order, frame order, and admitted ids must
  // stay aligned from the same input pass instead of drifting through
  // metric-shaped builders.
  // ignore: halstead-volume
  ElementRegistry({
    required Iterable<CanvasElement> backgroundElements,
    required Iterable<CanvasLayer> layers,
    required Set<String> resourceIds,
  }) : this._(
         backgroundElementIds: [
           for (final element in backgroundElements) element.id,
         ],
         familyTables: FamilyTables([
           ...backgroundElements,
           for (final layer in layers) ...layer.elements,
         ], resourceIds: resourceIds),
         layerTable: LayerTable(
           layers.map(
             (layer) => LayerRow(
               id: layer.id,
               elementIds: layer.elements.map((element) => element.id),
               metadata: layer.metadata,
             ),
           ),
         ),
       );

  ElementRegistry._({
    required Iterable<CanvasElementId> backgroundElementIds,
    required this.familyTables,
    required this.layerTable,
  }) {
    final backgroundElementList = List<CanvasElementId>.unmodifiable(
      backgroundElementIds,
    );
    final contentOrder = List<CanvasElementId>.unmodifiable([
      for (final row in layerTable.rows)
        for (final id in row.elementIds) id,
    ]);
    final frameOrder = List<CanvasElementId>.unmodifiable([
      ...backgroundElementList,
      ...contentOrder,
    ]);
    this.backgroundElementIds = backgroundElementList;
    contentElementOrder = contentOrder;
    frameElementOrder = frameOrder;
    frameOrderTokensById = _frameOrderTokensById(frameOrder);
    elementLocationFacts = _elementLocationFacts(
      backgroundElementList,
      layerTable,
    );
    admittedElementIds = Set.unmodifiable(familyTables.admittedElementIds);
    admittedLayerIds = Set.unmodifiable(layerTable.admittedIds);
  }

  ElementRegistry._withUpdatedFamilies({
    required this.familyTables,
    required this.layerTable,
    required this.backgroundElementIds,
    required this.contentElementOrder,
    required this.frameElementOrder,
    required this.frameOrderTokensById,
    required this.elementLocationFacts,
    required this.admittedElementIds,
    required this.admittedLayerIds,
  });

  factory ElementRegistry.fromTables({
    required Iterable<CanvasElementId> backgroundElementIds,
    required FamilyTables familyTables,
    required LayerTable layerTable,
  }) {
    return ElementRegistry._(
      backgroundElementIds: backgroundElementIds,
      familyTables: familyTables,
      layerTable: layerTable,
    );
  }

  late final List<CanvasElementId> backgroundElementIds;
  late final FamilyTables familyTables;
  late final LayerTable layerTable;
  late final List<CanvasElementId> contentElementOrder;
  late final List<CanvasElementId> frameElementOrder;
  late final Map<CanvasElementId, int> frameOrderTokensById;
  late final Map<CanvasElementId, ElementLocationFacts> elementLocationFacts;
  late final Set<String> admittedElementIds;
  late final Set<String> admittedLayerIds;

  int get elementCount {
    return backgroundElementIds.length +
        layerTable.rows.fold<int>(
          0,
          (count, row) => count + row.elementIds.length,
        );
  }

  Set<CanvasElementId> get contentElementIds {
    return {for (final id in contentElementOrder) id};
  }

  Set<CanvasElementId> get selectableElementIds {
    return {
      for (final row in layerTable.rows)
        for (final id in row.elementIds)
          if (familyTables.isSelectionEligible(id)) id,
    };
  }

  FamilyElementFacts? elementFrameFacts(CanvasElementId id) {
    return familyTables.elementFrameFacts(id);
  }

  bool frameOrderMatches(int orderToken, CanvasElementId id) {
    return frameOrderTokensById[id] == orderToken;
  }

  bool containsElement(CanvasElementId id) {
    return familyTables.contains(id);
  }

  bool containsLayer(CanvasLayerId id) {
    return layerTable.contains(id);
  }

  bool referencesResource(CanvasResourceId id) {
    return familyTables.referencesResource(id);
  }

  CanvasElement? elementById(CanvasElementId id) {
    return familyTables.elementByCanvasId(id);
  }

  ElementRegistry ensureLayer(CanvasLayerId id, {int? index}) {
    return ElementRegistry._(
      backgroundElementIds: backgroundElementIds,
      familyTables: familyTables,
      layerTable: layerTable.ensureLayer(id, index: index),
    );
  }

  ElementRegistry addElement(
    CanvasElement element, {
    required Set<String> resourceIds,
    CanvasLayerId? layerId,
    int? index,
  }) {
    final appendLayerId = _contentAppendLayerId(layerId: layerId, index: index);
    final nextFamilyTables = familyTables.addElement(element, resourceIds);
    final nextLayerTable = layerTable.addElement(
      element.id,
      layerId: layerId,
      index: index,
    );
    if (appendLayerId != null) {
      return _withAppendedContentElement(
        element.id,
        layerId: appendLayerId,
        familyTables: nextFamilyTables,
        layerTable: nextLayerTable,
        admitsNewLayer: !layerTable.contains(appendLayerId),
      );
    }

    return ElementRegistry._(
      backgroundElementIds: backgroundElementIds,
      familyTables: nextFamilyTables,
      layerTable: nextLayerTable,
    );
  }

  ElementRegistry addBackgroundElement(
    CanvasElement element, {
    required Set<String> resourceIds,
    int? index,
  }) {
    final nextBackgroundIds = backgroundElementIds.toList();
    nextBackgroundIds.insert(
      _clampedInsertIndex(index, nextBackgroundIds.length),
      element.id,
    );

    return ElementRegistry._(
      backgroundElementIds: nextBackgroundIds,
      familyTables: familyTables.addElement(element, resourceIds),
      layerTable: layerTable,
    );
  }

  ElementRegistry? updateElement(
    CanvasElement element, {
    required Set<String> resourceIds,
    required bool Function(CanvasElement left, CanvasElement right) sameElement,
  }) {
    final before = familyTables.elementByCanvasId(element.id);
    if (before == null) {
      return null;
    }
    final updatedFamilyTables = familyTables.replaceElement(
      before,
      element,
      resourceIds,
      sameElement: sameElement,
    );
    if (updatedFamilyTables == null) {
      return null;
    }

    return ElementRegistry._withUpdatedFamilies(
      familyTables: updatedFamilyTables,
      layerTable: layerTable,
      backgroundElementIds: backgroundElementIds,
      contentElementOrder: contentElementOrder,
      frameElementOrder: frameElementOrder,
      frameOrderTokensById: frameOrderTokensById,
      elementLocationFacts: elementLocationFacts,
      admittedElementIds: admittedElementIds,
      admittedLayerIds: admittedLayerIds,
    );
  }

  ElementRegistry removeElement(CanvasElementId id) {
    return ElementRegistry._(
      backgroundElementIds: [
        for (final elementId in backgroundElementIds)
          if (elementId != id) elementId,
      ],
      familyTables: familyTables.removeElement(id),
      layerTable: layerTable.removeElement(id),
    );
  }

  ElementRegistry clearContent() {
    return ElementRegistry._(
      backgroundElementIds: const [],
      familyTables: familyTables.clearElements(),
      layerTable: layerTable.clearElements(),
    );
  }

  CanvasLayerId? _contentAppendLayerId({
    required CanvasLayerId? layerId,
    required int? index,
  }) {
    if (index != null) {
      return null;
    }
    if (layerTable.rows.isEmpty) {
      return layerId ?? CanvasLayerId('default-layer');
    }
    if (layerId == null) {
      return layerTable.rows.last.id;
    }
    final targetIndex = layerTable.rows.indexWhere((row) => row.id == layerId);
    if (targetIndex == -1 || targetIndex == layerTable.rows.length - 1) {
      return layerId;
    }

    return null;
  }

  ElementRegistry _withAppendedContentElement(
    CanvasElementId id, {
    required CanvasLayerId layerId,
    required FamilyTables familyTables,
    required LayerTable layerTable,
    required bool admitsNewLayer,
  }) {
    return ElementRegistry._withUpdatedFamilies(
      familyTables: familyTables,
      layerTable: layerTable,
      backgroundElementIds: backgroundElementIds,
      contentElementOrder: List.unmodifiable([...contentElementOrder, id]),
      frameElementOrder: List.unmodifiable([...frameElementOrder, id]),
      frameOrderTokensById: _AppendedReadOnlyMap(
        frameOrderTokensById,
        id,
        frameElementOrder.length,
      ),
      elementLocationFacts: _AppendedReadOnlyMap(
        elementLocationFacts,
        id,
        ElementLocationFacts.content(layerId),
      ),
      admittedElementIds: _AppendedReadOnlySet(admittedElementIds, id.value),
      admittedLayerIds: admitsNewLayer
          ? _AppendedReadOnlySet(admittedLayerIds, layerId.value)
          : admittedLayerIds,
    );
  }
}

Map<CanvasElementId, int> _frameOrderTokensById(
  Iterable<CanvasElementId> frameOrder,
) {
  return Map.unmodifiable({
    for (final indexed in frameOrder.indexed) indexed.$2: indexed.$1,
  });
}

Map<CanvasElementId, ElementLocationFacts> _elementLocationFacts(
  Iterable<CanvasElementId> backgroundElementIds,
  LayerTable layerTable,
) {
  return Map.unmodifiable({
    for (final id in backgroundElementIds)
      id: const ElementLocationFacts.background(),
    for (final layer in layerTable.rows)
      for (final id in layer.elementIds)
        id: ElementLocationFacts.content(layer.id),
  });
}

int _clampedInsertIndex(int? requestedIndex, int length) {
  final index = requestedIndex ?? length;
  if (index < 0) {
    return 0;
  }
  if (index > length) {
    return length;
  }

  return index;
}

enum ElementLocationKind { background, content }

final class ElementLocationFacts {
  const ElementLocationFacts.background()
    : kind = ElementLocationKind.background,
      layerId = null;

  const ElementLocationFacts.content(this.layerId)
    : kind = ElementLocationKind.content;

  final ElementLocationKind kind;
  final CanvasLayerId? layerId;
}

final class _AppendedReadOnlyMap<K, V> extends MapBase<K, V> {
  _AppendedReadOnlyMap(this._base, this._key, this._value);

  final Map<K, V> _base;
  final K _key;
  final V _value;

  @override
  Iterable<K> get keys =>
      _base.containsKey(_key) ? _base.keys : _followedByOne(_base.keys, _key);

  @override
  V? operator [](Object? key) => key == _key ? _value : _base[key];

  @override
  void operator []=(K key, V value) {
    throw UnsupportedError('ElementRegistry maps are read-only.');
  }

  @override
  void clear() {
    throw UnsupportedError('ElementRegistry maps are read-only.');
  }

  @override
  V? remove(Object? key) {
    throw UnsupportedError('ElementRegistry maps are read-only.');
  }
}

final class _AppendedReadOnlySet<E> extends SetBase<E> {
  _AppendedReadOnlySet(this._base, this._value);

  final Set<E> _base;
  final E _value;

  @override
  bool contains(Object? element) =>
      element == _value || _base.contains(element);

  @override
  Iterator<E> get iterator {
    if (_base.contains(_value)) {
      return _base.iterator;
    }

    return _followedByOne(_base, _value).iterator;
  }

  @override
  int get length => _base.contains(_value) ? _base.length : _base.length + 1;

  @override
  bool add(E value) {
    throw UnsupportedError('ElementRegistry sets are read-only.');
  }

  @override
  E? lookup(Object? element) {
    if (element == _value) {
      return _value;
    }

    return _base.lookup(element);
  }

  @override
  bool remove(Object? value) {
    throw UnsupportedError('ElementRegistry sets are read-only.');
  }

  @override
  Set<E> toSet() => Set.of(this);
}

Iterable<T> _followedByOne<T>(Iterable<T> values, T value) sync* {
  yield* values;
  yield value;
}
