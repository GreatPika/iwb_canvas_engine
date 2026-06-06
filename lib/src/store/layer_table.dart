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

  bool contains(CanvasLayerId id) => admittedIds.contains(id.value);

  LayerTable ensureLayer(CanvasLayerId id, {int? index}) {
    if (contains(id)) {
      return this;
    }
    final nextRows = rows.map(_copyRow).toList();
    final targetIndex = _clampedInsertIndex(index, nextRows.length);
    nextRows.insert(
      targetIndex,
      LayerRow(
        id: id,
        elementIds: const [],
        metadata: const CanvasMetadata.empty(),
      ),
    );

    return LayerTable(nextRows);
  }

  // Layer insertion stays in one method so default-layer creation and target
  // row insertion remain one ordered table update.
  // ignore: halstead-volume
  LayerTable addElement(
    CanvasElementId id, {
    CanvasLayerId? layerId,
    int? index,
  }) {
    final nextRows = rows.map(_copyRow).toList();
    var targetIndex = nextRows.length - 1;
    if (layerId != null) {
      targetIndex = nextRows.indexWhere((row) => row.id == layerId);
      if (targetIndex == -1) {
        nextRows.add(
          LayerRow(
            id: layerId,
            elementIds: const [],
            metadata: const CanvasMetadata.empty(),
          ),
        );
        targetIndex = nextRows.length - 1;
      }
    } else if (targetIndex == -1) {
      nextRows.add(
        LayerRow(
          id: CanvasLayerId('default-layer'),
          elementIds: const [],
          metadata: const CanvasMetadata.empty(),
        ),
      );
      targetIndex = 0;
    }

    final row = nextRows[targetIndex];
    final elementIds = row.elementIds.toList();
    elementIds.insert(_clampedInsertIndex(index, elementIds.length), id);
    nextRows[targetIndex] = LayerRow(
      id: row.id,
      elementIds: elementIds,
      metadata: row.metadata,
    );

    return LayerTable(nextRows);
  }

  LayerTable removeElement(CanvasElementId id) {
    return LayerTable([
      for (final row in rows)
        LayerRow(
          id: row.id,
          elementIds: [
            for (final elementId in row.elementIds)
              if (elementId != id) elementId,
          ],
          metadata: row.metadata,
        ),
    ]);
  }

  LayerTable clearElements() {
    return LayerTable([
      for (final row in rows)
        LayerRow(id: row.id, elementIds: const [], metadata: row.metadata),
    ]);
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

LayerRow _copyRow(LayerRow row) {
  return LayerRow(
    id: row.id,
    elementIds: row.elementIds,
    metadata: row.metadata,
  );
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
