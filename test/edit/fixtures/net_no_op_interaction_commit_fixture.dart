import 'dart:ui';

// This direct EditKernel fixture owns one interaction commit transaction with
// store, compiler, applier, and action-intent seams; splitting those imports
// would hide the temporal boundary the regression tests enforce.
// ignore_for_file: number-of-imports

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine/src/contracts/internal/commit_action_intent.dart';
import 'package:iwb_canvas_engine/src/contracts/internal/commit_delivery.dart';
import 'package:iwb_canvas_engine/src/contracts/internal/prepared_selection_effect.dart';
import 'package:iwb_canvas_engine/src/contracts/internal/resolver_mutation_guard.dart';
import 'package:iwb_canvas_engine/src/edit/commit_applier.dart';
import 'package:iwb_canvas_engine/src/edit/edit_kernel.dart';
import 'package:iwb_canvas_engine/src/edit/commit_plan.dart';
import 'package:iwb_canvas_engine/src/edit/edit_session.dart';
import 'package:iwb_canvas_engine/src/store/document_store_kernel.dart';

import '../../support/document_store_with_document.dart';

void main() {
  test(
    'interaction compensation skips augmentPlan and installs nothing',
    () => expect(_interactionCompensationSkipsAugmentPlan, returnsNormally),
  );
  test(
    'accepted interaction augments after store finalization',
    () => expect(_acceptedInteractionAugmentsFinalPlan, returnsNormally),
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

void _interactionCompensationSkipsAugmentPlan() {
  final store = documentStoreWithDocument(_baseDocument());
  final beforeDocumentRevision = store.documentRevision;
  final beforeProjectionBuilds = store.projectionBuildCount;
  final scenario = _InteractionCommitScenario(store);
  final result = scenario.kernel.prepareInteractionCommit(
    (edit) {
      edit.setBackgroundColor(const Color(0xFF112233));
      edit.setBackgroundColor(const Color(0xFFFFFFFF));
    },
    augmentPlan: (_) {
      throw StateError('Accepted net no-op interaction must not augment.');
    },
  );

  expect(result.shouldPublishState, isFalse);
  expect(result.effects, isEmpty);
  expect(result.actionIntents, isEmpty);
  expect(scenario.installCount, 0);
  expect(scenario.deliverCount, 0);
  expect(scenario.loadCount, 0);
  expect(store.documentRevision, beforeDocumentRevision);
  expect(store.projectionBuildCount, beforeProjectionBuilds);
}

void _acceptedInteractionAugmentsFinalPlan() {
  final store = documentStoreWithDocument(_baseDocument());
  final scenario = _InteractionCommitScenario(store);
  final before = _InteractionCommitSnapshot.capture(store, scenario);
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
  required _InteractionCommitSnapshot before,
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

void _expectInstalledWithoutDelivery(_InteractionCommitScenario scenario) {
  expect(scenario.installCount, 1);
  expect(scenario.deliverCount, 0);
  expect(scenario.loadCount, 0);
}

void _throwingInteractionAugmentationRollsBack() {
  final store = documentStoreWithDocument(_baseDocument());
  final scenario = _InteractionCommitScenario(store);
  final before = _InteractionCommitSnapshot.capture(store, scenario);

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
  final store = documentStoreWithDocument(_baseDocument());
  final scenario = _InteractionCommitScenario(store);
  final before = _InteractionCommitSnapshot.capture(store, scenario);

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

CanvasDocument _baseDocument() {
  return CanvasDocument(
    layers: [
      CanvasLayer(
        id: CanvasLayerId('layer-1'),
        elements: [
          CanvasRectElement(
            id: CanvasElementId('rect-1'),
            size: const Size(1, 1),
          ),
        ],
      ),
    ],
  );
}

final class _InteractionCommitScenario {
  _InteractionCommitScenario(this.store) {
    kernel = EditKernel(
      mutationGuard: _AllowMutationGuard(),
      readDocument: store.readDocument,
      readSparseFacts: () => _StoreSparseFactsForTest(store),
      selectedElementIds: () => <CanvasElementId>{},
      prepareSparseCommit: store.prepareSparseCommit,
      prepareMaterializedCommit: store.prepareMaterializedCommit,
      installCommit: _installCommit,
      deliverApplyResult: (_) {
        deliverCount += 1;
      },
      installLoadedDocument: (_) {
        loadCount += 1;
      },
    );
  }

  final DocumentStoreKernel store;
  late final EditKernel kernel;
  int installCount = 0;
  int deliverCount = 0;
  int loadCount = 0;

  CommitInstaller get _installCommit {
    return (document, plan) {
      installCount += 1;

      return const CommitApplier().apply(
        document: document,
        plan: plan,
        documentInstallers: CommitDocumentInstallers(
          installDocument: store.installDocument,
          replaceDocument: store.replaceDocument,
          installSparseCommit: store.installSparseCommit,
        ),
        selectionInstallers: CommitSelectionInstallers(
          prepareSelectionEffect: (_, _) => PreparedSelectionEffect(const []),
          installSelectionEffect: (_) => false,
        ),
      );
    };
  }
}

final class _InteractionCommitSnapshot {
  const _InteractionCommitSnapshot({
    required this.documentRevision,
    required this.structuralRevision,
    required this.boundsRevision,
    required this.elementVisualRevision,
    required this.backgroundRevision,
    required this.resourceRevision,
    required this.background,
    required this.camera,
    required this.palette,
    required this.projectionBuildCount,
    required this.installCount,
    required this.deliverCount,
    required this.loadCount,
  });

  factory _InteractionCommitSnapshot.capture(
    DocumentStoreKernel store,
    _InteractionCommitScenario scenario,
  ) {
    return _InteractionCommitSnapshot(
      documentRevision: store.documentRevision,
      structuralRevision: store.structuralRevision,
      boundsRevision: store.boundsRevision,
      elementVisualRevision: store.elementVisualRevision,
      backgroundRevision: store.backgroundRevision,
      resourceRevision: store.resourceRevision,
      background: store.background,
      camera: store.camera,
      palette: store.palette,
      projectionBuildCount: store.projectionBuildCount,
      installCount: scenario.installCount,
      deliverCount: scenario.deliverCount,
      loadCount: scenario.loadCount,
    );
  }

  final int documentRevision;
  final int structuralRevision;
  final int boundsRevision;
  final int elementVisualRevision;
  final int backgroundRevision;
  final int resourceRevision;
  final CanvasBackground background;
  final CanvasCamera camera;
  final CanvasPalette palette;
  final int projectionBuildCount;
  final int installCount;
  final int deliverCount;
  final int loadCount;

  void expectUnchanged(
    DocumentStoreKernel store,
    _InteractionCommitScenario scenario,
  ) {
    expect(store.documentRevision, documentRevision);
    expect(store.structuralRevision, structuralRevision);
    expect(store.boundsRevision, boundsRevision);
    expect(store.elementVisualRevision, elementVisualRevision);
    expect(store.backgroundRevision, backgroundRevision);
    expect(store.resourceRevision, resourceRevision);
    expect(store.background, background);
    expect(store.camera, camera);
    expect(store.palette, palette);
    expect(store.projectionBuildCount, projectionBuildCount);
    expect(scenario.installCount, installCount);
    expect(scenario.deliverCount, deliverCount);
    expect(scenario.loadCount, loadCount);
  }
}

final class _AllowMutationGuard implements ResolverMutationGuard {
  _AllowMutationGuard();

  bool isAllowed = true;

  @override
  void ensureRuntimeMutationAllowed() {
    if (!isAllowed) {
      throw StateError('Test mutation guard denied mutation.');
    }
  }

  @override
  T runResolverCallback<T>(T Function() callback) => callback();
}

// This test adapter mirrors the store sparse fact boundary so the direct
// interaction test does not build a public document projection.
// ignore: number-of-methods
final class _StoreSparseFactsForTest implements SparseEditSessionFacts {
  const _StoreSparseFactsForTest(this.store);

  final DocumentStoreKernel store;

  @override
  CanvasDocumentSummary get summary => store.documentSummary;

  @override
  CanvasBackground get background => store.background;

  @override
  CanvasCamera get camera => store.camera;

  @override
  CanvasPalette get palette => store.palette;

  @override
  bool hasLayer(CanvasLayerId id) => store.hasLayer(id);

  @override
  Iterable<CanvasElementId> get backgroundElementIds {
    return store.backgroundElementIds;
  }

  @override
  Iterable<CanvasElementId> get elementIds => store.elementIds;

  @override
  Iterable<CanvasLayerId> get layerIds => store.layerIds;

  @override
  Iterable<CanvasElementId> elementIdsInLayer(CanvasLayerId id) {
    return store.elementIdsInLayer(id);
  }

  @override
  Iterable<CanvasResourceId> get resourceIds => store.resourceIds;

  @override
  CanvasElement? elementById(CanvasElementId id) => store.elementById(id);

  @override
  CanvasResource? resourceById(CanvasResourceId id) => store.resourceById(id);

  @override
  bool isResourceReferenced(CanvasResourceId id) {
    return store.isResourceReferenced(id);
  }
}
