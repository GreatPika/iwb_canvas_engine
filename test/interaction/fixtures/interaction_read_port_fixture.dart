import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine/src/interaction/interaction_read_port.dart';
import 'package:iwb_canvas_engine/src/runtime/runtime_root.dart';

void main() {
  _testRuntimeInjectsReadPortIntoInteractionEngine();
  _testSelectedMoveStartFacts();
  _testSelectedMoveCommitFiltersStaleFacts();
  _testSelectedMoveCommitRejectsMismatchedSelectionFacts();
  _testMarqueeStartFacts();
  _testMarqueeCommitFacts();
  _testMarqueeQueryBudgetFacts();
}

void _testRuntimeInjectsReadPortIntoInteractionEngine() {
  test('runtime injects the read port into the interaction engine', () {
    final root = _runtimeRoot();
    addTearDown(root.dispose);

    expect(root.interactionEngine.readPort, same(root.interactionReadPort));
  });
}

void _testSelectedMoveStartFacts() {
  test('selected move start facts are immutable and document ordered', () {
    final root = _runtimeRoot()
      ..selection.setSelection([
        CanvasElementId('static-a'),
        CanvasElementId('locked-a'),
        CanvasElementId('movable-a'),
      ]);
    addTearDown(root.dispose);

    final facts = root.interactionReadPort.selectedMoveStartFacts(
      const SelectedMoveStartReadRequest(worldPosition: Offset(5, 5)),
    );

    expect(facts.selectedIds, [
      CanvasElementId('movable-a'),
      CanvasElementId('locked-a'),
      CanvasElementId('static-a'),
    ]);
    expect(facts.movableSelectedIds, [CanvasElementId('movable-a')]);
    expect(facts.controllerEpoch, 0);
    expect(facts.hitSelectedMovable, isTrue);
    expect(facts.query.status, InteractionReadQueryStatus.candidates);
    expect(
      () => facts.selectedIds.add(CanvasElementId('x')),
      throwsUnsupportedError,
    );
  });
}

void _testSelectedMoveCommitFiltersStaleFacts() {
  test('selected move commit filters stale and non-movable session ids', () {
    final root = _runtimeRoot()
      ..selection.setSelection([
        CanvasElementId('movable-a'),
        CanvasElementId('locked-a'),
      ]);
    addTearDown(root.dispose);
    final capturedRevision = root.selectionFacts.selectionRevision;

    root.edits.edit((edit) {
      expect(edit.removeElement(CanvasElementId('movable-a')), isTrue);
    });
    final facts = root.interactionReadPort.selectedMoveCommitFacts(
      SelectedMoveCommitReadRequest(
        sessionSelectedIds: [CanvasElementId('movable-a')],
        sessionMovableIds: [
          CanvasElementId('movable-a'),
          CanvasElementId('locked-a'),
        ],
        selectionRevision: capturedRevision,
      ),
    );

    expect(facts.movableIds, isEmpty);
    expect(facts.skippedSessionIds, [
      CanvasElementId('movable-a'),
      CanvasElementId('locked-a'),
    ]);
    expect(facts.controllerEpoch, 0);
    expect(facts.hasDocumentChangesAvailable, isFalse);
    expect(facts.selectionRevision, greaterThan(capturedRevision));
  });
}

void _testSelectedMoveCommitRejectsMismatchedSelectionFacts() {
  test('selected move commit rejects ids outside the captured selection', () {
    final root = _runtimeRoot()
      ..selection.setSelection([
        CanvasElementId('movable-a'),
        CanvasElementId('locked-a'),
      ]);
    addTearDown(root.dispose);
    final capturedRevision = root.selectionFacts.selectionRevision;

    final facts = root.interactionReadPort.selectedMoveCommitFacts(
      SelectedMoveCommitReadRequest(
        sessionSelectedIds: [CanvasElementId('locked-a')],
        sessionMovableIds: [
          CanvasElementId('movable-a'),
          CanvasElementId('locked-a'),
        ],
        selectionRevision: capturedRevision,
      ),
    );

    expect(facts.movableIds, isEmpty);
    expect(facts.skippedSessionIds, [
      CanvasElementId('movable-a'),
      CanvasElementId('locked-a'),
    ]);
    expect(facts.hasDocumentChangesAvailable, isFalse);
  });
}

