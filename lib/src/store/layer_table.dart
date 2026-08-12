import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart' show immutable, visibleForTesting;

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

@immutable
final class LayerLocationFacts {
  const LayerLocationFacts({required this.row, required this.index});

  final LayerRow row;
  final int index;
}

@visibleForTesting
enum LayerTableWorkEvent {
  constructionInputRowVisit,
  schemaImportInputRowVisit,
  constructionPublishedRowVisit,
  schemaImportPublishedRowVisit,
  mutationRowVisit,
  locationRebuildRowVisit,
  locationUpdate,
  locationPublication,
  locationFactEntryVisit,
  fullLocationMapCopy,
  discard,
  unchangedLocationFactIdentityRetain,
  membershipLookup,
  membershipLocationRead,
  membershipRowVisit,
  rowIndexRowVisit,
  rowIndexLocationRead,
  placementRowVisit,
  placementLocationRead,
  perLayerElementRowVisit,
  perLayerElementLocationRead,
  intentionalIterationRowVisit,
  admissionEnumerationOpen,
  admissionEnumerationEntry,
  admissionEnumerationClose,
}

// Internal consumers use this only to classify owner work when an observer is
// installed; it does not supply results or retain production telemetry.
enum LayerTableReadScope {
  membership,
  rowIndex,
  placement,
  perLayerElements,
  intentionalIteration,
}

enum _LayerTableTraversalScope { construction, schemaImport, mutation }

// The table keeps row mutation and its atomically published derived location
// together; splitting either solely for metrics would obscure that invariant.
// ignore: coupling-between-object-classes, number-of-methods, response-for-class, weighted-methods-per-class
final class LayerTable {
  static final Object _workZoneKey = Object();
  static final Object _readScopeZoneKey = Object();
  static final Object _traversalScopeZoneKey = Object();

  const LayerTable.empty()
    : rows = const _LayerRowsView(<LayerRow>[]),
      layerLocationFacts = const _LayerLocationFactsView(
        <CanvasLayerId, LayerLocationFacts>{},
      );

  LayerTable(Iterable<LayerRow> rows)
    : this._fromFacts(
        _withTraversalScope(
          _LayerTableTraversalScope.construction,
          () => _admitRows(
            _ObservedInput<LayerRow>(
              rows,
              LayerTableWorkEvent.constructionInputRowVisit,
            ),
          ),
        ),
      );

  LayerTable._fromFacts(_LayerTableFacts facts)
    : rows = _publishedRows(facts.rows),
      layerLocationFacts = _LayerLocationFactsView(facts.layerLocationFacts);

  final List<LayerRow> rows;
  final Map<CanvasLayerId, LayerLocationFacts> layerLocationFacts;

  // Complete-id consumers receive each committed row id immediately; no
  // membership collection is retained for admission.
  void enumerateLayerIds(void Function(String) accept) {
    _recordWork(LayerTableWorkEvent.admissionEnumerationOpen);
    try {
      for (final row in rows) {
        _recordWork(LayerTableWorkEvent.admissionEnumerationEntry);
        accept(row.id.value);
      }
    } finally {
      _recordWork(LayerTableWorkEvent.admissionEnumerationClose);
    }
  }

  static List<LayerRow> _publishedRows(List<LayerRow> rows) {
    return rows is _LayerRowsView ? rows : _LayerRowsView(rows);
  }

  bool contains(CanvasLayerId id) {
    return withReadScope(LayerTableReadScope.membership, () {
      _recordWork(LayerTableWorkEvent.membershipLookup);
      _recordWork(LayerTableWorkEvent.membershipLocationRead);
      return layerLocationFacts.containsKey(id);
    });
  }

  LayerLocationFacts? locationFor(CanvasLayerId id) {
    switch (Zone.current[_readScopeZoneKey]) {
      case LayerTableReadScope.membership:
      case LayerTableReadScope.rowIndex:
        _recordWork(LayerTableWorkEvent.rowIndexLocationRead);
      case LayerTableReadScope.placement:
        _recordWork(LayerTableWorkEvent.placementLocationRead);
      case LayerTableReadScope.perLayerElements:
        _recordWork(LayerTableWorkEvent.perLayerElementLocationRead);
      case LayerTableReadScope.intentionalIteration:
      case null:
        break;
    }
    return layerLocationFacts[id];
  }

