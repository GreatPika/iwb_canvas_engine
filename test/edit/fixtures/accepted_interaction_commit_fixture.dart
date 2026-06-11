import 'dart:ui';

// This direct EditKernel fixture owns one interaction commit transaction with
// store, compiler, applier, and action-intent seams; splitting those imports
// would hide the temporal boundary the regression tests enforce.
// ignore_for_file: number-of-imports

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine/src/contracts/internal/commit_action_intent.dart';
import 'package:iwb_canvas_engine/src/contracts/internal/commit_delivery.dart';
import 'package:iwb_canvas_engine/src/edit/commit_plan.dart';
import 'package:iwb_canvas_engine/src/store/document_store_kernel.dart';

import '../../support/document_store_with_document.dart';
import 'interaction_commit_scenario_support.dart';

void main() {
  test(
    'accepted interaction augments after store finalization',
    () => expect(_acceptedInteractionAugmentsFinalPlan, returnsNormally),
  );
  test(
    'append add interaction returns spatial element touch without layer rebuild',
    () => expect(_appendAddReturnsElementTouchOnly, returnsNormally),
  );
  test(
    'content removal interaction returns base layer spatial touch',
    () => expect(_contentRemovalReturnsSpatialLayerTouch, returnsNormally),
  );
  test(
    'background removal interaction returns spatial touch',
    () => expect(_backgroundRemovalReturnsSpatialTouch, returnsNormally),
  );
  test(
    'spatial-only update interaction returns geometry touch',
    () => expect(_spatialOnlyUpdateReturnsGeometryTouch, returnsNormally),
  );
  test(
    'transient selection prune does not deliver accepted selection effect',
    () => expect(
      _transientSelectionPruneDoesNotDeliverAcceptedSelectionEffect,
      returnsNormally,
    ),
  );
  test(
    'throwing interaction augmentation rolls back before install',
    () => expect(_throwingInteractionAugmentationRollsBack, returnsNormally),
  );
  test(
    'nested interaction augmentation rolls back before install',
    () => expect(_nestedInteractionAugmentationRollsBack, returnsNormally),
  );
}

void _acceptedInteractionAugmentsFinalPlan() {
  final store = documentStoreWithDocument(interactionCommitBaseDocument());
  final scenario = InteractionCommitScenario(store);
  final before = InteractionCommitSnapshot.capture(store, scenario);
  var augmentCallCount = 0;

  final result = scenario.kernel.prepareInteractionCommit(
    (edit) {
      edit.setCameraOffset(const Offset(9, 9));
      edit.setCameraOffset(Offset.zero);
      edit.setBackgroundColor(const Color(0xFF112233));
    },
    augmentPlan: (plan) {
      augmentCallCount += 1;
      _expectAcceptedBackgroundPlan(plan);

      return plan.withActionIntents([
        RemoveElementActionIntent(elementId: CanvasElementId('rect-1')),
      ]);
    },
  );

  _expectAugmentedBackgroundCommit(
    result: result,
    store: store,
    before: before,
    augmentCallCount: augmentCallCount,
  );
  _expectInstalledWithoutDelivery(scenario);
}

void _appendAddReturnsElementTouchOnly() {
  final store = documentStoreWithDocument(interactionCommitBaseDocument());
  final scenario = InteractionCommitScenario(store);

  final result = scenario.kernel.prepareInteractionCommit((edit) {
    edit.addElement(
      CanvasRectElement(
        id: CanvasElementId('implicit-layer-add'),
        size: const Size(2, 3),
      ),
    );
  });

  final spatial = result.effects.whereType<SpatialDeliveryEffect>().single;
  expect(spatial.touchedSet.addedElementIds, {
    CanvasElementId('implicit-layer-add'),
  });
  expect(spatial.touchedSet.layerIds, isEmpty);
  expect(scenario.installCount, 1);
  expect(store.projectionBuildCount, 0);
}

void _contentRemovalReturnsSpatialLayerTouch() {
  final store = documentStoreWithDocument(interactionCommitBaseDocument());
  final scenario = InteractionCommitScenario(store);

  final result = scenario.kernel.prepareInteractionCommit((edit) {
    edit.removeElement(CanvasElementId('rect-1'));
  });

  final spatial = result.effects.whereType<SpatialDeliveryEffect>().single;
  expect(spatial.touchedSet.removedElementIds, {CanvasElementId('rect-1')});
  expect(spatial.touchedSet.layerIds, {CanvasLayerId('layer-1')});
  expect(scenario.installCount, 1);
  expect(store.projectionBuildCount, 0);
}

void _backgroundRemovalReturnsSpatialTouch() {
  final store = documentStoreWithDocument(
    interactionCommitBaseDocument(backgroundElementIds: ['background-1']),
  );
  final scenario = InteractionCommitScenario(store);

  final result = scenario.kernel.prepareInteractionCommit((edit) {
    edit.removeElement(CanvasElementId('background-1'));
  });

  final spatial = result.effects.whereType<SpatialDeliveryEffect>().single;
  expect(spatial.touchedSet.removedElementIds, {
    CanvasElementId('background-1'),
  });
  expect(spatial.touchedSet.backgroundLayerChanged, isTrue);
  expect(scenario.installCount, 1);
  expect(store.projectionBuildCount, 0);
}

