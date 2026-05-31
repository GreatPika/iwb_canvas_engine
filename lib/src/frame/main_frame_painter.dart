import 'dart:ui' show Image;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';

import '../contracts/public/canvas_ids.dart';
import '../resources/resource_resolver_adapter.dart';
import 'frame_paint_output.dart';
import 'main_frame_record_painter.dart';
import 'render_element_record.dart';
import 'selection_decoration_planner.dart';
import 'static_background_planner.dart';

final class MainFramePainter extends CustomPainter {
  const MainFramePainter({required this.output});

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
    _paintStaticBackground(canvas, output.staticBackgroundPlan.primitive);
    for (final record in mainFrameRecordsInPaintOrder(
      output.selectedMoveSupplementPlan.mergedRecords,
    )) {
      paintMainFrameRecord(canvas, record, _resolvedImages(output));
    }
    _paintSelectionDecorations(
      canvas,
      output.selectionDecorationPlan.primitives,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant MainFramePainter oldDelegate) {
    return !identical(oldDelegate.output, output);
  }
}

Map<CanvasResourceId, Image> _resolvedImages(MainFramePaintOutput output) {
  return {
    for (final entry in output.assetBindings.images.entries)
      if (entry.value is ResolvedResourceImage)
        entry.key: (entry.value as ResolvedResourceImage).image,
  };
}

@visibleForTesting
Iterable<RenderElementRecord> mainFrameRecordsInPaintOrder(
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

void _paintStaticBackground(
  Canvas canvas,
  StaticBackgroundPrimitive primitive,
) {
  final strokeWidth = primitive.gridStrokeWidth;
  if (strokeWidth <= 0) {
    return;
  }
  final viewport = primitive.viewportRect;
  const spacing = 20.0;
  final paint = Paint()
    ..color = const Color(0x14000000)
    ..strokeWidth = strokeWidth;
  final firstX = (viewport.left / spacing).floorToDouble() * spacing;
  for (var x = firstX; x <= viewport.right; x += spacing) {
    canvas.drawLine(Offset(x, viewport.top), Offset(x, viewport.bottom), paint);
  }
  final firstY = (viewport.top / spacing).floorToDouble() * spacing;
  for (var y = firstY; y <= viewport.bottom; y += spacing) {
    canvas.drawLine(Offset(viewport.left, y), Offset(viewport.right, y), paint);
  }
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
