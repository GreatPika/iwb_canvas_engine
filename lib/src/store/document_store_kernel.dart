import 'dart:ui';

// DocumentStoreKernel directly names the DTO, fact, projection, and revision
// owners it coordinates; hiding one import behind a wrapper would obscure the
// committed-store boundary instead of simplifying it.
// ignore_for_file: number-of-imports

import '../contracts/public/canvas_document.dart';
import '../contracts/public/canvas_element.dart';
import '../contracts/public/canvas_errors.dart';
import '../contracts/public/canvas_geometry.dart';
import '../contracts/public/canvas_ids.dart';
import '../contracts/public/canvas_metadata.dart';
import '../contracts/public/canvas_resource.dart';
import 'canvas_element_snapshot.dart';
import 'committed_document.dart';
import 'document_projection_cache.dart';
import 'element_registry.dart';
import 'family_tables.dart';
import 'resource_table.dart';
import 'revision_state.dart';
import 'sparse_store_commit.dart';
import 'store_revision_delta.dart';

// DocumentStoreKernel is the single owner for committed document facts, read
// projection, id admission, and selection normalization inputs; splitting these
// accessors would obscure the shared committed-state source of truth.
// ignore: coupling-between-object-classes, number-of-methods, response-for-class, weighted-methods-per-class
final class DocumentStoreKernel {
  DocumentStoreKernel(CanvasDocument initialDocument)
    : _document = CommittedDocument(initialDocument) {
    _elementIds = _IdAdmission(
      prefix: 'e',
      admittedIds: _document.admittedElementIds,
    );
    _layerIds = _IdAdmission(
      prefix: 'l',
      admittedIds: _document.admittedLayerIds,
    );
    _resourceIds = _IdAdmission(
      prefix: 'r',
      admittedIds: _document.admittedResourceIds,
    );
  }

  CommittedDocument _document;
  final DocumentProjectionCache _projectionCache = DocumentProjectionCache();
  late _IdAdmission _elementIds;
  late _IdAdmission _layerIds;
  late _IdAdmission _resourceIds;

  CanvasDocument readDocument() => _projectionCache.projectionFor(_document);

  CanvasDocumentSummary get documentSummary => _document.summary;
  int get documentRevision => _document.revisions.documentRevision;
  int get structuralRevision => _document.revisions.structuralRevision;
  int get boundsRevision => _document.revisions.boundsRevision;
  int get elementVisualRevision => _document.revisions.elementVisualRevision;
  int get backgroundRevision => _document.revisions.backgroundRevision;
  int get gridRevision => _document.revisions.gridRevision;
  int get resourceRevision => _document.revisions.resourceRevision;
  CanvasBackground get background => _document.background;
  CanvasCamera get camera => _document.camera;
  CanvasPalette get palette => _document.palette;
  int get projectionBuildCount => _projectionCache.buildCount;
  int get resourceCount => _document.resourceTable.rows.length;
  List<CanvasResource> get resources {
    return List.unmodifiable(
      _document.resourceTable.rows.map(ResourceTable.copy),
    );
  }

  CanvasResource? resourceById(CanvasResourceId id) {
    for (final resource in _document.resourceTable.rows) {
      if (resource.id == id) {
        return ResourceTable.copy(resource);
      }
    }

    return null;
  }

  CanvasElement? elementById(CanvasElementId id) {
    return _document.elements.elementById(id);
  }

  Iterable<CanvasElementId> get backgroundElementIds {
    return _document.elements.backgroundElementIds;
  }

  bool hasLayer(CanvasLayerId id) {
    return _document.elements.containsLayer(id);
  }

  Iterable<CanvasLayerId> get layerIds {
    return _document.elements.layerTable.rows.map((row) => row.id);
  }

  Iterable<CanvasElementId> elementIdsInLayer(CanvasLayerId id) {
    for (final row in _document.elements.layerTable.rows) {
      if (row.id == id) {
        return row.elementIds;
      }
    }

    return const <CanvasElementId>[];
  }

  bool isResourceReferenced(CanvasResourceId id) {
    return _document.elements.referencesResource(id);
  }

  Iterable<CanvasElementId> get elementIds {
    return _document.elements.frameElementOrder;
  }

