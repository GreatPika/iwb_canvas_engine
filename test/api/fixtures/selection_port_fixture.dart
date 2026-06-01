// Test bodies are named helpers so DCM metrics stay on each scenario; the
// assertions live in those helpers and DCM does not follow tear-offs.
// ignore_for_file: missing-test-assertion

import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';

void main() {
  test(
    'direct selection changes publish selection revisions and no actions',
    _directSelectionChangesPublishSelectionOnly,
  );
}

Future<void> _directSelectionChangesPublishSelectionOnly() async {
  final runtime = CanvasRuntime(initialDocument: _document());
  final actions = <CanvasActionCommitted>[];
  final subscription = runtime.actions.listen(actions.add);
  addTearDown(() async {
    await subscription.cancel();
    runtime.dispose();
  });

  _expectFilteredSetSelection(runtime);
  _expectToggleAndClear(runtime);
  _expectSelectAll(runtime);

  await Future<void>.delayed(Duration.zero);
  expect(actions, isEmpty);
}

void _expectFilteredSetSelection(CanvasRuntime runtime) {
  expect(runtime.state.value.revisions.selection, 0);
  runtime.selection.setSelection([
    CanvasElementId('content-b'),
    CanvasElementId('missing'),
    CanvasElementId('background-a'),
    CanvasElementId('hidden-a'),
  ]);

  expect(runtime.selection.selectedElementIds, {CanvasElementId('content-b')});
  expect(runtime.state.value.revisions.selection, 1);
  expect(runtime.state.value.revisions.document, 0);
  runtime.selection.setSelection([CanvasElementId('content-b')]);
  expect(runtime.state.value.revisions.selection, 1);
}

void _expectToggleAndClear(CanvasRuntime runtime) {
  runtime.selection.toggleSelection(CanvasElementId('content-a'));
  expect(runtime.selection.selectedElementIds, {
    CanvasElementId('content-a'),
    CanvasElementId('content-b'),
  });
  expect(runtime.state.value.revisions.selection, 2);

  runtime.selection.clearSelection();
  expect(runtime.selection.selectedElementIds, isEmpty);
  expect(runtime.state.value.revisions.selection, 3);
}

void _expectSelectAll(CanvasRuntime runtime) {
  runtime.selection.selectAll();
  expect(runtime.selection.selectedElementIds, {
    CanvasElementId('content-a'),
    CanvasElementId('content-b'),
  });
  expect(runtime.state.value.revisions.selection, 4);

  runtime.selection.selectAll(onlySelectable: false);
  expect(runtime.selection.selectedElementIds, {
    CanvasElementId('content-a'),
    CanvasElementId('content-b'),
    CanvasElementId('hidden-a'),
    CanvasElementId('not-selectable-a'),
  });
  expect(runtime.state.value.revisions.selection, 5);
  expect(runtime.state.value.revisions.document, 0);
}

CanvasDocument _document() {
  return CanvasDocument(
    backgroundElements: [
      CanvasRectElement(
        id: CanvasElementId('background-a'),
        size: const Size(1, 1),
      ),
    ],
    layers: [
      CanvasLayer(
        id: CanvasLayerId('layer-a'),
        elements: [
          CanvasRectElement(
            id: CanvasElementId('content-a'),
            size: const Size(2, 2),
          ),
          CanvasRectElement(
            id: CanvasElementId('content-b'),
            size: const Size(2, 2),
          ),
          CanvasRectElement(
            id: CanvasElementId('hidden-a'),
            size: const Size(2, 2),
            isVisible: false,
          ),
          CanvasRectElement(
            id: CanvasElementId('not-selectable-a'),
            size: const Size(2, 2),
            isSelectable: false,
          ),
        ],
      ),
    ],
  );
}
