import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart' show visibleForTesting;

import '../contracts/public/canvas_document.dart';
import '../contracts/public/canvas_element.dart';
import '../contracts/public/canvas_ids.dart';
import '../contracts/public/canvas_metadata.dart';
import 'family_tables.dart';
import 'indexed_order_sequence.dart';
import 'layer_table.dart';

@visibleForTesting
enum ElementRegistryStructuralOrderKind { layer, background, content }

@visibleForTesting
enum ElementRegistryStructuralEditorWorkKind {
  editorOpen,
  orderOpen,
  clearContentTraversalVisit,
  finalTraversalVisit,
  layerRowsPublication,
  layerLocationsPublication,
  backgroundOrderPublication,
  contentOrderPublication,
  frameOrderPublication,
  frameTokenPublication,
  elementLocationPublication,
  finalIdentityRetain,
  discard,
  postClosureAttempt,
}

// Structural-editor events describe one owner lifecycle and never report a
// result back into production. Test code owns observation and aggregation.
@visibleForTesting
final class ElementRegistryStructuralEditorWorkEvent {
  const ElementRegistryStructuralEditorWorkEvent({
    required this.kind,
    this.order,
  });

  final ElementRegistryStructuralEditorWorkKind kind;
  final ElementRegistryStructuralOrderKind? order;
}

// These are immutable comparisons from the structural editor's one final
// traversal. Store consumes them for revision classification without reading
// the materialized registry a second time.
final class ElementRegistryStructuralComparisonFacts {
  const ElementRegistryStructuralComparisonFacts({
    required this.elementCountChanged,
    required this.backgroundOrderChanged,
    required this.flatContentOrderChanged,
    required this.contentPlacementChanged,
    required this.frameOrderChanged,
    required this.elementLocationFactsChanged,
    required this.layerStructureChanged,
    required this.layerOrderChanged,
    required this.layerMetadataChanged,
  });

  const ElementRegistryStructuralComparisonFacts.unchanged()
    : elementCountChanged = false,
      backgroundOrderChanged = false,
      flatContentOrderChanged = false,
      contentPlacementChanged = false,
      frameOrderChanged = false,
      elementLocationFactsChanged = false,
      layerStructureChanged = false,
      layerOrderChanged = false,
      layerMetadataChanged = false;

  final bool elementCountChanged;
  final bool backgroundOrderChanged;
  final bool flatContentOrderChanged;
  final bool contentPlacementChanged;
  final bool frameOrderChanged;
  final bool elementLocationFactsChanged;
  final bool layerStructureChanged;
  final bool layerOrderChanged;
  final bool layerMetadataChanged;
}

// ElementRegistry is the committed element table aggregate; keeping sparse row
// operations with lookup/order facts prevents a second source of truth.
// Sparse append overlays belong here so order and location facts stay one
// atomic registry snapshot instead of drifting across helpers.
// ignore: coupling-between-object-classes, number-of-methods, response-for-class, weighted-methods-per-class
final class ElementRegistry {
  ElementRegistry.empty()
    : this._(
        backgroundElementIds: const [],
        familyTables: const FamilyTables.empty(),
        layerTable: const LayerTable.empty(),
      );