  Iterable<CanvasResourceId> get resourceIds {
    return _document.resourceTable.rows.map((resource) => resource.id);
  }

  Set<CanvasElementId> get selectableElementIds {
    return Set.unmodifiable(_document.elements.selectableElementIds);
  }

  Set<CanvasElementId> get contentElementIds {
    return Set.unmodifiable(_document.elements.contentElementIds);
  }

  int elementCount(int structuralRevision) {
    if (structuralRevision != _document.revisions.structuralRevision) {
      return 0;
    }

    return _document.elements.frameElementOrder.length;
  }

  List<StoreElementHandle> elementHandles(int structuralRevision) {
    if (structuralRevision != _document.revisions.structuralRevision) {
      return const [];
    }

    return List.unmodifiable([
      for (final indexed in _document.elements.frameElementOrder.indexed)
        StoreElementHandle(
          id: indexed.$2,
          structuralRevision: structuralRevision,
          generation: 0,
          orderToken: indexed.$1,
        ),
    ]);
  }

  StoreElementHandle? elementHandleForId(
    int structuralRevision,
    CanvasElementId id,
  ) {
    if (structuralRevision != _document.revisions.structuralRevision) {
      return null;
    }
    final orderToken = _document.elements.frameOrderTokensById[id];
    if (orderToken == null) {
      return null;
    }

    return StoreElementHandle(
      id: id,
      structuralRevision: structuralRevision,
      generation: 0,
      orderToken: orderToken,
    );
  }

  StoreElementFacts? resolveElement(StoreElementHandle handle) {
    if (handle.structuralRevision != _document.revisions.structuralRevision ||
        handle.generation != 0) {
      return null;
    }
    final facts = _document.elements.elementFrameFacts(handle.id);
    if (facts == null) {
      return null;
    }
    if (!_document.elements.frameOrderMatches(handle.orderToken, handle.id)) {
      return null;
    }
    final location = _document.elements.elementLocationFacts[handle.id];
    if (location == null) {
      return null;
    }

    return StoreElementFacts.fromFamilyFacts(
      facts,
      orderToken: handle.orderToken,
      location: location,
    );
  }

  StoreResourceDescriptorFacts? resourceDescriptor(CanvasResourceId id) {
    return _document.resourceDescriptor(id);
  }

  StoreElementFacts? elementFactsById(CanvasElementId id) {
    final orderToken = _document.elements.frameOrderTokensById[id];
    if (orderToken == null) {
      return null;
    }
    final facts = _document.elements.elementFrameFacts(id);
    final location = _document.elements.elementLocationFacts[id];
    if (facts == null || location == null) {
      return null;
    }

    return StoreElementFacts.fromFamilyFacts(
      facts,
      orderToken: orderToken,
      location: location,
    );
  }

  Set<CanvasElementId> normalizeSelection(Iterable<CanvasElementId> ids) {
    return _normalizeSelectionInCommittedDocument(_document, ids);
  }

  Set<CanvasElementId> normalizeSelectionForSparseCommit(
    PreparedSparseStoreCommit commit,
    Iterable<CanvasElementId> ids,
  ) {
    if (commit.baseRevisions != _document.revisions) {
      throw StateError('Prepared sparse store commit is stale.');
    }

    return _normalizeSelectionInCommittedDocument(commit.document, ids);
  }

  Set<CanvasElementId> normalizeSelectionForDocument(
    CanvasDocument document,
    Iterable<CanvasElementId> ids,
  ) {
    return _normalizeSelectionInCommittedDocument(
      CommittedDocument.withRevisions(
        document,
        revisions: const RevisionState(),
      ),
      ids,
    );
  }

  CanvasElementId generateElementId() {
    return CanvasElementId(_elementIds.nextValue());
  }

  CanvasLayerId generateLayerId() {
    return CanvasLayerId(_layerIds.nextValue());
  }

  CanvasResourceId generateResourceId() {
    return CanvasResourceId(_resourceIds.nextValue());
  }

  void installDocument(CanvasDocument document, StoreRevisionDelta delta) {
    if (!delta.hasChanges) {
      return;
    }
    _document = CommittedDocument.withRevisions(
      document,
      revisions: delta.advance(_document.revisions),
    );
    _elementIds.admitAll(_document.admittedElementIds);
    _layerIds.admitAll(_document.admittedLayerIds);
    _resourceIds.admitAll(_document.admittedResourceIds);
  }

