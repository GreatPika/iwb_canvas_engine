import 'dart:async';
import 'dart:collection';
import 'dart:ui';

import 'package:meta/meta.dart' show visibleForTesting;

// EditSession is the CanvasEdit handle and must name every DTO accepted by that
// public transaction surface; hiding those imports would make the mutation
// boundary less auditable.
// ignore_for_file: number-of-imports

import '../contracts/public/canvas_document.dart';
import '../contracts/public/canvas_element.dart';
import '../contracts/public/canvas_element_update.dart';
import '../contracts/public/canvas_errors.dart';
import '../contracts/public/canvas_ids.dart';
import '../contracts/public/canvas_resource.dart';
import '../contracts/public/canvas_runtime.dart';
import '../contracts/internal/touched_set.dart';
import '../store/sparse_store_commit.dart';
import '../store/store_revision_delta.dart';
import 'commit_compiler.dart';
import 'commit_plan.dart';
import 'draft_document.dart';
import 'element_update_application.dart';
import 'resource_edit_policy.dart';
import 'sparse_edit_resource_references.dart';
import 'sparse_edit_structure.dart';
import 'touched_set_builder.dart';

@visibleForTesting
enum SparsePromotionWorkPhase {
  open,
  journalElementRead,
  draftApplication,
  complete,
}

@visibleForTesting
final class SparsePromotionWorkEvent {
  const SparsePromotionWorkEvent({required this.phase, this.mutation});

  final SparsePromotionWorkPhase phase;
  final StoreSparseMutation? mutation;
}

final Object _sparsePromotionWorkZoneKey = Object();
final TouchedSet _emptyTouchedSet = TouchedSet();

/// Records the sparse promotion boundary only under asserts.
@visibleForTesting
T observeSparsePromotionWork<T>(
  void Function(SparsePromotionWorkEvent event) sink,
  T Function() operation,
) {
  return runZoned(operation, zoneValues: {_sparsePromotionWorkZoneKey: sink});
}

_EditSessionBacking Function() _sparseBackingFactory({
  required SparseEditSessionFacts Function() readFacts,
  required DraftDocument Function(Set<CanvasElementId>) promoteDraft,
  required Set<CanvasElementId> Function() readSelectedElementIds,
}) =>
    () => _SparseEditBacking(
      readFacts: readFacts,
      promoteDraft: promoteDraft,
      selectedElementIds: readSelectedElementIds,
    );

// CanvasEdit is intentionally represented by one session handle: the stale
// guard and draft reference must stay uniform across every public entry point.
// Keeping the full CanvasEdit routing surface together makes stale-handle
// enforcement uniform; splitting it would only distribute forwarding logic.
// ignore: coupling-between-object-classes, number-of-methods, response-for-class, weighted-methods-per-class
final class EditSession implements CanvasEdit {
  EditSession({required DraftDocument draft})
    : _backing = _MaterializedEditBacking(draft),
      _openSparseBacking = null;

  EditSession.sparse({
    required SparseEditSessionFacts Function() readFacts,
    required DraftDocument Function(Set<CanvasElementId>) promoteDraft,
    required Set<CanvasElementId> Function() readSelectedElementIds,
  }) : _backing = null,
       _openSparseBacking = _sparseBackingFactory(
         readFacts: readFacts,
         promoteDraft: promoteDraft,
         readSelectedElementIds: readSelectedElementIds,
       );

  _EditSessionBacking? _backing;
  final _EditSessionBacking Function()? _openSparseBacking;
  ReplaceSelectionEffect? _pendingSelectionEffect;
  bool _isClosed = false;

  bool get didChange => _backing?.didChange ?? false;
  StoreRevisionDelta get revisionDelta =>
      _backing?.revisionDelta ?? const StoreRevisionDelta();
  TouchedSet get touchedSet => _backing?.touchedSet ?? _emptyTouchedSet;
  CommitPlan get commitPlan => const CommitCompiler().compile(
    revisionDelta: revisionDelta,
    touchedSet: touchedSet,
    selectionEffect: _pendingSelectionEffect,
  );
  bool get hasMaterializedDraft => _backing?.isMaterialized ?? false;
  bool get didReplaceDraftDocument => _backing?.documentReplaced ?? false;
  StoreSparseCommit? get materializedEmptyLayerRemovalSparseCommit =>
      _backing?.materializedEmptyLayerRemovalSparseCommit;
  StoreSparseCommit get sparseCommit => _documentBacking.sparseCommit;
  StoreSparseCommit sparseCommitFor({CanvasElementId? affectedElementId}) =>
      _documentBacking.sparseCommitFor(affectedElementId: affectedElementId);
  Set<CanvasElementId> get selectedElementIds =>
      _documentBacking.selectedElementIds;
  ReplaceSelectionEffect? get pendingSelectionEffect => _pendingSelectionEffect;

  void close() {
    if (_isClosed) {
      return;
    }
    _backing?.close();
    _pendingSelectionEffect = null;
    _isClosed = true;
  }

  @override
  CanvasDocument readDraftDocument() {
    _ensureActive();

    return _documentBacking.readDraftDocument();
  }

