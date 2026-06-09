import 'dart:ui'
    show
        BlendMode,
        Canvas,
        Color,
        ColorFilter,
        Image,
        Offset,
        Paint,
        PaintingStyle,
        Rect,
        Size;

import 'package:flutter/painting.dart';

import '../contracts/public/canvas_ids.dart';
import 'frame_drawable_policy.dart';
import 'render_element_record.dart';
import 'render_primitive_cache_snapshot.dart';

const _drawablePolicy = FrameDrawablePolicy();

void paintMainFrameRecord(
  Canvas canvas,
  RenderElementRecord record,
  Map<CanvasResourceId, Image> imageBindings,
  RenderPrimitiveCacheSnapshot renderPrimitives,
) {
  switch (record.row) {
    case final ImageRenderRow row:
      _paintImageRecord(canvas, record, row, imageBindings);
    case final RectRenderRow row:
      _paintRectRecord(canvas, record, row);
    case final PathRenderRow row:
      _paintPathRecord(canvas, record, row, renderPrimitives);
    case final TextRenderRow row:
      _paintTextRecord(canvas, record, row, renderPrimitives);
    case final StrokeRenderRow row:
      _paintStrokeRecord(canvas, record, row, renderPrimitives);
    case final LineRenderRow row:
      _paintLineRecord(canvas, record, row);
  }
}

void _paintImageRecord(
  Canvas canvas,
  RenderElementRecord record,
  ImageRenderRow row,
  Map<CanvasResourceId, Image> imageBindings,
) {
  final resourceId = record.resourceId;
  final image = resourceId == null ? null : imageBindings[resourceId];
  _withRecordTransform(canvas, record, () {
    final localBounds = _localRectForSize(row.size);
    if (image != null) {
      canvas.drawImageRect(
        image,
        Offset.zero & Size(image.width.toDouble(), image.height.toDouble()),
        localBounds,
        _imagePaint(record.primitiveAlpha),
      );

      return;
    }
    _paintFallbackBounds(canvas, localBounds, record.primitiveAlpha);
  });
}

void _paintRectRecord(
  Canvas canvas,
  RenderElementRecord record,
  RectRenderRow row,
) {
  _withRecordTransform(canvas, record, () {
    final localBounds = _localRectForSize(row.size);
    final fill = row.fillColor;
    if (fill != null) {
      canvas.drawRect(
        localBounds,
        Paint()..color = _withElementOpacity(fill, record.primitiveAlpha),
      );
    }
    final stroke = row.strokeColor;
    if (stroke != null && row.strokeWidth > 0) {
      canvas.drawRect(
        localBounds,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = row.strokeWidth
          ..color = _withElementOpacity(stroke, record.primitiveAlpha),
      );
    }
  });
}

void _paintPathRecord(
  Canvas canvas,
  RenderElementRecord record,
  PathRenderRow row,
  RenderPrimitiveCacheSnapshot renderPrimitives,
) {
  _withRecordTransform(canvas, record, () {
    final path = renderPrimitives.paths[row.geometryCacheKey]?.path;
    if (path == null) {
      _paintFallbackBounds(
        canvas,
        record.paintBoundsLocal,
        record.primitiveAlpha,
      );

      return;
    }
    final fill = row.fillColor;
    if (fill != null) {
      canvas.drawPath(
        path,
        Paint()..color = _withElementOpacity(fill, record.primitiveAlpha),
      );
    }
    final stroke = row.strokeColor;
    if (stroke != null && row.strokeWidth > 0) {
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = row.strokeWidth
          ..color = _withElementOpacity(stroke, record.primitiveAlpha),
      );
    }
  });
}

void _paintTextRecord(
  Canvas canvas,
  RenderElementRecord record,
  TextRenderRow row,
  RenderPrimitiveCacheSnapshot renderPrimitives,
) {
  _withRecordTransform(canvas, record, () {
    final entry = renderPrimitives.textLayouts[row.layoutCacheKey];
    if (entry == null) {
      _paintFallbackBounds(
        canvas,
        record.paintBoundsLocal,
        record.primitiveAlpha,
      );

      return;
    }
    entry.painter.paint(canvas, entry.layout.paintBoundsLocal.topLeft);
  });
}

void _paintStrokeRecord(
  Canvas canvas,
  RenderElementRecord record,
  StrokeRenderRow row,
  RenderPrimitiveCacheSnapshot renderPrimitives,
) {
  _withRecordTransform(canvas, record, () {
    final path = renderPrimitives.strokes[row.strokeCacheKey]?.path;
    final painted = _drawablePolicy.paintCachedStroke(
      canvas: canvas,
      points: row.points,
      path: path,
      paint: Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = row.thickness
        ..color = _withElementOpacity(row.color, record.primitiveAlpha),
    );
    if (!painted) {
      _paintFallbackBounds(
        canvas,
        record.paintBoundsLocal,
        record.primitiveAlpha,
      );

      return;
    }
  });
}

void _paintLineRecord(
  Canvas canvas,
  RenderElementRecord record,
  LineRenderRow row,
) {
  _withRecordTransform(canvas, record, () {
    _drawablePolicy.paintLine(
      canvas,
      row.start,
      row.end,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = row.thickness
        ..color = _withElementOpacity(row.color, record.primitiveAlpha),
    );
  });
}

Paint _imagePaint(int primitiveAlpha) {
  if (primitiveAlpha >= 255) {
    return Paint();
  }

  return Paint()
    ..colorFilter = ColorFilter.mode(
      Color.fromARGB(primitiveAlpha, 255, 255, 255),
      BlendMode.modulate,
    );
}

Color _withElementOpacity(Color color, int primitiveAlpha) {
  final sourceAlpha = (color.toARGB32() >> 24) & 0xFF;
  final combinedAlpha = (sourceAlpha * primitiveAlpha / 255).round();

  return color.withAlpha(combinedAlpha);
}

void _withRecordTransform(
  Canvas canvas,
  RenderElementRecord record,
  VoidCallback paintLocalRecord,
) {
  canvas.save();
  canvas.transform(record.transform.toCanvasTransform());
  paintLocalRecord();
  canvas.restore();
}

Rect _localRectForSize(Size size) {
  return Rect.fromCenter(
    center: Offset.zero,
    width: size.width,
    height: size.height,
  );
}

void _paintFallbackBounds(Canvas canvas, Rect bounds, int primitiveAlpha) {
  canvas.drawRect(
    bounds,
    Paint()..color = Color.fromARGB(primitiveAlpha, 0, 0, 0),
  );
}
