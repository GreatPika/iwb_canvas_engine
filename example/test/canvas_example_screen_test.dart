import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine_example/src/canvas_example_defaults.dart';
import 'package:iwb_canvas_engine_example/src/canvas_example_screen.dart';
import 'package:iwb_canvas_engine_example/src/canvas_example_view_model.dart';
import 'package:iwb_canvas_engine_example/src/canvas_pending_line_overlay.dart';

void main() {
  _registerSurfaceAndPointerTests();
  _registerSurfaceStyleTest();
  _registerDrawToolDockTest();
  _registerDrawColorDockTest();
  _registerCameraPanControlTest();
  _registerCameraResetControlTest();
  _registerGridDockTest();
  _registerBackgroundDockTest();
  _registerClearDockTest();
  _registerSelectionRotateDockTest();
  _registerSelectionFlipVerticalDockTest();
  _registerSelectionFlipHorizontalDockTest();
  _registerSelectionDeleteDockTest();
  _registerAddSampleEntryPointTest();
  _registerPendingLineOverlayTest();
  _registerPendingLinePainterTest();
}

void _registerSurfaceAndPointerTests() {
  testWidgets('screen mounts CanvasSurface and routes pointer drawing', (
    tester,
  ) async {
    final runtime = createCanvasExampleRuntime();
    addTearDown(runtime.dispose);
    final viewModel = CanvasExampleViewModel(runtime: runtime);
    addTearDown(viewModel.dispose);
    await _pumpScreen(tester, viewModel);

    expect(find.byType(CanvasSurface), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('mode.draw')));
    await tester.pump();
    await tester.drag(find.byType(CanvasSurface), const Offset(30, 0));
    await tester.pump();

    expect(runtime.state.value.summary.elementCount, greaterThan(0));
  });
}

void _registerSurfaceStyleTest() {
  testWidgets('screen preserves legacy selection surface style', (
    tester,
  ) async {
    final viewModel = CanvasExampleViewModel();
    addTearDown(viewModel.dispose);
    await _pumpScreen(tester, viewModel);

    final surface = tester.widget<CanvasSurface>(find.byType(CanvasSurface));

    expect(surface.selectionStyle.color.toARGB32(), 0xFFFFFF00);
    expect(surface.selectionStyle.strokeWidth, 4);
  });
}

void _registerDrawToolDockTest() {
  testWidgets('all draw tool controls update public state', (tester) async {
    final viewModel = CanvasExampleViewModel();
    addTearDown(viewModel.dispose);
    await _pumpScreen(tester, viewModel);

    await tester.tap(find.byKey(const ValueKey('mode.draw')));
    await tester.pump();
    expect(viewModel.mode, CanvasInteractionMode.draw);

    await _tapTool(tester, 'tool.pencil', CanvasDrawTool.pencil, viewModel);
    await tester.tap(find.byKey(const ValueKey('tool.marker')));
    await tester.pump();
    expect(viewModel.drawTool, CanvasDrawTool.marker);
    await _tapTool(tester, 'tool.line', CanvasDrawTool.line, viewModel);
    await _tapTool(tester, 'tool.eraser', CanvasDrawTool.eraser, viewModel);
  });
}

void _registerDrawColorDockTest() {
  testWidgets('all draw color controls update public state', (tester) async {
    final viewModel = CanvasExampleViewModel();
    addTearDown(viewModel.dispose);
    await _pumpScreen(tester, viewModel);

    await tester.tap(find.byKey(const ValueKey('mode.draw')));
    await tester.pump();

    for (final color in viewModel.penColors) {
      final colorButton = find.byKey(
        ValueKey('draw.color.${color.toARGB32()}'),
      );
      await tester.scrollUntilVisible(
        colorButton,
        80,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(colorButton);
      await tester.pump();
      expect(viewModel.drawColor, color);
    }
  });
}

void _registerCameraPanControlTest() {
  testWidgets('all camera pan controls update public camera state', (
    tester,
  ) async {
    final viewModel = CanvasExampleViewModel();
    addTearDown(viewModel.dispose);
    await _pumpScreen(tester, viewModel);

    await tester.tap(find.byKey(const ValueKey('camera.pan.left')));
    await tester.pump();
    expect(viewModel.cameraOffset, const Offset(-50, 0));

    await tester.tap(find.byKey(const ValueKey('camera.pan.right')));
    await tester.pump();
    expect(viewModel.cameraOffset, Offset.zero);

    await tester.tap(find.byKey(const ValueKey('camera.pan.up')));
    await tester.pump();
    expect(viewModel.cameraOffset, const Offset(0, -50));

    await tester.tap(find.byKey(const ValueKey('camera.pan.down')));
    await tester.pump();
    expect(viewModel.cameraOffset, Offset.zero);
  });
}

void _registerCameraResetControlTest() {
  testWidgets('camera reset control updates public camera state', (
    tester,
  ) async {
    final viewModel = CanvasExampleViewModel();
    addTearDown(viewModel.dispose);
    await _pumpScreen(tester, viewModel);
    viewModel.panCameraBy(const Offset(25, 25));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('camera.reset')));
    await tester.pump();
    expect(viewModel.cameraOffset, Offset.zero);
  });
}