  @override
  CanvasDocumentSummary get draftSummary {
    _ensureActive();

    return _documentBacking.draftSummary;
  }

  @override
  bool ensureLayer(CanvasLayerId id, {int? index}) {
    _ensureActive();
    return _documentBacking.ensureLayer(id, index: index);
  }

  @override
  bool removeEmptyLayer(CanvasLayerId id) {
    _ensureActive();
    return _documentBacking.removeEmptyLayer(id);
  }

  @override
  CanvasElementId addElement(
    CanvasElement element, {
    CanvasLayerId? layerId,
    int? index,
  }) {
    _ensureActive();
    return _documentBacking.addElement(element, layerId: layerId, index: index);
  }

  @override
  CanvasElementId addBackgroundElement(CanvasElement element, {int? index}) {
    _ensureActive();
    return _documentBacking.addBackgroundElement(element, index: index);
  }

  @override
  bool updateElement(CanvasElementUpdate update) {
    _ensureActive();
    return _documentBacking.updateElement(update);
  }

  @override
  bool removeElement(CanvasElementId id) {
    _ensureActive();
    return _documentBacking.removeElement(id);
  }

  @override
  bool upsertResource(CanvasResource resource) {
    _ensureActive();
    return _documentBacking.upsertResource(resource);
  }

  @override
  bool removeUnusedResource(CanvasResourceId id) {
    _ensureActive();
    return _documentBacking.removeUnusedResource(id);
  }

  @override
  void setBackgroundColor(Color color) {
    _ensureActive();
    _documentBacking.setBackgroundColor(color);
  }

  @override
  void setGrid(CanvasGrid grid) {
    _ensureActive();
    _documentBacking.setGrid(grid);
  }

  @override
  void updateGrid(CanvasGridUpdate update) {
    _ensureActive();
    _documentBacking.updateGrid(update);
  }

  @override
  void setPalette(CanvasPalette palette) {
    _ensureActive();
    _documentBacking.setPalette(palette);
  }

  @override
  void updatePalette(CanvasPaletteUpdate update) {
    _ensureActive();
    _documentBacking.updatePalette(update);
  }

  @override
  void setCameraOffset(Offset offset) {
    _ensureActive();
    _documentBacking.setCameraOffset(offset);
  }

  @override
  void setSelection(Iterable<CanvasElementId> ids) {
    _ensureActive();
    // Construct before replacing prior intent: a throwing iterable must leave
    // the last successful callback-local request intact.
    final next = ReplaceSelectionEffect(ids);
    _pendingSelectionEffect = next;
  }

  @override
  CanvasClearResult clearContent({bool removeUnusedResources = false}) {
    _ensureActive();
    return _documentBacking.clearContent(
      removeUnusedResources: removeUnusedResources,
    );
  }

  @override
  void replaceDraftDocument(CanvasDocument document) {
    _ensureActive();
    _documentBacking.replaceDraftDocument(document);
  }

  void _ensureActive() {
    if (_isClosed) {
      throw StateError('CanvasEdit handle is stale.');
    }
  }

  _EditSessionBacking get _documentBacking {
    final existing = _backing;
    if (existing != null) {
      return existing;
    }
    final sparseFactory = _openSparseBacking;
    if (sparseFactory == null) {
      throw StateError('Materialized edit sessions always retain a backing.');
    }
    return _backing = sparseFactory();
  }
}

// Sparse edit sessions need the complete committed fact surface to avoid
// materializing public projections; splitting this port would add sync glue
// between facts that must be read from one store snapshot.
// ignore: number-of-methods
abstract interface class SparseEditSessionFacts
    implements SparseEditStructureFacts, SparseEditReferenceFacts {
  CanvasDocumentSummary get summary;
  CanvasBackground get background;
  CanvasCamera get camera;
  CanvasPalette get palette;
  @override
  bool hasLayer(CanvasLayerId id);
  @override
  Iterable<CanvasElementId> get backgroundElementIds;
  @override
  Iterable<CanvasLayerId> get layerIds;
  @override
  Iterable<CanvasElementId> elementIdsInLayer(CanvasLayerId id);
  Iterable<CanvasElementId> get elementIds;
  Iterable<CanvasResourceId> get resourceIds;
  CanvasElement? elementById(CanvasElementId id);
  CanvasResource? resourceById(CanvasResourceId id);
}

