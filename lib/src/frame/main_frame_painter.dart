import 'package:flutter/rendering.dart';

import '../contracts/public/canvas_ids.dart';
import '../resources/resource_resolver_adapter.dart';
import 'frame_paint_output.dart';
import 'render_element_record.dart';

final class MainFramePainter extends CustomPainter {
  const MainFramePainter({required this.output});

  final MainFramePaintOutput output;

  @override
  void paint(Canvas canvas, Size size) {
    final viewport = output.capturedFrame.snapshot.inputs.viewportWorldBounds;
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0x00000000),
    );
    canvas.save();
    canvas.translate(-viewport.left, -viewport.top);
    for (final record in output.selectedMoveSupplementPlan.mergedRecords) {
      _paintRecord(canvas, record, output.assetBindings.images);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant MainFramePainter oldDelegate) {
    return !identical(oldDelegate.output, output);
  }
}

void _paintRecord(
  Canvas canvas,
  RenderElementRecord record,
  Map<CanvasResourceId, ResourceImageResolveResult> imageBindings,
) {
  switch (record.row) {
    case ImageRenderRow():
      _paintImageRecord(canvas, record, imageBindings);
    case final RectRenderRow row:
      _paintRectRecord(canvas, record, row);
    case PathRenderRow() ||
        TextRenderRow() ||
        StrokeRenderRow() ||
        LineRenderRow():
      _paintFallbackBounds(canvas, record);
  }
}

void _paintImageRecord(
  Canvas canvas,
  RenderElementRecord record,
  Map<CanvasResourceId, ResourceImageResolveResult> imageBindings,
) {
  final resourceId = record.resourceId;
  final binding = resourceId == null ? null : imageBindings[resourceId];
  if (binding is ResolvedResourceImage) {
    canvas.drawImageRect(
      binding.image,
      Offset.zero &
          Size(binding.image.width.toDouble(), binding.image.height.toDouble()),
      record.paintBoundsWorld,
      Paint(),
    );

    return;
  }

  _paintFallbackBounds(canvas, record);
}

void _paintRectRecord(
  Canvas canvas,
  RenderElementRecord record,
  RectRenderRow row,
) {
  final fill = row.fillColor;
  if (fill != null) {
    canvas.drawRect(
      record.paintBoundsWorld,
      Paint()..color = fill.withAlpha(record.primitiveAlpha),
    );
  }
  final stroke = row.strokeColor;
  if (stroke != null && row.strokeWidth > 0) {
    canvas.drawRect(
      record.paintBoundsWorld,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = row.strokeWidth
        ..color = stroke.withAlpha(record.primitiveAlpha),
    );
  }
}

void _paintFallbackBounds(Canvas canvas, RenderElementRecord record) {
  canvas.drawRect(
    record.paintBoundsWorld,
    Paint()..color = Color.fromARGB(record.primitiveAlpha, 0, 0, 0),
  );
}
