import '../contracts/public/canvas_ids.dart';
import '../contracts/public/canvas_metadata.dart';
import '../contracts/public/canvas_errors.dart';

final class LayerRow {
  LayerRow({
    required this.id,
    required Iterable<CanvasElementId> elementIds,
    required this.metadata,
  }) : elementIds = List.unmodifiable(elementIds);

  final CanvasLayerId id;
  final List<CanvasElementId> elementIds;
  final CanvasMetadata metadata;
}

final class LayerTable {
  LayerTable(Iterable<LayerRow> rows)
    : rows = List.unmodifiable(_admitRows(rows));

  final List<LayerRow> rows;

  Set<String> get admittedIds {
    return {for (final row in rows) row.id.value};
  }
}

List<LayerRow> _admitRows(Iterable<LayerRow> rows) {
  final admittedIds = <String>{};
  final admittedRows = <LayerRow>[];
  for (final row in rows) {
    if (!admittedIds.add(row.id.value)) {
      throw CanvasDataException(
        code: CanvasDataErrorCode.duplicateLayerId,
        message: 'duplicate layer id.',
        path: 'layers.id',
      );
    }
    admittedRows.add(row);
  }

  return admittedRows;
}
