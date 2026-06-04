import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine/src/interaction/interaction_read_port.dart';
import 'package:iwb_canvas_engine/src/interaction/move_machine.dart';
import 'package:iwb_canvas_engine/src/interaction/pointer_cleanup_protocol.dart';
import 'package:iwb_canvas_engine/src/runtime/runtime_root.dart';

const _selectedMoveDragEnd = Offset(9, 0);
const _groupMoveStart = Offset(10, 0);
const _groupMoveEnd = Offset(19, 0);

void main() {
  _testMoveMachineGroupAdmissionFacts();
  _testMoveMachineRejectsOccludedGroupFacts();
  _testMoveMachineRejectsSingleSelectionGroupFacts();
  _testMoveMachineRejectsNonFiniteGroupFacts();
  _testMoveMachineRejectsUnreliableGroupOcclusionFacts();
  _testSelectedMoveAdmissionAndPreview();
  _testGroupInteriorSelectedMoveAdmissionAndPreview();
  _testOccludedGroupInteriorDoesNotStartSelectedMove();
  _testSingleSelectedLineBoundsMissDoesNotStartSelectedMove();
  _testSameDeltaMoveKeepsPreviewRevision();
  _testSelectedMoveZeroDeltaDoesNotResolve();
  _testGroupInteriorZeroDeltaDoesNotResolve();
  _testSelectedMoveStaleSelectionDoesNotResolve();
  _testGroupInteriorStaleSelectionDoesNotResolve();
  _testSelectedMoveInvalidTerminalDoesNotResolve();
  _testSelectedMoveEmptyMovableSetDoesNotResolve();
  _testSelectedMoveCommitWithResolver();
  _testGroupInteriorSelectedMoveCommitWithResolver();
  _testSelectedMoveResolverCancelDoesNotCommit();
  _testGroupInteriorResolverCancelDoesNotCommit();
  _testSelectedMoveResolverErrorCleansPreview();
  _testGroupInteriorResolverErrorCleansPreview();
  _testSelectedMoveNonFiniteResolverDeltaCleansPreview();
  _testSelectedMoveCancelDoesNotResolve();
  _testSelectedMoveModeChangeDoesNotResolve();
  _testSelectedMoveInteractiveDisabledDoesNotResolve();
  _testSelectedMoveLoadAndDisposeDoNotResolve();
  _testSelectedMoveEditFailureCleansPreview();
  _testSelectedMoveResolverReentrancy();
  _testSelectedMoveResolverDisposeReentrancy();
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

void _testMoveMachineRejectsUnreliableGroupOcclusionFacts() {
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
      final scenario = _occludedNoCommitScenario();
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
    final root = RuntimeRoot(
      initialDocument: _singleLineDocument(),
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
  expect(value.timestampMs, 0);
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
  expect(action.timestampMs, 1);
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
  });
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
    loadScenario.root.edits.loadDocument(_document());
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

_NoCommitScenario _occludedNoCommitScenario() {
  var resolverCalls = 0;
  final root = RuntimeRoot(
    initialDocument: _occludedGroupDocument(),
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

void _dragSelectedMove(
  RuntimeRoot root, {
  required Offset start,
  required Offset end,
}) {
  root.handlePointer(_sample(CanvasPointerLifecyclePhase.down, start));
  root.handlePointer(_sample(CanvasPointerLifecyclePhase.move, end));
  root.handlePointer(_sample(CanvasPointerLifecyclePhase.up, end));
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

RuntimeRoot _runtimeRoot({CanvasMoveCommitResolver? resolver}) {
  return RuntimeRoot(
    initialDocument: _document(),
    config: CanvasRuntimeConfig(moveCommitResolver: resolver),
  );
}

CanvasPointerSample _sample(
  CanvasPointerLifecyclePhase phase,
  Offset position, {
  int pointerId = 1,
}) {
  return CanvasPointerSample(
    pointerId: pointerId,
    position: position,
    phase: phase,
    kind: PointerDeviceKind.touch,
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

CanvasDocument _occludedGroupDocument() {
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
