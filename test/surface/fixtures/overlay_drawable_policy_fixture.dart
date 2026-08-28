import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine/src/frame/frame_paint_output.dart';
import 'package:iwb_canvas_engine/src/frame/frame_repaint_signal.dart';
import 'package:iwb_canvas_engine/src/frame/overlay_preview_planner.dart';
import 'package:iwb_canvas_engine/src/surface/overlay_painter.dart';

import '../../frame/fixtures/ordinary_paint_test_support.dart';
import '../../support/runtime_root_with_committed_document_seed.dart';

void main() {
  _testOverlayOnePointPreviews();
  _testOverlayStrokePreviewJoins();
  _testOverlayLinePreviewCaps();
  _testOverlayEmptyPreviews();
  _testRetainedEraserPreviewsUseThePublicOverlayRoute();
}

// One route assertion intentionally keeps all three public preview forms on
// one RuntimeRoot output route, so an injected synthetic frame cannot pass.
// ignore: halstead-volume, source-lines-of-code
void _testRetainedEraserPreviewsUseThePublicOverlayRoute() {
  test(
    'one-point, ordinary, and resampled eraser previews reach the frame',
    () async {
      var publishedPreviewForms = 0;
      final root = runtimeRootWithCommittedDocumentSeed(CanvasDocument());
      addTearDown(root.dispose);
      root.setInteractionMode(CanvasInteractionMode.draw);
      root.setDrawStyle(
        CanvasDrawStyle(tool: CanvasDrawTool.eraser, eraserThickness: 6),
      );
      OverlayFramePaintOutput output() => root.buildResourceFreeOverlayFrame(
        viewportWorldBounds: const Rect.fromLTWH(0, 0, 32, 32),
        devicePixelRatio: 1,
        selectionStyle: CanvasSelectionStyle.defaultStyle,
        gridStyle: CanvasGridStyle.defaultStyle,
      );

      root.handlePointer(
        _eraserSample(const Offset(5, 5), CanvasPointerLifecyclePhase.down),
      );
      await _expectPublicEraserFrame(root.preview, output(), 1);
      publishedPreviewForms += 1;
      root.handlePointer(
        _eraserSample(const Offset(8, 9), CanvasPointerLifecyclePhase.move),
      );
      await _expectPublicEraserFrame(root.preview, output(), 2);
      publishedPreviewForms += 1;
      for (var index = 2; index <= 8000; index += 1) {
        root.handlePointer(
          _eraserSample(
            Offset(
              5 + (index % 24).toDouble(),
              5 + ((index * 7) % 24).toDouble(),
            ),
            CanvasPointerLifecyclePhase.move,
          ),
        );
      }
      await _expectPublicEraserFrame(root.preview, output(), 4000);
      publishedPreviewForms += 1;
      expect(publishedPreviewForms, 3);
    },
  );
}

Future<void> _expectPublicEraserFrame(
  CanvasPreviewState preview,
  OverlayFramePaintOutput output,
  int corridorPointCount,
) async {
  final eraser = preview as CanvasEraserPreview;
  expect(eraser.corridor, hasLength(corridorPointCount));
  final captured = output.capturedFrame.overlayPreview as CanvasEraserPreview;
  final primitive =
      output.overlayPreviewPlan.primitives.single as EraserOverlayPrimitive;
  expect(captured, same(eraser));
  expect(captured.corridor, eraser.corridor);
  expect(primitive.corridor, eraser.corridor);
  expect(
    await _alphaAt(
      (canvas) => OverlayFramePainter(
        outputListenable: ValueNotifier(output),
      ).paint(canvas, const Size(32, 32)),
      5,
      5,
    ),
    greaterThan(0),
  );
}

CanvasPointerSample _eraserSample(
  Offset position,
  CanvasPointerLifecyclePhase phase,
) => CanvasPointerSample(
  pointerId: 1,
  position: position,
  phase: phase,
  kind: PointerDeviceKind.touch,
);

void _testOverlayOnePointPreviews() {
  test('overlay one-point stroke previews produce visible pixels', () async {
    expect(
      await _overlayAlphaAt(
        CanvasPencilStrokePreview(
          points: const [Offset(5, 5)],
          color: const Color(0xFFFF0000),
          thickness: 6,
          opacity: 1,
        ),
      ),
      greaterThan(0),
    );
    expect(
      await _overlayAlphaAt(
        CanvasMarkerStrokePreview(
          points: const [Offset(5, 5)],
          color: const Color(0xFF00FF00),
          thickness: 6,
          opacity: 0.8,
        ),
      ),
      greaterThan(0),
    );
    expect(
      await _overlayAlphaAt(
        CanvasEraserPreview(corridor: const [Offset(5, 5)], thickness: 6),
      ),
      greaterThan(0),
    );
  });
}

void _testOverlayStrokePreviewJoins() {
  test('overlay stroke previews paint path joins as solid turns', () async {
    final preview = CanvasMarkerStrokePreview(
      points: const [Offset(8, 24), Offset(16, 8), Offset(24, 24)],
      color: const Color(0xFF00FF00),
      thickness: 10,
      opacity: 0.8,
    );

    expect(await _overlayAlphaAt(preview, x: 16, y: 5), greaterThan(0));
    expect(await _overlayAlphaAt(preview, x: 16, y: 1), 0);
  });
}

void _testOverlayLinePreviewCaps() {
  test('overlay line previews paint round caps', () async {
    const preview = CanvasLinePreview(
      start: Offset(8, 16),
      end: Offset(24, 16),
      color: Color(0xFF0000FF),
      thickness: 10,
    );

    expect(await _overlayAlphaAt(preview, x: 4, y: 16), greaterThan(0));
    expect(await _overlayAlphaAt(preview, x: 2, y: 16), 0);
  });
}

void _testOverlayEmptyPreviews() {
  test('overlay empty point lists are no-op', () async {
    expect(
      await _overlayAlphaAt(
        CanvasPencilStrokePreview(
          points: const [],
          color: const Color(0xFFFF0000),
          thickness: 6,
          opacity: 1,
        ),
      ),
      0,
    );
    expect(
      await _overlayAlphaAt(
        CanvasEraserPreview(corridor: const [], thickness: 6),
      ),
      0,
    );
  });
}

Future<int> _overlayAlphaAt(
  CanvasPreviewState preview, {
  int x = 5,
  int y = 5,
}) {
  final frame = capturedOverlayFrameFor(preview);
  final plan = const OverlayPreviewPlanner().build(frame);
  final output = OverlayFramePaintOutput(
    capturedFrame: frame,
    overlayPreviewPlan: plan,
    repaintSignal: const FrameRepaintSignal(
      mainCanvas: false,
      overlayCanvas: true,
      reason: 'test',
    ),
  );

  return _alphaAt(
    (canvas) => OverlayFramePainter(
      outputListenable: ValueNotifier(output),
    ).paint(canvas, const Size(32, 32)),
    x,
    y,
  );
}

Future<int> _alphaAt(void Function(Canvas canvas) paint, int x, int y) async {
  final recorder = PictureRecorder();
  paint(Canvas(recorder));
  final image = await recorder.endRecording().toImage(32, 32);
  final bytes = await image.toByteData(format: ImageByteFormat.rawRgba);
  if (bytes == null) {
    throw StateError('overlay drawable policy test produced no pixel data');
  }

  return bytes.buffer.asUint8List()[(y * 32 + x) * 4 + 3];
}
