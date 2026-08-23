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

/// Records the sparse promotion boundary only under asserts.
@visibleForTesting
T observeSparsePromotionWork<T>(
  void Function(SparsePromotionWorkEvent event) sink,
  T Function() operation,
) {
  return runZoned(operation, zoneValues: {_sparsePromotionWorkZoneKey: sink});
}

// CanvasEdit is intentionally represented by one session handle: the stale
// guard and draft reference must stay uniform across every public entry point.
// ignore: coupling-between-object-classes, number-of-methods
final class EditSession implements CanvasEdit {
  EditSession({required DraftDocument draft})
    : _backing = _MaterializedEditBacking(draft);

  EditSession.sparse({
    required SparseEditSessionFacts facts,
    required DraftDocument Function() promoteDraft,
    required Iterable<CanvasElementId> selectedElementIds,
  }) : _backing = _SparseEditBacking(
         facts: facts,
         promoteDraft: promoteDraft,
         selectedElementIds: selectedElementIds,
       );

  final _EditSessionBacking _backing;
  bool _isClosed = false;

  bool get didChange => _backing.didChange;
  StoreRevisionDelta get revisionDelta => _backing.revisionDelta;
  TouchedSet get touchedSet => _backing.touchedSet;
  CommitPlan get commitPlan => _backing.commitPlan;
  bool get hasMaterializedDraft => _backing.isMaterialized;
  bool get didReplaceDraftDocument => _backing.documentReplaced;
  StoreSparseCommit get sparseCommit => _backing.sparseCommit;

  void close() {
    _isClosed = true;
  }

  @override
  CanvasDocument readDraftDocument() {
    _ensureActive();

    return _backing.readDraftDocument();
  }

  @override
  CanvasDocumentSummary get draftSummary {
    _ensureActive();

    return _backing.draftSummary;
  }

  @override
  bool ensureLayer(CanvasLayerId id, {int? index}) {
    _ensureActive();
    return _backing.ensureLayer(id, index: index);
  }

  @override
  CanvasElementId addElement(
    CanvasElement element, {
    CanvasLayerId? layerId,
    int? index,
  }) {
    _ensureActive();
    return _backing.addElement(element, layerId: layerId, index: index);
  }

  @override
  CanvasElementId addBackgroundElement(CanvasElement element, {int? index}) {
    _ensureActive();
    return _backing.addBackgroundElement(element, index: index);
  }

  @override
  bool updateElement(CanvasElementUpdate update) {
    _ensureActive();
    return _backing.updateElement(update);
  }

  @override
  bool removeElement(CanvasElementId id) {
    _ensureActive();
    return _backing.removeElement(id);
  }

  @override
  bool upsertResource(CanvasResource resource) {
    _ensureActive();
    return _backing.upsertResource(resource);
  }

  @override
  bool removeUnusedResource(CanvasResourceId id) {
    _ensureActive();
    return _backing.removeUnusedResource(id);
  }

  @override
  void setBackgroundColor(Color color) {
    _ensureActive();
    _backing.setBackgroundColor(color);
  }

  @override
  void setGrid(CanvasGrid grid) {
    _ensureActive();
    _backing.setGrid(grid);
  }

  @override
  void setPalette(CanvasPalette palette) {
    _ensureActive();
    _backing.setPalette(palette);
  }

  @override
  void setCameraOffset(Offset offset) {
    _ensureActive();
    _backing.setCameraOffset(offset);
  }

  @override
  CanvasClearResult clearContent({bool removeUnusedResources = false}) {
    _ensureActive();
    return _backing.clearContent(removeUnusedResources: removeUnusedResources);
  }

  @override
  void replaceDraftDocument(CanvasDocument document) {
    _ensureActive();
    _backing.replaceDraftDocument(document);
  }

  void _ensureActive() {
    if (_isClosed) {
      throw StateError('CanvasEdit handle is stale.');
    }
  }
}