  void replaceDocument(CanvasDocument document, StoreRevisionDelta delta) {
    if (!delta.hasChanges) {
      return;
    }
    _document = CommittedDocument.withRevisions(
      document,
      revisions: delta.advance(_document.revisions),
    );
    _elementIds = _IdAdmission(
      prefix: 'e',
      admittedIds: _document.admittedElementIds,
    );
    _layerIds = _IdAdmission(
      prefix: 'l',
      admittedIds: _document.admittedLayerIds,
    );
    _resourceIds = _IdAdmission(
      prefix: 'r',
      admittedIds: _document.admittedResourceIds,
    );
  }

  // Sparse preparation validates, applies, and records admitted-id deltas in
  // one pass so commit acceptance cannot drift from generator admission.
  // ignore: cyclomatic-complexity, halstead-volume, source-lines-of-code
  PreparedSparseStoreCommit prepareSparseCommit(StoreSparseCommit commit) {
    final revisionDelta = _validatedSparseRevisionDelta(commit.revisionDelta);
    final acceptedRevisions = revisionDelta.advance(_document.revisions);
    var nextDocument = _document;
    var didMutateFacts = false;
    var requiredRevisionDelta = const StoreRevisionDelta();
    final admittedIds = _SparseAdmittedIds();
    for (var index = 0; index < commit.mutations.length;) {
      final mutation = commit.mutations[index];
      if (mutation is StoreSparseUpdateElement) {
        final updates = <StoreSparseUpdateElement>[];
        while (index < commit.mutations.length) {
          final current = commit.mutations[index];
          if (current is! StoreSparseUpdateElement) {
            break;
          }
          updates.add(current);
          index += 1;
        }
        final applied = _updateElements(nextDocument, updates);
        nextDocument = applied.document;
        didMutateFacts = didMutateFacts || applied.didMutateFacts;
        requiredRevisionDelta = requiredRevisionDelta.merge(
          applied.requiredRevisionDelta,
        );
        continue;
      }
      final applied = _applySparseMutation(
        nextDocument,
        mutation,
        acceptedRevisions: acceptedRevisions,
      );
      nextDocument = applied.document;
      didMutateFacts = didMutateFacts || applied.didMutateFacts;
      requiredRevisionDelta = requiredRevisionDelta.merge(
        applied.requiredRevisionDelta,
      );
      if (applied.didMutateFacts) {
        admittedIds.addMutation(mutation);
      }
      index += 1;
    }
    if (didMutateFacts && !revisionDelta.hasChanges) {
      throw ArgumentError.value(
        commit.revisionDelta,
        'revisionDelta',
        'sparse store commits that change facts must advance revisions.',
      );
    }
    _validateSparseRevisionCoverage(
      provided: revisionDelta,
      required: requiredRevisionDelta,
    );

    return PreparedSparseStoreCommit(
      baseRevisions: _document.revisions,
      document: didMutateFacts
          ? nextDocument.copyWith(revisions: acceptedRevisions)
          : _document,
      revisionDelta: didMutateFacts
          ? revisionDelta
          : const StoreRevisionDelta(),
      admittedElementIds: didMutateFacts ? admittedIds.elementIds : const [],
      admittedLayerIds: didMutateFacts ? admittedIds.layerIds : const [],
      admittedResourceIds: didMutateFacts ? admittedIds.resourceIds : const [],
    );
  }

  void installSparseCommit(PreparedSparseStoreCommit commit) {
    if (!commit.hasChanges) {
      return;
    }
    if (commit.baseRevisions != _document.revisions) {
      throw StateError('Prepared sparse store commit is stale.');
    }
    _document = commit.document;
    _elementIds.admitAll(commit.admittedElementIds);
    _layerIds.admitAll(commit.admittedLayerIds);
    _resourceIds.admitAll(commit.admittedResourceIds);
  }

