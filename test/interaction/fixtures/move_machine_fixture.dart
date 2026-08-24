import 'dart:ui';
import "../../support/runtime_root_with_committed_document_seed.dart";

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine/src/contracts/internal/commit_delivery.dart';
import 'package:iwb_canvas_engine/src/contracts/internal/resolver_mutation_guard.dart';
import 'package:iwb_canvas_engine/src/diagnostics/diagnostic_code.dart';
import 'package:iwb_canvas_engine/src/interaction/interaction_pointer_context.dart';
import 'package:iwb_canvas_engine/src/interaction/interaction_read_port.dart';
import 'package:iwb_canvas_engine/src/interaction/move_machine.dart';
import 'package:iwb_canvas_engine/src/interaction/pointer_cleanup_protocol.dart';
import 'package:iwb_canvas_engine/src/runtime/runtime_root.dart';
import 'package:iwb_canvas_engine/src/store/committed_document.dart';
import 'package:iwb_canvas_engine/src/store/document_store_kernel.dart';

// This fixture exercises one public pointer route across its real owners, so
// keeping the focused imports together is clearer than introducing test glue.
// ignore_for_file: number-of-imports

const _selectedMoveDragEnd = Offset(9, 0);
const _groupMoveStart = Offset(10, 0);
const _groupMoveEnd = Offset(19, 0);
const _previewDelta = Offset(5, 0);
const _commitDelta = Offset(17, 0);

void main() {
  _registerMoveMachineFactTests();
  _registerUnselectedMoveRegressionTests();
  _registerSelectedMoveStartTests();
  _registerSelectedMoveTerminalTests();
  _registerSelectedMoveCleanupTests();
  _registerResolverReentrancyTests();
}

void _registerMoveMachineFactTests() {
  _testMoveMachineGroupAdmissionFacts();
  _testMoveMachineRejectsOccludedGroupFacts();
  _testMoveMachineRejectsSingleSelectionGroupFacts();
  _testMoveMachineRejectsNonFiniteGroupFacts();
  _testMoveMachineRejectsGroupUnionWithoutCandidateQueryProof();
  _testMoveMachineRejectsGroupUnionWithSkippedCandidates();
  _testMoveMachineRejectsGroupUnionWithUnreliableOcclusionRead();
}

void _registerUnselectedMoveRegressionTests() {
  _testSelectedMoveAdmissionAndPreview();
  _testUnselectedMovableDragSelectsAndMoves();
  _testUnselectedMovableDragCancelRestoresSelection();
  _testUnselectedMovableResolverCancelRestoresSelection();
  _testUnselectedMovableDragUsesDragStartSlop();
  _testUnselectedMovableClickJitterRemainsSelectionTap();
  _testUnselectedMovableTapTerminalRestoresPreviousSelection();
  _testUnselectedMovableCleanupPreservesExternalSelection();
  _testUnselectedMovablePreviewRequiresCurrentSelection();
  _testUnselectedMovableInvalidTerminalRestoresSelection();
  _testUnselectedMovableCleanupPreservesExternalSelectionRoundTrip();
  _testUnselectedMovableTapTerminalPreservesExternalSelection();
  _testUnselectedMovableTapTerminalReadsTerminalTopmost();
  _testLockedHitDoesNotStartMove();
}

void _registerSelectedMoveStartTests() {
  _testSelectedMoveDragStartSlopFallbackUsesTapSlop();
  _testSelectedMoveContinuesInsideSlopAfterPreviewStart();
  _testGroupInteriorSelectedMoveAdmissionAndPreview();
  _testOccludedGroupInteriorDoesNotStartSelectedMove();
  _testNonSelectableOccludedGroupInteriorDoesNotStartSelectedMove();
  _testSingleSelectedLineBoundsMissDoesNotStartSelectedMove();
  _testSameDeltaMoveKeepsPreviewRevision();
}

void _registerSelectedMoveTerminalTests() {
  _testSelectedMoveZeroDeltaDoesNotResolve();
  _testGroupInteriorZeroDeltaDoesNotResolve();
  _testSelectedMoveStaleSelectionDoesNotResolve();
  _testGroupInteriorStaleSelectionDoesNotResolve();
  _testSelectedMoveInvalidTerminalDoesNotResolve();
  _testSelectedMoveEmptyMovableSetDoesNotResolve();
  _testSelectedMoveCommitWithResolver();
  _testGroupInteriorSelectedMoveCommitWithResolver();
  _testSelectedVectorMoveCommitUpdatesDocument();
  _testSelectedMoveResolverPrecedesPreparation();
}

void _registerSelectedMoveCleanupTests() {
  _testSelectedMoveResolverCancelDoesNotCommit();
  _testSelectedMoveResolverZeroDeltaDoesNotCommit();
  _testGroupInteriorResolverCancelDoesNotCommit();
  _testSelectedMoveResolverErrorCleansPreview();
  _testGroupInteriorResolverErrorCleansPreview();
  _testSelectedMoveNonFiniteResolverDeltaCleansPreview();
  _testSelectedMoveCancelDoesNotResolve();
  _testSelectedMoveModeChangeDoesNotResolve();
  _testSelectedMoveInteractiveDisabledDoesNotResolve();
  _testSelectedMoveLoadAndDisposeDoNotResolve();
  _testSelectedMoveEditFailureCleansPreview();
}

void _registerResolverReentrancyTests() {
  _testSelectedMoveResolverReentrancy();
  _testSelectedMoveResolverDisposeReentrancy();
  _testSelectedMoveResolverFailureFidelity();
  _testSelectedMoveCleanupPrecedesDelivery();
}

void _testMoveMachineGroupAdmissionFacts() {
  test('move machine admits complete multi-select group union facts', () {
    final decision = const MoveMachine().start(_groupStartFacts());

    expect(decision.admitted, isTrue);
    expect(decision.selectedIds, [CanvasElementId('a'), CanvasElementId('b')]);
    expect(decision.movableIds, [CanvasElementId('a'), CanvasElementId('b')]);
  });
}

void _testMoveMachineRejectsOccludedGroupFacts() {
  test('move machine rejects occluded selected group union facts', () {
    expect(
      const MoveMachine().start(_groupStartFacts(occluded: true)).admitted,
      isFalse,
    );
  });
}

void _testMoveMachineRejectsSingleSelectionGroupFacts() {
  test('move machine rejects single-selection group union facts', () {
    expect(
      const MoveMachine()
          .start(_groupStartFacts(singleSelection: true))
          .admitted,
      isFalse,
    );
  });
}

void _testMoveMachineRejectsNonFiniteGroupFacts() {
  test('move machine rejects non-finite selected group union facts', () {
    expect(
      const MoveMachine()
          .start(
            _groupStartFacts(
              bounds: const Rect.fromLTRB(-5, -5, double.infinity, 5),
            ),
          )
          .admitted,
      isFalse,
    );
  });
}

void _testMoveMachineRejectsGroupUnionWithoutCandidateQueryProof() {
  test(
    'move machine rejects group union facts without candidate query proof',
    () {
      expect(
        const MoveMachine()
            .start(
              _groupStartFacts(query: const InteractionReadQueryFacts.notRun()),
            )
            .admitted,
        isFalse,
      );
    },
  );
}

void _testMoveMachineRejectsGroupUnionWithSkippedCandidates() {
  test('move machine rejects group union facts with skipped candidates', () {
    expect(
      const MoveMachine()
          .start(
            _groupStartFacts(
              query: const InteractionReadQueryFacts.candidates(
                candidateCount: 2,
                skippedCandidateCount: 1,
              ),
            ),
          )
          .admitted,
      isFalse,
    );
  });
}

void _testMoveMachineRejectsGroupUnionWithUnreliableOcclusionRead() {
  test('move machine rejects group union facts with unreliable occlusion', () {
    expect(
      const MoveMachine()
          .start(
            SelectedMoveStartFacts(
              selectedIds: [CanvasElementId('a'), CanvasElementId('b')],
              movableSelectedIds: [CanvasElementId('a'), CanvasElementId('b')],
              controllerEpoch: 0,
              selectionRevision: 0,
              hitSelectedMovable: false,
              selectedGroupBoundsWorld: const Rect.fromLTRB(-5, -5, 25, 5),
              selectedTopOrderToken: 1,
              insideSelectedGroupUnion: true,
              groupUnionOcclusionReliable: false,
              query: const InteractionReadQueryFacts.candidates(
                candidateCount: 0,
                skippedCandidateCount: 0,
              ),
            ),
          )
          .admitted,
      isFalse,
    );
  });
}

void _testSelectedMoveAdmissionAndPreview() {
  test(
    'selected move admits selected hit and publishes delta-only preview',
    () {
      final root = _runtimeRoot();
      addTearDown(root.dispose);
      root.selection.setSelection([CanvasElementId('a'), CanvasElementId('b')]);

      root.handlePointer(
        _sample(CanvasPointerLifecyclePhase.down, Offset.zero),
      );
      root.handlePointer(
        _sample(CanvasPointerLifecyclePhase.move, _selectedMoveDragEnd),
      );

      expect(root.interactionEngine.activeSession, isNotNull);
      final preview = root.preview as CanvasSelectedMovePreview;
      expect(preview.delta, _selectedMoveDragEnd);
      expect(root.state.value.revisions.preview, 1);
    },
  );
}

