import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine/src/contracts/internal/commit_delivery.dart';
import 'package:iwb_canvas_engine/src/geometry/spatial_query_policy.dart';
import 'package:iwb_canvas_engine/src/geometry/spatial_query_result.dart';
import 'package:iwb_canvas_engine/src/runtime/runtime_root.dart';

import '../../support/runtime_root_with_committed_document_seed.dart';

void main() {
  test(
    'caught grid rejection commits earlier mixed partial updates',
    () => expectLater(
      _expectCaughtGridRejectionCommitsEarlierMixedUpdates(),
      completes,
    ),
  );

  test(
    'escaping grid validation rolls back mixed partial updates',
    () => expectLater(
      _expectEscapingGridValidationRollsBackMixedUpdates(),
      completes,
    ),
  );

  test(
    'escaping callback rolls back mixed partial updates',
    () =>
        expectLater(_expectEscapingCallbackRollsBackMixedUpdates(), completes),
  );
}

// This public transaction trace keeps the caught rejection and its final
// delivery together, so neither the earlier work nor commit observables become
// a proxy for the other.
Future<void> _expectCaughtGridRejectionCommitsEarlierMixedUpdates() async {
  final control = await _openCommittedMixedControl();
  try {
    final probe = await _AtomicityProbe.open();
    try {
      final before = probe.toSnapshot();

      probe.root.edits.edit((edit) {
        _applyValidMixedUpdates(edit);
        expect(
          () => edit.updateGrid(CanvasGridUpdate(cellSize: 0)),
          throwsA(
            isA<CanvasDataException>()
                .having(
                  (error) => error.code,
                  'code',
                  CanvasDataErrorCode.fieldMustBePositive,
                )
                .having((error) => error.path, 'path', 'grid.cellSize'),
          ),
        );
      });
      await probe.flush();

      _expectMixedUpdatesCommitted(probe.root, before);
      probe.expectAcceptedMixedDeliveryParity(control);
    } finally {
      await probe.close();
    }
  } finally {
    await control.close();
  }
}

Future<_AtomicityProbe> _openCommittedMixedControl() async {
  final control = await _AtomicityProbe.open();
  try {
    control.root.edits.edit(_applyValidMixedUpdates);
    await control.flush();
    return control;
  } catch (_) {
    await control.close();
    rethrow;
  }
}

Future<void> _expectEscapingGridValidationRollsBackMixedUpdates() async {
  final probe = await _AtomicityProbe.open();
  final before = probe.toSnapshot();

  expect(
    () => probe.root.edits.edit((edit) {
      _applyValidMixedUpdates(edit);
      edit.updateGrid(CanvasGridUpdate(cellSize: 0));
    }),
    throwsA(
      isA<CanvasDataException>()
          .having(
            (error) => error.code,
            'code',
            CanvasDataErrorCode.fieldMustBePositive,
          )
          .having((error) => error.path, 'path', 'grid.cellSize'),
    ),
  );
  await probe.flush();

  before.expectUnchanged(probe);
  await probe.close();
}

Future<void> _expectEscapingCallbackRollsBackMixedUpdates() async {
  final probe = await _AtomicityProbe.open();
  final before = probe.toSnapshot();

  expect(
    () => probe.root.edits.edit((edit) {
      _applyValidMixedUpdates(edit);
      throw StateError('rollback mixed partial updates');
    }),
    throwsStateError,
  );
  await probe.flush();

  before.expectUnchanged(probe);
  await probe.close();
}

void _applyValidMixedUpdates(CanvasEdit edit) {
  edit.updatePalette(CanvasPaletteUpdate(penColors: const [Color(0xFF010203)]));
  edit.updateGrid(CanvasGridUpdate(enabled: true, cellSize: 24));
}

