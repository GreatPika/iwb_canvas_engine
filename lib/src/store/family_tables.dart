import 'dart:async';
import 'dart:collection';
import 'dart:ui';

import 'package:flutter/foundation.dart' show visibleForTesting;

// Family-specific row tables stay together so admission and projection cannot
// drift across element kinds; splitting them would obscure the shared id owner.

import '../contracts/internal/schema_v1_import_events.dart';
import '../contracts/public/canvas_element.dart';
import '../contracts/public/canvas_errors.dart';
import '../contracts/public/canvas_geometry.dart';
import '../contracts/public/canvas_ids.dart';
import '../contracts/public/canvas_metadata.dart';

// The family tables are the single admission and projection owner for all
// element kinds; splitting by kind would reintroduce cross-table drift.
// Sparse row mutation belongs with family admission so updates cannot drift
// from duplicate-id and resource-reference validation.
// ignore: coupling-between-object-classes, number-of-methods, response-for-class, weighted-methods-per-class
final class FamilyTables {
  static final Object _workZoneKey = Object();

  const FamilyTables.empty()
    : this._fromTables(
        imageRows: const {},
        vectorRows: const {},
        pathRows: const {},
        textRows: const {},
        strokeRows: const {},
        lineRows: const {},
        rectRows: const {},
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
      );

  const FamilyTables._fromTables({
    required this.imageRows,
    required this.vectorRows,
    required this.pathRows,
    required this.textRows,
    required this.strokeRows,
    required this.lineRows,
    required this.rectRows,
  });

  final Map<String, ImageRow> imageRows;
  final Map<String, VectorRow> vectorRows;
  final Map<String, PathRow> pathRows;
  final Map<String, TextRow> textRows;
  final Map<String, StrokeRow> strokeRows;
  final Map<String, LineRow> lineRows;
  final Map<String, RectRow> rectRows;

