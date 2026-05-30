import 'dart:ui';

import '../contracts/internal/frame_facts_port.dart';
import '../contracts/public/canvas_element.dart';
import '../contracts/public/canvas_geometry.dart';
import '../contracts/public/canvas_ids.dart';
import '../geometry/geometry_policy.dart';

enum RenderElementFamily { image, path, text, stroke, line, rect }

sealed class RenderElementRow {
  const RenderElementRow();
}

final class ImageRenderRow extends RenderElementRow {
  const ImageRenderRow({
    required this.resourceId,
    required this.size,
    required this.naturalSize,
  });

  final CanvasResourceId resourceId;
  final Size size;
  final Size? naturalSize;
}

final class PathRenderRow extends RenderElementRow {
  const PathRenderRow({
    required this.pathDataKey,
    required this.fillColor,
    required this.strokeColor,
    required this.strokeWidth,
    required this.fillRule,
  });

  final String pathDataKey;
  final Color? fillColor;
  final Color? strokeColor;
  final double strokeWidth;
  final CanvasPathFillRule fillRule;
}

final class TextRenderRow extends RenderElementRow {
  const TextRenderRow({
    required this.text,
    required this.fontSize,
    required this.color,
    required this.align,
    required this.direction,
    required this.isBold,
    required this.isItalic,
    required this.isUnderline,
    required this.fontFamily,
    required this.maxWidth,
    required this.lineHeight,
  });

  final String text;
  final double fontSize;
  final Color color;
  final TextAlign align;
  final TextDirection direction;
  final bool isBold;
  final bool isItalic;
  final bool isUnderline;
  final String? fontFamily;
  final double? maxWidth;
  final double? lineHeight;
}

final class StrokeRenderRow extends RenderElementRow {
  const StrokeRenderRow({
    required this.pointsKey,
    required this.points,
    required this.thickness,
    required this.color,
  });

  final String pointsKey;
  final List<Offset> points;
  final double thickness;
  final Color color;
}

final class LineRenderRow extends RenderElementRow {
  const LineRenderRow({
    required this.start,
    required this.end,
    required this.thickness,
    required this.color,
  });

  final Offset start;
  final Offset end;
  final double thickness;
  final Color color;
}

final class RectRenderRow extends RenderElementRow {
  const RectRenderRow({
    required this.size,
    required this.fillColor,
    required this.strokeColor,
    required this.strokeWidth,
  });

  final Size size;
  final Color? fillColor;
  final Color? strokeColor;
  final double strokeWidth;
}

final class RenderElementRecord {
  const RenderElementRecord({
    required this.id,
    required this.family,
    required this.generation,
    required this.orderToken,
    required this.transform,
    required this.opacity,
    required this.primitiveAlpha,
    required this.paintBoundsWorld,
    required this.hitBoundsWorld,
    required this.resourceId,
    required this.row,
  });

  final CanvasElementId id;
  final RenderElementFamily family;
  final int generation;
  final int orderToken;
  final CanvasTransform transform;
  final double opacity;
  final int primitiveAlpha;
  final Rect paintBoundsWorld;
  final Rect hitBoundsWorld;
  final CanvasResourceId? resourceId;
  final RenderElementRow row;

  bool get requiresSaveLayer => false;

  factory RenderElementRecord.fromFacts(
    FrameElementFacts facts, {
    GeometryPolicy geometryPolicy = const GeometryPolicy(),
  }) {
    final bounds = geometryPolicy.boundsFor(facts);

    return RenderElementRecord(
      id: facts.id,
      family: _familyFor(facts.kind),
      generation: facts.generation,
      orderToken: facts.orderToken,
      transform: facts.transform,
      opacity: facts.opacity,
      primitiveAlpha: _primitiveAlpha(facts.opacity),
      paintBoundsWorld: bounds.paintBoundsWorld,
      hitBoundsWorld: bounds.hitBoundsWorld,
      resourceId: facts.resourceId,
      row: _rowFor(facts),
    );
  }
}

