import 'package:flutter/painting.dart';

import '../contracts/public/canvas_prepared_vector.dart';
import '../contracts/public/canvas_ids.dart';
import 'frame_drawable_policy.dart';
import 'paint_asset_binding_service.dart';
import 'render_element_record.dart';
import 'render_primitive_cache_snapshot.dart';

const _drawablePolicy = FrameDrawablePolicy();

void paintMainFrameRecord(
  Canvas canvas,
  RenderElementRecord record,
  Map<CanvasResourceId, FrameAssetBinding> assetBindings,
  RenderPrimitiveCacheSnapshot renderPrimitives,
) {
  switch (record.row) {
    case final ImageRenderRow row:
      _paintImageRecord(canvas, record, row, assetBindings);
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
    case final VectorRenderRow row:
      _paintVectorRecord(canvas, record, row, assetBindings);
  }
}

void _paintImageRecord(
  Canvas canvas,
  RenderElementRecord record,
  ImageRenderRow row,
  Map<CanvasResourceId, FrameAssetBinding> assetBindings,
) {
  final resourceId = record.resourceId;
  final asset = resourceId == null ? null : assetBindings[resourceId];
  _withRecordTransform(canvas, record, () {
    final localBounds = _localRectForSize(row.size);
    if (asset case final FrameImageAssetBinding imageAsset) {
      final image = imageAsset.image;
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

// Zero/partial/full alpha, clipping, transform, direct Picture draw, and
// restore form one ordered canvas transaction; splitting them would obscure
// the record-local layer and no-op guarantees.
// ignore: halstead-volume
void _paintVectorRecord(
  Canvas canvas,
  RenderElementRecord record,
  VectorRenderRow row,
  Map<CanvasResourceId, FrameAssetBinding> assetBindings,
) {
  if (record.primitiveAlpha == 0) {
    return;
  }
  final asset = assetBindings[row.resourceId];
  _withRecordTransform(canvas, record, () {
    final localBounds = _localRectForSize(row.size);
    if (asset is! FrameVectorAssetBinding) {
      _paintFallbackBounds(canvas, localBounds, record.primitiveAlpha);

      return;
    }
    final picture = liveCanvasPreparedVectorPicture(asset.prepared);
    final intrinsicSize = asset.prepared.intrinsicSize;
    canvas.save();
    canvas.clipRect(localBounds);
    if (record.requiresSaveLayer) {
      canvas.saveLayer(
        localBounds,
        Paint()..color = Color.fromARGB(record.primitiveAlpha, 255, 255, 255),
      );
    }
    canvas.translate(localBounds.left, localBounds.top);
    canvas.scale(
      localBounds.width / intrinsicSize.width,
      localBounds.height / intrinsicSize.height,
    );
    canvas.drawPicture(picture);
    if (record.requiresSaveLayer) {
      canvas.restore();
    }
    canvas.restore();
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