  // Membership is an owner-local read: a direct probe avoids constructing a
  // document-sized key union for callers that only need one id.
  // ignore: cyclomatic-complexity
  bool contains(CanvasElementId id) {
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

  // This test-only observation is assert-gated and owns no rows, ids, or
  // membership data, so it cannot become another table authority.
  @visibleForTesting
  static T observeWork<T>(FamilyTablesWork work, T Function() operation) {
    return runZoned(operation, zoneValues: {_workZoneKey: work});
  }

  bool referencesResource(CanvasResourceId id) {
    return imageRows.values.any((row) => row.resourceId == id) ||
        vectorRows.values.any((row) => row.resourceId == id);
  }

  // Family lookup stays explicit so projection, sparse updates, and frame facts
  // all preserve the same family precedence in one audited place.
  // ignore: cyclomatic-complexity
  CanvasElement? elementByCanvasId(CanvasElementId id) {
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
    final admitted = _copyRows()..remove(id.value);

    return FamilyTables._(admitted);
  }

  FamilyTables clearElements() {
    return FamilyTables._(_AdmittedRows());
  }

  FamilyTables replaceElements(Iterable<CanvasElement> elements) {
    _recordBatchReplacementStart();
    final batchRows = _MutableFamilyRows.fromTables(this);

    for (final element in elements) {
      batchRows.replace(element);
    }

    return batchRows.toFamilyTables();
  }

  // The lookup deliberately checks every family table in one place so missing
  // ids fail at the caller-owned admission boundary.
  // ignore: cyclomatic-complexity
  CanvasElement elementById(String id) {
    return imageRows[id]?.toElement() ??
        vectorRows[id]?.toElement() ??
        pathRows[id]?.toElement() ??
        textRows[id]?.toElement() ??
        strokeRows[id]?.toElement() ??
        lineRows[id]?.toElement() ??
        rectRows[id]!.toElement();
  }

  Set<String> get admittedElementIds {
    _recordMembershipSetAllocation();
    _recordMembershipKeyCopies(
      imageRows.length +
          vectorRows.length +
          pathRows.length +
          textRows.length +
          strokeRows.length +
          lineRows.length +
          rectRows.length,
    );

    return {
      ...imageRows.keys,
      ...vectorRows.keys,
      ...pathRows.keys,
      ...textRows.keys,
      ...strokeRows.keys,
      ...lineRows.keys,
      ...rectRows.keys,
    };
  }

  bool isSelectionEligible(CanvasElementId id) {
    final common = _commonById(id.value);

    return common != null && common.isVisible && common.isSelectable;
  }

  // Frame fact lookup has to preserve the same family ordering as admission and
  // projection to avoid divergent element-kind behavior.
  // ignore: cyclomatic-complexity
  FamilyElementFacts? elementFrameFacts(CanvasElementId id) {
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
    assert(() {
      final work = Zone.current[_workZoneKey];
      if (work is FamilyTablesWork) {
        work._recordMapProbe();
      }
      return true;
    }(), 'membership map-probe observation failed');
  }

  static void _recordBatchReplacementStart() {
    assert(() {
      final work = Zone.current[_workZoneKey];
      if (work is FamilyTablesWork) {
        work._recordReplacement();
      }
      return true;
    }(), 'batch replacement observation failed');
  }

  static void _recordBatchFamilyOpen(CanvasElementKind kind) {
    assert(() {
      final work = Zone.current[_workZoneKey];
      if (work is FamilyTablesWork) {
        work._recordFamilyOpen(kind);
      }
      return true;
    }(), 'batch family open observation failed');
  }

  static void _recordBatchFamilyBaseEntryCopies(
    CanvasElementKind kind,
    int count,
  ) {
    assert(() {
      final work = Zone.current[_workZoneKey];
      if (work is FamilyTablesWork) {
        work._recordFamilyBaseEntryCopies(kind, count);
      }
      return true;
    }(), 'batch family copy observation failed');
  }

  static void _recordBatchFamilyFreeze(CanvasElementKind kind) {
    assert(() {
      final work = Zone.current[_workZoneKey];
      if (work is FamilyTablesWork) {
        work._recordFamilyFreeze(kind);
      }
      return true;
    }(), 'batch family freeze observation failed');
  }

  static void _recordBatchFinalMapIdentity(
    CanvasElementKind kind, {
    required bool retainsBaseIdentity,
  }) {
    assert(() {
      final work = Zone.current[_workZoneKey];
      if (work is FamilyTablesWork) {
        work._recordFinalMapIdentity(
          kind,
          retainsBaseIdentity: retainsBaseIdentity,
        );
      }
      return true;
    }(), 'batch final-map identity observation failed');
  }

  static void _recordMembershipSetAllocation() {
    assert(() {
      final work = Zone.current[_workZoneKey];
      if (work is FamilyTablesWork) {
        work._recordMembershipSetAllocation();
      }
      return true;
    }(), 'membership set-allocation observation failed');
  }

  static void _recordMembershipKeyCopies(int count) {
    assert(() {
      final work = Zone.current[_workZoneKey];
      if (work is FamilyTablesWork) {
        work._recordMembershipKeyCopies(count);
      }
      return true;
    }(), 'membership key-copy observation failed');
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
      ..ids.addAll(admittedElementIds);
  }

  // This single switch is the family-table insertion owner; splitting per row
  // kind would duplicate admission/projection rules and obscure sparse updates.
  // ignore: halstead-volume, source-lines-of-code
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
      ),
      CanvasPathElement() => FamilyTables._fromTables(
        imageRows: imageRows,
        vectorRows: vectorRows,
        pathRows: Map.unmodifiable(Map.of(pathRows)..[id] = PathRow(element)),
        textRows: textRows,
        strokeRows: strokeRows,
        lineRows: lineRows,
        rectRows: rectRows,
      ),
      CanvasTextElement() => FamilyTables._fromTables(
        imageRows: imageRows,
        vectorRows: vectorRows,
        pathRows: pathRows,
        textRows: Map.unmodifiable(Map.of(textRows)..[id] = TextRow(element)),
        strokeRows: strokeRows,
        lineRows: lineRows,
        rectRows: rectRows,
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
      ),
      CanvasLineElement() => FamilyTables._fromTables(
        imageRows: imageRows,
        vectorRows: vectorRows,
        pathRows: pathRows,
        textRows: textRows,
        strokeRows: strokeRows,
        lineRows: Map.unmodifiable(Map.of(lineRows)..[id] = LineRow(element)),
        rectRows: rectRows,
      ),
      CanvasRectElement() => FamilyTables._fromTables(
        imageRows: imageRows,
        vectorRows: vectorRows,
        pathRows: pathRows,
        textRows: textRows,
        strokeRows: strokeRows,
        lineRows: lineRows,
        rectRows: Map.unmodifiable(Map.of(rectRows)..[id] = RectRow(element)),
      ),
    };
  }
}

