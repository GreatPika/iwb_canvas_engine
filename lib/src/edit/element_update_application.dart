import '../contracts/public/canvas_element.dart';
import '../contracts/public/canvas_element_update.dart';
import '../contracts/public/canvas_errors.dart';
import '../contracts/public/canvas_field_update.dart';
import '../contracts/public/canvas_geometry.dart';
import '../contracts/public/canvas_metadata.dart';

bool elementUpdateMatchesKind(
  CanvasElement element,
  CanvasElementUpdate update,
) {
  return switch ((element, update)) {
    (CanvasImageElement(), CanvasImageElementUpdate()) => true,
    (CanvasPathElement(), CanvasPathElementUpdate()) => true,
    (CanvasTextElement(), CanvasTextElementUpdate()) => true,
    (CanvasStrokeElement(), CanvasStrokeElementUpdate()) => true,
    (CanvasLineElement(), CanvasLineElementUpdate()) => true,
    (CanvasRectElement(), CanvasRectElementUpdate()) => true,
    _ => false,
  };
}

CanvasElement? updatedElementFor(
  CanvasElement element,
  CanvasElementUpdate update,
) {
  final common = _CommonUpdate.apply(element, update);
  final updated = switch ((element, update)) {
    (final CanvasImageElement element, final CanvasImageElementUpdate update) =>
      _updatedImageElement(element, update, common),
    (final CanvasPathElement element, final CanvasPathElementUpdate update) =>
      _updatedPathElement(element, update, common),
    (final CanvasTextElement element, final CanvasTextElementUpdate update) =>
      _updatedTextElement(element, update, common),
    (
      final CanvasStrokeElement element,
      final CanvasStrokeElementUpdate update,
    ) =>
      _updatedStrokeElement(element, update, common),
    (final CanvasLineElement element, final CanvasLineElementUpdate update) =>
      _updatedLineElement(element, update, common),
    (final CanvasRectElement element, final CanvasRectElementUpdate update) =>
      _updatedRectElement(element, update, common),
    _ => null,
  };

  return updated != null && !sameCanvasElement(element, updated)
      ? updated
      : null;
}

