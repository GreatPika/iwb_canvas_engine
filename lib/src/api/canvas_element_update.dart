import 'dart:ui';

import 'canvas_document.dart';
import 'canvas_element.dart';
import 'canvas_field_update.dart';
import 'canvas_geometry.dart';
import 'canvas_ids.dart';

sealed class CanvasElementUpdate {
  const CanvasElementUpdate({
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
  });

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

final class CanvasImageElementUpdate extends CanvasElementUpdate {
  const CanvasImageElementUpdate({
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
  });

  final CanvasFieldUpdate<CanvasResourceId> resourceId;
  final CanvasFieldUpdate<Size> size;
  final CanvasFieldUpdate<Size?> naturalSize;
}

final class CanvasPathElementUpdate extends CanvasElementUpdate {
  const CanvasPathElementUpdate({
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
  });

  final CanvasFieldUpdate<String> svgPathData;
  final CanvasFieldUpdate<Color?> fillColor;
  final CanvasFieldUpdate<Color?> strokeColor;
  final CanvasFieldUpdate<double> strokeWidth;
  final CanvasFieldUpdate<CanvasPathFillRule> fillRule;
}

final class CanvasTextElementUpdate extends CanvasElementUpdate {
  const CanvasTextElementUpdate({
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
  });

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

final class CanvasStrokeElementUpdate extends CanvasElementUpdate {
  const CanvasStrokeElementUpdate({
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
    this.points = const CanvasFieldUpdate.absent(),
    this.thickness = const CanvasFieldUpdate.absent(),
    this.color = const CanvasFieldUpdate.absent(),
  });

  final CanvasFieldUpdate<List<Offset>> points;
  final CanvasFieldUpdate<double> thickness;
  final CanvasFieldUpdate<Color> color;
}

final class CanvasLineElementUpdate extends CanvasElementUpdate {
  const CanvasLineElementUpdate({
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
  });

  final CanvasFieldUpdate<Offset> start;
  final CanvasFieldUpdate<Offset> end;
  final CanvasFieldUpdate<double> thickness;
  final CanvasFieldUpdate<Color> color;
}

final class CanvasRectElementUpdate extends CanvasElementUpdate {
  const CanvasRectElementUpdate({
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
  });

  final CanvasFieldUpdate<Size> size;
  final CanvasFieldUpdate<Color?> fillColor;
  final CanvasFieldUpdate<Color?> strokeColor;
  final CanvasFieldUpdate<double> strokeWidth;
}