  _SparseMutationResult _applySparseMutation(
    CommittedDocument document,
    StoreSparseMutation mutation, {
    required RevisionState acceptedRevisions,
  }) {
    return switch (mutation) {
      StoreSparseEnsureLayer(:final id, :final index) => _ensureLayer(
        document,
        id,
        index: index,
      ),
      final StoreSparseAddElement mutation => _addElement(document, mutation),
      final StoreSparseUpdateElement mutation => _updateElement(
        document,
        mutation,
      ),
      StoreSparseRemoveElement(:final id) => _removeElement(document, id),
      StoreSparseUpsertResource(:final resource) => _upsertResource(
        document,
        resource,
        acceptedRevisions: acceptedRevisions,
      ),
      StoreSparseRemoveUnusedResource(:final id) => _removeUnusedResource(
        document,
        id,
        acceptedRevisions: acceptedRevisions,
      ),
      StoreSparseClearContent(:final removeUnusedResources) => _clearContent(
        document,
        removeUnusedResources: removeUnusedResources,
        acceptedRevisions: acceptedRevisions,
      ),
      StoreSparseSetBackground(:final background) => _setBackground(
        document,
        background,
      ),
      StoreSparseSetCamera(:final camera) => _setCamera(document, camera),
      StoreSparseSetPalette(:final palette) => _setPalette(document, palette),
    };
  }

  _SparseMutationResult _ensureLayer(
    CommittedDocument document,
    CanvasLayerId id, {
    int? index,
  }) {
    if (document.elements.containsLayer(id)) {
      return _SparseMutationResult.unchanged(document);
    }

    return _SparseMutationResult.changed(
      document.copyWith(
        elements: document.elements.ensureLayer(id, index: index),
      ),
      requiredRevisionDelta: const StoreRevisionDelta.layerStructural(),
    );
  }

  _SparseMutationResult _addElement(
    CommittedDocument document,
    StoreSparseAddElement mutation,
  ) {
    final elements = mutation.background
        ? document.elements.addBackgroundElement(
            mutation.element,
            resourceIds: document.resourceTable.admittedIds,
            index: mutation.index,
          )
        : document.elements.addElement(
            mutation.element,
            resourceIds: document.resourceTable.admittedIds,
            layerId: mutation.layerId,
            index: mutation.index,
          );

    return _SparseMutationResult.changed(
      document.copyWith(elements: elements),
      requiredRevisionDelta: const StoreRevisionDelta.structural(),
    );
  }

  _SparseMutationResult _updateElement(
    CommittedDocument document,
    StoreSparseUpdateElement mutation,
  ) {
    return _updateElements(document, [mutation]);
  }

  _SparseMutationResult _updateElements(
    CommittedDocument document,
    List<StoreSparseUpdateElement> updates,
  ) {
    final batch = _prepareSparseElementUpdateBatch(document, updates);
    if (!batch.hasChanges) {
      return _SparseMutationResult.unchanged(document);
    }
    final elements = document.elements.updateElements(
      batch.elements,
      resourceIds: document.resourceTable.admittedIds,
    );
    if (elements == null) {
      return _SparseMutationResult.unchanged(document);
    }

    return _SparseMutationResult.changed(
      document.copyWith(elements: elements),
      requiredRevisionDelta: batch.requiredRevisionDelta,
    );
  }

  _SparseElementUpdateBatch _prepareSparseElementUpdateBatch(
    CommittedDocument document,
    List<StoreSparseUpdateElement> updates,
  ) {
    final changedById = <CanvasElementId, CanvasElement>{};
    var requiredRevisionDelta = const StoreRevisionDelta();
    for (final update in updates) {
      final element = update.element;
      final before =
          changedById[element.id] ?? document.elements.elementById(element.id);
      if (before == null) {
        continue;
      }
      _validateSparseElementUpdateSource(before: before, update: update);
      if (_isSparseElementUpdateNoOp(before: before, update: update)) {
        continue;
      }
      _validateSparseElementUpdate(
        before: before,
        update: update,
        resourceIds: document.resourceTable.admittedIds,
      );
      requiredRevisionDelta = requiredRevisionDelta.merge(
        update.compiledUpdate.revisionDelta,
      );
      changedById[element.id] = element;
    }

    return _SparseElementUpdateBatch(
      elements: changedById.values,
      requiredRevisionDelta: requiredRevisionDelta,
    );
  }