  // The constructor materializes one committed element registry snapshot:
  // family rows, layer rows, content order, and frame order must stay aligned
  // from the same input pass instead of drifting through
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
  }

  ElementRegistry._withUpdatedFamilies({
    required this.familyTables,
    required this.layerTable,
    required this.backgroundElementIds,
    required this.contentElementOrder,
    required this.frameElementOrder,
    required this.frameOrderTokensById,
    required this.elementLocationFacts,
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
    );
  }

  late final List<CanvasElementId> backgroundElementIds;
  late final FamilyTables familyTables;
  late final LayerTable layerTable;
  late final List<CanvasElementId> contentElementOrder;
  late final List<CanvasElementId> frameElementOrder;
  late final Map<CanvasElementId, int> frameOrderTokensById;
  late final Map<CanvasElementId, ElementLocationFacts> elementLocationFacts;

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

  // Sparse structural mutation owns one transaction-local lifecycle. The
  // wrapper is intentionally the only entry point that can leave a live
  // editor: successful callbacks consume it and every other exit discards it.
  static T editSparseStructure<T>(
    ElementRegistry base,
    T Function(ElementRegistryStructuralEditor editor) operation,
  ) {
    final editor = ElementRegistryStructuralEditor._(base);
    try {
      return operation(editor);
    } finally {
      if (!editor.isClosed) {
        editor.discard();
      }
    }
  }

  @visibleForTesting
  static T observeSparseStructuralEditorWork<T>(
    void Function(ElementRegistryStructuralEditorWorkEvent event) sink,
    T Function() operation,
  ) {
    return runZoned(
      operation,
      zoneValues: {ElementRegistryStructuralEditor._workZoneKey: sink},
    );
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
    );
  }

  ElementRegistry ensureLayer(CanvasLayerId id, {int? index}) {
    return editSparseStructure(this, (editor) {
      editor.ensureLayer(id, index: index);
      return editor.freeze(familyTables: familyTables);
    });
  }

  ElementRegistry addElement(
    CanvasElement element, {
    CanvasLayerId? layerId,
    int? index,
  }) {
    return editSparseStructure(this, (editor) {
      editor.addContentElement(element.id, layerId: layerId, index: index);
      return editor.freeze(familyTables: familyTables.addElement(element));
    });
  }

  ElementRegistry addBackgroundElement(CanvasElement element, {int? index}) {
    return editSparseStructure(this, (editor) {
      editor.addBackgroundElement(element.id, index: index);
      return editor.freeze(familyTables: familyTables.addElement(element));
    });
  }

  ElementRegistry removeElement(CanvasElementId id) {
    return editSparseStructure(this, (editor) {
      editor.removeElement(id);
      return editor.freeze(familyTables: familyTables.removeElement(id));
    });
  }
}

// The editor keeps current layer and element placement facts together with the
// owner-local sequences. It is not an admission/touched mirror: family rows
// remain with FamilyTables and every structural decision goes through this
// state until one final integrated traversal seals it.
// ignore: coupling-between-object-classes, number-of-methods, response-for-class, weighted-methods-per-class
final class ElementRegistryStructuralEditor {
  ElementRegistryStructuralEditor._(this._base) {
    _record(ElementRegistryStructuralEditorWorkKind.editorOpen);
  }

  static final Object _workZoneKey = Object();

  final ElementRegistry _base;
  final Map<CanvasLayerId, _StructuralLayerState> _layerStates = {};
  final Map<CanvasElementId, ElementLocationFacts?> _locationChanges = {};
  IndexedOrderSequence<CanvasLayerId, CanvasLayerId>? _layerOrder;
  IndexedOrderSequence<CanvasElementId, CanvasElementId>? _backgroundOrder;
  int? _contentElementCount;
  var _contentCleared = false;
  var _changed = false;
  var _finalized = false;
  var _closed = false;
  ElementRegistryStructuralComparisonFacts? _finalizedComparisonFacts;
  _PreparedElementRegistryStructuralFacts? _preparedStructuralFacts;

  bool get isClosed => _closed;

  ElementRegistryStructuralComparisonFacts get finalizedComparisonFacts {
    if (!_finalized || _closed) {
      _record(ElementRegistryStructuralEditorWorkKind.postClosureAttempt);
      throw StateError(
        'ElementRegistryStructuralEditor has no live final comparison facts.',
      );
    }
    final facts = _finalizedComparisonFacts;
    if (facts == null) {
      throw StateError(
        'ElementRegistryStructuralEditor lost its final comparison facts.',
      );
    }
    return facts;
  }

  Iterable<CanvasElementId> get finalizedFrameElementIds {
    final facts = _finalizedComparisonFacts;
    if (!_finalized || _closed || facts == null) {
      _record(ElementRegistryStructuralEditorWorkKind.postClosureAttempt);
      throw StateError(
        'ElementRegistryStructuralEditor has no live final frame facts.',
      );
    }
    return _preparedStructuralFacts?.orderFacts.frameElementOrder ??
        _base.frameElementOrder;
  }

  bool containsLayer(CanvasLayerId id) {
    _ensureOpen();
    return _layerOrder?.containsId(id) ??
        _layerStates.containsKey(id) || _base.layerTable.contains(id);
  }

  bool get hasBackgroundElements => currentBackgroundElementIds.isNotEmpty;

  bool get hasContentElements => currentContentElementIds.isNotEmpty;