// Equality for no-op detection intentionally mirrors all public element
// families in one audited place so sparse and materialized edit paths cannot
// silently disagree on a missed field.
// ignore: cyclomatic-complexity, halstead-volume, source-lines-of-code
bool sameCanvasElement(CanvasElement left, CanvasElement right) {
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

CanvasImageElement _updatedImageElement(
  CanvasImageElement element,
  CanvasImageElementUpdate update,
  _CommonUpdate common,
) {
  return CanvasImageElement(
    id: element.id,
    resourceId: _requiredField(update.resourceId, element.resourceId),
    size: _requiredField(update.size, element.size),
    naturalSize: _nullableField(update.naturalSize, element.naturalSize),
    revision: element.revision + 1,
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

CanvasPathElement _updatedPathElement(
  CanvasPathElement element,
  CanvasPathElementUpdate update,
  _CommonUpdate common,
) {
  return CanvasPathElement(
    id: element.id,
    svgPathData: _requiredField(update.svgPathData, element.svgPathData),
    fillColor: _nullableField(update.fillColor, element.fillColor),
    strokeColor: _nullableField(update.strokeColor, element.strokeColor),
    strokeWidth: _requiredField(update.strokeWidth, element.strokeWidth),
    fillRule: _requiredField(update.fillRule, element.fillRule),
    revision: element.revision + 1,
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

// Text updates carry the full text field surface in one constructor call so
// omitted and nullable fields cannot drift from public DTO semantics.
// ignore: halstead-volume
CanvasTextElement _updatedTextElement(
  CanvasTextElement element,
  CanvasTextElementUpdate update,
  _CommonUpdate common,
) {
  return CanvasTextElement(
    id: element.id,
    text: _requiredField(update.text, element.text),
    color: _requiredField(update.color, element.color),
    textDirection: _requiredField(update.textDirection, element.textDirection),
    fontSize: _requiredField(update.fontSize, element.fontSize),
    align: _requiredField(update.align, element.align),
    isBold: _requiredField(update.isBold, element.isBold),
    isItalic: _requiredField(update.isItalic, element.isItalic),
    isUnderline: _requiredField(update.isUnderline, element.isUnderline),
    fontFamily: _nullableField(update.fontFamily, element.fontFamily),
    maxWidth: _nullableField(update.maxWidth, element.maxWidth),
    lineHeight: _nullableField(update.lineHeight, element.lineHeight),
    revision: element.revision + 1,
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

CanvasStrokeElement _updatedStrokeElement(
  CanvasStrokeElement element,
  CanvasStrokeElementUpdate update,
  _CommonUpdate common,
) {
  return CanvasStrokeElement(
    id: element.id,
    points: _requiredListField(update.points, element.points),
    thickness: _requiredField(update.thickness, element.thickness),
    color: _requiredField(update.color, element.color),
    revision: element.revision + 1,
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

CanvasLineElement _updatedLineElement(
  CanvasLineElement element,
  CanvasLineElementUpdate update,
  _CommonUpdate common,
) {
  return CanvasLineElement(
    id: element.id,
    start: _requiredField(update.start, element.start),
    end: _requiredField(update.end, element.end),
    thickness: _requiredField(update.thickness, element.thickness),
    color: _requiredField(update.color, element.color),
    revision: element.revision + 1,
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

CanvasRectElement _updatedRectElement(
  CanvasRectElement element,
  CanvasRectElementUpdate update,
  _CommonUpdate common,
) {
  return CanvasRectElement(
    id: element.id,
    size: _requiredField(update.size, element.size),
    fillColor: _nullableField(update.fillColor, element.fillColor),
    strokeColor: _nullableField(update.strokeColor, element.strokeColor),
    strokeWidth: _requiredField(update.strokeWidth, element.strokeWidth),
    revision: element.revision + 1,
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

final class _CommonUpdate {
  const _CommonUpdate({
    required this.transform,
    required this.opacity,
    required this.hitPadding,
    required this.isVisible,
    required this.isSelectable,
    required this.isLocked,
    required this.isDeletable,
    required this.isTransformable,
    required this.metadata,
  });

  factory _CommonUpdate.apply(
    CanvasElement element,
    CanvasElementUpdate update,
  ) {
    return _CommonUpdate(
      transform: _requiredField(update.transform, element.transform),
      opacity: _requiredField(update.opacity, element.opacity),
      hitPadding: _requiredField(update.hitPadding, element.hitPadding),
      isVisible: _requiredField(update.isVisible, element.isVisible),
      isSelectable: _requiredField(update.isSelectable, element.isSelectable),
      isLocked: _requiredField(update.isLocked, element.isLocked),
      isDeletable: _requiredField(update.isDeletable, element.isDeletable),
      isTransformable: _requiredField(
        update.isTransformable,
        element.isTransformable,
      ),
      metadata: _requiredField(update.metadata, element.metadata),
    );
  }

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

T _requiredField<T extends Object>(CanvasFieldUpdate<T> update, T current) {
  return switch (update) {
    CanvasFieldAbsent<T>() => current,
    CanvasFieldSet<T>(:final value) => value,
    _ => throw CanvasDataException(
      code: CanvasDataErrorCode.forbiddenField,
      message: 'non-nullable fields cannot be cleared.',
      path: 'update',
    ),
  };
}

T? _nullableField<T extends Object>(CanvasFieldUpdate<T?> update, T? current) {
  return switch (update) {
    CanvasFieldAbsent<T?>() => current,
    CanvasFieldSet<T>(:final value) => value,
    CanvasFieldClear<T>() => null,
    _ => current,
  };
}

List<T> _requiredListField<T extends Object>(
  CanvasFieldUpdate<List<T>> update,
  List<T> current,
) {
  return switch (update) {
    CanvasFieldAbsent<List<T>>() => current,
    CanvasFieldSet<List<T>>(:final value) => List.unmodifiable(value),
    _ => throw CanvasDataException(
      code: CanvasDataErrorCode.forbiddenField,
      message: 'non-nullable fields cannot be cleared.',
      path: 'update',
    ),
  };
}

// Common-field comparison stays whole because every element family shares
// these fields and no-op detection must not drift by family.
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