void _testUnselectedMovableDragSelectsAndMoves() {
  test(
    'dragging unselected movable hit selects it and commits move only',
    () async {
      final scenario = _actionScenario(config: _dragStartBeforeTapConfig());
      final root = scenario.root;
      _selectPreviousObject(root);

      _startUnselectedMovablePreview(root, _commitDelta);
      _finishPointer(root, CanvasPointerLifecyclePhase.up, timestampMs: 17);
      await Future<void>.delayed(Duration.zero);

      expect(_rect(root, 'a').transform.translation, _commitDelta);
      expect(_rect(root, 'b').transform.translation, const Offset(20, 0));
      expect(root.selection.selectedElementIds, {CanvasElementId('a')});
      _expectSingleActionForA(scenario, CanvasActionType.moveSelection);
    },
  );
}

void _testUnselectedMovableDragCancelRestoresSelection() {
  test('cancel during unselected movable drag restores previous selection', () {
    final scenario = _actionScenario(
      config: CanvasRuntimeConfig(
        pointerPolicy: CanvasPointerPolicy(tapSlop: 16, dragStartSlop: 4),
      ),
    );
    final root = scenario.root;
    root.selection.setSelection([CanvasElementId('b')]);

    root.handlePointer(_sample(CanvasPointerLifecyclePhase.down, Offset.zero));
    root.handlePointer(
      _sample(CanvasPointerLifecyclePhase.move, const Offset(5, 0)),
    );
    root.handlePointer(
      _sample(CanvasPointerLifecyclePhase.cancel, const Offset(5, 0)),
    );

    expect(root.preview, isA<CanvasNoPreview>());
    expect(root.selection.selectedElementIds, {CanvasElementId('b')});
    expect(_rect(root, 'a').transform.translation, Offset.zero);
    expect(scenario.actions, isEmpty);
  });
}

void _testUnselectedMovableResolverCancelRestoresSelection() {
  test(
    'resolver cancel during unselected movable drag restores previous selection',
    () async {
      final scenario = _actionScenario(
        config: _dragStartBeforeTapConfig(
          moveCommitResolver: (_) => const CanvasMoveCancel(),
        ),
      );
      final root = scenario.root;
      _selectPreviousObject(root);

      _startUnselectedMovablePreview(root, _commitDelta);
      _finishPointer(root, CanvasPointerLifecyclePhase.up);
      await Future<void>.delayed(Duration.zero);

      _expectPreviousSelectionRestored(root);
      expect(scenario.actions, isEmpty);
    },
  );
}

void _testUnselectedMovableDragUsesDragStartSlop() {
  test('unselected movable drag starts after dragStartSlop before tapSlop', () {
    final root = _runtimeRoot(
      config: CanvasRuntimeConfig(
        pointerPolicy: CanvasPointerPolicy(tapSlop: 16, dragStartSlop: 4),
      ),
    );
    addTearDown(root.dispose);

    root.handlePointer(_sample(CanvasPointerLifecyclePhase.down, Offset.zero));
    root.handlePointer(
      _sample(CanvasPointerLifecyclePhase.move, const Offset(4, 0)),
    );
    expect(root.preview, isA<CanvasNoPreview>());

    root.handlePointer(
      _sample(CanvasPointerLifecyclePhase.move, const Offset(5, 0)),
    );
    final preview = root.preview as CanvasSelectedMovePreview;
    expect(preview.delta, const Offset(5, 0));
  });
}

void _testUnselectedMovableClickJitterRemainsSelectionTap() {
  test(
    'unselected movable click jitter inside tapSlop remains selection tap',
    () async {
      final scenario = _actionScenario(config: _dragStartBeforeTapConfig());
      final root = scenario.root;
      _selectPreviousObject(root);

      _startUnselectedMovablePreview(root, _previewDelta);
      _finishPointer(
        root,
        CanvasPointerLifecyclePhase.up,
        position: _previewDelta,
      );
      await Future<void>.delayed(Duration.zero);

      expect(root.preview, isA<CanvasNoPreview>());
      expect(root.selection.selectedElementIds, {CanvasElementId('a')});
      expect(_rect(root, 'a').transform.translation, Offset.zero);
      _expectSingleActionForA(scenario, CanvasActionType.selectMarquee);
    },
  );
}

void _testUnselectedMovableTapTerminalRestoresPreviousSelection() {
  test(
    'unselected movable tap terminal restores previous selection on no-op select',
    () async {
      final scenario = _actionScenario(config: _wideTapDragStartConfig());
      final root = scenario.root;
      _selectPreviousObject(root);

      _startUnselectedMovablePreview(root, _previewDelta);
      _finishPointer(
        root,
        CanvasPointerLifecyclePhase.up,
        position: const Offset(20, 0),
      );
      await Future<void>.delayed(Duration.zero);

      _expectPreviousSelectionRestored(root);
      expect(scenario.actions, isEmpty);
    },
  );
}

void _testUnselectedMovableTapTerminalReadsTerminalTopmost() {
  test(
    'unselected movable tap terminal selects terminal topmost hit',
    () async {
      final scenario = _actionScenario(config: _dragStartBeforeTapConfig());
      final root = scenario.root;
      _selectPreviousObject(root);

      _startUnselectedMovablePreview(root, _previewDelta);
      _addTerminalTopElement(root);
      _finishPointer(
        root,
        CanvasPointerLifecyclePhase.up,
        position: _previewDelta,
      );
      await Future<void>.delayed(Duration.zero);

      expect(root.preview, isA<CanvasNoPreview>());
      expect(root.selection.selectedElementIds, {
        CanvasElementId('terminal-top'),
      });
      expect(_rect(root, 'a').transform.translation, Offset.zero);
      _expectTerminalTopSelectionAction(scenario);
    },
  );
}

void _testLockedHitDoesNotStartMove() {
  test(
    'dragging locked unselected hit does not start move or marquee',
    () async {
      final scenario = _actionScenario(config: _dragStartBeforeTapConfig());
      final root = scenario.root;

      root.handlePointer(
        _sample(CanvasPointerLifecyclePhase.down, const Offset(40, 0)),
      );
      root.handlePointer(
        _sample(CanvasPointerLifecyclePhase.move, const Offset(57, 0)),
      );
      root.handlePointer(
        _sample(CanvasPointerLifecyclePhase.up, const Offset(57, 0)),
      );
      await Future<void>.delayed(Duration.zero);

      expect(root.preview, isA<CanvasNoPreview>());
      expect(root.selection.selectedElementIds, isEmpty);
      expect(_rect(root, 'locked').transform.translation, const Offset(40, 0));
      expect(scenario.actions, isEmpty);
    },
  );
}

void _testUnselectedMovableCleanupPreservesExternalSelection() {
  test(
    'provisional cleanup preserves external selection replacement',
    () async {
      final scenario = _actionScenario(config: _dragStartBeforeTapConfig());
      final root = scenario.root;
      _selectPreviousObject(root);

      _startUnselectedMovablePreview(root, _commitDelta);
      _selectExternalObject(root);
      _finishPointer(
        root,
        CanvasPointerLifecyclePhase.cancel,
        position: _commitDelta,
      );
      await Future<void>.delayed(Duration.zero);

      expect(root.preview, isA<CanvasNoPreview>());
      expect(root.selection.selectedElementIds, {CanvasElementId('locked')});
      expect(_rect(root, 'a').transform.translation, Offset.zero);
      expect(scenario.actions, isEmpty);
    },
  );
}

void _testUnselectedMovablePreviewRequiresCurrentSelection() {
  test(
    'provisional preview is rejected after external selection replacement',
    () async {
      final scenario = _actionScenario(config: _dragStartBeforeTapConfig());
      final root = scenario.root;
      _selectPreviousObject(root);

      root.handlePointer(
        _sample(CanvasPointerLifecyclePhase.down, Offset.zero),
      );
      _selectExternalObject(root);
      root.handlePointer(
        _sample(CanvasPointerLifecyclePhase.move, _commitDelta),
      );
      await Future<void>.delayed(Duration.zero);

      expect(root.preview, isA<CanvasNoPreview>());
      expect(root.interactionEngine.activeSession, isNull);
      expect(root.selection.selectedElementIds, {CanvasElementId('locked')});
      expect(_rect(root, 'a').transform.translation, Offset.zero);
      expect(scenario.actions, isEmpty);
    },
  );
}

void _testUnselectedMovableInvalidTerminalRestoresSelection() {
  test('provisional stale-controller cleanup carries selection restore', () {
    final scenario = _actionScenario(config: _dragStartBeforeTapConfig());
    final root = scenario.root;
    _selectPreviousObject(root);

    _startUnselectedMovablePreview(root, _commitDelta);
    final admission = root.interactionEngine.handlePointerSample(
      _sample(CanvasPointerLifecyclePhase.up, _commitDelta),
      InteractionPointerContext(
        viewCameraOffset: Offset.zero,
        controllerEpoch: 1,
        selectedIds: root.selection.selectedElementIds,
        selectionRevision: root.selectionFacts.selectionRevision,
        resolveOutputTimestamp: (_) => 0,
      ),
    );

    expect(admission.selectionReplacement?.elementIds, [CanvasElementId('b')]);
    expect(admission.selectionReplacement?.expectedCurrentIds, [
      CanvasElementId('a'),
    ]);
    expect(
      admission.selectionReplacement?.expectedCurrentRevision,
      root.selectionFacts.selectionRevision,
    );
    expect(admission.publishRuntimeState, isTrue);
    expect(scenario.actions, isEmpty);
  });
}