  Iterable<CanvasElementId> get currentBackgroundElementIds {
    _ensureOpen();
    return _backgroundOrder?.orderedValues ?? _base.backgroundElementIds;
  }

  Iterable<CanvasElementId> get currentContentElementIds sync* {
    _ensureOpen();
    for (final layerId in _currentLayerIds()) {
      yield* _contentIdsFor(_requiredStateForLayer(layerId));
    }
  }

  Iterable<CanvasElementId> get currentFrameElementIds sync* {
    _ensureOpen();
    yield* currentBackgroundElementIds;
    yield* currentContentElementIds;
  }

  ElementLocationFacts? locationFor(CanvasElementId id) {
    _ensureOpen();
    if (_locationChanges.containsKey(id)) {
      return _locationChanges[id];
    }
    final baseLocation = _base.elementLocationFacts[id];
    if (_contentCleared && baseLocation?.kind == ElementLocationKind.content) {
      return null;
    }
    return baseLocation;
  }

  bool ensureLayer(CanvasLayerId id, {int? index}) {
    _ensureOpen();
    if (containsLayer(id)) {
      return false;
    }
    _openLayerOrder().insert(id, index: index);
    _layerStates[id] = _StructuralLayerState.added(id);
    _changed = true;
    return true;
  }

  void addBackgroundElement(CanvasElementId id, {int? index}) {
    _ensureOpen();
    _openBackgroundOrder().insert(id, index: index);
    _locationChanges[id] = const ElementLocationFacts.background();
    _changed = true;
  }

  void addContentElement(
    CanvasElementId id, {
    CanvasLayerId? layerId,
    int? index,
  }) {
    _ensureOpen();
    final layer = LayerTable.withReadScope(
      LayerTableReadScope.placement,
      () => _targetLayer(layerId),
    );
    _openContentOrder(layer).insert(id, index: index);
    final contentElementCount = _contentElementCount;
    if (contentElementCount != null) {
      _contentElementCount = contentElementCount + 1;
    }
    _locationChanges[id] = ElementLocationFacts.content(layer.id);
    _changed = true;
  }

  bool removeElement(CanvasElementId id) {
    _ensureOpen();
    final location = locationFor(id);
    if (location == null) {
      return false;
    }
    switch (location.kind) {
      case ElementLocationKind.background:
        _openBackgroundOrder().remove(id);
      case ElementLocationKind.content:
        final layerId = location.layerId;
        if (layerId == null) {
          throw StateError('content element location omitted its layer id.');
        }
        _openContentOrder(_requiredStateForLayer(layerId)).remove(id);
        final contentElementCount = _contentElementCount;
        if (contentElementCount != null) {
          _contentElementCount = contentElementCount - 1;
        }
    }
    _locationChanges[id] = null;
    _changed = true;
    return true;
  }

  List<CanvasElementId> clearContent() {
    _ensureOpen();
    if (_contentElementCount == 0) {
      return const [];
    }
    final ids =
        (_contentCleared
                ? _contentElementIdsSinceClear()
                : _contentElementIdsBeforeClear())
            .toList(growable: false);
    _contentElementCount = 0;
    if (ids.isEmpty) {
      return ids;
    }
    _contentCleared = true;
    for (final state in _layerStates.values) {
      state.contentOrder?.clear();
    }
    for (final id in ids) {
      _locationChanges[id] = null;
    }
    _changed = true;
    return ids;
  }

  ElementRegistry freeze({required FamilyTables familyTables}) {
    if (!_finalized) {
      finalize();
    }
    if (_closed) {
      _record(ElementRegistryStructuralEditorWorkKind.postClosureAttempt);
      throw StateError('ElementRegistryStructuralEditor was already closed.');
    }
    final registry = _freezePrepared(familyTables);
    _recordStructuralPublication(registry);
    _preparedStructuralFacts = null;
    _finalizedComparisonFacts = null;
    _close();
    return registry;
  }

