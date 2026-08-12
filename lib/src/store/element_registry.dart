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
  ElementRegistry.empty()
    : this._(
        backgroundElementIds: const [],
        familyTables: const FamilyTables.empty(),
        layerTable: const LayerTable.empty(),
      );

  // The constructor materializes one committed element registry snapshot:
  // family rows, layer rows, content order, frame order, and admitted ids must
  // stay aligned from the same input pass instead of drifting through
  // metric-shaped builders.
  // ignore: halstead-volume
  ElementRegistry({
    required Iterable<CanvasElement> backgroundElements,
    required Iterable<CanvasLayer> layers,
  }) : this._(
         backgroundElementIds: [
           for (final element in backgroundElements) element.id,
         ],
         familyTables: FamilyTables([
           ...backgroundElements,
           for (final layer in layers) ...layer.elements,
         ]),
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
    final orderFacts = _ElementRegistryOrderFacts.build(
      backgroundElementIds,
      layerTable,
    );
    this.backgroundElementIds = orderFacts.backgroundElementIds;
    contentElementOrder = orderFacts.contentElementOrder;
    frameElementOrder = orderFacts.frameElementOrder;
    frameOrderTokensById = orderFacts.frameOrderTokensById;
    elementLocationFacts = orderFacts.elementLocationFacts;
    admittedElementIds = orderFacts.admittedElementIds;
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

  factory ElementRegistry.fromSchemaV1ImportTables({
    required FamilyTables familyTables,
    required LayerTable layerTable,
    required ElementRegistryOrderImportFacts orderFacts,
  }) {
    return ElementRegistry._withUpdatedFamilies(
      familyTables: familyTables,
      layerTable: layerTable,
      backgroundElementIds: orderFacts.backgroundElementIds,
      contentElementOrder: orderFacts.contentElementOrder,
      frameElementOrder: orderFacts.frameElementOrder,
      frameOrderTokensById: orderFacts.frameOrderTokensById,
      elementLocationFacts: orderFacts.elementLocationFacts,
      admittedElementIds: orderFacts.admittedElementIds,
      admittedLayerIds: Set.unmodifiable(layerTable.admittedIds),
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
    return frameElementOrder.length;
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

  // Sparse family rows are adopted once after their editor freezes; all other
  // committed registry facts keep their existing immutable lifecycle.
  ElementRegistry adoptFamilyTables(FamilyTables familyTables) {
    FamilyTables.recordSparseFamilyAdoption(familyTables);
    return ElementRegistry._withUpdatedFamilies(
      familyTables: familyTables,
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

  ElementRegistry ensureLayer(CanvasLayerId id, {int? index}) {
    return ElementRegistry._(
      backgroundElementIds: backgroundElementIds,
      familyTables: familyTables,
      layerTable: layerTable.ensureLayer(id, index: index),
    );
  }

  ElementRegistry addElement(
    CanvasElement element, {
    CanvasLayerId? layerId,
    int? index,
  }) {
    final appendLayerId = _contentAppendLayerId(layerId: layerId, index: index);
    final nextFamilyTables = familyTables.addElement(element);
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

  ElementRegistry addBackgroundElement(CanvasElement element, {int? index}) {
    final nextBackgroundIds = backgroundElementIds.toList();
    nextBackgroundIds.insert(
      _clampedInsertIndex(index, nextBackgroundIds.length),
      element.id,
    );

    return ElementRegistry._(
      backgroundElementIds: nextBackgroundIds,
      familyTables: familyTables.addElement(element),
      layerTable: layerTable,
    );
  }

  ElementRegistry addElementStructure(
    CanvasElement element, {
    CanvasLayerId? layerId,
    int? index,
  }) {
    final appendLayerId = _contentAppendLayerId(layerId: layerId, index: index);
    final nextLayerTable = layerTable.addElement(
      element.id,
      layerId: layerId,
      index: index,
    );
    if (appendLayerId != null) {
      return _withAppendedContentElement(
        element.id,
        layerId: appendLayerId,
        familyTables: familyTables,
        layerTable: nextLayerTable,
        admitsNewLayer: !layerTable.contains(appendLayerId),
      );
    }

    return ElementRegistry._(
      backgroundElementIds: backgroundElementIds,
      familyTables: familyTables,
      layerTable: nextLayerTable,
    );
  }

  ElementRegistry addBackgroundElementStructure(
    CanvasElement element, {
    int? index,
  }) {
    final nextBackgroundIds = backgroundElementIds.toList();
    nextBackgroundIds.insert(
      _clampedInsertIndex(index, nextBackgroundIds.length),
      element.id,
    );

    return ElementRegistry._(
      backgroundElementIds: nextBackgroundIds,
      familyTables: familyTables,
      layerTable: layerTable,
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

  ElementRegistry removeElementStructure(CanvasElementId id) {
    return ElementRegistry._(
      backgroundElementIds: [
        for (final elementId in backgroundElementIds)
          if (elementId != id) elementId,
      ],
      familyTables: familyTables,
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

  ElementRegistry clearContentStructure() {
    return ElementRegistry._(
      backgroundElementIds: const [],
      familyTables: familyTables,
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

final class _ElementRegistryOrderFacts {
  const _ElementRegistryOrderFacts({
    required this.backgroundElementIds,
    required this.contentElementOrder,
    required this.frameElementOrder,
    required this.frameOrderTokensById,
    required this.elementLocationFacts,
    required this.admittedElementIds,
  });

  final List<CanvasElementId> backgroundElementIds;
  final List<CanvasElementId> contentElementOrder;
  final List<CanvasElementId> frameElementOrder;
  final Map<CanvasElementId, int> frameOrderTokensById;
  final Map<CanvasElementId, ElementLocationFacts> elementLocationFacts;
  final Set<String> admittedElementIds;

  factory _ElementRegistryOrderFacts.build(
    Iterable<CanvasElementId> backgroundElementIds,
    LayerTable layerTable,
  ) {
    final accumulator = _ElementRegistryOrderAccumulator();

    for (final id in backgroundElementIds) {
      accumulator.addBackground(id);
    }
    for (final layer in layerTable.rows) {
      final location = ElementLocationFacts.content(layer.id);
      for (final id in layer.elementIds) {
        accumulator.addContent(id, location);
      }
    }

    return accumulator.freeze();
  }
}

final class _ElementRegistryOrderAccumulator {
  final _background = <CanvasElementId>[];
  final _content = <CanvasElementId>[];
  final _frame = <CanvasElementId>[];
  final _tokens = <CanvasElementId, int>{};
  final _locations = <CanvasElementId, ElementLocationFacts>{};
  final _admittedIds = <String>{};

  void addBackground(CanvasElementId id) {
    _background.add(id);
    _admit(id, const ElementLocationFacts.background());
  }

  void addContent(CanvasElementId id, ElementLocationFacts location) {
    _content.add(id);
    _admit(id, location);
  }

  void _admit(CanvasElementId id, ElementLocationFacts location) {
    _tokens[id] = _frame.length;
    _locations[id] = location;
    _admittedIds.add(id.value);
    _frame.add(id);
  }

  _ElementRegistryOrderFacts freeze() {
    return _ElementRegistryOrderFacts(
      backgroundElementIds: List.unmodifiable(_background),
      contentElementOrder: List.unmodifiable(_content),
      frameElementOrder: List.unmodifiable(_frame),
      frameOrderTokensById: Map.unmodifiable(_tokens),
      elementLocationFacts: Map.unmodifiable(_locations),
      admittedElementIds: Set.unmodifiable(_admittedIds),
    );
  }
}

final class ElementRegistrySchemaV1OrderImportBuilder {
  List<CanvasElementId>? _background = [];
  List<CanvasElementId>? _content = [];
  List<CanvasElementId>? _frame = [];
  Map<CanvasElementId, int>? _tokens = {};
  Map<CanvasElementId, ElementLocationFacts>? _locations = {};
  Set<String>? _admittedIds = {};

  void addBackground(CanvasElementId id) {
    _live(_background).add(id);
    _admit(id, const ElementLocationFacts.background());
  }

  void addContent(CanvasLayerId layerId, CanvasElementId id) {
    _live(_content).add(id);
    _admit(id, ElementLocationFacts.content(layerId));
  }

  ElementRegistryOrderImportFacts consume() {
    final background = _live(_background);
    final content = _live(_content);
    final frame = _live(_frame);
    final tokens = _live(_tokens);
    final locations = _live(_locations);
    final admittedIds = _live(_admittedIds);
    _background = null;
    _content = null;
    _frame = null;
    _tokens = null;
    _locations = null;
    _admittedIds = null;

    return ElementRegistryOrderImportFacts._owned(
      backgroundElementIds: background,
      contentElementOrder: content,
      frameElementOrder: frame,
      frameOrderTokensById: tokens,
      elementLocationFacts: locations,
      admittedElementIds: admittedIds,
    );
  }

  void ensureNotConsumed() {
    _live(_frame);
  }

  void _admit(CanvasElementId id, ElementLocationFacts location) {
    final frame = _live(_frame);
    _live(_tokens)[id] = frame.length;
    _live(_locations)[id] = location;
    _live(_admittedIds).add(id.value);
    frame.add(id);
  }

  T _live<T extends Object>(T? value) {
    if (value == null) {
      throw StateError(
        'ElementRegistrySchemaV1OrderImportBuilder was consumed.',
      );
    }

    return value;
  }
}

final class ElementRegistryOrderImportFacts {
  ElementRegistryOrderImportFacts._owned({
    required List<CanvasElementId> backgroundElementIds,
    required List<CanvasElementId> contentElementOrder,
    required List<CanvasElementId> frameElementOrder,
    required Map<CanvasElementId, int> frameOrderTokensById,
    required Map<CanvasElementId, ElementLocationFacts> elementLocationFacts,
    required Set<String> admittedElementIds,
  }) : backgroundElementIds = UnmodifiableListView(backgroundElementIds),
       contentElementOrder = UnmodifiableListView(contentElementOrder),
       frameElementOrder = UnmodifiableListView(frameElementOrder),
       frameOrderTokensById = UnmodifiableMapView(frameOrderTokensById),
       elementLocationFacts = UnmodifiableMapView(elementLocationFacts),
       admittedElementIds = UnmodifiableSetView(admittedElementIds);

  final List<CanvasElementId> backgroundElementIds;
  final List<CanvasElementId> contentElementOrder;
  final List<CanvasElementId> frameElementOrder;
  final Map<CanvasElementId, int> frameOrderTokensById;
  final Map<CanvasElementId, ElementLocationFacts> elementLocationFacts;
  final Set<String> admittedElementIds;
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