void _testUnselectedMovableCleanupPreservesExternalSelectionRoundTrip() {
  test('provisional cleanup preserves external selection round trip', () async {
    final scenario = _actionScenario(config: _dragStartBeforeTapConfig());
    final root = scenario.root;
    _selectPreviousObject(root);

    _startUnselectedMovablePreview(root, _commitDelta);
    _selectExternalObject(root);
    root.selection.setSelection([CanvasElementId('a')]);
    _finishPointer(
      root,
      CanvasPointerLifecyclePhase.cancel,
      position: _commitDelta,
    );
    await Future<void>.delayed(Duration.zero);

    expect(root.preview, isA<CanvasNoPreview>());
    expect(root.selection.selectedElementIds, {CanvasElementId('a')});
    expect(_rect(root, 'a').transform.translation, Offset.zero);
    expect(scenario.actions, isEmpty);
  });
}

void _testUnselectedMovableTapTerminalPreservesExternalSelection() {
  test(
    'provisional tap terminal preserves external selection replacement',
    () async {
      final scenario = _actionScenario(config: _dragStartBeforeTapConfig());
      final root = scenario.root;
      _selectPreviousObject(root);

      _startUnselectedMovablePreview(root, _previewDelta);
      _selectExternalObject(root);
      _finishPointer(
        root,
        CanvasPointerLifecyclePhase.up,
        position: _previewDelta,
      );
      await Future<void>.delayed(Duration.zero);

      expect(root.preview, isA<CanvasNoPreview>());
      expect(root.selection.selectedElementIds, {CanvasElementId('locked')});
      expect(_rect(root, 'a').transform.translation, Offset.zero);
      expect(scenario.actions, isEmpty);
    },
  );
}

void _testSelectedMoveDragStartSlopFallbackUsesTapSlop() {
  test('selected move dragStartSlop null falls back to tapSlop', () {
    final root = _runtimeRoot(
      config: CanvasRuntimeConfig(
        pointerPolicy: CanvasPointerPolicy(tapSlop: 8),
      ),
    );
    addTearDown(root.dispose);
    root.selection.setSelection([CanvasElementId('a')]);

    root.handlePointer(_sample(CanvasPointerLifecyclePhase.down, Offset.zero));
    root.handlePointer(
      _sample(CanvasPointerLifecyclePhase.move, const Offset(8, 0)),
    );
    expect(root.preview, isA<CanvasNoPreview>());

    root.handlePointer(
      _sample(CanvasPointerLifecyclePhase.move, const Offset(9, 0)),
    );
    final preview = root.preview as CanvasSelectedMovePreview;
    expect(preview.delta, const Offset(9, 0));
  });
}

void _testSelectedMoveContinuesInsideSlopAfterPreviewStart() {
  test('selected move keeps preview live when crossing back through start', () {
    final root = _runtimeRoot(
      config: CanvasRuntimeConfig(
        pointerPolicy: CanvasPointerPolicy(tapSlop: 16, dragStartSlop: 4),
      ),
    );
    addTearDown(root.dispose);
    root.selection.setSelection([CanvasElementId('a')]);

    root.handlePointer(_sample(CanvasPointerLifecyclePhase.down, Offset.zero));
    root.handlePointer(
      _sample(CanvasPointerLifecyclePhase.move, const Offset(5, 0)),
    );
    expect(
      (root.preview as CanvasSelectedMovePreview).delta,
      const Offset(5, 0),
    );

    root.handlePointer(
      _sample(CanvasPointerLifecyclePhase.move, const Offset(3, 0)),
    );
    expect(
      (root.preview as CanvasSelectedMovePreview).delta,
      const Offset(3, 0),
    );

    root.handlePointer(_sample(CanvasPointerLifecyclePhase.move, Offset.zero));
    expect((root.preview as CanvasSelectedMovePreview).delta, Offset.zero);
  });
}

void _testGroupInteriorSelectedMoveAdmissionAndPreview() {
  test('selected move admits empty space inside selected group union', () {
    final root = _runtimeRoot();
    addTearDown(root.dispose);
    root.selection.setSelection([CanvasElementId('a'), CanvasElementId('b')]);

    root.handlePointer(
      _sample(CanvasPointerLifecyclePhase.down, _groupMoveStart),
    );
    root.handlePointer(
      _sample(CanvasPointerLifecyclePhase.move, _groupMoveEnd),
    );

    expect(root.interactionEngine.activeSession, isNotNull);
    final preview = root.preview as CanvasSelectedMovePreview;
    expect(preview.delta, _groupMoveEnd - _groupMoveStart);
  });
}

void _testOccludedGroupInteriorDoesNotStartSelectedMove() {
  test(
    'higher order exact hit blocks selected group union admission',
    () async {
      final scenario = _occludedNoCommitScenario(occluderLocked: true);
      final root = scenario.root;
      root.selection.setSelection([CanvasElementId('a'), CanvasElementId('b')]);

      root.handlePointer(
        _sample(CanvasPointerLifecyclePhase.down, const Offset(15, 0)),
      );
      root.handlePointer(
        _sample(CanvasPointerLifecyclePhase.move, const Offset(24, 0)),
      );
      await Future<void>.delayed(Duration.zero);

      expect(root.preview, isNot(isA<CanvasSelectedMovePreview>()));
      expect(scenario.resolverCalls(), 0);
      expect(scenario.actions, isEmpty);
      _expectOccludedDocumentUnmoved(root);
    },
  );
}

void _testNonSelectableOccludedGroupInteriorDoesNotStartSelectedMove() {
  test(
    'higher order non-selectable content blocks selected group union admission',
    () async {
      final scenario = _occludedNoCommitScenario(occluderSelectable: false);
      final root = scenario.root;
      root.selection.setSelection([CanvasElementId('a'), CanvasElementId('b')]);

      root.handlePointer(
        _sample(CanvasPointerLifecyclePhase.down, const Offset(15, 0)),
      );
      root.handlePointer(
        _sample(CanvasPointerLifecyclePhase.move, const Offset(24, 0)),
      );
      await Future<void>.delayed(Duration.zero);

      expect(root.preview, isNot(isA<CanvasSelectedMovePreview>()));
      expect(scenario.resolverCalls(), 0);
      expect(scenario.actions, isEmpty);
      _expectOccludedDocumentUnmoved(root);
    },
  );
}

void _testSingleSelectedLineBoundsMissDoesNotStartSelectedMove() {
  test('single selected line bounds miss does not start selected move', () {
    final root = runtimeRootWithCommittedDocumentSeed(
      _singleLineDocument(),
      config: const CanvasRuntimeConfig(),
    )..selection.setSelection([CanvasElementId('line-a')]);
    addTearDown(root.dispose);

    root.handlePointer(
      _sample(CanvasPointerLifecyclePhase.down, const Offset(80, 20)),
    );
    root.handlePointer(
      _sample(CanvasPointerLifecyclePhase.move, const Offset(89, 20)),
    );

    expect(root.preview, isNot(isA<CanvasSelectedMovePreview>()));
  });
}

void _testSameDeltaMoveKeepsPreviewRevision() {
  test('selected move same-delta stays private before drag threshold', () {
    final root = _runtimeRoot();
    addTearDown(root.dispose);
    root.selection.setSelection([CanvasElementId('a')]);

    root.handlePointer(_sample(CanvasPointerLifecyclePhase.down, Offset.zero));
    final previewRevision = root.interactionEngine.previewRevision;
    root.handlePointer(_sample(CanvasPointerLifecyclePhase.move, Offset.zero));

    expect(root.interactionEngine.previewRevision, previewRevision);
    expect(root.preview, isA<CanvasNoPreview>());
  });
}

void _testSelectedMoveZeroDeltaDoesNotResolve() {
  test(
    'selected move zero delta terminal cleans up without resolver',
    () async {
      final scenario = _noCommitScenario();
      final root = scenario.root;
      root.selection.setSelection([CanvasElementId('a')]);

      root.handlePointer(
        _sample(CanvasPointerLifecyclePhase.down, Offset.zero),
      );
      root.handlePointer(_sample(CanvasPointerLifecyclePhase.up, Offset.zero));
      await Future<void>.delayed(Duration.zero);

      expect(scenario.resolverCalls(), 0);
      _expectNoMoveEffects(scenario);
    },
  );
}

void _testGroupInteriorZeroDeltaDoesNotResolve() {
  test(
    'selected group interior zero delta terminal cleans up without resolver',
    () async {
      final scenario = _noCommitScenario();
      final root = scenario.root;
      root.selection.setSelection([CanvasElementId('a'), CanvasElementId('b')]);

      root.handlePointer(
        _sample(CanvasPointerLifecyclePhase.down, _groupMoveStart),
      );
      root.handlePointer(
        _sample(CanvasPointerLifecyclePhase.up, _groupMoveStart),
      );
      await Future<void>.delayed(Duration.zero);

      expect(scenario.resolverCalls(), 0);
      _expectNoMoveEffects(scenario);
    },
  );
}