  // Final traversal seals mutable order state but does not publish a committed
  // owner. Sparse coverage and later gates can still fail, in which case the
  // wrapper discards this private result without exposing structural facts.
  // Keeping comparison and every derived fact in one traversal prevents a
  // second structural scan, which is safer than splitting it for metrics.
  // ignore: cyclomatic-complexity, halstead-volume, source-lines-of-code, maintainability-index, maximum-nesting-level
  ElementRegistryStructuralComparisonFacts finalize() {
    _ensureOpen();
    if (!_changed) {
      const facts = ElementRegistryStructuralComparisonFacts.unchanged();
      _finalizedComparisonFacts = facts;
      _finalized = true;
      _sealMutableState();
      return facts;
    }

    final rows = <LayerRow>[];
    final locations = <CanvasLayerId, LayerLocationFacts>{};
    final orderFacts = _ElementRegistryOrderAccumulator();
    final baseBackgroundIds = _base.backgroundElementIds;
    final baseFrameIds = _base.frameElementOrder;
    var backgroundMatchesBase = true;
    var backgroundIndex = 0;
    var frameIndex = 0;
    var frameOrderChanged = false;
    var elementLocationFactsChanged = false;

    final backgroundOrder = _backgroundOrder;
    final backgroundIds =
        backgroundOrder?.orderedValues ?? _base.backgroundElementIds;
    try {
      for (final id in backgroundIds) {
        _record(
          ElementRegistryStructuralEditorWorkKind.finalTraversalVisit,
          order: ElementRegistryStructuralOrderKind.background,
        );
        orderFacts.addBackground(id);
        if (backgroundIndex >= baseBackgroundIds.length ||
            id != baseBackgroundIds[backgroundIndex]) {
          backgroundMatchesBase = false;
        }
        if (frameIndex >= baseFrameIds.length ||
            id != baseFrameIds[frameIndex]) {
          frameOrderChanged = true;
        }
        final baseLocation = _base.elementLocationFacts[id];
        if (baseLocation == null ||
            baseLocation.kind != ElementLocationKind.background ||
            baseLocation.layerId != null) {
          elementLocationFactsChanged = true;
        }
        backgroundIndex += 1;
        frameIndex += 1;
      }
    } finally {
      _discardBackgroundOrder();
    }
    if (backgroundIndex != baseBackgroundIds.length) {
      backgroundMatchesBase = false;
    }

    var matchesBase = backgroundMatchesBase;
    var layerTableMatchesBase = true;
    var baseIndex = 0;
    final baseContentIds = _base.contentElementOrder;
    var baseContentIndex = 0;
    var contentElementCount = 0;
    var flatContentOrderChanged = false;
    var contentPlacementChanged = false;
    var layerStructureChanged = false;
    var layerOrderChanged = false;
    var layerMetadataChanged = false;

    final layerOrder = _layerOrder;
    final layerIds =
        layerOrder?.orderedValues ?? _base.layerTable.rows.map((row) => row.id);
    try {
      for (final layerId in layerIds) {
        _record(
          ElementRegistryStructuralEditorWorkKind.finalTraversalVisit,
          order: ElementRegistryStructuralOrderKind.layer,
        );
        final state = _requiredStateForLayer(layerId);
        final baseRow = baseIndex < _base.layerTable.rows.length
            ? _base.layerTable.rows[baseIndex]
            : null;
        final metadata =
            state.baseRow?.metadata ?? const CanvasMetadata.empty();
        final layerBaseRow = state.baseRow;
        if (layerBaseRow == null) {
          layerStructureChanged = true;
        } else if (layerBaseRow.metadata != metadata) {
          layerMetadataChanged = true;
        }
        if (baseRow == null || baseRow.id != state.id) {
          layerOrderChanged = true;
        }
        var rowMatchesBase =
            baseRow != null &&
            baseRow.id == state.id &&
            baseRow.metadata == metadata;
        var baseElementIndex = 0;
        var contentMatchesLayerBase = true;
        final elementIds = <CanvasElementId>[];
        final contentOrder = state.contentOrder;
        final contentIds =
            contentOrder?.orderedValues ??
            (_contentCleared
                ? const <CanvasElementId>[]
                : state.baseRow?.elementIds ?? const <CanvasElementId>[]);
        try {
          for (final id in contentIds) {
            _record(
              ElementRegistryStructuralEditorWorkKind.finalTraversalVisit,
              order: ElementRegistryStructuralOrderKind.content,
            );
            elementIds.add(id);
            final location = ElementLocationFacts.content(state.id);
            orderFacts.addContent(id, location);
            if (baseRow == null ||
                baseElementIndex >= baseRow.elementIds.length ||
                id != baseRow.elementIds[baseElementIndex]) {
              rowMatchesBase = false;
            }
            if (layerBaseRow == null ||
                baseElementIndex >= layerBaseRow.elementIds.length ||
                id != layerBaseRow.elementIds[baseElementIndex]) {
              contentMatchesLayerBase = false;
            }
            if (baseContentIndex >= baseContentIds.length ||
                id != baseContentIds[baseContentIndex]) {
              flatContentOrderChanged = true;
            }
            if (frameIndex >= baseFrameIds.length ||
                id != baseFrameIds[frameIndex]) {
              frameOrderChanged = true;
            }
            final baseLocation = _base.elementLocationFacts[id];
            if (baseLocation == null ||
                baseLocation.kind != ElementLocationKind.content ||
                baseLocation.layerId != state.id) {
              elementLocationFactsChanged = true;
            }
            baseElementIndex += 1;
            baseContentIndex += 1;
            contentElementCount += 1;
            frameIndex += 1;
          }
        } finally {
          _discardContentOrder(state);
        }
        if (baseRow == null || baseElementIndex != baseRow.elementIds.length) {
          rowMatchesBase = false;
        }
        if (layerBaseRow != null &&
            baseElementIndex != layerBaseRow.elementIds.length) {
          contentMatchesLayerBase = false;
        }
        if (!contentMatchesLayerBase) {
          contentPlacementChanged = true;
        }
        final row = layerBaseRow != null && contentMatchesLayerBase
            ? layerBaseRow
            : LayerRow.fromSparseTransactionFacts(
                id: state.id,
                elementIds: elementIds,
                metadata: metadata,
              );
        rows.add(row);
        final index = rows.length - 1;
        final previous = _base.layerTable.layerLocationFacts[layerId];
        locations[layerId] =
            previous != null &&
                identical(previous.row, row) &&
                previous.index == index
            ? previous
            : LayerLocationFacts(row: row, index: index);
        if (!rowMatchesBase) {
          matchesBase = false;
          layerTableMatchesBase = false;
        }
        baseIndex += 1;
      }
    } finally {
      _discardLayerOrder();
    }
    if (baseIndex != _base.layerTable.rows.length) {
      matchesBase = false;
      layerTableMatchesBase = false;
      layerStructureChanged = true;
      layerOrderChanged = true;
    }
    if (baseContentIndex != baseContentIds.length) {
      flatContentOrderChanged = true;
    }
    if (frameIndex != baseFrameIds.length) {
      frameOrderChanged = true;
      elementLocationFactsChanged = true;
    }

    final comparisonFacts = ElementRegistryStructuralComparisonFacts(
      elementCountChanged:
          backgroundIndex + contentElementCount != _base.elementCount,
      backgroundOrderChanged: !backgroundMatchesBase,
      flatContentOrderChanged: flatContentOrderChanged,
      contentPlacementChanged: contentPlacementChanged,
      frameOrderChanged: frameOrderChanged,
      elementLocationFactsChanged: elementLocationFactsChanged,
      layerStructureChanged: layerStructureChanged,
      layerOrderChanged: layerOrderChanged,
      layerMetadataChanged: layerMetadataChanged,
    );
    _finalizedComparisonFacts = comparisonFacts;

    if (matchesBase) {
      _finalized = true;
      _sealMutableState();
      return comparisonFacts;
    }

    _preparedStructuralFacts = _PreparedElementRegistryStructuralFacts(
      rows: rows,
      layerLocationFacts: locations,
      orderFacts: orderFacts.freeze(),
      layerTableMatchesBase: layerTableMatchesBase,
      backgroundMatchesBase: backgroundMatchesBase,
      contentOrderMatchesBase: !flatContentOrderChanged,
      frameOrderMatchesBase: !frameOrderChanged,
      elementLocationFactsMatchBase: !elementLocationFactsChanged,
    );
    _finalized = true;
    _sealMutableState();
    return comparisonFacts;
  }

