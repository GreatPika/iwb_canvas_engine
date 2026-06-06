import 'dart:ui';

// Family-specific row tables stay together so admission and projection cannot
// drift across element kinds; splitting them would obscure the shared id owner.

import '../contracts/public/canvas_element.dart';
import '../contracts/public/canvas_errors.dart';
import '../contracts/public/canvas_geometry.dart';
import '../contracts/public/canvas_ids.dart';
import '../contracts/public/canvas_metadata.dart';

// The family tables are the single admission and projection owner for all
// element kinds; splitting by kind would reintroduce cross-table drift.
// Sparse row mutation belongs with family admission so updates cannot drift
// from duplicate-id and resource-reference validation.
// ignore: coupling-between-object-classes, number-of-methods, weighted-methods-per-class
final class FamilyTables {
  FamilyTables(
    Iterable<CanvasElement> elements, {
    required Set<String> resourceIds,
  }) : this._(_admitElements(elements, resourceIds));

  FamilyTables._(_AdmittedRows admitted)
    : this._fromTables(
        imageRows: Map.unmodifiable(admitted.imageRows),
        pathRows: Map.unmodifiable(admitted.pathRows),
        textRows: Map.unmodifiable(admitted.textRows),
        strokeRows: Map.unmodifiable(admitted.strokeRows),
        lineRows: Map.unmodifiable(admitted.lineRows),
        rectRows: Map.unmodifiable(admitted.rectRows),
      );

  const FamilyTables._fromTables({
    required this.imageRows,
    required this.pathRows,
    required this.textRows,
    required this.strokeRows,
    required this.lineRows,
    required this.rectRows,
  });

  final Map<String, ImageRow> imageRows;
  final Map<String, PathRow> pathRows;
  final Map<String, TextRow> textRows;
  final Map<String, StrokeRow> strokeRows;
  final Map<String, LineRow> lineRows;
  final Map<String, RectRow> rectRows;

  bool contains(CanvasElementId id) => admittedElementIds.contains(id.value);

  bool referencesResource(CanvasResourceId id) {
    return imageRows.values.any((row) => row.resourceId == id);
  }

  // Family lookup stays explicit so projection, sparse updates, and frame facts
  // all preserve the same family precedence in one audited place.
  // ignore: cyclomatic-complexity
  CanvasElement? elementByCanvasId(CanvasElementId id) {
    final value = id.value;

    return imageRows[value]?.toElement() ??
        pathRows[value]?.toElement() ??
        textRows[value]?.toElement() ??
        strokeRows[value]?.toElement() ??
        lineRows[value]?.toElement() ??
        rectRows[value]?.toElement();
  }

  FamilyTables addElement(CanvasElement element, Set<String> resourceIds) {
    if (_commonById(element.id.value) != null) {
      throw CanvasDataException(
        code: CanvasDataErrorCode.duplicateElementId,
        message: 'duplicate element id.',
        path: 'elements.id',
      );
    }
    _validateElementResourceReferences(element, resourceIds);

    return _withSameFamilyElement(element);
  }

  FamilyTables removeElement(CanvasElementId id) {
    final admitted = _copyRows()..remove(id.value);

    return FamilyTables._(admitted);
  }

  FamilyTables clearElements() {
    return FamilyTables._(_AdmittedRows());
  }

  FamilyTables? replaceElement(
    CanvasElement before,
    CanvasElement after,
    Set<String> resourceIds,
  ) {
    if (before.kind != after.kind) {
      throw ArgumentError.value(
        after,
        'after',
        'element update kind does not match the target element.',
      );
    }
    if (_sameElement(before, after)) {
      return null;
    }
    _validateElementResourceReferences(after, resourceIds);

    return _withSameFamilyElement(after);
  }

  // The lookup deliberately checks every family table in one place so missing
  // ids fail at the caller-owned admission boundary.
  // ignore: cyclomatic-complexity
  CanvasElement elementById(String id) {
    return imageRows[id]?.toElement() ??
        pathRows[id]?.toElement() ??
        textRows[id]?.toElement() ??
        strokeRows[id]?.toElement() ??
        lineRows[id]?.toElement() ??
        rectRows[id]!.toElement();
  }

  Set<String> get admittedElementIds {
    return {
      ...imageRows.keys,
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
        CanvasElementKind.rect => rectRows[common.id.value]?.size,
        _ => null,
      },
      naturalSize: imageRows[common.id.value]?.naturalSize,
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
        pathRows[id]?.common ??
        textRows[id]?.common ??
        strokeRows[id]?.common ??
        lineRows[id]?.common ??
        rectRows[id]?.common;
  }

