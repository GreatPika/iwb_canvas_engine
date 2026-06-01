import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine/src/runtime/runtime_root.dart';

void main() {
  test(
    'selection changes publish selection facts without document effects',
    () {
      final root = RuntimeRoot(
        initialDocument: _document(),
        config: const CanvasRuntimeConfig(),
      );
      final selection = root.selection;

      final firstProjection = root.readDocument();
      expect(root.projectionBuildCount, 1);

      _verifySelectionNormalization(root, selection, firstProjection);
      _verifyToggleAndNoOpBehavior(root, selection);
      _verifyClearAndSelectAll(root, selection);
      _verifyEditPrunesSelectionAtomically(root, selection);

      root.dispose();
    },
  );

  test('public facade exposes the selection port', () {
    final runtime = CanvasRuntime(initialDocument: _document());

    runtime.selection.setSelection([CanvasElementId('element-a')]);

    expect(runtime.selection.selectedElementIds, {
      CanvasElementId('element-a'),
    });
    expect(runtime.state.value.revisions.selection, 1);
    expect(runtime.state.value.summary.selectedCount, 1);

    runtime.dispose();
  });
}

void _verifySelectionNormalization(
  RuntimeRoot root,
  CanvasSelectionPort selection,
  CanvasDocument firstProjection,
) {
  selection.setSelection([
    CanvasElementId('element-a'),
    CanvasElementId('missing'),
    CanvasElementId('background-a'),
    CanvasElementId('hidden-a'),
    CanvasElementId('not-selectable-a'),
  ]);

  expect(selection.selectedElementIds, {CanvasElementId('element-a')});
  expect(root.selectionFacts.selectedElementIds, {
    CanvasElementId('element-a'),
  });
  expect(root.state.value.revisions.document, 0);
  expect(root.state.value.revisions.selection, 1);
  expect(root.state.value.summary.selectedCount, 1);
  expect(root.projectionBuildCount, 1);
  expect(identical(root.readDocument(), firstProjection), isTrue);
}

void _verifyToggleAndNoOpBehavior(
  RuntimeRoot root,
  CanvasSelectionPort selection,
) {
  selection.setSelection([CanvasElementId('element-a')]);
  expect(root.state.value.revisions.selection, 1);

  selection.toggleSelection(CanvasElementId('element-b'));
  expect(selection.selectedElementIds, {
    CanvasElementId('element-a'),
    CanvasElementId('element-b'),
  });
  expect(root.state.value.revisions.selection, 2);
  expect(root.state.value.revisions.document, 0);
  expect(root.projectionBuildCount, 1);

  selection.toggleSelection(CanvasElementId('missing'));
  expect(root.state.value.revisions.selection, 2);
}

void _verifyClearAndSelectAll(RuntimeRoot root, CanvasSelectionPort selection) {
  selection.clearSelection();
  expect(selection.selectedElementIds, isEmpty);
  expect(root.state.value.revisions.selection, 3);
  selection.clearSelection();
  expect(root.state.value.revisions.selection, 3);

  selection.selectAll();
  expect(selection.selectedElementIds, {
    CanvasElementId('element-a'),
    CanvasElementId('element-b'),
  });
  expect(root.state.value.revisions.selection, 4);
  expect(root.state.value.summary.selectedCount, 2);

  selection.selectAll(onlySelectable: false);
  expect(selection.selectedElementIds, {
    CanvasElementId('element-a'),
    CanvasElementId('element-b'),
    CanvasElementId('hidden-a'),
    CanvasElementId('not-selectable-a'),
  });
  expect(root.state.value.revisions.selection, 5);
  expect(root.state.value.summary.selectedCount, 4);
}

void _verifyEditPrunesSelectionAtomically(
  RuntimeRoot root,
  CanvasSelectionPort selection,
) {
  selection.setSelection([CanvasElementId('element-a')]);
  final beforeDocumentRevision = root.state.value.revisions.document;
  final beforeSelectionRevision = root.state.value.revisions.selection;
  final snapshots = <CanvasRuntimeState>[];
  root.state.addListener(() {
    snapshots.add(root.state.value);
  });

  root.edits.edit((edit) {
    edit.removeElement(CanvasElementId('element-a'));
  });

  expect(selection.selectedElementIds, isEmpty);
  expect(root.state.value.revisions.document, beforeDocumentRevision + 1);
  expect(root.state.value.revisions.selection, beforeSelectionRevision + 1);
  expect(snapshots, hasLength(1));
  expect(snapshots.single.summary.selectedCount, 0);
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
            id: CanvasElementId('element-a'),
            size: const Size(2, 2),
          ),
          CanvasRectElement(
            id: CanvasElementId('element-b'),
            size: const Size(3, 3),
          ),
          CanvasRectElement(
            id: CanvasElementId('hidden-a'),
            size: const Size(4, 4),
            isVisible: false,
          ),
          CanvasRectElement(
            id: CanvasElementId('not-selectable-a'),
            size: const Size(5, 5),
            isSelectable: false,
          ),
        ],
      ),
    ],
  );
}