  // Each derived owner selects its base identity or prepared replacement as
  // one atomic materialization decision. Splitting these branches would make
  // their shared comparison facts drift and risk publishing mixed structure.
  // ignore: cyclomatic-complexity, halstead-volume, source-lines-of-code
  ElementRegistry _freezePrepared(FamilyTables familyTables) {
    final prepared = _preparedStructuralFacts;
    if (prepared == null && identical(familyTables, _base.familyTables)) {
      return _base;
    }
    if (!identical(familyTables, _base.familyTables)) {
      FamilyTables.recordSparseFamilyAdoption(familyTables);
    }
    final layerTable = prepared == null || prepared.layerTableMatchesBase
        ? _base.layerTable
        : LayerTable.fromSparseTransactionFacts(
            rows: prepared.rows,
            layerLocationFacts: prepared.layerLocationFacts,
          );
    final backgroundElementIds =
        prepared == null || prepared.backgroundMatchesBase
        ? _base.backgroundElementIds
        : prepared.orderFacts.backgroundElementIds;
    final contentElementOrder =
        prepared == null || prepared.contentOrderMatchesBase
        ? _base.contentElementOrder
        : prepared.orderFacts.contentElementOrder;
    final frameElementOrder = prepared == null || prepared.frameOrderMatchesBase
        ? _base.frameElementOrder
        : prepared.orderFacts.frameElementOrder;
    final frameOrderTokensById =
        prepared == null || prepared.frameOrderMatchesBase
        ? _base.frameOrderTokensById
        : prepared.orderFacts.frameOrderTokensById;
    final elementLocationFacts =
        prepared == null || prepared.elementLocationFactsMatchBase
        ? _base.elementLocationFacts
        : prepared.orderFacts.elementLocationFacts;
    return ElementRegistry._withUpdatedFamilies(
      familyTables: familyTables,
      layerTable: layerTable,
      backgroundElementIds: backgroundElementIds,
      contentElementOrder: contentElementOrder,
      frameElementOrder: frameElementOrder,
      frameOrderTokensById: frameOrderTokensById,
      elementLocationFacts: elementLocationFacts,
    );
  }

