import '../contracts/public/canvas_document.dart';
import '../contracts/public/canvas_element.dart';
import '../contracts/public/canvas_ids.dart';
import 'family_tables.dart';
import 'layer_table.dart';

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
  }) {
    final backgroundElementList = List<CanvasElement>.unmodifiable(
      backgroundElements,
    );
    final layerList = List<CanvasLayer>.unmodifiable(layers);
    final layerRows = LayerTable(
      layerList.map(
        (layer) => LayerRow(
          id: layer.id,
          elementIds: layer.elements.map((element) => element.id),
          metadata: layer.metadata,
        ),
      ),
    );
    final families = FamilyTables([
      ...backgroundElementList,
      for (final layer in layerList) ...layer.elements,
    ], resourceIds: resourceIds);
    final contentOrder = List<CanvasElementId>.unmodifiable([
      for (final row in layerRows.rows)
        for (final id in row.elementIds) id,
    ]);
    final frameOrder = List<CanvasElementId>.unmodifiable([
      for (final element in backgroundElementList) element.id,
      ...contentOrder,
    ]);

    backgroundElementIds = List<CanvasElementId>.unmodifiable(
      backgroundElementList.map((element) => element.id),
    );
    familyTables = families;
    layerTable = layerRows;
    contentElementOrder = contentOrder;
    frameElementOrder = frameOrder;
    admittedElementIds = Set.unmodifiable(families.admittedElementIds);
    admittedLayerIds = Set.unmodifiable(layerRows.admittedIds);
  }

  late final List<CanvasElementId> backgroundElementIds;
  late final FamilyTables familyTables;
  late final LayerTable layerTable;
  late final List<CanvasElementId> contentElementOrder;
  late final List<CanvasElementId> frameElementOrder;
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
    return orderToken >= 0 &&
        orderToken < frameElementOrder.length &&
        frameElementOrder[orderToken] == id;
  }
}
