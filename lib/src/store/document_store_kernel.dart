import 'dart:async';
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

@visibleForTesting
enum IdAdmissionWorkPhase { reset, acceptedAdmission, generation }

@visibleForTesting
enum IdAdmissionWorkKind {
  inputVisit,
  sparseLedgerVisit,
  completeInputSetAllocation,
  cursorProbe,
  collision,
  advance,
  candidateObservation,
  reservation,
}

// Admission observations carry only semantic operation categories. Tests own
// accumulation, so production retains neither IDs nor telemetry history.
@immutable
@visibleForTesting
final class IdAdmissionWorkEvent {
  const IdAdmissionWorkEvent({
    required this.prefix,
    required this.phase,
    required this.kind,
  });

  final String prefix;
  final IdAdmissionWorkPhase phase;
  final IdAdmissionWorkKind kind;
}

// DocumentStoreKernel is the single owner for committed document facts, read
// projection, id admission, and selection normalization inputs; splitting these
// accessors would obscure the shared committed-state source of truth.
// ignore: coupling-between-object-classes, number-of-methods, response-for-class, weighted-methods-per-class
final class DocumentStoreKernel {
  static final Object _idAdmissionWorkZoneKey = Object();

  DocumentStoreKernel() : _document = CommittedDocument.empty() {
    _validateFinalCandidateResourceRelationships(_document);
    _resetIdAdmissionFromOwners();
  }

  @visibleForTesting
  DocumentStoreKernel.withCommittedDocumentForTesting(this._document) {
    _validateFinalCandidateResourceRelationships(_document);
    _resetIdAdmissionFromOwners();
  }

  void _resetIdAdmissionFromOwners() {
    _elementIds = _IdAdmission(
      prefix: 'e',
      enumerate: _document.elements.familyTables.enumerateElementIds,
    );
    _layerIds = _IdAdmission(
      prefix: 'l',
      enumerate: _document.elements.layerTable.enumerateLayerIds,
    );
    _resourceIds = _IdAdmission(
      prefix: 'r',
      enumerate: _document.resourceTable.enumerateResourceIds,
    );
  }

  void _admitCompleteDocumentOwners() {
    _elementIds.admitComplete(
      _document.elements.familyTables.enumerateElementIds,
    );
    _layerIds.admitComplete(_document.elements.layerTable.enumerateLayerIds);
    _resourceIds.admitComplete(_document.resourceTable.enumerateResourceIds);
  }

  CommittedDocument _document;
  final DocumentProjectionCache _projectionCache = DocumentProjectionCache();
  late _IdAdmission _elementIds;
  late _IdAdmission _layerIds;
  late _IdAdmission _resourceIds;

  // The Zone sink is test-only and assert-gated at the owner operation, so it
  // cannot retain admission state or add production telemetry work.
  @visibleForTesting
  static T observeIdAdmissionWork<T>(
    void Function(IdAdmissionWorkEvent event) sink,
    T Function() operation,
  ) {
    return runZoned(operation, zoneValues: {_idAdmissionWorkZoneKey: sink});
  }

