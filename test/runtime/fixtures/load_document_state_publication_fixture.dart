import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine/src/edit/commit_plan.dart';
import 'package:iwb_canvas_engine/src/runtime/runtime_root.dart';

void main() {
  test('successful load publishes one post-install state and effects', () {
    expect(_expectSuccessfulLoadStatePublication, returnsNormally);
  });

  test('successful load records selection clear when already empty', () {
    expect(_expectSuccessfulLoadClearsEmptySelection, returnsNormally);
  });

  test('failed load publishes no state and leaves runtime facts unchanged', () {
    expect(_expectFailedLoadHasNoSideEffects, returnsNormally);
  });
}

void _expectSuccessfulLoadStatePublication() {
  final effectBatches = <List<CommitEffect>>[];
  final root = _runtimeRoot(effectBatches);
  root.selection.setSelection([CanvasElementId('old-element')]);
  final snapshots = <CanvasRuntimeState>[];
  root.state.addListener(() {
    snapshots.add(root.state.value);
  });

  root.edits.loadDocument(_replacementDocument());

  expect(snapshots, hasLength(1));
  _expectReplacementDocumentInstalled(root);
  _expectReplacementState(snapshots.single);
  _expectLoadEffects(effectBatches.single);
}

void _expectSuccessfulLoadClearsEmptySelection() {
  final effectBatches = <List<CommitEffect>>[];
  final root = _runtimeRoot(effectBatches);

  root.edits.loadDocument(_replacementDocument());

  expect(root.state.value.revisions.selection, 1);
  _expectLoadEffects(effectBatches.single);
}

void _expectFailedLoadHasNoSideEffects() {
  final effectBatches = <List<CommitEffect>>[];
  final root = _runtimeRoot(effectBatches);
  root.selection.setSelection([CanvasElementId('old-element')]);
  root.cameraPort().setOffset(const Offset(3, 4));
  final before = _RuntimeFactsSnapshot.capture(root);
  final snapshots = <CanvasRuntimeState>[];
  root.state.addListener(() {
    snapshots.add(root.state.value);
  });
  effectBatches.clear();

  _expectDuplicateElementLoadRejected(root);

  expect(snapshots, isEmpty);
  expect(effectBatches, isEmpty);
  before.expectStillCurrent(root);
  expect(root.cameraPort().offset, const Offset(3, 4));
  expect(root.generateElementId(), CanvasElementId('e0'));
}

void _expectDuplicateElementLoadRejected(RuntimeRoot root) {
  expect(
    () => root.edits.loadDocument(_documentWithDuplicateElements()),
    throwsA(
      isA<CanvasDataException>().having(
        (error) => error.code,
        'code',
        CanvasDataErrorCode.duplicateElementId,
      ),
    ),
  );
}

RuntimeRoot _runtimeRoot(List<List<CommitEffect>> effectBatches) {
  return RuntimeRoot(
    initialDocument: _initialDocument(),
    config: const CanvasRuntimeConfig(),
    commitEffectObserver: effectBatches.add,
  );
}

void _expectReplacementDocumentInstalled(RuntimeRoot root) {
  expect(root.readDocument().backgroundElements.single.id.value, 'new-bg');
  expect(root.readDocument().layers.single.elements.single.id.value, 'new-el');
  expect(root.readDocument().resources.single.id.value, 'new-resource');
  expect(root.selectedElementIds, isEmpty);
  expect(root.cameraPort().offset, const Offset(7, 9));
  expect(root.generateElementId(), CanvasElementId('e0'));
}

void _expectReplacementState(CanvasRuntimeState state) {
  expect(
    state.summary,
    const CanvasRuntimeSummary(
      elementCount: 2,
      layerCount: 1,
      resourceCount: 1,
      selectedCount: 0,
    ),
  );
  expect(state.revisions.document, 1);
  expect(state.revisions.selection, 2);
  expect(state.revisions.viewCamera, 1);
  expect(state.revisions.epoch, 1);
  expect(state.revisions.preview, 0);
}

void _expectLoadEffects(List<CommitEffect> effects) {
  expect(effects.whereType<ProjectionEffect>(), hasLength(1));
  expect(effects.whereType<SpatialEffect>(), hasLength(1));
  expect(effects.whereType<ResourceEffect>(), hasLength(1));
  final repaintEffect = effects.whereType<RepaintEffect>().single;
  expect(repaintEffect.mainCanvas, isTrue);
  expect(repaintEffect.overlayCanvas, isTrue);
  expect(effects.whereType<SelectionEffect>(), hasLength(1));
  expect(effects.whereType<PublicStateEffect>(), hasLength(1));
  expect(() => effects.add(const PublicStateEffect()), throwsUnsupportedError);
}

final class _RuntimeFactsSnapshot {
  const _RuntimeFactsSnapshot({
    required this.state,
    required this.document,
    required this.selection,
  });

  factory _RuntimeFactsSnapshot.capture(RuntimeRoot root) {
    return _RuntimeFactsSnapshot(
      state: root.state.value,
      document: root.readDocument(),
      selection: root.selectedElementIds,
    );
  }

  final CanvasRuntimeState state;
  final CanvasDocument document;
  final Set<CanvasElementId> selection;

  void expectStillCurrent(RuntimeRoot root) {
    expect(root.state.value, state);
    expect(root.readDocument(), same(document));
    expect(root.selectedElementIds, selection);
  }
}

CanvasDocument _initialDocument() {
  return CanvasDocument(
    backgroundElements: [
      CanvasRectElement(id: CanvasElementId('old-bg'), size: const Size(1, 1)),
    ],
    layers: [
      CanvasLayer(
        id: CanvasLayerId('old-layer'),
        elements: [
          CanvasRectElement(
            id: CanvasElementId('old-element'),
            size: const Size(1, 1),
          ),
        ],
      ),
    ],
  );
}

CanvasDocument _replacementDocument() {
  return CanvasDocument(
    camera: CanvasCamera(offset: const Offset(7, 9)),
    resources: [
      CanvasImageResource(
        id: CanvasResourceId('new-resource'),
        source: CanvasResourceSource.appKey('new-resource'),
      ),
    ],
    backgroundElements: [
      CanvasRectElement(id: CanvasElementId('new-bg'), size: const Size(1, 1)),
    ],
    layers: [
      CanvasLayer(
        id: CanvasLayerId('new-layer'),
        elements: [
          CanvasImageElement(
            id: CanvasElementId('new-el'),
            resourceId: CanvasResourceId('new-resource'),
            size: const Size(2, 2),
          ),
        ],
      ),
    ],
  );
}

CanvasDocument _documentWithDuplicateElements() {
  return CanvasDocument(
    backgroundElements: [
      CanvasRectElement(
        id: CanvasElementId('duplicate'),
        size: const Size(1, 1),
      ),
    ],
    layers: [
      CanvasLayer(
        id: CanvasLayerId('layer'),
        elements: [
          CanvasRectElement(
            id: CanvasElementId('duplicate'),
            size: const Size(1, 1),
          ),
        ],
      ),
    ],
  );
}