  _AdmittedRows _copyRows() {
    return _AdmittedRows()
      ..imageRows.addAll(imageRows)
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
        pathRows: pathRows,
        textRows: textRows,
        strokeRows: strokeRows,
        lineRows: lineRows,
        rectRows: rectRows,
      ),
      CanvasPathElement() => FamilyTables._fromTables(
        imageRows: imageRows,
        pathRows: Map.unmodifiable(Map.of(pathRows)..[id] = PathRow(element)),
        textRows: textRows,
        strokeRows: strokeRows,
        lineRows: lineRows,
        rectRows: rectRows,
      ),
      CanvasTextElement() => FamilyTables._fromTables(
        imageRows: imageRows,
        pathRows: pathRows,
        textRows: Map.unmodifiable(Map.of(textRows)..[id] = TextRow(element)),
        strokeRows: strokeRows,
        lineRows: lineRows,
        rectRows: rectRows,
      ),
      CanvasStrokeElement() => FamilyTables._fromTables(
        imageRows: imageRows,
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
        pathRows: pathRows,
        textRows: textRows,
        strokeRows: strokeRows,
        lineRows: Map.unmodifiable(Map.of(lineRows)..[id] = LineRow(element)),
        rectRows: rectRows,
      ),
      CanvasRectElement() => FamilyTables._fromTables(
        imageRows: imageRows,
        pathRows: pathRows,
        textRows: textRows,
        strokeRows: strokeRows,
        lineRows: lineRows,
        rectRows: Map.unmodifiable(Map.of(rectRows)..[id] = RectRow(element)),
      ),
    };
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
  final Map<String, PathRow> pathRows = {};
  final Map<String, TextRow> textRows = {};
  final Map<String, StrokeRow> strokeRows = {};
  final Map<String, LineRow> lineRows = {};
  final Map<String, RectRow> rectRows = {};
  final Set<String> ids = {};

  void add(CanvasElement element, Set<String> resourceIds) {
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
        if (!resourceIds.contains(element.resourceId.value)) {
          throw CanvasDataException(
            code: CanvasDataErrorCode.missingResourceReference,
            message: 'image element references a missing resource.',
            path: 'image.resourceId',
          );
        }
        imageRows[id] = ImageRow(element);
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

  void remove(String id) {
    if (!ids.remove(id)) {
      return;
    }
    imageRows.remove(id);
    pathRows.remove(id);
    textRows.remove(id);
    strokeRows.remove(id);
    lineRows.remove(id);
    rectRows.remove(id);
  }
}

_AdmittedRows _admitElements(
  Iterable<CanvasElement> elements,
  Set<String> resourceIds,
) {
  final admitted = _AdmittedRows();
  for (final element in elements) {
    admitted.add(element, resourceIds);
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

final class PathRow {
  PathRow(CanvasPathElement element)
    : common = ElementCommonRow(element),
      svgPathData = element.svgPathData,
      fillColor = element.fillColor,
      strokeColor = element.strokeColor,
      strokeWidth = element.strokeWidth,
      fillRule = element.fillRule;

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

void _validateElementResourceReferences(
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

// Equality for no-op detection intentionally mirrors all public element
// families in one place so a missed field cannot silently create commits.
// ignore: cyclomatic-complexity, halstead-volume, source-lines-of-code
bool _sameElement(CanvasElement left, CanvasElement right) {
  if (!_sameCommonElementFields(left, right)) {
    return false;
  }

  return switch ((left, right)) {
    (final CanvasImageElement left, final CanvasImageElement right) =>
      left.resourceId == right.resourceId &&
          left.size == right.size &&
          left.naturalSize == right.naturalSize,
    (final CanvasPathElement left, final CanvasPathElement right) =>
      left.svgPathData == right.svgPathData &&
          left.fillColor == right.fillColor &&
          left.strokeColor == right.strokeColor &&
          left.strokeWidth == right.strokeWidth &&
          left.fillRule == right.fillRule,
    (final CanvasTextElement left, final CanvasTextElement right) =>
      left.text == right.text &&
          left.fontSize == right.fontSize &&
          left.color == right.color &&
          left.align == right.align &&
          left.textDirection == right.textDirection &&
          left.isBold == right.isBold &&
          left.isItalic == right.isItalic &&
          left.isUnderline == right.isUnderline &&
          left.fontFamily == right.fontFamily &&
          left.maxWidth == right.maxWidth &&
          left.lineHeight == right.lineHeight,
    (final CanvasStrokeElement left, final CanvasStrokeElement right) =>
      _sameList(left.points, right.points) &&
          left.thickness == right.thickness &&
          left.color == right.color,
    (final CanvasLineElement left, final CanvasLineElement right) =>
      left.start == right.start &&
          left.end == right.end &&
          left.thickness == right.thickness &&
          left.color == right.color,
    (final CanvasRectElement left, final CanvasRectElement right) =>
      left.size == right.size &&
          left.fillColor == right.fillColor &&
          left.strokeColor == right.strokeColor &&
          left.strokeWidth == right.strokeWidth,
    _ => false,
  };
}

// Common-field comparison stays whole because these fields are shared by every
// element family and define whether an update is a real sparse-store change.
// ignore: cyclomatic-complexity
bool _sameCommonElementFields(CanvasElement left, CanvasElement right) {
  return left.id == right.id &&
      left.kind == right.kind &&
      left.transform == right.transform &&
      left.opacity == right.opacity &&
      left.hitPadding == right.hitPadding &&
      left.isVisible == right.isVisible &&
      left.isSelectable == right.isSelectable &&
      left.isLocked == right.isLocked &&
      left.isDeletable == right.isDeletable &&
      left.isTransformable == right.isTransformable &&
      left.metadata == right.metadata;
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
