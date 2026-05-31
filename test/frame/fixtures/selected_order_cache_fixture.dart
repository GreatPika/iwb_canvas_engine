import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/src/contracts/internal/selection_facts_port.dart';
import 'package:iwb_canvas_engine/src/contracts/public/canvas_preview.dart';
import 'package:iwb_canvas_engine/src/contracts/public/canvas_surface_styles.dart';
import 'package:iwb_canvas_engine/src/frame/captured_frame.dart';
import 'package:iwb_canvas_engine/src/frame/frame_engine.dart';
import 'package:iwb_canvas_engine/src/frame/selected_order_cache.dart';
import 'package:iwb_canvas_engine/src/geometry/spatial_kernel.dart';

import 'ordinary_paint_test_support.dart';

void main() {
  _testSelectedOrderCache();
  _testSelectedOrderUsesDocumentOrder();
}

void _testSelectedOrderCache() {
  test('selected order cache keeps one derived snapshot', () {
    final a = rectFacts('a', orderToken: 1).id;
    final b = rectFacts('b', orderToken: 2).id;
    final c = rectFacts('c', orderToken: 3).id;
    final cache = SelectedOrderCache();
    const firstKey = SelectedOrderKey(
      selectionRevision: 1,
      structuralRevision: 2,
    );
    const changedKey = SelectedOrderKey(
      selectionRevision: 2,
      structuralRevision: 2,
    );

    final first = cache.readOrBuild(key: firstKey, orderedSelectedIds: [b, a]);
    final again = cache.readOrBuild(key: firstKey, orderedSelectedIds: [c]);
    final changed = cache.readOrBuild(key: changedKey, orderedSelectedIds: [c]);

    expect(again, same(first));
    expect(first.orderedSelectedIds, [b, a]);
    expect(changed, isNot(same(first)));
    expect(cache.probe.selectedCount, 1);
    expect(cache.probe.rebuildCount, 2);
  });
}

void _testSelectedOrderUsesDocumentOrder() {
  test('frame engine selected order uses selection and document order', () {
    final rows = [
      rectFacts('a', orderToken: 1),
      rectFacts('b', orderToken: 2),
      rectFacts('offscreen', orderToken: 3),
    ];
    final frameFacts = frameFactsPort(
      elements: rows,
      spatialCandidates: [frameFactsPort(elements: rows).spatialCandidates[1]],
    );
    final engine = FrameEngine(
      frameFacts: frameFacts,
      selectionFacts: TestSelectionFactsPort(
        SelectionFacts(
          selectedElementIds: [rows[2].id, rows[0].id],
          selectionRevision: 3,
        ),
      ),
      spatialKernel: SpatialKernel()..rebuild(frameFacts),
    );

    final output = engine.buildResourceFreeMainFrame(
      inputs: _inputs(),
      viewCameraBucket: 0,
    );

    expect(output.selectedOrderSnapshot.orderedSelectedIds, [
      rows[0].id,
      rows[2].id,
    ]);
  });
}

FrameCaptureInputs _inputs() {
  return const FrameCaptureInputs(
    viewportWorldBounds: Rect.fromLTWH(0, 0, 10, 10),
    devicePixelRatio: 1,
    selectionStyle: CanvasSelectionStyle.defaultStyle,
    gridStyle: CanvasGridStyle.defaultStyle,
    preview: CanvasNoPreview(),
    previewRevision: 0,
  );
}
