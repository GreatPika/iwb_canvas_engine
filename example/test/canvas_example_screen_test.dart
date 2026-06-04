import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine_example/src/canvas_example_defaults.dart';
import 'package:iwb_canvas_engine_example/src/canvas_example_screen.dart';
import 'package:iwb_canvas_engine_example/src/canvas_example_view_model.dart';
import 'package:iwb_canvas_engine_example/src/canvas_pending_line_overlay.dart';

void main() {
  _registerSurfaceAndPointerTests();
  _registerLineDragSurfaceTest();
  _registerSurfaceStyleTest();
  _registerSurfaceStabilityTest();
  _registerDrawToolDockTest();
  _registerDrawColorDockTest();
  _registerCameraPanControlTest();
  _registerGridDockTest();
  _registerBackgroundDockTest();
  _registerClearDockTest();
  _registerSelectionRotateDockTest();
  _registerSelectionFlipVerticalDockTest();
  _registerSelectionFlipHorizontalDockTest();
  _registerSelectionDeleteDockTest();
  _registerAddSampleEntryPointTest();
  _registerTextStyleDockTest();
  _registerInlineTextEditOverlayCommitTest();
  _registerInlineTextEditSurfaceDoubleTapTest();
  _registerInlineTextEditOverlayCoverageTest();
  _registerInlineTextEditOverlayDismissTest();
  _registerInlineTextEditOverlayStaleCommitTest();
  _registerJsonExportDialogTest();
  _registerJsonImportDialogPrefillTest();
  _registerJsonImportDialogSuccessTest();
  _registerJsonImportDialogFailureTest();
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

void _registerLineDragSurfaceTest() {
  testWidgets('screen line tool commits first pointer drag', (tester) async {
    final runtime = createCanvasExampleRuntime();
    addTearDown(runtime.dispose);
    final viewModel = CanvasExampleViewModel(runtime: runtime);
    addTearDown(viewModel.dispose);
    await _pumpScreen(tester, viewModel);

    await tester.tap(find.byKey(const ValueKey('mode.draw')));
    await tester.pump();
    await _tapTool(tester, 'tool.line', CanvasDrawTool.line, viewModel);

    await tester.drag(find.byType(CanvasSurface), const Offset(40, 20));
    await tester.pump();

    final line = _singleLineElement(viewModel.document);
    expect(line.start, isNot(equals(line.end)));
    expect(viewModel.preview, isA<CanvasNoPreview>());
  });
}

void _registerSurfaceStyleTest() {
  testWidgets('screen uses readable selection surface style', (
    tester,
  ) async {
    final viewModel = CanvasExampleViewModel();
    addTearDown(viewModel.dispose);
    await _pumpScreen(tester, viewModel);

    final surface = tester.widget<CanvasSurface>(find.byType(CanvasSurface));

    expect(surface.selectionStyle.color.toARGB32(), 0xFFFFFF00);
    expect(surface.selectionStyle.strokeWidth, 2);
    expect(surface.selectionStyle.haloWidth, 0);
  });
}

void _registerSurfaceStabilityTest() {
  testWidgets('runtime notifications do not recreate CanvasSurface', (
    tester,
  ) async {
    final viewModel = CanvasExampleViewModel();
    addTearDown(viewModel.dispose);
    await _pumpScreen(tester, viewModel);
    final surfaceBefore = tester.widget<CanvasSurface>(
      find.byType(CanvasSurface),
    );
    final resolverBefore = surfaceBefore.resourceResolver;

    viewModel.panCameraBy(const Offset(5, 0));
    await tester.pump();

    final surfaceAfter = tester.widget<CanvasSurface>(
      find.byType(CanvasSurface),
    );
    expect(viewModel.cameraOffset, const Offset(5, 0));
    expect(surfaceAfter, same(surfaceBefore));
    expect(surfaceAfter.resourceResolver, same(resolverBefore));
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

void _registerGridDockTest() {
  testWidgets(
    'grid toggle and every grid size control mutate public document',
    (tester) async {
      final viewModel = CanvasExampleViewModel();
      addTearDown(viewModel.dispose);
      await _pumpScreen(tester, viewModel);

      await tester.tap(find.byKey(const ValueKey('grid.menu')));
      await tester.pump();
      await tester.tap(find.byType(Switch));
      await tester.pump();

      expect(viewModel.grid.enabled, isTrue);

      for (final size in viewModel.gridSizes) {
        await tester.tap(find.text(size.toStringAsFixed(0)).last);
        await tester.pump();
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
    await tester.tap(find.byKey(const ValueKey('system.menu')));
    await tester.pump();

    for (final color in viewModel.backgroundColors) {
      await tester.tap(
        find.byKey(ValueKey('background.color.${color.toARGB32()}')),
      );
      await tester.pump();
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

    await tester.tap(find.byKey(const ValueKey('system.menu')));
    await tester.pump();
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

void _registerTextStyleDockTest() {
  testWidgets('text controls update selected public text element', (
    tester,
  ) async {
    final viewModel = CanvasExampleViewModel();
    addTearDown(viewModel.dispose);
    final textId = _addText(viewModel.runtime, 'screen-style-text');
    viewModel.setSelection([textId]);
    await _pumpScreen(tester, viewModel);

    expect(find.byKey(const ValueKey('text.bold')), findsOneWidget);
    await _applyTextStyleDockControls(tester);
    _expectUpdatedTextStyle(viewModel.document, textId);
  });
}

void _registerInlineTextEditOverlayCommitTest() {
  testWidgets(
    'inline text overlay focuses and commits through public command',
    (tester) async {
      final viewModel = CanvasExampleViewModel();
      addTearDown(viewModel.dispose);
      final textId = _addText(viewModel.runtime, 'screen-edit-text');
      await _pumpScreen(tester, viewModel);

      await _openTextOverlay(tester, viewModel);

      final editor = tester.widget<EditableText>(find.byType(EditableText));
      expect(editor.focusNode.hasFocus, isTrue);
      _expectTextDocumentState(viewModel, textId, text: 'hello');

      await tester.enterText(find.byType(EditableText), 'updated');
      await tester.pump();
      _commitInlineTextEdit(tester);
      await tester.pump();

      _expectTextDocumentState(viewModel, textId, text: 'updated');
      expect(find.byType(EditableText), findsNothing);
    },
  );
}

void _registerInlineTextEditSurfaceDoubleTapTest() {
  testWidgets('surface double tap opens inline text overlay after selection', (
    tester,
  ) async {
    final viewModel = CanvasExampleViewModel();
    addTearDown(viewModel.dispose);
    final textId = _addText(viewModel.runtime, 'screen-double-tap-text');
    await _pumpScreen(tester, viewModel);

    await _tapSurfaceAt(tester, const Offset(60, 0));
    await tester.pump();

    expect(viewModel.runtime.textEditing.activeSession.value, isNull);
    expect(viewModel.selectedElementIds, {textId});

    await _tapSurfaceAt(tester, const Offset(61, 0));
    await tester.pump();
    await tester.pump();

    expect(viewModel.runtime.textEditing.activeSession.value, isNotNull);
    expect(find.byType(EditableText), findsOneWidget);
    _expectTextDocumentState(viewModel, textId, text: 'hello');
  });
}

void _registerInlineTextEditOverlayCoverageTest() {
  testWidgets('inline text overlay covers the target text bounds', (
    tester,
  ) async {
    final viewModel = CanvasExampleViewModel();
    addTearDown(viewModel.dispose);
    _addWideText(viewModel.runtime, 'screen-wide-edit-text');
    await _pumpScreen(tester, viewModel);

    await _openTextOverlay(tester, viewModel);

    final overlaySize = _textEditBoundsSize(tester);
    final targetBounds = _activeEditBoundsLocal(viewModel);
    expect(overlaySize.width, greaterThan(0));
    expect(overlaySize.width, greaterThan(targetBounds.width));
    expect(overlaySize.height, greaterThan(0));

    await tester.enterText(
      find.byType(EditableText),
      'wide editable text\nwrapped line',
    );
    await tester.pump();
    final resizedOverlaySize = _textEditBoundsSize(tester);
    expect(resizedOverlaySize.height, greaterThan(overlaySize.height));
    expect(resizedOverlaySize.height, _activeEditBoundsLocal(viewModel).height);
  });
}

void _registerInlineTextEditOverlayDismissTest() {
  testWidgets('inline text overlay dismisses without document mutation', (
    tester,
  ) async {
    final viewModel = CanvasExampleViewModel();
    addTearDown(viewModel.dispose);
    final textId = _addText(viewModel.runtime, 'screen-dismiss-text');
    await _pumpScreen(tester, viewModel);

    await _openTextOverlay(tester, viewModel);
    await tester.enterText(find.byType(EditableText), 'ignored');
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();

    _expectTextDocumentState(viewModel, textId, text: 'hello');
    expect(find.byType(EditableText), findsNothing);
  });
}

void _registerInlineTextEditOverlayStaleCommitTest() {
  testWidgets('stale inline text commit leaves document unchanged', (
    tester,
  ) async {
    final viewModel = CanvasExampleViewModel();
    addTearDown(viewModel.dispose);
    final textId = _addText(viewModel.runtime, 'screen-stale-edit-text');
    await _pumpScreen(tester, viewModel);

    await _openTextOverlay(tester, viewModel);
    final session = _activeTextEditSession(viewModel);
    _expectSurfaceTextSuppressed();
    await tester.enterText(find.byType(EditableText), 'stale update');
    await tester.pump();
    viewModel.runtime.edits.loadDocument(
      _documentWithText(textId, 'replacement'),
    );
    await tester.pump();

    expect(session.commit(), isFalse);
    await tester.pump();

    _expectTextDocumentState(viewModel, textId, text: 'replacement');
    expect(viewModel.runtime.textEditing.activeSession.value, isNull);
    expect(find.byType(EditableText), findsNothing);
    _expectSurfaceTextPainted();
  });
}

void _registerJsonExportDialogTest() {
  testWidgets('export dialog shows schema v1 JSON and copies it', (
    tester,
  ) async {
    final clipboard = _ClipboardRecorder();
    _installClipboardRecorder(clipboard);
    final viewModel = CanvasExampleViewModel();
    addTearDown(viewModel.dispose);
    _addText(viewModel.runtime, 'screen-export-text');
    await _pumpScreen(tester, viewModel);

    await _openJsonExportDialog(tester);
    final json = _exportDialogJson(tester);

    expect(json, contains('"schemaVersion":1'));
    expect(viewModel.lastExportedJson, json);

    await tester.tap(find.byKey(const ValueKey('json.export.copy')));
    await tester.pump();
    expect(clipboard.copiedText, json);
  });
}

void _registerJsonImportDialogPrefillTest() {
  testWidgets('import dialog pre-fills the last exported JSON', (tester) async {
    final viewModel = CanvasExampleViewModel();
    addTearDown(viewModel.dispose);
    final json = viewModel.exportDocumentJson();
    await _pumpScreen(tester, viewModel);

    await _openJsonImportDialog(tester);

    expect(_textFieldValue(const ValueKey('json.import.text'), tester), json);
  });
}

void _registerJsonImportDialogSuccessTest() {
  testWidgets('valid import dialog JSON replaces the public document', (
    tester,
  ) async {
    final viewModel = CanvasExampleViewModel();
    addTearDown(viewModel.dispose);
    final textId = CanvasElementId('screen-import-text');
    final json = encodeCanvasDocumentToJson(
      _documentWithText(textId, 'imported'),
    );
    await _pumpScreen(tester, viewModel);

    await _openJsonImportDialog(tester);
    await tester.enterText(
      find.byKey(const ValueKey('json.import.text')),
      json,
    );
    await tester.tap(find.byKey(const ValueKey('json.import.submit')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('json.import.text')), findsNothing);
    expect(
      (_findElement(viewModel.document, textId) as CanvasTextElement).text,
      'imported',
    );
  });
}

void _registerJsonImportDialogFailureTest() {
  testWidgets('invalid import dialog JSON shows snackbar without mutation', (
    tester,
  ) async {
    final viewModel = CanvasExampleViewModel();
    addTearDown(viewModel.dispose);
    _addText(viewModel.runtime, 'screen-invalid-json-text');
    final before = viewModel.document;
    await _pumpScreen(tester, viewModel);

    await _openJsonImportDialog(tester);
    await tester.enterText(find.byKey(const ValueKey('json.import.text')), '{');
    await tester.tap(find.byKey(const ValueKey('json.import.submit')));
    await tester.pumpAndSettle();

    expect(viewModel.document, same(before));
    expect(find.byKey(const ValueKey('json.import.text')), findsOneWidget);
    expect(
      find.text('Unable to import schema v1 document JSON.'),
      findsOneWidget,
    );
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

CanvasElementId _addText(CanvasRuntime runtime, String id) {
  final elementId = CanvasElementId(id);
  runtime.edits.edit((edit) {
    edit.addElement(
      CanvasTextElement(
        id: elementId,
        text: 'hello',
        color: const Color(0xFF111827),
        textDirection: TextDirection.ltr,
        transform: CanvasTransform.translation(const Offset(60, 0)),
      ),
      layerId: CanvasLayerId('layer-auto-0'),
    );
  });

  return elementId;
}

CanvasElementId _addWideText(CanvasRuntime runtime, String id) {
  final elementId = CanvasElementId(id);
  runtime.edits.edit((edit) {
    edit.addElement(
      CanvasTextElement(
        id: elementId,
        text: 'wide editable text',
        color: const Color(0xFF111827),
        textDirection: TextDirection.ltr,
        maxWidth: 620,
        lineHeight: 2,
        transform: CanvasTransform.translation(const Offset(60, 0)),
      ),
      layerId: CanvasLayerId('layer-auto-0'),
    );
  });

  return elementId;
}

CanvasDocument _documentWithText(CanvasElementId id, String text) {
  return CanvasDocument(
    layers: [
      CanvasLayer(
        id: CanvasLayerId('layer-auto-0'),
        elements: [
          CanvasTextElement(
            id: id,
            text: text,
            color: const Color(0xFF111827),
            textDirection: TextDirection.ltr,
          ),
        ],
      ),
      CanvasLayer(id: CanvasLayerId('layer-auto-1')),
    ],
  );
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

CanvasLineElement _singleLineElement(CanvasDocument document) {
  final lines = <CanvasLineElement>[];
  for (final layer in document.layers) {
    for (final element in layer.elements) {
      if (element case final CanvasLineElement line) {
        lines.add(line);
      }
    }
  }

  return lines.single;
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

Future<void> _applyTextStyleDockControls(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('text.bold')));
  await tester.pump();
  await tester.tap(find.byKey(const ValueKey('text.italic')));
  await tester.pump();
  await tester.tap(find.byKey(const ValueKey('text.underline')));
  await tester.pump();
  await tester.tap(find.byKey(const ValueKey('text.align.center')));
  await tester.pump();
  tester
      .widget<Slider>(find.byKey(const ValueKey('text.font.size.slider')))
      .onChanged
      ?.call(32);
  await tester.pump();
  tester
      .widget<Slider>(find.byKey(const ValueKey('text.line.height.slider')))
      .onChanged
      ?.call(1.5);
  await tester.pump();
  tester
      .widget<GestureDetector>(
        find.byKey(
          ValueKey('text.color.${const Color(0xFFE53935).toARGB32()}'),
        ),
      )
      .onTap
      ?.call();
  await tester.pump();
}

void _expectUpdatedTextStyle(CanvasDocument document, CanvasElementId textId) {
  final text = _findElement(document, textId) as CanvasTextElement;
  expect(text.isBold, isTrue);
  expect(text.isItalic, isTrue);
  expect(text.isUnderline, isTrue);
  expect(text.align, TextAlign.center);
  expect(text.fontSize, 32);
  expect(text.lineHeight, 1.5);
  expect(text.color.toARGB32(), 0xFFE53935);
}

String _textFieldValue(ValueKey<String> key, WidgetTester tester) {
  final field = tester.widget<TextField>(find.byKey(key));
  final controller = field.controller;
  if (controller == null) {
    fail('Expected text field ${key.value} to have a controller.');
  }

  return controller.text;
}

Size _textEditBoundsSize(WidgetTester tester) {
  return tester.getSize(find.byType(EditableText));
}

Rect _activeEditBoundsLocal(CanvasExampleViewModel viewModel) {
  final bounds = _activeTextEditSession(viewModel).geometry.editBoundsLocal;
  if (bounds == null) {
    fail('Expected active text edit geometry.');
  }

  return bounds;
}

CanvasTextEditSession _activeTextEditSession(CanvasExampleViewModel viewModel) {
  final session = viewModel.runtime.textEditing.activeSession.value;
  if (session == null) {
    fail('Expected an active text edit session.');
  }

  return session;
}

void _expectTextDocumentState(
  CanvasExampleViewModel viewModel,
  CanvasElementId textId, {
  required String text,
}) {
  final element = _findElement(viewModel.document, textId) as CanvasTextElement;
  expect(element.text, text);
  expect(element.isVisible, isTrue);
}

void _expectSurfaceTextSuppressed() {
  expect(_surfacePaintHost(), isNot(paints..paragraph()));
}

void _expectSurfaceTextPainted() {
  expect(_surfacePaintHost(), paints..paragraph());
}

Finder _surfacePaintHost() {
  return find.byKey(const ValueKey<String>('iwb_canvas_surface.paint_host'));
}

String _exportDialogJson(WidgetTester tester) {
  return _textFieldValue(const ValueKey('json.export.text'), tester);
}

void _installClipboardRecorder(_ClipboardRecorder recorder) {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') {
          recorder.copiedText =
              (call.arguments as Map<Object?, Object?>)['text'] as String?;
        }

        return null;
      });
  addTearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });
}

Future<void> _openJsonExportDialog(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('system.menu')));
  await tester.pump();
  await tester.tap(find.byKey(const ValueKey('json.export')));
  await tester.pumpAndSettle();
  expect(find.byKey(const ValueKey('json.export.text')), findsOneWidget);
}

Future<void> _openJsonImportDialog(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('system.menu')));
  await tester.pump();
  await tester.tap(find.byKey(const ValueKey('json.import')));
  await tester.pumpAndSettle();
  expect(find.byKey(const ValueKey('json.import.text')), findsOneWidget);
}

Future<void> _openTextOverlay(
  WidgetTester tester,
  CanvasExampleViewModel viewModel,
) async {
  viewModel.runtime.tools.handleDoubleTap(position: const Offset(60, 0));
  await tester.pump();
  await tester.pump();
  expect(viewModel.runtime.textEditing.activeSession.value, isNotNull);
  expect(find.byType(EditableText), findsOneWidget);
}

void _commitInlineTextEdit(WidgetTester tester) {
  tester
      .widget<EditableText>(find.byType(EditableText))
      .onEditingComplete
      ?.call();
}

Future<void> _tapSurfaceAt(WidgetTester tester, Offset localPosition) async {
  final topLeft = tester.getTopLeft(_surfacePaintHost());
  await tester.tapAt(topLeft + localPosition);
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

final class _ClipboardRecorder {
  String? copiedText;
}