void _spatialOnlyUpdateReturnsGeometryTouch() {
  final store = documentStoreWithDocument(interactionCommitBaseDocument());
  final scenario = InteractionCommitScenario(store);

  final result = scenario.kernel.prepareInteractionCommit((edit) {
    edit.updateElement(
      CanvasRectElementUpdate(
        id: CanvasElementId('rect-1'),
        isSelectable: const CanvasFieldSet(false),
      ),
    );
  });

  final spatial = result.effects.whereType<SpatialDeliveryEffect>().single;
  expect(spatial.touchedSet.updatedElementIds, {CanvasElementId('rect-1')});
  expect(spatial.touchedSet.geometryElementIds, {CanvasElementId('rect-1')});
  expect(scenario.installCount, 1);
  expect(store.projectionBuildCount, 0);
}

void _transientSelectionPruneDoesNotDeliverAcceptedSelectionEffect() {
  final store = documentStoreWithDocument(interactionCommitBaseDocument());
  final scenario = InteractionCommitScenario(
    store,
    selectedElementIds: {CanvasElementId('rect-1')},
  );

  final result = scenario.kernel.prepareInteractionCommit((edit) {
    edit.updateElement(
      CanvasRectElementUpdate(
        id: CanvasElementId('rect-1'),
        isSelectable: const CanvasFieldSet(false),
      ),
    );
    edit.updateElement(
      CanvasRectElementUpdate(
        id: CanvasElementId('rect-1'),
        isSelectable: const CanvasFieldSet(true),
        opacity: const CanvasFieldSet(0.5),
      ),
    );
  });

  expect(result.effects.whereType<SelectionDeliveryEffect>(), isEmpty);
  expect(scenario.prepareSelectionCount, 0);
  expect(scenario.installCount, 1);
  final element = store.elementById(CanvasElementId('rect-1'));
  if (element is! CanvasRectElement) {
    throw StateError('Expected rect-1 to remain a committed rect.');
  }
  expect(element.isSelectable, isTrue);
  expect(element.opacity, 0.5);
}

void _expectAcceptedBackgroundPlan(CommitPlan plan) {
  expect(plan.hasChanges, isTrue);
  expect(plan.revisionDelta.document, isTrue);
  expect(plan.revisionDelta.projection, isTrue);
  expect(plan.revisionDelta.background, isTrue);
  expect(plan.revisionDelta.bounds, isFalse);
  expect(plan.revisionDelta.elementVisual, isFalse);
  expect(plan.touchedSet.persistedCamera, isFalse);
  expect(plan.touchedSet.background, isTrue);
}

void _expectAugmentedBackgroundCommit({
  required CommitDeliveryResult result,
  required DocumentStoreKernel store,
  required InteractionCommitSnapshot before,
  required int augmentCallCount,
}) {
  expect(augmentCallCount, 1);
  expect(result.shouldPublishState, isTrue);
  expect(result.effects, isNotEmpty);
  expect(result.actionIntents, hasLength(1));
  expect(
    result.actionIntents.single.kind,
    CommitActionIntentKind.removeElement,
  );
  expect(store.background.color, const Color(0xFF112233));
  expect(store.camera, before.camera);
  expect(store.documentRevision, before.documentRevision + 1);
  expect(store.projectionBuildCount, before.projectionBuildCount);
}

void _expectInstalledWithoutDelivery(InteractionCommitScenario scenario) {
  expect(scenario.installCount, 1);
  expect(scenario.deliverCount, 0);
  expect(scenario.loadCount, 0);
}

void _throwingInteractionAugmentationRollsBack() {
  final store = documentStoreWithDocument(interactionCommitBaseDocument());
  final scenario = InteractionCommitScenario(store);
  final before = InteractionCommitSnapshot.capture(store, scenario);

  expect(
    () => scenario.kernel.prepareInteractionCommit(
      (edit) {
        edit.setBackgroundColor(const Color(0xFF445566));
      },
      augmentPlan: (_) {
        throw StateError('augment failed');
      },
    ),
    throwsStateError,
  );

  before.expectUnchanged(store, scenario);
}

void _nestedInteractionAugmentationRollsBack() {
  final store = documentStoreWithDocument(interactionCommitBaseDocument());
  final scenario = InteractionCommitScenario(store);
  final before = InteractionCommitSnapshot.capture(store, scenario);

  expect(
    () => scenario.kernel.prepareInteractionCommit(
      (edit) {
        edit.setBackgroundColor(const Color(0xFF778899));
      },
      augmentPlan: (_) {
        scenario.kernel.prepareInteractionCommit((nested) {
          nested.setCameraOffset(const Offset(4, 5));
        });
        throw StateError('nested interaction unexpectedly returned');
      },
    ),
    throwsStateError,
  );

  before.expectUnchanged(store, scenario);
}
