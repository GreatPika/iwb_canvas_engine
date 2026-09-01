import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';

// DocumentStoreKernel directly names the DTO, fact, projection, and revision
// owners it coordinates; hiding one import behind a wrapper would obscure the
// committed-store boundary instead of simplifying it.
// ignore_for_file: number-of-imports

import '../contracts/public/canvas_element.dart';
import '../contracts/internal/deletion_entry_projection_port.dart';
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
import 'id_admission.dart';
import 'layer_table.dart';
import 'resource_table.dart';
import 'revision_state.dart';
import 'schema_v1_store_import.dart';
import 'sparse_store_commit.dart';
import 'store_commit_finalization.dart';
import 'store_revision_delta.dart';

export 'id_admission.dart' show IdAdmissionWorkKind, IdAdmissionWorkPhase;
export 'sparse_store_commit.dart' show StoreAffectedElementProjection;
export 'store_commit_finalization.dart' show MaterializedStoreCommitCandidates;

// Admission observations carry a semantic operation and, when it is a sparse
// ledger visit, the visited ID. Tests own accumulation, so production retains
// neither IDs nor telemetry history.
@immutable
@visibleForTesting
final class IdAdmissionWorkEvent {
  const IdAdmissionWorkEvent({
    required this.prefix,
    required this.phase,
    required this.kind,
    this.subject,
  });

  final String prefix;
  final IdAdmissionWorkPhase phase;
  final IdAdmissionWorkKind kind;
  final String? subject;
}

@visibleForTesting
enum SparseTransactionWorkPhase { replay, finalization }

@visibleForTesting
enum SparseTransactionWorkKind { journalVisit, ledgerAppend, ledgerRead }

@visibleForTesting
enum SparseTransactionWorkLedger {
  touched,
  admission,
  relationship,
  layer,
  requiredDelta,
  deferredValidation,
}

@visibleForTesting
enum DeletionProjectionWorkEvent {
  snapshotRead,
  inputIdRead,
  duplicateId,
  elementFactRead,
  locationFactRead,
  layerFactRead,
  canonicalOrderComparison,
  arbitraryOrderComparison,
}

@visibleForTesting
enum DeletionPreparedInstallEvent { bound, installed }

/// Selection membership visits are addressed by desired ID, never by document
/// row, so owner fixtures can prove unrelated canvas rows stay out of the path.
@visibleForTesting
enum SelectionNormalizationWorkEvent { desiredIdVisit }

/// Distinct Store-owned preparation phases of a deferred deletion.
///
/// Test injection remains at the owner operation, so a route fixture cannot
/// mistake a RuntimeRoot catch-all for Store preparation.
@visibleForTesting
enum DeletionStorePreparationPhase {
  sparseValidationAndMutation,
  staleStoreBind,
  selectionNormalization,
}

// Sparse preparation exposes only phase-attributed semantic work. The fixture
// owns the trace, so the transaction keeps no telemetry history in production.
@immutable
@visibleForTesting
final class SparseTransactionWorkEvent {
  const SparseTransactionWorkEvent({
    required this.phase,
    required this.kind,
    this.ledger,
    this.journalIndex,
    this.subject,
  });

  final SparseTransactionWorkPhase phase;
  final SparseTransactionWorkKind kind;
  final SparseTransactionWorkLedger? ledger;
  final int? journalIndex;
  final String? subject;
}

// DocumentStoreKernel is the single owner for committed document facts, read
// projection, id admission, and selection normalization inputs; splitting these
// accessors would obscure the shared committed-state source of truth.
// ignore: coupling-between-object-classes, number-of-methods, response-for-class, weighted-methods-per-class
final class DocumentStoreKernel implements DeletionEntryProjectionPort {
  static final Object _idAdmissionWorkZoneKey = Object();
  static final Object _sparseTransactionWorkZoneKey = Object();
  static final Object _deletionProjectionWorkZoneKey = Object();
  static final Object _deletionEntryProjectionZoneKey = Object();
  static final Object _deletionPreparedInstallZoneKey = Object();
  static final Object _deletionPreparedInstallFailureZoneKey = Object();
  static final Object _deletionPreparationFailureZoneKey = Object();
  static final Object _selectionNormalizationWorkZoneKey = Object();
  static final Object _affectedElementProjectionTestScopeZoneKey = Object();

  DocumentStoreKernel() : _document = CommittedDocument.empty() {
    _validateFinalCandidateResourceRelationships(
      _ResourceRelationshipCandidate(_document),
    );
    _resetIdAdmissionFromOwners();
  }

  @visibleForTesting
  DocumentStoreKernel.withCommittedDocumentForTesting(this._document) {
    _validateFinalCandidateResourceRelationships(
      _ResourceRelationshipCandidate(_document),
    );
    _resetIdAdmissionFromOwners();
  }

  void _resetIdAdmissionFromOwners() {
    final admissions = _resetIdAdmissionsFor(_document);
    _elementIds = admissions.elements;
    _layerIds = admissions.layers;
    _resourceIds = admissions.resources;
  }

  StoreIdAdmissions _resetIdAdmissionsFor(CommittedDocument document) {
    return StoreIdAdmissions(
      elements: StoreIdAdmission.fromEnumerated(
        prefix: 'e',
        enumerate: document.elements.familyTables.enumerateElementIds,
        record: (phase, kind, {subject}) => _recordIdAdmissionWork(
          prefix: 'e',
          phase: phase,
          kind: kind,
          subject: subject,
        ),
      ),
      layers: StoreIdAdmission.fromEnumerated(
        prefix: 'l',
        enumerate: document.elements.layerTable.enumerateLayerIds,
        record: (phase, kind, {subject}) => _recordIdAdmissionWork(
          prefix: 'l',
          phase: phase,
          kind: kind,
          subject: subject,
        ),
      ),
      resources: StoreIdAdmission.fromEnumerated(
        prefix: 'r',
        enumerate: document.resourceTable.enumerateResourceIds,
        record: (phase, kind, {subject}) => _recordIdAdmissionWork(
          prefix: 'r',
          phase: phase,
          kind: kind,
          subject: subject,
        ),
      ),
    );
  }

  StoreIdAdmissions _admitCompleteDocumentOwners(CommittedDocument document) {
    return StoreIdAdmissions(
      elements: _elementIds.admitComplete(
        document.elements.familyTables.enumerateElementIds,
      ),
      layers: _layerIds.admitComplete(
        document.elements.layerTable.enumerateLayerIds,
      ),
      resources: _resourceIds.admitComplete(
        document.resourceTable.enumerateResourceIds,
      ),
    );
  }

  StoreIdAdmissions _admitSparseLedgers(PreparedSparseStoreCommit commit) {
    return _admitSparseIdLists(
      elementIds: commit.admittedElementIds,
      layerIds: commit.admittedLayerIds,
      resourceIds: commit.admittedResourceIds,
    );
  }

  StoreIdAdmissions _admitSparseIdLists({
    required Iterable<String> elementIds,
    required Iterable<String> layerIds,
    required Iterable<String> resourceIds,
  }) {
    return StoreIdAdmissions(
      elements: _elementIds.admitLedger(elementIds),
      layers: _layerIds.admitLedger(layerIds),
      resources: _resourceIds.admitLedger(resourceIds),
    );
  }

  void _installIdAdmissions(StoreIdAdmissions admissions) {
    _elementIds = admissions.elements;
    _layerIds = admissions.layers;
    _resourceIds = admissions.resources;
  }

  CommittedDocument _document;
  final DocumentProjectionCache _projectionCache = DocumentProjectionCache();
  late StoreIdAdmission _elementIds;
  late StoreIdAdmission _layerIds;
  late StoreIdAdmission _resourceIds;

  // The Zone sink is test-only and assert-gated at the owner operation, so it
  // cannot retain admission state or add production telemetry work.
  @visibleForTesting
  static T observeIdAdmissionWork<T>(
    void Function(IdAdmissionWorkEvent event) sink,
    T Function() operation,
  ) {
    return runZoned(operation, zoneValues: {_idAdmissionWorkZoneKey: sink});
  }

  /// Observes real addressed candidate projections without retaining facts.
  @visibleForTesting
  static T observeAffectedElementProjection<T>(
    void Function(StoreAffectedElementProjection projection) sink,
    T Function() operation,
  ) {
    final inherited = _affectedElementProjectionTestScopeForCurrentZone;
    return runZoned(
      operation,
      zoneValues: {
        _affectedElementProjectionTestScopeZoneKey:
            inherited?.withObserver(sink) ??
            _AffectedElementProjectionTestScope(observer: sink),
      },
    );
  }

  /// Fails the actual pre-install projection owner under test assertions.
  @visibleForTesting
  static T injectAffectedElementProjectionFailure<T>(
    Error error,
    T Function() operation,
  ) {
    final inherited = _affectedElementProjectionTestScopeForCurrentZone;
    return runZoned(
      operation,
      zoneValues: {
        _affectedElementProjectionTestScopeZoneKey:
            (inherited ?? const _AffectedElementProjectionTestScope())
                .withFailure(error),
      },
    );
  }

  static _AffectedElementProjectionTestScope?
  get _affectedElementProjectionTestScopeForCurrentZone =>
      Zone.current[_affectedElementProjectionTestScopeZoneKey]
          as _AffectedElementProjectionTestScope?;

  /// Projects one already-prepared sparse candidate against its committed base.
  ///
  /// Both reads are addressed by [id], so preparing an action from the pair
  /// cannot materialize or traverse unrelated document rows.
  StoreAffectedElementProjection projectAffectedElement(
    PreparedSparseStoreCommit candidate,
    CanvasElementId id,
  ) {
    if (candidate.baseRevisions != _document.revisions) {
      throw StateError('A sparse candidate no longer matches committed state.');
    }
    final projection = candidate.affectedElementProjection;
    if (projection == null ||
        projection.before.id != id ||
        projection.after.id != id) {
      throw StateError('An affected element projection requires both rows.');
    }
    assert(
      _observeAffectedElementProjectionForTesting(
        _affectedElementProjectionTestScopeForCurrentZone,
        projection,
      ),
      'affected element projection observation failed',
    );
    return projection;
  }

  static bool _observeAffectedElementProjectionForTesting(
    _AffectedElementProjectionTestScope? scope,
    StoreAffectedElementProjection projection,
  ) {
    final failure = scope?.failure;
    if (failure != null) {
      throw failure;
    }
    scope?.observer?.call(projection);
    return true;
  }