  void _recordStructuralPublication(ElementRegistry registry) {
    final prepared = _preparedStructuralFacts;
    if (identical(registry, _base)) {
      _record(ElementRegistryStructuralEditorWorkKind.finalIdentityRetain);
      return;
    }
    if (prepared == null) {
      return;
    }
    if (!prepared.layerTableMatchesBase) {
      LayerTable.recordSparseTransactionPublication();
      _record(ElementRegistryStructuralEditorWorkKind.layerRowsPublication);
      _record(
        ElementRegistryStructuralEditorWorkKind.layerLocationsPublication,
      );
    }
    if (!prepared.backgroundMatchesBase) {
      _record(
        ElementRegistryStructuralEditorWorkKind.backgroundOrderPublication,
      );
    }
    if (!prepared.contentOrderMatchesBase) {
      _record(ElementRegistryStructuralEditorWorkKind.contentOrderPublication);
    }
    if (!prepared.frameOrderMatchesBase) {
      _record(ElementRegistryStructuralEditorWorkKind.frameOrderPublication);
      _record(ElementRegistryStructuralEditorWorkKind.frameTokenPublication);
    }
    if (!prepared.elementLocationFactsMatchBase) {
      _record(
        ElementRegistryStructuralEditorWorkKind.elementLocationPublication,
      );
    }
  }

  void discard() {
    if (_closed) {
      _record(ElementRegistryStructuralEditorWorkKind.postClosureAttempt);
      throw StateError('ElementRegistryStructuralEditor was already closed.');
    }
    if (!_finalized) {
      _discardLayerOrder();
      _discardBackgroundOrder();
      for (final state in _layerStates.values) {
        _discardContentOrder(state);
      }
    }
    _finalizedComparisonFacts = null;
    _preparedStructuralFacts = null;
    _close();
    _record(ElementRegistryStructuralEditorWorkKind.discard);
  }

  _StructuralLayerState _targetLayer(CanvasLayerId? requestedLayerId) {
    if (requestedLayerId != null) {
      if (!containsLayer(requestedLayerId)) {
        ensureLayer(requestedLayerId);
      }
      return _requiredStateForLayer(requestedLayerId);
    }
    final order = _layerOrder;
    if (order != null) {
      final last = order.last;
      if (last == null) {
        final defaultLayerId = CanvasLayerId('default-layer');
        ensureLayer(defaultLayerId);
        return _requiredStateForLayer(defaultLayerId);
      }
      return _requiredStateForLayer(last);
    }
    if (_base.layerTable.rows.isEmpty) {
      final defaultLayerId = CanvasLayerId('default-layer');
      ensureLayer(defaultLayerId);
      return _requiredStateForLayer(defaultLayerId);
    }
    return _requiredStateForLayer(_base.layerTable.rows.last.id);
  }