  // The observation is assert-gated and carries only a semantic event. Tests
  // own any accumulation so production retains no telemetry state or facts.
  @visibleForTesting
  static T observeWork<T>(
    void Function(LayerTableWorkEvent event) sink,
    T Function() operation,
  ) {
    return runZoned(operation, zoneValues: {_workZoneKey: sink});
  }

  static T withReadScope<T>(LayerTableReadScope scope, T Function() operation) {
    var observesWork = false;
    assert(() {
      observesWork =
          Zone.current[_workZoneKey] is void Function(LayerTableWorkEvent);
      return true;
    }(), 'layer table work observation failed');
    if (!observesWork) {
      return operation();
    }
    return runZoned(operation, zoneValues: {_readScopeZoneKey: scope});
  }

  static Iterable<T> withReadScopeIterable<T>(
    LayerTableReadScope scope,
    Iterable<T> Function() operation,
  ) {
    var observesWork = false;
    assert(() {
      observesWork =
          Zone.current[_workZoneKey] is void Function(LayerTableWorkEvent);
      return true;
    }(), 'layer table work observation failed');
    if (!observesWork) {
      return operation();
    }
    final scopedZone = Zone.current.fork(
      zoneValues: {_readScopeZoneKey: scope},
    );
    return _ScopedIterable<T>(operation(), scopedZone);
  }

  static T _withTraversalScope<T>(
    _LayerTableTraversalScope scope,
    T Function() operation,
  ) {
    return runZoned(operation, zoneValues: {_traversalScopeZoneKey: scope});
  }

  static void _recordPublishedRowVisit() {
    switch (Zone.current[_traversalScopeZoneKey]) {
      case _LayerTableTraversalScope.mutation:
        _recordWork(LayerTableWorkEvent.mutationRowVisit);
      case _LayerTableTraversalScope.construction:
        _recordWork(LayerTableWorkEvent.constructionPublishedRowVisit);
      case _LayerTableTraversalScope.schemaImport:
        _recordWork(LayerTableWorkEvent.schemaImportPublishedRowVisit);
      case null:
        switch (Zone.current[_readScopeZoneKey]) {
          case LayerTableReadScope.membership:
            _recordWork(LayerTableWorkEvent.membershipRowVisit);
          case LayerTableReadScope.rowIndex:
            _recordWork(LayerTableWorkEvent.rowIndexRowVisit);
          case LayerTableReadScope.placement:
            _recordWork(LayerTableWorkEvent.placementRowVisit);
          case LayerTableReadScope.perLayerElements:
            _recordWork(LayerTableWorkEvent.perLayerElementRowVisit);
          case LayerTableReadScope.intentionalIteration:
            _recordWork(LayerTableWorkEvent.intentionalIterationRowVisit);
          case null:
            break;
        }
    }
  }

  static void _recordLocationFactEntryVisit() {
    _recordWork(LayerTableWorkEvent.locationFactEntryVisit);
  }

  static void _recordLocationFactTraversalOpen() {
    if (Zone.current[_traversalScopeZoneKey] != null) {
      _recordWork(LayerTableWorkEvent.fullLocationMapCopy);
    }
  }

  static void _recordWork(LayerTableWorkEvent event) {
    assert(() {
      final sink = Zone.current[_workZoneKey];
      if (sink is void Function(LayerTableWorkEvent)) {
        sink(event);
      }
      return true;
    }(), 'layer table work observation failed');
  }

  LayerTable ensureLayer(CanvasLayerId id, {int? index}) {
    if (contains(id)) {
      _recordWork(LayerTableWorkEvent.unchangedLocationFactIdentityRetain);
      return this;
    }
    final targetIndex = _clampedInsertIndex(index, rows.length);

    return _insertRow(
      targetIndex,
      LayerRow(
        id: id,
        elementIds: const [],
        metadata: const CanvasMetadata.empty(),
      ),
    );
  }