// Backing implementations deliberately mirror the full CanvasEdit surface so
// stale guards and sparse/materialized dispatch stay uniform across entries.
// ignore: coupling-between-object-classes, number-of-methods
abstract interface class _EditSessionBacking {
  bool get didChange;
  bool get isMaterialized;
  bool get documentReplaced;
  StoreSparseCommit? get materializedEmptyLayerRemovalSparseCommit;
  Set<CanvasElementId> get selectedElementIds;
  StoreRevisionDelta get revisionDelta;
  TouchedSet get touchedSet;
  StoreSparseCommit get sparseCommit;
  StoreSparseCommit sparseCommitFor({CanvasElementId? affectedElementId});
  CanvasDocument readDraftDocument();
  CanvasDocumentSummary get draftSummary;
  bool ensureLayer(CanvasLayerId id, {int? index});
  bool removeEmptyLayer(CanvasLayerId id);
  CanvasElementId addElement(
    CanvasElement element, {
    CanvasLayerId? layerId,
    int? index,
  });
  CanvasElementId addBackgroundElement(CanvasElement element, {int? index});
  bool updateElement(CanvasElementUpdate update);
  bool removeElement(CanvasElementId id);
  bool upsertResource(CanvasResource resource);
  bool removeUnusedResource(CanvasResourceId id);
  void setBackgroundColor(Color color);
  void setGrid(CanvasGrid grid);
  void updateGrid(CanvasGridUpdate update);
  void setPalette(CanvasPalette palette);
  void updatePalette(CanvasPaletteUpdate update);
  void setCameraOffset(Offset offset);
  CanvasClearResult clearContent({required bool removeUnusedResources});
  void replaceDraftDocument(CanvasDocument document);
  void close();
}

// Materialized backing is a direct DraftDocument adapter for every CanvasEdit
// entry; splitting it would create method-group sync glue with no owner value.
// Its complete edit-surface response set is clearer than splitting stale-safe
// dispatch across forwarding fragments solely to lower a metric.
// ignore: coupling-between-object-classes, number-of-methods, response-for-class
final class _MaterializedEditBacking implements _EditSessionBacking {
  _MaterializedEditBacking(this._draft);

  final DraftDocument _draft;

  @override
  bool get didChange => _draft.didChange;

  @override
  bool get isMaterialized => true;

  @override
  StoreRevisionDelta get revisionDelta => _draft.revisionDelta;

  @override
  TouchedSet get touchedSet => _draft.touchedSet;

  @override
  bool get documentReplaced => _draft.documentReplaced;

  @override
  StoreSparseCommit? get materializedEmptyLayerRemovalSparseCommit =>
      _draft.emptyLayerRemovalSparseCommit;

  @override
  Set<CanvasElementId> get selectedElementIds => _draft.selectedElementIds;

  @override
  StoreSparseCommit get sparseCommit {
    throw StateError(
      'Materialized edit sessions do not expose sparse commits.',
    );
  }

  @override
  StoreSparseCommit sparseCommitFor({CanvasElementId? affectedElementId}) =>
      sparseCommit;

  @override
  CanvasDocument readDraftDocument() => _draft.readDocument();

  @override
  CanvasDocumentSummary get draftSummary => _draft.summary;

  @override
  bool ensureLayer(CanvasLayerId id, {int? index}) {
    return _draft.ensureLayer(id, index: index);
  }

  @override
  bool removeEmptyLayer(CanvasLayerId id) => _draft.removeEmptyLayer(id);

  @override
  CanvasElementId addElement(
    CanvasElement element, {
    CanvasLayerId? layerId,
    int? index,
  }) {
    return _draft.addElement(element, layerId: layerId, index: index);
  }

  @override
  CanvasElementId addBackgroundElement(CanvasElement element, {int? index}) {
    return _draft.addBackgroundElement(element, index: index);
  }

  @override
  bool updateElement(CanvasElementUpdate update) {
    return _draft.updateElement(update);
  }

  @override
  bool removeElement(CanvasElementId id) {
    return _draft.removeElement(id);
  }

  @override
  bool upsertResource(CanvasResource resource) {
    return _draft.upsertResource(resource);
  }

  @override
  bool removeUnusedResource(CanvasResourceId id) {
    return _draft.removeUnusedResource(id);
  }

  @override
  void setBackgroundColor(Color color) {
    _draft.setBackgroundColor(color);
  }

  @override
  void setGrid(CanvasGrid grid) {
    _draft.setGrid(grid);
  }

  @override
  void updateGrid(CanvasGridUpdate update) {
    _draft.setGrid(_mergeGridUpdate(_draft.background.grid, update));
  }

  @override
  void setPalette(CanvasPalette palette) {
    _draft.setPalette(palette);
  }

  @override
  void updatePalette(CanvasPaletteUpdate update) {
    final current = _draft.palette;
    _draft.applyOwnedPalette(_mergePaletteUpdate(current, update));
  }

  @override
  void setCameraOffset(Offset offset) {
    _draft.setCameraOffset(offset);
  }

  @override
  CanvasClearResult clearContent({required bool removeUnusedResources}) {
    return _draft.clearContent(removeUnusedResources: removeUnusedResources);
  }

  @override
  void replaceDraftDocument(CanvasDocument document) {
    _draft.replaceDocument(document);
  }

  @override
  // A materialized session owns no sparse sequence to release.
  // ignore: no-empty-block
  void close() {}
}

// Sparse backing owns the callback-local journal and promotion decision for
// the complete CanvasEdit surface; keeping it cohesive prevents mixed sparse
// and materialized state ownership.
// ignore: coupling-between-object-classes, number-of-methods, response-for-class, weighted-methods-per-class
final class _SparseEditBacking implements _EditSessionBacking {
  _SparseEditBacking({
    required SparseEditSessionFacts Function() readFacts,
    required DraftDocument Function(Set<CanvasElementId>) promoteDraft,
    required Set<CanvasElementId> Function() selectedElementIds,
  }) : this._(
         facts: readFacts(),
         promoteDraft: promoteDraft,
         selectedElementIds: selectedElementIds(),
       );

