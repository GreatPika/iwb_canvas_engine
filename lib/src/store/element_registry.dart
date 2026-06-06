import '../contracts/public/canvas_document.dart';
import '../contracts/public/canvas_element.dart';
import '../contracts/public/canvas_ids.dart';
import 'family_tables.dart';
import 'layer_table.dart';

// ElementRegistry is the committed element table aggregate; keeping sparse row
// operations with lookup/order facts prevents a second source of truth.
// ignore: number-of-methods, response-for-class
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
    return ElementRegistry._(
      backgroundElementIds: backgroundElementIds,
      familyTables: familyTables.addElement(element, resourceIds),
      layerTable: layerTable.addElement(
        element.id,
        layerId: layerId,
        index: index,
      ),
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
  }) {
    final before = familyTables.elementByCanvasId(element.id);
    if (before == null) {
      return null;
    }
    final updatedFamilyTables = familyTables.replaceElement(
      before,
      element,
      resourceIds,
    );
    if (updatedFamilyTables == null) {
      return null;
    }

    return ElementRegistry._(
      backgroundElementIds: backgroundElementIds,
      familyTables: updatedFamilyTables,
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

  ElementRegistry clearContent() {
    return ElementRegistry._(
      backgroundElementIds: const [],
      familyTables: familyTables.clearElements(),
      layerTable: layerTable.clearElements(),
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