  // Layer insertion stays in one method so default-layer creation and target
  // row insertion remain one ordered table update.
  // ignore: halstead-volume
  LayerTable addElement(
    CanvasElementId id, {
    CanvasLayerId? layerId,
    int? index,
  }) {
    final target = withReadScope(LayerTableReadScope.placement, () {
      LayerRow? targetRow;
      var targetIndex = rows.length - 1;
      if (layerId != null) {
        final location = locationFor(layerId);
        targetIndex = location?.index ?? rows.length;
        targetRow = location?.row;
      } else if (targetIndex == -1) {
        targetIndex = 0;
        targetRow = LayerRow(
          id: CanvasLayerId('default-layer'),
          elementIds: const [],
          metadata: const CanvasMetadata.empty(),
        );
      } else {
        targetRow = rows[targetIndex];
      }

      return (row: targetRow, index: targetIndex);
    });

    final row =
        target.row ??
        LayerRow(
          id: layerId ?? CanvasLayerId('default-layer'),
          elementIds: const [],
          metadata: const CanvasMetadata.empty(),
        );
    final elementIds = row.elementIds.toList();
    elementIds.insert(_clampedInsertIndex(index, elementIds.length), id);
    final nextRow = LayerRow(
      id: row.id,
      elementIds: elementIds,
      metadata: row.metadata,
    );

    return target.index == rows.length
        ? _insertRow(target.index, nextRow)
        : _replaceRow(target.index, nextRow);
  }

  LayerTable removeElement(
    CanvasElementId id, {
    required CanvasLayerId layerId,
  }) {
    final location = locationFor(layerId);
    if (location == null || !location.row.elementIds.contains(id)) {
      _recordWork(LayerTableWorkEvent.unchangedLocationFactIdentityRetain);
      return this;
    }

    return _replaceRow(
      location.index,
      LayerRow(
        id: location.row.id,
        elementIds: location.row.elementIds.where(
          (elementId) => elementId != id,
        ),
        metadata: location.row.metadata,
      ),
    );
  }

  LayerTable clearElements({required bool hasContent}) {
    if (!hasContent) {
      _recordWork(LayerTableWorkEvent.unchangedLocationFactIdentityRetain);
      return this;
    }
    return _withTraversalScope(_LayerTableTraversalScope.mutation, () {
      final builder = _LayerTableBuilder();
      for (final row in rows) {
        if (row.elementIds.isEmpty) {
          builder.append(row, previous: layerLocationFacts[row.id]);
        } else {
          builder.append(
            LayerRow(id: row.id, elementIds: const [], metadata: row.metadata),
          );
        }
      }

      return LayerTable._fromFacts(builder.build());
    });
  }

  LayerTable _insertRow(int index, LayerRow row) {
    return _withTraversalScope(_LayerTableTraversalScope.mutation, () {
      final builder = _LayerTableBuilder();
      var sourceIndex = 0;
      for (final sourceRow in rows) {
        if (sourceIndex == index) {
          builder.append(row);
        }
        builder.append(sourceRow, previous: layerLocationFacts[sourceRow.id]);
        sourceIndex += 1;
      }
      if (index == rows.length) {
        builder.append(row);
      }

      return LayerTable._fromFacts(builder.build());
    });
  }

  LayerTable _replaceRow(int index, LayerRow row) {
    return _withTraversalScope(_LayerTableTraversalScope.mutation, () {
      final builder = _LayerTableBuilder();
      var sourceIndex = 0;
      for (final sourceRow in rows) {
        final nextRow = sourceIndex == index ? row : sourceRow;
        builder.append(
          nextRow,
          previous: sourceIndex == index
              ? null
              : layerLocationFacts[sourceRow.id],
        );
        sourceIndex += 1;
      }

      return LayerTable._fromFacts(builder.build());
    });
  }
}

// This import builder owns the one-shot pending-row lifecycle and its atomic
// publication; splitting its construction dependencies would hide that seam.
// ignore: coupling-between-object-classes
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
    return LayerTable._withTraversalScope(
      _LayerTableTraversalScope.schemaImport,
      () {
        final builder = _LayerTableBuilder();
        for (final row in _ObservedInput<_PendingLayerRow>(
          rows,
          LayerTableWorkEvent.schemaImportInputRowVisit,
        )) {
          builder.append(
            LayerRow._owned(
              id: row.id,
              elementIds: row.elementIds,
              metadata: row.metadata,
            ),
          );
        }

        return LayerTable._fromFacts(builder.build());
      },
    );
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

_LayerTableFacts _admitRows(Iterable<LayerRow> rows) {
  final builder = _LayerTableBuilder();
  for (final row in rows) {
    if (builder.contains(row.id)) {
      builder.discard();
      throw CanvasDataException(
        code: CanvasDataErrorCode.duplicateLayerId,
        message: 'duplicate layer id.',
        path: 'layers.id',
      );
    }
    builder.append(row);
  }

  return builder.build();
}

final class _LayerTableFacts {
  _LayerTableFacts({required this.rows, required this.layerLocationFacts});

  final List<LayerRow> rows;
  final Map<CanvasLayerId, LayerLocationFacts> layerLocationFacts;
}