  _SparseEditBacking._({
    required SparseEditSessionFacts facts,
    required DraftDocument Function(Set<CanvasElementId>) promoteDraft,
    required Set<CanvasElementId> selectedElementIds,
  }) : _facts = facts,
       _promoteDraft = promoteDraft,
       _committedSummary = facts.summary,
       _structure = SparseEditStructure(facts),
       _resourceReferences = SparseEditResourceReferences(facts),
       _selectedElementIds = Set.unmodifiable(selectedElementIds);

  final SparseEditSessionFacts _facts;
  final DraftDocument Function(Set<CanvasElementId>) _promoteDraft;
  final CanvasDocumentSummary _committedSummary;
  final SparseEditStructure _structure;
  final SparseEditResourceReferences _resourceReferences;
  final _SparseMutationJournal _mutationJournal = _SparseMutationJournal();
  final TouchedSetBuilder _touchedSet = TouchedSetBuilder();
  StoreRevisionDelta _revisionDelta = const StoreRevisionDelta();
  final Set<CanvasElementId> _selectedElementIds;
  DraftDocument? _draft;
  final Map<CanvasElementId, CanvasElement> _elementOverrides = {};
  final Set<CanvasElementId> _addedElementIds = {};
  final Set<CanvasElementId> _removedCommittedElementIds = {};
  final Map<CanvasResourceId, CanvasResource> _resourceOverrides = {};
  final Set<CanvasResourceId> _addedResourceIds = {};
  final Set<CanvasResourceId> _removedCommittedResourceIds = {};
  CanvasBackground? _backgroundOverride;
  CanvasCamera? _cameraOverride;
  CanvasPalette? _paletteOverride;

  DraftDocument get _materializedDraft {
    final existing = _draft;
    if (existing != null) {
      return existing;
    }
    final target = DraftSparsePromotionTarget.open(
      () => _promoteDraft(_selectedElementIds),
    );
    _mutationJournal.promoteInto(target);
    final promoted = target.finish();
    _structure.dispose();
    _resourceReferences.dispose();
    _draft = promoted;

    return promoted;
  }

  bool get _isMaterialized => _draft != null;

  @override
  bool get isMaterialized => _isMaterialized;

  @override
  bool get didChange =>
      _draft?.didChange ??
      _mutationJournal.isNotEmpty ||
          _backgroundOverride != null ||
          _cameraOverride != null ||
          _paletteOverride != null;

  @override
  StoreRevisionDelta get revisionDelta =>
      _draft?.revisionDelta ?? _revisionDelta;

  @override
  TouchedSet get touchedSet => _draft?.touchedSet ?? _touchedSet.build();

  @override
  bool get documentReplaced => _draft?.documentReplaced ?? false;

  @override
  StoreSparseCommit? get materializedEmptyLayerRemovalSparseCommit =>
      _draft?.emptyLayerRemovalSparseCommit;

  @override
  Set<CanvasElementId> get selectedElementIds => _selectedElementIds;

  @override
  StoreSparseCommit get sparseCommit {
    return sparseCommitFor();
  }

  @override
  StoreSparseCommit sparseCommitFor({CanvasElementId? affectedElementId}) {
    if (_isMaterialized) {
      throw StateError(
        'Materialized edit sessions do not expose sparse commits.',
      );
    }

    return _mutationJournal.storeSnapshot(
      revisionDelta: _revisionDelta,
      affectedElementId: affectedElementId,
    );
  }

  @override
  CanvasDocument readDraftDocument() => _materializedDraft.readDocument();

  @override
  CanvasDocumentSummary get draftSummary {
    final draft = _draft;
    if (draft != null) {
      return draft.summary;
    }

    return CanvasDocumentSummary(
      elementCount: _sparseElementCount,
      layerCount: _structure.layerCount(
        committedCount: _committedSummary.layerCount,
      ),
      resourceCount: _sparseResourceCount,
    );
  }

  @override
  bool ensureLayer(CanvasLayerId id, {int? index}) {
    if (_isMaterialized) {
      return _materializedDraft.ensureLayer(id, index: index);
    }
    if (!_admitSparseLayer(id, index: index)) {
      return false;
    }
    _mutationJournal.append(StoreSparseEnsureLayer(id, index: index));
    _touchedSet.touchLayer(id);
    _mergeRevisionDelta(const StoreRevisionDelta.layerStructural());

    return true;
  }

  @override
  bool removeEmptyLayer(CanvasLayerId id) {
    if (_isMaterialized) {
      return _materializedDraft.removeEmptyLayer(id);
    }
    if (!_structure.removeEmptyLayer(id)) {
      return false;
    }
    _mutationJournal.append(StoreSparseRemoveEmptyLayer(id));
    _touchedSet.touchLayer(id);
    _mergeRevisionDelta(const StoreRevisionDelta.layerStructural());
    return true;
  }