// Sparse edit sessions need the complete committed fact surface to avoid
// materializing public projections; splitting this port would add sync glue
// between facts that must be read from one store snapshot.
// ignore: number-of-methods
abstract interface class SparseEditSessionFacts {
  CanvasDocumentSummary get summary;
  CanvasBackground get background;
  CanvasCamera get camera;
  CanvasPalette get palette;
  bool hasLayer(CanvasLayerId id);
  Iterable<CanvasElementId> get backgroundElementIds;
  Iterable<CanvasLayerId> get layerIds;
  Iterable<CanvasElementId> elementIdsInLayer(CanvasLayerId id);
  Iterable<CanvasElementId> get elementIds;
  Iterable<CanvasResourceId> get resourceIds;
  CanvasElement? elementById(CanvasElementId id);
  CanvasResource? resourceById(CanvasResourceId id);
  bool isResourceReferenced(CanvasResourceId id);
}

// Backing implementations deliberately mirror the full CanvasEdit surface so
// stale guards and sparse/materialized dispatch stay uniform across entries.
// ignore: coupling-between-object-classes, number-of-methods
abstract interface class _EditSessionBacking {
  bool get didChange;
  bool get isMaterialized;
  bool get documentReplaced;
  StoreRevisionDelta get revisionDelta;
  TouchedSet get touchedSet;
  CommitPlan get commitPlan;
  StoreSparseCommit get sparseCommit;
  CanvasDocument readDraftDocument();
  CanvasDocumentSummary get draftSummary;
  bool ensureLayer(CanvasLayerId id, {int? index});
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
  void setPalette(CanvasPalette palette);
  void setCameraOffset(Offset offset);
  CanvasClearResult clearContent({required bool removeUnusedResources});
  void replaceDraftDocument(CanvasDocument document);
}

// Materialized backing is a direct DraftDocument adapter for every CanvasEdit
// entry; splitting it would create method-group sync glue with no owner value.
// ignore: coupling-between-object-classes, number-of-methods
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
  CommitPlan get commitPlan => _draft.commitPlan;

  @override
  bool get documentReplaced => _draft.documentReplaced;

  @override
  StoreSparseCommit get sparseCommit {
    throw StateError(
      'Materialized edit sessions do not expose sparse commits.',
    );
  }

  @override
  CanvasDocument readDraftDocument() => _draft.readDocument();

  @override
  CanvasDocumentSummary get draftSummary => _draft.summary;

  @override
  bool ensureLayer(CanvasLayerId id, {int? index}) {
    return _draft.ensureLayer(id, index: index);
  }

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
  void setPalette(CanvasPalette palette) {
    _draft.setPalette(palette);
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
}

// Sparse backing owns the callback-local journal and promotion decision for
// the complete CanvasEdit surface; keeping it cohesive prevents mixed sparse
// and materialized state ownership.
// ignore: coupling-between-object-classes, number-of-methods, response-for-class, weighted-methods-per-class
final class _SparseEditBacking implements _EditSessionBacking {
  _SparseEditBacking({
    required SparseEditSessionFacts facts,
    required DraftDocument Function() promoteDraft,
    required Iterable<CanvasElementId> selectedElementIds,
  }) : _facts = facts,
       _promoteDraft = promoteDraft,
       _committedSummary = facts.summary,
       _selectedElementIds = Set.unmodifiable(selectedElementIds);

  final SparseEditSessionFacts _facts;
  final DraftDocument Function() _promoteDraft;
  final CanvasDocumentSummary _committedSummary;
  final _SparseMutationJournal _mutationJournal = _SparseMutationJournal();
  final TouchedSetBuilder _touchedSet = TouchedSetBuilder();
  StoreRevisionDelta _revisionDelta = const StoreRevisionDelta();
  final Set<CanvasElementId> _selectedElementIds;
  DraftDocument? _draft;
  final Set<CanvasLayerId> _addedLayerIds = {};
  List<CanvasElementId>? _backgroundElementOrder;
  List<CanvasLayerId>? _layerOrder;
  final Map<CanvasLayerId, List<CanvasElementId>> _contentElementOrderByLayer =
      {};
  final Map<CanvasElementId, CanvasElement> _elementOverrides = {};
  final Map<CanvasElementId, bool> _elementBackgroundLocationOverrides = {};
  final Map<CanvasElementId, CanvasLayerId> _elementContentLayerOverrides = {};
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
    final target = DraftSparsePromotionTarget.open(_promoteDraft);
    _mutationJournal.promoteInto(target);
    final promoted = target.finish();
    _draft = promoted;