void _testSelectedMoveStaleSelectionDoesNotResolve() {
  test('selected move stale selection terminal cannot edit or act', () async {
    final scenario = _noCommitScenario();
    final root = scenario.root;
    root.selection.setSelection([CanvasElementId('a')]);

    root.handlePointer(_sample(CanvasPointerLifecyclePhase.down, Offset.zero));
    root.selection.clearSelection();
    root.handlePointer(
      _sample(CanvasPointerLifecyclePhase.move, _selectedMoveDragEnd),
    );
    root.handlePointer(
      _sample(CanvasPointerLifecyclePhase.up, _selectedMoveDragEnd),
    );
    await Future<void>.delayed(Duration.zero);

    expect(scenario.resolverCalls(), 0);
    _expectNoMoveEffects(scenario);
  });
}

void _testGroupInteriorStaleSelectionDoesNotResolve() {
  test(
    'selected group interior stale selection terminal cannot edit or act',
    () async {
      final scenario = _noCommitScenario();
      final root = scenario.root;
      root.selection.setSelection([CanvasElementId('a'), CanvasElementId('b')]);

      root.handlePointer(
        _sample(CanvasPointerLifecyclePhase.down, _groupMoveStart),
      );
      root.selection.clearSelection();
      root.handlePointer(
        _sample(CanvasPointerLifecyclePhase.move, _groupMoveEnd),
      );
      root.handlePointer(
        _sample(CanvasPointerLifecyclePhase.up, _groupMoveEnd),
      );
      await Future<void>.delayed(Duration.zero);

      expect(scenario.resolverCalls(), 0);
      _expectNoMoveEffects(scenario);
    },
  );
}

void _testSelectedMoveInvalidTerminalDoesNotResolve() {
  test('selected move invalid terminal cannot edit or act', () async {
    final scenario = _noCommitScenario();
    final root = scenario.root;
    root.selection.setSelection([CanvasElementId('a')]);

    root.handlePointer(_sample(CanvasPointerLifecyclePhase.down, Offset.zero));
    root.handlePointer(
      _sample(CanvasPointerLifecyclePhase.move, _selectedMoveDragEnd),
    );
    root.handlePointer(
      _sample(
        CanvasPointerLifecyclePhase.up,
        _selectedMoveDragEnd,
        pointerId: 2,
      ),
    );
    await Future<void>.delayed(Duration.zero);

    expect(root.interactionEngine.activeSession, isNotNull);
    expect(scenario.resolverCalls(), 0);
    expect(scenario.actions, isEmpty);
    expect(_rect(root, 'a').transform, CanvasTransform.identity);
  });
}

void _testSelectedMoveEmptyMovableSetDoesNotResolve() {
  test('selected move empty movable set terminal cannot edit or act', () async {
    final scenario = _noCommitScenario();
    final root = scenario.root;
    root.selection.setSelection([CanvasElementId('a')]);

    root.handlePointer(_sample(CanvasPointerLifecyclePhase.down, Offset.zero));
    root.edits.edit(
      (edit) => edit.updateElement(
        CanvasRectElementUpdate(
          id: CanvasElementId('a'),
          isLocked: const CanvasFieldSet(true),
        ),
      ),
    );
    root.handlePointer(
      _sample(CanvasPointerLifecyclePhase.move, _selectedMoveDragEnd),
    );
    root.handlePointer(
      _sample(CanvasPointerLifecyclePhase.up, _selectedMoveDragEnd),
    );
    await Future<void>.delayed(Duration.zero);

    expect(scenario.resolverCalls(), 0);
    _expectNoMoveEffects(scenario, expectedLocked: true);
  });
}

void _testSelectedMoveCommitWithResolver() {
  test(
    'selected move terminal commits resolved delta and typed action',
    () async {
      final scenario = _commitScenario();
      final root = scenario.root;
      final actions = scenario.actions;
      root.selection.setSelection([CanvasElementId('b'), CanvasElementId('a')]);

      _dragSelectedMove(root, start: Offset.zero, end: _selectedMoveDragEnd);
      await Future<void>.delayed(Duration.zero);

      expect(scenario.resolverCalls(), 1);
      _expectResolverRequest(scenario.request());
      _expectCommittedTransforms(root);
      _expectMoveAction(actions.single);
      expect(root.preview, isA<CanvasNoPreview>());
    },
  );
}

void _testGroupInteriorSelectedMoveCommitWithResolver() {
  test(
    'selected group interior terminal uses existing move commit path',
    () async {
      final scenario = _commitScenario();
      final root = scenario.root;
      final actions = scenario.actions;
      root.selection.setSelection([CanvasElementId('b'), CanvasElementId('a')]);

      _dragSelectedMove(root, start: _groupMoveStart, end: _groupMoveEnd);
      await Future<void>.delayed(Duration.zero);

      expect(scenario.resolverCalls(), 1);
      final request = scenario.request() as CanvasMoveCommitRequest;
      expect(request.proposedDelta, _groupMoveEnd - _groupMoveStart);
      _expectGroupResolverRequest(request);
      _expectCommittedTransforms(root);
      _expectMoveAction(actions.single);
      expect(root.preview, isA<CanvasNoPreview>());
    },
  );
}

// The real selection start, resolver commit, and committed document result are
// one move transaction; extracting setup would obscure that direct outcome.
// ignore: halstead-volume
void _testSelectedVectorMoveCommitUpdatesDocument() {
  test(
    'selected vector move commits its transformed document element',
    () async {
      final resourceId = CanvasResourceId('vector-resource');
      final root = runtimeRootWithCommittedDocumentSeed(
        CanvasDocument(
          resources: [
            CanvasVectorResource(
              id: resourceId,
              source: CanvasResourceSource.appKey('vector-resource'),
            ),
          ],
          layers: [
            CanvasLayer(
              id: CanvasLayerId('layer-a'),
              elements: [
                CanvasVectorElement(
                  id: CanvasElementId('vector-a'),
                  resourceId: resourceId,
                  size: const Size(10, 10),
                ),
              ],
            ),
          ],
        ),
        config: const CanvasRuntimeConfig(
          moveCommitResolver: _commitVectorMove,
        ),
      );
      addTearDown(root.dispose);
      root.selection.setSelection([CanvasElementId('vector-a')]);

      _dragSelectedMove(root, start: Offset.zero, end: _selectedMoveDragEnd);
      await Future<void>.delayed(Duration.zero);

      final vector =
          root.readDocument().layers.single.elements.single
              as CanvasVectorElement;
      expect(vector.transform, CanvasTransform.translation(const Offset(7, 8)));
    },
  );
}

// The branch matrix shares one route setup and semantic Store observation.
// Keeping it together makes rejected-branch absence directly comparable.
// ignore: halstead-volume, source-lines-of-code, maintainability-index
void _testSelectedMoveResolverPrecedesPreparation() {
  test(
    'selected move resolver closes before preparation and rejected branches',
    () {
      final directTrace = <String>[];
      final directEvents = <RuntimeRouteTemporalEvent>[];
      final direct = _observedMoveRuntime();
      addTearDown(direct.dispose);
      direct.selection.setSelection([CanvasElementId('a')]);
      _startSelectedMove(direct);
      RuntimeRoot.observeRouteTemporalEvents(
        (event) {
          directEvents.add(event);
          _recordResolverGuardTrace(event, directTrace);
        },
        () => CommittedDocument.observeSparseCandidateEvents(
          (event) {
            if (event.kind == StoreSparseCandidateEventKind.open) {
              directTrace.add('prepare-open');
            }
          },
          () => direct.handlePointer(
            _sample(CanvasPointerLifecyclePhase.up, _selectedMoveDragEnd),
          ),
        ),
      );
      expect(directTrace, ['prepare-open']);
      _expectResolverGuardEvents(directEvents, const []);

      final acceptedTrace = <String>[];
      final acceptedEvents = <RuntimeRouteTemporalEvent>[];
      final accepted = _observedMoveRuntime(
        resolver: (_) {
          acceptedTrace.add('resolver-enter');
          try {
            return const CanvasMoveCommit(delta: Offset(3, 0));
          } finally {
            acceptedTrace.add('resolver-exit');
          }
        },
      );
      addTearDown(accepted.dispose);
      accepted.selection.setSelection([CanvasElementId('a')]);
      _startSelectedMove(accepted);
      RuntimeRoot.observeRouteTemporalEvents(
        (event) {
          acceptedEvents.add(event);
          _recordResolverGuardTrace(event, acceptedTrace);
        },
        () => CommittedDocument.observeSparseCandidateEvents(
          (event) {
            if (event.kind == StoreSparseCandidateEventKind.open) {
              acceptedTrace.add('prepare-open');
            }
          },
          () => accepted.handlePointer(
            _sample(CanvasPointerLifecyclePhase.up, _selectedMoveDragEnd),
          ),
        ),
      );
      expect(acceptedTrace, [
        'guard-enter',
        'resolver-enter',
        'resolver-exit',
        'guard-release',
        'prepare-open',
      ]);
      _expectResolverGuardEvents(acceptedEvents, [
        RuntimeRouteTemporalEventKind.resolverGuardEntered,
        RuntimeRouteTemporalEventKind.resolverGuardReleased,
      ]);

      for (final resolver in <CanvasMoveCommitResolver>[
        (_) => const CanvasMoveCancel(),
        (_) => const CanvasMoveCommit(delta: Offset.zero),
        (_) => const CanvasMoveCommit(delta: Offset(double.infinity, 0)),
        (_) => throw StateError('resolver rejection'),
      ]) {
        final trace = <String>[];
        final routeEvents = <RuntimeRouteTemporalEvent>[];
        final rejected = _observedMoveRuntime(
          resolver: (request) {
            trace.add('resolver-enter');
            try {
              return resolver(request);
            } finally {
              trace.add('resolver-exit');
            }
          },
        );
        addTearDown(rejected.dispose);
        rejected.selection.setSelection([CanvasElementId('a')]);
        _startSelectedMove(rejected);
        RuntimeRoot.observeRouteTemporalEvents(
          (event) {
            routeEvents.add(event);
            _recordResolverGuardTrace(event, trace);
          },
          () => CommittedDocument.observeSparseCandidateEvents(
            (event) {
              if (event.kind == StoreSparseCandidateEventKind.open) {
                trace.add('prepare-open');
              }
            },
            () {
              try {
                rejected.handlePointer(
                  _sample(CanvasPointerLifecyclePhase.up, _selectedMoveDragEnd),
                );
              } on Object {
                // Resolver failure is an admitted rejected branch; its public
                // projection is asserted separately below.
              }
            },
          ),
        );
        expect(trace, [
          'guard-enter',
          'resolver-enter',
          'resolver-exit',
          'guard-release',
        ]);
        _expectResolverGuardEvents(routeEvents, [
          RuntimeRouteTemporalEventKind.resolverGuardEntered,
          RuntimeRouteTemporalEventKind.resolverGuardReleased,
        ]);
        expect(rejected.preview, isA<CanvasNoPreview>());
        expect(rejected.interactionEngine.activeSession, isNull);
      }
    },
  );
}

