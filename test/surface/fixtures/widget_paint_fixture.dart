import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';

void main() {
  _testPassiveHost();
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

final class _RecordingResolver implements CanvasResourceResolver {
  int calls = 0;

  @override
  ui.Image? resolveImage(CanvasImageResource resource) {
    calls += 1;

    return null;
  }
}