    return promoted;
  }

  bool get _isMaterialized => _draft != null;

  @override
  bool get isMaterialized => _isMaterialized;

  @override
  bool get didChange {
    return _draft?.didChange ??
        _mutationJournal.isNotEmpty ||
            _backgroundOverride != null ||
            _cameraOverride != null ||
            _paletteOverride != null;
  }

  @override
  StoreRevisionDelta get revisionDelta {
    return _draft?.revisionDelta ?? _revisionDelta;
  }

  @override
  TouchedSet get touchedSet {
    return _draft?.touchedSet ?? _touchedSet.build();
  }

  @override
  CommitPlan get commitPlan {
    final draft = _draft;
    if (draft != null) {
      return draft.commitPlan;
    }

    return const CommitCompiler().compile(
      revisionDelta: _revisionDelta,
      touchedSet: _touchedSet.build(),
    );
  }

  @override
  bool get documentReplaced => _draft?.documentReplaced ?? false;

  @override
  StoreSparseCommit get sparseCommit {
    if (_isMaterialized) {
      throw StateError(
        'Materialized edit sessions do not expose sparse commits.',
      );
    }

    return _mutationJournal.storeSnapshot(revisionDelta: _revisionDelta);
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
      layerCount: _committedSummary.layerCount + _addedLayerIds.length,
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
    _elementBackgroundLocationOverrides[element.id] = false;
    _elementContentLayerOverrides[element.id] = targetLayerId;
    _elementOverrides[element.id] = element;
    _insertSparseContentElement(
      element.id,
      layerId: targetLayerId,
      index: index,
    );
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
    _elementBackgroundLocationOverrides[element.id] = true;
    _elementContentLayerOverrides.remove(element.id);
    _elementOverrides[element.id] = element;
    _insertSparseBackgroundElement(element.id, index: index);
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
    final removesBackgroundElement = _isBackgroundElementId(id);
    _elementOverrides.remove(id);
    _elementBackgroundLocationOverrides.remove(id);
    final contentLayerId = _elementContentLayerOverrides.remove(id);
    if (contentLayerId != null) {
      _removeSparseContentElement(id, contentLayerId);
    } else {
      _removeSparseBackgroundElement(id);
    }
    if (!_addedElementIds.remove(id) && _facts.elementById(id) != null) {
      _removedCommittedElementIds.add(id);
    }
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
    if (_isResourceReferenced(resource.id)) {
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
    if (_resourceById(id) == null || _isResourceReferenced(id)) {
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
    final removedElementIds = List<CanvasElementId>.unmodifiable(
      _currentContentElementIds(),
    );
    return _SparseClearCandidate(
      removedElementIds: removedElementIds,
      removedResourceIds: removeUnusedResources
          ? _sparseClearRemovedResourceIds()
          : const <CanvasResourceId>[],
    );
  }

  List<CanvasResourceId> _sparseClearRemovedResourceIds() {
    final retainedBackgroundResourceIds = <CanvasResourceId>{};
    for (final id in _mutableBackgroundElementOrder()) {
      final element = _elementById(id);
      switch (element) {
        case CanvasImageElement(:final resourceId):
          retainedBackgroundResourceIds.add(resourceId);
        case CanvasVectorElement(:final resourceId):
          retainedBackgroundResourceIds.add(resourceId);
        default:
      }
    }

    return List<CanvasResourceId>.unmodifiable([
      for (final id in _currentResourceIds())
        if (!retainedBackgroundResourceIds.contains(id)) id,
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
      _elementBackgroundLocationOverrides.remove(id);
      _elementContentLayerOverrides.remove(id);
      if (!_addedElementIds.remove(id)) {
        _removedCommittedElementIds.add(id);
      }
    }
    for (final layerId in _mutableLayerOrder()) {
      _contentElementOrderByLayer[layerId] = <CanvasElementId>[];
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
    if (_addedLayerIds.contains(id) || _facts.hasLayer(id)) {
      return false;
    }
    _addedLayerIds.add(id);
    final order = _mutableLayerOrder();
    if (!order.contains(id)) {
      order.insert(_clampedSparseInsertIndex(index, order.length), id);
    }

    return true;
  }

  int get _sparseLayerCount {
    return _committedSummary.layerCount + _addedLayerIds.length;
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
    final layerOrder = _mutableLayerOrder();
    if (layerOrder.isEmpty) {
      final defaultLayerId = CanvasLayerId('default-layer');
      layerOrder.add(defaultLayerId);

      return defaultLayerId;
    }

    return layerOrder.last;
  }

  void _insertSparseBackgroundElement(CanvasElementId id, {int? index}) {
    final order = _mutableBackgroundElementOrder();
    order.insert(_clampedSparseInsertIndex(index, order.length), id);
  }

  void _insertSparseContentElement(
    CanvasElementId id, {
    required CanvasLayerId layerId,
    int? index,
  }) {
    final order = _mutableContentElementOrder(layerId);
    order.insert(_clampedSparseInsertIndex(index, order.length), id);
  }

  void _removeSparseBackgroundElement(CanvasElementId id) {
    _backgroundElementOrder?.remove(id);
  }

  void _removeSparseContentElement(CanvasElementId id, CanvasLayerId layerId) {
    _contentElementOrderByLayer[layerId]?.remove(id);
  }

  List<CanvasElementId> _mutableBackgroundElementOrder() {
    return _backgroundElementOrder ??= List.of(_facts.backgroundElementIds);
  }

  List<CanvasLayerId> _mutableLayerOrder() {
    return _layerOrder ??= List.of(_facts.layerIds);
  }

  List<CanvasElementId> _mutableContentElementOrder(CanvasLayerId layerId) {
    return _contentElementOrderByLayer.putIfAbsent(layerId, () {
      return List.of(_facts.elementIdsInLayer(layerId));
    });
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

  bool _isResourceReferenced(CanvasResourceId id) {
    final localReference = _elementOverrides.values.any(
      (element) => elementReferencesResource(element, id),
    );
    if (localReference) {
      return true;
    }
    if (_removedCommittedResourceIds.contains(id)) {
      return false;
    }
    if (_canUseCommittedResourceReferenceFact) {
      return _facts.isResourceReferenced(id);
    }

    return _acceptedElements().any(
      (element) => elementReferencesResource(element, id),
    );
  }

  bool get _canUseCommittedResourceReferenceFact {
    return _removedCommittedElementIds.isEmpty &&
        !_elementOverrides.keys.any(_isCommittedElementId);
  }

  bool _isCommittedElementId(CanvasElementId id) {
    return _facts.elementById(id) != null;
  }

  Iterable<CanvasElementId> _currentElementIds() sync* {
    for (final id in _facts.elementIds) {
      if (!_removedCommittedElementIds.contains(id)) {
        yield id;
      }
    }
    yield* _addedElementIds;
  }

  Iterable<CanvasElementId> _currentContentElementIds() sync* {
    for (final layerId in _mutableLayerOrder()) {
      for (final id in _mutableContentElementOrder(layerId)) {
        if (_elementById(id) != null) {
          yield id;
        }
      }
    }
  }

  bool _isBackgroundElementId(CanvasElementId id) {
    final override = _elementBackgroundLocationOverrides[id];
    if (override != null) {
      return override;
    }

    return _facts.backgroundElementIds.contains(id);
  }

  Iterable<CanvasResourceId> _currentResourceIds() sync* {
    for (final id in _facts.resourceIds) {
      if (!_removedCommittedResourceIds.contains(id)) {
        yield id;
      }
    }
    yield* _addedResourceIds;
  }

  Iterable<CanvasElement> _acceptedElements() sync* {
    for (final id in _currentElementIds()) {
      final element = _elementById(id);
      if (element != null) {
        yield element;
      }
    }
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

  StoreSparseCommit storeSnapshot({required StoreRevisionDelta revisionDelta}) {
    return StoreSparseCommit(mutations: _storage, revisionDelta: revisionDelta);
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

int _clampedSparseInsertIndex(int? requestedIndex, int length) {
  if (requestedIndex == null || requestedIndex > length) {
    return length;
  }
  if (requestedIndex < 0) {
    return 0;
  }

  return requestedIndex;
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
