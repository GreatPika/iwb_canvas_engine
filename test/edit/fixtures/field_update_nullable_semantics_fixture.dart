import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine/src/edit/commit_plan.dart';
import 'package:iwb_canvas_engine/src/edit/draft_document.dart';
import 'package:iwb_canvas_engine/src/runtime/runtime_root.dart';

void main() {
  test('nullable clears update nullable element fields', () {
    expect(_expectNullableClearUpdatesField, returnsNormally);
  });

  test('dynamic non-nullable clear requests reject before install', () {
    expect(_expectDynamicNonNullableClearRejected, returnsNormally);
  });

  test('non-invertible transform updates reject before draft mutation', () {
    expect(_expectNonInvertibleTransformRejected, returnsNormally);
  });

  test('mismatched update kind rejects before draft mutation', () {
    expect(_expectMismatchedUpdateKindRejected, returnsNormally);
  });

  test('geometry updates advance bounds revision', () {
    expect(_expectGeometryUpdateAdvancesBoundsRevision, returnsNormally);
  });

  test('visibility updates request selection pruning', () {
    expect(_expectVisibilityUpdateTouchesSelection, returnsNormally);
  });
}

void _expectNullableClearUpdatesField() {
  final root = RuntimeRoot(
    initialDocument: _document(),
    config: const CanvasRuntimeConfig(),
  );

  final changed = root.edits.edit((edit) {
    return edit.updateElement(
      CanvasRectElementUpdate(
        id: CanvasElementId('rect-1'),
        fillColor: const CanvasFieldClear<Color>(),
      ),
    );
  });

  final rect = root.readDocument().layers.single.elements.single;
  expect(changed, isTrue);
  expect(rect, isA<CanvasRectElement>());
  expect((rect as CanvasRectElement).fillColor, isNull);
  expect(root.documentFacts.documentRevision, 1);
}

void _expectDynamicNonNullableClearRejected() {
  final effectBatches = <List<CommitEffect>>[];
  final root = _runtimeRoot(effectBatches);
  final before = root.readDocument().layers.single.elements.single;

  expect(
    () => root.edits.edit((edit) {
      final Object clear = const CanvasFieldClear<double>();
      final update = CanvasRectElementUpdate(
        id: CanvasElementId('rect-1'),
        strokeWidth: clear as CanvasFieldUpdate<double>,
      );
      edit.updateElement(update);
    }),
    throwsA(anyOf(isA<TypeError>(), isA<CanvasDataException>())),
  );

  expect(root.readDocument().layers.single.elements.single, same(before));
  expect(root.documentFacts.documentRevision, 0);
  expect(effectBatches, isEmpty);
}

void _expectNonInvertibleTransformRejected() {
  final effectBatches = <List<CommitEffect>>[];
  final root = _runtimeRoot(effectBatches);

  expect(
    () => root.edits.edit((edit) {
      edit.updateElement(
        CanvasRectElementUpdate(
          id: CanvasElementId('rect-1'),
          transform: CanvasFieldSet(
            CanvasTransform(a: 0, b: 0, c: 0, d: 0, tx: 0, ty: 0),
          ),
        ),
      );
    }),
    throwsA(isA<CanvasDataException>()),
  );

  expect(root.documentFacts.documentRevision, 0);
  expect(effectBatches, isEmpty);
}

void _expectMismatchedUpdateKindRejected() {
  final effectBatches = <List<CommitEffect>>[];
  final root = _runtimeRoot(effectBatches);

  expect(
    () => root.edits.edit((edit) {
      edit.updateElement(
        CanvasTextElementUpdate(
          id: CanvasElementId('rect-1'),
          text: const CanvasFieldSet('wrong kind'),
        ),
      );
    }),
    throwsArgumentError,
  );

  expect(root.documentFacts.documentRevision, 0);
  expect(effectBatches, isEmpty);
}

void _expectGeometryUpdateAdvancesBoundsRevision() {
  final root = RuntimeRoot(
    initialDocument: _document(),
    config: const CanvasRuntimeConfig(),
  );

  final changed = root.edits.edit((edit) {
    return edit.updateElement(
      CanvasRectElementUpdate(
        id: CanvasElementId('rect-1'),
        size: const CanvasFieldSet(Size(2, 2)),
      ),
    );
  });

  expect(changed, isTrue);
  expect(root.documentFacts.documentRevision, 1);
  expect(root.frameRevisions.boundsRevision, 1);
  expect(root.frameRevisions.elementVisualRevision, 1);
}

void _expectVisibilityUpdateTouchesSelection() {
  final draft = DraftDocument(
    _document(),
    selectedElementIds: [CanvasElementId('rect-1')],
  );

  draft.updateElement(
    CanvasRectElementUpdate(
      id: CanvasElementId('rect-1'),
      isVisible: const CanvasFieldSet(false),
    ),
  );

  expect(draft.touchedSet.selection, isTrue);
  expect(draft.touchedSet.geometryElementIds, {CanvasElementId('rect-1')});
}

CanvasDocument _document() {
  return CanvasDocument(
    layers: [
      CanvasLayer(
        id: CanvasLayerId('layer-1'),
        elements: [
          CanvasRectElement(
            id: CanvasElementId('rect-1'),
            size: const Size(1, 1),
            fillColor: const Color(0xFF00FF00),
            strokeWidth: 1,
          ),
        ],
      ),
    ],
  );
}

RuntimeRoot _runtimeRoot(List<List<CommitEffect>> effectBatches) {
  return RuntimeRoot(
    initialDocument: _document(),
    config: const CanvasRuntimeConfig(),
    commitEffectObserver: effectBatches.add,
  );
}