final class _ObservedInput<T> extends IterableBase<T> {
  _ObservedInput(this._rows, this._event, {void Function()? onOpen})
    : _onOpen = onOpen;

  final Iterable<T> _rows;
  final LayerTableWorkEvent _event;
  final void Function()? _onOpen;

  @override
  Iterator<T> get iterator {
    _onOpen?.call();
    return _ObservedIterator<T>(
      _rows.iterator,
      () => LayerTable._recordWork(_event),
    );
  }
}

final class _LayerRowsView extends ListBase<LayerRow> {
  const _LayerRowsView(this._rows);

  final List<LayerRow> _rows;

  @override
  int get length => _rows.length;

  @override
  set length(int value) => throw UnsupportedError('Layer rows are immutable.');

  @override
  LayerRow operator [](int index) {
    LayerTable._recordPublishedRowVisit();
    return _rows[index];
  }

  @override
  void operator []=(int index, LayerRow value) {
    throw UnsupportedError('Layer rows are immutable.');
  }

  @override
  Iterator<LayerRow> get iterator => _ObservedIterator<LayerRow>(
    _rows.iterator,
    LayerTable._recordPublishedRowVisit,
  );
}

// MapBase requires the complete immutable Map surface here; extracting its
// overrides would obscure the one owner boundary that records traversal.
// ignore: number-of-methods
final class _LayerLocationFactsView
    extends MapBase<CanvasLayerId, LayerLocationFacts> {
  const _LayerLocationFactsView(this._facts);

  final Map<CanvasLayerId, LayerLocationFacts> _facts;

  @override
  LayerLocationFacts? operator [](Object? key) => _facts[key];

  @override
  Iterable<CanvasLayerId> get keys => _observed(_facts.keys);

  @override
  bool containsKey(Object? key) => _facts.containsKey(key);

  @override
  Iterable<LayerLocationFacts> get values => _observed(_facts.values);

  @override
  Iterable<MapEntry<CanvasLayerId, LayerLocationFacts>> get entries =>
      _observed(_facts.entries);

  @override
  int get length => _facts.length;

  @override
  void forEach(
    void Function(CanvasLayerId key, LayerLocationFacts value) action,
  ) {
    LayerTable._recordLocationFactTraversalOpen();
    _facts.forEach((key, value) {
      LayerTable._recordLocationFactEntryVisit();
      action(key, value);
    });
  }

  @override
  void operator []=(CanvasLayerId key, LayerLocationFacts value) {
    throw UnsupportedError('Layer location facts are immutable.');
  }

  @override
  void clear() {
    throw UnsupportedError('Layer location facts are immutable.');
  }

  @override
  LayerLocationFacts? remove(Object? key) {
    throw UnsupportedError('Layer location facts are immutable.');
  }

  Iterable<T> _observed<T>(Iterable<T> values) {
    return _ObservedInput<T>(
      values,
      LayerTableWorkEvent.locationFactEntryVisit,
      onOpen: LayerTable._recordLocationFactTraversalOpen,
    );
  }
}

final class _LayerTableBuilder {
  final _rows = _LayerRowBuffer();
  final _layerLocationFacts = _LayerLocationFactsBuffer();
  var _consumed = false;

  bool contains(CanvasLayerId id) {
    _ensureLive();
    return _layerLocationFacts.containsKey(id);
  }

  void append(LayerRow row, {LayerLocationFacts? previous}) {
    _ensureLive();
    final index = _rows.length;
    _rows.add(row);
    if (previous != null &&
        identical(previous.row, row) &&
        previous.index == index) {
      _layerLocationFacts[row.id] = previous;
      LayerTable._recordWork(
        LayerTableWorkEvent.unchangedLocationFactIdentityRetain,
      );
      return;
    }
    _layerLocationFacts[row.id] = LayerLocationFacts(row: row, index: index);
    LayerTable._recordWork(LayerTableWorkEvent.locationUpdate);
  }

  _LayerTableFacts build() {
    _ensureLive();
    final rows = _rows.takeOwnership();
    final layerLocationFacts = _layerLocationFacts.takeOwnership();
    _consumed = true;
    LayerTable._recordWork(LayerTableWorkEvent.locationPublication);
    return _LayerTableFacts(rows: rows, layerLocationFacts: layerLocationFacts);
  }

  void discard() {
    _ensureLive();
    _rows.discard();
    _layerLocationFacts.discard();
    _consumed = true;
    LayerTable._recordWork(LayerTableWorkEvent.discard);
  }