RenderElementFamily _familyFor(CanvasElementKind kind) {
  return switch (kind) {
    CanvasElementKind.image => RenderElementFamily.image,
    CanvasElementKind.path => RenderElementFamily.path,
    CanvasElementKind.text => RenderElementFamily.text,
    CanvasElementKind.stroke => RenderElementFamily.stroke,
    CanvasElementKind.line => RenderElementFamily.line,
    CanvasElementKind.rect => RenderElementFamily.rect,
  };
}

RenderElementRow _rowFor(FrameElementFacts facts) {
  return switch (facts.kind) {
    CanvasElementKind.image => _imageRow(facts),
    CanvasElementKind.path => _pathRow(facts),
    CanvasElementKind.text => _textRow(facts),
    CanvasElementKind.stroke => _strokeRow(facts),
    CanvasElementKind.line => _lineRow(facts),
    CanvasElementKind.rect => _rectRow(facts),
  };
}

ImageRenderRow _imageRow(FrameElementFacts facts) {
  final resourceId = facts.resourceId;
  final size = facts.size;
  if (resourceId == null || size == null) {
    throw StateError('Image render rows require resourceId and size.');
  }

  return ImageRenderRow(
    resourceId: resourceId,
    size: size,
    naturalSize: facts.naturalSize,
  );
}

PathRenderRow _pathRow(FrameElementFacts facts) {
  final pathData = facts.svgPathData;
  if (pathData == null) {
    throw StateError('Path render rows require path data.');
  }

  return PathRenderRow(
    pathDataKey: pathData,
    fillColor: facts.fillColor,
    strokeColor: facts.strokeColor,
    strokeWidth: facts.strokeWidth ?? 0,
    fillRule: facts.fillRule ?? CanvasPathFillRule.nonZero,
  );
}

TextRenderRow _textRow(FrameElementFacts facts) {
  final text = facts.text;
  if (text == null) {
    throw StateError('Text render rows require text.');
  }

  return TextRenderRow(
    text: text,
    fontSize: facts.fontSize ?? 24,
    color: facts.textColor ?? const Color(0xFF000000),
    align: facts.textAlign ?? TextAlign.left,
    direction: facts.textDirection ?? TextDirection.ltr,
    isBold: facts.isBold ?? false,
    isItalic: facts.isItalic ?? false,
    isUnderline: facts.isUnderline ?? false,
    fontFamily: facts.fontFamily,
    maxWidth: facts.maxWidth,
    lineHeight: facts.lineHeight,
  );
}

StrokeRenderRow _strokeRow(FrameElementFacts facts) {
  return StrokeRenderRow(
    pointsKey: _pointsKey(facts.points),
    points: List.unmodifiable(facts.points),
    thickness: facts.thickness ?? 1,
    color: facts.color ?? const Color(0xFF000000),
  );
}

LineRenderRow _lineRow(FrameElementFacts facts) {
  final start = facts.start;
  final end = facts.end;
  if (start == null || end == null) {
    throw StateError('Line render rows require start and end points.');
  }

  return LineRenderRow(
    start: start,
    end: end,
    thickness: facts.thickness ?? 1,
    color: facts.color ?? const Color(0xFF000000),
  );
}

RectRenderRow _rectRow(FrameElementFacts facts) {
  final size = facts.size;
  if (size == null) {
    throw StateError('Rect render rows require size.');
  }

  return RectRenderRow(
    size: size,
    fillColor: facts.fillColor,
    strokeColor: facts.strokeColor,
    strokeWidth: facts.strokeWidth ?? 0,
  );
}

int _primitiveAlpha(double opacity) {
  return (opacity.clamp(0, 1) * 255).round();
}

String _pointsKey(List<Offset> points) {
  return points.map((point) => '${point.dx},${point.dy}').join(';');
}
