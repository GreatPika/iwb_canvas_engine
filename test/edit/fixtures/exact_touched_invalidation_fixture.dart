import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine/src/edit/draft_document.dart';

void main() {
  test('layer-only edits touch only layer facts', () {
    expect(_expectLayerOnlyTouch, returnsNormally);
  });

  test('element edits record exact element ids without global replacement', () {
    expect(_expectElementTouch, returnsNormally);
  });

  test('implicit layers and background elements record their owners', () {
    expect(_expectImplicitLayerAndBackgroundTouches, returnsNormally);
  });

  test('background layer removals and clears record their owner', () {
    expect(_expectBackgroundLayerRemovalTouches, returnsNormally);
  });

  test('document metadata edits record their own flags only', () {
    expect(_expectDocumentFlagTouches, returnsNormally);
  });

  test('selection touches require selected removed ids', () {
    expect(_expectSelectionTouchesRequireIntersection, returnsNormally);
  });
}

void _expectLayerOnlyTouch() {
  final draft = DraftDocument(_document());

  draft.ensureLayer(CanvasLayerId('layer-2'));

  expect(draft.touchedSet.layerIds, {CanvasLayerId('layer-2')});
  expect(draft.touchedSet.elementIds, isEmpty);
  expect(draft.touchedSet.documentReplaced, isFalse);
}

void _expectElementTouch() {
  final draft = DraftDocument(_document());

  draft.updateElement(
    CanvasRectElementUpdate(
      id: CanvasElementId('rect-1'),
      fillColor: const CanvasFieldSet(Color(0xFF0000FF)),
    ),
  );

  expect(draft.touchedSet.elementIds, {CanvasElementId('rect-1')});
  expect(draft.touchedSet.updatedElementIds, {CanvasElementId('rect-1')});
  expect(draft.touchedSet.visualElementIds, {CanvasElementId('rect-1')});
  expect(draft.touchedSet.geometryElementIds, isEmpty);
  expect(draft.touchedSet.transformedElementIds, isEmpty);
  expect(draft.touchedSet.layerIds, isEmpty);
  expect(draft.touchedSet.documentReplaced, isFalse);
}

void _expectImplicitLayerAndBackgroundTouches() {
  final contentDraft = DraftDocument(CanvasDocument());
  contentDraft.addElement(_rect('rect-1'));

  expect(contentDraft.touchedSet.layerIds, {CanvasLayerId('default-layer')});
  expect(contentDraft.touchedSet.addedElementIds, {CanvasElementId('rect-1')});
  expect(contentDraft.touchedSet.backgroundLayerChanged, isFalse);

  final backgroundDraft = DraftDocument(CanvasDocument());
  backgroundDraft.addBackgroundElement(_rect('background-1'));

  expect(backgroundDraft.touchedSet.backgroundLayerChanged, isTrue);
  expect(backgroundDraft.touchedSet.addedElementIds, {
    CanvasElementId('background-1'),
  });
}

void _expectBackgroundLayerRemovalTouches() {
  final removeDraft = DraftDocument(_documentWithBackgroundElement());

  removeDraft.removeElement(CanvasElementId('background-1'));

  expect(removeDraft.touchedSet.backgroundLayerChanged, isTrue);
  expect(removeDraft.touchedSet.removedElementIds, {
    CanvasElementId('background-1'),
  });

  final clearDraft = DraftDocument(_documentWithBackgroundElement());

  clearDraft.clearContent(removeUnusedResources: false);

  expect(clearDraft.touchedSet.backgroundLayerChanged, isTrue);
  expect(clearDraft.touchedSet.removedElementIds, {
    CanvasElementId('background-1'),
  });
}

void _expectDocumentFlagTouches() {
  final draft = DraftDocument(_document());

  draft.setBackgroundColor(const Color(0xFF00FF00));
  draft.setGrid(CanvasGrid(enabled: true, cellSize: 20));
  draft.setPalette(
    CanvasPalette(
      penColors: const [Color(0xFF000000)],
      backgroundColors: const [],
      gridSizes: const [20],
    ),
  );
  draft.setCameraOffset(const Offset(4, 8));

  expect(draft.touchedSet.background, isTrue);
  expect(draft.touchedSet.grid, isTrue);
  expect(draft.touchedSet.palette, isTrue);
  expect(draft.touchedSet.persistedCamera, isTrue);
  expect(draft.touchedSet.documentReplaced, isFalse);
}

void _expectSelectionTouchesRequireIntersection() {
  final unselectedRemove = DraftDocument(_document());
  unselectedRemove.removeElement(CanvasElementId('rect-1'));
  expect(unselectedRemove.touchedSet.selection, isFalse);

  final selectedRemove = DraftDocument(
    _document(),
    selectedElementIds: [CanvasElementId('rect-1')],
  );
  selectedRemove.removeElement(CanvasElementId('rect-1'));
  expect(selectedRemove.touchedSet.selection, isTrue);

  final unselectedClear = DraftDocument(_document());
  unselectedClear.clearContent(removeUnusedResources: false);
  expect(unselectedClear.touchedSet.selection, isFalse);
}

CanvasDocument _document() {
  return CanvasDocument(
    layers: [
      CanvasLayer(id: CanvasLayerId('layer-1'), elements: [_rect('rect-1')]),
    ],
  );
}

CanvasDocument _documentWithBackgroundElement() {
  return CanvasDocument(backgroundElements: [_rect('background-1')]);
}

CanvasRectElement _rect(String id) {
  return CanvasRectElement(id: CanvasElementId(id), size: const Size(1, 1));
}
