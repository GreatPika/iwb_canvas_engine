import 'dart:ui' as ui show Image;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';

import '../../support/runtime_with_document.dart';
import 'package:iwb_canvas_engine/src/frame/frame_paint_output.dart';
import 'package:iwb_canvas_engine/src/surface/main_painter.dart';

void main() {
  testWidgets('CanvasSurface camera pan keeps ordinary plan identity', (
    tester,
  ) async {
    expect(await _surfaceCameraPanKeepsOrdinaryPlanIdentity(tester), isTrue);
  });
}

Future<bool> _surfaceCameraPanKeepsOrdinaryPlanIdentity(
  WidgetTester tester,
) async {
  final runtime = runtimeWithDocument(_document());
  addTearDown(runtime.dispose);

  await tester.pumpWidget(_SurfaceHost(runtime: runtime));
  final beforeOutput = _mainPainter(tester).output;
  final beforePan = beforeOutput.ordinaryPlan;

  _expectSurfaceCapturedRuntimePreview(beforeOutput, runtime);

  runtime.camera.setOffset(const Offset(12, 0));
  await tester.pump();
  final afterOutput = _mainPainter(tester).output;
  final afterPan = afterOutput.capturedFrame.snapshot.inputs;

  expect(afterOutput.ordinaryPlan.key, beforePan.key);
  expect(
    afterPan.viewportWorldBounds,
    beforeOutput.capturedFrame.snapshot.inputs.viewportWorldBounds,
  );
  expect(afterPan.viewCameraOffset, const Offset(12, 0));
  expect(
    afterPan.effectiveWorldBounds,
    afterPan.viewportWorldBounds.shift(const Offset(12, 0)),
  );

  return true;
}

void _expectSurfaceCapturedRuntimePreview(
  MainFramePaintOutput output,
  CanvasRuntime runtime,
) {
  final snapshot = output.capturedFrame.snapshot;

  expect(snapshot.preview, same(runtime.preview));
  expect(snapshot.previewRevision, runtime.state.value.revisions.preview);
}

CanvasDocument _document() {
  return CanvasDocument(
    layers: [
      CanvasLayer(
        id: CanvasLayerId('layer-a'),
        elements: [
          CanvasRectElement(
            id: CanvasElementId('rect-a'),
            size: const Size(10, 10),
            fillColor: const Color(0xFF336699),
          ),
        ],
      ),
    ],
  );
}

final class _SurfaceHost extends StatelessWidget {
  const _SurfaceHost({required this.runtime});

  final CanvasRuntime runtime;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: SizedBox(
        width: 100,
        height: 100,
        child: CanvasSurface(
          runtime: runtime,
          resourceResolver: _NoopResolver(),
          interactive: false,
        ),
      ),
    );
  }
}

MainFramePainter _mainPainter(WidgetTester tester) {
  final host = find.byKey(
    const ValueKey<String>('iwb_canvas_surface.paint_host'),
  );
  final paintHost = tester.widget<CustomPaint>(host);
  final painter = paintHost.painter;

  expect(painter, isA<MainFramePainter>());

  return painter as MainFramePainter;
}

final class _NoopResolver implements CanvasResourceResolver {
  @override
  ui.Image? resolveImage(CanvasImageResource resource) {
    return null;
  }
}
