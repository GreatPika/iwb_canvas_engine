import 'package:iwb_canvas_engine/iwb_canvas_engine.dart'
    show CanvasElementKind;
import 'package:iwb_canvas_engine/src/store/family_tables.dart';

// This test-owned fold preserves every admitted semantic work signal without
// giving production telemetry an accumulator, history, or query API.
// ignore: number-of-methods, response-for-class, weighted-methods-per-class
final class FamilyTablesTelemetry {
  int _mapProbeCount = 0;
  int _membershipUnionAllocationCount = 0;
  int _membershipKeyCopyCount = 0;
  int _retainedMembershipCopyAllocationCount = 0;
  int _batchReplacementCount = 0;
  final Map<CanvasElementKind, int> _transactionOpenCountByFamily = {};
  final Map<CanvasElementKind, int> _transactionBaseEntryCopyCountByFamily = {};
  final Map<CanvasElementKind, int> _transactionFreezeCountByFamily = {};
  final Map<CanvasElementKind, int> _transactionNormalizationWriteCount = {};
  final Map<CanvasElementKind, bool>
  _transactionFinalMapRetainsBaseIdentityByFamily = {};
  int _transactionDiscardCount = 0;
  int _transactionImmutablePublicationCount = 0;
  int _transactionIntermediateImmutablePublicationCount = 0;
  int _staleDecisionReadCount = 0;
  int _postFreezeWriteCount = 0;
  int _postFreezeCopyCount = 0;
  int _postFreezeNormalizationCount = 0;
  int _postFreezeImmutablePublicationCount = 0;
  int _referenceConstructionRowVisitCount = 0;
  int _referenceCommittedSummaryReadCount = 0;
  int _referenceEditorBaseSummaryReadCount = 0;
  int _referenceEditorDeltaReadCount = 0;
  int _referenceEditorMaximumDeltaDepth = 0;
  int _referenceQueryFamilyRowVisitCount = 0;
  int _imageReferenceSummaryDeltaOpenCount = 0;
  int _vectorReferenceSummaryDeltaOpenCount = 0;
  int _imageReferenceAffectedIdUpdateCount = 0;
  int _vectorReferenceAffectedIdUpdateCount = 0;
  int _imageReferenceSummaryCompleteCopyCount = 0;
  int _vectorReferenceSummaryCompleteCopyCount = 0;
  int _imageReferenceSummaryMaterializationCount = 0;
  int _vectorReferenceSummaryMaterializationCount = 0;
  int _imageReferenceSummaryPublicationCount = 0;
  int _vectorReferenceSummaryPublicationCount = 0;
  bool _imageReferenceSummaryRetainsBaseIdentity = false;
  bool _vectorReferenceSummaryRetainsBaseIdentity = false;
  int _enumerationOpenCount = 0;
  int _enumerationCloseCount = 0;
  final Map<CanvasElementKind, int> _enumerationEntryCountByFamily = {};
  final List<FamilyTablesDecision> _editorDecisionTrace = [];
  final List<FamilyTablesDecisionRead> _editorDecisionReads = [];
  final Map<FamilyTablesDecision, int> _editorDecisionCount = {};
  final Map<FamilyTablesDecision, int> _staleDecisionReadCountByDecision = {};