// The appearance and revision assertions form one public commit result; keeping
// them adjacent prevents either partial-update family becoming a proxy for it.
// ignore: halstead-volume, source-lines-of-code
void _expectMixedUpdatesCommitted(RuntimeRoot root, _AtomicSnapshot before) {
  final appearance = root.readAppearance();
  final revisions = root.state.value.revisions;
  final beforeRevisions = before.publicState.revisions;
  expect(appearance.backgroundColor, const Color(0xFF111213));
  expect(appearance.palette.penColors, const [Color(0xFF010203)]);
  expect(appearance.palette.backgroundColors, const [Color(0xFF202020)]);
  expect(appearance.palette.gridSizes, const [8]);
  expect(
    appearance.grid,
    CanvasGrid(enabled: true, cellSize: 24, color: const Color(0xFF303030)),
  );
  expect(
    root.documentFacts.documentRevision,
    before.documentFacts.documentRevision + 1,
  );
  expect(
    root.frameRevisions.documentRevision,
    before.frameFacts.documentRevision + 1,
  );
  expect(
    root.frameRevisions.backgroundRevision,
    before.frameFacts.backgroundRevision,
  );
  expect(root.frameRevisions.gridRevision, before.frameFacts.gridRevision + 1);
  expect(
    root.frameRevisions.structuralRevision,
    before.frameFacts.structuralRevision,
  );
  expect(root.frameRevisions.boundsRevision, before.frameFacts.boundsRevision);
  expect(
    root.frameRevisions.elementVisualRevision,
    before.frameFacts.elementVisualRevision,
  );
  expect(
    root.frameRevisions.resourceRevision,
    before.frameFacts.resourceRevision,
  );
  expect(root.documentFacts.elementCount, before.documentFacts.elementCount);
  expect(root.documentFacts.layerCount, before.documentFacts.layerCount);
  expect(root.documentFacts.resourceCount, before.documentFacts.resourceCount);
  expect(
    root.documentFacts.contentElementIds,
    before.documentFacts.contentElementIds,
  );
  expect(
    root.documentFacts.selectableElementIds,
    before.documentFacts.selectableElementIds,
  );
  expect(root.selectedElementIds, before.selectedElementIds);
  expect(_spatialIds(root), before.spatialElementIds);
  expect(root.projectionBuildCount, before.projectionBuildCount);
  expect(root.state.value.summary, before.publicState.summary);
  expect(revisions.document, beforeRevisions.document + 1);
  expect(revisions.selection, beforeRevisions.selection);
  expect(revisions.preview, beforeRevisions.preview);
  expect(revisions.viewCamera, beforeRevisions.viewCamera);
  expect(revisions.resourceVisual, beforeRevisions.resourceVisual);
  expect(revisions.interaction, beforeRevisions.interaction);
  expect(revisions.epoch, beforeRevisions.epoch);
}

CanvasDocument _baseDocument() {
  return CanvasDocument(
    palette: CanvasPalette(
      penColors: const [Color(0xFF101010)],
      backgroundColors: const [Color(0xFF202020)],
      gridSizes: const [8],
    ),
    background: CanvasBackground(
      color: const Color(0xFF111213),
      grid: CanvasGrid(
        enabled: false,
        cellSize: 10,
        color: const Color(0xFF303030),
      ),
    ),
    layers: [
      CanvasLayer(
        id: CanvasLayerId('layer-1'),
        elements: [
          CanvasRectElement(
            id: CanvasElementId('element-1'),
            size: const Size(1, 1),
          ),
        ],
      ),
    ],
  );
}

// This one probe intentionally observes all public delivery families from one
// callback; splitting it would disconnect atomicity from its visible effects.
// ignore: coupling-between-object-classes
final class _AtomicityProbe {
  _AtomicityProbe._({
    required this.root,
    required this.effectBatches,
    required this.actions,
    required this.contextActions,
    required this.closeSubscriptions,
  }) {
    root.state.addListener(_recordStatePublication);
  }