  void _ensureLive() {
    if (_consumed) {
      throw StateError('Layer table builder was consumed.');
    }
  }
}

final class _LayerRowBuffer extends ListBase<LayerRow> {
  List<LayerRow>? _rows = [];

  List<LayerRow> get _liveRows {
    final rows = _rows;
    if (rows == null) {
      throw StateError('Layer row buffer was consumed.');
    }
    return rows;
  }

  @override
  int get length => _liveRows.length;

  @override
  set length(int value) => _liveRows.length = value;

  @override
  LayerRow operator [](int index) {
    LayerTable._recordWork(LayerTableWorkEvent.locationRebuildRowVisit);
    return _liveRows[index];
  }

  @override
  void operator []=(int index, LayerRow value) {
    _liveRows[index] = value;
  }

  @override
  void add(LayerRow value) {
    _liveRows.add(value);
  }

  @override
  Iterator<LayerRow> get iterator => _ObservedIterator<LayerRow>(
    _liveRows.iterator,
    () => LayerTable._recordWork(LayerTableWorkEvent.locationRebuildRowVisit),
  );

  List<LayerRow> takeOwnership() {
    final rows = _liveRows;
    _rows = null;
    return rows;
  }

  void discard() {
    _rows = null;
  }
}

// This mutable builder buffer keeps the complete MapBase surface at the one
// raw-fact owner so every traversal is observed before zero-copy publication.
// ignore: number-of-methods
final class _LayerLocationFactsBuffer
    extends MapBase<CanvasLayerId, LayerLocationFacts> {
  Map<CanvasLayerId, LayerLocationFacts>? _facts = {};

  Map<CanvasLayerId, LayerLocationFacts> get _liveFacts {
    final facts = _facts;
    if (facts == null) {
      throw StateError('Layer location facts buffer was consumed.');
    }
    return facts;
  }

  @override
  LayerLocationFacts? operator [](Object? key) => _liveFacts[key];

  @override
  Iterable<CanvasLayerId> get keys => _observed(_liveFacts.keys);

  @override
  bool containsKey(Object? key) => _liveFacts.containsKey(key);

  @override
  Iterable<LayerLocationFacts> get values => _observed(_liveFacts.values);

  @override
  Iterable<MapEntry<CanvasLayerId, LayerLocationFacts>> get entries =>
      _observed(_liveFacts.entries);

  @override
  int get length => _liveFacts.length;

  @override
  void operator []=(CanvasLayerId key, LayerLocationFacts value) {
    _liveFacts[key] = value;
  }

  @override
  void clear() {
    _liveFacts.clear();
  }

  @override
  LayerLocationFacts? remove(Object? key) => _liveFacts.remove(key);

  @override
  void forEach(
    void Function(CanvasLayerId key, LayerLocationFacts value) action,
  ) {
    LayerTable._recordLocationFactTraversalOpen();
    _liveFacts.forEach((key, value) {
      LayerTable._recordLocationFactEntryVisit();
      action(key, value);
    });
  }

  Map<CanvasLayerId, LayerLocationFacts> takeOwnership() {
    final facts = _liveFacts;
    _facts = null;
    return facts;
  }

  void discard() {
    _facts = null;
  }

  Iterable<T> _observed<T>(Iterable<T> values) {
    return _ObservedInput<T>(
      values,
      LayerTableWorkEvent.locationFactEntryVisit,
      onOpen: LayerTable._recordLocationFactTraversalOpen,
    );
  }
}

final class _ObservedIterator<T> implements Iterator<T> {
  _ObservedIterator(this._iterator, this._onVisit);

  final Iterator<T> _iterator;
  final void Function() _onVisit;

  @override
  T get current => _iterator.current;

  @override
  bool moveNext() {
    final hasNext = _iterator.moveNext();
    if (hasNext) {
      _onVisit();
    }
    return hasNext;
  }
}

final class _ScopedIterable<T> extends IterableBase<T> {
  _ScopedIterable(this._values, this._zone);

  final Iterable<T> _values;
  final Zone _zone;

  @override
  Iterator<T> get iterator => _ScopedIterator<T>(_values.iterator, _zone);
}

final class _ScopedIterator<T> implements Iterator<T> {
  _ScopedIterator(this._iterator, this._zone);

  final Iterator<T> _iterator;
  final Zone _zone;

  @override
  T get current => _iterator.current;

  @override
  bool moveNext() => _zone.run(_iterator.moveNext);
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
