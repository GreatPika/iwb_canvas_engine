import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine/src/contracts/internal/prepared_selection_effect.dart';
import 'package:iwb_canvas_engine/src/edit/commit_applier.dart';
import 'package:iwb_canvas_engine/src/edit/edit_kernel.dart';
import 'package:iwb_canvas_engine/src/store/document_store_kernel.dart';

import 'edit_kernel_test_support.dart';

CanvasDocument interactionCommitBaseDocument({
  List<String> backgroundElementIds = const [],
}) {
  return CanvasDocument(
    backgroundElements: [
      for (final id in backgroundElementIds)
        CanvasRectElement(id: CanvasElementId(id), size: const Size(1, 1)),
    ],
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

// The fixture intentionally composes the real Edit/Store/Selection owners.
// Keeping its one scenario object intact is clearer than metric-only adapters.
// ignore: coupling-between-object-classes
final class InteractionCommitScenario {
  InteractionCommitScenario(
    this.store, {
    Set<CanvasElementId> selectedElementIds = const {},
  }) : selectedElementIds = Set.unmodifiable(selectedElementIds) {
    kernel = EditKernel(
      mutationGuard: AllowMutationGuard(),
      readDocument: store.readDocument,
      readSparseFacts: () => StoreSparseFactsForTest(store),
      selectedElementIds: () => this.selectedElementIds,
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
  final Set<CanvasElementId> selectedElementIds;
  late final EditKernel kernel;
  int installCount = 0;
  int deliverCount = 0;
  int loadCount = 0;
  int prepareSelectionCount = 0;
  int sparseInstallCount = 0;
  int preparedMaterializedInstallCount = 0;

  CommitInstaller get _installCommit {
    return (document, plan) {
      installCount += 1;

      return const CommitApplier().apply(
        document: document,
        plan: plan,
        documentInstallers: CommitDocumentInstallers(
          prepareDocumentInstall: (document, {required documentReplaced}) {
            return switch (document) {
              PreparedMaterializedDocument(
                :final document,
                :final revisionDelta,
              ) =>
                (documentReplaced
                        ? store.prepareReplacementDocumentInstall(
                            document,
                            revisionDelta,
                          )
                        : store.prepareDocumentInstall(document, revisionDelta))
                    .consume,
              PreparedSparseStoreDocument(:final commit) => () {
                sparseInstallCount += 1;
                store.prepareSparseInstall(commit).consume();
              },
              PreparedMaterializedStoreDocument(:final commit) => () {
                preparedMaterializedInstallCount += 1;
                store.preparePreparedMaterializedInstall(commit).consume();
              },
              PreparedUnchangedStoreDocument() => () => 0,
            };
          },
        ),
        selectionInstallers: CommitSelectionInstallers(
          prepareSelectionEffect: (_, _) {
            prepareSelectionCount += 1;

            return PreparedSelectionEffect(const []);
          },
          installSelectionEffect: (_) => false,
        ),
      );
    };
  }
}

final class InteractionCommitSnapshot {
  const InteractionCommitSnapshot({
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

  factory InteractionCommitSnapshot.capture(
    DocumentStoreKernel store,
    InteractionCommitScenario scenario,
  ) {
    return InteractionCommitSnapshot(
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
    InteractionCommitScenario scenario,
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
