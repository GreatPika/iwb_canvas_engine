import 'dart:async';
import 'dart:collection';
import 'dart:ui';

import 'package:flutter/foundation.dart' show immutable, visibleForTesting;

// Family-specific row tables stay together so admission and projection cannot
// drift across element kinds; splitting them would obscure the shared id owner.

import '../contracts/internal/schema_v1_import_events.dart';
import '../contracts/public/canvas_element.dart';
import '../contracts/public/canvas_errors.dart';
import '../contracts/public/canvas_geometry.dart';
import '../contracts/public/canvas_ids.dart';
import '../contracts/public/canvas_metadata.dart';

@visibleForTesting
enum FamilyTablesTelemetryKind {
  membershipMapProbe,
  batchReplacement,
  transactionFamilyOpen,
  transactionFamilyBaseEntryCopies,
  transactionFamilyFreeze,
  transactionNormalizationWrite,
  transactionFinalMapIdentity,
  transactionDiscard,
  transactionImmutablePublication,
  transactionIntermediateImmutablePublication,
  staleDecisionRead,
  postFreezeWrite,
  postFreezeCopy,
  postFreezeNormalization,
  postFreezeImmutablePublication,
  referenceConstructionRowVisit,
  referenceCommittedSummaryRead,
  referenceQueryFamilyRowVisits,
  referenceEditorBaseSummaryRead,
  referenceEditorDeltaRead,
  referenceSummaryDeltaOpen,
  referenceAffectedIdUpdate,
  referenceSummaryCompleteCopy,
  referenceSummaryMaterialization,
  referenceSummaryPublication,
  referenceSummaryIdentity,
  editorDecisionRead,
  editorCurrentRowRead,
  enumerationOpen,
  enumerationEntry,
  enumerationClose,
}

@visibleForTesting
enum FamilyTablesResourceSplit { image, vector }

@visibleForTesting
@immutable
final class FamilyTablesTelemetryEvent {
  const FamilyTablesTelemetryEvent(
    this.kind, {
    this.family,
    this.decision,
    this.subjectKind,
    this.subject,
    this.result,
    this.resourceSplit,
    this.count,
    this.identityRetained,
  });

  final FamilyTablesTelemetryKind kind;
  final CanvasElementKind? family;
  final FamilyTablesDecision? decision;
  final FamilyTablesDecisionSubjectKind? subjectKind;
  final String? subject;
  final FamilyTablesDecisionResult? result;
  final FamilyTablesResourceSplit? resourceSplit;
  final int? count;
  final bool? identityRetained;
}

@visibleForTesting
typedef FamilyTablesTelemetrySink =
    void Function(FamilyTablesTelemetryEvent event);

// The family tables are the single admission and projection owner for all
// element kinds; splitting by kind would reintroduce cross-table drift.
// Sparse row mutation belongs with family admission so updates cannot drift
// from duplicate-id and resource-reference validation.
// ignore: coupling-between-object-classes, number-of-methods, response-for-class, weighted-methods-per-class
final class FamilyTables {
  static final Object _telemetryZoneKey = Object();
  static final Object _sparseEditorZoneKey = Object();
  static final Object _sparseDecisionZoneKey = Object();
  static final Object _sparseBaseReadZoneKey = Object();
  static final bool _debugTelemetryEnabled = _assertionsEnabled();

  static bool _assertionsEnabled() {
    var enabled = false;
    assert(() {
      enabled = true;
      return true;
    }(), 'assertion-mode detection failed');
    return enabled;
  }

  const FamilyTables.empty()
    : this._fromTables(
        imageRows: const {},
        vectorRows: const {},
        pathRows: const {},
        textRows: const {},
        strokeRows: const {},
        lineRows: const {},
        rectRows: const {},
        imageResourceReferenceCounts: const {},
        vectorResourceReferenceCounts: const {},
      );

  FamilyTables(Iterable<CanvasElement> elements)
    : this._(_admitElements(elements));

  FamilyTables.fromSchemaV1Import(Iterable<SchemaV1ElementImportEvent> elements)
    : this._(_admitSchemaV1Elements(elements));

  FamilyTables._(_AdmittedRows admitted)
    : this._fromTables(
        imageRows: Map.unmodifiable(admitted.imageRows),
        vectorRows: Map.unmodifiable(admitted.vectorRows),
        pathRows: Map.unmodifiable(admitted.pathRows),
        textRows: Map.unmodifiable(admitted.textRows),
        strokeRows: Map.unmodifiable(admitted.strokeRows),
        lineRows: Map.unmodifiable(admitted.lineRows),
        rectRows: Map.unmodifiable(admitted.rectRows),
        imageResourceReferenceCounts: Map.unmodifiable(
          admitted.imageResourceReferenceCounts,
        ),
        vectorResourceReferenceCounts: Map.unmodifiable(
          admitted.vectorResourceReferenceCounts,
        ),
      );

  FamilyTables._owned(_AdmittedRows admitted)
    : this._fromTables(
        imageRows: UnmodifiableMapView(admitted.imageRows),
        vectorRows: UnmodifiableMapView(admitted.vectorRows),
        pathRows: UnmodifiableMapView(admitted.pathRows),
        textRows: UnmodifiableMapView(admitted.textRows),
        strokeRows: UnmodifiableMapView(admitted.strokeRows),
        lineRows: UnmodifiableMapView(admitted.lineRows),
        rectRows: UnmodifiableMapView(admitted.rectRows),
        imageResourceReferenceCounts: UnmodifiableMapView(
          admitted.imageResourceReferenceCounts,
        ),
        vectorResourceReferenceCounts: UnmodifiableMapView(
          admitted.vectorResourceReferenceCounts,
        ),
      );

  const FamilyTables._fromTables({
    required this.imageRows,
    required this.vectorRows,
    required this.pathRows,
    required this.textRows,
    required this.strokeRows,
    required this.lineRows,
    required this.rectRows,
    required this.imageResourceReferenceCounts,
    required this.vectorResourceReferenceCounts,
  });

  final Map<String, ImageRow> imageRows;
  final Map<String, VectorRow> vectorRows;
  final Map<String, PathRow> pathRows;
  final Map<String, TextRow> textRows;
  final Map<String, StrokeRow> strokeRows;
  final Map<String, LineRow> lineRows;
  final Map<String, RectRow> rectRows;
  final Map<CanvasResourceId, int> imageResourceReferenceCounts;
  final Map<CanvasResourceId, int> vectorResourceReferenceCounts;

  // Complete-id consumers receive each authoritative key immediately, keeping
  // the seven family maps as the only committed element-id source.
  // Keeping ordered family traversal and its exact events together prevents
  // an admission route from drifting from the owner sequence.
  // ignore: source-lines-of-code
  void enumerateElementIds(void Function(String) accept) {
    _emitTelemetry(
      const FamilyTablesTelemetryEvent(
        FamilyTablesTelemetryKind.enumerationOpen,
      ),
    );
    try {
      for (final id in imageRows.keys) {
        _recordEnumerationEntry(CanvasElementKind.image);
        accept(id);
      }
      for (final id in vectorRows.keys) {
        _recordEnumerationEntry(CanvasElementKind.vector);
        accept(id);
      }
      for (final id in pathRows.keys) {
        _recordEnumerationEntry(CanvasElementKind.path);
        accept(id);
      }
      for (final id in textRows.keys) {
        _recordEnumerationEntry(CanvasElementKind.text);
        accept(id);
      }
      for (final id in strokeRows.keys) {
        _recordEnumerationEntry(CanvasElementKind.stroke);
        accept(id);
      }
      for (final id in lineRows.keys) {
        _recordEnumerationEntry(CanvasElementKind.line);
        accept(id);
      }
      for (final id in rectRows.keys) {
        _recordEnumerationEntry(CanvasElementKind.rect);
        accept(id);
      }
    } finally {
      _emitTelemetry(
        const FamilyTablesTelemetryEvent(
          FamilyTablesTelemetryKind.enumerationClose,
        ),
      );
    }
  }

  // Tests own all accumulation. Production only relays local semantic events
  // through this one assert-gated sink and retains no history or counters.
  @visibleForTesting
  static T observeTelemetry<T>(
    FamilyTablesTelemetrySink sink,
    T Function() operation,
  ) {
    return runZoned(operation, zoneValues: {_telemetryZoneKey: sink});
  }