void _testMarqueeStartFacts() {
  test('marquee start facts preserve previous selection in document order', () {
    final root = _runtimeRoot()
      ..selection.setSelection([CanvasElementId('static-a')]);
    addTearDown(root.dispose);

    final facts = root.interactionReadPort.marqueeStartFacts(
      const MarqueeStartReadRequest(),
    );

    expect(facts.previousSelectedIds, [CanvasElementId('static-a')]);
    expect(facts.controllerEpoch, 0);
    expect(
      () => facts.previousSelectedIds.add(CanvasElementId('x')),
      throwsUnsupportedError,
    );
  });
}

void _testMarqueeCommitFacts() {
  test(
    'marquee commit facts normalize rects and include locked selectable ids',
    () {
      final root = _runtimeRoot()
        ..selection.setSelection([CanvasElementId('static-a')]);
      addTearDown(root.dispose);

      final commit = root.interactionReadPort.marqueeCommitFacts(
        const MarqueeCommitReadRequest(
          rectWorld: Rect.fromLTRB(34, 15, -5, -5),
        ),
      );

      expect(commit.previousSelectedIds, [CanvasElementId('static-a')]);
      expect(commit.nextSelectedIds, [
        CanvasElementId('movable-a'),
        CanvasElementId('locked-a'),
      ]);
      expect(commit.rectWorld, const Rect.fromLTRB(-5, -5, 34, 15));
      expect(commit.controllerEpoch, 0);
      expect(() => commit.nextSelectedIds.clear(), throwsUnsupportedError);
    },
  );
}

void _testMarqueeQueryBudgetFacts() {
  test(
    'marquee read exposes query budget facts without mutable candidates',
    () {
      final root = _runtimeRoot();
      addTearDown(root.dispose);
      root.edits.loadDocument(_document());

      final facts = root.interactionReadPort.marqueeCommitFacts(
        const MarqueeCommitReadRequest(
          rectWorld: Rect.fromLTRB(0, 0, 10000000000, 10000000000),
        ),
      );

      expect(facts.nextSelectedIds, isEmpty);
      expect(facts.controllerEpoch, 1);
      expect(facts.query.status, InteractionReadQueryStatus.budgetExceeded);
      expect(
        facts.query.budgetExceededReason,
        InteractionReadBudgetExceededReason.queryTileBudgetExceeded,
      );
    },
  );
}

RuntimeRoot _runtimeRoot() {
  return RuntimeRoot(
    initialDocument: _document(),
    config: const CanvasRuntimeConfig(),
  );
}

CanvasDocument _document() {
  return CanvasDocument(
    backgroundElements: [
      CanvasRectElement(
        id: CanvasElementId('background-a'),
        size: const Size(10, 10),
      ),
    ],
    layers: [
      CanvasLayer(
        id: CanvasLayerId('layer-a'),
        elements: [
          _rect('movable-a', const Offset(0, 0)),
          _lockedRect('locked-a', const Offset(20, 0)),
          _staticRect('static-a', const Offset(40, 0)),
          _nonselectableRect('nonselectable-a', const Offset(0, 20)),
          _hiddenRect('hidden-a', const Offset(20, 20)),
        ],
      ),
    ],
  );
}

CanvasRectElement _rect(String id, Offset offset) {
  return CanvasRectElement(
    id: CanvasElementId(id),
    size: const Size(10, 10),
    transform: CanvasTransform.translation(offset),
  );
}

CanvasRectElement _lockedRect(String id, Offset offset) {
  return CanvasRectElement(
    id: CanvasElementId(id),
    size: const Size(10, 10),
    transform: CanvasTransform.translation(offset),
    isLocked: true,
  );
}

CanvasRectElement _staticRect(String id, Offset offset) {
  return CanvasRectElement(
    id: CanvasElementId(id),
    size: const Size(10, 10),
    transform: CanvasTransform.translation(offset),
    isTransformable: false,
  );
}

CanvasRectElement _nonselectableRect(String id, Offset offset) {
  return CanvasRectElement(
    id: CanvasElementId(id),
    size: const Size(10, 10),
    transform: CanvasTransform.translation(offset),
    isSelectable: false,
  );
}

CanvasRectElement _hiddenRect(String id, Offset offset) {
  return CanvasRectElement(
    id: CanvasElementId(id),
    size: const Size(10, 10),
    transform: CanvasTransform.translation(offset),
    isVisible: false,
  );
}
