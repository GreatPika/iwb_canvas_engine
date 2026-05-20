import 'dart:ui';

import 'canvas_contract_limits.dart';
import 'canvas_document.dart';
import 'canvas_errors.dart';
import 'canvas_geometry.dart';
import 'canvas_ids.dart';
import 'canvas_value_validators.dart';

enum CanvasElementKind { image, path, text, stroke, line, rect }

enum CanvasPathFillRule { nonZero, evenOdd }

sealed class CanvasElement {
  CanvasElement({
    required this.id,
    this.revision = 0,
    this.transform = CanvasTransform.identity,
    this.opacity = 1.0,
    this.hitPadding = 0.0,
    this.isVisible = true,
    this.isSelectable = true,
    this.isLocked = false,
    this.isDeletable = true,
    this.isTransformable = true,
    this.metadata = const CanvasMetadata.empty(),
  }) {
    validateNonNegativeInt(revision, path: 'element.revision');
    validateElementTransformAdmission(transform, path: 'element.transform');
    validateDoubleRange(opacity, path: 'element.opacity', min: 0, max: 1);
    validateNonNegativeDouble(
      hitPadding,
      path: 'element.hitPadding',
      max: canvasMaxHitPadding,
    );
  }

  final CanvasElementId id;
  CanvasElementKind get kind;
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

final class CanvasImageElement extends CanvasElement {
  CanvasImageElement({
    required super.id,
    required this.resourceId,
    required this.size,
    this.naturalSize,
    super.revision,
    super.transform,
    super.opacity,
    super.hitPadding,
    super.isVisible,
    super.isSelectable,
    super.isLocked,
    super.isDeletable,
    super.isTransformable,
    super.metadata,
  }) {
    validateSize(size, path: 'image.size');
    final naturalSize = this.naturalSize;
    if (naturalSize != null) {
      validateSize(naturalSize, path: 'image.naturalSize');
    }
  }

  final CanvasResourceId resourceId;
  final Size size;
  final Size? naturalSize;
  @override
  CanvasElementKind get kind => CanvasElementKind.image;
}

final class CanvasPathElement extends CanvasElement {
  CanvasPathElement({
    required super.id,
    required this.svgPathData,
    this.fillColor,
    this.strokeColor,
    this.strokeWidth = 0.0,
    this.fillRule = CanvasPathFillRule.nonZero,
    super.revision,
    super.transform,
    super.opacity,
    super.hitPadding,
    super.isVisible,
    super.isSelectable,
    super.isLocked,
    super.isDeletable,
    super.isTransformable,
    super.metadata,
  }) {
    if (svgPathData.isEmpty) {
      throw CanvasDataException(
        code: CanvasDataErrorCode.fieldMustNotBeEmpty,
        message: 'path data must not be empty.',
        path: 'path.svgPathData',
      );
    }
    if (svgPathData.length > canvasMaxSvgPathDataLength) {
      throw CanvasDataException(
        code: CanvasDataErrorCode.fieldMaxLength,
        message: 'path data exceeds the maximum length.',
        path: 'path.svgPathData',
      );
    }
    validateNonNegativeDouble(
      strokeWidth,
      path: 'path.strokeWidth',
      max: canvasMaxThickness,
    );
  }