  // Membership is an owner-local read: a direct probe avoids constructing a
  // document-sized key union for callers that only need one id.
  // ignore: cyclomatic-complexity
  bool contains(CanvasElementId id) {
    _recordImmutableSparseFamilyRead(this);
    final value = id.value;
    _recordMembershipMapProbe();
    if (imageRows.containsKey(value)) {
      return true;
    }
    _recordMembershipMapProbe();
    if (vectorRows.containsKey(value)) {
      return true;
    }
    _recordMembershipMapProbe();
    if (pathRows.containsKey(value)) {
      return true;
    }
    _recordMembershipMapProbe();
    if (textRows.containsKey(value)) {
      return true;
    }
    _recordMembershipMapProbe();
    if (strokeRows.containsKey(value)) {
      return true;
    }
    _recordMembershipMapProbe();
    if (lineRows.containsKey(value)) {
      return true;
    }
    _recordMembershipMapProbe();

    return rectRows.containsKey(value);
  }

  // Sparse base/final comparisons intentionally read the immutable base while
  // the editor is live. Marking that role prevents those explicit comparisons
  // from masking a candidate read that bypasses the editor.
  static T readSparseBase<T>(T Function() operation) {
    if (!_debugTelemetryEnabled) {
      return operation();
    }
    return runZoned(operation, zoneValues: {_sparseBaseReadZoneKey: true});
  }

  T editSparse<T>(T Function(FamilyTablesEditor editor) operation) {
    final editor = FamilyTablesEditor._(this);
    T execute() {
      try {
        final result = operation(editor);
        editor.discard();

        return result;
      } catch (_) {
        editor.discard();
        rethrow;
      }
    }

    if (!_debugTelemetryEnabled) {
      return execute();
    }
    return runZoned(execute, zoneValues: {_sparseEditorZoneKey: editor});
  }

  static void _recordImmutableSparseFamilyRead(FamilyTables tables) {
    assert(() {
      final editor = Zone.current[_sparseEditorZoneKey];
      if (editor is FamilyTablesEditor &&
          identical(editor._base, tables) &&
          Zone.current[_sparseBaseReadZoneKey] != true) {
        _emitTelemetry(
          const FamilyTablesTelemetryEvent(
            FamilyTablesTelemetryKind.staleDecisionRead,
          ),
        );
      }
      return true;
    }(), 'stale sparse family read observation failed');
  }

  // Any immutable family operation while the transaction editor has already
  // frozen is a second snapshot lifecycle. The normal editor adoption is
  // allowed exactly once and is checked separately below.
  static void recordSparseFamilySnapshotMutation() {
    assert(() {
      final editor = Zone.current[_sparseEditorZoneKey];
      if (editor is FamilyTablesEditor) {
        if (editor._isFrozen) {
          _emitTelemetry(
            const FamilyTablesTelemetryEvent(
              FamilyTablesTelemetryKind.postFreezeWrite,
            ),
          );
          _emitTelemetry(
            const FamilyTablesTelemetryEvent(
              FamilyTablesTelemetryKind.postFreezeCopy,
            ),
          );
          _emitTelemetry(
            const FamilyTablesTelemetryEvent(
              FamilyTablesTelemetryKind.postFreezeImmutablePublication,
            ),
          );
        } else {
          _emitTelemetry(
            const FamilyTablesTelemetryEvent(
              FamilyTablesTelemetryKind
                  .transactionIntermediateImmutablePublication,
            ),
          );
        }
      }
      return true;
    }(), 'post-freeze sparse family mutation observation failed');
  }

  static void recordSparseFamilyAdoption(FamilyTables tables) {
    assert(() {
      final editor = Zone.current[_sparseEditorZoneKey];
      if (editor is FamilyTablesEditor &&
          !editor._consumeFrozenAdoption(tables)) {
        if (editor._isFrozen) {
          _emitTelemetry(
            const FamilyTablesTelemetryEvent(
              FamilyTablesTelemetryKind.postFreezeImmutablePublication,
            ),
          );
        } else {
          _emitTelemetry(
            const FamilyTablesTelemetryEvent(
              FamilyTablesTelemetryKind
                  .transactionIntermediateImmutablePublication,
            ),
          );
        }
      }
      return true;
    }(), 'sparse family adoption observation failed');
  }

  bool referencesResource(CanvasResourceId id) {
    _recordImmutableSparseFamilyRead(this);
    _recordReferenceQueryFamilyRowVisits(0);
    return imageResourceReferenceCount(id) + vectorResourceReferenceCount(id) >
        0;
  }

  @visibleForTesting
  int imageResourceReferenceCount(CanvasResourceId id) {
    _recordReferenceCommittedSummaryRead();

    return imageResourceReferenceCounts[id] ?? 0;
  }

  @visibleForTesting
  int vectorResourceReferenceCount(CanvasResourceId id) {
    _recordReferenceCommittedSummaryRead();

    return vectorResourceReferenceCounts[id] ?? 0;
  }

  // Family lookup stays explicit so projection, sparse updates, and frame facts
  // all preserve the same family precedence in one audited place.
  // ignore: cyclomatic-complexity
  CanvasElement? elementByCanvasId(CanvasElementId id) {
    _recordImmutableSparseFamilyRead(this);
    final value = id.value;

    return imageRows[value]?.toElement() ??
        vectorRows[value]?.toElement() ??
        pathRows[value]?.toElement() ??
        textRows[value]?.toElement() ??
        strokeRows[value]?.toElement() ??
        lineRows[value]?.toElement() ??
        rectRows[value]?.toElement();
  }

  FamilyTables addElement(CanvasElement element) {
    recordSparseFamilySnapshotMutation();
    if (_commonById(element.id.value) != null) {
      throw CanvasDataException(
        code: CanvasDataErrorCode.duplicateElementId,
        message: 'duplicate element id.',
        path: 'elements.id',
      );
    }
    return _withSameFamilyElement(element);
  }

  FamilyTables removeElement(CanvasElementId id) {
    recordSparseFamilySnapshotMutation();
    final admitted = _copyRows()..remove(id.value);

    return FamilyTables._(admitted);
  }

  FamilyTables clearElements() {
    recordSparseFamilySnapshotMutation();
    return FamilyTables._(_AdmittedRows());
  }

  // The lookup deliberately checks every family table in one place so missing
  // ids fail at the caller-owned admission boundary.
  // ignore: cyclomatic-complexity
  CanvasElement elementById(String id) {
    _recordImmutableSparseFamilyRead(this);
    return imageRows[id]?.toElement() ??
        vectorRows[id]?.toElement() ??
        pathRows[id]?.toElement() ??
        textRows[id]?.toElement() ??
        strokeRows[id]?.toElement() ??
        lineRows[id]?.toElement() ??
        rectRows[id]!.toElement();
  }

  bool isSelectionEligible(CanvasElementId id) {
    _recordImmutableSparseFamilyRead(this);
    final common = _commonById(id.value);

    return common != null && common.isVisible && common.isSelectable;
  }

  // Frame fact lookup has to preserve the same family ordering as admission and
  // projection to avoid divergent element-kind behavior.
  // ignore: cyclomatic-complexity
  FamilyElementFacts? elementFrameFacts(CanvasElementId id) {
    _recordImmutableSparseFamilyRead(this);
    final value = id.value;

    return _imageFrameFacts(value) ??
        _vectorFrameFacts(value) ??
        _commonFrameFacts(pathRows[value]?.common, CanvasElementKind.path) ??
        _commonFrameFacts(textRows[value]?.common, CanvasElementKind.text) ??
        _commonFrameFacts(
          strokeRows[value]?.common,
          CanvasElementKind.stroke,
        ) ??
        _commonFrameFacts(lineRows[value]?.common, CanvasElementKind.line) ??
        _commonFrameFacts(rectRows[value]?.common, CanvasElementKind.rect);
  }

  FamilyElementFacts? _imageFrameFacts(String id) {
    final row = imageRows[id];
    if (row == null) {
      return null;
    }

    return _commonFrameFacts(
      row.common,
      CanvasElementKind.image,
      resourceId: row.resourceId,
    );
  }

  FamilyElementFacts? _vectorFrameFacts(String id) {
    final row = vectorRows[id];
    if (row == null) {
      return null;
    }

    return _commonFrameFacts(
      row.common,
      CanvasElementKind.vector,
      resourceId: row.resourceId,
    );
  }