  _SparseMutationResult _removeElement(
    CommittedDocument document,
    CanvasElementId id,
  ) {
    if (!document.elements.containsElement(id)) {
      return _SparseMutationResult.unchanged(document);
    }

    return _SparseMutationResult.changed(
      document.copyWith(elements: document.elements.removeElement(id)),
      requiredRevisionDelta: const StoreRevisionDelta.structural(),
    );
  }

  _SparseMutationResult _upsertResource(
    CommittedDocument document,
    CanvasResource resource, {
    required RevisionState acceptedRevisions,
  }) {
    return _SparseMutationResult.changed(
      document.copyWith(
        resourceTable: document.resourceTable.upsert(
          resource,
          revision: acceptedRevisions.resourceRevision,
        ),
      ),
      requiredRevisionDelta: const StoreRevisionDelta.resource(),
    );
  }

  _SparseMutationResult _removeUnusedResource(
    CommittedDocument document,
    CanvasResourceId id, {
    required RevisionState acceptedRevisions,
  }) {
    if (!document.resourceTable.contains(id) ||
        document.elements.referencesResource(id)) {
      return _SparseMutationResult.unchanged(document);
    }

    return _SparseMutationResult.changed(
      document.copyWith(
        resourceTable: document.resourceTable.remove(
          id,
          revision: acceptedRevisions.resourceRevision,
        ),
      ),
      requiredRevisionDelta: const StoreRevisionDelta.resource(),
    );
  }

  _SparseMutationResult _clearContent(
    CommittedDocument document, {
    required bool removeUnusedResources,
    required RevisionState acceptedRevisions,
  }) {
    final didClearElements = document.elements.elementCount != 0;
    final didClearResources =
        removeUnusedResources && document.resourceTable.rows.isNotEmpty;
    if (!didClearElements && !didClearResources) {
      return _SparseMutationResult.unchanged(document);
    }
    final clearedElements = document.elements.clearContent();
    final clearedResources = removeUnusedResources
        ? document.resourceTable.clear(
            revision: acceptedRevisions.resourceRevision,
          )
        : document.resourceTable;

    var requiredRevisionDelta = const StoreRevisionDelta();
    if (didClearElements) {
      requiredRevisionDelta = requiredRevisionDelta.merge(
        const StoreRevisionDelta.structural(),
      );
    }
    if (didClearResources) {
      requiredRevisionDelta = requiredRevisionDelta.merge(
        const StoreRevisionDelta.resource(),
      );
    }

    return _SparseMutationResult.changed(
      document.copyWith(
        elements: clearedElements,
        resourceTable: clearedResources,
      ),
      requiredRevisionDelta: requiredRevisionDelta,
    );
  }

  _SparseMutationResult _setBackground(
    CommittedDocument document,
    CanvasBackground background,
  ) {
    if (document.background == background) {
      return _SparseMutationResult.unchanged(document);
    }

    var requiredRevisionDelta = const StoreRevisionDelta();
    if (document.background.color != background.color) {
      requiredRevisionDelta = requiredRevisionDelta.merge(
        const StoreRevisionDelta.background(),
      );
    }
    if (document.background.grid != background.grid) {
      requiredRevisionDelta = requiredRevisionDelta.merge(
        const StoreRevisionDelta.grid(),
      );
    }

    return _SparseMutationResult.changed(
      document.copyWith(background: background),
      requiredRevisionDelta: requiredRevisionDelta,
    );
  }

  _SparseMutationResult _setCamera(
    CommittedDocument document,
    CanvasCamera camera,
  ) {
    if (document.camera == camera) {
      return _SparseMutationResult.unchanged(document);
    }

    return _SparseMutationResult.changed(
      document.copyWith(camera: camera),
      requiredRevisionDelta: const StoreRevisionDelta.projectionOnly(),
    );
  }

  _SparseMutationResult _setPalette(
    CommittedDocument document,
    CanvasPalette palette,
  ) {
    if (_samePalette(document.palette, palette)) {
      return _SparseMutationResult.unchanged(document);
    }

    return _SparseMutationResult.changed(
      document.copyWith(palette: palette),
      requiredRevisionDelta: const StoreRevisionDelta.projectionOnly(),
    );
  }
}