void _recordResolverGuardTrace(
  RuntimeRouteTemporalEvent event,
  List<String> trace,
) {
  switch (event.kind) {
    case RuntimeRouteTemporalEventKind.resolverGuardEntered:
      trace.add('guard-enter');
    case RuntimeRouteTemporalEventKind.resolverGuardReleased:
      trace.add('guard-release');
    default:
      break;
  }
}

void _expectResolverGuardEvents(
  List<RuntimeRouteTemporalEvent> events,
  List<RuntimeRouteTemporalEventKind> expected,
) {
  expect(
    events
        .where(
          (event) =>
              event.kind ==
                  RuntimeRouteTemporalEventKind.resolverGuardEntered ||
              event.kind == RuntimeRouteTemporalEventKind.resolverGuardReleased,
        )
        .map((event) => event.kind),
    expected,
  );
}

void _expectRouteLifecycle(
  List<RuntimeRouteTemporalEvent> events,
  RuntimeNonTextRoute route,
  List<RuntimeRouteTemporalEventKind> expected,
) {
  expect(
    events.where((event) => event.route == route).map((event) => event.kind),
    expected,
  );
}

void _recordRouteLifecycleTrace(
  RuntimeRouteTemporalEvent event,
  RuntimeNonTextRoute route,
  List<String> trace,
) {
  if (event.route != route) return;
  switch (event.kind) {
    case RuntimeRouteTemporalEventKind.preparedApplyReturned:
      trace.add('prepared');
    case RuntimeRouteTemporalEventKind.routeCleanupCompleted:
      trace.add('cleanup');
    case RuntimeRouteTemporalEventKind.cleanupEffectsAugmented:
      trace.add('effects');
    case RuntimeRouteTemporalEventKind.commonDeliveryEntered:
      trace.add('delivery');
    default:
      break;
  }
}

CanvasMoveCommit _commitVectorMove(CanvasMoveCommitRequest _) {
  return const CanvasMoveCommit(delta: Offset(7, 8));
}

_CommitScenario _commitScenario() {
  CanvasMoveCommitRequest? request;
  var resolverCalls = 0;
  final root = _runtimeRoot(
    resolver: (value) {
      resolverCalls += 1;
      request = value;

      return const CanvasMoveCommit(delta: Offset(7, 8));
    },
  );
  final actions = <CanvasActionCommitted>[];
  final subscription = root.actions.listen(actions.add);
  addTearDown(() async {
    await subscription.cancel();
    root.dispose();
  });

  return _CommitScenario(
    root: root,
    actions: actions,
    request: () => request,
    resolverCalls: () => resolverCalls,
  );
}

void _expectResolverRequest(CanvasMoveCommitRequest? request) {
  final value = request as CanvasMoveCommitRequest;
  expect(value.proposedDelta, _selectedMoveDragEnd);
  expect(value.movedElements.map((element) => element.id), [
    CanvasElementId('a'),
    CanvasElementId('b'),
  ]);
  expect(value.selectionBoundsWorld, const Rect.fromLTRB(-5, -5, 25, 5));
}

void _expectGroupResolverRequest(CanvasMoveCommitRequest request) {
  expect(request.movedElements.map((element) => element.id), [
    CanvasElementId('a'),
    CanvasElementId('b'),
  ]);
  expect(request.selectionBoundsWorld, const Rect.fromLTRB(-5, -5, 25, 5));
}

void _expectCommittedTransforms(RuntimeRoot root) {
  final elements = root.readDocument().layers.single.elements;
  final a = elements.whereType<CanvasRectElement>().firstWhere(
    (element) => element.id == CanvasElementId('a'),
  );
  final b = elements.whereType<CanvasRectElement>().firstWhere(
    (element) => element.id == CanvasElementId('b'),
  );

  expect(a.transform, CanvasTransform.translation(const Offset(7, 8)));
  expect(b.transform, CanvasTransform.translation(const Offset(27, 8)));
}

void _expectOccludedDocumentUnmoved(RuntimeRoot root) {
  expect(_rect(root, 'a').transform, CanvasTransform.identity);
  expect(
    _rect(root, 'b').transform,
    CanvasTransform.translation(const Offset(30, 0)),
  );
}

void _expectMoveAction(CanvasActionCommitted action) {
  expect(action.type, CanvasActionType.moveSelection);
  expect(action.elementIds, [CanvasElementId('a'), CanvasElementId('b')]);
  expect(action.timestampMs, 0);
  final payload = action.payload as CanvasTransformActionPayload;
  expect(payload.delta, CanvasTransform.translation(const Offset(7, 8)));
  expect(payload.operation, CanvasTransformOperation.move);
  expect(payload.pivotWorld, isNull);
}

void _testSelectedMoveResolverCancelDoesNotCommit() {
  test('selected move resolver cancel cleans preview without action', () async {
    final scenario = _noCommitScenario(
      resolver: (_) => const CanvasMoveCancel(),
    );
    final root = scenario.root;
    root.selection.setSelection([CanvasElementId('a')]);

    _dragSelectedMove(root, start: Offset.zero, end: _selectedMoveDragEnd);
    await Future<void>.delayed(Duration.zero);

    expect(scenario.resolverCalls(), 1);
    _expectNoMoveEffects(scenario, expectedResolverCalls: 1);
    _expectNextAcceptedMoveStartsTimestampCursor(scenario);
  });
}

void _testSelectedMoveResolverZeroDeltaDoesNotCommit() {
  test(
    'selected move resolver zero delta cleans preview without action',
    () async {
      final scenario = _noCommitScenario(
        resolver: (_) => const CanvasMoveCommit(delta: Offset.zero),
      );
      final root = scenario.root;
      root.selection.setSelection([CanvasElementId('a')]);

      _dragSelectedMove(root, start: Offset.zero, end: _selectedMoveDragEnd);
      await Future<void>.delayed(Duration.zero);

      expect(scenario.resolverCalls(), 1);
      _expectNoMoveEffects(scenario, expectedResolverCalls: 1);
      _expectNextAcceptedMoveStartsTimestampCursor(scenario);
    },
  );
}

void _testGroupInteriorResolverCancelDoesNotCommit() {
  test(
    'selected group interior resolver cancel cleans preview without action',
    () async {
      final scenario = _noCommitScenario(
        resolver: (_) => const CanvasMoveCancel(),
      );
      final root = scenario.root;
      root.selection.setSelection([CanvasElementId('a'), CanvasElementId('b')]);

      _dragSelectedMove(root, start: _groupMoveStart, end: _groupMoveEnd);
      await Future<void>.delayed(Duration.zero);

      expect(scenario.resolverCalls(), 1);
      _expectNoMoveEffects(scenario, expectedResolverCalls: 1);
    },
  );
}

