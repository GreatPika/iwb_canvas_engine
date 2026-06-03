import 'package:flutter/rendering.dart';

import '../frame/frame_paint_output.dart';
import '../frame/main_frame_asset_images.dart';
import '../frame/main_frame_record_painter.dart';
import '../frame/render_element_record.dart';
import '../frame/selection_decoration_planner.dart';

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
    canvas.drawPicture(output.staticBackgroundPlan.picture.picture);
    paintMainFrameRecordsAndSelectionDecorations(canvas, output);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant MainFramePainter oldDelegate) {
    return !identical(oldDelegate.output, output);
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
  final pendingDecorations = output.selectionDecorationPlan.primitives;
  var nextDecorationIndex = 0;
  for (final record in mainFrameRecordsInPaintOrder(
    output.selectedMoveSupplementPlan.mergedRecords,
  )) {
    nextDecorationIndex = _paintSelectionDecorationsBeforeRecord(
      canvas,
      pendingDecorations,
      nextDecorationIndex,
      record,
    );
    paintMainFrameRecord(
      canvas,
      record,
      imageBindings,
      output.renderPrimitiveSnapshot,
    );
    nextDecorationIndex = _paintSelectionDecorationsAtRecord(
      canvas,
      pendingDecorations,
      nextDecorationIndex,
      record,
    );
  }
  _paintSelectionDecorationRange(
    canvas,
    pendingDecorations,
    nextDecorationIndex,
    pendingDecorations.length,
  );
}

int _paintSelectionDecorationsBeforeRecord(
  Canvas canvas,
  List<SelectionDecorationPrimitive> primitives,
  int startIndex,
  RenderElementRecord record,
) {
  var index = startIndex;
  while (index < primitives.length &&
      primitives[index].paintOrderToken < record.orderToken) {
    _paintSelectionDecoration(canvas, primitives[index]);
    index += 1;
  }

  return index;
}

int _paintSelectionDecorationsAtRecord(
  Canvas canvas,
  List<SelectionDecorationPrimitive> primitives,
  int startIndex,
  RenderElementRecord record,
) {
  var index = startIndex;
  while (index < primitives.length &&
      primitives[index].paintOrderToken <= record.orderToken) {
    _paintSelectionDecoration(canvas, primitives[index]);
    index += 1;
  }

  return index;
}

void _paintSelectionDecorationRange(
  Canvas canvas,
  List<SelectionDecorationPrimitive> primitives,
  int startIndex,
  int endIndex,
) {
  for (var index = startIndex; index < endIndex; index += 1) {
    _paintSelectionDecoration(canvas, primitives[index]);
  }
}

void _paintSelectionDecoration(
  Canvas canvas,
  SelectionDecorationPrimitive primitive,
) {
  final haloWidth = primitive.haloWidth;
  if (haloWidth > 0) {
    final effectiveHaloWidth = _effectiveSelectionStrokeWidth(
      primitive,
      haloWidth,
    );
    canvas.drawRect(
      _selectionDecorationStrokeRectFor(
        primitive,
        strokeWidth: effectiveHaloWidth,
        isHalo: true,
      ),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = effectiveHaloWidth
        ..color = primitive.color.withAlpha(48),
    );
  }
  final strokeWidth = primitive.strokeWidth;
  if (strokeWidth > 0) {
    final effectiveStrokeWidth = _effectiveSelectionStrokeWidth(
      primitive,
      strokeWidth,
    );
    canvas.drawRect(
      _selectionDecorationStrokeRectFor(
        primitive,
        strokeWidth: effectiveStrokeWidth,
        isHalo: false,
      ),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = effectiveStrokeWidth
        ..color = primitive.color,
    );
  }
}

double _effectiveSelectionStrokeWidth(
  SelectionDecorationPrimitive primitive,
  double strokeWidth,
) {
  if (primitive.strokePlacement ==
      SelectionDecorationStrokePlacement.boundsOutline) {
    return strokeWidth;
  }
  final maxInsideWidth = _minPositive(
    primitive.boundsWorld.width,
    primitive.boundsWorld.height,
  );

  return strokeWidth <= maxInsideWidth ? strokeWidth : maxInsideWidth;
}

Rect _selectionDecorationStrokeRectFor(
  SelectionDecorationPrimitive primitive, {
  required double strokeWidth,
  required bool isHalo,
}) {
  final bounds = primitive.boundsWorld;
  if (primitive.strokePlacement ==
      SelectionDecorationStrokePlacement.boundsOutline) {
    return isHalo ? bounds.inflate(strokeWidth / 2) : bounds;
  }
  final inset = _insideStrokeInset(bounds, strokeWidth);

  return bounds.deflate(inset);
}

double _insideStrokeInset(Rect bounds, double strokeWidth) {
  final halfStroke = strokeWidth / 2;
  final maxInset = _minPositive(bounds.width, bounds.height) / 2;

  return halfStroke <= maxInset ? halfStroke : maxInset;
}

double _minPositive(double left, double right) {
  if (left <= 0 || right <= 0) {
    return 0;
  }

  return left < right ? left : right;
}
