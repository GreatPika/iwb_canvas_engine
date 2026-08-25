import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine/src/contracts/internal/deletion_entry_projection_port.dart';
import 'package:iwb_canvas_engine/src/contracts/internal/touched_set.dart';
import 'package:iwb_canvas_engine/src/geometry/spatial_query_policy.dart';
import 'package:iwb_canvas_engine/src/interaction/interaction_read_port.dart';
import 'package:iwb_canvas_engine/src/runtime/runtime_root.dart';

import '../../support/runtime_root_with_committed_document_seed.dart';
import 'interaction_read_port_bounded_read_fixture.dart';

void main() {
  _testRuntimeInjectsReadPortIntoInteractionEngine();
  _testSelectedMoveStartFacts();
  _testVectorSelectedMoveFacts();
  _testSelectedMoveStartGroupUnionFacts();
  _testSelectedMoveStartOccludedGroupUnionFacts();
  _testSelectedMoveStartNonSelectableOccludedGroupUnionFacts();
  _testSingleLineMoveStartDoesNotExposeGroupUnionFacts();
  testSelectedMoveStartUsesSelectedHandleLookups();
  _testSelectedMoveCommitFiltersStaleFacts();
  _testSelectedMoveCommitRejectsMismatchedSelectionFacts();
  _testMarqueeStartFacts();
  _testMarqueeCommitFacts();
  _testMarqueeQueryBudgetFacts();
  _testEraserReadFacts();
  _testEraserKindPolicyBeforeBudgets();
  _testContextTargetReadFacts();
  _testVectorContextTargetReadFacts();
  _testRejectedContextTargetReadOutcomes();
  _testTextCommitGuardFacts();
}

void _testRuntimeInjectsReadPortIntoInteractionEngine() {
  test('runtime injects the read port into the interaction engine', () {
    final root = _runtimeRoot();
    addTearDown(root.dispose);

    expect(root.interactionEngine.readPort, same(root.interactionReadPort));
  });
}

// This selected move-start matrix stays together to prove ordering,
// movability, exact-hit facts, and immutability from one committed read.
// ignore: halstead-volume
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
    expect(facts.topmostHitId, CanvasElementId('movable-a'));
    expect(facts.topmostHitOrderToken, isNotNull);
    expect(facts.query.status, InteractionReadQueryStatus.candidates);
    expect(
      () => facts.selectedIds.add(CanvasElementId('x')),
      throwsUnsupportedError,
    );
  });
}

// Start and terminal facts form one move transaction; keeping their assertions
// together makes a broken cross-phase vector admission immediately legible.
// ignore: halstead-volume
void _testVectorSelectedMoveFacts() {
  test('selected vector move keeps its hit and commit facts', () {
    final root = _runtimeRoot()
      ..selection.setSelection([CanvasElementId('vector-a')]);
    addTearDown(root.dispose);

    final start = root.interactionReadPort.selectedMoveStartFacts(
      const SelectedMoveStartReadRequest(worldPosition: Offset(65, 5)),
    );

    expect(start.selectedIds, [CanvasElementId('vector-a')]);
    expect(start.movableSelectedIds, [CanvasElementId('vector-a')]);
    expect(start.hitSelectedMovable, isTrue);
    expect(start.topmostMovableHitId, CanvasElementId('vector-a'));
    expect(start.topmostHitId, CanvasElementId('vector-a'));

    final commit = root.interactionReadPort.selectedMoveCommitFacts(
      SelectedMoveCommitReadRequest(
        sessionSelectedIds: start.selectedIds,
        sessionMovableIds: start.movableSelectedIds,
        selectionRevision: start.selectionRevision,
      ),
    );

    expect(commit.movableIds, [CanvasElementId('vector-a')]);
    expect(commit.movedElements, hasLength(1));
    expect(commit.selectionBoundsWorld, const Rect.fromLTRB(55, -5, 65, 5));
    expect(commit.hasDocumentChangesAvailable, isTrue);
    expect(commit.skippedSessionIds, isEmpty);
  });
}