void _testSelectedMoveResolverErrorCleansPreview() {
  test('selected move resolver error cleans preview and rethrows', () {
    final scenario = _noCommitScenario(
      resolver: (_) => throw StateError('resolver failed'),
    );
    final root = scenario.root;
    root.selection.setSelection([CanvasElementId('a')]);
    _startSelectedMove(root);

    expect(
      () => root.handlePointer(
        _sample(CanvasPointerLifecyclePhase.up, _selectedMoveDragEnd),
      ),
      throwsStateError,
    );
    _expectNoMoveEffects(scenario, expectedResolverCalls: 1);
    _expectNextAcceptedMoveStartsTimestampCursor(scenario);
  });
}

void _testGroupInteriorResolverErrorCleansPreview() {
  test(
    'selected group interior resolver error cleans preview and rethrows',
    () {
      final scenario = _noCommitScenario(
        resolver: (_) => throw StateError('resolver failed'),
      );
      final root = scenario.root;
      root.selection.setSelection([CanvasElementId('a'), CanvasElementId('b')]);
      _startGroupInteriorSelectedMove(root);

      expect(
        () => root.handlePointer(
          _sample(CanvasPointerLifecyclePhase.up, _groupMoveEnd),
        ),
        throwsStateError,
      );
      _expectNoMoveEffects(scenario, expectedResolverCalls: 1);
    },
  );
}

void _testSelectedMoveNonFiniteResolverDeltaCleansPreview() {
  test('selected move non-finite resolver delta cleans preview', () {
    final scenario = _noCommitScenario(
      resolver: (_) =>
          const CanvasMoveCommit(delta: Offset(double.infinity, 0)),
    );
    final root = scenario.root;
    root.selection.setSelection([CanvasElementId('a')]);
    _startSelectedMove(root);

    expect(
      () => root.handlePointer(
        _sample(CanvasPointerLifecyclePhase.up, _selectedMoveDragEnd),
      ),
      throwsArgumentError,
    );
    _expectNoMoveEffects(scenario, expectedResolverCalls: 1);
    _expectNextAcceptedMoveStartsTimestampCursor(scenario);
  });
}

void _testSelectedMoveCancelDoesNotResolve() {
  test(
    'selected move cancel clears preview without resolver or action',
    () async {
      final scenario = _cancelScenario();
      final root = scenario.root;
      final actions = scenario.actions;
      root.selection.setSelection([CanvasElementId('a')]);

      root.handlePointer(
        _sample(CanvasPointerLifecyclePhase.down, Offset.zero),
      );
      _cancelSelectedMove(root, const Offset(1, 1));
      await Future<void>.delayed(Duration.zero);

      expect(root.preview, isA<CanvasNoPreview>());
      expect(root.interactionEngine.activeSession, isNull);
      expect(scenario.resolverCalls(), 0);
      expect(actions, isEmpty);
      expect(_rect(root, 'a').transform, CanvasTransform.identity);
    },
  );
}

_CancelScenario _cancelScenario() {
  var resolverCalls = 0;
  final root = _runtimeRoot(
    resolver: (_) {
      resolverCalls += 1;

      return const CanvasMoveCommit(delta: Offset(1, 1));
    },
  );
  final actions = <CanvasActionCommitted>[];
  final subscription = root.actions.listen(actions.add);
  addTearDown(() async {
    await subscription.cancel();
    root.dispose();
  });

  return _CancelScenario(
    root: root,
    actions: actions,
    resolverCalls: () => resolverCalls,
  );
}

void _testSelectedMoveLoadAndDisposeDoNotResolve() {
  test('selected move load and dispose cleanup do not resolve', () {
    final loadScenario = _noCommitScenario();
    loadScenario.root.selection.setSelection([CanvasElementId('a')]);
    _startSelectedMove(loadScenario.root);
    loadScenario.root.edits.loadDocumentFromJson(
      encodeCanvasDocumentToJson(_document()),
    );
    _expectNoMoveEffects(loadScenario);

    final disposeScenario = _noCommitScenario();
    disposeScenario.root.selection.setSelection([CanvasElementId('a')]);
    _startSelectedMove(disposeScenario.root);
    disposeScenario.root.dispose();
    expect(disposeScenario.resolverCalls(), 0);
    expect(disposeScenario.actions, isEmpty);
  });
}

void _testSelectedMoveModeChangeDoesNotResolve() {
  test('selected move mode-change cleanup does not resolve', () {
    final scenario = _noCommitScenario();
    scenario.root.selection.setSelection([CanvasElementId('a')]);
    _startSelectedMove(scenario.root);

    _cleanupSelectedMove(
      scenario.root,
      reason: PointerCleanupReason.modeToolChange,
    );

    expect(scenario.resolverCalls(), 0);
    _expectNoMoveEffects(scenario);
  });
}

void _testSelectedMoveInteractiveDisabledDoesNotResolve() {
  test('selected move interactive-disabled cleanup does not resolve', () {
    final scenario = _noCommitScenario();
    scenario.root.selection.setSelection([CanvasElementId('a')]);
    _startSelectedMove(scenario.root);

    _cleanupSelectedMove(
      scenario.root,
      reason: PointerCleanupReason.interactiveDisabled,
    );

    expect(scenario.resolverCalls(), 0);
    _expectNoMoveEffects(scenario);
  });
}

void _testSelectedMoveEditFailureCleansPreview() {
  test('selected move edit failure cleans preview and rethrows', () {
    final scenario = _noCommitScenario(
      resolver: (_) => const CanvasMoveCommit(delta: Offset(1e8, 0)),
    );
    final root = scenario.root;
    root.selection.setSelection([CanvasElementId('a')]);
    _startSelectedMove(root);

    expect(
      () => root.handlePointer(
        _sample(CanvasPointerLifecyclePhase.up, _selectedMoveDragEnd),
      ),
      throwsA(isA<CanvasDataException>()),
    );
    expect(scenario.resolverCalls(), 1);
    _expectNoMoveEffects(scenario, expectedResolverCalls: 1);
    _expectNextAcceptedMoveStartsTimestampCursor(scenario);
  });
}

_NoCommitScenario _noCommitScenario({CanvasMoveCommitResolver? resolver}) {
  var resolverCalls = 0;
  final root = _runtimeRoot(
    resolver: (request) {
      resolverCalls += 1;

      return resolver?.call(request) ??
          const CanvasMoveCommit(delta: Offset(1, 1));
    },
  );
  final actions = <CanvasActionCommitted>[];
  final subscription = root.actions.listen(actions.add);
  addTearDown(() async {
    await subscription.cancel();
    root.dispose();
  });

  return _NoCommitScenario(
    root: root,
    actions: actions,
    resolverCalls: () => resolverCalls,
  );
}

_NoCommitScenario _occludedNoCommitScenario({
  bool occluderSelectable = true,
  bool occluderLocked = false,
}) {
  var resolverCalls = 0;
  final root = runtimeRootWithCommittedDocumentSeed(
    _occludedGroupDocument(
      occluderSelectable: occluderSelectable,
      occluderLocked: occluderLocked,
    ),
    config: CanvasRuntimeConfig(
      moveCommitResolver: (request) {
        resolverCalls += 1;

        return const CanvasMoveCommit(delta: Offset(1, 1));
      },
    ),
  );
  final actions = <CanvasActionCommitted>[];
  final subscription = root.actions.listen(actions.add);
  addTearDown(() async {
    await subscription.cancel();
    root.dispose();
  });

  return _NoCommitScenario(
    root: root,
    actions: actions,
    resolverCalls: () => resolverCalls,
  );
}

void _expectNoMoveEffects(
  _NoCommitScenario scenario, {
  int expectedResolverCalls = 0,
  bool expectedLocked = false,
}) {
  expect(scenario.root.preview, isA<CanvasNoPreview>());
  expect(scenario.root.interactionEngine.activeSession, isNull);
  expect(scenario.resolverCalls(), expectedResolverCalls);
  expect(scenario.actions, isEmpty);
  expect(_rect(scenario.root, 'a').transform, CanvasTransform.identity);
  expect(_rect(scenario.root, 'a').isLocked, expectedLocked);
}

void _expectNextAcceptedMoveStartsTimestampCursor(_NoCommitScenario scenario) {
  scenario.root.selection.moveSelection(const Offset(2, 0));

  expect(scenario.actions, hasLength(1));
  final action = scenario.actions.single;
  expect(action.type, CanvasActionType.moveSelection);
  expect(action.timestampMs, 0);
}

void _testSelectedMoveResolverReentrancy() {
  test('resolver reentrant public mutation throws without runtime effects', () {
    late RuntimeRoot root;
    root = _runtimeRoot(
      resolver: (_) {
        root.selection.clearSelection();

        return const CanvasMoveCommit(delta: Offset(1, 1));
      },
    );
    addTearDown(root.dispose);
    root.selection.setSelection([CanvasElementId('a')]);

    root.handlePointer(_sample(CanvasPointerLifecyclePhase.down, Offset.zero));
    root.handlePointer(
      _sample(CanvasPointerLifecyclePhase.move, _selectedMoveDragEnd),
    );

    expect(
      () => root.handlePointer(
        _sample(CanvasPointerLifecyclePhase.up, _selectedMoveDragEnd),
      ),
      throwsStateError,
    );
    expect(root.preview, isA<CanvasNoPreview>());
    expect(_rect(root, 'a').transform, CanvasTransform.identity);
  });
}

