import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine/src/contracts/internal/commit_action_intent.dart';
import 'package:iwb_canvas_engine/src/contracts/internal/commit_delivery.dart';
import 'package:iwb_canvas_engine/src/contracts/internal/selection_membership_port.dart';
import 'package:iwb_canvas_engine/src/edit/commit_applier.dart';
import 'package:iwb_canvas_engine/src/edit/commit_plan.dart';
import 'package:iwb_canvas_engine/src/runtime/runtime_root.dart';
import 'package:iwb_canvas_engine/src/selection/selection_kernel.dart';

void main() {
  test('selection replacement commits without document delta', () {
    expect(_verifySelectionReplacementCommit, returnsNormally);
  });

  test('selection no-op drops effects and action intents', () {
    expect(_verifySelectionNoOpDropsActionIntents, returnsNormally);
  });

  test('accepted delivery carries payload-aware action intents', () {
    expect(_verifyPayloadAwareActionIntents, returnsNormally);
  });

  test('document remove and clear prune selection atomically', () {
    expect(_verifyDocumentEditsPruneSelection, returnsNormally);
  });
}

void _verifySelectionReplacementCommit() {
  final selection = _selectionKernel()..setSelection([CanvasElementId('a')]);
  final events = <String>[];
  final plan = CommitPlan.replaceSelection(
    elementIds: [CanvasElementId('b'), CanvasElementId('c')],
    actionIntents: [
      SelectMarqueeActionIntent(
        previousSelection: [CanvasElementId('a')],
        nextSelection: [CanvasElementId('b'), CanvasElementId('c')],
        marqueeRectWorld: const Rect.fromLTRB(0, 0, 10, 10),
      ),
    ],
  );

  final result = _applyPlan(plan, selection, events);

  expect(plan.revisionDelta.hasChanges, isFalse);
  expect(events, ['selection']);
  _expectReplacementSelectionInstalled(selection);
  _expectReplacementDelivery(result);
}

void _expectReplacementSelectionInstalled(SelectionKernel selection) {
  expect(selection.selectionFacts.selectedElementIds, {
    CanvasElementId('b'),
    CanvasElementId('c'),
  });
  expect(selection.selectionFacts.selectionRevision, 2);
}

void _expectReplacementDelivery(CommitDeliveryResult result) {
  expect(result.shouldPublishState, isTrue);
  expect(result.effects.whereType<SelectionDeliveryEffect>(), hasLength(1));
  expect(result.effects.whereType<PublicStateDeliveryEffect>(), hasLength(1));
  final intent = result.actionIntents.single as SelectMarqueeActionIntent;
  expect(intent.kind, CommitActionIntentKind.selectMarquee);
  expect(intent.previousSelection, [CanvasElementId('a')]);
  expect(intent.nextSelection, [CanvasElementId('b'), CanvasElementId('c')]);
  expect(intent.elementIds, [CanvasElementId('b'), CanvasElementId('c')]);
  expect(intent.marqueeRectWorld, const Rect.fromLTRB(0, 0, 10, 10));
  expect(
    () => result.actionIntents.add(_clearIntent()),
    throwsUnsupportedError,
  );
}

void _verifySelectionNoOpDropsActionIntents() {
  final selection = _selectionKernel()..setSelection([CanvasElementId('a')]);
  final events = <String>[];
  final plan = CommitPlan.replaceSelection(
    elementIds: [CanvasElementId('a')],
    actionIntents: [
      SelectMarqueeActionIntent(
        previousSelection: [CanvasElementId('a')],
        nextSelection: [CanvasElementId('a')],
        marqueeRectWorld: const Rect.fromLTRB(0, 0, 10, 10),
      ),
    ],
  );

  final result = _applyPlan(plan, selection, events);

  expect(events, ['selection']);
  expect(selection.selectionFacts.selectionRevision, 1);
  expect(result.shouldPublishState, isFalse);
  expect(result.effects, isEmpty);
  expect(result.actionIntents, isEmpty);
}

void _verifyPayloadAwareActionIntents() {
  final selection = _selectionKernel();
  final result = _applyPlan(
    CommitPlan.replaceSelection(
      elementIds: [CanvasElementId('b')],
      actionIntents: _allPayloadAwareIntents(),
    ),
    selection,
    <String>[],
  );

  _expectMoveIntent(result.actionIntents[0]);
  _expectTransformIntent(result.actionIntents[1]);
  _expectDeleteIntent(result.actionIntents[2]);
  _expectRemoveIntent(result.actionIntents[3]);
  _expectClearIntent(result.actionIntents[4]);
}

List<CommitActionIntent> _allPayloadAwareIntents() {
  return [
    MoveSelectionActionIntent(
      elementIds: [CanvasElementId('a')],
      transform: CanvasTransform.translation(const Offset(2, 3)),
    ),
    TransformSelectionActionIntent(
      elementIds: [CanvasElementId('b')],
      transform: CanvasTransform.rotationDegrees(90),
      operation: CanvasTransformOperation.rotateClockwise,
      pivotWorld: const Offset(4, 5),
    ),
    DeleteSelectionActionIntent(
      removedElementIds: [CanvasElementId('a'), CanvasElementId('b')],
    ),
    RemoveElementActionIntent(elementId: CanvasElementId('c')),
    _clearIntent(),
  ];
}