  Iterable<CanvasLayerId> _currentLayerIds() {
    final order = _layerOrder;
    if (order != null) {
      return order.orderedValues;
    }
    return _base.layerTable.rows.map((row) => row.id);
  }

  _StructuralLayerState? _stateForLayer(CanvasLayerId id) {
    final current = _layerStates[id];
    if (current != null) {
      return current;
    }
    final baseLocation = _base.layerTable.locationFor(id);
    if (baseLocation == null) {
      return null;
    }
    return _layerStates[id] = _StructuralLayerState.existing(baseLocation.row);
  }

  _StructuralLayerState _requiredStateForLayer(CanvasLayerId id) {
    final state = _stateForLayer(id);
    if (state == null) {
      throw StateError('current layer state was missing for ${id.value}.');
    }
    return state;
  }

  IndexedOrderSequence<CanvasLayerId, CanvasLayerId> _openLayerOrder() {
    return _layerOrder ??= _openOrder(
      ElementRegistryStructuralOrderKind.layer,
      _base.layerTable.rows.map((row) => row.id),
    );
  }

  IndexedOrderSequence<CanvasElementId, CanvasElementId>
  _openBackgroundOrder() {
    return _backgroundOrder ??= _openOrder(
      ElementRegistryStructuralOrderKind.background,
      _base.backgroundElementIds,
    );
  }

  IndexedOrderSequence<CanvasElementId, CanvasElementId> _openContentOrder(
    _StructuralLayerState state,
  ) {
    return state.contentOrder ??= _openOrder(
      ElementRegistryStructuralOrderKind.content,
      _contentIdsFor(state),
    );
  }

  IndexedOrderSequence<T, T> _openOrder<T>(
    ElementRegistryStructuralOrderKind kind,
    Iterable<T> values,
  ) {
    _record(ElementRegistryStructuralEditorWorkKind.orderOpen, order: kind);
    return IndexedOrderSequence<T, T>(values, idOf: (value) => value);
  }

  Iterable<CanvasElementId> _contentIdsFor(_StructuralLayerState state) {
    final order = state.contentOrder;
    if (order != null) {
      return order.orderedValues;
    }
    if (_contentCleared) {
      return const <CanvasElementId>[];
    }
    return state.baseRow?.elementIds ?? const <CanvasElementId>[];
  }

  Iterable<CanvasElementId> _contentElementIdsSinceClear() sync* {
    for (final state in _layerStates.values) {
      final order = state.contentOrder;
      if (order != null) {
        _record(
          ElementRegistryStructuralEditorWorkKind.clearContentTraversalVisit,
          order: ElementRegistryStructuralOrderKind.content,
        );
        yield* order.orderedValues;
      }
    }
  }

  Iterable<CanvasElementId> _contentElementIdsBeforeClear() sync* {
    for (final layerId in _currentLayerIds()) {
      _record(
        ElementRegistryStructuralEditorWorkKind.clearContentTraversalVisit,
        order: ElementRegistryStructuralOrderKind.layer,
      );
      yield* _contentIdsFor(_requiredStateForLayer(layerId));
    }
  }

  void _discardLayerOrder() {
    final order = _layerOrder;
    _layerOrder = null;
    order?.discard();
  }

  void _discardBackgroundOrder() {
    final order = _backgroundOrder;
    _backgroundOrder = null;
    order?.discard();
  }

  void _discardContentOrder(_StructuralLayerState state) {
    final order = state.contentOrder;
    state.contentOrder = null;
    order?.discard();
  }

  void _close() {
    if (_layerOrder != null ||
        _backgroundOrder != null ||
        _layerStates.values.any((state) => state.contentOrder != null)) {
      throw StateError(
        'ElementRegistryStructuralEditor sealed an unclosed order sequence.',
      );
    }
    _closed = true;
    _sealMutableState();
  }

  void _sealMutableState() {
    _layerStates.clear();
    _locationChanges.clear();
  }

  void _ensureOpen() {
    if (!_closed && !_finalized) {
      return;
    }
    _record(ElementRegistryStructuralEditorWorkKind.postClosureAttempt);
    throw StateError('ElementRegistryStructuralEditor was already closed.');
  }