  final String svgPathData;
  final Color? fillColor;
  final Color? strokeColor;
  final double strokeWidth;
  final CanvasPathFillRule fillRule;
  @override
  CanvasElementKind get kind => CanvasElementKind.path;
}

final class CanvasTextElement extends CanvasElement {
  CanvasTextElement({
    required super.id,
    required this.text,
    required this.color,
    required this.textDirection,
    this.fontSize = 24.0,
    this.align = TextAlign.left,
    this.isBold = false,
    this.isItalic = false,
    this.isUnderline = false,
    this.fontFamily,
    this.maxWidth,
    this.lineHeight,
    super.revision,
    super.transform,
    super.opacity,
    super.hitPadding,
    super.isVisible,
    super.isSelectable,
    super.isLocked,
    super.isDeletable,
    super.isTransformable,
    super.metadata,
  }) {
    if (text.length > canvasMaxTextLength) {
      throw CanvasDataException(
        code: CanvasDataErrorCode.fieldMaxLength,
        message: 'text exceeds the maximum length.',
        path: 'text.text',
      );
    }
    validatePositiveDouble(
      fontSize,
      path: 'text.fontSize',
      max: canvasMaxThickness,
    );
    final fontFamily = this.fontFamily;
    if (fontFamily != null &&
        (fontFamily.isEmpty || fontFamily.length > canvasMaxFontFamilyLength)) {
      throw CanvasDataException(
        code: CanvasDataErrorCode.fieldMaxLength,
        message: 'font family length is invalid.',
        path: 'text.fontFamily',
      );
    }
    final maxWidth = this.maxWidth;
    if (maxWidth != null) {
      validatePositiveDouble(
        maxWidth,
        path: 'text.maxWidth',
        max: canvasMaxPositiveSize,
      );
    }
    final lineHeight = this.lineHeight;
    if (lineHeight != null) {
      validatePositiveDouble(
        lineHeight,
        path: 'text.lineHeight',
        max: canvasMaxPositiveSize,
      );
    }
  }

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
  @override
  CanvasElementKind get kind => CanvasElementKind.text;
}

final class CanvasStrokeElement extends CanvasElement {
  CanvasStrokeElement({
    required super.id,
    required Iterable<Offset> points,
    required this.thickness,
    required this.color,
    super.revision,
    super.transform,
    super.opacity,
    super.hitPadding,
    super.isVisible,
    super.isSelectable,
    super.isLocked,
    super.isDeletable,
    super.isTransformable,
    super.metadata,
  }) : _points = List.unmodifiable(points) {
    if (_points.isEmpty) {
      throw CanvasDataException(
        code: CanvasDataErrorCode.fieldMustNotBeEmpty,
        message: 'stroke points must not be empty.',
        path: 'stroke.points',
      );
    }
    if (_points.length > canvasMaxStrokePointsPerElement) {
      throw CanvasDataException(
        code: CanvasDataErrorCode.maxItems,
        message: 'stroke points exceed the maximum count.',
        path: 'stroke.points',
      );
    }
    for (final point in _points) {
      validateOffset(point, path: 'stroke.points');
    }
    validatePositiveDouble(
      thickness,
      path: 'stroke.thickness',
      max: canvasMaxThickness,
    );
  }

  final List<Offset> _points;
  List<Offset> get points => _points;
  final double thickness;
  final Color color;
  @override
  CanvasElementKind get kind => CanvasElementKind.stroke;
}

final class CanvasLineElement extends CanvasElement {
  CanvasLineElement({
    required super.id,
    required this.start,
    required this.end,
    required this.thickness,
    required this.color,
    super.revision,
    super.transform,
    super.opacity,
    super.hitPadding,
    super.isVisible,
    super.isSelectable,
    super.isLocked,
    super.isDeletable,
    super.isTransformable,
    super.metadata,
  }) {
    validateOffset(start, path: 'line.start');
    validateOffset(end, path: 'line.end');
    validatePositiveDouble(
      thickness,
      path: 'line.thickness',
      max: canvasMaxThickness,
    );
  }

  final Offset start;
  final Offset end;
  final double thickness;
  final Color color;
  @override
  CanvasElementKind get kind => CanvasElementKind.line;
}

final class CanvasRectElement extends CanvasElement {
  CanvasRectElement({
    required super.id,
    required this.size,
    this.fillColor,
    this.strokeColor,
    this.strokeWidth = 0.0,
    super.revision,
    super.transform,
    super.opacity,
    super.hitPadding,
    super.isVisible,
    super.isSelectable,
    super.isLocked,
    super.isDeletable,
    super.isTransformable,
    super.metadata,
  }) {
    validateSize(size, path: 'rect.size');
    validateNonNegativeDouble(
      strokeWidth,
      path: 'rect.strokeWidth',
      max: canvasMaxThickness,
    );
  }

  final Size size;
  final Color? fillColor;
  final Color? strokeColor;
  final double strokeWidth;
  @override
  CanvasElementKind get kind => CanvasElementKind.rect;
}
