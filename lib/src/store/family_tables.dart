import 'dart:ui';

// Family-specific row tables stay together so admission and projection cannot
// drift across element kinds; splitting them would obscure the shared id owner.
// ignore_for_file: type=metrics

import '../api/canvas_element.dart';
import '../api/canvas_errors.dart';
import '../api/canvas_geometry.dart';
import '../api/canvas_ids.dart';
import '../api/canvas_metadata.dart';
import '../api/canvas_resource.dart';

final class FamilyTables {
  FamilyTables(
    Iterable<CanvasElement> elements, {
    required Set<String> resourceIds,
  }) : this._(_admitElements(elements, resourceIds));

  FamilyTables._(_AdmittedRows admitted)
    : imageRows = Map.unmodifiable(admitted.imageRows),
      pathRows = Map.unmodifiable(admitted.pathRows),
      textRows = Map.unmodifiable(admitted.textRows),
      strokeRows = Map.unmodifiable(admitted.strokeRows),
      lineRows = Map.unmodifiable(admitted.lineRows),
      rectRows = Map.unmodifiable(admitted.rectRows);

  final Map<String, ImageRow> imageRows;
  final Map<String, PathRow> pathRows;
  final Map<String, TextRow> textRows;
  final Map<String, StrokeRow> strokeRows;
  final Map<String, LineRow> lineRows;
  final Map<String, RectRow> rectRows;

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

  ElementFrameFacts? elementFrameFacts(CanvasElementId id) {
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

  ElementFrameFacts? _imageFrameFacts(String id) {
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

  ElementFrameFacts? _commonFrameFacts(
    ElementCommonRow? common,
    CanvasElementKind kind, {
    CanvasResourceId? resourceId,
  }) {
    if (common == null) {
      return null;
    }

    return ElementFrameFacts(
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

  ElementCommonRow? _commonById(String id) {
    return imageRows[id]?.common ??
        pathRows[id]?.common ??
        textRows[id]?.common ??
        strokeRows[id]?.common ??
        lineRows[id]?.common ??
        rectRows[id]?.common;
  }
}

final class ElementFrameFacts {
  ElementFrameFacts({
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

CanvasResource copyResource(CanvasResource resource) {
  return switch (resource) {
    CanvasImageResource() => CanvasImageResource(
      id: resource.id,
      source: resource.source,
      mimeType: resource.mimeType,
      contentHash: resource.contentHash,
      byteLength: resource.byteLength,
      metadata: resource.metadata,
    ),
  };
}