  @override
  CanvasElementId addElement(
    CanvasElement element, {
    CanvasLayerId? layerId,
    int? index,
  }) {
    if (_isMaterialized) {
      return _materializedDraft.addElement(
        element,
        layerId: layerId,
        index: index,
      );
    }
    _admitSparseElement(element);
    final targetLayerId = _admitSparseContentLayerForAdd(layerId);
    _trackSparseElementAdd(element.id);
    _elementOverrides[element.id] = element;
    _structure.addContent(element.id, layerId: targetLayerId, index: index);
    _resourceReferences.recordTransition(after: element);
    _mutationJournal.append(
      StoreSparseAddElement(element: element, layerId: layerId, index: index),
    );
    _touchedSet.touchAddedElement(element.id);
    _mergeRevisionDelta(const StoreRevisionDelta.structural());

    return element.id;
  }

  CanvasLayerId _admitSparseContentLayerForAdd(CanvasLayerId? layerId) {
    if (layerId != null) {
      if (_admitSparseLayer(layerId)) {
        _touchedSet.touchLayer(layerId);
      }

      return layerId;
    }
    if (_sparseLayerCount == 0) {
      final defaultLayerId = CanvasLayerId('default-layer');
      if (_admitSparseLayer(defaultLayerId)) {
        _touchedSet.touchLayer(defaultLayerId);
      }

      return defaultLayerId;
    }

    return _contentLayerForSparseAdd(null);
  }

  @override
  CanvasElementId addBackgroundElement(CanvasElement element, {int? index}) {
    if (_isMaterialized) {
      return _materializedDraft.addBackgroundElement(element, index: index);
    }
    _admitSparseElement(element);
    _trackSparseElementAdd(element.id);
    _elementOverrides[element.id] = element;
    _structure.addBackground(element.id, index: index);
    _resourceReferences.recordTransition(after: element);
    _mutationJournal.append(
      StoreSparseAddElement(element: element, index: index, background: true),
    );
    _touchedSet.touchAddedElement(element.id);
    _touchedSet.touchBackgroundLayer();
    _mergeRevisionDelta(const StoreRevisionDelta.structural());

    return element.id;
  }

  @override
  bool updateElement(CanvasElementUpdate update) {
    if (_isMaterialized) {
      return _materializedDraft.updateElement(update);
    }
    final before = _elementById(update.id);
    if (before == null) {
      return false;
    }
    if (!elementUpdateMatchesKind(before, update)) {
      throw ArgumentError.value(
        update,
        'update',
        'element update kind does not match the target element.',
      );
    }
    final after = updatedElementFor(before, update);
    if (after == null) {
      return false;
    }
    final compiledUpdate = const CommitCompiler().compileElementUpdate(
      before: before,
      after: after,
    );
    final mutation = StoreSparseUpdateElement(
      before: before,
      element: after,
      elementRevisionDelta: compiledUpdate.revisionDelta,
    );
    _elementOverrides[after.id] = after;
    _resourceReferences.recordTransition(before: before, after: after);
    _mutationJournal.append(mutation);
    _recordSparseElementUpdate(after: after, compiledUpdate: compiledUpdate);

    return true;
  }

  @override
  bool removeElement(CanvasElementId id) {
    if (_isMaterialized) {
      return _materializedDraft.removeElement(id);
    }
    if (_elementById(id) == null) {
      return false;
    }
    final removedLocation = _structure.remove(id);
    if (removedLocation == null) {
      return false;
    }
    final removesBackgroundElement = removedLocation.layerId == null;
    final removedElement = _elementById(id);
    _elementOverrides.remove(id);
    if (!_addedElementIds.remove(id) && _facts.elementById(id) != null) {
      _removedCommittedElementIds.add(id);
    }
    _resourceReferences.recordTransition(before: removedElement);
    _mutationJournal.append(StoreSparseRemoveElement(id));
    _touchedSet.touchRemovedElement(id);
    if (removesBackgroundElement) {
      _touchedSet.touchBackgroundLayer();
    }
    if (_selectedElementIds.contains(id)) {
      _touchedSet.touchSelection();
    }
    _mergeRevisionDelta(const StoreRevisionDelta.structural());

    return true;
  }

  @override
  bool upsertResource(CanvasResource resource) {
    if (_isMaterialized) {
      return _materializedDraft.upsertResource(resource);
    }
    final current = _resourceById(resource.id);
    if (current != null && hasSameResourceFacts(current, resource)) {
      return false;
    }
    _trackSparseResourceUpsert(resource.id);
    _resourceOverrides[resource.id] = resource;
    _mutationJournal.append(StoreSparseUpsertResource(resource));
    _touchedSet.touchResourceDescriptor(resource.id);
    if (_resourceReferences.isReferenced(resource.id)) {
      _touchedSet.touchResourceVisual(resource.id);
    }
    _mergeRevisionDelta(const StoreRevisionDelta.resource());

    return true;
  }