Set<CanvasElementId> _normalizeSelectionInCommittedDocument(
  CommittedDocument document,
  Iterable<CanvasElementId> ids,
) {
  final selectable = document.elements.selectableElementIds;

  return {
    for (final id in ids)
      if (selectable.contains(id)) id,
  };
}

StoreRevisionDelta _validatedSparseRevisionDelta(StoreRevisionDelta delta) {
  if (!delta.hasChanges) {
    return delta;
  }
  if (_hasProjectionWithoutDocument(delta)) {
    throw ArgumentError.value(
      delta,
      'revisionDelta',
      'projection invalidation must advance the document revision.',
    );
  }
  if (_hasDocumentWithoutProjection(delta)) {
    throw ArgumentError.value(
      delta,
      'revisionDelta',
      'sparse committed fact changes must invalidate public projection.',
    );
  }
  if (_hasFactRevisionWithoutDocument(delta)) {
    throw ArgumentError.value(
      delta,
      'revisionDelta',
      'sparse committed fact changes require a document revision.',
    );
  }
  if (_hasFactRevisionWithoutProjection(delta)) {
    throw ArgumentError.value(
      delta,
      'revisionDelta',
      'sparse committed fact changes require projection invalidation.',
    );
  }

  return delta;
}

void _validateSparseRevisionCoverage({
  required StoreRevisionDelta provided,
  required StoreRevisionDelta required,
}) {
  if (!required.hasChanges) {
    return;
  }
  if (_missingRequiredRevision(provided.document, required.document) ||
      _missingRequiredRevision(provided.projection, required.projection) ||
      _missingRequiredRevision(provided.structural, required.structural) ||
      _missingRequiredRevision(provided.bounds, required.bounds) ||
      _missingRequiredRevision(
        provided.elementVisual,
        required.elementVisual,
      ) ||
      _missingRequiredRevision(provided.background, required.background) ||
      _missingRequiredRevision(provided.grid, required.grid) ||
      _missingRequiredRevision(provided.resource, required.resource)) {
    throw ArgumentError.value(
      provided,
      'revisionDelta',
      'sparse revision delta does not cover changed committed facts.',
    );
  }
}

bool _missingRequiredRevision(bool provided, bool required) {
  return required && !provided;
}

bool _hasProjectionWithoutDocument(StoreRevisionDelta delta) {
  return delta.projection && !delta.document;
}

bool _hasDocumentWithoutProjection(StoreRevisionDelta delta) {
  return delta.document && !delta.projection;
}

bool _hasFactRevisionWithoutDocument(StoreRevisionDelta delta) {
  return _changesCommittedFacts(delta) && !delta.document;
}

bool _hasFactRevisionWithoutProjection(StoreRevisionDelta delta) {
  return _changesCommittedFacts(delta) && !delta.projection;
}

bool _changesCommittedFacts(StoreRevisionDelta delta) {
  return [
    delta.structural,
    delta.bounds,
    delta.elementVisual,
    delta.background,
    delta.grid,
    delta.resource,
  ].contains(true);
}

void _validateSparseElementRevision({
  required CanvasElement before,
  required CanvasElement after,
}) {
  final expectedRevision = before.revision + 1;
  if (after.revision != expectedRevision) {
    throw ArgumentError.value(
      after.revision,
      'element.revision',
      'sparse element updates must carry the next committed element revision.',
    );
  }
}

bool _isSparseElementUpdateNoOp({
  required CanvasElement before,
  required StoreSparseUpdateElement update,
}) {
  return !update.compiledUpdate.revisionDelta.hasChanges &&
      update.element.revision == before.revision;
}

void _validateSparseElementUpdateSource({
  required CanvasElement before,
  required StoreSparseUpdateElement update,
}) {
  if (!sameCanvasElementSnapshot(update.before, before)) {
    throw ArgumentError.value(
      update.before,
      'before',
      'sparse element update taxonomy must be compiled from the committed row.',
    );
  }
}