@visibleForTesting
// The seven explicit counters are one owner-semantic probe: splitting them
// would fragment the single assert-gated observation surface by evidence type.
// ignore: number-of-methods
final class FamilyTablesWork {
  int _mapProbeCount = 0;
  int _membershipSetAllocationCount = 0;
  int _membershipKeyCopyCount = 0;
  final Map<CanvasElementKind, int> _batchOpenCountByFamily = {};
  final Map<CanvasElementKind, int> _batchBaseEntryCopyCountByFamily = {};
  final Map<CanvasElementKind, int> _batchFreezeCountByFamily = {};
  final Map<CanvasElementKind, bool> _batchFinalMapRetainsBaseIdentityByFamily =
      {};
  int _batchReplacementCount = 0;

  int get mapProbeCount => _mapProbeCount;
  int get membershipSetAllocationCount => _membershipSetAllocationCount;
  int get membershipKeyCopyCount => _membershipKeyCopyCount;
  int get batchReplacementCount => _batchReplacementCount;

  int batchOpenCount(CanvasElementKind kind) {
    return _batchOpenCountByFamily[kind] ?? 0;
  }

  int batchBaseEntryCopyCount(CanvasElementKind kind) {
    return _batchBaseEntryCopyCountByFamily[kind] ?? 0;
  }

  int batchFreezeCount(CanvasElementKind kind) {
    return _batchFreezeCountByFamily[kind] ?? 0;
  }

  bool batchFinalMapRetainsBaseIdentity(CanvasElementKind kind) {
    return _batchFinalMapRetainsBaseIdentityByFamily[kind] ?? false;
  }

  void _recordMapProbe() {
    _mapProbeCount += 1;
  }

  void _recordMembershipSetAllocation() {
    _membershipSetAllocationCount += 1;
  }

  void _recordMembershipKeyCopies(int count) {
    _membershipKeyCopyCount += count;
  }

  void _recordReplacement() {
    _batchReplacementCount += 1;
  }

  void _recordFamilyOpen(CanvasElementKind kind) {
    _batchOpenCountByFamily.update(
      kind,
      (count) => count + 1,
      ifAbsent: () => 1,
    );
  }

  void _recordFamilyBaseEntryCopies(CanvasElementKind kind, int count) {
    _batchBaseEntryCopyCountByFamily.update(
      kind,
      (current) => current + count,
      ifAbsent: () => count,
    );
  }

  void _recordFamilyFreeze(CanvasElementKind kind) {
    _batchFreezeCountByFamily.update(
      kind,
      (count) => count + 1,
      ifAbsent: () => 1,
    );
  }

  void _recordFinalMapIdentity(
    CanvasElementKind kind, {
    required bool retainsBaseIdentity,
  }) {
    _batchFinalMapRetainsBaseIdentityByFamily[kind] = retainsBaseIdentity;
  }
}