  static Future<_AtomicityProbe> open() async {
    final effectBatches = <List<CommitDeliveryEffect>>[];
    final root = runtimeRootWithCommittedDocumentSeed(
      _baseDocument(),
      commitEffectObserver: effectBatches.add,
    );
    final actions = <CanvasActionCommitted>[];
    final contextActions = <CanvasContextActionRequested>[];
    final actionSubscription = root.actions.listen(actions.add);
    final contextActionSubscription = root.contextActionRequests.listen(
      contextActions.add,
    );
    return _AtomicityProbe._(
      root: root,
      effectBatches: effectBatches,
      actions: actions,
      contextActions: contextActions,
      closeSubscriptions: () async {
        await actionSubscription.cancel();
        await contextActionSubscription.cancel();
      },
    );
  }

  final RuntimeRoot root;
  final List<List<CommitDeliveryEffect>> effectBatches;
  final List<CanvasActionCommitted> actions;
  final List<CanvasContextActionRequested> contextActions;
  final Future<void> Function() closeSubscriptions;
  int statePublicationCount = 0;

  _AtomicSnapshot toSnapshot() => _AtomicSnapshot.capture(this);

  Future<void> flush() => Future<void>.delayed(Duration.zero);

  void expectAcceptedMixedDeliveryParity(_AtomicityProbe control) {
    expect(statePublicationCount, 1);
    expect(control.statePublicationCount, 1);
    expect(actions, isEmpty);
    expect(control.actions, isEmpty);
    expect(contextActions, isEmpty);
    expect(control.contextActions, isEmpty);
    expect(effectBatches, hasLength(1));
    expect(control.effectBatches, hasLength(1));
    _expectSameDeliveryBatch(
      effectBatches.single,
      control.effectBatches.single,
    );
  }

  Future<void> close() async {
    root.state.removeListener(_recordStatePublication);
    await closeSubscriptions();
    root.dispose();
  }

  void _recordStatePublication() {
    statePublicationCount += 1;
  }
}

void _expectSameDeliveryBatch(
  List<CommitDeliveryEffect> actual,
  List<CommitDeliveryEffect> control,
) {
  expect(
    actual.map((effect) => effect.runtimeType),
    control.map((effect) => effect.runtimeType),
  );
  for (var index = 0; index < actual.length; index += 1) {
    final actualEffect = actual[index];
    final controlEffect = control[index];
    switch ((actualEffect, controlEffect)) {
      case (
        final RepaintDeliveryEffect actualRepaint,
        final RepaintDeliveryEffect controlRepaint,
      ):
        expect(actualRepaint.mainCanvas, controlRepaint.mainCanvas);
        expect(actualRepaint.overlayCanvas, controlRepaint.overlayCanvas);
      default:
        break;
    }
  }
}

final class _AtomicSnapshot {
  const _AtomicSnapshot({
    required this.document,
    required this.publicState,
    required this.documentFacts,
    required this.frameFacts,
    required this.selectedElementIds,
    required this.spatialElementIds,
    required this.projectionBuildCount,
    required this.effectBatchCount,
    required this.statePublicationCount,
    required this.actionCount,
    required this.contextActionCount,
  });

  factory _AtomicSnapshot.capture(_AtomicityProbe probe) {
    final root = probe.root;
    final documentFacts = root.documentFacts;
    final frameFacts = root.frameRevisions;
    return _AtomicSnapshot(
      document: root.readDocument(),
      publicState: root.state.value,
      documentFacts: (
        elementCount: documentFacts.elementCount,
        layerCount: documentFacts.layerCount,
        resourceCount: documentFacts.resourceCount,
        documentRevision: documentFacts.documentRevision,
        structuralRevision: documentFacts.structuralRevision,
        contentElementIds: Set.of(documentFacts.contentElementIds),
        selectableElementIds: Set.of(documentFacts.selectableElementIds),
      ),
      frameFacts: (
        documentRevision: frameFacts.documentRevision,
        structuralRevision: frameFacts.structuralRevision,
        boundsRevision: frameFacts.boundsRevision,
        elementVisualRevision: frameFacts.elementVisualRevision,
        backgroundRevision: frameFacts.backgroundRevision,
        gridRevision: frameFacts.gridRevision,
        resourceRevision: frameFacts.resourceRevision,
      ),
      selectedElementIds: Set.of(root.selectedElementIds),
      spatialElementIds: _spatialIds(root),
      projectionBuildCount: root.projectionBuildCount,
      effectBatchCount: probe.effectBatches.length,
      statePublicationCount: probe.statePublicationCount,
      actionCount: probe.actions.length,
      contextActionCount: probe.contextActions.length,
    );
  }