  int get mapProbeCount => _mapProbeCount;
  int get membershipUnionAllocationCount => _membershipUnionAllocationCount;
  int get membershipKeyCopyCount => _membershipKeyCopyCount;
  int get retainedMembershipCopyAllocationCount =>
      _retainedMembershipCopyAllocationCount;
  int get batchReplacementCount => _batchReplacementCount;
  int get transactionDiscardCount => _transactionDiscardCount;
  int get transactionImmutablePublicationCount =>
      _transactionImmutablePublicationCount;
  int get transactionIntermediateImmutablePublicationCount =>
      _transactionIntermediateImmutablePublicationCount;
  int get staleDecisionReadCount => _staleDecisionReadCount;
  int get postFreezeWriteCount => _postFreezeWriteCount;
  int get postFreezeCopyCount => _postFreezeCopyCount;
  int get postFreezeNormalizationCount => _postFreezeNormalizationCount;
  int get postFreezeImmutablePublicationCount =>
      _postFreezeImmutablePublicationCount;
  int get referenceQueryFamilyRowVisitCount =>
      _referenceQueryFamilyRowVisitCount;
  int get referenceConstructionRowVisitCount =>
      _referenceConstructionRowVisitCount;
  int get referenceCommittedSummaryReadCount =>
      _referenceCommittedSummaryReadCount;
  int get referenceEditorBaseSummaryReadCount =>
      _referenceEditorBaseSummaryReadCount;
  int get referenceEditorDeltaReadCount => _referenceEditorDeltaReadCount;
  int get referenceEditorMaximumDeltaDepth => _referenceEditorMaximumDeltaDepth;
  int get imageReferenceSummaryDeltaOpenCount =>
      _imageReferenceSummaryDeltaOpenCount;
  int get vectorReferenceSummaryDeltaOpenCount =>
      _vectorReferenceSummaryDeltaOpenCount;
  int get imageReferenceAffectedIdUpdateCount =>
      _imageReferenceAffectedIdUpdateCount;
  int get vectorReferenceAffectedIdUpdateCount =>
      _vectorReferenceAffectedIdUpdateCount;
  int get imageReferenceSummaryCompleteCopyCount =>
      _imageReferenceSummaryCompleteCopyCount;
  int get vectorReferenceSummaryCompleteCopyCount =>
      _vectorReferenceSummaryCompleteCopyCount;
  int get imageReferenceSummaryMaterializationCount =>
      _imageReferenceSummaryMaterializationCount;
  int get vectorReferenceSummaryMaterializationCount =>
      _vectorReferenceSummaryMaterializationCount;
  int get imageReferenceSummaryPublicationCount =>
      _imageReferenceSummaryPublicationCount;
  int get vectorReferenceSummaryPublicationCount =>
      _vectorReferenceSummaryPublicationCount;
  bool get imageReferenceSummaryRetainsBaseIdentity =>
      _imageReferenceSummaryRetainsBaseIdentity;
  bool get vectorReferenceSummaryRetainsBaseIdentity =>
      _vectorReferenceSummaryRetainsBaseIdentity;
  int get enumerationOpenCount => _enumerationOpenCount;
  int get enumerationCloseCount => _enumerationCloseCount;
  List<FamilyTablesDecision> get editorDecisionTrace =>
      List.unmodifiable(_editorDecisionTrace);
  List<FamilyTablesDecisionRead> get editorDecisionReads =>
      List.unmodifiable(_editorDecisionReads);

  int transactionOpenCount(CanvasElementKind kind) {
    return _transactionOpenCountByFamily[kind] ?? 0;
  }

  int transactionBaseEntryCopyCount(CanvasElementKind kind) {
    return _transactionBaseEntryCopyCountByFamily[kind] ?? 0;
  }

  int transactionFreezeCount(CanvasElementKind kind) {
    return _transactionFreezeCountByFamily[kind] ?? 0;
  }

  int transactionNormalizationWriteCount(CanvasElementKind kind) {
    return _transactionNormalizationWriteCount[kind] ?? 0;
  }

  bool transactionFinalMapRetainsBaseIdentity(CanvasElementKind kind) {
    return _transactionFinalMapRetainsBaseIdentityByFamily[kind] ?? false;
  }

  int editorDecisionCount(FamilyTablesDecision decision) {
    return _editorDecisionCount[decision] ?? 0;
  }

  int staleDecisionReadCountFor(FamilyTablesDecision decision) {
    return _staleDecisionReadCountByDecision[decision] ?? 0;
  }

  int enumerationEntryCount(CanvasElementKind kind) {
    return _enumerationEntryCountByFamily[kind] ?? 0;
  }

