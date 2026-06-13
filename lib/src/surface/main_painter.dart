import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';

import '../frame/frame_paint_output.dart';
import '../frame/main_frame_asset_images.dart';
import '../frame/main_frame_record_painter.dart';
import '../frame/render_element_record.dart';
import '../frame/selection_decoration_planner.dart';

final class MainFramePainter extends CustomPainter {
  MainFramePainter({required this.outputListenable})
    : super(repaint: outputListenable);

  final ValueListenable<MainFramePaintOutput?> outputListenable;

  MainFramePaintOutput get output {
    final value = outputListenable.value;
    if (value == null) {
      throw StateError('Main frame output has not been built.');
    }

    return value;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final viewport = output.capturedFrame.snapshot.inputs.effectiveWorldBounds;
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0x00000000),
    );
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.translate(-viewport.left, -viewport.top);
    canvas.drawPicture(output.staticBackgroundPlan.picture.picture);
    paintMainFrameRecordsAndSelectionDecorations(canvas, output);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant MainFramePainter oldDelegate) {
    return !identical(oldDelegate.outputListenable, outputListenable);
  }
}

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

void paintMainFrameRecordsAndSelectionDecorations(
  Canvas canvas,
  MainFramePaintOutput output,
) {
  final imageBindings = resolvedMainFrameImages(output);
  for (final record in mainFrameRecordsInPaintOrder(
    output.selectedMoveSupplementPlan.mergedRecords,
  )) {
    paintMainFrameRecord(
      canvas,
      record,
      imageBindings,
      output.renderPrimitiveSnapshot,
    );
  }
  for (final primitive in output.selectionDecorationPlan.primitives) {
    _paintSelectionDecoration(canvas, primitive);
  }
}

void _paintSelectionDecoration(
  Canvas canvas,
  SelectionDecorationPrimitive primitive,
) {
  final haloWidth = primitive.haloWidth;
  if (haloWidth > 0) {
    canvas.drawRect(
      _selectionDecorationStrokeRectFor(
        primitive,
        strokeWidth: haloWidth,
        isHalo: true,
      ),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = haloWidth
        ..color = primitive.color.withAlpha(48),
    );
  }
  final strokeWidth = primitive.strokeWidth;
  if (strokeWidth > 0) {
    canvas.drawRect(
      _selectionDecorationStrokeRectFor(
        primitive,
        strokeWidth: strokeWidth,
        isHalo: false,
      ),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..color = primitive.color,
    );
  }
}

Rect _selectionDecorationStrokeRectFor(
  SelectionDecorationPrimitive primitive, {
  required double strokeWidth,
  required bool isHalo,
}) {
  final bounds = primitive.boundsWorld;
  switch (primitive.strokePlacement) {
    case SelectionDecorationStrokePlacement.outsideBox:
      final outerGap = isHalo ? primitive.strokeWidth : 0;
      return bounds.inflate(outerGap + strokeWidth / 2);
    case SelectionDecorationStrokePlacement.boundsOutline:
      return isHalo ? bounds.inflate(strokeWidth / 2) : bounds;
  }
}
