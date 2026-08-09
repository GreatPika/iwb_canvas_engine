import 'dart:ui';

import 'package:flutter/foundation.dart';

// DocumentStoreKernel directly names the DTO, fact, projection, and revision
// owners it coordinates; hiding one import behind a wrapper would obscure the
// committed-store boundary instead of simplifying it.
// ignore_for_file: number-of-imports

import '../contracts/public/canvas_element.dart';
import '../contracts/public/canvas_errors.dart';
import '../contracts/public/canvas_geometry.dart';
import '../contracts/public/canvas_document.dart';
import '../contracts/public/canvas_ids.dart';
import '../contracts/public/canvas_metadata.dart';
import '../contracts/public/canvas_resource.dart';
import 'canvas_element_snapshot.dart';
import 'committed_document.dart';
import 'document_projection_cache.dart';
import 'element_registry.dart';
import 'family_tables.dart';
import 'layer_table.dart';
import 'resource_table.dart';
import 'revision_state.dart';
import 'schema_v1_store_import.dart';
import 'sparse_store_commit.dart';
import 'store_commit_finalization.dart';
import 'store_revision_delta.dart';

// DocumentStoreKernel is the single owner for committed document facts, read
// projection, id admission, and selection normalization inputs; splitting these
// accessors would obscure the shared committed-state source of truth.
// ignore: coupling-between-object-classes, number-of-methods, response-for-class, weighted-methods-per-class
final class DocumentStoreKernel {
  DocumentStoreKernel() : _document = CommittedDocument.empty() {
    _validateFinalCandidateResourceRelationships(_document);
    _resetIdAdmission();
  }

  @visibleForTesting
  DocumentStoreKernel.withCommittedDocumentForTesting(this._document) {
    _validateFinalCandidateResourceRelationships(_document);
    _resetIdAdmission();
  }

