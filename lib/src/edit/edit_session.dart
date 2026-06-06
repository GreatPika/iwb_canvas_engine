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
import '../store/store_revision_delta.dart';
import 'commit_plan.dart';
import 'draft_document.dart';
import 'element_update_application.dart';

// CanvasEdit is intentionally represented by one session handle: the stale
// guard and draft reference must stay uniform across every public entry point.
// ignore: coupling-between-object-classes, number-of-methods
final class EditSession implements CanvasEdit {
  EditSession({required DraftDocument draft})
    : _backing = _MaterializedEditBacking(draft);

  EditSession.sparse({
    required SparseEditSessionFacts facts,
    required DraftDocument Function() promoteDraft,
  }) : _backing = _SparseEditBacking(facts: facts, promoteDraft: promoteDraft);

  final _EditSessionBacking _backing;
  bool _isClosed = false;

  bool get didChange => _backing.didChange;
  StoreRevisionDelta get revisionDelta => _backing.revisionDelta;
  CommitPlan get commitPlan => _backing.commitPlan;

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

abstract interface class SparseEditSessionFacts {
  CanvasDocumentSummary get summary;
  CanvasBackground get background;
  CanvasCamera get camera;
  CanvasPalette get palette;
  bool hasLayer(CanvasLayerId id);
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
  StoreRevisionDelta get revisionDelta;
  CommitPlan get commitPlan;
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
  StoreRevisionDelta get revisionDelta => _draft.revisionDelta;

  @override
  CommitPlan get commitPlan => _draft.commitPlan;

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
  }) : _facts = facts,
       _promoteDraft = promoteDraft,
       _committedSummary = facts.summary;

  final SparseEditSessionFacts _facts;
  final DraftDocument Function() _promoteDraft;
  final CanvasDocumentSummary _committedSummary;
  final List<void Function(DraftDocument draft)> _journal = [];
  DraftDocument? _draft;
  final Set<CanvasLayerId> _addedLayerIds = {};
  final Map<CanvasElementId, CanvasElement> _elementOverrides = {};
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
  bool get didChange {
    return _draft?.didChange ??
        _journal.isNotEmpty ||
            _backgroundOverride != null ||
            _cameraOverride != null ||
            _paletteOverride != null;
  }

  @override
  StoreRevisionDelta get revisionDelta {
    return _materializedDraft.revisionDelta;
  }

  @override
  CommitPlan get commitPlan => _materializedDraft.commitPlan;

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
      _admitSparseLayer(layerId);
    } else if (_sparseLayerCount == 0) {
      _admitSparseLayer(CanvasLayerId('default-layer'));
    }
    _trackSparseElementAdd(element.id);
    _elementOverrides[element.id] = element;
    _journal.add(
      (draft) => draft.addElement(element, layerId: layerId, index: index),
    );

    return element.id;
  }

  @override
  CanvasElementId addBackgroundElement(CanvasElement element, {int? index}) {
    if (_isMaterialized) {
      return _materializedDraft.addBackgroundElement(element, index: index);
    }
    _admitSparseElement(element);
    _trackSparseElementAdd(element.id);
    _elementOverrides[element.id] = element;
    _journal.add((draft) => draft.addBackgroundElement(element, index: index));

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
    _elementOverrides[after.id] = after;
    _journal.add((draft) => draft.updateElement(update));

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
    _elementOverrides.remove(id);
    if (!_addedElementIds.remove(id) &&
        !_elementsCleared &&
        _facts.elementById(id) != null) {
      _removedCommittedElementIds.add(id);
    }
    _journal.add((draft) => draft.removeElement(id));

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
    _backgroundOverride = CanvasBackground(color: color, grid: current.grid);
    _journal.add((draft) => draft.setBackgroundColor(color));
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
    _backgroundOverride = CanvasBackground(color: current.color, grid: grid);
    _journal.add((draft) => draft.setGrid(grid));
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
  }

  @override
  CanvasClearResult clearContent({required bool removeUnusedResources}) {
    if (_isMaterialized) {
      return _materializedDraft.clearContent(
        removeUnusedResources: removeUnusedResources,
      );
    }
    final removedElementIds = List<CanvasElementId>.unmodifiable(
      _currentElementIds(),
    );
    final removedResourceIds = removeUnusedResources
        ? List<CanvasResourceId>.unmodifiable(_currentResourceIds())
        : const <CanvasResourceId>[];
    final didClearContent =
        removedElementIds.isNotEmpty || removedResourceIds.isNotEmpty;
    if (!didClearContent) {
      return CanvasClearResult(
        removedElementIds: removedElementIds,
        removedResourceIds: removedResourceIds,
        didClearContent: false,
      );
    }
    _elementsCleared = true;
    _addedElementIds.clear();
    _removedCommittedElementIds.clear();
    _elementOverrides.clear();
    if (removeUnusedResources) {
      _resourcesCleared = true;
      _addedResourceIds.clear();
      _removedCommittedResourceIds.clear();
      _resourceOverrides.clear();
    }
    _journal.add(
      (draft) =>
          draft.clearContent(removeUnusedResources: removeUnusedResources),
    );

    return CanvasClearResult(
      removedElementIds: removedElementIds,
      removedResourceIds: removedResourceIds,
      didClearContent: didClearContent,
    );
  }

  @override
  void replaceDraftDocument(CanvasDocument document) {
    _materializedDraft.replaceDocument(document);
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
