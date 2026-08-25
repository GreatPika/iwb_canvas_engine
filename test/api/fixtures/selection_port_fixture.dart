// Test bodies are named helpers so DCM metrics stay on each scenario; the
// assertions live in those helpers and DCM does not follow tear-offs.
// ignore_for_file: missing-test-assertion

import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import '../../support/runtime_with_document.dart';

void main() {
  test(
    'direct selection changes publish selection revisions and no actions',
    _directSelectionChangesPublishSelectionOnly,
  );
  test(
    'delete availability is derived from current selection and document facts',
    _deleteAvailabilityIsDerivedFromCurrentSelectionAndDocumentFacts,
  );
}

void _deleteAvailabilityIsDerivedFromCurrentSelectionAndDocumentFacts() {
  final runtime = runtimeWithDocument(_document());
  addTearDown(runtime.dispose);
  final notifications = <CanvasRuntimeState>[];
  final beforeSelectionRevision = runtime.state.value.revisions.selection;
  final beforeDocumentRevision = runtime.state.value.revisions.document;
  runtime.state.addListener(() => notifications.add(runtime.state.value));

  _expectEmptyDeleteAvailability(runtime, notifications);
  _selectDeletableContent(runtime, notifications, beforeSelectionRevision);
  _makeSelectedContentNonDeletable(
    runtime,
    notifications,
    beforeDocumentRevision,
    beforeSelectionRevision,
  );
}

void _expectEmptyDeleteAvailability(
  CanvasRuntime runtime,
  List<CanvasRuntimeState> notifications,
) {
  expect(
    runtime.selection.deleteAvailability,
    const CanvasSelectionDeleteAvailability(
      hasSelection: false,
      allSelectedElementsDeletable: false,
    ),
  );
  expect(notifications, isEmpty);
}

void _selectDeletableContent(
  CanvasRuntime runtime,
  List<CanvasRuntimeState> notifications,
  int beforeSelectionRevision,
) {
  runtime.selection.setSelection([CanvasElementId('content-a')]);
  expect(
    runtime.selection.deleteAvailability,
    const CanvasSelectionDeleteAvailability(
      hasSelection: true,
      allSelectedElementsDeletable: true,
    ),
  );
  expect(notifications.last.revisions.selection, beforeSelectionRevision + 1);
}

void _makeSelectedContentNonDeletable(
  CanvasRuntime runtime,
  List<CanvasRuntimeState> notifications,
  int beforeDocumentRevision,
  int beforeSelectionRevision,
) {
  runtime.edits.edit((edit) {
    edit.updateElement(
      CanvasRectElementUpdate(
        id: CanvasElementId('content-a'),
        isDeletable: const CanvasFieldSet(false),
      ),
    );
  });

  expect(
    runtime.selection.deleteAvailability,
    const CanvasSelectionDeleteAvailability(
      hasSelection: true,
      allSelectedElementsDeletable: false,
    ),
  );
  expect(notifications.last.revisions.document, beforeDocumentRevision + 1);
  expect(notifications.last.revisions.selection, beforeSelectionRevision + 1);
}

Future<void> _directSelectionChangesPublishSelectionOnly() async {
  final runtime = runtimeWithDocument(_document());
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
  final beforeSelectionRevision = runtime.state.value.revisions.selection;
  final beforeDocumentRevision = runtime.state.value.revisions.document;

  runtime.selection.setSelection([
    CanvasElementId('content-b'),
    CanvasElementId('missing'),
    CanvasElementId('background-a'),
    CanvasElementId('hidden-a'),
  ]);

  expect(runtime.selection.selectedElementIds, {CanvasElementId('content-b')});
  expect(runtime.state.value.revisions.selection, beforeSelectionRevision + 1);
  expect(runtime.state.value.revisions.document, beforeDocumentRevision);
  runtime.selection.setSelection([CanvasElementId('content-b')]);
  expect(runtime.state.value.revisions.selection, beforeSelectionRevision + 1);
}

void _expectToggleAndClear(CanvasRuntime runtime) {
  final beforeToggleSelectionRevision = runtime.state.value.revisions.selection;

  runtime.selection.toggleSelection(CanvasElementId('content-a'));
  expect(runtime.selection.selectedElementIds, {
    CanvasElementId('content-a'),
    CanvasElementId('content-b'),
  });
  expect(
    runtime.state.value.revisions.selection,
    beforeToggleSelectionRevision + 1,
  );

  final beforeClearSelectionRevision = runtime.state.value.revisions.selection;

  runtime.selection.clearSelection();
  expect(runtime.selection.selectedElementIds, isEmpty);
  expect(
    runtime.state.value.revisions.selection,
    beforeClearSelectionRevision + 1,
  );
}

void _expectSelectAll(CanvasRuntime runtime) {
  final beforeSelectAllRevision = runtime.state.value.revisions.selection;
  final beforeDocumentRevision = runtime.state.value.revisions.document;

  runtime.selection.selectAll();
  expect(runtime.selection.selectedElementIds, {
    CanvasElementId('content-a'),
    CanvasElementId('content-b'),
  });
  expect(runtime.state.value.revisions.selection, beforeSelectAllRevision + 1);

  final beforeSelectAllIncludingHiddenRevision =
      runtime.state.value.revisions.selection;

  runtime.selection.selectAll(onlySelectable: false);
  expect(runtime.selection.selectedElementIds, {
    CanvasElementId('content-a'),
    CanvasElementId('content-b'),
    CanvasElementId('hidden-a'),
    CanvasElementId('not-selectable-a'),
  });
  expect(
    runtime.state.value.revisions.selection,
    beforeSelectAllIncludingHiddenRevision + 1,
  );
  expect(runtime.state.value.revisions.document, beforeDocumentRevision);
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
