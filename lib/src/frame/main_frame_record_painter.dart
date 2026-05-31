import 'dart:ui'
    show
        BlendMode,
        Canvas,
        Color,
        ColorFilter,
        Image,
        Offset,
        Paint,
        PathFillType,
        PaintingStyle,
        PointMode,
        Rect,
        Size;

import 'package:flutter/painting.dart';
import 'package:path_drawing/path_drawing.dart';

import '../contracts/public/canvas_element.dart';
import '../contracts/public/canvas_ids.dart';
import 'render_element_record.dart';

void paintMainFrameRecord(
  Canvas canvas,
  RenderElementRecord record,
  Map<CanvasResourceId, Image> imageBindings,
) {
  switch (record.row) {
    case final ImageRenderRow row:
      _paintImageRecord(canvas, record, row, imageBindings);
    case final RectRenderRow row:
      _paintRectRecord(canvas, record, row);
    case final PathRenderRow row:
      _paintPathRecord(canvas, record, row);
    case final TextRenderRow row:
      _paintTextRecord(canvas, record, row);
    case final StrokeRenderRow row:
      _paintStrokeRecord(canvas, record, row);
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
) {
  _withRecordTransform(canvas, record, () {
    final path = parseSvgPathData(row.pathDataKey)
      ..fillType = switch (row.fillRule) {
        CanvasPathFillRule.evenOdd => PathFillType.evenOdd,
        CanvasPathFillRule.nonZero => PathFillType.nonZero,
      };
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
) {
  _withRecordTransform(canvas, record, () {
    final painter = TextPainter(
      text: TextSpan(
        text: row.text,
        style: TextStyle(
          color: _withElementOpacity(row.color, record.primitiveAlpha),
          fontSize: row.fontSize,
          fontFamily: row.fontFamily,
          fontWeight: row.isBold ? FontWeight.bold : FontWeight.normal,
          fontStyle: row.isItalic ? FontStyle.italic : FontStyle.normal,
          decoration: row.isUnderline ? TextDecoration.underline : null,
          height: row.lineHeight,
        ),
      ),
      textAlign: row.align,
      textDirection: row.direction,
    )..layout(maxWidth: row.maxWidth ?? double.infinity);
    final localBounds = Rect.fromCenter(
      center: Offset.zero,
      width: painter.width,
      height: painter.height,
    );
    painter.paint(canvas, localBounds.topLeft);
  });
}

void _paintStrokeRecord(
  Canvas canvas,
  RenderElementRecord record,
  StrokeRenderRow row,
) {
  _withRecordTransform(canvas, record, () {
    canvas.drawPoints(
      PointMode.polygon,
      row.points,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = row.thickness
        ..color = _withElementOpacity(row.color, record.primitiveAlpha),
    );
  });
}

void _paintLineRecord(
  Canvas canvas,
  RenderElementRecord record,
  LineRenderRow row,
) {
  _withRecordTransform(canvas, record, () {
    canvas.drawLine(
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