  // This is the single element-family materialization point; extracting per
  // field would duplicate table lookup rules and hide kind-specific fallbacks.
  // ignore: cyclomatic-complexity, halstead-volume, source-lines-of-code, maintainability-index
  FamilyElementFacts? _commonFrameFacts(
    ElementCommonRow? common,
    CanvasElementKind kind, {
    CanvasResourceId? resourceId,
  }) {
    if (common == null) {
      return null;
    }

    return FamilyElementFacts(
      id: common.id,
      kind: kind,
      revision: common.revision,
      generation: 0,
      transform: common.transform,
      opacity: common.opacity,
      hitPadding: common.hitPadding,
      isVisible: common.isVisible,
      isSelectable: common.isSelectable,
      isLocked: common.isLocked,
      isDeletable: common.isDeletable,
      isTransformable: common.isTransformable,
      metadata: common.metadata,
      resourceId: resourceId,
      size: switch (kind) {
        CanvasElementKind.image => imageRows[common.id.value]?.size,
        CanvasElementKind.vector => vectorRows[common.id.value]?.size,
        CanvasElementKind.rect => rectRows[common.id.value]?.size,
        _ => null,
      },
      naturalSize:
          imageRows[common.id.value]?.naturalSize ??
          vectorRows[common.id.value]?.naturalSize,
      svgPathData: pathRows[common.id.value]?.svgPathData,
      fillColor:
          pathRows[common.id.value]?.fillColor ??
          rectRows[common.id.value]?.fillColor,
      strokeColor:
          pathRows[common.id.value]?.strokeColor ??
          rectRows[common.id.value]?.strokeColor,
      strokeWidth:
          pathRows[common.id.value]?.strokeWidth ??
          rectRows[common.id.value]?.strokeWidth,
      fillRule: pathRows[common.id.value]?.fillRule,
      text: textRows[common.id.value]?.text,
      fontSize: textRows[common.id.value]?.fontSize,
      textColor: textRows[common.id.value]?.color,
      textAlign: textRows[common.id.value]?.align,
      textDirection: textRows[common.id.value]?.textDirection,
      isBold: textRows[common.id.value]?.isBold,
      isItalic: textRows[common.id.value]?.isItalic,
      isUnderline: textRows[common.id.value]?.isUnderline,
      fontFamily: textRows[common.id.value]?.fontFamily,
      maxWidth: textRows[common.id.value]?.maxWidth,
      lineHeight: textRows[common.id.value]?.lineHeight,
      points: strokeRows[common.id.value]?.points,
      start: lineRows[common.id.value]?.start,
      end: lineRows[common.id.value]?.end,
      color:
          strokeRows[common.id.value]?.color ??
          lineRows[common.id.value]?.color,
      thickness:
          strokeRows[common.id.value]?.thickness ??
          lineRows[common.id.value]?.thickness,
    );
  }

  // Common-row lookup mirrors the admitted family order in one explicit list.
  // ignore: cyclomatic-complexity
  ElementCommonRow? _commonById(String id) {
    return imageRows[id]?.common ??
        vectorRows[id]?.common ??
        pathRows[id]?.common ??
        textRows[id]?.common ??
        strokeRows[id]?.common ??
        lineRows[id]?.common ??
        rectRows[id]?.common;
  }

  static void _recordMembershipMapProbe() {
    _emitTelemetry(
      const FamilyTablesTelemetryEvent(
        FamilyTablesTelemetryKind.membershipMapProbe,
      ),
    );
  }

  static void _recordReferenceConstructionRowVisit() {
    _emitTelemetry(
      const FamilyTablesTelemetryEvent(
        FamilyTablesTelemetryKind.referenceConstructionRowVisit,
      ),
    );
  }

  static void _recordReferenceCommittedSummaryRead() {
    _emitTelemetry(
      const FamilyTablesTelemetryEvent(
        FamilyTablesTelemetryKind.referenceCommittedSummaryRead,
      ),
    );
  }

  static void _recordReferenceQueryFamilyRowVisits(int count) {
    _emitTelemetry(
      FamilyTablesTelemetryEvent(
        FamilyTablesTelemetryKind.referenceQueryFamilyRowVisits,
        count: count,
      ),
    );
  }

  static void _recordReferenceEditorBaseSummaryRead() {
    _emitTelemetry(
      const FamilyTablesTelemetryEvent(
        FamilyTablesTelemetryKind.referenceEditorBaseSummaryRead,
      ),
    );
  }

  static void _recordReferenceEditorDeltaRead({required int depth}) {
    _emitTelemetry(
      FamilyTablesTelemetryEvent(
        FamilyTablesTelemetryKind.referenceEditorDeltaRead,
        count: depth,
      ),
    );
  }

  static void _recordReferenceSummaryDeltaOpen({required bool image}) {
    _emitReferenceTelemetry(
      FamilyTablesTelemetryKind.referenceSummaryDeltaOpen,
      image: image,
    );
  }

  static void _recordReferenceAffectedIdUpdate({required bool image}) {
    _emitReferenceTelemetry(
      FamilyTablesTelemetryKind.referenceAffectedIdUpdate,
      image: image,
    );
  }

  static void _recordReferenceSummaryCompleteCopy({required bool image}) {
    _emitReferenceTelemetry(
      FamilyTablesTelemetryKind.referenceSummaryCompleteCopy,
      image: image,
    );
  }

  static void _recordReferenceSummaryMaterialization({required bool image}) {
    _emitReferenceTelemetry(
      FamilyTablesTelemetryKind.referenceSummaryMaterialization,
      image: image,
    );
  }

  static void _recordReferenceSummaryPublication({required bool image}) {
    _emitReferenceTelemetry(
      FamilyTablesTelemetryKind.referenceSummaryPublication,
      image: image,
    );
  }

  static void _recordReferenceSummaryIdentity({
    required bool image,
    required bool retainsBaseIdentity,
  }) {
    _emitReferenceTelemetry(
      FamilyTablesTelemetryKind.referenceSummaryIdentity,
      image: image,
      identityRetained: retainsBaseIdentity,
    );
  }

  static void _recordBatchReplacementStart() {
    _emitTelemetry(
      const FamilyTablesTelemetryEvent(
        FamilyTablesTelemetryKind.batchReplacement,
      ),
    );
  }

  static void _recordTransactionFamilyOpen(CanvasElementKind kind) {
    _emitFamilyTelemetry(FamilyTablesTelemetryKind.transactionFamilyOpen, kind);
  }

  static void _recordTransactionFamilyBaseEntryCopies(
    CanvasElementKind kind,
    int count,
  ) {
    _emitTelemetry(
      FamilyTablesTelemetryEvent(
        FamilyTablesTelemetryKind.transactionFamilyBaseEntryCopies,
        family: kind,
        count: count,
      ),
    );
  }

  static void _recordTransactionFamilyFreeze(CanvasElementKind kind) {
    _emitFamilyTelemetry(
      FamilyTablesTelemetryKind.transactionFamilyFreeze,
      kind,
    );
  }

  static void _recordTransactionFinalMapIdentity(
    CanvasElementKind kind, {
    required bool retainsBaseIdentity,
  }) {
    _emitTelemetry(
      FamilyTablesTelemetryEvent(
        FamilyTablesTelemetryKind.transactionFinalMapIdentity,
        family: kind,
        identityRetained: retainsBaseIdentity,
      ),
    );
  }

  static void _recordTransactionDiscard() {
    _emitTelemetry(
      const FamilyTablesTelemetryEvent(
        FamilyTablesTelemetryKind.transactionDiscard,
      ),
    );
  }

  static void _recordTransactionImmutablePublication() {
    _emitTelemetry(
      const FamilyTablesTelemetryEvent(
        FamilyTablesTelemetryKind.transactionImmutablePublication,
      ),
    );
  }

  static void _recordTransactionNormalizationWrite(CanvasElementKind kind) {
    _emitFamilyTelemetry(
      FamilyTablesTelemetryKind.transactionNormalizationWrite,
      kind,
    );
  }

  static void _recordEnumerationEntry(CanvasElementKind family) {
    _emitFamilyTelemetry(FamilyTablesTelemetryKind.enumerationEntry, family);
  }

  static void _emitFamilyTelemetry(
    FamilyTablesTelemetryKind kind,
    CanvasElementKind family,
  ) {
    _emitTelemetry(FamilyTablesTelemetryEvent(kind, family: family));
  }