  void _record(
    ElementRegistryStructuralEditorWorkKind kind, {
    ElementRegistryStructuralOrderKind? order,
  }) {
    assert(() {
      final sink = Zone.current[_workZoneKey];
      if (sink is void Function(ElementRegistryStructuralEditorWorkEvent)) {
        sink(
          ElementRegistryStructuralEditorWorkEvent(kind: kind, order: order),
        );
      }
      return true;
    }(), 'structural editor work observation failed');
  }
}

final class _StructuralLayerState {
  _StructuralLayerState.existing(LayerRow row) : id = row.id, baseRow = row;

  _StructuralLayerState.added(this.id) : baseRow = null;

  final CanvasLayerId id;
  final LayerRow? baseRow;
  IndexedOrderSequence<CanvasElementId, CanvasElementId>? contentOrder;
}

final class _PreparedElementRegistryStructuralFacts {
  const _PreparedElementRegistryStructuralFacts({
    required this.rows,
    required this.layerLocationFacts,
    required this.orderFacts,
    required this.layerTableMatchesBase,
    required this.backgroundMatchesBase,
    required this.contentOrderMatchesBase,
    required this.frameOrderMatchesBase,
    required this.elementLocationFactsMatchBase,
  });

  final List<LayerRow> rows;
  final Map<CanvasLayerId, LayerLocationFacts> layerLocationFacts;
  final _ElementRegistryOrderFacts orderFacts;
  final bool layerTableMatchesBase;
  final bool backgroundMatchesBase;
  final bool contentOrderMatchesBase;
  final bool frameOrderMatchesBase;
  final bool elementLocationFactsMatchBase;
}

final class _ElementRegistryOrderFacts {
  const _ElementRegistryOrderFacts({
    required this.backgroundElementIds,
    required this.contentElementOrder,
    required this.frameElementOrder,
    required this.frameOrderTokensById,
    required this.elementLocationFacts,
  });

  final List<CanvasElementId> backgroundElementIds;
  final List<CanvasElementId> contentElementOrder;
  final List<CanvasElementId> frameElementOrder;
  final Map<CanvasElementId, int> frameOrderTokensById;
  final Map<CanvasElementId, ElementLocationFacts> elementLocationFacts;

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
    _frame.add(id);
  }

  _ElementRegistryOrderFacts freeze() {
    return _ElementRegistryOrderFacts(
      backgroundElementIds: List.unmodifiable(_background),
      contentElementOrder: List.unmodifiable(_content),
      frameElementOrder: List.unmodifiable(_frame),
      frameOrderTokensById: Map.unmodifiable(_tokens),
      elementLocationFacts: Map.unmodifiable(_locations),
    );
  }
}

final class ElementRegistrySchemaV1OrderImportBuilder {
  List<CanvasElementId>? _background = [];
  List<CanvasElementId>? _content = [];
  List<CanvasElementId>? _frame = [];
  Map<CanvasElementId, int>? _tokens = {};
  Map<CanvasElementId, ElementLocationFacts>? _locations = {};

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
    _background = null;
    _content = null;
    _frame = null;
    _tokens = null;
    _locations = null;

    return ElementRegistryOrderImportFacts._owned(
      backgroundElementIds: background,
      contentElementOrder: content,
      frameElementOrder: frame,
      frameOrderTokensById: tokens,
      elementLocationFacts: locations,
    );
  }

  void ensureNotConsumed() {
    _live(_frame);
  }

  void _admit(CanvasElementId id, ElementLocationFacts location) {
    final frame = _live(_frame);
    _live(_tokens)[id] = frame.length;
    _live(_locations)[id] = location;
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
  }) : backgroundElementIds = UnmodifiableListView(backgroundElementIds),
       contentElementOrder = UnmodifiableListView(contentElementOrder),
       frameElementOrder = UnmodifiableListView(frameElementOrder),
       frameOrderTokensById = UnmodifiableMapView(frameOrderTokensById),
       elementLocationFacts = UnmodifiableMapView(elementLocationFacts);

  final List<CanvasElementId> backgroundElementIds;
  final List<CanvasElementId> contentElementOrder;
  final List<CanvasElementId> frameElementOrder;
  final Map<CanvasElementId, int> frameOrderTokensById;
  final Map<CanvasElementId, ElementLocationFacts> elementLocationFacts;
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
