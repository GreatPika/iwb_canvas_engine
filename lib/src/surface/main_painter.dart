import 'package:flutter/rendering.dart';

import '../frame/frame_paint_output.dart';
import '../frame/main_frame_asset_images.dart';
import '../frame/main_frame_record_painter.dart';
import '../frame/render_element_record.dart';
import '../frame/selection_decoration_planner.dart';

final class MainSurfacePainter extends CustomPainter {
  const MainSurfacePainter({required this.output});

  final MainFramePaintOutput output;

  @override
  void paint(Canvas canvas, Size size) {
    final viewport = output.capturedFrame.snapshot.inputs.effectiveWorldBounds;
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0x00000000),
    );
    canvas.save();
    canvas.translate(-viewport.left, -viewport.top);
    canvas.drawPicture(output.staticBackgroundPlan.picture.picture);
    final imageBindings = resolvedMainFrameImages(output);
    for (final record in _mainFrameRecordsInPaintOrder(
      output.selectedMoveSupplementPlan.mergedRecords,
    )) {
      paintMainFrameRecord(
        canvas,
        record,
        imageBindings,
        output.renderPrimitiveSnapshot,
      );
    }
    _paintSelectionDecorations(
      canvas,
      output.selectionDecorationPlan.primitives,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant MainSurfacePainter oldDelegate) {
    return !identical(oldDelegate.output, output);
  }
}

Iterable<RenderElementRecord> _mainFrameRecordsInPaintOrder(
  List<RenderElementRecord> records,
) {
  if (_recordsAreTopmostFirst(records)) {
    return records.reversed;
  }

  return records;
}

bool _recordsAreTopmostFirst(List<RenderElementRecord> records) {
  RenderElementRecord? previous;
  for (final record in records) {
    final before = previous;
    previous = record;
    if (before == null || before.orderToken == record.orderToken) {
      continue;
    }

    return before.orderToken > record.orderToken;
  }

  return false;
}

void _paintSelectionDecorations(
  Canvas canvas,
  Iterable<SelectionDecorationPrimitive> primitives,
) {
  for (final primitive in primitives) {
    final bounds = primitive.boundsWorld;
    final haloWidth = primitive.haloWidth;
    if (haloWidth > 0) {
      canvas.drawRect(
        bounds.inflate(haloWidth / 2),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = haloWidth
          ..color = primitive.color.withAlpha(48),
      );
    }
    final strokeWidth = primitive.strokeWidth;
    if (strokeWidth > 0) {
      canvas.drawRect(
        bounds,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..color = primitive.color,
      );
    }
  }
}