  static void _emitReferenceTelemetry(
    FamilyTablesTelemetryKind kind, {
    required bool image,
    bool? identityRetained,
  }) {
    _emitTelemetry(
      FamilyTablesTelemetryEvent(
        kind,
        resourceSplit: image
            ? FamilyTablesResourceSplit.image
            : FamilyTablesResourceSplit.vector,
        identityRetained: identityRetained,
      ),
    );
  }

  static void _emitTelemetry(FamilyTablesTelemetryEvent event) {
    assert(() {
      final sink = Zone.current[_telemetryZoneKey];
      if (sink is FamilyTablesTelemetrySink) {
        sink(event);
      }
      return true;
    }(), 'family table telemetry observation failed');
  }

  _AdmittedRows _copyRows() {
    return _AdmittedRows()
      ..imageRows.addAll(imageRows)
      ..vectorRows.addAll(vectorRows)
      ..pathRows.addAll(pathRows)
      ..textRows.addAll(textRows)
      ..strokeRows.addAll(strokeRows)
      ..lineRows.addAll(lineRows)
      ..rectRows.addAll(rectRows)
      ..imageResourceReferenceCounts.addAll(imageResourceReferenceCounts)
      ..vectorResourceReferenceCounts.addAll(vectorResourceReferenceCounts);
  }

  // This single switch is the family-table insertion owner; splitting per row
  // kind would duplicate admission/projection rules and obscure sparse updates.
  // It stays cohesive despite the localized maintainability metric because the
  // split count facts must publish with the same family choice.
  // ignore: halstead-volume, source-lines-of-code, maintainability-index
  FamilyTables _withSameFamilyElement(CanvasElement element) {
    final id = element.id.value;

    return switch (element) {
      CanvasImageElement() => FamilyTables._fromTables(
        imageRows: Map.unmodifiable(
          Map.of(imageRows)..[id] = ImageRow(element),
        ),
        vectorRows: vectorRows,
        pathRows: pathRows,
        textRows: textRows,
        strokeRows: strokeRows,
        lineRows: lineRows,
        rectRows: rectRows,
        imageResourceReferenceCounts: _incrementReferenceCount(
          imageResourceReferenceCounts,
          element.resourceId,
        ),
        vectorResourceReferenceCounts: vectorResourceReferenceCounts,
      ),
      CanvasVectorElement() => FamilyTables._fromTables(
        imageRows: imageRows,
        vectorRows: Map.unmodifiable(
          Map.of(vectorRows)..[id] = VectorRow(element),
        ),
        pathRows: pathRows,
        textRows: textRows,
        strokeRows: strokeRows,
        lineRows: lineRows,
        rectRows: rectRows,
        imageResourceReferenceCounts: imageResourceReferenceCounts,
        vectorResourceReferenceCounts: _incrementReferenceCount(
          vectorResourceReferenceCounts,
          element.resourceId,
        ),
      ),
      CanvasPathElement() => FamilyTables._fromTables(
        imageRows: imageRows,
        vectorRows: vectorRows,
        pathRows: Map.unmodifiable(Map.of(pathRows)..[id] = PathRow(element)),
        textRows: textRows,
        strokeRows: strokeRows,
        lineRows: lineRows,
        rectRows: rectRows,
        imageResourceReferenceCounts: imageResourceReferenceCounts,
        vectorResourceReferenceCounts: vectorResourceReferenceCounts,
      ),
      CanvasTextElement() => FamilyTables._fromTables(
        imageRows: imageRows,
        vectorRows: vectorRows,
        pathRows: pathRows,
        textRows: Map.unmodifiable(Map.of(textRows)..[id] = TextRow(element)),
        strokeRows: strokeRows,
        lineRows: lineRows,
        rectRows: rectRows,
        imageResourceReferenceCounts: imageResourceReferenceCounts,
        vectorResourceReferenceCounts: vectorResourceReferenceCounts,
      ),
      CanvasStrokeElement() => FamilyTables._fromTables(
        imageRows: imageRows,
        vectorRows: vectorRows,
        pathRows: pathRows,
        textRows: textRows,
        strokeRows: Map.unmodifiable(
          Map.of(strokeRows)..[id] = StrokeRow(element),
        ),
        lineRows: lineRows,
        rectRows: rectRows,
        imageResourceReferenceCounts: imageResourceReferenceCounts,
        vectorResourceReferenceCounts: vectorResourceReferenceCounts,
      ),
      CanvasLineElement() => FamilyTables._fromTables(
        imageRows: imageRows,
        vectorRows: vectorRows,
        pathRows: pathRows,
        textRows: textRows,
        strokeRows: strokeRows,
        lineRows: Map.unmodifiable(Map.of(lineRows)..[id] = LineRow(element)),
        rectRows: rectRows,
        imageResourceReferenceCounts: imageResourceReferenceCounts,
        vectorResourceReferenceCounts: vectorResourceReferenceCounts,
      ),
      CanvasRectElement() => FamilyTables._fromTables(
        imageRows: imageRows,
        vectorRows: vectorRows,
        pathRows: pathRows,
        textRows: textRows,
        strokeRows: strokeRows,
        lineRows: lineRows,
        rectRows: Map.unmodifiable(Map.of(rectRows)..[id] = RectRow(element)),
        imageResourceReferenceCounts: imageResourceReferenceCounts,
        vectorResourceReferenceCounts: vectorResourceReferenceCounts,
      ),
    };
  }

  static Map<CanvasResourceId, int> _incrementReferenceCount(
    Map<CanvasResourceId, int> counts,
    CanvasResourceId id,
  ) {
    final nextCounts = Map<CanvasResourceId, int>.of(counts)
      ..update(id, (count) => count + 1, ifAbsent: () => 1);

    return Map.unmodifiable(nextCounts);
  }
}

enum FamilyTablesDecision {
  duplicateAdd,
  updateCurrentRow,
  updateMissingId,
  updateSource,
  updateKind,
  updateNoOp,
  removeMembership,
  removeUnusedReference,
  clear,
  relationship,
  acceptedDelta,
}

enum FamilyTablesDecisionSubjectKind { element, resource, content }

enum FamilyTablesDecisionResult {
  present,
  missing,
  matches,
  differs,
  changed,
  unchanged,
  referenced,
  unreferenced,
  added,
  removed,
  valid,
  invalid,
}

@visibleForTesting
@immutable
final class FamilyTablesDecisionRead {
  const FamilyTablesDecisionRead({
    required this.decision,
    required this.subjectKind,
    required this.subject,
    required this.result,
  });

  final FamilyTablesDecision decision;
  final FamilyTablesDecisionSubjectKind subjectKind;
  final String subject;
  final FamilyTablesDecisionResult result;

  @override
  bool operator ==(Object other) {
    return other is FamilyTablesDecisionRead &&
        other.decision == decision &&
        other.subjectKind == subjectKind &&
        other.subject == subject &&
        other.result == result;
  }

  @override
  int get hashCode => Object.hash(decision, subjectKind, subject, result);
}

// The sparse editor is the sole transaction-lifetime consumer of the generic
// per-family buffer: rows stay current here until one accepted freeze.
// Keeping all row-family operations here preserves that single source of truth.
// ignore: coupling-between-object-classes, number-of-methods, response-for-class, weighted-methods-per-class
final class FamilyTablesEditor {
  FamilyTablesEditor._(this._base)
    : _imageRows = _LazyFamilyMapBuffer(
        _base.imageRows,
        CanvasElementKind.image,
      ),
      _vectorRows = _LazyFamilyMapBuffer(
        _base.vectorRows,
        CanvasElementKind.vector,
      ),
      _pathRows = _LazyFamilyMapBuffer(_base.pathRows, CanvasElementKind.path),
      _textRows = _LazyFamilyMapBuffer(_base.textRows, CanvasElementKind.text),
      _strokeRows = _LazyFamilyMapBuffer(
        _base.strokeRows,
        CanvasElementKind.stroke,
      ),
      _lineRows = _LazyFamilyMapBuffer(_base.lineRows, CanvasElementKind.line),
      _rectRows = _LazyFamilyMapBuffer(_base.rectRows, CanvasElementKind.rect),
      _imageResourceReferences = _ReferenceSummaryDelta(
        _base.imageResourceReferenceCounts,
        image: true,
      ),
      _vectorResourceReferences = _ReferenceSummaryDelta(
        _base.vectorResourceReferenceCounts,
        image: false,
      );