  // One explicit fold preserves the admitted telemetry query surface; splitting
  // event kinds would duplicate counter ownership across test helpers.
  // ignore: cyclomatic-complexity, halstead-volume, source-lines-of-code, maintainability-index
  void record(FamilyTablesTelemetryEvent event) {
    switch (event.kind) {
      case FamilyTablesTelemetryKind.membershipMapProbe:
        _mapProbeCount += 1;
      case FamilyTablesTelemetryKind.membershipUnionAllocation:
        _membershipUnionAllocationCount += 1;
      case FamilyTablesTelemetryKind.membershipKeyCopy:
        _membershipKeyCopyCount += 1;
      case FamilyTablesTelemetryKind.retainedMembershipCopyAllocation:
        _retainedMembershipCopyAllocationCount += 1;
      case FamilyTablesTelemetryKind.batchReplacement:
        _batchReplacementCount += 1;
      case FamilyTablesTelemetryKind.transactionFamilyOpen:
        _incrementFamily(_transactionOpenCountByFamily, event.family);
      case FamilyTablesTelemetryKind.transactionFamilyBaseEntryCopies:
        _incrementFamily(
          _transactionBaseEntryCopyCountByFamily,
          event.family,
          event.count,
        );
      case FamilyTablesTelemetryKind.transactionFamilyFreeze:
        _incrementFamily(_transactionFreezeCountByFamily, event.family);
      case FamilyTablesTelemetryKind.transactionNormalizationWrite:
        _incrementFamily(_transactionNormalizationWriteCount, event.family);
      case FamilyTablesTelemetryKind.transactionFinalMapIdentity:
        _transactionFinalMapRetainsBaseIdentityByFamily[_requireFamily(event)] =
            _requireIdentityRetained(event);
      case FamilyTablesTelemetryKind.transactionDiscard:
        _transactionDiscardCount += 1;
      case FamilyTablesTelemetryKind.transactionImmutablePublication:
        _transactionImmutablePublicationCount += 1;
      case FamilyTablesTelemetryKind
          .transactionIntermediateImmutablePublication:
        _transactionImmutablePublicationCount += 1;
        _transactionIntermediateImmutablePublicationCount += 1;
      case FamilyTablesTelemetryKind.staleDecisionRead:
        _staleDecisionReadCount += 1;
        final decision = event.decision;
        if (decision != null) {
          _editorDecisionCountBy(_staleDecisionReadCountByDecision, decision);
        }
      case FamilyTablesTelemetryKind.postFreezeWrite:
        _postFreezeWriteCount += 1;
      case FamilyTablesTelemetryKind.postFreezeCopy:
        _postFreezeCopyCount += 1;
      case FamilyTablesTelemetryKind.postFreezeNormalization:
        _postFreezeNormalizationCount += 1;
      case FamilyTablesTelemetryKind.postFreezeImmutablePublication:
        _postFreezeImmutablePublicationCount += 1;
      case FamilyTablesTelemetryKind.referenceConstructionRowVisit:
        _referenceConstructionRowVisitCount += 1;
      case FamilyTablesTelemetryKind.referenceCommittedSummaryRead:
        _referenceCommittedSummaryReadCount += 1;
      case FamilyTablesTelemetryKind.referenceQueryFamilyRowVisits:
        _referenceQueryFamilyRowVisitCount += _requireCount(event);
      case FamilyTablesTelemetryKind.referenceEditorBaseSummaryRead:
        _referenceEditorBaseSummaryReadCount += 1;
      case FamilyTablesTelemetryKind.referenceEditorDeltaRead:
        _referenceEditorDeltaReadCount += 1;
        final depth = _requireCount(event);
        _referenceEditorMaximumDeltaDepth =
            _referenceEditorMaximumDeltaDepth > depth
            ? _referenceEditorMaximumDeltaDepth
            : depth;
      case FamilyTablesTelemetryKind.referenceSummaryDeltaOpen:
        _incrementSplitDeltaOpen(event.resourceSplit);
      case FamilyTablesTelemetryKind.referenceAffectedIdUpdate:
        _incrementSplitAffectedId(event.resourceSplit);
      case FamilyTablesTelemetryKind.referenceSummaryCompleteCopy:
        _incrementSplitCompleteCopy(event.resourceSplit);
      case FamilyTablesTelemetryKind.referenceSummaryMaterialization:
        _incrementSplitMaterialization(event.resourceSplit);
      case FamilyTablesTelemetryKind.referenceSummaryPublication:
        _incrementSplitPublication(event.resourceSplit);
      case FamilyTablesTelemetryKind.referenceSummaryIdentity:
        final identityRetained = _requireIdentityRetained(event);
        if (event.resourceSplit == FamilyTablesResourceSplit.image) {
          _imageReferenceSummaryRetainsBaseIdentity = identityRetained;
        } else {
          _vectorReferenceSummaryRetainsBaseIdentity = identityRetained;
        }
      case FamilyTablesTelemetryKind.editorDecision:
        final decision = _requireDecision(event);
        _editorDecisionTrace.add(decision);
        _editorDecisionCountBy(_editorDecisionCount, decision);
      case FamilyTablesTelemetryKind.editorDecisionRead:
        _editorDecisionReads.add(
          FamilyTablesDecisionRead(
            decision: _requireDecision(event),
            subjectKind: _requireSubjectKind(event),
            subject: _requireSubject(event),
            result: _requireResult(event),
          ),
        );
      case FamilyTablesTelemetryKind.enumerationOpen:
        _enumerationOpenCount += 1;
      case FamilyTablesTelemetryKind.enumerationEntry:
        _incrementFamily(_enumerationEntryCountByFamily, event.family);
      case FamilyTablesTelemetryKind.enumerationClose:
        _enumerationCloseCount += 1;
    }
  }