// Batch replacement remains one cohesive consumer while each typed family buffer
// copies only when that family receives its first replacement in the batch.
// ignore: coupling-between-object-classes
final class _MutableFamilyRows {
  _MutableFamilyRows.fromTables(FamilyTables tables)
    : imageRows = _LazyFamilyMapBuffer(
        tables.imageRows,
        CanvasElementKind.image,
      ),
      vectorRows = _LazyFamilyMapBuffer(
        tables.vectorRows,
        CanvasElementKind.vector,
      ),
      pathRows = _LazyFamilyMapBuffer(tables.pathRows, CanvasElementKind.path),
      textRows = _LazyFamilyMapBuffer(tables.textRows, CanvasElementKind.text),
      strokeRows = _LazyFamilyMapBuffer(
        tables.strokeRows,
        CanvasElementKind.stroke,
      ),
      lineRows = _LazyFamilyMapBuffer(tables.lineRows, CanvasElementKind.line),
      rectRows = _LazyFamilyMapBuffer(tables.rectRows, CanvasElementKind.rect);

  final _LazyFamilyMapBuffer<ImageRow> imageRows;
  final _LazyFamilyMapBuffer<VectorRow> vectorRows;
  final _LazyFamilyMapBuffer<PathRow> pathRows;
  final _LazyFamilyMapBuffer<TextRow> textRows;
  final _LazyFamilyMapBuffer<StrokeRow> strokeRows;
  final _LazyFamilyMapBuffer<LineRow> lineRows;
  final _LazyFamilyMapBuffer<RectRow> rectRows;

  void replace(CanvasElement element) {
    final id = element.id.value;
    switch (element) {
      case CanvasImageElement():
        imageRows.replace(id, ImageRow(element));
      case CanvasVectorElement():
        vectorRows.replace(id, VectorRow(element));
      case CanvasPathElement():
        pathRows.replace(id, PathRow(element));
      case CanvasTextElement():
        textRows.replace(id, TextRow(element));
      case CanvasStrokeElement():
        strokeRows.replace(id, StrokeRow(element));
      case CanvasLineElement():
        lineRows.replace(id, LineRow(element));
      case CanvasRectElement():
        rectRows.replace(id, RectRow(element));
    }
  }

  FamilyTables toFamilyTables() {
    return FamilyTables._fromTables(
      imageRows: imageRows.freeze(),
      vectorRows: vectorRows.freeze(),
      pathRows: pathRows.freeze(),
      textRows: textRows.freeze(),
      strokeRows: strokeRows.freeze(),
      lineRows: lineRows.freeze(),
      rectRows: rectRows.freeze(),
    );
  }
}

final class _LazyFamilyMapBuffer<Row> {
  _LazyFamilyMapBuffer(this._baseRows, this._kind);

  final Map<String, Row> _baseRows;
  final CanvasElementKind _kind;
  Map<String, Row>? _mutableRows;

  void replace(String id, Row row) {
    _openRows()[id] = row;
  }

  Map<String, Row> freeze() {
    final mutableRows = _mutableRows;
    if (mutableRows == null) {
      FamilyTables._recordBatchFinalMapIdentity(
        _kind,
        retainsBaseIdentity: true,
      );
      return _baseRows;
    }

    final frozenRows = Map<String, Row>.unmodifiable(mutableRows);
    FamilyTables._recordBatchFamilyFreeze(_kind);
    FamilyTables._recordBatchFinalMapIdentity(
      _kind,
      retainsBaseIdentity: identical(frozenRows, _baseRows),
    );

    return frozenRows;
  }

  Map<String, Row> _openRows() {
    final mutableRows = _mutableRows;
    if (mutableRows != null) {
      return mutableRows;
    }

    FamilyTables._recordBatchFamilyOpen(_kind);
    FamilyTables._recordBatchFamilyBaseEntryCopies(_kind, _baseRows.length);
    final openedRows = Map<String, Row>.of(_baseRows);
    _mutableRows = openedRows;

    return openedRows;
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
      case CanvasVectorElement():
        vectorRows[id] = VectorRow(element);
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
      case SchemaV1VectorElementImportEvent():
        vectorRows[id] = VectorRow.fromSchemaV1Import(event);
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
    if (!ids.remove(id)) {
      return;
    }
    imageRows.remove(id);
    vectorRows.remove(id);
    pathRows.remove(id);
    textRows.remove(id);
    strokeRows.remove(id);
    lineRows.remove(id);
    rectRows.remove(id);
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