  @override
  bool removeUnusedResource(CanvasResourceId id) {
    if (_isMaterialized) {
      return _materializedDraft.removeUnusedResource(id);
    }
    if (_resourceById(id) == null || _resourceReferences.isReferenced(id)) {
      return false;
    }
    _resourceOverrides.remove(id);
    if (!_addedResourceIds.remove(id) && _facts.resourceById(id) != null) {
      _removedCommittedResourceIds.add(id);
    }
    _mutationJournal.append(StoreSparseRemoveUnusedResource(id));
    _touchedSet.touchResourceDescriptor(id);
    _mergeRevisionDelta(const StoreRevisionDelta.resource());

    return true;
  }

  @override
  void setBackgroundColor(Color color) {
    if (_isMaterialized) {
      _materializedDraft.setBackgroundColor(color);

      return;
    }
    final current = _backgroundOverride ?? _facts.background;
    if (current.color == color) {
      return;
    }
    final nextBackground = CanvasBackground(color: color, grid: current.grid);
    _backgroundOverride = nextBackground;
    _mutationJournal.append(StoreSparseSetBackground(nextBackground));
    _touchedSet.touchBackground();
    _mergeRevisionDelta(const StoreRevisionDelta.background());
  }

  @override
  void setGrid(CanvasGrid grid) {
    if (_isMaterialized) {
      _materializedDraft.setGrid(grid);

      return;
    }
    final current = _backgroundOverride ?? _facts.background;
    if (current.grid == grid) {
      return;
    }
    final nextBackground = CanvasBackground(color: current.color, grid: grid);
    _backgroundOverride = nextBackground;
    _mutationJournal.append(StoreSparseSetBackground(nextBackground));
    _touchedSet.touchGrid();
    _mergeRevisionDelta(const StoreRevisionDelta.grid());
  }

  @override
  void updateGrid(CanvasGridUpdate update) {
    if (_isMaterialized) {
      final draft = _materializedDraft;
      draft.setGrid(_mergeGridUpdate(draft.background.grid, update));

      return;
    }
    final current = (_backgroundOverride ?? _facts.background).grid;
    setGrid(_mergeGridUpdate(current, update));
  }

  @override
  void setPalette(CanvasPalette palette) {
    if (_isMaterialized) {
      _materializedDraft.setPalette(palette);

      return;
    }
    final current = _paletteOverride ?? _facts.palette;
    if (_samePalette(current, palette)) {
      return;
    }
    _paletteOverride = palette;
    _mutationJournal.append(StoreSparseSetPalette(palette));
    _touchedSet.touchPalette();
    _mergeRevisionDelta(const StoreRevisionDelta.projectionOnly());
  }

  @override
  void updatePalette(CanvasPaletteUpdate update) {
    if (_isMaterialized) {
      final draft = _materializedDraft;
      draft.applyOwnedPalette(_mergePaletteUpdate(draft.palette, update));

      return;
    }
    final current = _paletteOverride ?? _facts.palette;
    setPalette(_mergePaletteUpdate(current, update));
  }

  @override
  void setCameraOffset(Offset offset) {
    if (_isMaterialized) {
      _materializedDraft.setCameraOffset(offset);

      return;
    }
    final current = _cameraOverride ?? _facts.camera;
    final next = CanvasCamera(offset: offset);
    if (current == next) {
      return;
    }
    _cameraOverride = next;
    _mutationJournal.append(StoreSparseSetCamera(next));
    _touchedSet.touchPersistedCamera();
    _mergeRevisionDelta(const StoreRevisionDelta.projectionOnly());
  }

  @override
  CanvasClearResult clearContent({required bool removeUnusedResources}) {
    if (_isMaterialized) {
      return _materializedDraft.clearContent(
        removeUnusedResources: removeUnusedResources,
      );
    }
    final candidate = _sparseClearCandidate(
      removeUnusedResources: removeUnusedResources,
    );
    final didClearContent =
        candidate.removedElementIds.isNotEmpty ||
        candidate.removedResourceIds.isNotEmpty;
    if (!didClearContent) {
      return CanvasClearResult(
        removedElementIds: candidate.removedElementIds,
        removedResourceIds: candidate.removedResourceIds,
        didClearContent: false,
      );
    }
    _installSparseClear(
      candidate,
      removeUnusedResources: removeUnusedResources,
    );

    return CanvasClearResult(
      removedElementIds: candidate.removedElementIds,
      removedResourceIds: candidate.removedResourceIds,
      didClearContent: true,
    );
  }

  @override
  void replaceDraftDocument(CanvasDocument document) {
    _materializedDraft.replaceDocument(document);
  }

  _SparseClearCandidate _sparseClearCandidate({
    required bool removeUnusedResources,
  }) {
    final removedElementIds = _structure.clearContent();
    for (final id in removedElementIds) {
      _resourceReferences.recordTransition(before: _elementById(id));
    }
    return _SparseClearCandidate(
      removedElementIds: removedElementIds,
      removedResourceIds: removeUnusedResources
          ? _sparseClearRemovedResourceIds()
          : const <CanvasResourceId>[],
    );
  }