  final CanvasDocument document;
  final CanvasRuntimeState publicState;
  final _DocumentFactsSnapshot documentFacts;
  final _FrameFactsSnapshot frameFacts;
  final Set<CanvasElementId> selectedElementIds;
  final List<CanvasElementId> spatialElementIds;
  final int projectionBuildCount;
  final int effectBatchCount;
  final int statePublicationCount;
  final int actionCount;
  final int contextActionCount;

  void expectUnchanged(_AtomicityProbe probe) {
    final root = probe.root;
    expect(root.readDocument(), document);
    expect(root.state.value, publicState);
    _expectDocumentFacts(root, documentFacts);
    _expectNoInstallOrCompensation(root, documentFacts.documentRevision);
    _expectFrameFacts(root, frameFacts);
    expect(root.selectedElementIds, selectedElementIds);
    expect(_spatialIds(root), spatialElementIds);
    expect(root.projectionBuildCount, projectionBuildCount);
    expect(probe.effectBatches, hasLength(effectBatchCount));
    expect(probe.statePublicationCount, statePublicationCount);
    expect(probe.actions, hasLength(actionCount));
    expect(probe.contextActions, hasLength(contextActionCount));
  }
}

typedef _DocumentFactsSnapshot = ({
  int elementCount,
  int layerCount,
  int resourceCount,
  int documentRevision,
  int structuralRevision,
  Set<CanvasElementId> contentElementIds,
  Set<CanvasElementId> selectableElementIds,
});

typedef _FrameFactsSnapshot = ({
  int documentRevision,
  int structuralRevision,
  int boundsRevision,
  int elementVisualRevision,
  int backgroundRevision,
  int gridRevision,
  int resourceRevision,
});

void _expectDocumentFacts(RuntimeRoot root, _DocumentFactsSnapshot expected) {
  final actual = root.documentFacts;
  expect(actual.elementCount, expected.elementCount);
  expect(actual.layerCount, expected.layerCount);
  expect(actual.resourceCount, expected.resourceCount);
  expect(actual.structuralRevision, expected.structuralRevision);
  expect(actual.contentElementIds, expected.contentElementIds);
  expect(actual.selectableElementIds, expected.selectableElementIds);
}

// RuntimeRoot passes all ordinary edit installers into CommitApplier
// (`runtime_root.dart:_applyEditCommit`); their Store paths install only
// prepared/accepted documents whose changed plan has advanced this revision.
// Therefore exact equality excludes both an install and a later compensation.
void _expectNoInstallOrCompensation(RuntimeRoot root, int documentRevision) {
  expect(root.documentFacts.documentRevision, documentRevision);
}

void _expectFrameFacts(RuntimeRoot root, _FrameFactsSnapshot expected) {
  final actual = root.frameRevisions;
  expect(actual.documentRevision, expected.documentRevision);
  expect(actual.structuralRevision, expected.structuralRevision);
  expect(actual.boundsRevision, expected.boundsRevision);
  expect(actual.elementVisualRevision, expected.elementVisualRevision);
  expect(actual.backgroundRevision, expected.backgroundRevision);
  expect(actual.gridRevision, expected.gridRevision);
  expect(actual.resourceRevision, expected.resourceRevision);
}

List<CanvasElementId> _spatialIds(RuntimeRoot root) {
  final result = root.spatialKernel.queryHit(
    SpatialQueryWindow(
      boundsWorld: const Rect.fromLTRB(-20, -20, 20, 20),
      structuralRevision: root.frameRevisions.structuralRevision,
    ),
  );

  return switch (result) {
    SpatialCandidatesResult(:final orderedCandidates) =>
      orderedCandidates.map((handle) => handle.id).toList(),
    _ => fail('Expected SpatialCandidatesResult, got $result'),
  };
}
