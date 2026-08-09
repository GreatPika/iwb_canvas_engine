import 'dart:ui';

import 'canvas_contract_limits.dart';
import 'canvas_element.dart';
import 'canvas_errors.dart';
import 'canvas_field_update.dart';
import 'canvas_geometry.dart';
import 'canvas_ids.dart';
import 'canvas_metadata.dart';
import 'canvas_transform_admission.dart';
import 'canvas_value_validators.dart';

/// Public API v1 declaration for [CanvasElementUpdate].
sealed class CanvasElementUpdate {
  CanvasElementUpdate({
    required this.id,
    this.transform = const CanvasFieldUpdate.absent(),
    this.opacity = const CanvasFieldUpdate.absent(),
    this.hitPadding = const CanvasFieldUpdate.absent(),
    this.isVisible = const CanvasFieldUpdate.absent(),
    this.isSelectable = const CanvasFieldUpdate.absent(),
    this.isLocked = const CanvasFieldUpdate.absent(),
    this.isDeletable = const CanvasFieldUpdate.absent(),
    this.isTransformable = const CanvasFieldUpdate.absent(),
    this.metadata = const CanvasFieldUpdate.absent(),
  }) {
    _validateSet(transform, (value) {
      validateElementTransformAdmission(value, path: 'update.transform');
    });
    _validateSet(opacity, (value) {
      validateDoubleRange(value, path: 'update.opacity', min: 0, max: 1);
    });
    _validateSet(hitPadding, (value) {
      validateNonNegativeDouble(
        value,
        path: 'update.hitPadding',
        max: canvasMaxHitPadding,
      );
    });
  }

  final CanvasElementId id;
  final CanvasFieldUpdate<CanvasTransform> transform;
  final CanvasFieldUpdate<double> opacity;
  final CanvasFieldUpdate<double> hitPadding;
  final CanvasFieldUpdate<bool> isVisible;
  final CanvasFieldUpdate<bool> isSelectable;
  final CanvasFieldUpdate<bool> isLocked;
  final CanvasFieldUpdate<bool> isDeletable;
  final CanvasFieldUpdate<bool> isTransformable;
  final CanvasFieldUpdate<CanvasMetadata> metadata;
}

/// Public API v1 declaration for [CanvasImageElementUpdate].
final class CanvasImageElementUpdate extends CanvasElementUpdate {
  CanvasImageElementUpdate({
    required super.id,
    super.transform,
    super.opacity,
    super.hitPadding,
    super.isVisible,
    super.isSelectable,
    super.isLocked,
    super.isDeletable,
    super.isTransformable,
    super.metadata,
    this.resourceId = const CanvasFieldUpdate.absent(),
    this.size = const CanvasFieldUpdate.absent(),
    this.naturalSize = const CanvasFieldUpdate.absent(),
  }) {
    _validateSet(size, (value) => validateSize(value, path: 'image.size'));
    _validateSet(naturalSize, (value) {
      if (value != null) {
        validateSize(value, path: 'image.naturalSize');
      }
    });
  }

  final CanvasFieldUpdate<CanvasResourceId> resourceId;
  final CanvasFieldUpdate<Size> size;
  final CanvasFieldUpdate<Size?> naturalSize;
}

/// Public API v1 declaration for [CanvasVectorElementUpdate].
final class CanvasVectorElementUpdate extends CanvasElementUpdate {
  CanvasVectorElementUpdate({
    required super.id,
    super.transform,
    super.opacity,
    super.hitPadding,
    super.isVisible,
    super.isSelectable,
    super.isLocked,
    super.isDeletable,
    super.isTransformable,
    super.metadata,
    this.resourceId = const CanvasFieldUpdate.absent(),
    this.size = const CanvasFieldUpdate.absent(),
    this.naturalSize = const CanvasFieldUpdate.absent(),
  }) {
    _validateSet(size, (value) => validateSize(value, path: 'vector.size'));
    _validateSet(naturalSize, (value) {
      if (value != null) {
        validateSize(value, path: 'vector.naturalSize');
      }
    });
  }

  final CanvasFieldUpdate<CanvasResourceId> resourceId;
  final CanvasFieldUpdate<Size> size;
  final CanvasFieldUpdate<Size?> naturalSize;
}