  final FamilyTables _base;

  final _LazyFamilyMapBuffer<ImageRow> _imageRows;
  final _LazyFamilyMapBuffer<VectorRow> _vectorRows;
  final _LazyFamilyMapBuffer<PathRow> _pathRows;
  final _LazyFamilyMapBuffer<TextRow> _textRows;
  final _LazyFamilyMapBuffer<StrokeRow> _strokeRows;
  final _LazyFamilyMapBuffer<LineRow> _lineRows;
  final _LazyFamilyMapBuffer<RectRow> _rectRows;
  final _ReferenceSummaryDelta _imageResourceReferences;
  final _ReferenceSummaryDelta _vectorResourceReferences;

  bool _isOpen = true;
  FamilyTables? _frozenTables;
  bool _frozenTablesAdopted = false;

  bool get hasChanges =>
      _imageRows.hasChanges ||
      _vectorRows.hasChanges ||
      _pathRows.hasChanges ||
      _textRows.hasChanges ||
      _strokeRows.hasChanges ||
      _lineRows.hasChanges ||
      _rectRows.hasChanges;

  void recordUpdateBatch() {
    _checkOpen();
    FamilyTables._recordBatchReplacementStart();
  }

  void recordDecisionRead({
    required FamilyTablesDecision decision,
    required FamilyTablesDecisionSubjectKind subjectKind,
    required String subject,
    required FamilyTablesDecisionResult result,
  }) {
    FamilyTables._emitTelemetry(
      FamilyTablesTelemetryEvent(
        FamilyTablesTelemetryKind.editorDecisionRead,
        decision: decision,
        subjectKind: subjectKind,
        subject: subject,
        result: result,
      ),
    );
  }

  T decide<T>(FamilyTablesDecision decision, T Function() operation) {
    if (!FamilyTables._debugTelemetryEnabled) {
      return operation();
    }
    return runZoned(
      operation,
      zoneValues: {FamilyTables._sparseDecisionZoneKey: decision},
    );
  }

  bool contains(CanvasElementId id) {
    final value = id.value;

    return _imageRows.contains(value) ||
        _vectorRows.contains(value) ||
        _pathRows.contains(value) ||
        _textRows.contains(value) ||
        _strokeRows.contains(value) ||
        _lineRows.contains(value) ||
        _rectRows.contains(value);
  }

  bool referencesResource(CanvasResourceId id) {
    FamilyTables._recordReferenceQueryFamilyRowVisits(0);
    return imageResourceReferenceCount(id) + vectorResourceReferenceCount(id) >
        0;
  }

  @visibleForTesting
  int imageResourceReferenceCount(CanvasResourceId id) {
    return _imageResourceReferences.countFor(id);
  }

  @visibleForTesting
  int vectorResourceReferenceCount(CanvasResourceId id) {
    return _vectorResourceReferences.countFor(id);
  }

  // The lookup preserves FamilyTables' existing explicit family precedence.
  // ignore: cyclomatic-complexity
  CanvasElement? elementByCanvasId(CanvasElementId id) {
    if (Zone.current[FamilyTables._sparseDecisionZoneKey] ==
        FamilyTablesDecision.updateCurrentRow) {
      FamilyTables._emitTelemetry(
        const FamilyTablesTelemetryEvent(
          FamilyTablesTelemetryKind.editorCurrentRowRead,
        ),
      );
    }
    final value = id.value;

    return _imageRows[value]?.toElement() ??
        _vectorRows[value]?.toElement() ??
        _pathRows[value]?.toElement() ??
        _textRows[value]?.toElement() ??
        _strokeRows[value]?.toElement() ??
        _lineRows[value]?.toElement() ??
        _rectRows[value]?.toElement();
  }

  void addElement(CanvasElement element) {
    _checkOpen();
    final alreadyPresent = contains(element.id);
    recordDecisionRead(
      decision: FamilyTablesDecision.duplicateAdd,
      subjectKind: FamilyTablesDecisionSubjectKind.element,
      subject: element.id.value,
      result: alreadyPresent
          ? FamilyTablesDecisionResult.present
          : FamilyTablesDecisionResult.missing,
    );
    if (alreadyPresent) {
      throw CanvasDataException(
        code: CanvasDataErrorCode.duplicateElementId,
        message: 'duplicate element id.',
        path: 'elements.id',
      );
    }
    replaceElement(element);
  }

  void replaceElement(CanvasElement element) {
    _checkOpen();
    final id = element.id.value;
    switch (element) {
      case CanvasImageElement():
        final before = _imageRows[id];
        _imageRows.replace(id, ImageRow(element));
        _imageResourceReferences.transition(
          before: before?.resourceId,
          after: element.resourceId,
        );
      case CanvasVectorElement():
        final before = _vectorRows[id];
        _vectorRows.replace(id, VectorRow(element));
        _vectorResourceReferences.transition(
          before: before?.resourceId,
          after: element.resourceId,
        );
      case CanvasPathElement():
        _pathRows.replace(id, PathRow(element));
      case CanvasTextElement():
        _textRows.replace(id, TextRow(element));
      case CanvasStrokeElement():
        _strokeRows.replace(id, StrokeRow(element));
      case CanvasLineElement():
        _lineRows.replace(id, LineRow(element));
      case CanvasRectElement():
        _rectRows.replace(id, RectRow(element));
    }
  }

  void removeElement(CanvasElementId id) {
    _checkOpen();
    final value = id.value;
    final image = _imageRows[value];
    if (image != null) {
      _imageResourceReferences.transition(before: image.resourceId);
    }
    final vector = _vectorRows[value];
    if (vector != null) {
      _vectorResourceReferences.transition(before: vector.resourceId);
    }
    for (final rows in [
      _imageRows,
      _vectorRows,
      _pathRows,
      _textRows,
      _strokeRows,
      _lineRows,
      _rectRows,
    ]) {
      rows.removeIfPresent(value);
    }
  }

  void clearElements() {
    _checkOpen();
    _imageResourceReferences.clear();
    _vectorResourceReferences.clear();
    for (final rows in [
      _imageRows,
      _vectorRows,
      _pathRows,
      _textRows,
      _strokeRows,
      _lineRows,
      _rectRows,
    ]) {
      rows.clear();
    }
  }

  void normalizeFinalEqualRows(
    Iterable<CanvasElementId> ids,
    bool Function(CanvasElement before, CanvasElement after) isFinalEqual,
  ) {
    _checkOpen(normalization: true);
    for (final id in ids) {
      final before = FamilyTables.readSparseBase(
        () => _base.elementByCanvasId(id),
      );
      final after = elementByCanvasId(id);
      if (before == null || after == null || !isFinalEqual(before, after)) {
        continue;
      }
      _replaceBaseElement(before);
    }
    if (_imageRows.retainBaseIfExact()) {
      _imageResourceReferences.retainBase();
    }
    if (_vectorRows.retainBaseIfExact()) {
      _vectorResourceReferences.retainBase();
    }
    _pathRows.retainBaseIfExact();
    _textRows.retainBaseIfExact();
    _strokeRows.retainBaseIfExact();
    _lineRows.retainBaseIfExact();
    _rectRows.retainBaseIfExact();
  }

  FamilyTables freeze() {
    _checkOpen();
    _isOpen = false;
    final tables = FamilyTables._fromTables(
      imageRows: _imageRows.freeze(),
      vectorRows: _vectorRows.freeze(),
      pathRows: _pathRows.freeze(),
      textRows: _textRows.freeze(),
      strokeRows: _strokeRows.freeze(),
      lineRows: _lineRows.freeze(),
      rectRows: _rectRows.freeze(),
      imageResourceReferenceCounts: _imageResourceReferences.freeze(),
      vectorResourceReferenceCounts: _vectorResourceReferences.freeze(),
    );
    FamilyTables._recordTransactionImmutablePublication();
    _frozenTables = tables;

    return tables;
  }

  void discard() {
    if (!_isOpen) {
      return;
    }
    _isOpen = false;
    FamilyTables._recordTransactionDiscard();
  }