void _validateSparseElementUpdate({
  required CanvasElement before,
  required StoreSparseUpdateElement update,
  required Set<String> resourceIds,
}) {
  final after = update.element;
  if (before.kind != after.kind) {
    throw ArgumentError.value(
      after,
      'element',
      'element update kind does not match the target element.',
    );
  }
  _validateSparseUpdateResourceReferences(after, resourceIds);
  if (!update.compiledUpdate.revisionDelta.hasChanges) {
    throw ArgumentError.value(
      update.compiledUpdate.revisionDelta,
      'compiledUpdate.revisionDelta',
      'changed sparse element updates must carry a compiler-produced revision delta.',
    );
  }
  _validateSparseElementRevision(before: before, after: after);
}

void _validateSparseUpdateResourceReferences(
  CanvasElement element,
  Set<String> resourceIds,
) {
  if (element case CanvasImageElement(:final resourceId)) {
    if (!resourceIds.contains(resourceId.value)) {
      throw CanvasDataException(
        code: CanvasDataErrorCode.missingResourceReference,
        message: 'image element references a missing resource.',
        path: 'image.resourceId',
      );
    }
  }
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

// Sparse admission names every mutation family that can create ids; splitting
// the switch would hide the admission contract behind indirect helpers.
// ignore: coupling-between-object-classes
final class _SparseAdmittedIds {
  final Set<String> _elementIds = {};
  final Set<String> _layerIds = {};
  final Set<String> _resourceIds = {};

  List<String> get elementIds => List.unmodifiable(_elementIds);
  List<String> get layerIds => List.unmodifiable(_layerIds);
  List<String> get resourceIds => List.unmodifiable(_resourceIds);

  // Keeping all id-producing sparse mutations together makes missed admission
  // cases visible next to the sealed mutation taxonomy.
  // ignore: cyclomatic-complexity
  void addMutation(StoreSparseMutation mutation) {
    switch (mutation) {
      case StoreSparseEnsureLayer(:final id):
        _layerIds.add(id.value);
      case StoreSparseAddElement(:final element, :final layerId):
        _elementIds.add(element.id.value);
        if (layerId != null) {
          _layerIds.add(layerId.value);
        }
      case StoreSparseUpsertResource(:final resource):
        _resourceIds.add(resource.id.value);
      case StoreSparseUpdateElement() ||
          StoreSparseRemoveElement() ||
          StoreSparseRemoveUnusedResource() ||
          StoreSparseClearContent() ||
          StoreSparseSetBackground() ||
          StoreSparseSetCamera() ||
          StoreSparseSetPalette():
        break;
    }
  }
}

final class _SparseElementUpdateBatch {
  _SparseElementUpdateBatch({
    required Iterable<CanvasElement> elements,
    required this.requiredRevisionDelta,
  }) : elements = List.unmodifiable(elements);

  final List<CanvasElement> elements;
  final StoreRevisionDelta requiredRevisionDelta;

  bool get hasChanges => elements.isNotEmpty;
}

final class _SparseMutationResult {
  const _SparseMutationResult({
    required this.document,
    required this.didMutateFacts,
    required this.requiredRevisionDelta,
  });

  factory _SparseMutationResult.changed(
    CommittedDocument document, {
    required StoreRevisionDelta requiredRevisionDelta,
  }) {
    return _SparseMutationResult(
      document: document,
      didMutateFacts: true,
      requiredRevisionDelta: requiredRevisionDelta,
    );
  }

  factory _SparseMutationResult.unchanged(CommittedDocument document) {
    return _SparseMutationResult(
      document: document,
      didMutateFacts: false,
      requiredRevisionDelta: const StoreRevisionDelta(),
    );
  }

  final CommittedDocument document;
  final bool didMutateFacts;
  final StoreRevisionDelta requiredRevisionDelta;
}

final class StoreElementHandle {
  const StoreElementHandle({
    required this.id,
    required this.structuralRevision,
    required this.generation,
    required this.orderToken,
  });

  final CanvasElementId id;
  final int structuralRevision;
  final int generation;
  final int orderToken;
}

final class StoreElementFacts {
  StoreElementFacts({
    required this.id,
    required this.kind,
    required this.revision,
    required this.generation,
    required this.orderToken,
    required this.locationKind,
    required this.transform,
    required this.opacity,
    required this.hitPadding,
    required this.isVisible,
    required this.isSelectable,
    required this.isLocked,
    required this.isDeletable,
    required this.isTransformable,
    required this.metadata,
    this.resourceId,
    this.layerId,
    this.size,
    this.naturalSize,
    this.svgPathData,
    this.fillColor,
    this.strokeColor,
    this.strokeWidth,
    this.fillRule,
    this.text,
    this.fontSize,
    this.textColor,
    this.textAlign,
    this.textDirection,
    this.isBold,
    this.isItalic,
    this.isUnderline,
    this.fontFamily,
    this.maxWidth,
    this.lineHeight,
    Iterable<Offset> points = const [],
    this.start,
    this.end,
    this.color,
    this.thickness,
  }) : points = List.unmodifiable(points);

  // This mapper intentionally lists every immutable row field crossing from the
  // family tables into the store fact; splitting it would make the read-port
  // contract harder to audit.
  // ignore: halstead-volume, source-lines-of-code
  factory StoreElementFacts.fromFamilyFacts(
    FamilyElementFacts facts, {
    required int orderToken,
    required ElementLocationFacts location,
  }) {
    return StoreElementFacts(
      id: facts.id,
      kind: facts.kind,
      revision: facts.revision,
      generation: facts.generation,
      orderToken: orderToken,
      locationKind: switch (location.kind) {
        ElementLocationKind.background => StoreElementLocationKind.background,
        ElementLocationKind.content => StoreElementLocationKind.content,
      },
      transform: facts.transform,
      opacity: facts.opacity,
      hitPadding: facts.hitPadding,
      isVisible: facts.isVisible,
      isSelectable: facts.isSelectable,
      isLocked: facts.isLocked,
      isDeletable: facts.isDeletable,
      isTransformable: facts.isTransformable,
      metadata: facts.metadata,
      resourceId: facts.resourceId,
      layerId: location.layerId,
      size: facts.size,
      naturalSize: facts.naturalSize,
      svgPathData: facts.svgPathData,
      fillColor: facts.fillColor,
      strokeColor: facts.strokeColor,
      strokeWidth: facts.strokeWidth,
      fillRule: facts.fillRule,
      text: facts.text,
      fontSize: facts.fontSize,
      textColor: facts.textColor,
      textAlign: facts.textAlign,
      textDirection: facts.textDirection,
      isBold: facts.isBold,
      isItalic: facts.isItalic,
      isUnderline: facts.isUnderline,
      fontFamily: facts.fontFamily,
      maxWidth: facts.maxWidth,
      lineHeight: facts.lineHeight,
      points: facts.points,
      start: facts.start,
      end: facts.end,
      color: facts.color,
      thickness: facts.thickness,
    );
  }

  final CanvasElementId id;
  final CanvasElementKind kind;
  final int revision;
  final int generation;
  final int orderToken;
  final StoreElementLocationKind locationKind;
  final CanvasTransform transform;
  final double opacity;
  final double hitPadding;
  final bool isVisible;
  final bool isSelectable;
  final bool isLocked;
  final bool isDeletable;
  final bool isTransformable;
  final CanvasMetadata metadata;
  final CanvasResourceId? resourceId;
  final CanvasLayerId? layerId;
  final Size? size;
  final Size? naturalSize;
  final String? svgPathData;
  final Color? fillColor;
  final Color? strokeColor;
  final double? strokeWidth;
  final CanvasPathFillRule? fillRule;
  final String? text;
  final double? fontSize;
  final Color? textColor;
  final TextAlign? textAlign;
  final TextDirection? textDirection;
  final bool? isBold;
  final bool? isItalic;
  final bool? isUnderline;
  final String? fontFamily;
  final double? maxWidth;
  final double? lineHeight;
  final List<Offset> points;
  final Offset? start;
  final Offset? end;
  final Color? color;
  final double? thickness;
}

enum StoreElementLocationKind { background, content }

final class _IdAdmission {
  _IdAdmission({required this.prefix, required Iterable<String> admittedIds})
    : _reserved = Set.of(admittedIds);

  final String prefix;
  final Set<String> _reserved;
  int _next = 0;

  String nextValue() {
    while (true) {
      final candidate = '$prefix$_next';
      _next += 1;
      if (!_reserved.add(candidate)) {
        continue;
      }

      return candidate;
    }
  }

  void admitAll(Iterable<String> ids) {
    _reserved.addAll(ids);
  }
}