  List<CanvasResourceId> _sparseClearRemovedResourceIds() {
    return List<CanvasResourceId>.unmodifiable([
      for (final id in _currentResourceIds())
        if (!_resourceReferences.isReferenced(id)) id,
    ]);
  }

  void _installSparseClear(
    _SparseClearCandidate candidate, {
    required bool removeUnusedResources,
  }) {
    _applySparseClearOverlay(candidate);
    _mutationJournal.append(
      StoreSparseClearContent(removeUnusedResources: removeUnusedResources),
    );
    _recordSparseClear(
      removedElementIds: candidate.removedElementIds,
      removedResourceIds: candidate.removedResourceIds,
    );
  }

  void _mergeRevisionDelta(StoreRevisionDelta delta) {
    _revisionDelta = _revisionDelta.merge(delta);
  }

  void _recordSparseElementUpdate({
    required CanvasElement after,
    required ElementUpdateCompileResult compiledUpdate,
  }) {
    _touchedSet.touchUpdatedElement(after.id);
    if (compiledUpdate.touchesSpatial) {
      _touchedSet.touchGeometryElement(after.id);
    }
    if (compiledUpdate.transformsElement) {
      _touchedSet.touchTransformedElement(after.id);
    }
    if (compiledUpdate.touchesVisual) {
      _touchedSet.touchVisualElement(after.id);
    }
    if (compiledUpdate.prunesSelection &&
        _selectedElementIds.contains(after.id)) {
      _touchedSet.touchSelection();
    }
    _mergeRevisionDelta(compiledUpdate.revisionDelta);
  }

  void _recordSparseClear({
    required List<CanvasElementId> removedElementIds,
    required List<CanvasResourceId> removedResourceIds,
  }) {
    if (removedElementIds.isNotEmpty) {
      _touchedSet.touchRemovedElements(removedElementIds);
      if (_intersectsSelection(removedElementIds)) {
        _touchedSet.touchSelection();
      }
      _mergeRevisionDelta(const StoreRevisionDelta.structural());
    }
    if (removedResourceIds.isNotEmpty) {
      _touchedSet.touchResourceDescriptors(removedResourceIds);
      _mergeRevisionDelta(const StoreRevisionDelta.resource());
    }
  }

  void _applySparseClearOverlay(_SparseClearCandidate candidate) {
    for (final id in candidate.removedElementIds) {
      _elementOverrides.remove(id);
      if (!_addedElementIds.remove(id)) {
        _removedCommittedElementIds.add(id);
      }
    }
    for (final id in candidate.removedResourceIds) {
      _resourceOverrides.remove(id);
      if (!_addedResourceIds.remove(id)) {
        _removedCommittedResourceIds.add(id);
      }
    }
  }

  bool _intersectsSelection(Iterable<CanvasElementId> ids) {
    return ids.any(_selectedElementIds.contains);
  }

  void _admitSparseElement(CanvasElement element) {
    if (_elementById(element.id) != null) {
      throw CanvasDataException(
        code: CanvasDataErrorCode.duplicateElementId,
        message: 'duplicate element id.',
        path: 'elements.id',
      );
    }
  }

  bool _admitSparseLayer(CanvasLayerId id, {int? index}) {
    return _structure.ensureLayer(id, index: index);
  }

  int get _sparseLayerCount {
    return _structure.layerCount(committedCount: _committedSummary.layerCount);
  }

  int get _sparseElementCount {
    return _committedSummary.elementCount +
        _addedElementIds.length -
        _removedCommittedElementIds.length;
  }

  int get _sparseResourceCount {
    return _committedSummary.resourceCount +
        _addedResourceIds.length -
        _removedCommittedResourceIds.length;
  }

  void _trackSparseElementAdd(CanvasElementId id) {
    if (_facts.elementById(id) != null) {
      _removedCommittedElementIds.remove(id);

      return;
    }
    _addedElementIds.add(id);
  }

  CanvasLayerId _contentLayerForSparseAdd(CanvasLayerId? requestedLayerId) {
    if (requestedLayerId != null) {
      return requestedLayerId;
    }
    final layerId = _structure.lastLayerId();
    if (layerId == null) {
      final defaultLayerId = CanvasLayerId('default-layer');
      _structure.ensureLayer(defaultLayerId);

      return defaultLayerId;
    }

    return layerId;
  }

  void _trackSparseResourceUpsert(CanvasResourceId id) {
    if (_facts.resourceById(id) != null) {
      _removedCommittedResourceIds.remove(id);

      return;
    }
    _addedResourceIds.add(id);
  }

  CanvasElement? _elementById(CanvasElementId id) {
    final override = _elementOverrides[id];
    if (override != null) {
      return override;
    }
    if (_removedCommittedElementIds.contains(id)) {
      return null;
    }
    return _facts.elementById(id);
  }

  CanvasResource? _resourceById(CanvasResourceId id) {
    final override = _resourceOverrides[id];
    if (override != null) {
      return override;
    }
    if (_removedCommittedResourceIds.contains(id)) {
      return null;
    }
    return _facts.resourceById(id);
  }

