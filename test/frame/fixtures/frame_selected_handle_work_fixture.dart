import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/src/contracts/internal/selection_facts_port.dart';
import 'package:iwb_canvas_engine/src/contracts/public/canvas_preview.dart';
import 'package:iwb_canvas_engine/src/contracts/public/canvas_surface_styles.dart';
import 'package:iwb_canvas_engine/src/frame/captured_frame.dart';
import 'package:iwb_canvas_engine/src/frame/frame_engine.dart';
import 'package:iwb_canvas_engine/src/geometry/spatial_kernel.dart';

import 'ordinary_paint_test_support.dart';

const _selectedCount = 128;
const _frameInputs = FrameCaptureInputs(
  viewportWorldBounds: Rect.fromLTWH(0, 0, 10, 10),
  devicePixelRatio: 1,
  selectionStyle: CanvasSelectionStyle.defaultStyle,
  gridStyle: CanvasGridStyle.defaultStyle,
  preview: CanvasNoPreview(),
  previewRevision: 0,
);

void main() {
  test('main frame does not re-read captured selected handles', () {
    final rows = [
      for (var index = 0; index < _selectedCount; index += 1)
        rectFacts('selected-$index', orderToken: index),
    ];
    final frameFacts = frameFactsPort(elements: rows);
    final engine = FrameEngine(
      frameFacts: frameFacts,
      selectionFacts: TestSelectionFactsPort(
        SelectionFacts(
          selectedElementIds: [for (final row in rows) row.id],
          selectionRevision: 1,
        ),
      ),
      spatialKernel: SpatialKernel(),
    );

    final output = engine.buildResourceFreeMainFrame(
      inputs: _frameInputs,
      viewCameraBucket: 0,
    );

    expect(
      output.selectionDecorationPlan.primitives.single.selectedElementCount,
      rows.length,
    );
    expect(frameFacts.elementHandleForIdCalls, lessThanOrEqualTo(rows.length));
  });
}