// This group-start matrix stays together so union bounds, selected ordering,
// and gap admission cannot drift across separate fixture setups.
// ignore: halstead-volume
void _testSelectedMoveStartGroupUnionFacts() {
  test('selected move start facts expose selected group union facts', () {
    final root =
        runtimeRootWithCommittedDocumentSeed(
            _groupSelectionDocument(includeOccluder: false),
            config: const CanvasRuntimeConfig(
              deletionCommitResolver: _acceptDeletionCommit,
            ),
          )
          ..selection.setSelection([
            CanvasElementId('selected-left'),
            CanvasElementId('selected-right'),
          ]);
    addTearDown(root.dispose);

    final facts = root.interactionReadPort.selectedMoveStartFacts(
      const SelectedMoveStartReadRequest(worldPosition: Offset(15, 0)),
    );

    expect(facts.selectedIds, [
      CanvasElementId('selected-left'),
      CanvasElementId('selected-right'),
    ]);
    expect(facts.movableSelectedIds, [
      CanvasElementId('selected-left'),
      CanvasElementId('selected-right'),
    ]);
    expect(facts.hitSelectedMovable, isFalse);
    expect(facts.topmostHitId, isNull);
    expect(facts.selectedGroupBoundsWorld, const Rect.fromLTRB(-5, -5, 35, 5));
    expect(facts.selectedTopOrderToken, isNotNull);
    expect(facts.insideSelectedGroupUnion, isTrue);
    expect(facts.groupUnionOccludedByHigherOrderHit, isFalse);
  });
}

// Occlusion assertions stay together to prove exact top-hit order and selected
// group order are compared from one read-port snapshot.
// ignore: halstead-volume
void _testSelectedMoveStartOccludedGroupUnionFacts() {
  test(
    'selected group union facts report higher order exact-hit occlusion',
    () {
      final root =
          runtimeRootWithCommittedDocumentSeed(
              _groupSelectionDocument(includeOccluder: true),
              config: const CanvasRuntimeConfig(
                deletionCommitResolver: _acceptDeletionCommit,
              ),
            )
            ..selection.setSelection([
              CanvasElementId('selected-left'),
              CanvasElementId('selected-right'),
            ]);
      addTearDown(root.dispose);

      final facts = root.interactionReadPort.selectedMoveStartFacts(
        const SelectedMoveStartReadRequest(worldPosition: Offset(15, 0)),
      );

      expect(facts.hitSelectedMovable, isFalse);
      expect(facts.topmostHitId, CanvasElementId('occluder-a'));
      final selectedTopOrderToken = facts.selectedTopOrderToken;
      if (selectedTopOrderToken == null) {
        fail('selected top order token must be available for group selection');
      }
      expect(facts.topmostHitOrderToken, greaterThan(selectedTopOrderToken));
      expect(
        facts.selectedGroupBoundsWorld,
        const Rect.fromLTRB(-5, -5, 35, 5),
      );
      expect(facts.insideSelectedGroupUnion, isTrue);
      expect(facts.groupUnionOccludedByHigherOrderHit, isTrue);
    },
  );
}

void _testSelectedMoveStartNonSelectableOccludedGroupUnionFacts() {
  test(
    'selected group union facts use content hits for non-selectable occlusion',
    () {
      final root =
          runtimeRootWithCommittedDocumentSeed(
              _groupSelectionDocument(
                includeOccluder: true,
                occluderSelectable: false,
              ),
              config: const CanvasRuntimeConfig(
                deletionCommitResolver: _acceptDeletionCommit,
              ),
            )
            ..selection.setSelection([
              CanvasElementId('selected-left'),
              CanvasElementId('selected-right'),
            ]);
      addTearDown(root.dispose);

      final facts = root.interactionReadPort.selectedMoveStartFacts(
        const SelectedMoveStartReadRequest(worldPosition: Offset(15, 0)),
      );

      expect(facts.hitSelectedMovable, isFalse);
      expect(facts.topmostHitId, isNull);
      expect(facts.topmostHitOrderToken, isNull);
      expect(facts.insideSelectedGroupUnion, isTrue);
      expect(facts.groupUnionOcclusionReliable, isTrue);
      expect(facts.groupUnionOccludedByHigherOrderHit, isTrue);
    },
  );
}

