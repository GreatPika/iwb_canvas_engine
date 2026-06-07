import 'dart:collection';

import '../contracts/internal/schema_v1_import_events.dart';
import '../contracts/public/canvas_errors.dart';
import '../contracts/public/canvas_ids.dart';
import '../contracts/public/canvas_metadata.dart';

final class LayerRow {
  LayerRow({
    required this.id,
    required Iterable<CanvasElementId> elementIds,
    required this.metadata,
  }) : elementIds = List.unmodifiable(elementIds);

  LayerRow._owned({
    required this.id,
    required List<CanvasElementId> elementIds,
    required this.metadata,
  }) : elementIds = UnmodifiableListView(elementIds);

  final CanvasLayerId id;
  final List<CanvasElementId> elementIds;
  final CanvasMetadata metadata;
}

final class LayerTable {
  const LayerTable.empty() : rows = const [];

  LayerTable(Iterable<LayerRow> rows)
    : rows = List.unmodifiable(_admitRows(rows));

  LayerTable._owned(List<LayerRow> rows) : rows = UnmodifiableListView(rows);

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

final class LayerTableSchemaV1ImportBuilder {
  List<_PendingLayerRow>? _rows = [];
  final Set<String> _admittedLayerIds = {};
  _PendingLayerRow? _currentLayer;

  void addLayer(SchemaV1LayerImportEvent event) {
    final rows = _liveRows;
    if (!_admittedLayerIds.add(event.id.value)) {
      throw CanvasDataException(
        code: CanvasDataErrorCode.duplicateLayerId,
        message: 'duplicate layer id.',
        path: 'layers.id',
      );
    }
    final row = _PendingLayerRow(id: event.id, metadata: event.metadata);
    rows.add(row);
    _currentLayer = row;
  }

  void addElement(CanvasLayerId layerId, CanvasElementId elementId) {
    _ensureNotConsumed();
    final layer = _currentLayer;
    if (layer == null || layer.id != layerId) {
      throw StateError('schema v1 layer element arrived before its layer.');
    }
    layer.elementIds.add(elementId);
  }

  LayerTable consume() {
    final rows = _liveRows;
    _rows = null;
    _currentLayer = null;

    return LayerTable._owned([
      for (final row in rows)
        LayerRow._owned(
          id: row.id,
          elementIds: row.elementIds,
          metadata: row.metadata,
        ),
    ]);
  }

  List<_PendingLayerRow> get _liveRows {
    final rows = _rows;
    if (rows == null) {
      throw StateError('LayerTableSchemaV1ImportBuilder was consumed.');
    }

    return rows;
  }

  void _ensureNotConsumed() {
    _liveRows;
  }
}

final class _PendingLayerRow {
  _PendingLayerRow({required this.id, required this.metadata});

  final CanvasLayerId id;
  final CanvasMetadata metadata;
  final List<CanvasElementId> elementIds = [];
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
