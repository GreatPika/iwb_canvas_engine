import 'dart:ui';

import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';

CanvasDocument createCanvasExampleDocument() {
  return CanvasDocument(
    camera: CanvasCamera.origin,
    background: CanvasBackground(
      color: const Color(0xFFFFFFFF),
      grid: CanvasGrid(
        enabled: false,
        cellSize: 10,
        color: const Color(0x1F000000),
      ),
    ),
    palette: CanvasPalette(
      penColors: const [
        Color(0xFF000000),
        Color(0xFFE53935),
        Color(0xFF1E88E5),
        Color(0xFF43A047),
        Color(0xFFFB8C00),
        Color(0xFF8E24AA),
      ],
      backgroundColors: const [
        Color(0xFFFFFFFF),
        Color(0xFFFFF9C4),
        Color(0xFFBBDEFB),
        Color(0xFFC8E6C9),
      ],
      gridSizes: const [10, 20, 40, 80],
    ),
    layers: [
      CanvasLayer(id: CanvasLayerId('layer-auto-0')),
      CanvasLayer(id: CanvasLayerId('layer-auto-1')),
    ],
  );
}

CanvasRuntimeConfig createCanvasExampleRuntimeConfig() {
  return CanvasRuntimeConfig(
    clearSelectionOnDrawModeEnter: true,
    pointerPolicy: CanvasPointerPolicy(
      tapSlop: 1,
      doubleTapSlop: 32,
      doubleTapMaxDelayMs: 450,
      dragStartSlop: 1.0,
    ),
  );
}

CanvasRuntime createCanvasExampleRuntime() {
  final runtime = CanvasRuntime(config: createCanvasExampleRuntimeConfig());
  runtime.edits.loadDocumentFromJson(
    encodeCanvasDocumentToJson(createCanvasExampleDocument()),
  );

  return runtime;
}