  void _resetIdAdmission() {
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
  int get resourceCount => _document.resourceTable.count;
  List<CanvasResource> get resources {
    return _document.resourceTable.projectResources();
  }

  CanvasResource? resourceById(CanvasResourceId id) {
    return _document.resourceTable.projectResource(id);
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
    return _document.resourceTable.descriptors.keys;
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

  Set<CanvasElementId> normalizeSelectionForCommittedDocument(
    CommittedDocument document,
    Iterable<CanvasElementId> ids,
  ) {
    return _normalizeSelectionInCommittedDocument(document, ids);
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

  void installDocument(CommittedDocument document, StoreRevisionDelta delta) {
    _validateFinalCandidateResourceRelationships(document);
    if (!delta.hasChanges) {
      return;
    }
    _document = _acceptFullDocument(document, delta);
    _elementIds.admitAll(_document.admittedElementIds);
    _layerIds.admitAll(_document.admittedLayerIds);
    _resourceIds.admitAll(_document.admittedResourceIds);
  }

  void replaceDocument(CommittedDocument document, StoreRevisionDelta delta) {
    _validateFinalCandidateResourceRelationships(document);
    if (!delta.hasChanges) {
      return;
    }
    _document = _acceptFullDocument(document, delta);
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

  void replacePreparedLoadDocument(
    CommittedDocument document,
    StoreRevisionDelta delta,
  ) {
    _validateFinalCandidateResourceRelationships(document);
    if (!delta.hasChanges) {
      return;
    }
    _document = _acceptFullDocument(document, delta);
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

  PreparedStoreDocumentImport prepareSchemaV1Import(
    StoreSchemaV1ImportBuilder builder,
    StoreRevisionDelta delta,
  ) {
    final prepared = builder.prepare(
      baseRevisions: _document.revisions,
      revisionDelta: delta,
    );
    _validateFinalCandidateResourceRelationships(prepared.document);

    return prepared;
  }

  PreparedMaterializedStoreCommit prepareMaterializedCommit(
    CanvasDocument document,
    StoreRevisionDelta revisionDelta,
  ) {
    final candidate = CommittedDocument(document);
    _validateFinalCandidateResourceRelationships(candidate);
    final providedDelta = _validatedSparseRevisionDelta(revisionDelta);
    final acceptedDelta = _committedDocumentRevisionDelta(_document, candidate);
    if (!acceptedDelta.hasChanges) {
      return PreparedMaterializedStoreCommit(
        baseDocument: _document,
        document: _document,
        revisionDelta: const StoreRevisionDelta(),
        touchedFacts: AcceptedStoreTouchedFacts.empty(),
      );
    }
    if (!providedDelta.hasChanges) {
      throw ArgumentError.value(
        revisionDelta,
        'revisionDelta',
        'materialized store commits that change facts must advance revisions.',
      );
    }
    _validateSparseRevisionCoverage(
      provided: providedDelta,
      required: acceptedDelta,
    );

    return PreparedMaterializedStoreCommit(
      baseDocument: _document,
      document: _acceptFullDocument(candidate, acceptedDelta),
      revisionDelta: acceptedDelta,
      touchedFacts: _committedDocumentTouchedFacts(_document, candidate),
    );
  }

  void installPreparedSchemaV1Import(PreparedStoreDocumentImport prepared) {
    prepared.consume(_document.revisions);
    if (!prepared.hasChanges) {
      return;
    }
    _document = prepared.document;
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
  // Keeping validation, mutation application, final equality, and accepted
  // payload construction together is safer than splitting the transaction
  // boundary into metric-shaped phases.
  // ignore: cyclomatic-complexity, halstead-volume, source-lines-of-code, maintainability-index
  PreparedSparseStoreCommit prepareSparseCommit(StoreSparseCommit commit) {
    final revisionDelta = commit.revisionDelta;
    final acceptedRevisions = revisionDelta.advance(_document.revisions);
    var nextDocument = _document;
    var didMutateFacts = false;
    final admittedIds = _SparseAdmittedIds();
    final deferredElementUpdateValidation =
        <_DeferredSparseElementUpdateValidation>[];
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
        final applied = _updateElements(
          nextDocument,
          updates,
          deferredValidation: deferredElementUpdateValidation,
        );
        nextDocument = applied.document;
        didMutateFacts = didMutateFacts || applied.didMutateFacts;
        continue;
      }
      final applied = _applySparseMutation(
        nextDocument,
        mutation,
        acceptedRevisions: acceptedRevisions,
      );
      nextDocument = applied.document;
      didMutateFacts = didMutateFacts || applied.didMutateFacts;
      if (applied.didMutateFacts) {
        admittedIds.addMutation(mutation);
      }
      index += 1;
    }
    _validateFinalCandidateResourceRelationships(nextDocument);
    final validatedRevisionDelta = _validatedSparseRevisionDelta(revisionDelta);
    for (final validation in deferredElementUpdateValidation) {
      validation.validate();
    }
    final touched = _SparseTouchedCommittedFacts.fromMutations(
      commit.mutations,
    );
    final acceptedDelta = didMutateFacts
        ? _sparseAcceptedRevisionDelta(
            base: _document,
            candidate: nextDocument,
            touched: touched,
          )
        : const StoreRevisionDelta();
    final accepted = didMutateFacts && acceptedDelta.hasChanges;
    if (accepted && !validatedRevisionDelta.hasChanges) {
      throw ArgumentError.value(
        commit.revisionDelta,
        'revisionDelta',
        'sparse store commits that change facts must advance revisions.',
      );
    }
    if (accepted) {
      _validateSparseRevisionCoverage(
        provided: validatedRevisionDelta,
        required: acceptedDelta,
      );
    }

    return PreparedSparseStoreCommit(
      baseRevisions: _document.revisions,
      document: accepted
          ? _acceptSparseDocument(nextDocument, acceptedDelta, touched)
          : _document,
      revisionDelta: accepted ? acceptedDelta : const StoreRevisionDelta(),
      touchedFacts: accepted
          ? _sparseAcceptedTouchedFacts(
              base: _document,
              candidate: nextDocument,
              mutations: commit.mutations,
            )
          : AcceptedStoreTouchedFacts.empty(),
      admittedElementIds: accepted ? admittedIds.elementIds : const [],
      admittedLayerIds: accepted ? admittedIds.layerIds : const [],
      admittedResourceIds: accepted ? admittedIds.resourceIds : const [],
    );
  }

  CommittedDocument _acceptFullDocument(
    CommittedDocument document,
    StoreRevisionDelta delta,
  ) {
    final acceptedRevisions = delta.advance(_document.revisions);

    return document.copyWith(
      revisions: acceptedRevisions,
      resourceTable: document.resourceTable.withAcceptedResourceRevisions(
        _document.resourceTable,
        acceptedRevision: acceptedRevisions.resourceRevision,
      ),
    );
  }

  CommittedDocument _acceptSparseDocument(
    CommittedDocument document,
    StoreRevisionDelta delta,
    _SparseTouchedCommittedFacts touched,
  ) {
    final acceptedRevisions = delta.advance(_document.revisions);

    return document.copyWith(
      revisions: acceptedRevisions,
      elements: _acceptSparseElementRows(
        base: _document,
        candidate: document,
        touched: touched,
      ),
      resourceTable: document.resourceTable.withAcceptedResourceRevisions(
        _document.resourceTable,
        acceptedRevision: acceptedRevisions.resourceRevision,
      ),
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
      ),
      StoreSparseClearContent(:final removeUnusedResources) => _clearContent(
        document,
        removeUnusedResources: removeUnusedResources,
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
            index: mutation.index,
          )
        : document.elements.addElement(
            mutation.element,
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
    final deferredValidation = <_DeferredSparseElementUpdateValidation>[];
    final result = _updateElements(document, [
      mutation,
    ], deferredValidation: deferredValidation);
    for (final validation in deferredValidation) {
      validation.validate();
    }

    return result;
  }

  _SparseMutationResult _updateElements(
    CommittedDocument document,
    List<StoreSparseUpdateElement> updates, {
    required List<_DeferredSparseElementUpdateValidation> deferredValidation,
  }) {
    final batch = _prepareSparseElementUpdateBatch(document, updates);
    deferredValidation.addAll(batch.deferredValidation);
    if (!batch.hasChanges) {
      return _SparseMutationResult.unchanged(document);
    }
    final elements = document.elements.updateElements(batch.elements);
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
    final deferredValidation = <_DeferredSparseElementUpdateValidation>[];
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
      _validateSparseElementUpdateKind(before: before, update: update);
      deferredValidation.add(
        _DeferredSparseElementUpdateValidation(before: before, update: update),
      );
      requiredRevisionDelta = requiredRevisionDelta.merge(
        update.elementRevisionDelta,
      );
      changedById[element.id] = element;
    }

    return _SparseElementUpdateBatch(
      elements: changedById.values,
      requiredRevisionDelta: requiredRevisionDelta,
      deferredValidation: deferredValidation,
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
    CanvasResourceId id,
  ) {
    if (!document.resourceTable.contains(id) ||
        document.elements.referencesResource(id)) {
      return _SparseMutationResult.unchanged(document);
    }

    return _SparseMutationResult.changed(
      document.copyWith(resourceTable: document.resourceTable.remove(id)),
      requiredRevisionDelta: const StoreRevisionDelta.resource(),
    );
  }

  _SparseMutationResult _clearContent(
    CommittedDocument document, {
    required bool removeUnusedResources,
  }) {
    final didClearElements = document.elements.elementCount != 0;
    final didClearResources =
        removeUnusedResources && document.resourceTable.count != 0;
    if (!didClearElements && !didClearResources) {
      return _SparseMutationResult.unchanged(document);
    }
    final clearedElements = document.elements.clearContent();
    final clearedResources = removeUnusedResources
        ? document.resourceTable.clear()
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

StoreRevisionDelta _committedDocumentRevisionDelta(
  CommittedDocument base,
  CommittedDocument candidate,
) {
  var delta = const StoreRevisionDelta();
  if (base.camera != candidate.camera ||
      !_samePalette(base.palette, candidate.palette) ||
      base.metadata != candidate.metadata) {
    delta = delta.merge(const StoreRevisionDelta.projectionOnly());
  }
  if (base.background.color != candidate.background.color) {
    delta = delta.merge(const StoreRevisionDelta.background());
  }
  if (base.background.grid != candidate.background.grid) {
    delta = delta.merge(const StoreRevisionDelta.grid());
  }
  if (!_sameResourceTables(base.resourceTable, candidate.resourceTable)) {
    delta = delta.merge(const StoreRevisionDelta.resource());
  }

  return delta.merge(
    _elementRegistryRevisionDelta(base.elements, candidate.elements),
  );
}

StoreRevisionDelta _sparseAcceptedRevisionDelta({
  required CommittedDocument base,
  required CommittedDocument candidate,
  required _SparseTouchedCommittedFacts touched,
}) {
  var delta = const StoreRevisionDelta();
  if (touched.camera && base.camera != candidate.camera) {
    delta = delta.merge(const StoreRevisionDelta.projectionOnly());
  }
  if (touched.palette && !_samePalette(base.palette, candidate.palette)) {
    delta = delta.merge(const StoreRevisionDelta.projectionOnly());
  }
  if (touched.background) {
    if (base.background.color != candidate.background.color) {
      delta = delta.merge(const StoreRevisionDelta.background());
    }
    if (base.background.grid != candidate.background.grid) {
      delta = delta.merge(const StoreRevisionDelta.grid());
    }
  }
  if (!_sameTouchedResources(base, candidate, touched)) {
    delta = delta.merge(const StoreRevisionDelta.resource());
  }

  return delta.merge(
    _sparseTouchedElementRevisionDelta(
      base.elements,
      candidate.elements,
      touched,
    ),
  );
}

StoreRevisionDelta _sparseTouchedElementRevisionDelta(
  ElementRegistry base,
  ElementRegistry candidate,
  _SparseTouchedCommittedFacts touched,
) {
  var delta = _sparseTouchedElementStructureRevisionDelta(
    base,
    candidate,
    touched,
  );
  for (final id in touched.elementIds) {
    final before = base.elementById(id);
    final after = candidate.elementById(id);
    if (before == null || after == null) {
      if (before != after) {
        delta = delta.merge(const StoreRevisionDelta.structural());
      }
      continue;
    }
    delta = delta.merge(
      _committedElementRevisionDelta(before: before, after: after),
    );
  }

  return delta;
}

StoreRevisionDelta _sparseTouchedElementStructureRevisionDelta(
  ElementRegistry base,
  ElementRegistry candidate,
  _SparseTouchedCommittedFacts touched,
) {
  if (!touched.touchedElementStructure) {
    return const StoreRevisionDelta();
  }
  var delta = const StoreRevisionDelta();
  if (base.elementCount != candidate.elementCount ||
      !_sameTouchedBackgroundOrderForRegistries(base, candidate, touched) ||
      !_sameList(base.contentElementOrder, candidate.contentElementOrder)) {
    delta = delta.merge(const StoreRevisionDelta.structural());
  }
  if (base.layerTable.rows.length != candidate.layerTable.rows.length) {
    delta = delta.merge(const StoreRevisionDelta.layerStructural());
  }
  delta = delta.merge(
    _sparseTouchedLayerRevisionDelta(base, candidate, touched),
  );

  return delta;
}

StoreRevisionDelta _sparseTouchedLayerRevisionDelta(
  ElementRegistry base,
  ElementRegistry candidate,
  _SparseTouchedCommittedFacts touched,
) {
  var delta = const StoreRevisionDelta();
  for (final id in touched.layerIds) {
    final before = _layerRowById(base, id);
    final after = _layerRowById(candidate, id);
    if (before == null || after == null) {
      if (before != after) {
        delta = delta.merge(const StoreRevisionDelta.layerStructural());
      }
      continue;
    }
    if (before.id != after.id || before.metadata != after.metadata) {
      delta = delta.merge(const StoreRevisionDelta.layerStructural());
    }
    if (!_sameList(before.elementIds, after.elementIds)) {
      delta = delta.merge(const StoreRevisionDelta.structural());
    }
  }

  return delta;
}

bool _sameTouchedBackgroundOrderForRegistries(
  ElementRegistry base,
  ElementRegistry candidate,
  _SparseTouchedCommittedFacts touched,
) {
  return !touched.backgroundElementOrder ||
      _sameList(base.backgroundElementIds, candidate.backgroundElementIds);
}

ElementRegistry _acceptSparseElementRows({
  required CommittedDocument base,
  required CommittedDocument candidate,
  required _SparseTouchedCommittedFacts touched,
}) {
  final replacements = <CanvasElement>[];
  for (final id in _sparseElementIdsForRevisionNormalization(
    base.elements,
    candidate.elements,
    touched,
  )) {
    final before = base.elements.elementById(id);
    final after = candidate.elements.elementById(id);
    if (before == null || after == null) {
      continue;
    }
    if (!_committedElementRevisionDelta(
      before: before,
      after: after,
    ).hasChanges) {
      replacements.add(before);
    }
  }
  if (replacements.isEmpty) {
    return candidate.elements;
  }

  return candidate.elements.updateElements(replacements) ?? candidate.elements;
}

Iterable<CanvasElementId> _sparseElementIdsForRevisionNormalization(
  ElementRegistry base,
  ElementRegistry candidate,
  _SparseTouchedCommittedFacts touched,
) {
  if (!touched.allElements) {
    return touched.elementIds;
  }

  return {...base.frameElementOrder, ...candidate.frameElementOrder};
}

AcceptedStoreTouchedFacts _committedDocumentTouchedFacts(
  CommittedDocument base,
  CommittedDocument candidate,
) {
  final resourceTouches = _resourceTouchedFacts(base, candidate);
  final elementTouches = _elementTouchedFacts(
    base.elements,
    candidate.elements,
  );

  return _acceptedStoreTouchedFacts(
    elementTouches: elementTouches,
    resourceTouches: resourceTouches,
    layerIds: _changedLayerIds(base.elements, candidate.elements),
    aggregateTouches: _AggregateTouchedFacts(
      backgroundLayerChanged: !_sameList(
        base.elements.backgroundElementIds,
        candidate.elements.backgroundElementIds,
      ),
      persistedCamera: base.camera != candidate.camera,
      background: base.background.color != candidate.background.color,
      grid: base.background.grid != candidate.background.grid,
      palette: !_samePalette(base.palette, candidate.palette),
    ),
  );
}

bool _sameTouchedResources(
  CommittedDocument base,
  CommittedDocument candidate,
  _SparseTouchedCommittedFacts touched,
) {
  if (touched.resourceIds.isEmpty && !touched.allResources) {
    return true;
  }
  if (base.resourceTable.count != candidate.resourceTable.count) {
    return false;
  }
  if (touched.allResources) {
    return _sameResourceTables(base.resourceTable, candidate.resourceTable);
  }
  for (final id in touched.resourceIds) {
    final before = base.resourceDescriptor(id);
    final after = candidate.resourceDescriptor(id);
    if (before == null || after == null) {
      if (before != after) {
        return false;
      }
      continue;
    }
    if (!after.hasSameResourceFacts(before)) {
      return false;
    }
  }

  return true;
}

_ResourceTouchedFacts _resourceTouchedFacts(
  CommittedDocument base,
  CommittedDocument candidate, {
  Iterable<CanvasResourceId>? limitedToIds,
}) {
  final ids =
      limitedToIds ??
      {
        ...base.resourceTable.descriptors.keys,
        ...candidate.resourceTable.descriptors.keys,
      };
  final descriptorChangedIds = <CanvasResourceId>{};
  final visualChangedIds = <CanvasResourceId>{};
  for (final id in ids) {
    final before = base.resourceDescriptor(id);
    final after = candidate.resourceDescriptor(id);
    final changed =
        before == null || after == null || !after.hasSameResourceFacts(before);
    if (!changed) {
      continue;
    }
    descriptorChangedIds.add(id);
    if (base.elements.referencesResource(id) ||
        candidate.elements.referencesResource(id)) {
      visualChangedIds.add(id);
    }
  }

  return _ResourceTouchedFacts(
    descriptorChangedIds: descriptorChangedIds,
    visualChangedIds: visualChangedIds,
  );
}

bool _sameResourceTables(ResourceTable base, ResourceTable candidate) {
  if (base.count != candidate.count) {
    return false;
  }
  for (final id in base.descriptors.keys) {
    final before = base.descriptors[id];
    final after = candidate.descriptors[id];
    if (before == null ||
        after == null ||
        !after.hasSameResourceFacts(before)) {
      return false;
    }
  }

  return true;
}

StoreRevisionDelta _elementRegistryRevisionDelta(
  ElementRegistry base,
  ElementRegistry candidate,
) {
  var delta = const StoreRevisionDelta();
  if (!_sameList(base.backgroundElementIds, candidate.backgroundElementIds) ||
      !_sameList(base.frameElementOrder, candidate.frameElementOrder)) {
    delta = delta.merge(const StoreRevisionDelta.structural());
  }
  delta = delta.merge(
    _layerRowsRevisionDelta(base.layerTable.rows, candidate.layerTable.rows),
  );
  if (delta.structural) {
    return delta;
  }

  for (final id in base.frameElementOrder) {
    final before = base.elementById(id);
    final after = candidate.elementById(id);
    if (before == null || after == null) {
      return delta.merge(const StoreRevisionDelta.structural());
    }
    delta = delta.merge(
      _committedElementRevisionDelta(before: before, after: after),
    );
  }

  return delta;
}

StoreRevisionDelta _layerRowsRevisionDelta(
  List<LayerRow> base,
  List<LayerRow> candidate,
) {
  if (base.length != candidate.length) {
    return const StoreRevisionDelta.layerStructural();
  }

  var delta = const StoreRevisionDelta();
  for (var index = 0; index < base.length; index += 1) {
    final before = base[index];
    final after = candidate[index];
    if (before.id != after.id || before.metadata != after.metadata) {
      delta = delta.merge(const StoreRevisionDelta.layerStructural());
    }
    if (!_sameList(before.elementIds, after.elementIds)) {
      delta = delta.merge(const StoreRevisionDelta.structural());
    }
  }

  return delta;
}

_ElementTouchedFacts _elementTouchedFacts(
  ElementRegistry base,
  ElementRegistry candidate, {
  Iterable<CanvasElementId>? limitedToIds,
}) {
  final ids =
      limitedToIds ??
      {...base.frameElementOrder, ...candidate.frameElementOrder};
  final facts = _ElementTouchedFacts();
  for (final id in ids) {
    _recordElementTouch(
      facts,
      id: id,
      before: base.elementById(id),
      after: candidate.elementById(id),
    );
  }

  return facts;
}

void _recordElementTouch(
  _ElementTouchedFacts facts, {
  required CanvasElementId id,
  required CanvasElement? before,
  required CanvasElement? after,
}) {
  if (before == null && after == null) {
    return;
  }
  if (before == null) {
    facts.addedElementIds.add(id);

    return;
  }
  if (after == null) {
    facts.removedElementIds.add(id);
    facts.selectionPruneElementIds.add(id);

    return;
  }
  final delta = _committedElementRevisionDelta(before: before, after: after);
  if (!delta.hasChanges) {
    return;
  }
  facts.updatedElementIds.add(id);
  if (before.transform != after.transform) {
    facts.transformedElementIds.add(id);
  }
  if (_committedElementTouchesSpatial(before, after, delta)) {
    facts.geometryElementIds.add(id);
  }
  if (delta.elementVisual) {
    facts.visualElementIds.add(id);
  }
  if (_requiresSelectionPrune(before, after)) {
    facts.selectionPruneElementIds.add(id);
  }
}

bool _requiresSelectionPrune(CanvasElement before, CanvasElement after) {
  return (before.isVisible && !after.isVisible) ||
      (before.isSelectable && !after.isSelectable);
}

Set<CanvasLayerId> _changedLayerIds(
  ElementRegistry base,
  ElementRegistry candidate, {
  Iterable<CanvasLayerId>? limitedToIds,
}) {
  final ids =
      limitedToIds ??
      {
        for (final row in base.layerTable.rows) row.id,
        for (final row in candidate.layerTable.rows) row.id,
      };

  return {
    for (final id in ids)
      if (!_sameLayerFacts(
        _layerRowById(base, id),
        _layerRowById(candidate, id),
      ))
        id,
  };
}

LayerRow? _layerRowById(ElementRegistry registry, CanvasLayerId id) {
  for (final row in registry.layerTable.rows) {
    if (row.id == id) {
      return row;
    }
  }

  return null;
}

bool _sameLayerFacts(LayerRow? before, LayerRow? after) {
  if (before == null || after == null) {
    return before == after;
  }

  return before.id == after.id &&
      before.metadata == after.metadata &&
      _sameList(before.elementIds, after.elementIds);
}

StoreRevisionDelta _committedElementRevisionDelta({
  required CanvasElement before,
  required CanvasElement after,
}) {
  if (before.kind != after.kind) {
    return const StoreRevisionDelta.structural();
  }

  return _committedCommonElementDelta(
    before: before,
    after: after,
  ).merge(_committedElementFamilyDelta(before, after));
}

StoreRevisionDelta _committedCommonElementDelta({
  required CanvasElement before,
  required CanvasElement after,
}) {
  var delta = const StoreRevisionDelta();
  if (before.transform != after.transform ||
      before.isVisible != after.isVisible) {
    delta = delta.merge(const StoreRevisionDelta.elementBounds());
  }
  if (before.opacity != after.opacity) {
    delta = delta.merge(const StoreRevisionDelta.elementVisual());
  }
  if (before.hitPadding != after.hitPadding) {
    delta = delta.merge(const StoreRevisionDelta.elementBoundsOnly());
  }
  if (before.isSelectable != after.isSelectable ||
      before.isLocked != after.isLocked ||
      before.isDeletable != after.isDeletable ||
      before.isTransformable != after.isTransformable ||
      before.metadata != after.metadata) {
    delta = delta.merge(const StoreRevisionDelta.projectionOnly());
  }

  return delta;
}

StoreRevisionDelta _committedElementFamilyDelta(
  CanvasElement before,
  CanvasElement after,
) {
  return switch ((before, after)) {
    (final CanvasImageElement before, final CanvasImageElement after) =>
      _committedImageDelta(before, after),
    (final CanvasVectorElement before, final CanvasVectorElement after) =>
      _committedVectorDelta(before, after),
    (final CanvasPathElement before, final CanvasPathElement after) =>
      _committedPathDelta(before, after),
    (final CanvasTextElement before, final CanvasTextElement after) =>
      _committedTextDelta(before, after),
    (final CanvasStrokeElement before, final CanvasStrokeElement after) =>
      _committedStrokeDelta(before, after),
    (final CanvasLineElement before, final CanvasLineElement after) =>
      _committedLineDelta(before, after),
    (final CanvasRectElement before, final CanvasRectElement after) =>
      _committedRectDelta(before, after),
    _ => const StoreRevisionDelta(),
  };
}

StoreRevisionDelta _committedImageDelta(
  CanvasImageElement before,
  CanvasImageElement after,
) {
  var delta = const StoreRevisionDelta();
  if (before.size != after.size) {
    delta = delta.merge(const StoreRevisionDelta.elementBounds());
  }
  if (before.resourceId != after.resourceId ||
      before.naturalSize != after.naturalSize) {
    delta = delta.merge(const StoreRevisionDelta.elementVisual());
  }

  return delta;
}

StoreRevisionDelta _committedVectorDelta(
  CanvasVectorElement before,
  CanvasVectorElement after,
) {
  var delta = const StoreRevisionDelta();
  if (before.size != after.size) {
    delta = delta.merge(const StoreRevisionDelta.elementBounds());
  }
  if (before.resourceId != after.resourceId ||
      before.naturalSize != after.naturalSize) {
    delta = delta.merge(const StoreRevisionDelta.elementVisual());
  }

  return delta;
}

StoreRevisionDelta _committedPathDelta(
  CanvasPathElement before,
  CanvasPathElement after,
) {
  var delta = const StoreRevisionDelta();
  if (before.svgPathData != after.svgPathData ||
      before.strokeWidth != after.strokeWidth) {
    delta = delta.merge(const StoreRevisionDelta.elementBounds());
  }
  if (before.fillColor != after.fillColor ||
      before.fillRule != after.fillRule) {
    delta = delta.merge(const StoreRevisionDelta.elementVisual());
  }
  if (before.strokeColor != after.strokeColor) {
    delta = delta.merge(
      _strokePaintedBoundsChanged(
            before.strokeColor,
            before.strokeWidth,
            after.strokeColor,
            after.strokeWidth,
          )
          ? const StoreRevisionDelta.elementBounds()
          : const StoreRevisionDelta.elementVisual(),
    );
  }

  return delta;
}

StoreRevisionDelta _committedTextDelta(
  CanvasTextElement before,
  CanvasTextElement after,
) {
  var delta = const StoreRevisionDelta();
  if (_anyChanged([
    before.text != after.text,
    before.fontSize != after.fontSize,
    before.align != after.align,
    before.textDirection != after.textDirection,
    before.isBold != after.isBold,
    before.isItalic != after.isItalic,
    before.fontFamily != after.fontFamily,
    before.maxWidth != after.maxWidth,
    before.lineHeight != after.lineHeight,
  ])) {
    delta = delta.merge(const StoreRevisionDelta.elementBounds());
  }
  if (before.color != after.color || before.isUnderline != after.isUnderline) {
    delta = delta.merge(const StoreRevisionDelta.elementVisual());
  }

  return delta;
}

StoreRevisionDelta _committedStrokeDelta(
  CanvasStrokeElement before,
  CanvasStrokeElement after,
) {
  var delta = const StoreRevisionDelta();
  if (!_sameList(before.points, after.points) ||
      before.thickness != after.thickness) {
    delta = delta.merge(const StoreRevisionDelta.elementBounds());
  }
  if (before.color != after.color) {
    delta = delta.merge(const StoreRevisionDelta.elementVisual());
  }

  return delta;
}

StoreRevisionDelta _committedLineDelta(
  CanvasLineElement before,
  CanvasLineElement after,
) {
  var delta = const StoreRevisionDelta();
  if (before.start != after.start ||
      before.end != after.end ||
      before.thickness != after.thickness) {
    delta = delta.merge(const StoreRevisionDelta.elementBounds());
  }
  if (before.color != after.color) {
    delta = delta.merge(const StoreRevisionDelta.elementVisual());
  }

  return delta;
}

StoreRevisionDelta _committedRectDelta(
  CanvasRectElement before,
  CanvasRectElement after,
) {
  var delta = const StoreRevisionDelta();
  if (before.size != after.size || before.strokeWidth != after.strokeWidth) {
    delta = delta.merge(const StoreRevisionDelta.elementBounds());
  }
  if (before.fillColor != after.fillColor) {
    delta = delta.merge(const StoreRevisionDelta.elementVisual());
  }
  if (before.strokeColor != after.strokeColor) {
    delta = delta.merge(
      _strokePaintedBoundsChanged(
            before.strokeColor,
            before.strokeWidth,
            after.strokeColor,
            after.strokeWidth,
          )
          ? const StoreRevisionDelta.elementBounds()
          : const StoreRevisionDelta.elementVisual(),
    );
  }

  return delta;
}

bool _strokePaintedBoundsChanged(
  Color? beforeColor,
  double beforeStrokeWidth,
  Color? afterColor,
  double afterStrokeWidth,
) {
  return _isPaintedStroke(beforeColor, beforeStrokeWidth) !=
          _isPaintedStroke(afterColor, afterStrokeWidth) ||
      beforeStrokeWidth != afterStrokeWidth;
}

bool _isPaintedStroke(Color? color, double strokeWidth) {
  return color != null && strokeWidth > 0;
}

AcceptedStoreTouchedFacts _sparseAcceptedTouchedFacts({
  required CommittedDocument base,
  required CommittedDocument candidate,
  required List<StoreSparseMutation> mutations,
}) {
  final touched = _SparseTouchedCommittedFacts.fromMutations(mutations);
  final resourceIds = touched.allResources ? null : touched.resourceIds;
  final resourceTouches = _resourceTouchedFacts(
    base,
    candidate,
    limitedToIds: resourceIds,
  );
  final elementTouches = _elementTouchedFacts(
    base.elements,
    candidate.elements,
    limitedToIds: touched.allElements ? null : touched.elementIds,
  );

  return _acceptedStoreTouchedFacts(
    elementTouches: elementTouches,
    resourceTouches: resourceTouches,
    layerIds: touched.allElements
        ? _changedLayerIds(base.elements, candidate.elements)
        : _sparseAcceptedLayerIds(
            base: base.elements,
            candidate: candidate.elements,
            mutations: mutations,
          ),
    aggregateTouches: _sparseAggregateTouchedFacts(
      base: base,
      candidate: candidate,
      touched: touched,
    ),
  );
}

AcceptedStoreTouchedFacts _acceptedStoreTouchedFacts({
  required _ElementTouchedFacts elementTouches,
  required _ResourceTouchedFacts resourceTouches,
  required Set<CanvasLayerId> layerIds,
  required _AggregateTouchedFacts aggregateTouches,
}) {
  return AcceptedStoreTouchedFacts(
    addedElementIds: elementTouches.addedElementIds,
    removedElementIds: elementTouches.removedElementIds,
    updatedElementIds: elementTouches.updatedElementIds,
    transformedElementIds: elementTouches.transformedElementIds,
    geometryElementIds: elementTouches.geometryElementIds,
    visualElementIds: elementTouches.visualElementIds,
    selectionPruneElementIds: elementTouches.selectionPruneElementIds,
    resourceDescriptorChangedIds: resourceTouches.descriptorChangedIds,
    resourceVisualChangedIds: resourceTouches.visualChangedIds,
    layerIds: layerIds,
    backgroundLayerChanged: aggregateTouches.backgroundLayerChanged,
    persistedCamera: aggregateTouches.persistedCamera,
    background: aggregateTouches.background,
    grid: aggregateTouches.grid,
    palette: aggregateTouches.palette,
  );
}

Set<CanvasLayerId> _sparseAcceptedLayerIds({
  required ElementRegistry base,
  required ElementRegistry candidate,
  required List<StoreSparseMutation> mutations,
}) {
  final layerIds = <CanvasLayerId>{};
  for (final mutation in mutations) {
    _addSparseAcceptedLayerIdsForMutation(
      layerIds,
      base: base,
      candidate: candidate,
      mutation: mutation,
    );
  }

  return layerIds;
}

void _addSparseAcceptedLayerIdsForMutation(
  Set<CanvasLayerId> layerIds, {
  required ElementRegistry base,
  required ElementRegistry candidate,
  required StoreSparseMutation mutation,
}) {
  switch (mutation) {
    case StoreSparseEnsureLayer(:final id):
      _addAcceptedEnsuredLayerId(layerIds, base, candidate, id);
    case final StoreSparseAddElement mutation:
      _addAcceptedAddedElementLayerId(
        layerIds,
        base: base,
        candidate: candidate,
        mutation: mutation,
      );
    case StoreSparseRemoveElement(:final id):
      _addAcceptedRemovedElementLayerId(layerIds, base, candidate, id);
    case StoreSparseClearContent():
      layerIds.addAll(_nonEmptyContentLayerIds(base));
    case StoreSparseUpdateElement() ||
        StoreSparseUpsertResource() ||
        StoreSparseRemoveUnusedResource() ||
        StoreSparseSetBackground() ||
        StoreSparseSetCamera() ||
        StoreSparseSetPalette():
      break;
  }
}

void _addAcceptedEnsuredLayerId(
  Set<CanvasLayerId> layerIds,
  ElementRegistry base,
  ElementRegistry candidate,
  CanvasLayerId id,
) {
  if (!base.containsLayer(id) && candidate.containsLayer(id)) {
    layerIds.add(id);
  }
}

void _addAcceptedAddedElementLayerId(
  Set<CanvasLayerId> layerIds, {
  required ElementRegistry base,
  required ElementRegistry candidate,
  required StoreSparseAddElement mutation,
}) {
  final elementId = mutation.element.id;
  if (mutation.index != null &&
      !mutation.background &&
      base.elementById(elementId) == null &&
      candidate.elementById(elementId) != null) {
    _addContentLayerForElement(layerIds, candidate, elementId);
  }
}

void _addAcceptedRemovedElementLayerId(
  Set<CanvasLayerId> layerIds,
  ElementRegistry base,
  ElementRegistry candidate,
  CanvasElementId id,
) {
  if (base.elementById(id) != null && candidate.elementById(id) == null) {
    _addContentLayerForElement(layerIds, base, id);
  }
}

void _addContentLayerForElement(
  Set<CanvasLayerId> layerIds,
  ElementRegistry registry,
  CanvasElementId elementId,
) {
  if (registry.elementLocationFacts[elementId] case ElementLocationFacts(
    kind: ElementLocationKind.content,
    layerId: final layerId?,
  )) {
    layerIds.add(layerId);
  }
}

Iterable<CanvasLayerId> _nonEmptyContentLayerIds(
  ElementRegistry registry,
) sync* {
  for (final row in registry.layerTable.rows) {
    if (row.elementIds.isNotEmpty) {
      yield row.id;
    }
  }
}

_AggregateTouchedFacts _sparseAggregateTouchedFacts({
  required CommittedDocument base,
  required CommittedDocument candidate,
  required _SparseTouchedCommittedFacts touched,
}) {
  return _AggregateTouchedFacts(
    backgroundLayerChanged:
        _sparseTouchesBackgroundElementOrder(
          base.elements,
          candidate.elements,
          touched,
        ) &&
        !_sameList(
          base.elements.backgroundElementIds,
          candidate.elements.backgroundElementIds,
        ),
    persistedCamera: touched.camera && base.camera != candidate.camera,
    background:
        touched.background &&
        base.background.color != candidate.background.color,
    grid:
        touched.background && base.background.grid != candidate.background.grid,
    palette: touched.palette && !_samePalette(base.palette, candidate.palette),
  );
}

bool _committedElementTouchesSpatial(
  CanvasElement before,
  CanvasElement after,
  StoreRevisionDelta delta,
) {
  return delta.bounds || before.isSelectable != after.isSelectable;
}

bool _sparseTouchesBackgroundElementOrder(
  ElementRegistry base,
  ElementRegistry candidate,
  _SparseTouchedCommittedFacts touched,
) {
  if (touched.backgroundElementOrder) {
    return true;
  }

  return touched.elementIds.any(
    (id) =>
        _isBackgroundLocation(base.elementLocationFacts[id]) ||
        _isBackgroundLocation(candidate.elementLocationFacts[id]),
  );
}

bool _isBackgroundLocation(ElementLocationFacts? location) {
  return location?.kind == ElementLocationKind.background;
}

bool _anyChanged(List<bool> changes) {
  return changes.contains(true);
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
  return !update.elementRevisionDelta.hasChanges &&
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
      'sparse element update delta must be derived from the committed row.',
    );
  }
}

void _validateSparseElementUpdateKind({
  required CanvasElement before,
  required StoreSparseUpdateElement update,
}) {
  final after = update.element;
  if (before.kind != after.kind) {
    throw ArgumentError.value(
      after,
      'element',
      'element update kind does not match the target element.',
    );
  }
}

void _validateFinalCandidateResourceRelationships(CommittedDocument document) {
  for (final elementId in document.elements.frameElementOrder) {
    final element = document.elements.elementById(elementId);
    if (element == null) {
      throw StateError('committed element order references a missing row.');
    }
    switch (element) {
      case CanvasImageElement(:final resourceId):
        _validateResourceRelationship(
          document: document,
          resourceId: resourceId,
          path: 'image.resourceId',
          expectsImage: true,
        );
      case CanvasVectorElement(:final resourceId):
        _validateResourceRelationship(
          document: document,
          resourceId: resourceId,
          path: 'vector.resourceId',
          expectsImage: false,
        );
      case CanvasPathElement() ||
          CanvasTextElement() ||
          CanvasStrokeElement() ||
          CanvasLineElement() ||
          CanvasRectElement():
        break;
    }
  }
}

void _validateResourceRelationship({
  required CommittedDocument document,
  required CanvasResourceId resourceId,
  required String path,
  required bool expectsImage,
}) {
  final descriptor = document.resourceDescriptor(resourceId);
  if (descriptor == null) {
    throw CanvasDataException(
      code: CanvasDataErrorCode.missingResourceReference,
      message: 'resource element references a missing resource.',
      path: path,
    );
  }
  final matches = switch (descriptor) {
    StoreImageResourceDescriptorFacts() => expectsImage,
    StoreVectorResourceDescriptorFacts() => !expectsImage,
  };
  if (!matches) {
    throw CanvasDataException(
      code: CanvasDataErrorCode.resourceKindMismatch,
      message: 'resource kind does not match the referencing element.',
      path: path,
    );
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

final class _ResourceTouchedFacts {
  const _ResourceTouchedFacts({
    required this.descriptorChangedIds,
    required this.visualChangedIds,
  });

  final Set<CanvasResourceId> descriptorChangedIds;
  final Set<CanvasResourceId> visualChangedIds;
}

final class _ElementTouchedFacts {
  final Set<CanvasElementId> addedElementIds = {};
  final Set<CanvasElementId> removedElementIds = {};
  final Set<CanvasElementId> updatedElementIds = {};
  final Set<CanvasElementId> transformedElementIds = {};
  final Set<CanvasElementId> geometryElementIds = {};
  final Set<CanvasElementId> visualElementIds = {};
  final Set<CanvasElementId> selectionPruneElementIds = {};
}

final class _AggregateTouchedFacts {
  const _AggregateTouchedFacts({
    required this.backgroundLayerChanged,
    required this.persistedCamera,
    required this.background,
    required this.grid,
    required this.palette,
  });

  final bool backgroundLayerChanged;
  final bool persistedCamera;
  final bool background;
  final bool grid;
  final bool palette;
}

// Sparse finalization records only candidate-touched rows and aggregate
// families so net no-op detection stays bounded to the sparse mutation input.
// ignore: coupling-between-object-classes
final class _SparseTouchedCommittedFacts {
  _SparseTouchedCommittedFacts.fromMutations(
    Iterable<StoreSparseMutation> mutations,
  ) {
    for (final mutation in mutations) {
      addMutation(mutation);
    }
  }

  final Set<CanvasElementId> elementIds = {};
  final Set<CanvasLayerId> layerIds = {};
  final Set<CanvasResourceId> resourceIds = {};
  bool allElements = false;
  bool touchedElementStructure = false;
  bool backgroundElementOrder = false;
  bool allResources = false;
  bool background = false;
  bool camera = false;
  bool palette = false;

  // Keeping the sparse mutation taxonomy together makes omissions visible when
  // new sparse mutation types are added.
  // ignore: cyclomatic-complexity
  void addMutation(StoreSparseMutation mutation) {
    switch (mutation) {
      case StoreSparseEnsureLayer(:final id):
        touchedElementStructure = true;
        layerIds.add(id);
      case StoreSparseAddElement(
        :final element,
        :final layerId,
        :final background,
      ):
        touchedElementStructure = true;
        backgroundElementOrder = backgroundElementOrder || background;
        elementIds.add(element.id);
        if (layerId != null) {
          layerIds.add(layerId);
        }
      case StoreSparseUpdateElement(:final before, :final element):
        elementIds.add(before.id);
        elementIds.add(element.id);
      case StoreSparseRemoveElement(:final id):
        touchedElementStructure = true;
        elementIds.add(id);
      case StoreSparseUpsertResource(:final resource):
        resourceIds.add(resource.id);
      case StoreSparseRemoveUnusedResource(:final id):
        resourceIds.add(id);
      case StoreSparseClearContent(:final removeUnusedResources):
        allElements = true;
        touchedElementStructure = true;
        backgroundElementOrder = true;
        if (removeUnusedResources) {
          allResources = true;
        }
      case StoreSparseSetBackground():
        background = true;
      case StoreSparseSetCamera():
        camera = true;
      case StoreSparseSetPalette():
        palette = true;
    }
  }
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
    required Iterable<_DeferredSparseElementUpdateValidation>
    deferredValidation,
  }) : elements = List.unmodifiable(elements),
       deferredValidation = List.unmodifiable(deferredValidation);

  final List<CanvasElement> elements;
  final StoreRevisionDelta requiredRevisionDelta;
  final List<_DeferredSparseElementUpdateValidation> deferredValidation;

  bool get hasChanges => elements.isNotEmpty;
}

final class _DeferredSparseElementUpdateValidation {
  const _DeferredSparseElementUpdateValidation({
    required this.before,
    required this.update,
  });

  final CanvasElement before;
  final StoreSparseUpdateElement update;

  void validate() {
    if (!update.elementRevisionDelta.hasChanges) {
      throw ArgumentError.value(
        update.elementRevisionDelta,
        'elementRevisionDelta',
        'changed sparse element updates must carry an element revision delta.',
      );
    }
    _validateSparseElementRevision(before: before, after: update.element);
  }
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
    : _admittedIds = admittedIds is Set<String>
          ? admittedIds
          : Set.of(admittedIds);

  final String prefix;
  final Set<String> _admittedIds;
  final Set<String> _reserved = {};
  int _next = 0;

  String nextValue() {
    while (true) {
      final candidate = '$prefix$_next';
      _next += 1;
      if (_admittedIds.contains(candidate) || !_reserved.add(candidate)) {
        continue;
      }

      return candidate;
    }
  }

  void admitAll(Iterable<String> ids) {
    _reserved.addAll(ids);
  }
}
