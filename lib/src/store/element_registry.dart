import '../api/canvas_document.dart';
import '../api/canvas_element.dart';
import '../api/canvas_ids.dart';
import 'family_tables.dart';
import 'layer_table.dart';

final class ElementRegistry {
  ElementRegistry({
    required Iterable<CanvasElement> backgroundElements,
    required Iterable<CanvasLayer> layers,
    required Set<String> resourceIds,
  }) : backgroundElementIds = List.unmodifiable(
         backgroundElements.map((element) => element.id),
       ),
       familyTables = FamilyTables([
         ...backgroundElements,
         for (final layer in layers) ...layer.elements,
       ], resourceIds: resourceIds),
       layerTable = LayerTable(
         layers.map(
           (layer) => LayerRow(
             id: layer.id,
             elementIds: layer.elements.map((element) => element.id),
             metadata: layer.metadata,
           ),
         ),
       );

  final List<CanvasElementId> backgroundElementIds;
  final FamilyTables familyTables;
  final LayerTable layerTable;

  int get elementCount {
    return backgroundElementIds.length +
        layerTable.rows.fold<int>(
          0,
          (count, row) => count + row.elementIds.length,
        );
  }

  Set<String> get admittedElementIds => familyTables.admittedElementIds;
  Set<String> get admittedLayerIds => layerTable.admittedIds;
}