void _testSelectedMoveResolverDisposeReentrancy() {
  test('resolver reentrant dispose throws without runtime effects', () {
    late RuntimeRoot root;
    root = _runtimeRoot(
      resolver: (_) {
        root.dispose();

        return const CanvasMoveCommit(delta: Offset(1, 1));
      },
    );
    addTearDown(root.dispose);
    root.selection.setSelection([CanvasElementId('a')]);
    _startSelectedMove(root);

    expect(
      () => root.handlePointer(
        _sample(CanvasPointerLifecyclePhase.up, _selectedMoveDragEnd),
      ),
      throwsStateError,
    );
    expect(root.preview, isA<CanvasNoPreview>());
    expect(_rect(root, 'a').transform, CanvasTransform.identity);
    expect(root.state.value.summary.elementCount, 3);
  });
}

// Exact public errors, diagnostics, snapshots, and guard release are one
// failure contract; splitting them would hide the required relation.
// ignore: halstead-volume, source-lines-of-code, maintainability-index
void _testSelectedMoveResolverFailureFidelity() {
  test(
    'selected move resolver preserves rejection and thrown-error fidelity',
    () {
      final sentinel = StateError('move resolver sentinel');
      late RuntimeRoot root;
      var branch = 0;
      root = RuntimeRoot.test(
        config: CanvasRuntimeConfig(
          diagnosticPolicy: const CanvasDiagnosticPolicy.summary(),
          moveCommitResolver: (_) {
            return switch (branch) {
              0 => root.runResolverCallback(() => const CanvasMoveCancel()),
              1 => _rejectPublicMutationFromResolver(root),
              2 => throw sentinel,
              _ => const CanvasMoveCommit(delta: Offset(2, 0)),
            };
          },
        ),
        store: DocumentStoreKernel.withCommittedDocumentForTesting(
          CommittedDocument(_document()),
        ),
      );
      final actions = <CanvasActionCommitted>[];
      final subscription = root.actions.listen(actions.add);
      addTearDown(() async {
        await subscription.cancel();
        root.dispose();
      });
      root.selection.setSelection([CanvasElementId('a')]);

      _startSelectedMove(root);
      final nested = _captureResolverFailureWithoutPreparation(root);
      expect(nested.runtimeType, ResolverCallbackRejection);
      expect(
        nested.message,
        'Nested resource resolver callbacks are not supported.',
      );
      _expectResolverFailureSnapshot(root, actions);

      branch = 1;
      _startSelectedMove(root);
      final mutation = _captureResolverFailureWithoutPreparation(root);
      expect(mutation.runtimeType, ResolverCallbackRejection);
      expect(
        mutation.message,
        'CanvasRuntime public mutations cannot run during resource resolver callbacks.',
      );
      expect(
        root.diagnosticRecords.map((record) => record.code),
        contains(
          const DiagnosticCode.interaction(
            InteractionDiagnosticCode.resolverReentrantMutationRejected,
          ),
        ),
      );
      _expectResolverFailureSnapshot(root, actions);

      branch = 2;
      _startSelectedMove(root);
      final thrown = _captureResolverFailureWithoutPreparation(root);
      expect(identical(thrown, sentinel), isTrue);
      _expectResolverFailureSnapshot(root, actions);

      branch = 3;
      _dragSelectedMove(root, start: Offset.zero, end: _selectedMoveDragEnd);
      expect(actions, hasLength(1));
      expect(_rect(root, 'a').transform.translation, const Offset(2, 0));
    },
  );
}

// The callback surfaces must observe one shared selected-move terminal state.
// Keeping its lifecycle and callbacks together makes their temporal relation
// falsifiable without a second observation path.
// ignore: halstead-volume, source-lines-of-code, maintainability-index
void _testSelectedMoveCleanupPrecedesDelivery() {
  test('selected move callbacks observe cleanup and merged repaint intent', () {
    final trace = <String>[];
    var observerCalls = 0;
    var terminalDelivery = false;
    List<CommitDeliveryEffect>? observedEffects;
    late RuntimeRoot root;
    root = _runtimeRoot(
      config: CanvasRuntimeConfig(
        moveCommitResolver: (_) => const CanvasMoveCommit(delta: Offset(2, 0)),
      ),
      commitEffectObserver: (effects) {
        observerCalls += 1;
        observedEffects = effects;
        _expectCleanSelectedMoveDelivery(root);
        trace.add('observer');
      },
    );
    final surface = Object();
    root.attachSurface(surface);
    root.selection.setSelection([CanvasElementId('a')]);
    _startSelectedMove(root);
    root.surfaceFrameSignal.addListener(() {
      if (!terminalDelivery) return;
      _expectCleanSelectedMoveDelivery(root);
      final signal = root.surfaceFrameSignal.value;
      expect(signal?.mainCanvas, isTrue);
      expect(signal?.overlayCanvas, isFalse);
      trace.add('frame');
    });
    root.state.addListener(() {
      _expectCleanSelectedMoveDelivery(root);
      trace.add('state');
    });
    final subscription = root.actions.listen((_) {
      _expectCleanSelectedMoveDelivery(root);
      trace.add('action');
    });
    addTearDown(() async {
      await subscription.cancel();
      terminalDelivery = false;
      root.detachSurface(surface);
      root.dispose();
    });

    final events = <RuntimeRouteTemporalEvent>[];
    terminalDelivery = true;
    RuntimeRoot.observeRouteTemporalEvents(
      (event) {
        events.add(event);
        _recordRouteLifecycleTrace(
          event,
          RuntimeNonTextRoute.selectedMove,
          trace,
        );
      },
      () => root.handlePointer(
        _sample(CanvasPointerLifecyclePhase.up, _selectedMoveDragEnd),
      ),
    );

    expect(trace, [
      'prepared',
      'cleanup',
      'effects',
      'delivery',
      'frame',
      'state',
      'action',
      'observer',
    ]);
    expect(observerCalls, 1);
    final deliveryEffects = observedEffects;
    if (deliveryEffects == null) {
      fail('Expected selected-move commit-effect observer delivery.');
    }
    _expectSelectedMoveMergedRepaint(deliveryEffects);
    _expectRouteLifecycle(events, RuntimeNonTextRoute.selectedMove, const [
      RuntimeRouteTemporalEventKind.preparedApplyReturned,
      RuntimeRouteTemporalEventKind.routeCleanupCompleted,
      RuntimeRouteTemporalEventKind.cleanupEffectsAugmented,
      RuntimeRouteTemporalEventKind.commonDeliveryEntered,
    ]);
  });
}

void _expectCleanSelectedMoveDelivery(RuntimeRoot root) {
  expect(root.preview, isA<CanvasNoPreview>());
  expect(root.interactionEngine.activeSession, isNull);
}

void _expectSelectedMoveMergedRepaint(List<CommitDeliveryEffect> effects) {
  final repaint = effects.whereType<RepaintDeliveryEffect>().single;
  expect(repaint.mainCanvas, isTrue);
  expect(repaint.overlayCanvas, isFalse);
}

CanvasMoveResolution _rejectPublicMutationFromResolver(RuntimeRoot root) {
  root.generateElementId();

  return const CanvasMoveCancel();
}

StateError _captureResolverFailureWithoutPreparation(RuntimeRoot root) {
  final preparationEvents = <StoreSparseCandidateEvent>[];
  final routeEvents = <RuntimeRouteTemporalEvent>[];
  StateError? failure;
  RuntimeRoot.observeRouteTemporalEvents(
    routeEvents.add,
    () => CommittedDocument.observeSparseCandidateEvents(
      (event) {
        if (event.kind == StoreSparseCandidateEventKind.open) {
          preparationEvents.add(event);
        }
      },
      () {
        try {
          root.handlePointer(
            _sample(CanvasPointerLifecyclePhase.up, _selectedMoveDragEnd),
          );
        } on Object catch (error) {
          expect(error, isA<StateError>());
          failure = error as StateError;
        }
      },
    ),
  );
  expect(preparationEvents, isEmpty);
  _expectResolverGuardEvents(routeEvents, [
    RuntimeRouteTemporalEventKind.resolverGuardEntered,
    RuntimeRouteTemporalEventKind.resolverGuardReleased,
  ]);

  return failure ??
      (throw StateError('Expected selected move resolver failure.'));
}

void _expectResolverFailureSnapshot(
  RuntimeRoot root,
  List<CanvasActionCommitted> actions,
) {
  expect(root.preview, isA<CanvasNoPreview>());
  expect(root.interactionEngine.activeSession, isNull);
  expect(root.state.value.summary.elementCount, 3);
  expect(root.selection.selectedElementIds, {CanvasElementId('a')});
  expect(_rect(root, 'a').transform, CanvasTransform.identity);
  expect(actions, isEmpty);
}

void _dragSelectedMove(
  RuntimeRoot root, {
  required Offset start,
  required Offset end,
}) {
  root.handlePointer(_sample(CanvasPointerLifecyclePhase.down, start));
  root.handlePointer(_sample(CanvasPointerLifecyclePhase.move, end));
  root.handlePointer(_sample(CanvasPointerLifecyclePhase.up, end));
}