  /// Assert-only observation of the deletion-specific Store boundary.
  @visibleForTesting
  static T observeDeletionPreparedInstall<T>(
    void Function(DeletionPreparedInstallEvent event) sink,
    T Function() operation,
  ) => runZoned(operation, zoneValues: {_deletionPreparedInstallZoneKey: sink});

  /// Causes the real deletion binding owner to fail only under test asserts.
  @visibleForTesting
  static T injectDeletionPreparedInstallFailure<T>(
    Error error,
    T Function() operation,
  ) => runZoned(
    operation,
    zoneValues: {_deletionPreparedInstallFailureZoneKey: error},
  );

  /// Causes one real Store preparation phase to fail only under test asserts.
  @visibleForTesting
  static T injectDeletionPreparationFailure<T>(
    DeletionStorePreparationPhase phase,
    Error error,
    T Function() operation,
  ) => runZoned(
    operation,
    zoneValues: {
      _deletionPreparationFailureZoneKey: (phase: phase, error: error),
    },
  );

  static bool _throwInjectedDeletionPreparationFailure(
    DeletionStorePreparationPhase expected,
  ) {
    final value = Zone.current[_deletionPreparationFailureZoneKey];
    if (value is ({DeletionStorePreparationPhase phase, Error error}) &&
        value.phase == expected) {
      throw value.error;
    }
    return true;
  }

  static bool _throwInjectedDeletionPreparedInstallFailure() {
    final error = Zone.current[_deletionPreparedInstallFailureZoneKey];
    if (error is Error) {
      throw error;
    }
    return true;
  }

  static bool _recordDeletionPreparedInstall(
    DeletionPreparedInstallEvent event,
  ) {
    final sink = Zone.current[_deletionPreparedInstallZoneKey];
    if (sink is void Function(DeletionPreparedInstallEvent)) {
      sink(event);
    }
    return true;
  }

  @visibleForTesting
  static T observeDeletionProjectionWork<T>(
    void Function(DeletionProjectionWorkEvent event) sink,
    T Function() operation,
  ) => runZoned(operation, zoneValues: {_deletionProjectionWorkZoneKey: sink});

  @visibleForTesting
  static T observeSelectionNormalizationWork<T>(
    void Function(SelectionNormalizationWorkEvent event) sink,
    T Function() operation,
  ) => runZoned(
    operation,
    zoneValues: {_selectionNormalizationWorkZoneKey: sink},
  );

  static bool _recordSelectionNormalizationWork(
    SelectionNormalizationWorkEvent event,
  ) {
    final sink = Zone.current[_selectionNormalizationWorkZoneKey];
    if (sink is void Function(SelectionNormalizationWorkEvent)) {
      sink(event);
    }
    return true;
  }

  /// Exposes the immutable result only while assertions are enabled, so route
  /// fixtures can prove consumers retain the Store-produced entry sequence.
  @visibleForTesting
  static T observeDeletionEntryProjection<T>(
    void Function(List<DeletionEntryFacts> entries) sink,
    T Function() operation,
  ) => runZoned(operation, zoneValues: {_deletionEntryProjectionZoneKey: sink});

  static bool _recordDeletionProjectionWork(DeletionProjectionWorkEvent event) {
    final sink = Zone.current[_deletionProjectionWorkZoneKey];
    if (sink is void Function(DeletionProjectionWorkEvent)) {
      sink(event);
    }
    return true;
  }

  static bool _recordDeletionEntryProjection(List<DeletionEntryFacts> entries) {
    final sink = Zone.current[_deletionEntryProjectionZoneKey];
    if (sink is void Function(List<DeletionEntryFacts>)) {
      sink(entries);
    }
    return true;
  }

  static void _recordIdAdmissionWork({
    required String prefix,
    required IdAdmissionWorkPhase phase,
    required IdAdmissionWorkKind kind,
    String? subject,
  }) {
    assert(() {
      final sink = Zone.current[_idAdmissionWorkZoneKey];
      if (sink is void Function(IdAdmissionWorkEvent)) {
        sink(
          IdAdmissionWorkEvent(
            prefix: prefix,
            phase: phase,
            kind: kind,
            subject: subject,
          ),
        );
      }
      return true;
    }(), 'id admission work observation failed');
  }

  // The direct Store owner emits these observations at the journal/ledger
  // boundary, which lets tests distinguish replay work from finalization work.
  @visibleForTesting
  static T observeSparseTransactionWork<T>(
    void Function(SparseTransactionWorkEvent event) sink,
    T Function() operation,
  ) {
    return runZoned(
      operation,
      zoneValues: {_sparseTransactionWorkZoneKey: sink},
    );
  }

  static void _recordSparseTransactionWork(SparseTransactionWorkEvent event) {
    assert(() {
      final sink = Zone.current[_sparseTransactionWorkZoneKey];
      if (sink is void Function(SparseTransactionWorkEvent)) {
        sink(event);
      }
      return true;
    }(), 'sparse transaction work observation failed');
  }

  CanvasDocument readDocument() => _projectionCache.projectionFor(_document);

  CanvasAppearance readAppearance() {
    final document = _document;

    return CanvasAppearance(
      backgroundColor: document.background.color,
      grid: document.background.grid,
      palette: document.palette,
    );
  }

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