/// Public API v1 declaration for [CanvasPathElementUpdate].
final class CanvasPathElementUpdate extends CanvasElementUpdate {
  CanvasPathElementUpdate({
    required super.id,
    super.transform,
    super.opacity,
    super.hitPadding,
    super.isVisible,
    super.isSelectable,
    super.isLocked,
    super.isDeletable,
    super.isTransformable,
    super.metadata,
    this.svgPathData = const CanvasFieldUpdate.absent(),
    this.fillColor = const CanvasFieldUpdate.absent(),
    this.strokeColor = const CanvasFieldUpdate.absent(),
    this.strokeWidth = const CanvasFieldUpdate.absent(),
    this.fillRule = const CanvasFieldUpdate.absent(),
  }) {
    _validateSet(svgPathData, _validateSvgPathData);
    _validateSet(strokeWidth, (value) {
      validateNonNegativeDouble(
        value,
        path: 'path.strokeWidth',
        max: canvasMaxThickness,
      );
    });
  }

  final CanvasFieldUpdate<String> svgPathData;
  final CanvasFieldUpdate<Color?> fillColor;
  final CanvasFieldUpdate<Color?> strokeColor;
  final CanvasFieldUpdate<double> strokeWidth;
  final CanvasFieldUpdate<CanvasPathFillRule> fillRule;
}

/// Public API v1 declaration for [CanvasTextElementUpdate].
final class CanvasTextElementUpdate extends CanvasElementUpdate {
  CanvasTextElementUpdate({
    required super.id,
    super.transform,
    super.opacity,
    super.hitPadding,
    super.isVisible,
    super.isSelectable,
    super.isLocked,
    super.isDeletable,
    super.isTransformable,
    super.metadata,
    this.text = const CanvasFieldUpdate.absent(),
    this.fontSize = const CanvasFieldUpdate.absent(),
    this.color = const CanvasFieldUpdate.absent(),
    this.align = const CanvasFieldUpdate.absent(),
    this.textDirection = const CanvasFieldUpdate.absent(),
    this.isBold = const CanvasFieldUpdate.absent(),
    this.isItalic = const CanvasFieldUpdate.absent(),
    this.isUnderline = const CanvasFieldUpdate.absent(),
    this.fontFamily = const CanvasFieldUpdate.absent(),
    this.maxWidth = const CanvasFieldUpdate.absent(),
    this.lineHeight = const CanvasFieldUpdate.absent(),
  }) {
    _validateSet(text, _validateText);
    _validateSet(fontSize, (value) {
      validatePositiveDouble(
        value,
        path: 'text.fontSize',
        max: canvasMaxThickness,
      );
    });
    _validateSet(fontFamily, _validateNullableFontFamily);
    _validateSet(maxWidth, _validateNullablePositiveDimension('text.maxWidth'));
    _validateSet(
      lineHeight,
      _validateNullablePositiveDimension('text.lineHeight'),
    );
  }

  final CanvasFieldUpdate<String> text;
  final CanvasFieldUpdate<double> fontSize;
  final CanvasFieldUpdate<Color> color;
  final CanvasFieldUpdate<TextAlign> align;
  final CanvasFieldUpdate<TextDirection> textDirection;
  final CanvasFieldUpdate<bool> isBold;
  final CanvasFieldUpdate<bool> isItalic;
  final CanvasFieldUpdate<bool> isUnderline;
  final CanvasFieldUpdate<String?> fontFamily;
  final CanvasFieldUpdate<double?> maxWidth;
  final CanvasFieldUpdate<double?> lineHeight;
}

/// Public API v1 declaration for [CanvasStrokeElementUpdate].
final class CanvasStrokeElementUpdate extends CanvasElementUpdate {
  CanvasStrokeElementUpdate({
    required super.id,
    super.transform,
    super.opacity,
    super.hitPadding,
    super.isVisible,
    super.isSelectable,
    super.isLocked,
    super.isDeletable,
    super.isTransformable,
    super.metadata,
    CanvasFieldUpdate<List<Offset>> points = const CanvasFieldUpdate.absent(),
    this.thickness = const CanvasFieldUpdate.absent(),
    this.color = const CanvasFieldUpdate.absent(),
  }) : points = _freezeStrokePointsUpdate(points) {
    _validateSet(points, _validateStrokePoints);
    _validateSet(thickness, (value) {
      validatePositiveDouble(
        value,
        path: 'stroke.thickness',
        max: canvasMaxThickness,
      );
    });
  }

  final CanvasFieldUpdate<List<Offset>> points;
  final CanvasFieldUpdate<double> thickness;
  final CanvasFieldUpdate<Color> color;
}