  // Restoring a row and its matching derived reference fact is one atomic
  // normalization transition; separate family helpers would hide that pairing.
  // ignore: halstead-volume, source-lines-of-code
  void _replaceBaseElement(CanvasElement element) {
    switch (element) {
      case CanvasImageElement():
        final after = _imageRows[element.id.value];
        _imageRows.restoreBase(element.id.value);
        _imageResourceReferences.transition(
          before: after?.resourceId,
          after: element.resourceId,
        );
        FamilyTables._recordTransactionNormalizationWrite(
          CanvasElementKind.image,
        );
      case CanvasVectorElement():
        final after = _vectorRows[element.id.value];
        _vectorRows.restoreBase(element.id.value);
        _vectorResourceReferences.transition(
          before: after?.resourceId,
          after: element.resourceId,
        );
        FamilyTables._recordTransactionNormalizationWrite(
          CanvasElementKind.vector,
        );
      case CanvasPathElement():
        _pathRows.restoreBase(element.id.value);
        FamilyTables._recordTransactionNormalizationWrite(
          CanvasElementKind.path,
        );
      case CanvasTextElement():
        _textRows.restoreBase(element.id.value);
        FamilyTables._recordTransactionNormalizationWrite(
          CanvasElementKind.text,
        );
      case CanvasStrokeElement():
        _strokeRows.restoreBase(element.id.value);
        FamilyTables._recordTransactionNormalizationWrite(
          CanvasElementKind.stroke,
        );
      case CanvasLineElement():
        _lineRows.restoreBase(element.id.value);
        FamilyTables._recordTransactionNormalizationWrite(
          CanvasElementKind.line,
        );
      case CanvasRectElement():
        _rectRows.restoreBase(element.id.value);
        FamilyTables._recordTransactionNormalizationWrite(
          CanvasElementKind.rect,
        );
    }
  }

  bool get _isFrozen => _frozenTables != null;

  bool _consumeFrozenAdoption(FamilyTables tables) {
    if (!identical(_frozenTables, tables) || _frozenTablesAdopted) {
      return false;
    }
    _frozenTablesAdopted = true;

    return true;
  }

  void _checkOpen({bool normalization = false}) {
    if (!_isOpen) {
      assert(() {
        FamilyTables._emitTelemetry(
          FamilyTablesTelemetryEvent(
            normalization
                ? FamilyTablesTelemetryKind.postFreezeNormalization
                : FamilyTablesTelemetryKind.postFreezeWrite,
          ),
        );
        return true;
      }(), 'post-freeze sparse family editor mutation observation failed');
      throw StateError('FamilyTablesEditor was already consumed.');
    }
  }
}

// Reference summaries stay derived from image/vector rows, while this editor
// records only affected ids until the one accepted family-table freeze.
final class _ReferenceSummaryDelta {
  _ReferenceSummaryDelta(this._base, {required this.image});

  final Map<CanvasResourceId, int> _base;
  final bool image;
  Map<CanvasResourceId, int>? _deltas;
  bool _cleared = false;
  bool _hasDeltaChanges = false;

  bool get hasChanges => _cleared || _hasDeltaChanges;

  int countFor(CanvasResourceId id) {
    FamilyTables._recordReferenceEditorBaseSummaryRead();
    FamilyTables._recordReferenceEditorDeltaRead(depth: 1);

    return (_cleared ? 0 : _base[id] ?? 0) + (_deltas?[id] ?? 0);
  }

  void transition({CanvasResourceId? before, CanvasResourceId? after}) {
    if (before == after) {
      return;
    }
    if (before != null) {
      _adjust(before, -1);
    }
    if (after != null) {
      _adjust(after, 1);
    }
  }

  void clear() {
    _deltas?.clear();
    _hasDeltaChanges = false;
    _cleared = _base.isNotEmpty;
  }

  void retainBase() {
    _deltas = null;
    _cleared = false;
    _hasDeltaChanges = false;
  }

  Map<CanvasResourceId, int> freeze() {
    if (!hasChanges) {
      FamilyTables._recordReferenceSummaryIdentity(
        image: image,
        retainsBaseIdentity: true,
      );
      return _base;
    }

    final materialized = _cleared
        ? <CanvasResourceId, int>{}
        : Map<CanvasResourceId, int>.of(_base);
    if (!_cleared && _base.isNotEmpty) {
      FamilyTables._recordReferenceSummaryCompleteCopy(image: image);
    }
    for (final MapEntry(key: id, value: delta) in (_deltas ?? {}).entries) {
      final next = (materialized[id] ?? 0) + delta;
      if (next == 0) {
        materialized.remove(id);
      } else if (next > 0) {
        materialized[id] = next;
      } else {
        throw StateError('resource-reference count underflow.');
      }
    }
    final frozen = Map<CanvasResourceId, int>.unmodifiable(materialized);
    FamilyTables._recordReferenceSummaryMaterialization(image: image);
    FamilyTables._recordReferenceSummaryPublication(image: image);
    FamilyTables._recordReferenceSummaryIdentity(
      image: image,
      retainsBaseIdentity: false,
    );

    return frozen;
  }

  void _adjust(CanvasResourceId id, int amount) {
    final current = (_cleared ? 0 : _base[id] ?? 0) + (_deltas?[id] ?? 0);
    final next = current + amount;
    if (next < 0) {
      throw StateError('resource-reference count underflow.');
    }

    final deltas = _deltas ??= _openDeltas();
    final nextDelta = (deltas[id] ?? 0) + amount;
    if (nextDelta == 0) {
      deltas.remove(id);
    } else {
      deltas[id] = nextDelta;
    }
    _hasDeltaChanges = deltas.isNotEmpty;
    FamilyTables._recordReferenceAffectedIdUpdate(image: image);
  }

  Map<CanvasResourceId, int> _openDeltas() {
    FamilyTables._recordReferenceSummaryDeltaOpen(image: image);

    return <CanvasResourceId, int>{};
  }
}

// The generic buffer deliberately owns its complete COW lifecycle so no second
// family mutation algorithm can drift from editor semantics.
// ignore: number-of-methods
final class _LazyFamilyMapBuffer<Row> {
  _LazyFamilyMapBuffer(this._baseRows, this._kind);

  final Map<String, Row> _baseRows;
  final CanvasElementKind _kind;
  Map<String, Row>? _mutableRows;

  bool get hasChanges => _mutableRows != null;

  Row? operator [](String id) {
    final mutableRows = _mutableRows;
    return mutableRows == null ? _baseRows[id] : mutableRows[id];
  }

  bool contains(String id) {
    final mutableRows = _mutableRows;
    return mutableRows == null
        ? _baseRows.containsKey(id)
        : mutableRows.containsKey(id);
  }

  Iterable<Row> get values => (_mutableRows ?? _baseRows).values;

  void replace(String id, Row row) {
    _openRows()[id] = row;
  }

  void restoreBase(String id) {
    final row = _baseRows[id];
    if (row != null) {
      _openRows()[id] = row;
    }
  }

  void removeIfPresent(String id) {
    if (contains(id)) {
      _openRows().remove(id);
    }
  }

  void clear() {
    final mutableRows = _mutableRows;
    if (mutableRows != null) {
      mutableRows.clear();
      return;
    }
    _recordOpen(baseEntryCopies: 0);
    _mutableRows = <String, Row>{};
  }

  bool retainBaseIfExact() {
    final mutableRows = _mutableRows;
    if (mutableRows == null) {
      return true;
    }
    if (mutableRows.length != _baseRows.length) {
      return false;
    }
    for (final MapEntry(key: key, value: value) in _baseRows.entries) {
      if (!identical(mutableRows[key], value)) {
        return false;
      }
    }
    _mutableRows = null;

    return true;
  }

  Map<String, Row> freeze() {
    final mutableRows = _mutableRows;
    if (mutableRows == null) {
      _recordFinalMapIdentity(retainsBaseIdentity: true);
      return _baseRows;
    }

    final frozenRows = Map<String, Row>.unmodifiable(mutableRows);
    FamilyTables._recordTransactionFamilyFreeze(_kind);
    _recordFinalMapIdentity(
      retainsBaseIdentity: identical(frozenRows, _baseRows),
    );

    return frozenRows;
  }

  Map<String, Row> _openRows() {
    final mutableRows = _mutableRows;
    if (mutableRows != null) {
      return mutableRows;
    }

    _recordOpen(baseEntryCopies: _baseRows.length);
    final openedRows = Map<String, Row>.of(_baseRows);
    _mutableRows = openedRows;

    return openedRows;
  }