CanvasSelectedMovePreview _startUnselectedMovablePreview(
  RuntimeRoot root,
  Offset delta,
) {
  root.handlePointer(_sample(CanvasPointerLifecyclePhase.down, Offset.zero));
  root.handlePointer(_sample(CanvasPointerLifecyclePhase.move, delta));

  expect(root.selection.selectedElementIds, {CanvasElementId('a')});
  final preview = root.preview as CanvasSelectedMovePreview;
  expect(preview.delta, delta);

  return preview;
}

void _finishPointer(
  RuntimeRoot root,
  CanvasPointerLifecyclePhase phase, {
  Offset position = _commitDelta,
  int? timestampMs,
}) {
  root.handlePointer(_sample(phase, position, timestampMs: timestampMs));
}

void _selectPreviousObject(RuntimeRoot root) {
  root.selection.setSelection([CanvasElementId('b')]);
}

void _selectExternalObject(RuntimeRoot root) {
  root.selection.setSelection([CanvasElementId('locked')]);
}

void _addTerminalTopElement(RuntimeRoot root) {
  root.edits.edit((edit) {
    edit.addElement(
      CanvasRectElement(
        id: CanvasElementId('terminal-top'),
        size: const Size(10, 10),
      ),
      layerId: CanvasLayerId('layer-a'),
    );
  });
}

void _expectPreviousSelectionRestored(RuntimeRoot root) {
  expect(root.preview, isA<CanvasNoPreview>());
  expect(root.selection.selectedElementIds, {CanvasElementId('b')});
  expect(_rect(root, 'a').transform.translation, Offset.zero);
}

void _expectSingleActionForA(_ActionScenario scenario, CanvasActionType type) {
  expect(scenario.actions, hasLength(1));
  expect(scenario.actions.single.type, type);
  expect(scenario.actions.single.elementIds, [CanvasElementId('a')]);
}

void _expectTerminalTopSelectionAction(_ActionScenario scenario) {
  expect(scenario.actions, hasLength(1));
  final action = scenario.actions.single;
  expect(action.type, CanvasActionType.selectMarquee);
  expect(action.elementIds, [CanvasElementId('terminal-top')]);
  final payload = action.payload as CanvasSelectionActionPayload;
  expect(payload.previousSelection, [CanvasElementId('b')]);
  expect(payload.nextSelection, [CanvasElementId('terminal-top')]);
}

void _startSelectedMove(RuntimeRoot root) {
  root.handlePointer(_sample(CanvasPointerLifecyclePhase.down, Offset.zero));
  root.handlePointer(
    _sample(CanvasPointerLifecyclePhase.move, _selectedMoveDragEnd),
  );
}

void _startGroupInteriorSelectedMove(RuntimeRoot root) {
  root.handlePointer(
    _sample(CanvasPointerLifecyclePhase.down, _groupMoveStart),
  );
  root.handlePointer(_sample(CanvasPointerLifecyclePhase.move, _groupMoveEnd));
}

void _cleanupSelectedMove(
  RuntimeRoot root, {
  required PointerCleanupReason reason,
}) {
  root.interactionEngine.cleanupPointerTool(
    PointerCleanupRequest(
      reason: reason,
      activePreviewKind: PointerCleanupPreviewKind.selectedMove,
      hasActiveToken: true,
      hasActiveSession: true,
    ),
  );
}

void _cancelSelectedMove(RuntimeRoot root, Offset position) {
  root.handlePointer(_sample(CanvasPointerLifecyclePhase.move, position));
  root.handlePointer(_sample(CanvasPointerLifecyclePhase.cancel, position));
}

_ActionScenario _actionScenario({
  CanvasRuntimeConfig config = const CanvasRuntimeConfig(),
}) {
  final root = _runtimeRoot(config: config);
  final actions = <CanvasActionCommitted>[];
  final subscription = root.actions.listen(actions.add);
  addTearDown(() async {
    await subscription.cancel();
    root.dispose();
  });

  return _ActionScenario(root: root, actions: actions);
}

CanvasRuntimeConfig _dragStartBeforeTapConfig({
  CanvasMoveCommitResolver? moveCommitResolver,
}) {
  return CanvasRuntimeConfig(
    pointerPolicy: CanvasPointerPolicy(tapSlop: 16, dragStartSlop: 4),
    moveCommitResolver: moveCommitResolver,
  );
}

CanvasRuntimeConfig _wideTapDragStartConfig() {
  return CanvasRuntimeConfig(
    pointerPolicy: CanvasPointerPolicy(tapSlop: 32, dragStartSlop: 4),
  );
}

RuntimeRoot _runtimeRoot({
  CanvasMoveCommitResolver? resolver,
  CanvasRuntimeConfig? config,
  CommitEffectObserver? commitEffectObserver,
}) {
  return runtimeRootWithCommittedDocumentSeed(
    _document(),
    config: config ?? CanvasRuntimeConfig(moveCommitResolver: resolver),
    commitEffectObserver: commitEffectObserver,
  );
}

RuntimeRoot _observedMoveRuntime({CanvasMoveCommitResolver? resolver}) {
  final store = DocumentStoreKernel.withCommittedDocumentForTesting(
    CommittedDocument(_document()),
  );
  final root = RuntimeRoot.test(
    config: CanvasRuntimeConfig(moveCommitResolver: resolver),
    store: store,
  );

  return root;
}

CanvasPointerSample _sample(
  CanvasPointerLifecyclePhase phase,
  Offset position, {
  int pointerId = 1,
  int? timestampMs,
}) {
  return CanvasPointerSample(
    pointerId: pointerId,
    position: position,
    phase: phase,
    kind: PointerDeviceKind.touch,
    timestampMs: timestampMs,
  );
}

CanvasRectElement _rect(RuntimeRoot root, String id) {
  return root
      .readDocument()
      .layers
      .single
      .elements
      .whereType<CanvasRectElement>()
      .firstWhere((element) => element.id == CanvasElementId(id));
}

CanvasDocument _document() {
  return CanvasDocument(
    layers: [
      CanvasLayer(
        id: CanvasLayerId('layer-a'),
        elements: [
          CanvasRectElement(id: CanvasElementId('a'), size: const Size(10, 10)),
          CanvasRectElement(
            id: CanvasElementId('b'),
            size: const Size(10, 10),
            transform: CanvasTransform.translation(const Offset(20, 0)),
          ),
          CanvasRectElement(
            id: CanvasElementId('locked'),
            size: const Size(10, 10),
            transform: CanvasTransform.translation(const Offset(40, 0)),
            isLocked: true,
          ),
        ],
      ),
    ],
  );
}

CanvasDocument _occludedGroupDocument({
  bool occluderSelectable = true,
  bool occluderLocked = false,
}) {
  return CanvasDocument(
    layers: [
      CanvasLayer(
        id: CanvasLayerId('layer-a'),
        elements: [
          CanvasRectElement(id: CanvasElementId('a'), size: const Size(10, 10)),
          CanvasRectElement(
            id: CanvasElementId('b'),
            size: const Size(10, 10),
            transform: CanvasTransform.translation(const Offset(30, 0)),
          ),
          CanvasRectElement(
            id: CanvasElementId('occluder'),
            size: const Size(10, 10),
            transform: CanvasTransform.translation(const Offset(15, 0)),
            isSelectable: occluderSelectable,
            isLocked: occluderLocked,
          ),
        ],
      ),
    ],
  );
}

CanvasDocument _singleLineDocument() {
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

SelectedMoveStartFacts _groupStartFacts({
  bool occluded = false,
  bool singleSelection = false,
  Rect? bounds = const Rect.fromLTRB(-5, -5, 25, 5),
  InteractionReadQueryFacts query = const InteractionReadQueryFacts.candidates(
    candidateCount: 0,
    skippedCandidateCount: 0,
  ),
}) {
  final selectedIds = singleSelection
      ? [CanvasElementId('a')]
      : [CanvasElementId('a'), CanvasElementId('b')];

  return SelectedMoveStartFacts(
    selectedIds: selectedIds,
    movableSelectedIds: selectedIds,
    controllerEpoch: 0,
    selectionRevision: 0,
    hitSelectedMovable: false,
    selectedGroupBoundsWorld: bounds,
    selectedTopOrderToken: 1,
    insideSelectedGroupUnion: true,
    groupUnionOccludedByHigherOrderHit: occluded,
    query: query,
  );
}

final class _CommitScenario {
  const _CommitScenario({
    required this.root,
    required this.actions,
    required this.request,
    required this.resolverCalls,
  });

  final RuntimeRoot root;
  final List<CanvasActionCommitted> actions;
  final CanvasMoveCommitRequest? Function() request;
  final int Function() resolverCalls;
}

final class _ActionScenario {
  const _ActionScenario({required this.root, required this.actions});

  final RuntimeRoot root;
  final List<CanvasActionCommitted> actions;
}

final class _CancelScenario {
  const _CancelScenario({
    required this.root,
    required this.actions,
    required this.resolverCalls,
  });

  final RuntimeRoot root;
  final List<CanvasActionCommitted> actions;
  final int Function() resolverCalls;
}

final class _NoCommitScenario {
  const _NoCommitScenario({
    required this.root,
    required this.actions,
    required this.resolverCalls,
  });

  final RuntimeRoot root;
  final List<CanvasActionCommitted> actions;
  final int Function() resolverCalls;
}
