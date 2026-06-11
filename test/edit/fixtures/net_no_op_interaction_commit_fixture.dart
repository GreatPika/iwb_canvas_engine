import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine/src/contracts/internal/prepared_selection_effect.dart';
import 'package:iwb_canvas_engine/src/contracts/internal/resolver_mutation_guard.dart';
import 'package:iwb_canvas_engine/src/edit/commit_applier.dart';
import 'package:iwb_canvas_engine/src/edit/edit_kernel.dart';
import 'package:iwb_canvas_engine/src/edit/edit_session.dart';
import 'package:iwb_canvas_engine/src/store/document_store_kernel.dart';

import '../../support/document_store_with_document.dart';

void main() {
  test(
    'interaction compensation skips augmentPlan and installs nothing',
    () => expect(_interactionCompensationSkipsAugmentPlan, returnsNormally),
  );
}

void _interactionCompensationSkipsAugmentPlan() {
  final store = documentStoreWithDocument(_baseDocument());
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
  expect(store.documentRevision, 0);
  expect(store.projectionBuildCount, 0);
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