  static void _recordIdAdmissionWork({
    required String prefix,
    required IdAdmissionWorkPhase phase,
    required IdAdmissionWorkKind kind,
  }) {
    assert(() {
      final sink = Zone.current[_idAdmissionWorkZoneKey];
      if (sink is void Function(IdAdmissionWorkEvent)) {
        sink(IdAdmissionWorkEvent(prefix: prefix, phase: phase, kind: kind));
      }
      return true;
    }(), 'id admission work observation failed');
  }

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
    return LayerTable.withReadScopeIterable<CanvasLayerId>(
      LayerTableReadScope.intentionalIteration,
      () => _document.elements.layerTable.rows.map((row) => row.id),
    );
  }

  Iterable<CanvasElementId> elementIdsInLayer(CanvasLayerId id) {
    return LayerTable.withReadScope<Iterable<CanvasElementId>>(
      LayerTableReadScope.perLayerElements,
      () =>
          _document.elements.layerTable.locationFor(id)?.row.elementIds ??
          const <CanvasElementId>[],
    );
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
    final candidate = _elementIds.observeCandidate();
    _elementIds.reserveCandidate(candidate);
    return CanvasElementId(candidate);
  }

  @visibleForTesting
  CanvasElementId observeElementIdCandidateForTesting() {
    return CanvasElementId(_elementIds.observeCandidate());
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
    _admitCompleteDocumentOwners();
  }

  void replaceDocument(CommittedDocument document, StoreRevisionDelta delta) {
    _validateFinalCandidateResourceRelationships(document);
    if (!delta.hasChanges) {
      return;
    }
    _document = _acceptFullDocument(document, delta);
    _resetIdAdmissionFromOwners();
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
    _resetIdAdmissionFromOwners();
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

  void installPreparedMaterializedCommit(
    PreparedMaterializedStoreCommit commit,
  ) {
    if (!commit.hasChanges) {
      return;
    }
    if (!identical(commit.baseDocument, _document)) {
      throw StateError('Prepared materialized store commit is stale.');
    }
    _document = commit.document;
    _admitCompleteDocumentOwners();
  }

  void installPreparedSchemaV1Import(PreparedStoreDocumentImport prepared) {
    prepared.consume(_document.revisions);
    if (!prepared.hasChanges) {
      return;
    }
    _document = prepared.document;
    _resetIdAdmissionFromOwners();
  }

  // Sparse preparation validates, applies, and records admitted-id deltas in
  // one pass so commit acceptance cannot drift from generator admission.
  // Keeping validation, mutation application, final equality, and accepted
  // payload construction together is safer than splitting the transaction
  // boundary into metric-shaped phases.
  // ignore: cyclomatic-complexity, halstead-volume, source-lines-of-code, maintainability-index, maximum-nesting-level
  PreparedSparseStoreCommit prepareSparseCommit(StoreSparseCommit commit) {
    return _document.elements.familyTables.editSparse((familyEditor) {
      final revisionDelta = commit.revisionDelta;
      final acceptedRevisions = revisionDelta.advance(_document.revisions);
      var nextDocument = _document;
      var didMutateFacts = false;
      var needsFullResourceRelationshipValidation = false;
      final resourceRelationshipElementIds = <CanvasElementId>{};
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
          familyEditor.recordUpdateBatch();
          final applied = _updateElements(
            nextDocument,
            updates,
            familyEditor: familyEditor,
            deferredValidation: deferredElementUpdateValidation,
          );
          nextDocument = applied.document;
          didMutateFacts = didMutateFacts || applied.didMutateFacts;
          if (applied.didMutateFacts) {
            _addSparseResourceRelationshipElementIds(
              resourceRelationshipElementIds,
              updates,
            );
          }
          continue;
        }
        final resourceDescriptorBeforeMutation = switch (mutation) {
          StoreSparseUpsertResource(:final resource) =>
            nextDocument.resourceDescriptor(resource.id),
          _ => null,
        };
        final applied = _applySparseMutation(
          nextDocument,
          mutation,
          familyEditor: familyEditor,
          acceptedRevisions: acceptedRevisions,
        );
        nextDocument = applied.document;
        didMutateFacts = didMutateFacts || applied.didMutateFacts;
        if (applied.didMutateFacts) {
          admittedIds.addMutation(mutation);
          switch (mutation) {
            case StoreSparseAddElement(:final element):
              if (_isResourceBackedElement(element)) {
                resourceRelationshipElementIds.add(element.id);
              }
            case StoreSparseUpsertResource(:final resource):
              needsFullResourceRelationshipValidation =
                  needsFullResourceRelationshipValidation ||
                  _resourceDescriptorKindChanged(
                    before: resourceDescriptorBeforeMutation,
                    after: nextDocument.resourceDescriptor(resource.id),
                  );
            case StoreSparseEnsureLayer() ||
                StoreSparseUpdateElement() ||
                StoreSparseRemoveElement() ||
                StoreSparseRemoveUnusedResource() ||
                StoreSparseClearContent() ||
                StoreSparseSetBackground() ||
                StoreSparseSetCamera() ||
                StoreSparseSetPalette():
              break;
          }
        }
        index += 1;
      }
      resourceRelationshipElementIds.removeWhere((id) {
        final isMissing = familyEditor.decide(
          FamilyTablesDecision.removeMembership,
          () => !familyEditor.contains(id),
        );
        familyEditor.recordDecisionRead(
          decision: FamilyTablesDecision.removeMembership,
          subjectKind: FamilyTablesDecisionSubjectKind.element,
          subject: id.value,
          result: isMissing
              ? FamilyTablesDecisionResult.missing
              : FamilyTablesDecisionResult.present,
        );

        return isMissing;
      });
      if (needsFullResourceRelationshipValidation) {
        _validateFinalCandidateResourceRelationships(
          nextDocument,
          familyElementById: familyEditor.elementByCanvasId,
          familyEditor: familyEditor,
        );
      } else if (resourceRelationshipElementIds.isNotEmpty) {
        _validateFinalCandidateResourceRelationships(
          nextDocument,
          elementIds: resourceRelationshipElementIds,
          familyElementById: familyEditor.elementByCanvasId,
          familyEditor: familyEditor,
        );
      }
      final validatedRevisionDelta = _validatedSparseRevisionDelta(
        revisionDelta,
      );
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
              candidateFamilyTables: familyEditor,
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

      if (accepted && familyEditor.hasChanges) {
        familyEditor.normalizeFinalEqualRows(
          _sparseElementIdsForRevisionNormalization(
            _document.elements,
            nextDocument.elements,
            touched,
          ),
          (before, after) => !_committedElementRevisionDelta(
            before: before,
            after: after,
          ).hasChanges,
        );
        if (familyEditor.hasChanges) {
          nextDocument = nextDocument.copyWith(
            elements: nextDocument.elements.adoptFamilyTables(
              familyEditor.freeze(),
            ),
          );
        }
      }

      final acceptedDocument = accepted
          ? _acceptSparseDocument(nextDocument, acceptedDelta)
          : _document;
      return PreparedSparseStoreCommit(
        baseRevisions: _document.revisions,
        document: acceptedDocument,
        revisionDelta: accepted ? acceptedDelta : const StoreRevisionDelta(),
        touchedFacts: accepted
            ? _sparseAcceptedTouchedFacts(
                base: _document,
                candidate: acceptedDocument,
                mutations: commit.mutations,
                familyEditor: familyEditor,
              )
            : AcceptedStoreTouchedFacts.empty(),
        admittedElementIds: accepted ? admittedIds.elementIds : const [],
        admittedLayerIds: accepted ? admittedIds.layerIds : const [],
        admittedResourceIds: accepted ? admittedIds.resourceIds : const [],
      );
    });
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

  void installSparseCommit(PreparedSparseStoreCommit commit) {
    if (!commit.hasChanges) {
      return;
    }
    if (commit.baseRevisions != _document.revisions) {
      throw StateError('Prepared sparse store commit is stale.');
    }
    _document = commit.document;
    _elementIds.admitLedger(commit.admittedElementIds);
    _layerIds.admitLedger(commit.admittedLayerIds);
    _resourceIds.admitLedger(commit.admittedResourceIds);
  }

  // Dispatch stays as one exhaustive journal switch so mutation ordering and
  // the single live family editor cannot diverge through metric-only helpers.
  // ignore: source-lines-of-code
  _SparseMutationResult _applySparseMutation(
    CommittedDocument document,
    StoreSparseMutation mutation, {
    required FamilyTablesEditor familyEditor,
    required RevisionState acceptedRevisions,
  }) {
    return switch (mutation) {
      StoreSparseEnsureLayer(:final id, :final index) => _ensureLayer(
        document,
        id,
        index: index,
      ),
      final StoreSparseAddElement mutation => _addElement(
        document,
        mutation,
        familyEditor: familyEditor,
      ),
      final StoreSparseUpdateElement mutation => _updateElement(
        document,
        mutation,
        familyEditor: familyEditor,
      ),
      StoreSparseRemoveElement(:final id) => _removeElement(
        document,
        id,
        familyEditor: familyEditor,
      ),
      StoreSparseUpsertResource(:final resource) => _upsertResource(
        document,
        resource,
        acceptedRevisions: acceptedRevisions,
      ),
      StoreSparseRemoveUnusedResource(:final id) => _removeUnusedResource(
        document,
        id,
        familyEditor: familyEditor,
      ),
      StoreSparseClearContent(:final removeUnusedResources) => _clearContent(
        document,
        removeUnusedResources: removeUnusedResources,
        familyEditor: familyEditor,
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
    StoreSparseAddElement mutation, {
    required FamilyTablesEditor familyEditor,
  }) {
    familyEditor.decide(
      FamilyTablesDecision.duplicateAdd,
      () => familyEditor.addElement(mutation.element),
    );
    final elements = mutation.background
        ? document.elements.addBackgroundElementStructure(
            mutation.element,
            index: mutation.index,
          )
        : document.elements.addElementStructure(
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
    StoreSparseUpdateElement mutation, {
    required FamilyTablesEditor familyEditor,
  }) {
    final deferredValidation = <_DeferredSparseElementUpdateValidation>[];
    final result = _updateElements(
      document,
      [mutation],
      familyEditor: familyEditor,
      deferredValidation: deferredValidation,
    );
    for (final validation in deferredValidation) {
      validation.validate();
    }

    return result;
  }

  _SparseMutationResult _updateElements(
    CommittedDocument document,
    List<StoreSparseUpdateElement> updates, {
    required FamilyTablesEditor familyEditor,
    required List<_DeferredSparseElementUpdateValidation> deferredValidation,
  }) {
    final batch = _prepareSparseElementUpdateBatch(familyEditor, updates);
    deferredValidation.addAll(batch.deferredValidation);
    if (!batch.hasChanges) {
      return _SparseMutationResult.unchanged(document);
    }

    return _SparseMutationResult.changed(
      document,
      requiredRevisionDelta: batch.requiredRevisionDelta,
    );
  }

  // Source, no-op, kind, and deferred validation are intentionally ordered at
  // this one owner seam; extracting them would risk changing first failure.
  // ignore: halstead-volume, source-lines-of-code, maintainability-index
  _SparseElementUpdateBatch _prepareSparseElementUpdateBatch(
    FamilyTablesEditor familyEditor,
    List<StoreSparseUpdateElement> updates,
  ) {
    final deferredValidation = <_DeferredSparseElementUpdateValidation>[];
    var requiredRevisionDelta = const StoreRevisionDelta();
    for (final update in updates) {
      final element = update.element;
      final before = familyEditor.decide(
        FamilyTablesDecision.updateCurrentRow,
        () => familyEditor.elementByCanvasId(element.id),
      );
      familyEditor.recordDecisionRead(
        decision: FamilyTablesDecision.updateCurrentRow,
        subjectKind: FamilyTablesDecisionSubjectKind.element,
        subject: element.id.value,
        result: before == null
            ? FamilyTablesDecisionResult.missing
            : FamilyTablesDecisionResult.present,
      );
      if (before == null) {
        familyEditor.recordDecision(FamilyTablesDecision.updateMissingId);
        familyEditor.recordDecisionRead(
          decision: FamilyTablesDecision.updateMissingId,
          subjectKind: FamilyTablesDecisionSubjectKind.element,
          subject: element.id.value,
          result: FamilyTablesDecisionResult.missing,
        );
        continue;
      }
      try {
        familyEditor.decide(
          FamilyTablesDecision.updateSource,
          () => _validateSparseElementUpdateSource(
            before: before,
            update: update,
          ),
        );
        familyEditor.recordDecisionRead(
          decision: FamilyTablesDecision.updateSource,
          subjectKind: FamilyTablesDecisionSubjectKind.element,
          subject: element.id.value,
          result: FamilyTablesDecisionResult.matches,
        );
        // The established sparse source diagnostic is an ArgumentError; this
        // observation preserves that first failure while recording its result.
        // ignore: avoid_catching_errors
      } on ArgumentError {
        familyEditor.recordDecisionRead(
          decision: FamilyTablesDecision.updateSource,
          subjectKind: FamilyTablesDecisionSubjectKind.element,
          subject: element.id.value,
          result: FamilyTablesDecisionResult.differs,
        );
        rethrow;
      }
      final isNoOp = familyEditor.decide(
        FamilyTablesDecision.updateNoOp,
        () => _isSparseElementUpdateNoOp(before: before, update: update),
      );
      familyEditor.recordDecisionRead(
        decision: FamilyTablesDecision.updateNoOp,
        subjectKind: FamilyTablesDecisionSubjectKind.element,
        subject: element.id.value,
        result: isNoOp
            ? FamilyTablesDecisionResult.unchanged
            : FamilyTablesDecisionResult.changed,
      );
      if (isNoOp) {
        continue;
      }
      try {
        familyEditor.decide(
          FamilyTablesDecision.updateKind,
          () =>
              _validateSparseElementUpdateKind(before: before, update: update),
        );
        familyEditor.recordDecisionRead(
          decision: FamilyTablesDecision.updateKind,
          subjectKind: FamilyTablesDecisionSubjectKind.element,
          subject: element.id.value,
          result: FamilyTablesDecisionResult.matches,
        );
        // The established sparse kind diagnostic is an ArgumentError; this
        // observation preserves that first failure while recording its result.
        // ignore: avoid_catching_errors
      } on ArgumentError {
        familyEditor.recordDecisionRead(
          decision: FamilyTablesDecision.updateKind,
          subjectKind: FamilyTablesDecisionSubjectKind.element,
          subject: element.id.value,
          result: FamilyTablesDecisionResult.differs,
        );
        rethrow;
      }
      deferredValidation.add(
        _DeferredSparseElementUpdateValidation(before: before, update: update),
      );
      requiredRevisionDelta = requiredRevisionDelta.merge(
        update.elementRevisionDelta,
      );
      familyEditor.replaceElement(element);
    }

    return _SparseElementUpdateBatch(
      requiredRevisionDelta: requiredRevisionDelta,
      deferredValidation: deferredValidation,
    );
  }

  _SparseMutationResult _removeElement(
    CommittedDocument document,
    CanvasElementId id, {
    required FamilyTablesEditor familyEditor,
  }) {
    final isPresent = familyEditor.decide(
      FamilyTablesDecision.removeMembership,
      () => familyEditor.contains(id),
    );
    familyEditor.recordDecisionRead(
      decision: FamilyTablesDecision.removeMembership,
      subjectKind: FamilyTablesDecisionSubjectKind.element,
      subject: id.value,
      result: isPresent
          ? FamilyTablesDecisionResult.present
          : FamilyTablesDecisionResult.missing,
    );
    if (!isPresent) {
      return _SparseMutationResult.unchanged(document);
    }
    familyEditor.removeElement(id);

    return _SparseMutationResult.changed(
      document.copyWith(elements: document.elements.removeElementStructure(id)),
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
    required FamilyTablesEditor familyEditor,
  }) {
    if (!document.resourceTable.contains(id)) {
      return _SparseMutationResult.unchanged(document);
    }
    final isReferenced = familyEditor.decide(
      FamilyTablesDecision.removeUnusedReference,
      () => familyEditor.referencesResource(id),
    );
    familyEditor.recordDecisionRead(
      decision: FamilyTablesDecision.removeUnusedReference,
      subjectKind: FamilyTablesDecisionSubjectKind.resource,
      subject: id.value,
      result: isReferenced
          ? FamilyTablesDecisionResult.referenced
          : FamilyTablesDecisionResult.unreferenced,
    );
    if (isReferenced) {
      return _SparseMutationResult.unchanged(document);
    }

    return _SparseMutationResult.changed(
      document.copyWith(resourceTable: document.resourceTable.remove(id)),
      requiredRevisionDelta: const StoreRevisionDelta.resource(),
    );
  }

  // Clear's one all-family barrier records its semantic outcome before the
  // existing resource and structure transition, which is clearer kept whole.
  // ignore: halstead-volume, source-lines-of-code
  _SparseMutationResult _clearContent(
    CommittedDocument document, {
    required bool removeUnusedResources,
    required FamilyTablesEditor familyEditor,
  }) {
    familyEditor.recordDecision(FamilyTablesDecision.clear);
    final didClearElements = document.elements.elementCount != 0;
    final didClearResources =
        removeUnusedResources && document.resourceTable.count != 0;
    familyEditor.recordDecisionRead(
      decision: FamilyTablesDecision.clear,
      subjectKind: FamilyTablesDecisionSubjectKind.content,
      subject: 'content',
      result: didClearElements
          ? FamilyTablesDecisionResult.changed
          : FamilyTablesDecisionResult.unchanged,
    );
    if (!didClearElements && !didClearResources) {
      return _SparseMutationResult.unchanged(document);
    }
    if (didClearElements) {
      familyEditor.clearElements();
    }
    final clearedElements = didClearElements
        ? document.elements.clearContentStructure()
        : document.elements;
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

// Kept whole so origin and mutable state remain explicit at this boundary.
// ignore: halstead-volume, number-of-parameters
StoreRevisionDelta _sparseAcceptedRevisionDelta({
  required CommittedDocument base,
  required CommittedDocument candidate,
  required FamilyTablesEditor candidateFamilyTables,
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
      baseFamilyTables: base.elements.familyTables,
      candidateFamilyTables: candidateFamilyTables,
      touched: touched,
    ),
  );
}

// This comparison keeps base rows, live editor rows, and the decision trace at
// one gate, preserving sparse acceptance ordering over metric-shaped params.
// ignore: number-of-parameters
StoreRevisionDelta _sparseTouchedElementRevisionDelta(
  ElementRegistry base,
  ElementRegistry candidate, {
  required FamilyTables baseFamilyTables,
  required FamilyTablesEditor candidateFamilyTables,
  required _SparseTouchedCommittedFacts touched,
}) {
  var delta = _sparseTouchedElementStructureRevisionDelta(
    base,
    candidate,
    touched,
  );
  for (final id in touched.elementIds) {
    final rows = candidateFamilyTables.decide(
      FamilyTablesDecision.acceptedDelta,
      () => (
        before: FamilyTables.readSparseBase(
          () => baseFamilyTables.elementByCanvasId(id),
        ),
        after: candidateFamilyTables.elementByCanvasId(id),
      ),
    );
    final before = rows.before;
    final after = rows.after;
    candidateFamilyTables.recordDecisionRead(
      decision: FamilyTablesDecision.acceptedDelta,
      subjectKind: FamilyTablesDecisionSubjectKind.element,
      subject: id.value,
      result: _elementComparisonResult(before: before, after: after),
    );
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

// Optional sparse family sources let the existing touched-facts owner serve
// normal and editor-backed paths without duplicating the resource scan.
// ignore: cyclomatic-complexity, number-of-parameters, halstead-volume, source-lines-of-code
_ResourceTouchedFacts _resourceTouchedFacts(
  CommittedDocument base,
  CommittedDocument candidate, {
  Iterable<CanvasResourceId>? limitedToIds,
  FamilyTables? baseFamilyTables,
  FamilyTables? candidateFamilyTables,
  FamilyTablesEditor? familyEditor,
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
    final baseTables = baseFamilyTables ?? base.elements.familyTables;
    final candidateTables =
        candidateFamilyTables ?? candidate.elements.familyTables;
    final isReferenced = familyEditor == null
        ? baseTables.referencesResource(id) ||
              candidateTables.referencesResource(id)
        : familyEditor.decide(
            FamilyTablesDecision.acceptedTouched,
            () =>
                FamilyTables.readSparseBase(
                  () => baseTables.referencesResource(id),
                ) ||
                candidateTables.referencesResource(id),
          );
    familyEditor?.recordDecisionRead(
      decision: FamilyTablesDecision.acceptedTouched,
      subjectKind: FamilyTablesDecisionSubjectKind.resource,
      subject: id.value,
      result: isReferenced
          ? FamilyTablesDecisionResult.referenced
          : FamilyTablesDecisionResult.unreferenced,
    );
    if (isReferenced) {
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

// Optional sparse family sources keep normal and accepted-editor comparisons
// in the same touched-facts owner rather than creating duplicate classifiers.
// ignore: number-of-parameters
_ElementTouchedFacts _elementTouchedFacts(
  ElementRegistry base,
  ElementRegistry candidate, {
  Iterable<CanvasElementId>? limitedToIds,
  FamilyTables? baseFamilyTables,
  FamilyTables? candidateFamilyTables,
  FamilyTablesEditor? familyEditor,
}) {
  final ids =
      limitedToIds ??
      {...base.frameElementOrder, ...candidate.frameElementOrder};
  final facts = _ElementTouchedFacts();
  for (final id in ids) {
    final baseTables = baseFamilyTables ?? base.familyTables;
    final candidateTables = candidateFamilyTables ?? candidate.familyTables;
    final rows = familyEditor == null
        ? (
            before: baseTables.elementByCanvasId(id),
            after: candidateTables.elementByCanvasId(id),
          )
        : familyEditor.decide(
            FamilyTablesDecision.acceptedTouched,
            () => (
              before: FamilyTables.readSparseBase(
                () => baseTables.elementByCanvasId(id),
              ),
              after: candidateTables.elementByCanvasId(id),
            ),
          );
    familyEditor?.recordDecisionRead(
      decision: FamilyTablesDecision.acceptedTouched,
      subjectKind: FamilyTablesDecisionSubjectKind.element,
      subject: id.value,
      result: _elementComparisonResult(before: rows.before, after: rows.after),
    );
    _recordElementTouch(facts, id: id, before: rows.before, after: rows.after);
  }

  return facts;
}

FamilyTablesDecisionResult _elementComparisonResult({
  required CanvasElement? before,
  required CanvasElement? after,
}) {
  if (before == null) {
    return after == null
        ? FamilyTablesDecisionResult.unchanged
        : FamilyTablesDecisionResult.added;
  }
  if (after == null) {
    return FamilyTablesDecisionResult.removed;
  }

  return _committedElementRevisionDelta(before: before, after: after).hasChanges
      ? FamilyTablesDecisionResult.changed
      : FamilyTablesDecisionResult.unchanged;
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
  return LayerTable.withReadScope(
    LayerTableReadScope.rowIndex,
    () => registry.layerTable.locationFor(id)?.row,
  );
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
  required FamilyTablesEditor familyEditor,
}) {
  final touched = _SparseTouchedCommittedFacts.fromMutations(mutations);
  final resourceIds = touched.allResources ? null : touched.resourceIds;
  final resourceTouches = _resourceTouchedFacts(
    base,
    candidate,
    limitedToIds: resourceIds,
    baseFamilyTables: base.elements.familyTables,
    candidateFamilyTables: candidate.elements.familyTables,
    familyEditor: familyEditor,
  );
  final elementTouches = _elementTouchedFacts(
    base.elements,
    candidate.elements,
    limitedToIds: touched.allElements ? null : touched.elementIds,
    baseFamilyTables: base.elements.familyTables,
    candidateFamilyTables: candidate.elements.familyTables,
    familyEditor: familyEditor,
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
      FamilyTables.readSparseBase(
            () => base.familyTables.elementByCanvasId(elementId),
          ) ==
          null &&
      candidate.familyTables.elementByCanvasId(elementId) != null) {
    _addContentLayerForElement(layerIds, candidate, elementId);
  }
}

void _addAcceptedRemovedElementLayerId(
  Set<CanvasLayerId> layerIds,
  ElementRegistry base,
  ElementRegistry candidate,
  CanvasElementId id,
) {
  if (FamilyTables.readSparseBase(
            () => base.familyTables.elementByCanvasId(id),
          ) !=
          null &&
      candidate.familyTables.elementByCanvasId(id) == null) {
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

void _addSparseResourceRelationshipElementIds(
  Set<CanvasElementId> elementIds,
  Iterable<StoreSparseUpdateElement> updates,
) {
  for (final update in updates) {
    if (_sparseElementUpdateChangesResourceRelationships(update)) {
      elementIds.add(update.element.id);
    }
  }
}

bool _sparseElementUpdateChangesResourceRelationships(
  StoreSparseUpdateElement update,
) {
  final before = update.before;
  final after = update.element;
  if (before is CanvasImageElement && after is CanvasImageElement) {
    return before.resourceId != after.resourceId;
  }
  if (before is CanvasVectorElement && after is CanvasVectorElement) {
    return before.resourceId != after.resourceId;
  }

  return _isResourceBackedElement(before) || _isResourceBackedElement(after);
}

bool _isResourceBackedElement(CanvasElement? element) {
  return element is CanvasImageElement || element is CanvasVectorElement;
}

bool _resourceDescriptorKindChanged({
  required StoreResourceDescriptorFacts? before,
  required StoreResourceDescriptorFacts? after,
}) {
  if (before == null || after == null) {
    return false;
  }

  return switch (before) {
    StoreImageResourceDescriptorFacts() =>
      after is StoreVectorResourceDescriptorFacts,
    StoreVectorResourceDescriptorFacts() =>
      after is StoreImageResourceDescriptorFacts,
  };
}

// The exhaustive family validation switch stays alongside the optional live
// lookup so final relationship failure precedence remains explicit.
// ignore: cyclomatic-complexity, halstead-volume, source-lines-of-code
void _validateFinalCandidateResourceRelationships(
  CommittedDocument document, {
  Iterable<CanvasElementId>? elementIds,
  CanvasElement? Function(CanvasElementId id)? familyElementById,
  FamilyTablesEditor? familyEditor,
}) {
  final ids = elementIds ?? document.elements.frameElementOrder;
  for (final elementId in ids) {
    final element = familyEditor == null
        ? familyElementById?.call(elementId) ??
              document.elements.elementById(elementId)
        : familyEditor.decide(
            FamilyTablesDecision.relationship,
            () =>
                familyElementById?.call(elementId) ??
                document.elements.elementById(elementId),
          );
    if (element == null) {
      familyEditor?.recordDecisionRead(
        decision: FamilyTablesDecision.relationship,
        subjectKind: FamilyTablesDecisionSubjectKind.element,
        subject: elementId.value,
        result: FamilyTablesDecisionResult.missing,
      );
      throw StateError('committed element order references a missing row.');
    }
    try {
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
      familyEditor?.recordDecisionRead(
        decision: FamilyTablesDecision.relationship,
        subjectKind: FamilyTablesDecisionSubjectKind.element,
        subject: elementId.value,
        result: FamilyTablesDecisionResult.valid,
      );
    } on CanvasDataException {
      familyEditor?.recordDecisionRead(
        decision: FamilyTablesDecision.relationship,
        subjectKind: FamilyTablesDecisionSubjectKind.element,
        subject: elementId.value,
        result: FamilyTablesDecisionResult.invalid,
      );
      rethrow;
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
    required this.requiredRevisionDelta,
    required Iterable<_DeferredSparseElementUpdateValidation>
    deferredValidation,
  }) : deferredValidation = List.unmodifiable(deferredValidation);

  final StoreRevisionDelta requiredRevisionDelta;
  final List<_DeferredSparseElementUpdateValidation> deferredValidation;

  bool get hasChanges => deferredValidation.isNotEmpty;
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
  _IdAdmission({
    required this.prefix,
    required void Function(void Function(String) accept) enumerate,
  }) : _reserved = _allocateIdSet(
         prefix,
         phase: IdAdmissionWorkPhase.reset,
         completeInputCopy: false,
       ) {
    enumerate((id) {
      _record(IdAdmissionWorkPhase.reset, IdAdmissionWorkKind.inputVisit);
      _reserved.add(id);
    });
    _normalize(IdAdmissionWorkPhase.reset);
  }

  final String prefix;
  final Set<String> _reserved;
  int _next = 0;

  String observeCandidate() {
    _record(
      IdAdmissionWorkPhase.generation,
      IdAdmissionWorkKind.candidateObservation,
    );
    return '$prefix$_next';
  }

  String nextValue() {
    final candidate = '$prefix$_next';
    reserveCandidate(candidate);
    return candidate;
  }

  void reserveCandidate(String candidate) {
    if (candidate != '$prefix$_next') {
      throw StateError('Id admission candidate is stale.');
    }
    if (!_reserved.add(candidate)) {
      throw StateError('Id admission candidate is already reserved.');
    }
    _record(IdAdmissionWorkPhase.generation, IdAdmissionWorkKind.reservation);
    _next += 1;
    _record(IdAdmissionWorkPhase.generation, IdAdmissionWorkKind.advance);
    _normalize(IdAdmissionWorkPhase.generation);
  }

  void admitComplete(void Function(void Function(String) accept) enumerate) {
    _admit(
      phase: IdAdmissionWorkPhase.acceptedAdmission,
      values: (accept) => enumerate(accept),
    );
  }

  void admitLedger(Iterable<String> ids) {
    _admit(
      phase: IdAdmissionWorkPhase.acceptedAdmission,
      values: (accept) {
        for (final id in ids) {
          _record(
            IdAdmissionWorkPhase.acceptedAdmission,
            IdAdmissionWorkKind.sparseLedgerVisit,
          );
          accept(id);
        }
      },
    );
  }

  void _admit({
    required IdAdmissionWorkPhase phase,
    required void Function(void Function(String) accept) values,
  }) {
    final currentCandidate = '$prefix$_next';
    var shouldNormalize = false;
    values((id) {
      _record(phase, IdAdmissionWorkKind.inputVisit);
      if (_reserved.add(id) && id == currentCandidate) {
        shouldNormalize = true;
      }
    });
    if (shouldNormalize) {
      _normalize(phase);
    }
  }

  void _normalize(IdAdmissionWorkPhase phase) {
    while (true) {
      final candidate = '$prefix$_next';
      _record(phase, IdAdmissionWorkKind.cursorProbe);
      if (!_reserved.contains(candidate)) {
        return;
      }
      _record(phase, IdAdmissionWorkKind.collision);
      _next += 1;
      _record(phase, IdAdmissionWorkKind.advance);
    }
  }

  void _record(IdAdmissionWorkPhase phase, IdAdmissionWorkKind kind) {
    DocumentStoreKernel._recordIdAdmissionWork(
      prefix: prefix,
      phase: phase,
      kind: kind,
    );
  }
}

// Admission history allocates only here. A complete-input copy is forbidden,
// but if one is introduced at the centralized seeding owner it must declare
// that distinct allocation purpose for test-only semantic observation.
Set<String> _allocateIdSet(
  String prefix, {
  required IdAdmissionWorkPhase phase,
  required bool completeInputCopy,
}) {
  if (completeInputCopy) {
    DocumentStoreKernel._recordIdAdmissionWork(
      prefix: prefix,
      phase: phase,
      kind: IdAdmissionWorkKind.completeInputSetAllocation,
    );
  }
  return <String>{};
}
