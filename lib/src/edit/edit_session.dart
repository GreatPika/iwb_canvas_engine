import 'dart:ui';

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
import '../store/sparse_store_commit.dart';
import '../store/store_revision_delta.dart';
import 'commit_compiler.dart';
import 'commit_plan.dart';
import 'draft_document.dart';
import 'element_update_application.dart';
import 'touched_set_builder.dart';

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
  CommitPlan get commitPlan => _backing.commitPlan;
  bool get hasMaterializedDraft => _backing.isMaterialized;
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
  StoreRevisionDelta get revisionDelta;
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
  CommitPlan get commitPlan => _draft.commitPlan;

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
  final List<void Function(DraftDocument draft)> _journal = [];
  final List<StoreSparseMutation> _mutations = [];
  final TouchedSetBuilder _touchedSet = TouchedSetBuilder();
  StoreRevisionDelta _revisionDelta = const StoreRevisionDelta();
  final Set<CanvasElementId> _selectedElementIds;
  DraftDocument? _draft;
  final Set<CanvasLayerId> _addedLayerIds = {};
  final Map<CanvasElementId, CanvasElement> _elementOverrides = {};
  final Map<CanvasElementId, bool> _elementBackgroundLocationOverrides = {};
  final Set<CanvasElementId> _addedElementIds = {};
  final Set<CanvasElementId> _removedCommittedElementIds = {};
  final Map<CanvasResourceId, CanvasResource> _resourceOverrides = {};
  final Set<CanvasResourceId> _addedResourceIds = {};
  final Set<CanvasResourceId> _removedCommittedResourceIds = {};
  bool _elementsCleared = false;
  bool _resourcesCleared = false;
  CanvasBackground? _backgroundOverride;
  CanvasCamera? _cameraOverride;
  CanvasPalette? _paletteOverride;

  DraftDocument get _materializedDraft {
    final existing = _draft;
    if (existing != null) {
      return existing;
    }
    final promoted = _promoteDraft();
    for (final replay in _journal) {
      replay(promoted);
    }
    _journal.clear();
    _draft = promoted;

    return promoted;
  }

  bool get _isMaterialized => _draft != null;

  @override
  bool get isMaterialized => _isMaterialized;

  @override
  bool get didChange {
    return _draft?.didChange ??
        _journal.isNotEmpty ||
            _backgroundOverride != null ||
            _cameraOverride != null ||
            _paletteOverride != null;
  }

  @override
  StoreRevisionDelta get revisionDelta {
    return _draft?.revisionDelta ?? _revisionDelta;
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
  StoreSparseCommit get sparseCommit {
    if (_isMaterialized) {
      throw StateError(
        'Materialized edit sessions do not expose sparse commits.',
      );
    }

    return StoreSparseCommit(
      mutations: _mutations,
      revisionDelta: _revisionDelta,
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
      layerCount: _committedSummary.layerCount + _addedLayerIds.length,
      resourceCount: _sparseResourceCount,
    );
  }

  @override
  bool ensureLayer(CanvasLayerId id, {int? index}) {
    if (_isMaterialized) {
      return _materializedDraft.ensureLayer(id, index: index);
    }
    if (!_admitSparseLayer(id)) {
      return false;
    }
    _journal.add((draft) => draft.ensureLayer(id, index: index));
    _mutations.add(StoreSparseEnsureLayer(id, index: index));
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
    if (layerId != null) {
      if (_admitSparseLayer(layerId)) {
        _touchedSet.touchLayer(layerId);
      }
    } else if (_sparseLayerCount == 0) {
      final defaultLayerId = CanvasLayerId('default-layer');
      if (_admitSparseLayer(defaultLayerId)) {
        _touchedSet.touchLayer(defaultLayerId);
      }
    }
    _trackSparseElementAdd(element.id);
    _elementBackgroundLocationOverrides[element.id] = false;
    _elementOverrides[element.id] = element;
    _journal.add(
      (draft) => draft.addElement(element, layerId: layerId, index: index),
    );
    _mutations.add(
      StoreSparseAddElement(element: element, layerId: layerId, index: index),
    );
    _touchedSet.touchAddedElement(element.id);
    _mergeRevisionDelta(const StoreRevisionDelta.structural());

    return element.id;
  }

  @override
  CanvasElementId addBackgroundElement(CanvasElement element, {int? index}) {
    if (_isMaterialized) {
      return _materializedDraft.addBackgroundElement(element, index: index);
    }
    _admitSparseElement(element);
    _trackSparseElementAdd(element.id);
    _elementBackgroundLocationOverrides[element.id] = true;
    _elementOverrides[element.id] = element;
    _journal.add((draft) => draft.addBackgroundElement(element, index: index));
    _mutations.add(
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
    _validateSparseElementResourceReferences(after);
    final compiledUpdate = const CommitCompiler().compileElementUpdate(
      before: before,
      after: after,
    );
    _elementOverrides[after.id] = after;
    _journal.add((draft) => draft.updateElement(update));
    _mutations.add(
      StoreSparseUpdateElement(
        element: after,
        requiredRevisionDelta: compiledUpdate.revisionDelta,
      ),
    );
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
    if (!_addedElementIds.remove(id) &&
        !_elementsCleared &&
        _facts.elementById(id) != null) {
      _removedCommittedElementIds.add(id);
    }
    _journal.add((draft) => draft.removeElement(id));
    _mutations.add(StoreSparseRemoveElement(id));
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
    if (current != null && _sameResource(current, resource)) {
      return false;
    }
    _trackSparseResourceUpsert(resource.id);
    _resourceOverrides[resource.id] = resource;
    _journal.add((draft) => draft.upsertResource(resource));
    _mutations.add(StoreSparseUpsertResource(resource));
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
    if (!_addedResourceIds.remove(id) &&
        !_resourcesCleared &&
        _facts.resourceById(id) != null) {
      _removedCommittedResourceIds.add(id);
    }
    _journal.add((draft) => draft.removeUnusedResource(id));
    _mutations.add(StoreSparseRemoveUnusedResource(id));
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
    _journal.add((draft) => draft.setBackgroundColor(color));
    _mutations.add(StoreSparseSetBackground(nextBackground));
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
    _journal.add((draft) => draft.setGrid(grid));
    _mutations.add(StoreSparseSetBackground(nextBackground));
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
    _journal.add((draft) => draft.setPalette(palette));
    _mutations.add(StoreSparseSetPalette(palette));
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
    _journal.add((draft) => draft.setCameraOffset(offset));
    _mutations.add(StoreSparseSetCamera(next));
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
      _currentDocumentOrderElementIds(),
    );
    return _SparseClearCandidate(
      removedElementIds: removedElementIds,
      removedBackgroundElementIds: List.unmodifiable(
        removedElementIds.where(_isBackgroundElementId),
      ),
      removedResourceIds: removeUnusedResources
          ? List.unmodifiable(_currentResourceIds())
          : const <CanvasResourceId>[],
    );
  }

  void _installSparseClear(
    _SparseClearCandidate candidate, {
    required bool removeUnusedResources,
  }) {
    _applySparseClearOverlay(removeUnusedResources: removeUnusedResources);
    _journal.add(
      (draft) =>
          draft.clearContent(removeUnusedResources: removeUnusedResources),
    );
    _mutations.add(
      StoreSparseClearContent(removeUnusedResources: removeUnusedResources),
    );
    _recordSparseClear(
      removedElementIds: candidate.removedElementIds,
      removedBackgroundElementIds: candidate.removedBackgroundElementIds,
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
    required List<CanvasElementId> removedBackgroundElementIds,
    required List<CanvasResourceId> removedResourceIds,
  }) {
    if (removedElementIds.isNotEmpty) {
      _touchedSet.touchRemovedElements(removedElementIds);
      if (removedBackgroundElementIds.isNotEmpty) {
        _touchedSet.touchBackgroundLayer();
      }
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

  void _applySparseClearOverlay({required bool removeUnusedResources}) {
    _elementsCleared = true;
    _addedElementIds.clear();
    _removedCommittedElementIds.clear();
    _elementOverrides.clear();
    _elementBackgroundLocationOverrides.clear();
    if (removeUnusedResources) {
      _resourcesCleared = true;
      _addedResourceIds.clear();
      _removedCommittedResourceIds.clear();
      _resourceOverrides.clear();
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
    _validateSparseElementResourceReferences(element);
  }

  bool _admitSparseLayer(CanvasLayerId id) {
    if (_addedLayerIds.contains(id) || _facts.hasLayer(id)) {
      return false;
    }
    _addedLayerIds.add(id);

    return true;
  }

  int get _sparseLayerCount {
    return _committedSummary.layerCount + _addedLayerIds.length;
  }

  int get _sparseElementCount {
    return _elementsCleared
        ? _addedElementIds.length
        : _committedSummary.elementCount +
              _addedElementIds.length -
              _removedCommittedElementIds.length;
  }

  int get _sparseResourceCount {
    return _resourcesCleared
        ? _addedResourceIds.length
        : _committedSummary.resourceCount +
              _addedResourceIds.length -
              _removedCommittedResourceIds.length;
  }

  void _trackSparseElementAdd(CanvasElementId id) {
    if (_elementsCleared) {
      _addedElementIds.add(id);

      return;
    }
    if (_facts.elementById(id) != null) {
      _removedCommittedElementIds.remove(id);

      return;
    }
    _addedElementIds.add(id);
  }

  void _trackSparseResourceUpsert(CanvasResourceId id) {
    if (_resourcesCleared) {
      _addedResourceIds.add(id);

      return;
    }
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
    if (_elementsCleared || _removedCommittedElementIds.contains(id)) {
      return null;
    }
    return _facts.elementById(id);
  }

  CanvasResource? _resourceById(CanvasResourceId id) {
    final override = _resourceOverrides[id];
    if (override != null) {
      return override;
    }
    if (_resourcesCleared || _removedCommittedResourceIds.contains(id)) {
      return null;
    }
    return _facts.resourceById(id);
  }

  bool _isResourceReferenced(CanvasResourceId id) {
    final localReference = _elementOverrides.values.any((element) {
      return element is CanvasImageElement && element.resourceId == id;
    });
    if (localReference) {
      return true;
    }
    if (_elementsCleared || _removedCommittedResourceIds.contains(id)) {
      return false;
    }
    if (_canUseCommittedResourceReferenceFact) {
      return _facts.isResourceReferenced(id);
    }

    return _acceptedElements().any((element) {
      return element is CanvasImageElement && element.resourceId == id;
    });
  }

  void _validateSparseElementResourceReferences(CanvasElement element) {
    if (element case CanvasImageElement(:final resourceId)) {
      if (_resourceById(resourceId) == null) {
        throw CanvasDataException(
          code: CanvasDataErrorCode.missingResourceReference,
          message: 'image element references a missing resource.',
          path: 'image.resourceId',
        );
      }
    }
  }

  bool get _canUseCommittedResourceReferenceFact {
    return _removedCommittedElementIds.isEmpty &&
        !_elementOverrides.keys.any(_isCommittedElementId);
  }

  bool _isCommittedElementId(CanvasElementId id) {
    return _facts.elementById(id) != null;
  }

  Iterable<CanvasElementId> _currentElementIds() sync* {
    if (!_elementsCleared) {
      for (final id in _facts.elementIds) {
        if (!_removedCommittedElementIds.contains(id)) {
          yield id;
        }
      }
    }
    yield* _addedElementIds;
  }

  Iterable<CanvasElementId> _currentDocumentOrderElementIds() sync* {
    final currentIds = List<CanvasElementId>.unmodifiable(_currentElementIds());
    for (final id in currentIds) {
      if (_isBackgroundElementId(id)) {
        yield id;
      }
    }
    for (final id in currentIds) {
      if (!_isBackgroundElementId(id)) {
        yield id;
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
    if (!_resourcesCleared) {
      for (final id in _facts.resourceIds) {
        if (!_removedCommittedResourceIds.contains(id)) {
          yield id;
        }
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

final class _SparseClearCandidate {
  const _SparseClearCandidate({
    required this.removedElementIds,
    required this.removedBackgroundElementIds,
    required this.removedResourceIds,
  });

  final List<CanvasElementId> removedElementIds;
  final List<CanvasElementId> removedBackgroundElementIds;
  final List<CanvasResourceId> removedResourceIds;
}

bool _sameResource(CanvasResource left, CanvasResource right) {
  return left is CanvasImageResource &&
      right is CanvasImageResource &&
      left.id == right.id &&
      left.source == right.source &&
      left.mimeType == right.mimeType &&
      left.contentHash == right.contentHash &&
      left.byteLength == right.byteLength &&
      left.metadata == right.metadata;
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
