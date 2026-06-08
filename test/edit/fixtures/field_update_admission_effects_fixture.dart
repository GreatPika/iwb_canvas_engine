import 'dart:ui';
import "../../support/runtime_root_with_committed_document_seed.dart";

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine/src/contracts/internal/commit_delivery.dart';
import 'package:iwb_canvas_engine/src/edit/draft_document.dart';
import 'package:iwb_canvas_engine/src/runtime/runtime_root.dart';

void main() {
  test('field update admission and effects allow nullable clears', () {
    expect(_expectNullableClearUpdatesField, returnsNormally);
  });

  test('field update admission rejects dynamic non-nullable clears', () {
    expect(_expectDynamicNonNullableClearRejected, returnsNormally);
  });

  test('field update admission rejects non-invertible transforms', () {
    expect(_expectNonInvertibleTransformRejected, returnsNormally);
  });

  test('field update admission rejects mismatched update kinds', () {
    expect(_expectMismatchedUpdateKindRejected, returnsNormally);
  });

  test('field update effects advance geometry revisions', () {
    expect(_expectGeometryUpdateAdvancesBoundsRevision, returnsNormally);
  });

  test('field update effects request selection pruning', () {
    expect(_expectVisibilityUpdateTouchesSelection, returnsNormally);
  });
}

void _expectNullableClearUpdatesField() {
  final root = runtimeRootWithCommittedDocumentSeed(
    _document(),
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
  final effectBatches = <List<CommitDeliveryEffect>>[];
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
  final effectBatches = <List<CommitDeliveryEffect>>[];
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
  final effectBatches = <List<CommitDeliveryEffect>>[];
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
  final root = runtimeRootWithCommittedDocumentSeed(
    _document(),
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

RuntimeRoot _runtimeRoot(List<List<CommitDeliveryEffect>> effectBatches) {
  return runtimeRootWithCommittedDocumentSeed(
    _document(),
    config: const CanvasRuntimeConfig(),
    commitEffectObserver: effectBatches.add,
  );
}
