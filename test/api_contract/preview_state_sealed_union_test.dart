import 'package:test/test.dart';

import '../support/flutter_consumer_test_harness.dart';

void main() {
  test(
    'preview sealed union variants are constructible and immutable',
    () async {
      await expectLater(
        runFlutterConsumerTest(
          packageName: 'iwb_canvas_engine_preview_state_consumer',
          testFileName: 'preview_state_test.dart',
          testSource: _previewStateSource,
        ),
        completes,
      );
    },
  );
}

const _previewStateSource = '''
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';

void main() {
  test('sealed preview variants expose typed payloads', () {
    final sourcePoints = [Offset.zero, const Offset(1, 1)];
    final corridor = [Offset.zero, const Offset(2, 2)];
    final previews = <CanvasPreviewState>[
      const CanvasPreviewState.none(),
      const CanvasPreviewState.marquee(rect: Rect.fromLTWH(0, 0, 10, 20)),
      const CanvasPreviewState.selectedMove(delta: Offset(1, 2)),
      CanvasPreviewState.pencilStroke(
        points: sourcePoints,
        color: const Color(0xFF111111),
        thickness: 2,
        opacity: 1,
      ),
      CanvasPreviewState.markerStroke(
        points: sourcePoints,
        color: const Color(0xFF222222),
        thickness: 4,
        opacity: 0.5,
      ),
      const CanvasPreviewState.pendingLineStart(
        start: Offset(3, 4),
        timestampMs: 10,
        color: Color(0xFF333333),
        thickness: 2,
      ),
      const CanvasPreviewState.linePreview(
        start: Offset.zero,
        end: Offset(5, 6),
        color: Color(0xFF444444),
        thickness: 3,
      ),
      CanvasPreviewState.eraser(corridor: corridor, thickness: 8),
    ];

    sourcePoints.clear();
    corridor.clear();

    expect(previews.map((preview) => preview.kind), [
      CanvasPreviewKind.none,
      CanvasPreviewKind.marquee,
      CanvasPreviewKind.selectedMove,
      CanvasPreviewKind.pencilStroke,
      CanvasPreviewKind.markerStroke,
      CanvasPreviewKind.pendingLineStart,
      CanvasPreviewKind.linePreview,
      CanvasPreviewKind.eraser,
    ]);

    for (final preview in previews) {
      switch (preview) {
        case CanvasNoPreview():
          expect(preview.kind, CanvasPreviewKind.none);
        case CanvasMarqueePreview(:final rect):
          expect(rect.size, const Size(10, 20));
        case CanvasSelectedMovePreview(:final delta):
          expect(delta, const Offset(1, 2));
        case CanvasPencilStrokePreview(:final points, :final color):
          expect(points, hasLength(2));
          expect(color, const Color(0xFF111111));
          expect(() => points.clear(), throwsUnsupportedError);
        case CanvasMarkerStrokePreview(:final points, :final opacity):
          expect(points, hasLength(2));
          expect(opacity, 0.5);
          expect(() => points.clear(), throwsUnsupportedError);
        case CanvasPendingLineStartPreview(:final start, :final timestampMs):
          expect(start, const Offset(3, 4));
          expect(timestampMs, 10);
        case CanvasLinePreview(:final start, :final end):
          expect(start, Offset.zero);
          expect(end, const Offset(5, 6));
        case CanvasEraserPreview(:final corridor, :final thickness):
          expect(corridor, hasLength(2));
          expect(thickness, 8);
          expect(() => corridor.clear(), throwsUnsupportedError);
      }
    }
  });
}
''';