  void _incrementFamily(
    Map<CanvasElementKind, int> counts,
    CanvasElementKind? family, [
    int? amount,
  ]) {
    final currentFamily =
        family ??
        (throw StateError('Family telemetry event requires a family.'));
    counts.update(
      currentFamily,
      (current) => current + (amount ?? 1),
      ifAbsent: () => amount ?? 1,
    );
  }

  void _editorDecisionCountBy(
    Map<FamilyTablesDecision, int> counts,
    FamilyTablesDecision decision,
  ) {
    counts.update(decision, (count) => count + 1, ifAbsent: () => 1);
  }

  void _incrementSplitDeltaOpen(FamilyTablesResourceSplit? split) {
    if (_requireResourceSplit(split) == FamilyTablesResourceSplit.image) {
      _imageReferenceSummaryDeltaOpenCount += 1;
    } else {
      _vectorReferenceSummaryDeltaOpenCount += 1;
    }
  }

  void _incrementSplitAffectedId(FamilyTablesResourceSplit? split) {
    if (_requireResourceSplit(split) == FamilyTablesResourceSplit.image) {
      _imageReferenceAffectedIdUpdateCount += 1;
    } else {
      _vectorReferenceAffectedIdUpdateCount += 1;
    }
  }

  void _incrementSplitCompleteCopy(FamilyTablesResourceSplit? split) {
    if (_requireResourceSplit(split) == FamilyTablesResourceSplit.image) {
      _imageReferenceSummaryCompleteCopyCount += 1;
    } else {
      _vectorReferenceSummaryCompleteCopyCount += 1;
    }
  }

  void _incrementSplitMaterialization(FamilyTablesResourceSplit? split) {
    if (_requireResourceSplit(split) == FamilyTablesResourceSplit.image) {
      _imageReferenceSummaryMaterializationCount += 1;
    } else {
      _vectorReferenceSummaryMaterializationCount += 1;
    }
  }

  void _incrementSplitPublication(FamilyTablesResourceSplit? split) {
    if (_requireResourceSplit(split) == FamilyTablesResourceSplit.image) {
      _imageReferenceSummaryPublicationCount += 1;
    } else {
      _vectorReferenceSummaryPublicationCount += 1;
    }
  }

  CanvasElementKind _requireFamily(FamilyTablesTelemetryEvent event) {
    return event.family ??
        (throw StateError('Family telemetry event requires a family.'));
  }

  int _requireCount(FamilyTablesTelemetryEvent event) {
    return event.count ??
        (throw StateError('Family telemetry event requires a count.'));
  }

  bool _requireIdentityRetained(FamilyTablesTelemetryEvent event) {
    return event.identityRetained ??
        (throw StateError('Family telemetry event requires an identity fact.'));
  }

  FamilyTablesDecision _requireDecision(FamilyTablesTelemetryEvent event) {
    return event.decision ??
        (throw StateError('Family telemetry event requires a decision.'));
  }

  FamilyTablesDecisionSubjectKind _requireSubjectKind(
    FamilyTablesTelemetryEvent event,
  ) {
    return event.subjectKind ??
        (throw StateError('Family telemetry event requires a subject kind.'));
  }

  String _requireSubject(FamilyTablesTelemetryEvent event) {
    return event.subject ??
        (throw StateError('Family telemetry event requires a subject.'));
  }

  FamilyTablesDecisionResult _requireResult(FamilyTablesTelemetryEvent event) {
    return event.result ??
        (throw StateError('Family telemetry event requires a result.'));
  }

  FamilyTablesResourceSplit _requireResourceSplit(
    FamilyTablesResourceSplit? split,
  ) {
    return split ??
        (throw StateError('Family telemetry event requires a resource split.'));
  }
}