  void _recordOpen({required int baseEntryCopies}) {
    FamilyTables._recordTransactionFamilyOpen(_kind);
    FamilyTables._recordTransactionFamilyBaseEntryCopies(
      _kind,
      baseEntryCopies,
    );
  }

  void _recordFinalMapIdentity({required bool retainsBaseIdentity}) {
    FamilyTables._recordTransactionFinalMapIdentity(
      _kind,
      retainsBaseIdentity: retainsBaseIdentity,
    );
  }
}

final class FamilyTablesSchemaV1ImportBuilder {
  _AdmittedRows? _rows = _AdmittedRows();

  void add(SchemaV1ElementImportEvent event) {
    _liveRows.addSchemaV1Import(event);
  }

  FamilyTables consume() {
    final rows = _liveRows;
    _rows = null;

    return FamilyTables._owned(rows);
  }

  _AdmittedRows get _liveRows {
    final rows = _rows;
    if (rows == null) {
      throw StateError('FamilyTablesSchemaV1ImportBuilder was consumed.');
    }

    return rows;
  }
}

final class FamilyElementFacts {
  FamilyElementFacts({
    required this.id,
    required this.kind,
    required this.revision,
    required this.generation,
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
    Iterable<Offset>? points,
    this.start,
    this.end,
    this.color,
    this.thickness,
  }) : points = List.unmodifiable(points ?? const []);

  final CanvasElementId id;
  final CanvasElementKind kind;
  final int revision;
  final int generation;
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

// Admission stores every family table together so duplicate id detection and
// row insertion remain one atomic step.
// ignore: coupling-between-object-classes
final class _AdmittedRows {
  final Map<String, ImageRow> imageRows = {};
  final Map<String, VectorRow> vectorRows = {};
  final Map<String, PathRow> pathRows = {};
  final Map<String, TextRow> textRows = {};
  final Map<String, StrokeRow> strokeRows = {};
  final Map<String, LineRow> lineRows = {};
  final Map<String, RectRow> rectRows = {};
  final Map<CanvasResourceId, int> imageResourceReferenceCounts = {};
  final Map<CanvasResourceId, int> vectorResourceReferenceCounts = {};
  final Set<String> ids = {};

  void add(CanvasElement element) {
    final id = element.id.value;
    if (!ids.add(id)) {
      throw CanvasDataException(
        code: CanvasDataErrorCode.duplicateElementId,
        message: 'duplicate element id.',
        path: 'elements.id',
      );
    }

    switch (element) {
      case CanvasImageElement():
        imageRows[id] = ImageRow(element);
        _addImageReference(element.resourceId);
      case CanvasVectorElement():
        vectorRows[id] = VectorRow(element);
        _addVectorReference(element.resourceId);
      case CanvasPathElement():
        pathRows[id] = PathRow(element);
      case CanvasTextElement():
        textRows[id] = TextRow(element);
      case CanvasStrokeElement():
        strokeRows[id] = StrokeRow(element);
      case CanvasLineElement():
        lineRows[id] = LineRow(element);
      case CanvasRectElement():
        rectRows[id] = RectRow(element);
    }
  }

  void addSchemaV1Import(SchemaV1ElementImportEvent event) {
    final id = event.common.id.value;
    if (!ids.add(id)) {
      throw CanvasDataException(
        code: CanvasDataErrorCode.duplicateElementId,
        message: 'duplicate element id.',
        path: 'elements.id',
      );
    }

    switch (event) {
      case SchemaV1ImageElementImportEvent():
        imageRows[id] = ImageRow.fromSchemaV1Import(event);
        _addImageReference(event.resourceId);
      case SchemaV1VectorElementImportEvent():
        vectorRows[id] = VectorRow.fromSchemaV1Import(event);
        _addVectorReference(event.resourceId);
      case SchemaV1PathElementImportEvent():
        pathRows[id] = PathRow.fromSchemaV1Import(event);
      case SchemaV1TextElementImportEvent():
        textRows[id] = TextRow.fromSchemaV1Import(event);
      case SchemaV1StrokeElementImportEvent():
        strokeRows[id] = StrokeRow.fromSchemaV1Import(event);
      case SchemaV1LineElementImportEvent():
        lineRows[id] = LineRow.fromSchemaV1Import(event);
      case SchemaV1RectElementImportEvent():
        rectRows[id] = RectRow.fromSchemaV1Import(event);
    }
  }

  void remove(String id) {
    ids.remove(id);
    final image = imageRows.remove(id);
    if (image != null) {
      _removeImageReference(image.resourceId);
    }
    final vector = vectorRows.remove(id);
    if (vector != null) {
      _removeVectorReference(vector.resourceId);
    }
    pathRows.remove(id);
    textRows.remove(id);
    strokeRows.remove(id);
    lineRows.remove(id);
    rectRows.remove(id);
  }

  void _addImageReference(CanvasResourceId id) {
    _increment(imageResourceReferenceCounts, id);
    FamilyTables._recordReferenceConstructionRowVisit();
  }

  void _addVectorReference(CanvasResourceId id) {
    _increment(vectorResourceReferenceCounts, id);
    FamilyTables._recordReferenceConstructionRowVisit();
  }

  void _removeImageReference(CanvasResourceId id) {
    _decrement(imageResourceReferenceCounts, id);
  }

  void _removeVectorReference(CanvasResourceId id) {
    _decrement(vectorResourceReferenceCounts, id);
  }

  static void _increment(
    Map<CanvasResourceId, int> counts,
    CanvasResourceId id,
  ) {
    counts.update(id, (count) => count + 1, ifAbsent: () => 1);
  }

  static void _decrement(
    Map<CanvasResourceId, int> counts,
    CanvasResourceId id,
  ) {
    final count = counts[id];
    if (count == null || count <= 0) {
      throw StateError('resource-reference count underflow.');
    }
    if (count == 1) {
      counts.remove(id);
    } else {
      counts[id] = count - 1;
    }
  }
}

_AdmittedRows _admitElements(Iterable<CanvasElement> elements) {
  final admitted = _AdmittedRows();
  for (final element in elements) {
    admitted.add(element);
  }

  return admitted;
}

_AdmittedRows _admitSchemaV1Elements(
  Iterable<SchemaV1ElementImportEvent> elements,
) {
  final admitted = _AdmittedRows();
  for (final element in elements) {
    admitted.addSchemaV1Import(element);
  }

  return admitted;
}

final class ElementCommonRow {
  ElementCommonRow(CanvasElement element)
    : id = element.id,
      revision = element.revision,
      transform = element.transform,
      opacity = element.opacity,
      hitPadding = element.hitPadding,
      isVisible = element.isVisible,
      isSelectable = element.isSelectable,
      isLocked = element.isLocked,
      isDeletable = element.isDeletable,
      isTransformable = element.isTransformable,
      metadata = element.metadata;

  ElementCommonRow.fromSchemaV1Import(SchemaV1ElementCommonImport common)
    : id = common.id,
      revision = common.revision,
      transform = common.transform,
      opacity = common.opacity,
      hitPadding = common.hitPadding,
      isVisible = common.isVisible,
      isSelectable = common.isSelectable,
      isLocked = common.isLocked,
      isDeletable = common.isDeletable,
      isTransformable = common.isTransformable,
      metadata = common.metadata;

  final CanvasElementId id;
  final int revision;
  final CanvasTransform transform;
  final double opacity;
  final double hitPadding;
  final bool isVisible;
  final bool isSelectable;
  final bool isLocked;
  final bool isDeletable;
  final bool isTransformable;
  final CanvasMetadata metadata;
}

final class ImageRow {
  ImageRow(CanvasImageElement element)
    : common = ElementCommonRow(element),
      resourceId = element.resourceId,
      size = element.size,
      naturalSize = element.naturalSize;

  ImageRow.fromSchemaV1Import(SchemaV1ImageElementImportEvent event)
    : common = ElementCommonRow.fromSchemaV1Import(event.common),
      resourceId = event.resourceId,
      size = event.size,
      naturalSize = event.naturalSize;

  final ElementCommonRow common;
  final CanvasResourceId resourceId;
  final Size size;
  final Size? naturalSize;