/// Public API v1 declaration for [CanvasLineElementUpdate].
final class CanvasLineElementUpdate extends CanvasElementUpdate {
  CanvasLineElementUpdate({
    required super.id,
    super.transform,
    super.opacity,
    super.hitPadding,
    super.isVisible,
    super.isSelectable,
    super.isLocked,
    super.isDeletable,
    super.isTransformable,
    super.metadata,
    this.start = const CanvasFieldUpdate.absent(),
    this.end = const CanvasFieldUpdate.absent(),
    this.thickness = const CanvasFieldUpdate.absent(),
    this.color = const CanvasFieldUpdate.absent(),
  }) {
    _validateSet(start, (value) => validateOffset(value, path: 'line.start'));
    _validateSet(end, (value) => validateOffset(value, path: 'line.end'));
    _validateSet(thickness, (value) {
      validatePositiveDouble(
        value,
        path: 'line.thickness',
        max: canvasMaxThickness,
      );
    });
  }

  final CanvasFieldUpdate<Offset> start;
  final CanvasFieldUpdate<Offset> end;
  final CanvasFieldUpdate<double> thickness;
  final CanvasFieldUpdate<Color> color;
}

/// Public API v1 declaration for [CanvasRectElementUpdate].
final class CanvasRectElementUpdate extends CanvasElementUpdate {
  CanvasRectElementUpdate({
    required super.id,
    super.transform,
    super.opacity,
    super.hitPadding,
    super.isVisible,
    super.isSelectable,
    super.isLocked,
    super.isDeletable,
    super.isTransformable,
    super.metadata,
    this.size = const CanvasFieldUpdate.absent(),
    this.fillColor = const CanvasFieldUpdate.absent(),
    this.strokeColor = const CanvasFieldUpdate.absent(),
    this.strokeWidth = const CanvasFieldUpdate.absent(),
  }) {
    _validateSet(size, (value) => validateSize(value, path: 'rect.size'));
    _validateSet(strokeWidth, (value) {
      validateNonNegativeDouble(
        value,
        path: 'rect.strokeWidth',
        max: canvasMaxThickness,
      );
    });
  }

  final CanvasFieldUpdate<Size> size;
  final CanvasFieldUpdate<Color?> fillColor;
  final CanvasFieldUpdate<Color?> strokeColor;
  final CanvasFieldUpdate<double> strokeWidth;
}

void _validateSet<T>(
  CanvasFieldUpdate<T> update,
  void Function(T value) check,
) {
  if (update case CanvasFieldSet<Object>(:final value)) {
    check(value as T);
  }
}

void _validateSvgPathData(String value) {
  if (value.isEmpty) {
    throw CanvasDataException(
      code: CanvasDataErrorCode.fieldMustNotBeEmpty,
      message: 'path data must not be empty.',
      path: 'path.svgPathData',
    );
  }
  if (value.length > canvasMaxSvgPathDataLength) {
    throw CanvasDataException(
      code: CanvasDataErrorCode.fieldMaxLength,
      message: 'path data exceeds the maximum length.',
      path: 'path.svgPathData',
    );
  }
}

void _validateText(String value) {
  if (value.length > canvasMaxTextLength) {
    throw CanvasDataException(
      code: CanvasDataErrorCode.fieldMaxLength,
      message: 'text exceeds the maximum length.',
      path: 'text.text',
    );
  }
}

void _validateNullableFontFamily(String? value) {
  if (value != null &&
      (value.isEmpty || value.length > canvasMaxFontFamilyLength)) {
    throw CanvasDataException(
      code: CanvasDataErrorCode.fieldMaxLength,
      message: 'font family length is invalid.',
      path: 'text.fontFamily',
    );
  }
}

void Function(double?) _validateNullablePositiveDimension(String path) {
  return (value) {
    if (value != null) {
      validatePositiveDouble(value, path: path, max: canvasMaxPositiveSize);
    }
  };
}

void _validateStrokePoints(List<Offset> value) {
  if (value.isEmpty) {
    throw CanvasDataException(
      code: CanvasDataErrorCode.fieldMustNotBeEmpty,
      message: 'stroke points must not be empty.',
      path: 'stroke.points',
    );
  }
  if (value.length > canvasMaxStrokePointsPerElement) {
    throw CanvasDataException(
      code: CanvasDataErrorCode.maxItems,
      message: 'stroke points exceed the maximum count.',
      path: 'stroke.points',
    );
  }
  for (final point in value) {
    validateOffset(point, path: 'stroke.points');
  }
}

CanvasFieldUpdate<List<Offset>> _freezeStrokePointsUpdate(
  CanvasFieldUpdate<List<Offset>> update,
) {
  return switch (update) {
    CanvasFieldSet<List<Offset>>(:final value) => CanvasFieldSet(
      List<Offset>.unmodifiable(value),
    ),
    _ => update,
  };
}