void _testSingleLineMoveStartDoesNotExposeGroupUnionFacts() {
  test(
    'single selected line move start does not expose group-union admission',
    () {
      final root = runtimeRootWithCommittedDocumentSeed(
        _singleSelectedLineDocument(),
        config: const CanvasRuntimeConfig(
          deletionCommitResolver: _acceptDeletionCommit,
        ),
      )..selection.setSelection([CanvasElementId('line-a')]);
      addTearDown(root.dispose);

      final facts = root.interactionReadPort.selectedMoveStartFacts(
        const SelectedMoveStartReadRequest(worldPosition: Offset(80, 20)),
      );

      expect(facts.selectedIds, [CanvasElementId('line-a')]);
      expect(facts.movableSelectedIds, [CanvasElementId('line-a')]);
      expect(facts.hitSelectedMovable, isFalse);
      expect(facts.topmostHitId, isNull);
      expect(facts.selectedGroupBoundsWorld, isNull);
      expect(facts.selectedTopOrderToken, isNotNull);
      expect(facts.insideSelectedGroupUnion, isFalse);
      expect(facts.groupUnionOccludedByHigherOrderHit, isFalse);
    },
  );
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
      root.edits.loadDocumentFromJson(encodeCanvasDocumentToJson(_document()));

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

// This assertion matrix stays together to prove corridor immutability, exact ids,
// query facts, and budget status are from one eraser read snapshot.
// ignore: halstead-volume
void _testEraserReadFacts() {
  test('eraser read facts use immutable corridor and exact content ids', () {
    final root = _runtimeRoot();
    addTearDown(root.dispose);

    final corridor = [const Offset(1, 1), const Offset(9, 9)];
    final facts = root.interactionReadPort.eraserTerminalFacts(
      EraserReadRequest(corridorPoints: corridor, eraserThickness: 4),
    );
    corridor.clear();

    expect(facts.corridorPoints, [const Offset(1, 1), const Offset(9, 9)]);
    expect(facts.erasedElementIds, [CanvasElementId('movable-a')]);
    expect(facts.erasedEntries, hasLength(1));
    expect(facts.erasedEntries.single.id, CanvasElementId('movable-a'));
    expect(facts.erasedEntries.single.layerId, CanvasLayerId('layer-a'));
    expect(facts.erasedEntries.single.elementIndex, 0);
    expect(facts.erasedEntries.single.orderToken, 3);
    expect(facts.eraserThickness, 4);
    expect(facts.controllerEpoch, 0);
    expect(facts.documentRevision, 0);
    expect(facts.query.status, InteractionReadQueryStatus.candidates);
    expect(facts.exactCheckCount, greaterThanOrEqualTo(1));
    expect(facts.exactBudgetExceeded, isFalse);
    expect(root.projectionBuildCount, 0);

    final callerOwnedEntries = [...facts.erasedEntries];
    final callerProjection = DeletionEntryProjection(callerOwnedEntries);
    final copiedFacts = EraserReadFacts.terminal(
      corridorPoints: facts.corridorPoints,
      erasedEntryProjection: callerProjection,
      eraserThickness: facts.eraserThickness,
      controllerEpoch: facts.controllerEpoch,
      documentRevision: facts.documentRevision,
      exactCheckCount: facts.exactCheckCount,
      exactBudgetExceeded: facts.exactBudgetExceeded,
      query: facts.query,
    );
    callerOwnedEntries.clear();

    expect(copiedFacts.erasedEntries, hasLength(1));
    expect(() => facts.corridorPoints.clear(), throwsUnsupportedError);
    expect(() => facts.erasedElementIds.clear(), throwsUnsupportedError);
    expect(() => copiedFacts.erasedEntries.clear(), throwsUnsupportedError);
  });
}

// Preview near-limit and terminal parity share one real adapter setup, so this
// proof remains together instead of duplicating the mixed-kind fixture data.
// ignore: halstead-volume, source-lines-of-code
void _testEraserKindPolicyBeforeBudgets() {
  test(
    'eraser kind policy filters preview and terminal reads before budgets',
    () {
      final root = _eraserPolicyRoot(
        const CanvasRuntimeConfig(
          deletionCommitResolver: _acceptDeletionCommit,
          eraserElementKinds: {CanvasElementKind.rect},
        ),
        disallowedTextCount: 512,
      );
      addTearDown(root.dispose);

      final request = EraserReadRequest(
        corridorPoints: const [Offset(0, 0)],
        eraserThickness: 2,
      );
      final preview = root.interactionReadPort.eraserPreviewFacts(request);
      final terminal = root.interactionReadPort.eraserTerminalFacts(request);

      expect(preview.query.candidateCount, 1);
      expect(preview.exactCheckCount, 1);
      expect(preview.exactBudgetExceeded, isFalse);
      expect(preview.erasedElementIds, [CanvasElementId('allowed-rect')]);
      expect(terminal.query.candidateCount, 1);
      expect(terminal.exactCheckCount, 1);
      expect(terminal.exactBudgetExceeded, isFalse);
      expect(terminal.erasedElementIds, [CanvasElementId('allowed-rect')]);
    },
  );

  test('null preserves eraser admission and empty disables it', () {
    final unrestrictedRoot = _eraserPolicyRoot(
      const CanvasRuntimeConfig(deletionCommitResolver: _acceptDeletionCommit),
    );
    final disabledRoot = _eraserPolicyRoot(
      const CanvasRuntimeConfig(
        deletionCommitResolver: _acceptDeletionCommit,
        eraserElementKinds: {},
      ),
    );
    addTearDown(unrestrictedRoot.dispose);
    addTearDown(disabledRoot.dispose);

    final request = EraserReadRequest(
      corridorPoints: const [Offset(0, 0)],
      eraserThickness: 2,
    );
    final unrestricted = unrestrictedRoot.interactionReadPort
        .eraserTerminalFacts(request);
    final disabledPreview = disabledRoot.interactionReadPort.eraserPreviewFacts(
      request,
    );
    final disabledTerminal = disabledRoot.interactionReadPort
        .eraserTerminalFacts(request);

    expect(unrestricted.query.candidateCount, 2);
    expect(unrestricted.exactCheckCount, 2);
    expect(unrestricted.erasedElementIds, [
      CanvasElementId('disallowed-text-0'),
      CanvasElementId('allowed-rect'),
    ]);
    expect(disabledPreview.query.candidateCount, 0);
    expect(disabledPreview.exactCheckCount, 0);
    expect(disabledPreview.erasedElementIds, isEmpty);
    expect(disabledTerminal.query.candidateCount, 0);
    expect(disabledTerminal.exactCheckCount, 0);
    expect(disabledTerminal.erasedElementIds, isEmpty);
  });
}

// This target matrix stays together so content-vs-empty behavior and guard facts
// are proved against the same document ordering fixture.
// ignore: halstead-volume
void _testContextTargetReadFacts() {
  test(
    'context target facts distinguish content from empty background coverage',
    () {
      final root = _runtimeRoot();
      addTearDown(root.dispose);

      final content =
          root.interactionReadPort.directContextTargetFacts(
                const ContextTargetReadRequest(worldPosition: Offset(5, 25)),
              )
              as AdmittedContextTargetRead;
      final contentFacts = content.facts;

      expect(contentFacts.kind, ContextActionReadTargetKind.contentElement);
      expect(contentFacts.elementId, CanvasElementId('nonselectable-a'));
      expect(contentFacts.elementKind, CanvasElementKind.rect);
      expect(contentFacts.elementSnapshot, isA<CanvasRectElement>());
      expect(contentFacts.boundsWorld, const Rect.fromLTRB(-5, 15, 5, 25));
      expect(contentFacts.generation, 0);
      expect(contentFacts.elementRevision, 0);
      expect(contentFacts.controllerEpoch, 0);
      expect(contentFacts.documentRevision, 0);

      final empty =
          root.interactionReadPort.directContextTargetFacts(
                const ContextTargetReadRequest(worldPosition: Offset(200, 200)),
              )
              as AdmittedContextTargetRead;
      final emptyFacts = empty.facts;

      expect(emptyFacts.kind, ContextActionReadTargetKind.emptyCanvas);
      expect(emptyFacts.elementId, isNull);
      expect(emptyFacts.elementSnapshot, isNull);
      expect(emptyFacts.boundsWorld, isNull);
      expect(emptyFacts.controllerEpoch, 0);
      expect(emptyFacts.documentRevision, 0);
    },
  );
}

void _testVectorContextTargetReadFacts() {
  test(
    'context target reads capture content vectors and exclude background',
    () {
      final root = _runtimeRoot();
      addTearDown(root.dispose);

      final content =
          root.interactionReadPort.directContextTargetFacts(
                const ContextTargetReadRequest(worldPosition: Offset(65, 5)),
              )
              as AdmittedContextTargetRead;

      expect(content.facts.kind, ContextActionReadTargetKind.contentElement);
      expect(content.facts.elementId, CanvasElementId('vector-a'));
      expect(content.facts.elementKind, CanvasElementKind.vector);
      expect(content.facts.elementSnapshot, isA<CanvasVectorElement>());

      final background =
          root.interactionReadPort.directContextTargetFacts(
                const ContextTargetReadRequest(worldPosition: Offset(105, 25)),
              )
              as AdmittedContextTargetRead;
      expect(background.facts.kind, ContextActionReadTargetKind.emptyCanvas);
    },
  );
}

void _testRejectedContextTargetReadOutcomes() {
  _testInvalidIndexContextTargetReadOutcome();
  _testStaleIndexContextTargetReadOutcome();
  _testBudgetExceededContextTargetReadOutcome();
}

void _testInvalidIndexContextTargetReadOutcome() {
  test('context target reads reject invalid spatial index results', () {
    final root = runtimeRootWithCommittedDocumentSeed(
      CanvasDocument(),
      config: const CanvasRuntimeConfig(
        deletionCommitResolver: _acceptDeletionCommit,
      ),
    );
    addTearDown(root.dispose);
    root.spatialKernel.applyTouched(
      root,
      TouchedSet(updatedElementIds: [CanvasElementId('missing')]),
    );

    final rejected = root.interactionReadPort.directContextTargetFacts(
      const ContextTargetReadRequest(worldPosition: Offset.zero),
    );

    expect(rejected, isA<RejectedContextTargetRead>());
    expect(rejected.query.status, InteractionReadQueryStatus.invalidIndex);
  });
}

void _testStaleIndexContextTargetReadOutcome() {
  test('context target reads reject stale spatial index results', () {
    final root = _runtimeRoot();
    addTearDown(root.dispose);
    root.edits.edit((edit) {
      edit.addElement(
        _rect('fresh-a', Offset.zero),
        layerId: CanvasLayerId('layer-a'),
      );
    });
    root.spatialKernel.resetEmpty(0);

    final rejected = root.interactionReadPort.directContextTargetFacts(
      const ContextTargetReadRequest(worldPosition: Offset.zero),
    );

    expect(rejected, isA<RejectedContextTargetRead>());
    expect(rejected.query.status, InteractionReadQueryStatus.staleIndex);
  });
}

void _testBudgetExceededContextTargetReadOutcome() {
  test('context target reads reject fallback budget overflow results', () {
    final root = runtimeRootWithCommittedDocumentSeed(
      _fallbackBudgetDocument(),
      config: const CanvasRuntimeConfig(
        deletionCommitResolver: _acceptDeletionCommit,
      ),
    );
    addTearDown(root.dispose);
    root.spatialKernel.applyTouched(
      root,
      TouchedSet(updatedElementIds: [CanvasElementId('missing')]),
    );

    final rejected = root.interactionReadPort.directContextTargetFacts(
      const ContextTargetReadRequest(worldPosition: Offset.zero),
    );

    expect(rejected, isA<RejectedContextTargetRead>());
    expect(rejected.query.status, InteractionReadQueryStatus.budgetExceeded);
    expect(
      rejected.query.budgetExceededReason,
      InteractionReadBudgetExceededReason.fallbackCandidateBudgetExceeded,
    );
  });
}

void _testTextCommitGuardFacts() {
  test('text guard facts include current kind and observation revision', () {
    final root = _runtimeRoot();
    addTearDown(root.dispose);

    final textFacts = root.interactionReadPort.textCommitGuardFacts(
      TextCommitGuardReadRequest(targetElementId: CanvasElementId('text-a')),
    );

    expect(textFacts.exists, isTrue);
    expect(textFacts.targetKind, CanvasElementKind.text);
    expect(textFacts.generation, 0);
    expect(textFacts.elementRevision, 0);
    expect(textFacts.currentText, 'hello');
    expect(textFacts.controllerEpoch, 0);
    expect(textFacts.documentRevision, 0);

    final backgroundFacts = root.interactionReadPort.textCommitGuardFacts(
      TextCommitGuardReadRequest(
        targetElementId: CanvasElementId('background-a'),
      ),
    );

    expect(backgroundFacts.exists, isFalse);
    expect(backgroundFacts.targetKind, isNull);
    expect(backgroundFacts.documentRevision, 0);
  });
}

CanvasDocument _fallbackBudgetDocument() {
  return CanvasDocument(
    layers: [
      CanvasLayer(
        id: CanvasLayerId('layer-a'),
        elements: [
          for (var index = 0; index <= kCanvasMaxFallbackCandidates; index += 1)
            _rect('fallback-$index', Offset(index * 20, 0)),
        ],
      ),
    ],
  );
}

RuntimeRoot _runtimeRoot() {
  return runtimeRootWithCommittedDocumentSeed(
    _document(),
    config: const CanvasRuntimeConfig(
      deletionCommitResolver: _acceptDeletionCommit,
    ),
  );
}

RuntimeRoot _eraserPolicyRoot(
  CanvasRuntimeConfig config, {
  int disallowedTextCount = 1,
}) {
  return runtimeRootWithCommittedDocumentSeed(
    CanvasDocument(
      layers: [
        CanvasLayer(
          id: CanvasLayerId('eraser-policy-layer'),
          elements: [
            for (var index = 0; index < disallowedTextCount; index += 1)
              CanvasTextElement(
                id: CanvasElementId('disallowed-text-$index'),
                text: 'text',
                color: const Color(0xFF000000),
                textDirection: TextDirection.ltr,
                transform: CanvasTransform.translation(const Offset(-5, -5)),
              ),
            _rect('allowed-rect', const Offset(-5, -5)),
          ],
        ),
      ],
    ),
    config: config,
  );
}

CanvasDocument _groupSelectionDocument({
  required bool includeOccluder,
  bool occluderSelectable = true,
}) {
  return CanvasDocument(
    layers: [
      CanvasLayer(
        id: CanvasLayerId('layer-a'),
        elements: [
          _rect('selected-left', const Offset(0, 0)),
          _rect('selected-right', const Offset(30, 0)),
          if (includeOccluder)
            occluderSelectable
                ? _rect('occluder-a', const Offset(15, 0))
                : _nonselectableRect('occluder-a', const Offset(15, 0)),
        ],
      ),
    ],
  );
}

CanvasDocument _singleSelectedLineDocument() {
  return CanvasDocument(
    layers: [
      CanvasLayer(
        id: CanvasLayerId('layer-a'),
        elements: [
          CanvasLineElement(
            id: CanvasElementId('line-a'),
            start: Offset.zero,
            end: const Offset(100, 100),
            thickness: 2,
            color: const Color(0xFF111111),
          ),
        ],
      ),
    ],
  );
}

// The fixture document keeps all read-port target families in one place so
// ordering, background coverage, selectable state, and text facts do not drift.
// Keeping that complete committed document together is clearer than scattering
// the target-family setup merely to reduce the fixture's line count.
// ignore: halstead-volume, source-lines-of-code
CanvasDocument _document() {
  return CanvasDocument(
    resources: [
      CanvasVectorResource(
        id: CanvasResourceId('vector-resource'),
        source: CanvasResourceSource.appKey('vector-resource'),
      ),
    ],
    backgroundElements: [
      CanvasRectElement(
        id: CanvasElementId('background-a'),
        size: const Size(10, 10),
      ),
      CanvasRectElement(
        id: CanvasElementId('background-b'),
        size: const Size(10, 10),
        transform: CanvasTransform.translation(const Offset(80, 0)),
      ),
      CanvasVectorElement(
        id: CanvasElementId('background-vector-a'),
        resourceId: CanvasResourceId('vector-resource'),
        size: const Size(10, 10),
        transform: CanvasTransform.translation(const Offset(100, 20)),
      ),
    ],
    layers: [
      CanvasLayer(
        id: CanvasLayerId('layer-a'),
        elements: [
          _rect('movable-a', const Offset(0, 0)),
          _lockedRect('locked-a', const Offset(20, 0)),
          _staticRect('static-a', const Offset(40, 0)),
          CanvasTextElement(
            id: CanvasElementId('text-a'),
            text: 'hello',
            color: const Color(0xFF000000),
            textDirection: TextDirection.ltr,
            transform: CanvasTransform.translation(const Offset(120, 0)),
          ),
          _nonselectableRect('nonselectable-a', const Offset(0, 20)),
          _hiddenRect('hidden-a', const Offset(20, 20)),
          CanvasVectorElement(
            id: CanvasElementId('vector-a'),
            resourceId: CanvasResourceId('vector-resource'),
            size: const Size(10, 10),
            transform: CanvasTransform.translation(const Offset(60, 0)),
          ),
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

CanvasDeletionDecision _acceptDeletionCommit(CanvasDeletionCommitRequest _) =>
    CanvasDeletionDecision.accept;