  CanvasImageElement toElement() {
    return CanvasImageElement(
      id: common.id,
      resourceId: resourceId,
      size: size,
      naturalSize: naturalSize,
      revision: common.revision,
      transform: common.transform,
      opacity: common.opacity,
      hitPadding: common.hitPadding,
      isVisible: common.isVisible,
      isSelectable: common.isSelectable,
      isLocked: common.isLocked,
      isDeletable: common.isDeletable,
      isTransformable: common.isTransformable,
      metadata: common.metadata,
    );
  }
}

final class VectorRow {
  VectorRow(CanvasVectorElement element)
    : common = ElementCommonRow(element),
      resourceId = element.resourceId,
      size = element.size,
      naturalSize = element.naturalSize;

  VectorRow.fromSchemaV1Import(SchemaV1VectorElementImportEvent event)
    : common = ElementCommonRow.fromSchemaV1Import(event.common),
      resourceId = event.resourceId,
      size = event.size,
      naturalSize = event.naturalSize;

  final ElementCommonRow common;
  final CanvasResourceId resourceId;
  final Size size;
  final Size? naturalSize;

  CanvasVectorElement toElement() {
    return CanvasVectorElement(
      id: common.id,
      resourceId: resourceId,
      size: size,
      naturalSize: naturalSize,
      revision: common.revision,
      transform: common.transform,
      opacity: common.opacity,
      hitPadding: common.hitPadding,
      isVisible: common.isVisible,
      isSelectable: common.isSelectable,
      isLocked: common.isLocked,
      isDeletable: common.isDeletable,
      isTransformable: common.isTransformable,
      metadata: common.metadata,
    );
  }
}

final class PathRow {
  PathRow(CanvasPathElement element)
    : common = ElementCommonRow(element),
      svgPathData = element.svgPathData,
      fillColor = element.fillColor,
      strokeColor = element.strokeColor,
      strokeWidth = element.strokeWidth,
      fillRule = element.fillRule;

  PathRow.fromSchemaV1Import(SchemaV1PathElementImportEvent event)
    : common = ElementCommonRow.fromSchemaV1Import(event.common),
      svgPathData = event.svgPathData,
      fillColor = event.fillColor,
      strokeColor = event.strokeColor,
      strokeWidth = event.strokeWidth,
      fillRule = event.fillRule;

  final ElementCommonRow common;
  final String svgPathData;
  final Color? fillColor;
  final Color? strokeColor;
  final double strokeWidth;
  final CanvasPathFillRule fillRule;

  CanvasPathElement toElement() {
    return CanvasPathElement(
      id: common.id,
      svgPathData: svgPathData,
      fillColor: fillColor,
      strokeColor: strokeColor,
      strokeWidth: strokeWidth,
      fillRule: fillRule,
      revision: common.revision,
      transform: common.transform,
      opacity: common.opacity,
      hitPadding: common.hitPadding,
      isVisible: common.isVisible,
      isSelectable: common.isSelectable,
      isLocked: common.isLocked,
      isDeletable: common.isDeletable,
      isTransformable: common.isTransformable,
      metadata: common.metadata,
    );
  }
}

final class TextRow {
  TextRow(CanvasTextElement element)
    : common = ElementCommonRow(element),
      text = element.text,
      fontSize = element.fontSize,
      color = element.color,
      align = element.align,
      textDirection = element.textDirection,
      isBold = element.isBold,
      isItalic = element.isItalic,
      isUnderline = element.isUnderline,
      fontFamily = element.fontFamily,
      maxWidth = element.maxWidth,
      lineHeight = element.lineHeight;

  TextRow.fromSchemaV1Import(SchemaV1TextElementImportEvent event)
    : common = ElementCommonRow.fromSchemaV1Import(event.common),
      text = event.text,
      fontSize = event.fontSize,
      color = event.color,
      align = event.align,
      textDirection = event.textDirection,
      isBold = event.isBold,
      isItalic = event.isItalic,
      isUnderline = event.isUnderline,
      fontFamily = event.fontFamily,
      maxWidth = event.maxWidth,
      lineHeight = event.lineHeight;

  final ElementCommonRow common;
  final String text;
  final double fontSize;
  final Color color;
  final TextAlign align;
  final TextDirection textDirection;
  final bool isBold;
  final bool isItalic;
  final bool isUnderline;
  final String? fontFamily;
  final double? maxWidth;
  final double? lineHeight;

  CanvasTextElement toElement() {
    return CanvasTextElement(
      id: common.id,
      text: text,
      color: color,
      textDirection: textDirection,
      fontSize: fontSize,
      align: align,
      isBold: isBold,
      isItalic: isItalic,
      isUnderline: isUnderline,
      fontFamily: fontFamily,
      maxWidth: maxWidth,
      lineHeight: lineHeight,
      revision: common.revision,
      transform: common.transform,
      opacity: common.opacity,
      hitPadding: common.hitPadding,
      isVisible: common.isVisible,
      isSelectable: common.isSelectable,
      isLocked: common.isLocked,
      isDeletable: common.isDeletable,
      isTransformable: common.isTransformable,
      metadata: common.metadata,
    );
  }
}

final class StrokeRow {
  StrokeRow(CanvasStrokeElement element)
    : common = ElementCommonRow(element),
      points = List.unmodifiable(element.points),
      thickness = element.thickness,
      color = element.color;

  StrokeRow.fromSchemaV1Import(SchemaV1StrokeElementImportEvent event)
    : common = ElementCommonRow.fromSchemaV1Import(event.common),
      points = List.unmodifiable(event.points),
      thickness = event.thickness,
      color = event.color;

  final ElementCommonRow common;
  final List<Offset> points;
  final double thickness;
  final Color color;

  CanvasStrokeElement toElement() {
    return CanvasStrokeElement(
      id: common.id,
      points: points,
      thickness: thickness,
      color: color,
      revision: common.revision,
      transform: common.transform,
      opacity: common.opacity,
      hitPadding: common.hitPadding,
      isVisible: common.isVisible,
      isSelectable: common.isSelectable,
      isLocked: common.isLocked,
      isDeletable: common.isDeletable,
      isTransformable: common.isTransformable,
      metadata: common.metadata,
    );
  }
}

final class LineRow {
  LineRow(CanvasLineElement element)
    : common = ElementCommonRow(element),
      start = element.start,
      end = element.end,
      thickness = element.thickness,
      color = element.color;

  LineRow.fromSchemaV1Import(SchemaV1LineElementImportEvent event)
    : common = ElementCommonRow.fromSchemaV1Import(event.common),
      start = event.start,
      end = event.end,
      thickness = event.thickness,
      color = event.color;

  final ElementCommonRow common;
  final Offset start;
  final Offset end;
  final double thickness;
  final Color color;

  CanvasLineElement toElement() {
    return CanvasLineElement(
      id: common.id,
      start: start,
      end: end,
      thickness: thickness,
      color: color,
      revision: common.revision,
      transform: common.transform,
      opacity: common.opacity,
      hitPadding: common.hitPadding,
      isVisible: common.isVisible,
      isSelectable: common.isSelectable,
      isLocked: common.isLocked,
      isDeletable: common.isDeletable,
      isTransformable: common.isTransformable,
      metadata: common.metadata,
    );
  }
}

final class RectRow {
  RectRow(CanvasRectElement element)
    : common = ElementCommonRow(element),
      size = element.size,
      fillColor = element.fillColor,
      strokeColor = element.strokeColor,
      strokeWidth = element.strokeWidth;

  RectRow.fromSchemaV1Import(SchemaV1RectElementImportEvent event)
    : common = ElementCommonRow.fromSchemaV1Import(event.common),
      size = event.size,
      fillColor = event.fillColor,
      strokeColor = event.strokeColor,
      strokeWidth = event.strokeWidth;

  final ElementCommonRow common;
  final Size size;
  final Color? fillColor;
  final Color? strokeColor;
  final double strokeWidth;

  CanvasRectElement toElement() {
    return CanvasRectElement(
      id: common.id,
      size: size,
      fillColor: fillColor,
      strokeColor: strokeColor,
      strokeWidth: strokeWidth,
      revision: common.revision,
      transform: common.transform,
      opacity: common.opacity,
      hitPadding: common.hitPadding,
      isVisible: common.isVisible,
      isSelectable: common.isSelectable,
      isLocked: common.isLocked,
      isDeletable: common.isDeletable,
      isTransformable: common.isTransformable,
      metadata: common.metadata,
    );
  }
}