void _registerGridDockTest() {
  testWidgets(
    'grid toggle and every grid size control mutate public document',
    (tester) async {
      final viewModel = CanvasExampleViewModel();
      addTearDown(viewModel.dispose);
      await _pumpScreen(tester, viewModel);

      await tester.tap(find.byKey(const ValueKey('grid.toggle')));
      await tester.pump();

      expect(viewModel.grid.enabled, isTrue);

      for (final size in viewModel.gridSizes) {
        await tester.tap(find.byKey(const ValueKey('grid.size.menu')));
        await tester.pumpAndSettle();
        await tester.tap(find.text(size.toStringAsFixed(0)).last);
        await tester.pumpAndSettle();
        expect(viewModel.grid.cellSize, size);
      }
    },
  );
}

void _registerBackgroundDockTest() {
  testWidgets('every background color control mutates public document', (
    tester,
  ) async {
    final viewModel = CanvasExampleViewModel();
    addTearDown(viewModel.dispose);
    await _pumpScreen(tester, viewModel);

    for (final color in viewModel.backgroundColors) {
      await tester.tap(find.byKey(const ValueKey('background.color.menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(_colorLabel(color)).last);
      await tester.pumpAndSettle();
      expect(viewModel.background.color, color);
    }
  });
}

void _registerClearDockTest() {
  testWidgets('clear control mutates public document', (tester) async {
    final viewModel = CanvasExampleViewModel();
    addTearDown(viewModel.dispose);
    _addRect(viewModel.runtime, 'clear-from-dock');
    await _pumpScreen(tester, viewModel);

    await tester.tap(find.byKey(const ValueKey('canvas.clear')));
    await tester.pump();

    expect(viewModel.runtimeState.summary.elementCount, 0);
  });
}

void _registerSelectionRotateDockTest() {
  testWidgets('selection rotation controls invoke public commands', (
    tester,
  ) async {
    final viewModel = CanvasExampleViewModel();
    addTearDown(viewModel.dispose);
    final rotateCwId = _addRect(viewModel.runtime, 'screen-rotate-cw');
    final rotateCcwId = _addRect(viewModel.runtime, 'screen-rotate-ccw');
    viewModel.setSelection([rotateCwId]);
    await _pumpScreen(tester, viewModel);
    final beforeCw = _findElement(viewModel.document, rotateCwId).transform;

    await tester.tap(find.byKey(const ValueKey('selection.rotate.cw')));
    await tester.pump();
    expect(
      _findElement(viewModel.document, rotateCwId).transform,
      isNot(beforeCw),
    );

    viewModel.setSelection([rotateCcwId]);
    await tester.pump();
    final beforeCcw = _findElement(viewModel.document, rotateCcwId).transform;
    await tester.tap(find.byKey(const ValueKey('selection.rotate.ccw')));
    await tester.pump();
    expect(
      _findElement(viewModel.document, rotateCcwId).transform,
      isNot(beforeCcw),
    );
  });
}

void _registerSelectionFlipVerticalDockTest() {
  testWidgets('selection vertical flip control invokes public command', (
    tester,
  ) async {
    final viewModel = CanvasExampleViewModel();
    addTearDown(viewModel.dispose);
    final flipVerticalId = _addRect(viewModel.runtime, 'screen-flip-v');
    await _pumpScreen(tester, viewModel);
    viewModel.setSelection([flipVerticalId]);
    await tester.pump();
    final beforeVertical = _findElement(
      viewModel.document,
      flipVerticalId,
    ).transform;
    await tester.tap(find.byKey(const ValueKey('selection.flip.vertical')));
    await tester.pump();
    expect(
      _findElement(viewModel.document, flipVerticalId).transform,
      isNot(beforeVertical),
    );
  });
}

void _registerSelectionFlipHorizontalDockTest() {
  testWidgets('selection horizontal flip control invokes public command', (
    tester,
  ) async {
    final viewModel = CanvasExampleViewModel();
    addTearDown(viewModel.dispose);
    final flipHorizontalId = _addRect(viewModel.runtime, 'screen-flip-h');
    await _pumpScreen(tester, viewModel);
    viewModel.setSelection([flipHorizontalId]);
    await tester.pump();
    final beforeHorizontal = _findElement(
      viewModel.document,
      flipHorizontalId,
    ).transform;
    await tester.tap(find.byKey(const ValueKey('selection.flip.horizontal')));
    await tester.pump();
    expect(
      _findElement(viewModel.document, flipHorizontalId).transform,
      isNot(beforeHorizontal),
    );
  });
}

void _registerSelectionDeleteDockTest() {
  testWidgets('selection delete control invokes public command', (
    tester,
  ) async {
    final viewModel = CanvasExampleViewModel();
    addTearDown(viewModel.dispose);
    final deleteId = _addRect(viewModel.runtime, 'screen-delete');
    await _pumpScreen(tester, viewModel);
    viewModel.setSelection([deleteId]);
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('selection.delete')));
    await tester.pump();
    expect(_tryFindElement(viewModel.document, deleteId), isNull);
  });
}

void _registerAddSampleEntryPointTest() {
  testWidgets('Add Sample control invokes the view model command entry point', (
    tester,
  ) async {
    var calls = 0;
    final viewModel = CanvasExampleViewModel(addSampleCommand: () => calls++);
    addTearDown(viewModel.dispose);
    await _pumpScreen(tester, viewModel);

    await tester.tap(find.byKey(const ValueKey('sample.add')));
    await tester.pump();

    expect(calls, 1);
    expect(viewModel.runtimeState.summary.elementCount, 0);
  });
}

void _registerPendingLineOverlayTest() {
  testWidgets('pending line overlay projects public preview state', (
    tester,
  ) async {
    final runtime = createCanvasExampleRuntime();
    addTearDown(runtime.dispose);
    final viewModel = CanvasExampleViewModel(runtime: runtime);
    addTearDown(viewModel.dispose);
    runtime.tools.setMode(CanvasInteractionMode.draw);
    runtime.tools.setDrawTool(CanvasDrawTool.line);
    _tapPointer(runtime, const Offset(100, 100));
    await _pumpScreen(tester, viewModel);

    final overlay = tester.widget<CanvasPendingLineOverlay>(
      find.byType(CanvasPendingLineOverlay),
    );
    final marker = PendingLineMarker.fromPreview(overlay.preview);

    expect(marker.isVisible, isTrue);
    expect(marker.start, const Offset(100, 100));
  });
}

void _registerPendingLinePainterTest() {
  testWidgets('pending line painter renders marker with camera offset', (
    tester,
  ) async {
    await tester.pumpWidget(
      const CustomPaint(
        painter: CanvasPendingLinePainter(
          marker: PendingLineMarker(
            start: Offset(100, 100),
            color: Color(0xFF00AAFF),
            thickness: 4,
          ),
          cameraOffset: Offset(20, 30),
        ),
        child: SizedBox(width: 200, height: 200),
      ),
    );

    expect(find.byType(CustomPaint), _pendingLinePaintPattern());
  });
}

PaintPattern _pendingLinePaintPattern() {
  return paints
    ..circle(
      x: 80,
      y: 70,
      radius: 12,
      color: const Color(0xC800AAFF),
      strokeWidth: 4,
      style: PaintingStyle.stroke,
    )
    ..line(
      p1: const Offset(65, 70),
      p2: const Offset(95, 70),
      color: const Color(0xC800AAFF),
      strokeWidth: 4,
      style: PaintingStyle.stroke,
    )
    ..line(
      p1: const Offset(80, 55),
      p2: const Offset(80, 85),
      color: const Color(0xC800AAFF),
      strokeWidth: 4,
      style: PaintingStyle.stroke,
    );
}

Future<void> _pumpScreen(
  WidgetTester tester,
  CanvasExampleViewModel viewModel,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: SizedBox(
        width: 1000,
        height: 700,
        child: CanvasExampleScreen(viewModel: viewModel),
      ),
    ),
  );
  await tester.pump();
}

