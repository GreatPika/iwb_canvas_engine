import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine/src/frame/frame_paint_output.dart';
import 'package:iwb_canvas_engine/src/frame/main_frame_painter.dart';

void main() {
  _testPassiveHost();
  _testCameraPanPreservesOrdinaryPlan();
}

void _testPassiveHost() {
  testWidgets('CanvasSurface exposes a passive CustomPaint host', (
    tester,
  ) async {
    final runtime = CanvasRuntime(initialDocument: _document());
    final resolver = _RecordingResolver();
    addTearDown(runtime.dispose);

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(
          width: 100,
          height: 100,
          child: CanvasSurface(
            runtime: runtime,
            resourceResolver: resolver,
            interactive: false,
          ),
        ),
      ),
    );

    final host = find.byKey(
      const ValueKey<String>('iwb_canvas_surface.paint_host'),
    );
    expect(host, findsOneWidget);
    expect(find.byType(CustomPaint), findsOneWidget);
    final paintHost = tester.widget<CustomPaint>(host);
    expect(paintHost.painter, isNotNull);
    expect(paintHost.foregroundPainter, isNotNull);
    expect(resolver.calls, 0);
  });
}

void _testCameraPanPreservesOrdinaryPlan() {
  testWidgets(
    'CanvasSurface camera pan preserves ordinary paint cache identity',
    (tester) async {
      final runtime = CanvasRuntime(initialDocument: _document());
      addTearDown(runtime.dispose);

      await tester.pumpWidget(_surfaceHost(runtime));
      final beforeOutput = _mainPainter(tester).output;
      final beforePan = beforeOutput.ordinaryPlan;

      _expectSurfaceCapturedRuntimePreview(beforeOutput, runtime);

      runtime.camera.setOffset(const Offset(12, 0));
      await tester.pump();
      final afterPan = _mainPainter(
        tester,
      ).output.capturedFrame.snapshot.inputs;
      final afterOrdinaryPlan = _mainPainter(tester).output.ordinaryPlan;

      expect(afterOrdinaryPlan.key, beforePan.key);
      expect(
        afterPan.viewportWorldBounds,
        beforeOutput.capturedFrame.snapshot.inputs.viewportWorldBounds,
      );
      expect(afterPan.viewCameraOffset, const Offset(12, 0));
      expect(
        afterPan.effectiveWorldBounds,
        afterPan.viewportWorldBounds.shift(const Offset(12, 0)),
      );
    },
  );
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

Widget _surfaceHost(CanvasRuntime runtime) {
  return Directionality(
    textDirection: TextDirection.ltr,
    child: SizedBox(
      width: 100,
      height: 100,
      child: CanvasSurface(
        runtime: runtime,
        resourceResolver: _RecordingResolver(),
        interactive: false,
      ),
    ),
  );
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

final class _RecordingResolver implements CanvasResourceResolver {
  int calls = 0;

  @override
  ui.Image? resolveImage(CanvasImageResource resource) {
    calls += 1;

    return null;
  }
}