  Iterable<CanvasResourceId> _currentResourceIds() sync* {
    for (final id in _facts.resourceIds) {
      if (!_removedCommittedResourceIds.contains(id)) {
        yield id;
      }
    }
    yield* _addedResourceIds;
  }

  @override
  void close() {
    _structure.dispose();
    _resourceReferences.dispose();
  }
}

// The sole sparse-intent owner keeps Store export and direct promotion adjacent
// so no second replay history or pre-application collection pass can emerge.
final class _SparseMutationJournal {
  final _SparseMutationStorage _storage = _SparseMutationStorage();

  bool get isNotEmpty => _storage.isNotEmpty;

  void append(StoreSparseMutation mutation) {
    _storage.append(mutation);
  }

  StoreSparseCommit storeSnapshot({
    required StoreRevisionDelta revisionDelta,
    CanvasElementId? affectedElementId,
  }) {
    return StoreSparseCommit(
      mutations: _storage,
      revisionDelta: revisionDelta,
      affectedElementId: affectedElementId,
    );
  }

  void promoteInto(DraftSparseMutationConsumer target) {
    _recordSparsePromotionWork(SparsePromotionWorkPhase.open);
    for (final mutation in _storage) {
      target.apply(mutation);
      _recordSparsePromotionWork(
        SparsePromotionWorkPhase.draftApplication,
        mutation: mutation,
      );
    }
    _storage.clear();
    _recordSparsePromotionWork(SparsePromotionWorkPhase.complete);
  }
}

// The storage owns the only mutable DTO list. Both Store export and promotion
// obtain values through this iterator, which observes each actual source
// advance before any consumer can apply that DTO.
final class _SparseMutationStorage extends IterableBase<StoreSparseMutation> {
  final List<StoreSparseMutation> _mutations = [];

  void append(StoreSparseMutation mutation) {
    _mutations.add(mutation);
  }

  @override
  bool get isNotEmpty => _mutations.isNotEmpty;

  void clear() {
    _mutations.clear();
  }

  @override
  Iterator<StoreSparseMutation> get iterator {
    return _SparseMutationStorageIterator(_mutations.iterator);
  }
}

final class _SparseMutationStorageIterator
    implements Iterator<StoreSparseMutation> {
  _SparseMutationStorageIterator(this._source);

  final Iterator<StoreSparseMutation> _source;
  StoreSparseMutation? _current;

  @override
  StoreSparseMutation get current {
    final mutation = _current;
    if (mutation == null) {
      throw StateError('Sparse mutation iterator has no current value.');
    }
    return mutation;
  }

  @override
  bool moveNext() {
    if (!_source.moveNext()) {
      _current = null;
      return false;
    }
    final mutation = _source.current;
    _current = mutation;
    _recordSparsePromotionWork(
      SparsePromotionWorkPhase.journalElementRead,
      mutation: mutation,
    );
    return true;
  }
}

void _recordSparsePromotionWork(
  SparsePromotionWorkPhase phase, {
  StoreSparseMutation? mutation,
}) {
  assert(() {
    final sink = Zone.current[_sparsePromotionWorkZoneKey];
    if (sink is void Function(SparsePromotionWorkEvent)) {
      sink(SparsePromotionWorkEvent(phase: phase, mutation: mutation));
    }
    return true;
  }(), 'sparse promotion work observation failed');
}

final class _SparseClearCandidate {
  const _SparseClearCandidate({
    required this.removedElementIds,
    required this.removedResourceIds,
  });

  final List<CanvasElementId> removedElementIds;
  final List<CanvasResourceId> removedResourceIds;
}

CanvasPalette _mergePaletteUpdate(
  CanvasPalette current,
  CanvasPaletteUpdate update,
) {
  if (!update.hasPenColors &&
      !update.hasBackgroundColors &&
      !update.hasGridSizes) {
    return current;
  }

  return CanvasPalette(
    penColors: update.hasPenColors ? update.penColors : current.penColors,
    backgroundColors: update.hasBackgroundColors
        ? update.backgroundColors
        : current.backgroundColors,
    gridSizes: update.hasGridSizes ? update.gridSizes : current.gridSizes,
  );
}

CanvasGrid _mergeGridUpdate(CanvasGrid current, CanvasGridUpdate update) {
  if (update.enabled == null &&
      update.cellSize == null &&
      update.color == null) {
    return current;
  }

  return CanvasGrid(
    enabled: update.enabled ?? current.enabled,
    cellSize: update.cellSize ?? current.cellSize,
    color: update.color ?? current.color,
  );
}

bool _samePalette(CanvasPalette left, CanvasPalette right) {
  return _sameList(left.penColors, right.penColors) &&
      _sameList(left.backgroundColors, right.backgroundColors) &&
      _sameList(left.gridSizes, right.gridSizes);
}

bool _sameList<T>(List<T> left, List<T> right) {
  if (left.length != right.length) {
    return false;
  }

  for (var index = 0; index < left.length; index += 1) {
    if (left[index] != right[index]) {
      return false;
    }
  }

  return true;
}