CanvasElementId _addRect(CanvasRuntime runtime, String id) {
  final elementId = CanvasElementId(id);
  runtime.edits.edit((edit) {
    edit.addElement(
      CanvasRectElement(id: elementId, size: const Size(60, 40)),
      layerId: CanvasLayerId('layer-auto-0'),
    );
  });

  return elementId;
}

CanvasElement _findElement(CanvasDocument document, CanvasElementId id) {
  final element = _tryFindElement(document, id);
  if (element == null) {
    throw StateError('Missing element ${id.value}.');
  }

  return element;
}

CanvasElement? _tryFindElement(CanvasDocument document, CanvasElementId id) {
  for (final layer in document.layers) {
    for (final element in layer.elements) {
      if (element.id == id) {
        return element;
      }
    }
  }

  return null;
}

Future<void> _tapTool(
  WidgetTester tester,
  String key,
  CanvasDrawTool expected,
  CanvasExampleViewModel viewModel,
) async {
  await tester.tap(find.byKey(ValueKey(key)));
  await tester.pump();
  expect(viewModel.drawTool, expected);
}

String _colorLabel(Color color) {
  return '#${color.toARGB32().toRadixString(16).padLeft(8, '0')}';
}

void _tapPointer(CanvasRuntime runtime, Offset position) {
  runtime.tools.handlePointer(
    CanvasPointerSample(
      pointerId: 1,
      position: position,
      phase: CanvasPointerLifecyclePhase.down,
      kind: PointerDeviceKind.touch,
      timestampMs: 1,
    ),
  );
  runtime.tools.handlePointer(
    CanvasPointerSample(
      pointerId: 1,
      position: position,
      phase: CanvasPointerLifecyclePhase.up,
      kind: PointerDeviceKind.touch,
      timestampMs: 2,
    ),
  );
}