  ElementLocationFacts? elementLocationFor(CanvasElementId id) {
    return _document.elements.elementLocationFacts[id];
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

  int imageResourceReferenceCount(CanvasResourceId id) {
    // The sparse facts port reads the existing committed split summary directly.
    // ignore: invalid_use_of_visible_for_testing_member
    return _document.elements.familyTables.imageResourceReferenceCount(id);
  }

  int vectorResourceReferenceCount(CanvasResourceId id) {
    // The sparse facts port reads the existing committed split summary directly.
    // ignore: invalid_use_of_visible_for_testing_member
    return _document.elements.familyTables.vectorResourceReferenceCount(id);
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

  @override
  DeletionEntryProjection projectDeletionEntries(
    Iterable<CanvasElementId> ids,
  ) {
    final document = _document;
    assert(
      _recordDeletionProjectionWork(DeletionProjectionWorkEvent.snapshotRead),
      'deletion projection work observation failed',
    );
    final seen = <CanvasElementId>{};
    final entries = <DeletionEntryFacts>[];
    for (final id in ids) {
      assert(
        _recordDeletionProjectionWork(DeletionProjectionWorkEvent.inputIdRead),
        'deletion projection work observation failed',
      );
      if (!seen.add(id)) {
        assert(
          _recordDeletionProjectionWork(
            DeletionProjectionWorkEvent.duplicateId,
          ),
          'deletion projection work observation failed',
        );
        continue;
      }
      final entry = _deletionEntryFor(document, id);
      if (entry != null) {
        entries.add(entry);
      }
    }
    _orderDeletionEntries(entries);
    final result = DeletionEntryProjection(entries);
    assert(
      _recordDeletionEntryProjection(result.entries),
      'deletion entry projection observation failed',
    );
    return result;
  }

  // These validation and position reads share one committed snapshot. Keeping
  // them together preserves the fail-closed boundary without a second lookup
  // lifecycle merely to satisfy a metric.
  // ignore: cyclomatic-complexity, halstead-volume, source-lines-of-code
  DeletionEntryFacts? _deletionEntryFor(
    CommittedDocument document,
    CanvasElementId id,
  ) {
    assert(
      _recordDeletionProjectionWork(
        DeletionProjectionWorkEvent.elementFactRead,
      ),
      'deletion projection work observation failed',
    );
    final element = document.elements.elementById(id);
    assert(
      _recordDeletionProjectionWork(
        DeletionProjectionWorkEvent.locationFactRead,
      ),
      'deletion projection work observation failed',
    );
    final location = document.elements.elementLocationFacts[id];
    if (element == null ||
        location == null ||
        location.kind != ElementLocationKind.content) {
      return null;
    }
    final layerId = location.layerId;
    if (layerId == null) {
      return null;
    }
    assert(
      _recordDeletionProjectionWork(DeletionProjectionWorkEvent.layerFactRead),
      'deletion projection work observation failed',
    );
    final layer = document.elements.layerTable.locationFor(layerId)?.row;
    final orderToken = document.elements.frameOrderTokensById[id];
    if (layer == null || layer.elementIds.isEmpty || orderToken == null) {
      return null;
    }
    final firstToken =
        document.elements.frameOrderTokensById[layer.elementIds.first];
    if (firstToken == null) {
      return null;
    }
    final elementIndex = orderToken - firstToken;
    if (elementIndex < 0 ||
        elementIndex >= layer.elementIds.length ||
        layer.elementIds[elementIndex] != id) {
      return null;
    }
    return DeletionEntryFacts(
      element: element,
      layerId: layerId,
      elementIndex: elementIndex,
      orderToken: orderToken,
    );
  }

  void _orderDeletionEntries(List<DeletionEntryFacts> entries) {
    if (_entriesAreCanonical(entries)) {
      return;
    }
    entries.sort((left, right) {
      assert(
        _recordDeletionProjectionWork(
          DeletionProjectionWorkEvent.arbitraryOrderComparison,
        ),
        'deletion projection work observation failed',
      );
      return left.orderToken.compareTo(right.orderToken);
    });
  }

  bool _entriesAreCanonical(List<DeletionEntryFacts> entries) {
    for (var index = 1; index < entries.length; index += 1) {
      assert(
        _recordDeletionProjectionWork(
          DeletionProjectionWorkEvent.canonicalOrderComparison,
        ),
        'deletion projection work observation failed',
      );
      if (entries[index - 1].orderToken > entries[index].orderToken) {
        return false;
      }
    }
    return true;
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
    assert(
      _recordDeletionPreparedInstall(DeletionPreparedInstallEvent.bound),
      'deletion Store preparation observation failed',
    );
    assert(
      _throwInjectedDeletionPreparationFailure(
        DeletionStorePreparationPhase.selectionNormalization,
      ),
      'deletion Store selection normalization injection did not complete',
    );

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
    final reserved = _elementIds.reserveCandidate(candidate);
    _elementIds = reserved.admission;
    return CanvasElementId(reserved.value);
  }

  CanvasElementId readElementIdCandidate() {
    return CanvasElementId(_elementIds.observeCandidate());
  }

  CanvasLayerId generateLayerId() {
    final candidate = _layerIds.observeCandidate();
    final reserved = _layerIds.reserveCandidate(candidate);
    _layerIds = reserved.admission;
    return CanvasLayerId(reserved.value);
  }

  CanvasLayerId readLayerIdCandidate() {
    return CanvasLayerId(_layerIds.observeCandidate());
  }

  CanvasResourceId generateResourceId() {
    final candidate = _resourceIds.observeCandidate();
    final reserved = _resourceIds.reserveCandidate(candidate);
    _resourceIds = reserved.admission;
    return CanvasResourceId(reserved.value);
  }

  CanvasResourceId readResourceIdCandidate() {
    return CanvasResourceId(_resourceIds.observeCandidate());
  }

  void installDocument(CommittedDocument document, StoreRevisionDelta delta) {
    prepareDocumentInstall(document, delta).consume();
  }

  /// Prevalidates a normal full-document install while this Store snapshot is
  /// authoritative. Its terminal path has only freshness checks and backing
  /// assignments, so another owner cannot observe a partial admission.
  PreparedStoreDocumentInstall prepareDocumentInstall(
    CommittedDocument document,
    StoreRevisionDelta delta,
  ) {
    _validateFinalCandidateResourceRelationships(
      _ResourceRelationshipCandidate(document),
    );
    if (!delta.hasChanges) {
      return PreparedStoreDocumentInstall.noOp();
    }
    final accepted = _acceptFullDocument(document, delta);
    final admissions = _admitCompleteDocumentOwners(accepted);
    return PreparedStoreDocumentInstall._(
      owner: this,
      baseDocument: _document,
      document: accepted,
      idAdmissions: admissions,
    );
  }

  void replaceDocument(CommittedDocument document, StoreRevisionDelta delta) {
    prepareReplacementDocumentInstall(document, delta).consume();
  }

  PreparedStoreDocumentInstall prepareReplacementDocumentInstall(
    CommittedDocument document,
    StoreRevisionDelta delta,
  ) {
    _validateFinalCandidateResourceRelationships(
      _ResourceRelationshipCandidate(document),
    );
    if (!delta.hasChanges) {
      return PreparedStoreDocumentInstall.noOp();
    }
    final accepted = _acceptFullDocument(document, delta);
    final admissions = _resetIdAdmissionsFor(accepted);
    return PreparedStoreDocumentInstall._(
      owner: this,
      baseDocument: _document,
      document: accepted,
      idAdmissions: admissions,
    );
  }

  void replacePreparedLoadDocument(
    CommittedDocument document,
    StoreRevisionDelta delta,
  ) {
    prepareReplacementDocumentInstall(document, delta).consume();
  }

  PreparedStoreDocumentImport prepareSchemaV1Import(
    StoreSchemaV1ImportBuilder builder,
    StoreRevisionDelta delta,
  ) {
    final prepared = builder.prepare(
      baseRevisions: _document.revisions,
      revisionDelta: delta,
    );
    _validateFinalCandidateResourceRelationships(
      _ResourceRelationshipCandidate(prepared.document),
    );

    return prepared;
  }

  PreparedMaterializedStoreCommit prepareMaterializedCommit(
    CanvasDocument document,
    StoreRevisionDelta revisionDelta, {
    MaterializedStoreCommitCandidates? candidates,
  }) {
    final candidate = CommittedDocument(document);
    _validateFinalCandidateResourceRelationships(
      _ResourceRelationshipCandidate(candidate),
    );
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

    final acceptedDocument = _acceptFullDocument(candidate, acceptedDelta);
    return PreparedMaterializedStoreCommit(
      baseDocument: _document,
      document: acceptedDocument,
      revisionDelta: acceptedDelta,
      touchedFacts: _committedDocumentTouchedFacts(
        _document,
        candidate,
        candidates: candidates,
      ),
      idAdmissions: _admitCompleteDocumentOwners(acceptedDocument),
    );
  }

  void installPreparedMaterializedCommit(
    PreparedMaterializedStoreCommit commit,
  ) {
    preparePreparedMaterializedInstall(commit).consume();
  }

  PreparedStoreDocumentInstall preparePreparedMaterializedInstall(
    PreparedMaterializedStoreCommit commit,
  ) {
    if (!commit.hasChanges) {
      return PreparedStoreDocumentInstall.noOp();
    }
    if (!identical(commit.baseDocument, _document)) {
      throw StateError('Prepared materialized store commit is stale.');
    }
    final admissions =
        commit.idAdmissions ?? _admitCompleteDocumentOwners(commit.document);
    return PreparedStoreDocumentInstall._(
      owner: this,
      baseDocument: commit.baseDocument,
      document: commit.document,
      idAdmissions: admissions,
    );
  }

  void installPreparedSchemaV1Import(PreparedStoreDocumentImport prepared) {
    prepared.consume(_document.revisions);
    if (!prepared.hasChanges) {
      return;
    }
    final admissions = _resetIdAdmissionsFor(prepared.document);
    _document = prepared.document;
    _installIdAdmissions(admissions);
  }

  PreparedSparseStoreCommit prepareSparseCommit(StoreSparseCommit commit) {
    assert(
      _throwInjectedDeletionPreparationFailure(
        DeletionStorePreparationPhase.sparseValidationAndMutation,
      ),
      'deletion Store sparse preparation injection did not complete',
    );
    final revisionDelta = commit.revisionDelta;
    final journal = _SparseTransactionJournal(commit.mutations);
    return _StoreTransactionCandidate.edit(
      _document,
      (candidate) => _prepareSparseCommitInCandidate(
        revisionDelta: revisionDelta,
        journal: journal,
        candidate: candidate,
        affectedElementId: commit.affectedElementId,
      ),
    );
  }

  // Sparse preparation validates, applies, and records admitted-id deltas in
  // one pass so commit acceptance cannot drift from generator admission.
  // Keeping validation, mutation application, final equality, and accepted
  // payload construction together is safer than splitting the transaction
  // boundary into metric-shaped phases. The candidate keeps those owners
  // together without creating an aggregate snapshot during replay.
  // ignore: cyclomatic-complexity, halstead-volume, source-lines-of-code, maintainability-index, maximum-nesting-level
  PreparedSparseStoreCommit _prepareSparseCommitInCandidate({
    required StoreRevisionDelta revisionDelta,
    required _SparseTransactionJournal journal,
    required _StoreTransactionCandidate candidate,
    required CanvasElementId? affectedElementId,
  }) {
    final acceptedRevisions = revisionDelta.advance(_document.revisions);
    final accounting = _SparseTransactionAccounting(
      affectedElementId: affectedElementId,
    );
    try {
      _replaySparseJournal(
        candidate: candidate,
        journal: journal,
        accounting: accounting,
      );
      candidate.resources.enterFinalization();
      candidate.phase(StoreSparseCandidateEventKind.relationshipValidation);
      _validateSparseCandidateRelationships(candidate, accounting);
      candidate.phase(StoreSparseCandidateEventKind.providedDeltaValidation);
      final validatedRevisionDelta = _validatedSparseRevisionDelta(
        revisionDelta,
      );
      candidate.phase(StoreSparseCandidateEventKind.deferredValidation);
      accounting.validateDeferredValidations();
      final structuralComparisonFacts = candidate.structure.finalize();
      final touched = accounting.readTouchedFacts();
      candidate.phase(StoreSparseCandidateEventKind.acceptedFacts);
      final requiredMutationDelta = accounting.readRequiredRevisionDelta();
      final acceptedDelta = requiredMutationDelta.hasChanges
          ? _sparseAcceptedRevisionDelta(
              base: _document,
              candidate: candidate,
              structuralComparisonFacts: structuralComparisonFacts,
              touched: touched,
            )
          : const StoreRevisionDelta();
      final accepted =
          requiredMutationDelta.hasChanges && acceptedDelta.hasChanges;
      if (accepted && !validatedRevisionDelta.hasChanges) {
        throw ArgumentError.value(
          revisionDelta,
          'revisionDelta',
          'sparse store commits that change facts must advance revisions.',
        );
      }
      if (!accepted) {
        candidate.phase(StoreSparseCandidateEventKind.discard);
        candidate.structure.discard();
        return PreparedSparseStoreCommit(
          baseRevisions: _document.revisions,
          document: _document,
          revisionDelta: const StoreRevisionDelta(),
          touchedFacts: AcceptedStoreTouchedFacts.empty(),
        );
      }
      candidate.phase(StoreSparseCandidateEventKind.coverageValidation);
      _validateSparseRevisionCoverage(
        provided: validatedRevisionDelta,
        required: acceptedDelta,
      );
      candidate.phase(StoreSparseCandidateEventKind.normalization);
      final familyTables = _normalizeSparseCandidateFamilyTables(
        candidate: candidate,
        touched: touched,
      );
      candidate.resources.normalizeFinalFacts(
        acceptedRevision: acceptedRevisions.resourceRevision,
      );
      candidate.phase(StoreSparseCandidateEventKind.resourceFreeze);
      final resourceTable = candidate.resources.freeze();
      candidate.phase(StoreSparseCandidateEventKind.structuralPublication);
      final elements = candidate.structure.freeze(familyTables: familyTables);
      final acceptedDocument = CommittedDocument.fromSparseStoreCandidate(
        camera: candidate.camera,
        background: candidate.background,
        palette: candidate.palette,
        elements: elements,
        metadata: _document.metadata,
        resourceTable: resourceTable,
        revisions: acceptedDelta.advance(_document.revisions),
      );
      candidate.phase(StoreSparseCandidateEventKind.touchedFacts);
      final acceptedTouchedFacts = _sparseAcceptedTouchedFacts(
        base: _document,
        candidate: acceptedDocument,
        touched: touched,
        layerCandidates: accounting.readAcceptedLayerCandidates(),
      );
      final affectedElementProjection = accounting
          .readAcceptedAffectedElementProjection();
      candidate.phase(StoreSparseCandidateEventKind.consume);
      final admittedElementIds = accounting.readAdmittedElementIds();
      final admittedLayerIds = accounting.readAdmittedLayerIds();
      final admittedResourceIds = accounting.readAdmittedResourceIds();
      return PreparedSparseStoreCommit(
        baseRevisions: _document.revisions,
        document: acceptedDocument,
        revisionDelta: acceptedDelta,
        touchedFacts: acceptedTouchedFacts,
        admittedElementIds: admittedElementIds,
        admittedLayerIds: admittedLayerIds,
        admittedResourceIds: admittedResourceIds,
        idAdmissions: _admitSparseIdLists(
          elementIds: admittedElementIds,
          layerIds: admittedLayerIds,
          resourceIds: admittedResourceIds,
        ),
        affectedElementProjection: affectedElementProjection,
      );
    } catch (_) {
      candidate.phase(StoreSparseCandidateEventKind.discard);
      rethrow;
    }
  }

  // A single routine preserves journal barriers and ledger attribution at the
  // transaction boundary, where the current-owner reads remain visible.
  // ignore: halstead-volume, source-lines-of-code
  void _replaySparseJournal({
    required _StoreTransactionCandidate candidate,
    required _SparseTransactionJournal journal,
    required _SparseTransactionAccounting accounting,
  }) {
    while (journal.hasNext) {
      final entry = journal.readNext();
      final mutation = entry.mutation;
      if (mutation is StoreSparseUpdateElement) {
        final updateEntries = journal.readContiguousUpdateBatch(entry);
        final updates = <StoreSparseUpdateElement>[
          for (final updateEntry in updateEntries)
            updateEntry.mutation as StoreSparseUpdateElement,
        ];
        final updateJournalIndexes = <StoreSparseUpdateElement, int>{
          for (final updateEntry in updateEntries)
            updateEntry.mutation as StoreSparseUpdateElement:
                updateEntry.journalIndex,
        };
        for (final updateEntry in updateEntries) {
          accounting.recordReplayMutation(
            updateEntry.mutation,
            journalIndex: updateEntry.journalIndex,
          );
        }
        candidate.familyTables.recordUpdateBatch();
        final applied = _updateElements(
          updates,
          familyEditor: candidate.familyTables,
          onDeferredValidation: (validation) {
            accounting.recordDeferredValidation(
              validation,
              journalIndex: updateJournalIndexes[validation.update]!,
            );
          },
        );
        if (applied.didMutateFacts) {
          _recordUpdateResourceReferenceTransitions(
            updates,
            candidate.resources.descriptors,
          );
        }
        accounting.recordAppliedUpdateBatch(applied, updates: updates);
        continue;
      }
      accounting.recordReplayMutation(
        mutation,
        journalIndex: entry.journalIndex,
      );
      final resourceDescriptorBeforeMutation = switch (mutation) {
        StoreSparseUpsertResource(:final resource) =>
          candidate.resources.descriptors.descriptor(resource.id),
        _ => null,
      };
      final applied = _applySparseMutation(candidate, mutation);
      accounting.recordAppliedMutation(
        mutation,
        applied: applied,
        resourceDescriptorBeforeMutation: resourceDescriptorBeforeMutation,
        resourceDescriptorAfterMutation: switch (mutation) {
          StoreSparseUpsertResource(:final resource) =>
            candidate.resources.descriptors.descriptor(resource.id),
          _ => null,
        },
      );
    }
    journal.finishReplay();
  }

  // Relationship traversal keeps final frame order, live family facts, and
  // shared descriptor policy at one precedence gate.
  // ignore: halstead-volume, source-lines-of-code
  void _validateSparseCandidateRelationships(
    _StoreTransactionCandidate candidate,
    _SparseTransactionAccounting accounting,
  ) {
    accounting.removeMissingRelationshipElementIds((id) {
      final isMissing = candidate.familyTables.decide(
        FamilyTablesDecision.removeMembership,
        () => !candidate.familyTables.contains(id),
      );
      candidate.familyTables.recordDecisionRead(
        decision: FamilyTablesDecision.removeMembership,
        subjectKind: FamilyTablesDecisionSubjectKind.element,
        subject: id.value,
        result: isMissing
            ? FamilyTablesDecisionResult.missing
            : FamilyTablesDecisionResult.present,
      );
      return isMissing;
    });
    final ids = accounting.needsFullResourceRelationshipValidation
        ? candidate.structure.currentFrameElementIds
        : accounting.hasResourceRelationshipElementIds
        ? accounting.readResourceRelationshipElementIds()
        : const <CanvasElementId>[];
    for (final id in ids) {
      final element = candidate.familyTables.decide(
        FamilyTablesDecision.relationship,
        () => candidate.familyTables.elementByCanvasId(id),
      );
      if (element == null) {
        candidate.familyTables.recordDecisionRead(
          decision: FamilyTablesDecision.relationship,
          subjectKind: FamilyTablesDecisionSubjectKind.element,
          subject: id.value,
          result: FamilyTablesDecisionResult.missing,
        );
        throw StateError('committed element order references a missing row.');
      }
      try {
        _validateResourceBackedElementRelationship(
          element,
          candidate.resources.descriptors.descriptor,
        );
        candidate.familyTables.recordDecisionRead(
          decision: FamilyTablesDecision.relationship,
          subjectKind: FamilyTablesDecisionSubjectKind.element,
          subject: id.value,
          result: FamilyTablesDecisionResult.valid,
        );
      } on CanvasDataException {
        candidate.familyTables.recordDecisionRead(
          decision: FamilyTablesDecision.relationship,
          subjectKind: FamilyTablesDecisionSubjectKind.element,
          subject: id.value,
          result: FamilyTablesDecisionResult.invalid,
        );
        rethrow;
      }
    }
  }

  FamilyTables _normalizeSparseCandidateFamilyTables({
    required _StoreTransactionCandidate candidate,
    required _SparseTouchedCommittedFacts touched,
  }) {
    if (!candidate.familyTables.hasChanges) {
      return _document.elements.familyTables;
    }
    candidate.familyTables.normalizeFinalEqualRows(
      _sparseElementIdsForRevisionNormalization(
        _document.elements,
        candidate.structure.finalizedFrameElementIds,
        touched,
      ),
      (before, after) => !_committedElementRevisionDelta(
        before: before,
        after: after,
      ).hasChanges,
    );
    if (!candidate.familyTables.hasChanges) {
      return _document.elements.familyTables;
    }
    candidate.phase(StoreSparseCandidateEventKind.familyFreeze);
    return candidate.familyTables.freeze();
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

  void installSparseCommit(PreparedSparseStoreCommit commit) {
    prepareSparseInstall(commit).consume();
  }

  PreparedStoreDocumentInstall prepareSparseInstall(
    PreparedSparseStoreCommit commit,
  ) {
    if (!commit.hasChanges) {
      return PreparedStoreDocumentInstall.noOp();
    }
    if (commit.baseRevisions != _document.revisions) {
      throw StateError('Prepared sparse store commit is stale.');
    }
    assert(
      _throwInjectedDeletionPreparationFailure(
        DeletionStorePreparationPhase.staleStoreBind,
      ),
      'prepared Store bind injection did not complete',
    );
    assert(
      _throwInjectedDeletionPreparedInstallFailure(),
      'prepared Store installation failure injection did not complete',
    );
    final admissions = commit.idAdmissions ?? _admitSparseLedgers(commit);
    return PreparedStoreDocumentInstall._(
      owner: this,
      baseRevisions: commit.baseRevisions,
      document: commit.document,
      idAdmissions: admissions,
    );
  }

  void _installPreparedStoreDocument(PreparedStoreDocumentInstall prepared) {
    if (!prepared._isFreshFor(this)) {
      throw StateError('Prepared Store document install is stale.');
    }
    assert(
      identical(prepared._owner, this),
      'Bound deletion Store installation belongs to another Store owner.',
    );
    assert(
      _recordDeletionPreparedInstall(DeletionPreparedInstallEvent.installed),
      'deletion Store installation observation failed',
    );
    final document = prepared._document;
    final admissions = prepared._idAdmissions;
    if (document == null || admissions == null) {
      throw StateError(
        'A no-op Store install cannot be installed by an owner.',
      );
    }
    _document = document;
    _installIdAdmissions(admissions);
  }

  // Dispatch stays as one exhaustive journal switch so mutation ordering and
  // the one current candidate cannot diverge through a metric-only wrapper.
  // One exhaustive mutation dispatch preserves journal ordering and prevents
  // a second structural replay owner from drifting from Store semantics.
  // ignore: source-lines-of-code, cyclomatic-complexity
  _SparseMutationResult _applySparseMutation(
    _StoreTransactionCandidate candidate,
    StoreSparseMutation mutation,
  ) {
    return switch (mutation) {
      StoreSparseEnsureLayer(:final id, :final index) => _ensureLayer(
        candidate,
        id,
        index: index,
      ),
      StoreSparseRemoveEmptyLayer(:final id) => _removeEmptyLayer(
        candidate,
        id,
      ),
      final StoreSparseAddElement mutation => _addElement(candidate, mutation),
      final StoreSparseUpdateElement mutation => _updateElement(
        candidate,
        mutation,
      ),
      StoreSparseRemoveElement(:final id) => _removeElement(candidate, id),
      StoreSparseUpsertResource(:final resource) => _upsertResource(
        candidate,
        resource,
      ),
      StoreSparseRemoveUnusedResource(:final id) => _removeUnusedResource(
        candidate,
        id,
      ),
      StoreSparseClearContent(:final removeUnusedResources) => _clearContent(
        candidate,
        removeUnusedResources: removeUnusedResources,
      ),
      StoreSparseSetBackground(:final background) => _setBackground(
        candidate,
        background,
      ),
      StoreSparseSetCamera(:final camera) => _setCamera(candidate, camera),
      StoreSparseSetPalette(:final palette) => _setPalette(candidate, palette),
    };
  }

  _SparseMutationResult _ensureLayer(
    _StoreTransactionCandidate candidate,
    CanvasLayerId id, {
    int? index,
  }) {
    if (!candidate.structure.ensureLayer(id, index: index)) {
      return _SparseMutationResult.unchanged();
    }

    return _SparseMutationResult.changed(
      requiredRevisionDelta: const StoreRevisionDelta.layerStructural(),
    );
  }

  _SparseMutationResult _removeEmptyLayer(
    _StoreTransactionCandidate candidate,
    CanvasLayerId id,
  ) {
    if (!candidate.structure.removeEmptyLayer(id)) {
      return _SparseMutationResult.unchanged();
    }
    return _SparseMutationResult.changed(
      requiredRevisionDelta: const StoreRevisionDelta.layerStructural(),
    );
  }

  // The add boundary must make its three distinct owners explicit: duplicate
  // policy, resource references, and current structural placement.
  _SparseMutationResult _addElement(
    _StoreTransactionCandidate candidate,
    StoreSparseAddElement mutation,
  ) {
    candidate.familyTables.decide(
      FamilyTablesDecision.duplicateAdd,
      () => candidate.familyTables.addElement(mutation.element),
    );
    candidate.resources.descriptors.recordResourceReferenceTransition(
      _resourceIdForElement(mutation.element),
    );
    if (mutation.background) {
      candidate.structure.addBackgroundElement(
        mutation.element.id,
        index: mutation.index,
      );
    } else {
      candidate.structure.addContentElement(
        mutation.element.id,
        layerId: mutation.layerId,
        index: mutation.index,
      );
    }

    return _SparseMutationResult.changed(
      requiredRevisionDelta: const StoreRevisionDelta.structural(),
    );
  }

  _SparseMutationResult _updateElement(
    _StoreTransactionCandidate candidate,
    StoreSparseUpdateElement mutation,
  ) {
    final deferredValidation = <_DeferredSparseElementUpdateValidation>[];
    final result = _updateElements(
      [mutation],
      familyEditor: candidate.familyTables,
      onDeferredValidation: deferredValidation.add,
    );
    for (final validation in deferredValidation) {
      validation.validate();
    }
    if (result.didMutateFacts) {
      _recordUpdateResourceReferenceTransitions([
        mutation,
      ], candidate.resources.descriptors);
    }

    return result;
  }

  _SparseMutationResult _updateElements(
    List<StoreSparseUpdateElement> updates, {
    required FamilyTablesEditor familyEditor,
    required void Function(_DeferredSparseElementUpdateValidation validation)
    onDeferredValidation,
  }) {
    final batch = _prepareSparseElementUpdateBatch(familyEditor, updates);
    for (final validation in batch.deferredValidation) {
      onDeferredValidation(validation);
    }
    if (!batch.hasChanges) {
      return _SparseMutationResult.unchanged();
    }
    return _SparseMutationResult.changed(
      requiredRevisionDelta: batch.requiredRevisionDelta,
    );
  }

  void _recordUpdateResourceReferenceTransitions(
    Iterable<StoreSparseUpdateElement> updates,
    ResourceTableWorkingDescriptors resourceDescriptors,
  ) {
    for (final update in updates) {
      resourceDescriptors.recordResourceReferenceTransition(
        _resourceIdForElement(update.before),
      );
      resourceDescriptors.recordResourceReferenceTransition(
        _resourceIdForElement(update.element),
      );
    }
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

  // Removal keeps membership, resource references, and current placement at
  // the same ordered boundary instead of hiding them in a context object.
  // ignore: number-of-parameters
  _SparseMutationResult _removeElement(
    _StoreTransactionCandidate candidate,
    CanvasElementId id,
  ) {
    final isPresent = candidate.familyTables.decide(
      FamilyTablesDecision.removeMembership,
      () => candidate.familyTables.contains(id),
    );
    candidate.familyTables.recordDecisionRead(
      decision: FamilyTablesDecision.removeMembership,
      subjectKind: FamilyTablesDecisionSubjectKind.element,
      subject: id.value,
      result: isPresent
          ? FamilyTablesDecisionResult.present
          : FamilyTablesDecisionResult.missing,
    );
    if (!isPresent) {
      return _SparseMutationResult.unchanged();
    }
    final removed = candidate.familyTables.elementByCanvasId(id);
    candidate.familyTables.removeElement(id);
    candidate.resources.descriptors.recordResourceReferenceTransition(
      removed == null ? null : _resourceIdForElement(removed),
    );

    candidate.structure.removeElement(id);
    return _SparseMutationResult.changed(
      requiredRevisionDelta: const StoreRevisionDelta.structural(),
    );
  }

  _SparseMutationResult _upsertResource(
    _StoreTransactionCandidate candidate,
    CanvasResource resource,
  ) {
    candidate.resources.descriptors.upsert(
      resource,
      resourceRevision: candidate.base.revisions.resourceRevision,
    );
    return _SparseMutationResult.changed(
      requiredRevisionDelta: const StoreRevisionDelta.resource(),
    );
  }

  _SparseMutationResult _removeUnusedResource(
    _StoreTransactionCandidate candidate,
    CanvasResourceId id,
  ) {
    if (!candidate.resources.descriptors.contains(id)) {
      return _SparseMutationResult.unchanged();
    }
    final isReferenced = candidate.familyTables.decide(
      FamilyTablesDecision.removeUnusedReference,
      () => candidate.familyTables.referencesResource(id),
    );
    candidate.familyTables.recordDecisionRead(
      decision: FamilyTablesDecision.removeUnusedReference,
      subjectKind: FamilyTablesDecisionSubjectKind.resource,
      subject: id.value,
      result: isReferenced
          ? FamilyTablesDecisionResult.referenced
          : FamilyTablesDecisionResult.unreferenced,
    );
    if (isReferenced) {
      return _SparseMutationResult.unchanged();
    }
    candidate.resources.descriptors.remove(id);

    return _SparseMutationResult.changed(
      requiredRevisionDelta: const StoreRevisionDelta.resource(),
    );
  }

  // Clear records its sequential barrier before applying content-row removal,
  // resource filtering, and structure changes against the same live editor.
  // The candidate exposes the three owners without retaining their facts.
  // ignore: halstead-volume, source-lines-of-code
  _SparseMutationResult _clearContent(
    _StoreTransactionCandidate candidate, {
    required bool removeUnusedResources,
  }) {
    final contentElementIds = candidate.structure.clearContent();
    final didClearElements = contentElementIds.isNotEmpty;
    candidate.familyTables.recordDecisionRead(
      decision: FamilyTablesDecision.clear,
      subjectKind: FamilyTablesDecisionSubjectKind.content,
      subject: 'content',
      result: didClearElements
          ? FamilyTablesDecisionResult.changed
          : FamilyTablesDecisionResult.unchanged,
    );
    if (didClearElements) {
      _clearContentFamilyRows(
        contentElementIds,
        hasBackgroundElements: candidate.structure.hasBackgroundElements,
        familyEditor: candidate.familyTables,
        resourceEditor: candidate.resources,
      );
    }
    final didClearResources =
        removeUnusedResources &&
        candidate.resources.descriptors.removeUnreferenced(
          candidate.familyTables.referencesResource,
        );
    if (!didClearElements && !didClearResources) {
      return _SparseMutationResult.unchanged();
    }

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
      requiredRevisionDelta: requiredRevisionDelta,
    );
  }

  void _clearContentFamilyRows(
    Iterable<CanvasElementId> contentElementIds, {
    required bool hasBackgroundElements,
    required FamilyTablesEditor familyEditor,
    required ResourceTableEditor resourceEditor,
  }) {
    // With no background rows, the all-family clear is exactly content removal
    // and keeps the editor's family-buffer lifecycle normalized. Background
    // rows instead require selective preservation by content ID.
    for (final id in contentElementIds) {
      final element = familyEditor.elementByCanvasId(id);
      resourceEditor.descriptors.recordResourceReferenceTransition(
        element == null ? null : _resourceIdForElement(element),
      );
    }
    if (!hasBackgroundElements) {
      familyEditor.clearElements();
      return;
    }
    for (final id in contentElementIds) {
      familyEditor.removeElement(id);
    }
  }

  _SparseMutationResult _setBackground(
    _StoreTransactionCandidate candidate,
    CanvasBackground background,
  ) {
    final current = candidate.background;
    if (current == background) {
      return _SparseMutationResult.unchanged();
    }

    var requiredRevisionDelta = const StoreRevisionDelta();
    if (current.color != background.color) {
      requiredRevisionDelta = requiredRevisionDelta.merge(
        const StoreRevisionDelta.background(),
      );
    }
    if (current.grid != background.grid) {
      requiredRevisionDelta = requiredRevisionDelta.merge(
        const StoreRevisionDelta.grid(),
      );
    }

    candidate.setBackground(background);
    return _SparseMutationResult.changed(
      requiredRevisionDelta: requiredRevisionDelta,
    );
  }

  _SparseMutationResult _setCamera(
    _StoreTransactionCandidate candidate,
    CanvasCamera camera,
  ) {
    if (candidate.camera == camera) {
      return _SparseMutationResult.unchanged();
    }
    candidate.setCamera(camera);

    return _SparseMutationResult.changed(
      requiredRevisionDelta: const StoreRevisionDelta.projectionOnly(),
    );
  }

  _SparseMutationResult _setPalette(
    _StoreTransactionCandidate candidate,
    CanvasPalette palette,
  ) {
    if (_samePalette(candidate.palette, palette)) {
      return _SparseMutationResult.unchanged();
    }
    candidate.setPalette(palette);

    return _SparseMutationResult.changed(
      requiredRevisionDelta: const StoreRevisionDelta.projectionOnly(),
    );
  }
}

/// Store-owned prepared installation for every current document form.
///
/// The capability is internal to the Store/Edit/Runtime composition. It owns
/// no resolver policy; consume merely rechecks the prepared freshness fact and
/// swaps the already prepared document and admission backings.
final class PreparedStoreDocumentInstall {
  PreparedStoreDocumentInstall._({
    required DocumentStoreKernel owner,
    required CommittedDocument document,
    required StoreIdAdmissions idAdmissions,
    this.baseDocument,
    this.baseRevisions,
  }) : _owner = owner,
       _document = document,
       _idAdmissions = idAdmissions;

  PreparedStoreDocumentInstall.noOp()
    : _owner = null,
      baseDocument = null,
      baseRevisions = null,
      _document = null,
      _idAdmissions = null;

  final DocumentStoreKernel? _owner;
  final CommittedDocument? baseDocument;
  final RevisionState? baseRevisions;
  final CommittedDocument? _document;
  final StoreIdAdmissions? _idAdmissions;
  bool _consumed = false;

  void consume() {
    if (_consumed) {
      throw StateError('A prepared Store install can only be consumed once.');
    }
    _consumed = true;
    final owner = _owner;
    if (owner != null) {
      owner._installPreparedStoreDocument(this);
    }
  }

  bool _isFreshFor(DocumentStoreKernel owner) {
    final expectedDocument = baseDocument;
    if (expectedDocument != null &&
        !identical(expectedDocument, owner._document)) {
      return false;
    }
    final expectedRevisions = baseRevisions;
    return expectedRevisions == null ||
        expectedRevisions == owner._document.revisions;
  }
}

// This library-private aggregate coordinates the independently owned sparse
// editors. It retains no row, descriptor, or order mirror; each decision stays
// with its owner until final publication. edit closes it on every callback
// exit, so no retained scalar or owner access can outlive that transaction.
// ignore: number-of-methods
final class _StoreTransactionCandidate {
  _StoreTransactionCandidate._({
    required CommittedDocument base,
    required FamilyTablesEditor familyTables,
    required ResourceTableEditor resources,
    required ElementRegistryStructuralEditor structure,
  }) : _camera = base.camera,
       _background = base.background,
       _palette = base.palette,
       _base = base,
       _familyTables = familyTables,
       _resources = resources,
       _structure = structure {
    _record(StoreSparseCandidateEventKind.open);
  }

  static T edit<T>(
    CommittedDocument base,
    T Function(_StoreTransactionCandidate candidate) operation,
  ) {
    return ElementRegistry.editSparseStructure(base.elements, (structure) {
      return base.elements.familyTables.editSparse((familyTables) {
        return ResourceTableEditor.editSparse(base.resourceTable, (resources) {
          final candidate = _StoreTransactionCandidate._(
            base: base,
            familyTables: familyTables,
            resources: resources,
            structure: structure,
          );
          try {
            return operation(candidate);
          } finally {
            candidate._close();
          }
        });
      });
    });
  }

  final CommittedDocument _base;
  final FamilyTablesEditor _familyTables;
  final ResourceTableEditor _resources;
  final ElementRegistryStructuralEditor _structure;

  CanvasCamera _camera;
  CanvasBackground _background;
  CanvasPalette _palette;
  bool _isOpen = true;

  CommittedDocument get base {
    _ensureOpen();
    return _base;
  }

  FamilyTablesEditor get familyTables {
    _ensureOpen();
    return _familyTables;
  }

  ResourceTableEditor get resources {
    _ensureOpen();
    return _resources;
  }

  ElementRegistryStructuralEditor get structure {
    _ensureOpen();
    return _structure;
  }

  CanvasCamera get camera {
    _ensureOpen();
    _record(StoreSparseCandidateEventKind.currentScalarRead);
    return _camera;
  }

  CanvasBackground get background {
    _ensureOpen();
    _record(StoreSparseCandidateEventKind.currentScalarRead);
    return _background;
  }

  CanvasPalette get palette {
    _ensureOpen();
    _record(StoreSparseCandidateEventKind.currentScalarRead);
    return _palette;
  }

  bool setCamera(CanvasCamera value) {
    _ensureOpen();
    if (_camera == value) {
      return false;
    }
    _camera = value;
    return true;
  }

  bool setBackground(CanvasBackground value) {
    _ensureOpen();
    if (_background == value) {
      return false;
    }
    _background = value;
    return true;
  }

  bool setPalette(CanvasPalette value) {
    _ensureOpen();
    if (_samePalette(_palette, value)) {
      return false;
    }
    _palette = value;
    return true;
  }

  void phase(StoreSparseCandidateEventKind kind) => _record(kind);

  void _record(StoreSparseCandidateEventKind kind, {String? subject}) {
    _ensureOpen();
    CommittedDocument.recordSparseCandidateEvent(
      StoreSparseCandidateEvent(kind: kind, subject: subject),
    );
  }

  void _close() {
    _ensureOpen();
    _isOpen = false;
  }

  void _ensureOpen() {
    if (!_isOpen) {
      throw StateError('Store transaction candidate is closed.');
    }
  }
}

bool _samePalette(CanvasPalette left, CanvasPalette right) {
  return _sameList(left.penColors, right.penColors) &&
      _sameList(left.backgroundColors, right.backgroundColors) &&
      _sameList(left.gridSizes, right.gridSizes);
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
  required _StoreTransactionCandidate candidate,
  required ElementRegistryStructuralComparisonFacts structuralComparisonFacts,
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
  if (!_sameTouchedResources(candidate.resources, touched)) {
    delta = delta.merge(const StoreRevisionDelta.resource());
  }

  return delta.merge(
    _sparseTouchedElementRevisionDelta(
      baseFamilyTables: base.elements.familyTables,
      candidateFamilyTables: candidate.familyTables,
      structuralComparisonFacts: structuralComparisonFacts,
      touched: touched,
    ),
  );
}

// This comparison keeps base rows, live editor rows, and the decision trace at
// one gate, preserving sparse acceptance ordering over metric-shaped params.
// ignore: number-of-parameters
StoreRevisionDelta _sparseTouchedElementRevisionDelta({
  required FamilyTables baseFamilyTables,
  required FamilyTablesEditor candidateFamilyTables,
  required ElementRegistryStructuralComparisonFacts structuralComparisonFacts,
  required _SparseTouchedCommittedFacts touched,
}) {
  var delta = _sparseTouchedElementStructureRevisionDelta(
    structuralComparisonFacts,
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
  ElementRegistryStructuralComparisonFacts comparisonFacts,
  _SparseTouchedCommittedFacts touched,
) {
  if (!touched.touchedElementStructure) {
    return const StoreRevisionDelta();
  }
  var delta = const StoreRevisionDelta();
  if (comparisonFacts.elementCountChanged ||
      (touched.backgroundElementOrder &&
          comparisonFacts.backgroundOrderChanged) ||
      comparisonFacts.flatContentOrderChanged ||
      comparisonFacts.contentPlacementChanged) {
    delta = delta.merge(const StoreRevisionDelta.structural());
  }
  if (comparisonFacts.layerStructureChanged ||
      comparisonFacts.layerOrderChanged ||
      comparisonFacts.layerMetadataChanged) {
    delta = delta.merge(const StoreRevisionDelta.layerStructural());
  }

  return delta;
}

Iterable<CanvasElementId> _sparseElementIdsForRevisionNormalization(
  ElementRegistry base,
  Iterable<CanvasElementId> finalFrameElementIds,
  _SparseTouchedCommittedFacts touched,
) {
  if (!touched.allElements) {
    return touched.elementIds;
  }

  return {...base.frameElementOrder, ...finalFrameElementIds};
}

AcceptedStoreTouchedFacts _committedDocumentTouchedFacts(
  CommittedDocument base,
  CommittedDocument candidate, {
  MaterializedStoreCommitCandidates? candidates,
}) {
  final resourceTouches = _resourceTouchedFacts(base, candidate);
  final elementTouches = _elementTouchedFacts(base, candidate);

  return _acceptedStoreTouchedFacts(
    elementTouches: elementTouches,
    resourceTouches: resourceTouches,
    layerIds: _changedLayerIds(
      base.elements,
      candidate.elements,
      limitedToIds: _materializedLayerCandidateIds(
        base: base.elements,
        candidate: candidate.elements,
        candidates: candidates,
      ),
    ),
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

Set<CanvasLayerId>? _materializedLayerCandidateIds({
  required ElementRegistry base,
  required ElementRegistry candidate,
  required MaterializedStoreCommitCandidates? candidates,
}) {
  if (candidates == null) {
    return null;
  }

  final layerIds = <CanvasLayerId>{...candidates.layerIds};
  for (final elementId in candidates.addedElementIds) {
    _addCandidateElementPlacementLayerIds(
      layerIds,
      base: base,
      candidate: candidate,
      elementId: elementId,
    );
  }
  for (final elementId in candidates.removedElementIds) {
    _addCandidateElementPlacementLayerIds(
      layerIds,
      base: base,
      candidate: candidate,
      elementId: elementId,
    );
  }
  return layerIds;
}

bool _sameTouchedResources(
  ResourceTableEditor resourceEditor,
  _SparseTouchedCommittedFacts touched,
) {
  if (touched.resourceIds.isEmpty && !touched.allResources) {
    return true;
  }
  return resourceEditor.descriptors.hasSameFactsAsBase(
    touched.allResources ? null : touched.resourceIds,
  );
}

// Accepted resource touches compare normalized immutable base/final summaries.
// This runs after aggregate publication, so no consumed editor can become a
// second final-facts authority.
// ignore: cyclomatic-complexity, halstead-volume, source-lines-of-code
_ResourceTouchedFacts _resourceTouchedFacts(
  CommittedDocument base,
  CommittedDocument candidate, {
  Iterable<CanvasResourceId>? limitedToIds,
  bool recordSparseReads = false,
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
    final before = recordSparseReads
        ? base.readSparseTouchedResource(
            id,
            side: StoreSparseCandidateReadSide.base,
          )
        : base.resourceDescriptor(id);
    final after = recordSparseReads
        ? candidate.readSparseTouchedResource(
            id,
            side: StoreSparseCandidateReadSide.candidate,
          )
        : candidate.resourceDescriptor(id);
    if (before == null && after == null) {
      continue;
    }
    final changed =
        before == null || after == null || !after.hasSameResourceFacts(before);
    if (!changed) {
      continue;
    }
    descriptorChangedIds.add(id);
    final isReferenced =
        FamilyTables.readSparseBase(
          () => base.elements.familyTables.referencesResource(id),
        ) ||
        FamilyTables.readSparseBase(
          () => candidate.elements.familyTables.referencesResource(id),
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

// Accepted element touches compare normalized immutable base/final rows only.
_ElementTouchedFacts _elementTouchedFacts(
  CommittedDocument base,
  CommittedDocument candidate, {
  Iterable<CanvasElementId>? limitedToIds,
  bool recordSparseReads = false,
}) {
  final ids =
      limitedToIds ??
      {
        ...base.elements.frameElementOrder,
        ...candidate.elements.frameElementOrder,
      };
  final facts = _ElementTouchedFacts();
  for (final id in ids) {
    final rows = (
      before: recordSparseReads
          ? base.readSparseTouchedElement(
              id,
              side: StoreSparseCandidateReadSide.base,
            )
          : FamilyTables.readSparseBase(
              () => base.elements.familyTables.elementByCanvasId(id),
            ),
      after: recordSparseReads
          ? candidate.readSparseTouchedElement(
              id,
              side: StoreSparseCandidateReadSide.candidate,
            )
          : FamilyTables.readSparseBase(
              () => candidate.elements.familyTables.elementByCanvasId(id),
            ),
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
      if (!_sameLayerLocationFacts(
        _layerLocationById(base, id),
        _layerLocationById(candidate, id),
      ))
        id,
  };
}

LayerLocationFacts? _layerLocationById(
  ElementRegistry registry,
  CanvasLayerId id,
) {
  return LayerTable.withReadScope(
    LayerTableReadScope.rowIndex,
    () => registry.layerTable.locationFor(id),
  );
}

bool _sameLayerLocationFacts(
  LayerLocationFacts? before,
  LayerLocationFacts? after,
) {
  if (before == null || after == null) {
    return before == after;
  }

  return before.index == after.index && _sameLayerFacts(before.row, after.row);
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

// The finalizer needs all four committed owner inputs at one semantic gate.
// ignore: number-of-parameters
AcceptedStoreTouchedFacts _sparseAcceptedTouchedFacts({
  required CommittedDocument base,
  required CommittedDocument candidate,
  required _SparseTouchedCommittedFacts touched,
  required _SparseAcceptedLayerCandidates layerCandidates,
}) {
  final resourceTouches = _resourceTouchedFacts(
    base,
    candidate,
    limitedToIds: touched.allResources ? null : touched.resourceIds,
    recordSparseReads: !touched.allResources,
  );
  final elementTouches = _elementTouchedFacts(
    base,
    candidate,
    limitedToIds: touched.allElements ? null : touched.elementIds,
    recordSparseReads: !touched.allElements,
  );

  return _acceptedStoreTouchedFacts(
    elementTouches: elementTouches,
    resourceTouches: resourceTouches,
    layerIds: touched.allElements
        ? _changedLayerIds(base.elements, candidate.elements)
        : _sparseAcceptedLayerIds(
            base: base.elements,
            candidate: candidate.elements,
            candidates: layerCandidates,
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
  required _SparseAcceptedLayerCandidates candidates,
}) {
  final layerIds = <CanvasLayerId>{};
  for (final id in candidates.ensuredLayerIds) {
    _addAcceptedLayerCandidateId(layerIds, base, candidate, id);
  }
  for (final id in candidates.removedLayerIds) {
    _addAcceptedLayerCandidateId(layerIds, base, candidate, id);
  }
  for (final elementId in candidates.indexedAddedElementIds) {
    _addCandidateElementPlacementLayerIds(
      layerIds,
      base: base,
      candidate: candidate,
      elementId: elementId,
    );
  }
  for (final elementId in candidates.removedElementIds) {
    _addCandidateElementPlacementLayerIds(
      layerIds,
      base: base,
      candidate: candidate,
      elementId: elementId,
    );
  }
  if (candidates.clearedContent) {
    layerIds.addAll(_nonEmptyContentLayerIds(base));
  }

  return layerIds;
}

void _addAcceptedLayerCandidateId(
  Set<CanvasLayerId> layerIds,
  ElementRegistry base,
  ElementRegistry candidate,
  CanvasLayerId id,
) {
  final baseLocation = base.layerTable.locationFor(id);
  final candidateLocation = candidate.layerTable.locationFor(id);
  if (!_sameLayerLocationFacts(baseLocation, candidateLocation)) {
    layerIds.add(id);
  }
}

void _addCandidateElementPlacementLayerIds(
  Set<CanvasLayerId> layerIds, {
  required ElementRegistry base,
  required ElementRegistry candidate,
  required CanvasElementId elementId,
}) {
  _addContentLayerForElement(layerIds, base, elementId);
  _addContentLayerForElement(layerIds, candidate, elementId);
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
  return {
    for (final id in ids)
      if (_isSelectionEligibleInCommittedDocument(document, id)) id,
  };
}

bool _isSelectionEligibleInCommittedDocument(
  CommittedDocument document,
  CanvasElementId id,
) {
  assert(
    DocumentStoreKernel._recordSelectionNormalizationWork(
      SelectionNormalizationWorkEvent.desiredIdVisit,
    ),
    'selection normalization work observation failed',
  );
  final location = document.elements.elementLocationFacts[id];

  return location?.kind == ElementLocationKind.content &&
      document.elements.familyTables.isSelectionEligible(id);
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

CanvasResourceId? _resourceIdForElement(CanvasElement element) {
  return switch (element) {
    CanvasImageElement(:final resourceId) ||
    CanvasVectorElement(:final resourceId) => resourceId,
    CanvasPathElement() ||
    CanvasTextElement() ||
    CanvasStrokeElement() ||
    CanvasLineElement() ||
    CanvasRectElement() => null,
  };
}

// This candidate groups the immutable aggregate with its optional live
// descriptor authority, so relationship validation cannot read a stale table.
final class _ResourceRelationshipCandidate {
  const _ResourceRelationshipCandidate(this.document);

  final CommittedDocument document;

  StoreResourceDescriptorFacts? descriptor(CanvasResourceId id) =>
      document.resourceDescriptor(id);
}

// The exhaustive family validation switch stays alongside the candidate lookup
// so final relationship failure precedence remains explicit.
// ignore: cyclomatic-complexity, halstead-volume, source-lines-of-code
void _validateFinalCandidateResourceRelationships(
  _ResourceRelationshipCandidate candidate, {
  Iterable<CanvasElementId>? elementIds,
  CanvasElement? Function(CanvasElementId id)? familyElementById,
  FamilyTablesEditor? familyEditor,
}) {
  final document = candidate.document;
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
        case CanvasImageElement():
          _validateResourceBackedElementRelationship(
            element,
            candidate.descriptor,
          );
        case CanvasVectorElement():
          _validateResourceBackedElementRelationship(
            element,
            candidate.descriptor,
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

void _validateResourceDescriptorRelationship(
  StoreResourceDescriptorFacts? descriptor, {
  required String path,
  required bool expectsImage,
}) {
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

void _validateResourceBackedElementRelationship(
  CanvasElement element,
  StoreResourceDescriptorFacts? Function(CanvasResourceId id) descriptorById,
) {
  switch (element) {
    case CanvasImageElement(:final resourceId):
      _validateResourceDescriptorRelationship(
        descriptorById(resourceId),
        path: 'image.resourceId',
        expectsImage: true,
      );
    case CanvasVectorElement(:final resourceId):
      _validateResourceDescriptorRelationship(
        descriptorById(resourceId),
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

// This phase-aware boundary is the only sparse journal traversal owner. Replay
// consumes each entry once; later phases receive accounting ledgers instead of
// raw mutations, so any future journal access must return through this owner.
final class _SparseTransactionJournal {
  _SparseTransactionJournal(this._mutations);

  final List<StoreSparseMutation> _mutations;
  var _nextIndex = 0;
  var _phase = SparseTransactionWorkPhase.replay;
  _SparseTransactionJournalEntry? _pendingEntry;

  bool get hasNext => _pendingEntry != null || _nextIndex < _mutations.length;

  _SparseTransactionJournalEntry readNext() {
    final pendingEntry = _pendingEntry;
    if (pendingEntry != null) {
      _pendingEntry = null;
      return pendingEntry;
    }
    return _readSourceEntry();
  }

  List<_SparseTransactionJournalEntry> readContiguousUpdateBatch(
    _SparseTransactionJournalEntry first,
  ) {
    final entries = <_SparseTransactionJournalEntry>[first];
    while (_nextIndex < _mutations.length) {
      final entry = _readSourceEntry();
      if (entry.mutation is StoreSparseUpdateElement) {
        entries.add(entry);
      } else {
        _pendingEntry = entry;
        break;
      }
    }
    return entries;
  }

  void finishReplay() {
    if (hasNext) {
      throw StateError('Sparse transaction journal replay is incomplete.');
    }
    _phase = SparseTransactionWorkPhase.finalization;
  }

  _SparseTransactionJournalEntry _readSourceEntry() {
    if (_nextIndex >= _mutations.length) {
      throw StateError('Sparse transaction journal is exhausted.');
    }
    final entry = _readSourceEntryAt(_nextIndex);
    _nextIndex += 1;
    return entry;
  }

  _SparseTransactionJournalEntry _readSourceEntryAt(int journalIndex) {
    final entry = _SparseTransactionJournalEntry(
      mutation: _mutations[journalIndex],
      journalIndex: journalIndex,
    );
    _recordVisit(journalIndex);
    return entry;
  }

  void _recordVisit(int journalIndex) {
    DocumentStoreKernel._recordSparseTransactionWork(
      SparseTransactionWorkEvent(
        phase: _phase,
        kind: SparseTransactionWorkKind.journalVisit,
        journalIndex: journalIndex,
      ),
    );
  }
}

final class _SparseTransactionJournalEntry {
  const _SparseTransactionJournalEntry({
    required this.mutation,
    required this.journalIndex,
  });

  final StoreSparseMutation mutation;
  final int journalIndex;
}

// This one transaction-local owner distinguishes journal-derived candidates
// from base-final facts. Later phases receive its bounded ledgers rather than
// the mutation journal, while committed owner comparisons remain authoritative.
// Keeping the ledger lifecycle together prevents a finalizer from receiving a
// parallel journal-derived classification path.
// ignore: coupling-between-object-classes, number-of-methods, weighted-methods-per-class
final class _SparseTransactionAccounting {
  _SparseTransactionAccounting({CanvasElementId? affectedElementId})
    : _affectedElementId = affectedElementId;

  final _SparseTouchedCommittedFacts _touched = _SparseTouchedCommittedFacts();
  final _SparseAcceptedLayerCandidates _acceptedLayerCandidates =
      _SparseAcceptedLayerCandidates();
  final Set<String> _admittedElementIds = {};
  final Set<String> _admittedLayerIds = {};
  final Set<String> _admittedResourceIds = {};
  final Set<CanvasElementId> _resourceRelationshipElementIds = {};
  final Map<_DeferredSparseElementUpdateValidation, int>
  _deferredElementUpdateValidations = {};
  final CanvasElementId? _affectedElementId;
  CanvasElement? _affectedElementBefore;
  CanvasElement? _affectedElementAfter;
  var _requiredMutationDelta = const StoreRevisionDelta();
  var _needsFullResourceRelationshipValidation = false;

  bool get needsFullResourceRelationshipValidation =>
      _needsFullResourceRelationshipValidation;
  bool get hasResourceRelationshipElementIds =>
      _resourceRelationshipElementIds.isNotEmpty;

  void recordReplayMutation(
    StoreSparseMutation mutation, {
    required int journalIndex,
  }) {
    _touched.addMutation(mutation);
    _append(SparseTransactionWorkLedger.touched, journalIndex: journalIndex);
    if (_acceptedLayerCandidates.addMutation(mutation)) {
      _append(SparseTransactionWorkLedger.layer, journalIndex: journalIndex);
    }
  }

  // This exhaustive mutation boundary keeps first admission and relationship
  // candidates at their existing ordered decision point.
  // ignore: cyclomatic-complexity
  void recordAppliedMutation(
    StoreSparseMutation mutation, {
    required _SparseMutationResult applied,
    required StoreResourceDescriptorFacts? resourceDescriptorBeforeMutation,
    required StoreResourceDescriptorFacts? resourceDescriptorAfterMutation,
  }) {
    if (!applied.didMutateFacts) {
      return;
    }
    _recordRequiredMutationDelta(applied.requiredRevisionDelta);
    _recordAdmission(mutation);
    switch (mutation) {
      case StoreSparseAddElement(:final element):
        if (_isResourceBackedElement(element) &&
            _resourceRelationshipElementIds.add(element.id)) {
          _append(SparseTransactionWorkLedger.relationship);
        }
      case StoreSparseUpsertResource():
        _needsFullResourceRelationshipValidation =
            _needsFullResourceRelationshipValidation ||
            _resourceDescriptorKindChanged(
              before: resourceDescriptorBeforeMutation,
              after: resourceDescriptorAfterMutation,
            );
      case StoreSparseEnsureLayer() ||
          StoreSparseRemoveEmptyLayer() ||
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

  void recordAppliedUpdateBatch(
    _SparseMutationResult applied, {
    required Iterable<StoreSparseUpdateElement> updates,
  }) {
    if (!applied.didMutateFacts) {
      return;
    }
    _recordRequiredMutationDelta(applied.requiredRevisionDelta);
    for (final update in updates) {
      _captureAffectedElementUpdate(update);
      if (_sparseElementUpdateChangesResourceRelationships(update) &&
          _resourceRelationshipElementIds.add(update.element.id)) {
        _append(SparseTransactionWorkLedger.relationship);
      }
    }
  }

  StoreAffectedElementProjection? readAcceptedAffectedElementProjection() {
    final id = _affectedElementId;
    if (id == null) {
      return null;
    }
    final before = _affectedElementBefore;
    final after = _affectedElementAfter;
    if (before == null || after == null || before.id != id || after.id != id) {
      throw StateError('The requested affected element was not accepted.');
    }
    return StoreAffectedElementProjection(before: before, after: after);
  }

  void _captureAffectedElementUpdate(StoreSparseUpdateElement update) {
    if (update.element.id != _affectedElementId) {
      return;
    }
    _affectedElementBefore ??= update.before;
    _affectedElementAfter = update.element;
  }

  void recordDeferredValidation(
    _DeferredSparseElementUpdateValidation validation, {
    required int journalIndex,
  }) {
    _deferredElementUpdateValidations[validation] = journalIndex;
    _append(
      SparseTransactionWorkLedger.deferredValidation,
      journalIndex: journalIndex,
      subject: validation.update.element.id.value,
    );
  }

  void removeMissingRelationshipElementIds(
    bool Function(CanvasElementId id) isMissing,
  ) {
    _read(SparseTransactionWorkLedger.relationship);
    _resourceRelationshipElementIds.removeWhere(isMissing);
  }

  Iterable<CanvasElementId> readResourceRelationshipElementIds() {
    _read(SparseTransactionWorkLedger.relationship);
    return _resourceRelationshipElementIds;
  }

  void validateDeferredValidations() {
    for (final entry in _deferredElementUpdateValidations.entries) {
      final validation = entry.key;
      _read(
        SparseTransactionWorkLedger.deferredValidation,
        journalIndex: entry.value,
        subject: validation.update.element.id.value,
      );
      validation.validate();
    }
  }

  _SparseTouchedCommittedFacts readTouchedFacts() {
    _read(SparseTransactionWorkLedger.touched);
    return _touched;
  }

  _SparseAcceptedLayerCandidates readAcceptedLayerCandidates() {
    _read(SparseTransactionWorkLedger.layer);
    return _acceptedLayerCandidates;
  }

  StoreRevisionDelta readRequiredRevisionDelta() {
    _read(SparseTransactionWorkLedger.requiredDelta);
    return _requiredMutationDelta;
  }

  List<String> readAdmittedElementIds() =>
      _readAdmissionIds(_admittedElementIds);

  List<String> readAdmittedLayerIds() => _readAdmissionIds(_admittedLayerIds);

  List<String> readAdmittedResourceIds() =>
      _readAdmissionIds(_admittedResourceIds);

  // Sparse admission must remain exhaustive over the sealed mutation taxonomy.
  // ignore: cyclomatic-complexity
  void _recordAdmission(StoreSparseMutation mutation) {
    switch (mutation) {
      case StoreSparseEnsureLayer(:final id):
        _addAdmission(_admittedLayerIds, id.value);
      case StoreSparseRemoveEmptyLayer():
        break;
      case StoreSparseAddElement(:final element, :final layerId):
        _addAdmission(_admittedElementIds, element.id.value);
        if (layerId != null) {
          _addAdmission(_admittedLayerIds, layerId.value);
        }
      case StoreSparseUpsertResource(:final resource):
        _addAdmission(_admittedResourceIds, resource.id.value);
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

  void _addAdmission(Set<String> ids, String id) {
    if (ids.add(id)) {
      _append(SparseTransactionWorkLedger.admission, subject: id);
    }
  }

  void _recordRequiredMutationDelta(StoreRevisionDelta delta) {
    _requiredMutationDelta = _requiredMutationDelta.merge(delta);
    _append(SparseTransactionWorkLedger.requiredDelta);
  }

  List<String> _readAdmissionIds(Set<String> ids) {
    _read(SparseTransactionWorkLedger.admission);
    return List.unmodifiable(ids);
  }

  void _append(
    SparseTransactionWorkLedger ledger, {
    int? journalIndex,
    String? subject,
  }) {
    _record(
      phase: SparseTransactionWorkPhase.replay,
      kind: SparseTransactionWorkKind.ledgerAppend,
      ledger: ledger,
      journalIndex: journalIndex,
      subject: subject,
    );
  }

  void _read(
    SparseTransactionWorkLedger ledger, {
    int? journalIndex,
    String? subject,
  }) {
    _record(
      phase: SparseTransactionWorkPhase.finalization,
      kind: SparseTransactionWorkKind.ledgerRead,
      ledger: ledger,
      journalIndex: journalIndex,
      subject: subject,
    );
  }

  // Work events keep their optional attribution together so tests do not infer
  // phase or ledger facts from a private counter layout.
  // ignore: number-of-parameters
  void _record({
    required SparseTransactionWorkPhase phase,
    required SparseTransactionWorkKind kind,
    SparseTransactionWorkLedger? ledger,
    int? journalIndex,
    String? subject,
  }) {
    DocumentStoreKernel._recordSparseTransactionWork(
      SparseTransactionWorkEvent(
        phase: phase,
        kind: kind,
        ledger: ledger,
        journalIndex: journalIndex,
        subject: subject,
      ),
    );
  }
}

// Layer candidates intentionally mirror the sealed sparse taxonomy so no
// mutation family can bypass final base/candidate layer classification.
// ignore: coupling-between-object-classes
final class _SparseAcceptedLayerCandidates {
  final Set<CanvasLayerId> ensuredLayerIds = {};
  final Set<CanvasLayerId> removedLayerIds = {};
  final Set<CanvasElementId> indexedAddedElementIds = {};
  final Set<CanvasElementId> removedElementIds = {};
  bool clearedContent = false;

  // The exhaustive switch keeps every layer-relevant journal mutation visible.
  // The sealed mutation taxonomy keeps touched facts at the same owner as
  // replay, so a separate dispatcher would create duplicate classification.
  // ignore: cyclomatic-complexity, source-lines-of-code
  bool addMutation(StoreSparseMutation mutation) {
    switch (mutation) {
      case StoreSparseEnsureLayer(:final id):
        return ensuredLayerIds.add(id);
      case StoreSparseRemoveEmptyLayer(:final id):
        return removedLayerIds.add(id);
      case StoreSparseAddElement(
        :final element,
        :final index,
        :final background,
      ):
        return index != null &&
            !background &&
            indexedAddedElementIds.add(element.id);
      case StoreSparseRemoveElement(:final id):
        return removedElementIds.add(id);
      case StoreSparseClearContent():
        final wasCleared = clearedContent;
        clearedContent = true;
        return !wasCleared;
      case StoreSparseUpdateElement() ||
          StoreSparseUpsertResource() ||
          StoreSparseRemoveUnusedResource() ||
          StoreSparseSetBackground() ||
          StoreSparseSetCamera() ||
          StoreSparseSetPalette():
        return false;
    }
  }
}

// Sparse finalization records only candidate-touched rows and aggregate
// families so net no-op detection stays bounded to the sparse mutation input.
// ignore: coupling-between-object-classes
final class _SparseTouchedCommittedFacts {
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
  // new sparse mutation types are added; a second classifier would duplicate
  // replay ownership and risk divergent finalization facts.
  // ignore: cyclomatic-complexity, source-lines-of-code
  void addMutation(StoreSparseMutation mutation) {
    switch (mutation) {
      case StoreSparseEnsureLayer(:final id):
        touchedElementStructure = true;
        layerIds.add(id);
      case StoreSparseRemoveEmptyLayer(:final id):
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
    required this.didMutateFacts,
    required this.requiredRevisionDelta,
  });

  factory _SparseMutationResult.changed({
    required StoreRevisionDelta requiredRevisionDelta,
  }) {
    return _SparseMutationResult(
      didMutateFacts: true,
      requiredRevisionDelta: requiredRevisionDelta,
    );
  }

  factory _SparseMutationResult.unchanged() {
    return const _SparseMutationResult(
      didMutateFacts: false,
      requiredRevisionDelta: StoreRevisionDelta(),
    );
  }

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

final class _AffectedElementProjectionTestScope {
  const _AffectedElementProjectionTestScope({this.failure, this.observer});

  final Error? failure;
  final void Function(StoreAffectedElementProjection projection)? observer;

  _AffectedElementProjectionTestScope withFailure(Error nextFailure) =>
      _AffectedElementProjectionTestScope(
        failure: nextFailure,
        observer: observer,
      );

  _AffectedElementProjectionTestScope withObserver(
    void Function(StoreAffectedElementProjection projection) nextObserver,
  ) {
    final inherited = observer;
    return _AffectedElementProjectionTestScope(
      failure: failure,
      observer: inherited == null
          ? nextObserver
          : (projection) {
              inherited(projection);
              nextObserver(projection);
            },
    );
  }
}