void _expectMoveIntent(CommitActionIntent intent) {
  final move = intent as MoveSelectionActionIntent;
  expect(move.kind, CommitActionIntentKind.moveSelection);
  expect(move.elementIds, [CanvasElementId('a')]);
  expect(move.transform, CanvasTransform.translation(const Offset(2, 3)));
  expect(move.operation, CanvasTransformOperation.move);
  expect(move.pivotWorld, isNull);
  expect(
    () => move.elementIds.add(CanvasElementId('x')),
    throwsUnsupportedError,
  );
}

void _expectTransformIntent(CommitActionIntent intent) {
  final transform = intent as TransformSelectionActionIntent;
  expect(transform.kind, CommitActionIntentKind.transformSelection);
  expect(transform.elementIds, [CanvasElementId('b')]);
  expect(transform.transform, CanvasTransform.rotationDegrees(90));
  expect(transform.operation, CanvasTransformOperation.rotateClockwise);
  expect(transform.pivotWorld, const Offset(4, 5));
}

void _expectDeleteIntent(CommitActionIntent intent) {
  final delete = intent as DeleteSelectionActionIntent;
  expect(delete.kind, CommitActionIntentKind.deleteSelection);
  expect(delete.elementIds, [CanvasElementId('a'), CanvasElementId('b')]);
  expect(delete.removedElementIds, [
    CanvasElementId('a'),
    CanvasElementId('b'),
  ]);
}

void _expectRemoveIntent(CommitActionIntent intent) {
  final remove = intent as RemoveElementActionIntent;
  expect(remove.kind, CommitActionIntentKind.removeElement);
  expect(remove.elementIds, [CanvasElementId('c')]);
  expect(remove.removedElementIds, [CanvasElementId('c')]);
}

void _expectClearIntent(CommitActionIntent intent) {
  final clear = intent as ClearContentActionIntent;
  expect(clear.kind, CommitActionIntentKind.clearContent);
  expect(clear.elementIds, [CanvasElementId('a'), CanvasElementId('b')]);
  expect(clear.removedElementIds, [CanvasElementId('a'), CanvasElementId('b')]);
  expect(clear.removedResourceIds, [CanvasResourceId('r1')]);
}

ClearContentActionIntent _clearIntent() {
  return ClearContentActionIntent(
    removedElementIds: [CanvasElementId('a'), CanvasElementId('b')],
    removedResourceIds: [CanvasResourceId('r1')],
  );
}

void _verifyDocumentEditsPruneSelection() {
  _verifyRemovePrunesSelection();
  _verifyClearPrunesSelection();
}

void _verifyRemovePrunesSelection() {
  final root = _runtimeRoot();
  root.selection.setSelection([CanvasElementId('a'), CanvasElementId('b')]);
  final before = root.state.value;

  root.edits.edit((edit) {
    expect(edit.removeElement(CanvasElementId('a')), isTrue);
  });

  expect(root.selectedElementIds, {CanvasElementId('b')});
  expect(root.state.value.revisions.document, before.revisions.document + 1);
  expect(root.state.value.revisions.selection, before.revisions.selection + 1);
}

void _verifyClearPrunesSelection() {
  final root = _runtimeRoot();
  root.selection.setSelection([CanvasElementId('a'), CanvasElementId('b')]);
  final before = root.state.value;

  root.edits.edit((edit) {
    final result = edit.clearContent(removeUnusedResources: true);
    expect(result.didClearContent, isTrue);
  });

  expect(root.selectedElementIds, isEmpty);
  expect(root.state.value.revisions.document, before.revisions.document + 1);
  expect(root.state.value.revisions.selection, before.revisions.selection + 1);
}

CommitDeliveryResult _applyPlan(
  CommitPlan plan,
  SelectionKernel selection,
  List<String> events,
) {
  return const CommitApplier().apply(
    document: CanvasDocument(),
    plan: plan,
    documentInstallers: CommitDocumentInstallers(
      installDocument: (_, _) => events.add('document'),
      replaceDocument: (_, _) => events.add('replacement'),
    ),
    installSelectionEffects: (effect) {
      events.add('selection');

      return switch (effect) {
        PruneSelectionEffect() => selection.pruneSelection(),
        ReplaceSelectionEffect(:final elementIds) => selection.setSelection(
          elementIds,
        ),
      };
    },
  );
}

RuntimeRoot _runtimeRoot() {
  return RuntimeRoot(
    initialDocument: _document(),
    config: const CanvasRuntimeConfig(),
  );
}

SelectionKernel _selectionKernel() {
  return SelectionKernel(membership: const _SelectionMembership());
}

CanvasDocument _document() {
  return CanvasDocument(
    layers: [
      CanvasLayer(
        id: CanvasLayerId('layer-1'),
        elements: [
          CanvasRectElement(id: CanvasElementId('a'), size: const Size(1, 1)),
          CanvasRectElement(id: CanvasElementId('b'), size: const Size(1, 1)),
        ],
      ),
    ],
  );
}

final class _SelectionMembership implements SelectionMembershipPort {
  const _SelectionMembership();

  @override
  Set<CanvasElementId> normalizeSelection(Iterable<CanvasElementId> ids) {
    return Set.unmodifiable(ids);
  }

  @override
  Set<CanvasElementId> selectAllElementIds({required bool onlySelectable}) {
    return {CanvasElementId('a'), CanvasElementId('b'), CanvasElementId('c')};
  }
}
