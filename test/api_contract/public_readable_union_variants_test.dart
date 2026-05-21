import 'package:test/test.dart';

import '../support/flutter_consumer_test_harness.dart';

void main() {
  test(
    'public sealed unions expose readable variants through root barrel',
    () async {
      await expectLater(
        runFlutterConsumerTest(
          packageName: 'iwb_canvas_engine_readable_union_consumer',
          testFileName: 'readable_union_test.dart',
          testSource: _readableUnionSource,
        ),
        completes,
      );
    },
  );
}

const _readableUnionSource = '''
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';

void main() {
  test('resource source app-key variant is publicly readable', () {
    final source = CanvasResourceSource.appKey('asset-main');
    final resource = CanvasImageResource(
      id: CanvasResourceId('resource-1'),
      source: source,
    );

    expect(source, isA<CanvasAppKeyResourceSource>());
    switch (resource.source) {
      case CanvasAppKeyResourceSource(:final key):
        expect(key, 'asset-main');
    }
  });

  test('preview state variants are publicly readable', () {
    final previews = <CanvasPreviewState>[
      const CanvasPreviewState.none(),
      const CanvasPreviewState.marquee(
        rect: Rect.fromLTWH(0, 0, 10, 10),
      ),
      const CanvasPreviewState.selectedMove(delta: Offset(1, 2)),
      CanvasPreviewState.pencilStroke(
        points: [Offset.zero],
        color: const Color(0xFF000000),
        thickness: 2,
        opacity: 1,
      ),
      CanvasPreviewState.markerStroke(
        points: [Offset.zero],
        color: const Color(0xFF000000),
        thickness: 4,
        opacity: 0.5,
      ),
      const CanvasPreviewState.pendingLineStart(
        start: Offset.zero,
        timestampMs: 1,
        color: Color(0xFF000000),
        thickness: 2,
      ),
      const CanvasPreviewState.linePreview(
        start: Offset.zero,
        end: Offset(1, 1),
        color: Color(0xFF000000),
        thickness: 2,
      ),
      CanvasPreviewState.eraser(corridor: [Offset.zero], thickness: 8),
    ];

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
          expect(rect.width, 10);
        case CanvasSelectedMovePreview(:final delta):
          expect(delta.dx, 1);
        case CanvasPencilStrokePreview(:final points, :final opacity):
          expect(points, hasLength(1));
          expect(opacity, 1);
        case CanvasMarkerStrokePreview(:final points, :final opacity):
          expect(points, hasLength(1));
          expect(opacity, 0.5);
        case CanvasPendingLineStartPreview(:final timestampMs):
          expect(timestampMs, 1);
        case CanvasLinePreview(:final end):
          expect(end, const Offset(1, 1));
        case CanvasEraserPreview(:final corridor, :final thickness):
          expect(corridor, hasLength(1));
          expect(thickness, 8);
      }
    }
  });
}
''';
