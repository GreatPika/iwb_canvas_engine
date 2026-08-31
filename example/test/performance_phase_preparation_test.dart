import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine_example/perf/performance_fixtures.dart';
import 'package:iwb_canvas_engine_example/perf/performance_host.dart';
import 'package:iwb_canvas_engine_example/perf/performance_scenario.dart';

const _expectedFixtureMetadata = {
  'load_document.100k': {
    'preparedJsonElementCount': 100000,
    'targetElementCountBeforeAction': 0,
    'targetSelectedCountBeforeAction': 0,
  },
  'first_canvas_frame.50k': {
    'loadedElementCount': 50000,
    'surfaceRenderState': 'not_rendered_by_measured_surface',
  },
  'camera_pan.100k': {
    'loadedElementCount': 100000,
    'cameraOffsetBeforeAction': Offset.zero,
  },
  'selection_move.50k': {
    'loadedElementCount': 50000,
    'selectedElementId': 'r0',
    'selectedElementGeometry': 'original',
  },
  'marquee_select.50k': {
    'loadedElementCount': 50000,
    'selectedCountBeforeAction': 0,
    'toolModeBeforeAction': 'move',
  },
  'json_export.50k': {
    'loadedElementCount': 50000,
    'documentOrder': 'stable',
    'pendingEditSession': false,
  },
  'eraser_dense_50k': {
    'loadedElementCount': 50000,
    'toolModeBeforeAction': 'draw',
    'drawToolBeforeAction': 'eraser',
    'erasedElementCountBeforeAction': 0,
  },
  'eraser_delete_many.1k': {
    'loadedElementCount': performanceEraserDeletionBatchCount,
    'expectedErasedElementCount': performanceEraserDeletionBatchCount,
    'toolModeBeforeAction': 'draw',
    'drawToolBeforeAction': 'eraser',
  },
  'context_request_batch.64': {
    'loadedElementCount': 0,
    'contextRequestBatchCount': performanceContextRequestBatchCount,
    'toolModeBeforeAction': 'move',
  },
};

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('redesigned steady repeats start from canonical public state', (
    _,
  ) async {
    await expectLater(
      _expectRedesignedSteadyRepeatPreparation(binding),
      completes,
    );
  });

  test('interaction setup phases stop before measured actions', () async {
    await expectLater(_expectInteractionSetupSeparation(), completes);
  });

  testWidgets('batch performance phases execute their declared workloads', (
    _,
  ) async {
    final workload = await _executeBatchWorkloads(binding);
    expect(workload.erasedElementCount, performanceEraserDeletionBatchCount);
    expect(
      workload.contextRequests,
      hasLength(performanceContextRequestBatchCount),
    );
  });
}

Future<void> _expectRedesignedSteadyRepeatPreparation(
  IntegrationTestWidgetsFlutterBinding binding,
) async {
  for (final groupId in _expectedFixtureMetadata.keys) {
    final repeats = allPerformanceScenarioActionPhaseRuns
        .where(
          (run) =>
              run.scenarioGroupId == groupId &&
              run.phaseKey.startsWith('steady.'),
        )
        .take(2)
        .toList();

    expect(repeats, hasLength(2), reason: groupId);

    final controller = PerformanceHostController();
    addTearDown(controller.dispose);

    final first = await _runTracedWithPreparationProbe(
      binding,
      repeats[0],
      host: controller,
    );
    final second = await _runTracedWithPreparationProbe(
      binding,
      repeats[1],
      host: controller,
    );

    _expectEquivalentPreparedState(first, second);
    _expectPreActionPreparedState(second);
    _expectGroupFixtureMetadata(second, _expectedFixtureMetadata[groupId]!);
  }
}

Future<PerformancePhasePreparationSnapshot> _runTracedWithPreparationProbe(
  IntegrationTestWidgetsFlutterBinding binding,
  PerformanceScenarioActionPhaseRun run, {
  required PerformanceHostController host,
}) async {
  final snapshots = <PerformancePhasePreparationSnapshot>[];
  final runnerEvents = <String>[];
  await run.runTraced(
    binding: binding,
    host: host,
    pumpFrame: _pumpNoFrame,
    settle: _settleNoop,
    preparationProbe: (snapshot) {
      runnerEvents.add('preparationProbe');
      snapshots.add(snapshot);
    },
    traceAction: (action, {required reportKey}) async {
      runnerEvents.add('traceAction:$reportKey');
      await action();
      runnerEvents.add('measuredActionComplete');
    },
  );

  expect(snapshots, hasLength(1), reason: run.reportKey);
  expect(runnerEvents, [
    'preparationProbe',
    'traceAction:${run.reportKey}',
    'measuredActionComplete',
  ], reason: run.reportKey);
  return snapshots.single;
}

Future<void> _expectInteractionSetupSeparation() async {
  for (final expectation in _interactionSetupExpectations) {
    final run = allPerformanceScenarioActionPhaseRuns.singleWhere(
      (candidate) =>
          candidate.scenarioGroupId == expectation.scenarioGroup &&
          candidate.phaseKey == expectation.phaseKey,
    );
    final controller = PerformanceHostController();
    addTearDown(controller.dispose);

    await run.phase.action.action(
      PerformanceScenarioContext(host: controller, pumpFrame: _pumpNoFrame),
    );
    await _settleNoop();

    expectation.verify(controller.runtime);
  }
}

Future<void> _pumpNoFrame([Duration duration = Duration.zero]) {
  return Future<void>.value();
}

Future<void> _settleNoop() {
  return Future<void>.value();
}

void _expectEquivalentPreparedState(
  PerformancePhasePreparationSnapshot first,
  PerformancePhasePreparationSnapshot second,
) {
  expect(second.scenarioGroup, first.scenarioGroup);
  expect(second.phaseKey, first.phaseKey);
  expect(first.preparationMeasured, isFalse);
  expect(second.preparationMeasured, isFalse);
  expect(second.canonicalPreparation, first.canonicalPreparation);
  expect(second.resetReason, first.resetReason);
  expect(second.publicState.summary, first.publicState.summary);
  expect(second.documentFingerprint, first.documentFingerprint);
  expect(second.cameraOffset, first.cameraOffset);
  expect(second.toolMode, first.toolMode);
  expect(second.drawTool, first.drawTool);
  expect(second.fixtureMetadata, first.fixtureMetadata);
}

void _expectGroupFixtureMetadata(
  PerformancePhasePreparationSnapshot snapshot,
  Map<String, Object?> expected,
) {
  expect(snapshot.fixtureMetadata, expected, reason: snapshot.scenarioGroup);
}

void _expectPreActionPreparedState(
  PerformancePhasePreparationSnapshot snapshot,
) {
  switch (snapshot.scenarioGroup) {
    case 'load_document.100k':
      _expectLoadDocumentPreAction(snapshot);
    case 'first_canvas_frame.50k':
      _expectFirstCanvasFramePreAction(snapshot);
    case 'camera_pan.100k':
      _expectCameraPanPreAction(snapshot);
    case 'selection_move.50k':
      _expectSelectionMovePreAction(snapshot);
    case 'marquee_select.50k':
      _expectMarqueePreAction(snapshot);
    case 'json_export.50k':
      _expectJsonExportPreAction(snapshot);
    case 'eraser_dense_50k':
      _expectEraserPreAction(snapshot);
    case 'eraser_delete_many.1k':
      _expectEraserDeletionBatchPreAction(snapshot);
    case 'context_request_batch.64':
      _expectContextRequestBatchPreAction(snapshot);
    default:
      fail('Unexpected redesigned group ${snapshot.scenarioGroup}');
  }
}

void _expectLoadDocumentPreAction(
  PerformancePhasePreparationSnapshot snapshot,
) {
  expect(snapshot.publicState.summary.elementCount, 0);
  expect(snapshot.publicState.summary.selectedCount, 0);
}

void _expectFirstCanvasFramePreAction(
  PerformancePhasePreparationSnapshot snapshot,
) {
  expect(snapshot.publicState.summary.elementCount, 50000);
  expect(
    snapshot.fixtureMetadata['surfaceRenderState'],
    'not_rendered_by_measured_surface',
  );
}

void _expectCameraPanPreAction(PerformancePhasePreparationSnapshot snapshot) {
  expect(snapshot.publicState.summary.elementCount, 100000);
  expect(snapshot.cameraOffset, Offset.zero);
}

void _expectSelectionMovePreAction(
  PerformancePhasePreparationSnapshot snapshot,
) {
  expect(snapshot.publicState.summary.elementCount, 50000);
  expect(snapshot.publicState.summary.selectedCount, 1);
  expect(
    snapshot.documentFingerprint,
    encodeCanvasDocumentToJson(performanceRectDocument(50000)),
  );
}

void _expectMarqueePreAction(PerformancePhasePreparationSnapshot snapshot) {
  expect(snapshot.publicState.summary.elementCount, 50000);
  expect(snapshot.publicState.summary.selectedCount, 0);
  expect(snapshot.toolMode, CanvasInteractionMode.move);
}

void _expectJsonExportPreAction(PerformancePhasePreparationSnapshot snapshot) {
  expect(snapshot.publicState.summary.elementCount, 50000);
  expect(snapshot.fixtureMetadata['pendingEditSession'], isFalse);
}

void _expectEraserPreAction(PerformancePhasePreparationSnapshot snapshot) {
  expect(snapshot.publicState.summary.elementCount, 50000);
  expect(snapshot.toolMode, CanvasInteractionMode.draw);
  expect(snapshot.drawTool, CanvasDrawTool.eraser);
}

void _expectEraserDeletionBatchPreAction(
  PerformancePhasePreparationSnapshot snapshot,
) {
  expect(
    snapshot.publicState.summary.elementCount,
    performanceEraserDeletionBatchCount,
  );
  expect(snapshot.toolMode, CanvasInteractionMode.draw);
  expect(snapshot.drawTool, CanvasDrawTool.eraser);
}

void _expectContextRequestBatchPreAction(
  PerformancePhasePreparationSnapshot snapshot,
) {
  expect(snapshot.publicState.summary.elementCount, 0);
  expect(snapshot.toolMode, CanvasInteractionMode.move);
}

const _interactionSetupExpectations = [
  _InteractionSetupExpectation(
    scenarioGroup: 'selection_move.50k',
    phaseKey: 'setup.loaded_selected_document',
    verify: _expectSelectionMoveSetup,
  ),
  _InteractionSetupExpectation(
    scenarioGroup: 'marquee_select.50k',
    phaseKey: 'setup.loaded_document',
    verify: _expectMarqueeSetup,
  ),
  _InteractionSetupExpectation(
    scenarioGroup: 'eraser_dense_50k',
    phaseKey: 'setup.loaded_draw_mode_document',
    verify: _expectEraserSetup,
  ),
  _InteractionSetupExpectation(
    scenarioGroup: 'eraser_delete_many.1k',
    phaseKey: 'setup.loaded_eraser_batch_document',
    verify: _expectEraserDeletionBatchSetup,
  ),
  _InteractionSetupExpectation(
    scenarioGroup: 'context_request_batch.64',
    phaseKey: 'setup.loaded_empty_document',
    verify: _expectContextRequestBatchSetup,
  ),
];

final class _InteractionSetupExpectation {
  const _InteractionSetupExpectation({
    required this.scenarioGroup,
    required this.phaseKey,
    required this.verify,
  });

  final String scenarioGroup;
  final String phaseKey;
  final void Function(CanvasRuntime runtime) verify;
}

void _expectSelectionMoveSetup(CanvasRuntime runtime) {
  expect(runtime.state.value.summary.elementCount, 50000);
  expect(runtime.state.value.summary.selectedCount, 1);
  expect(
    encodeCanvasDocumentToJson(runtime.readDocument()),
    encodeCanvasDocumentToJson(performanceRectDocument(50000)),
  );
}

void _expectMarqueeSetup(CanvasRuntime runtime) {
  expect(runtime.state.value.summary.elementCount, 50000);
  expect(runtime.state.value.summary.selectedCount, 0);
  expect(runtime.tools.mode, CanvasInteractionMode.move);
}

void _expectEraserSetup(CanvasRuntime runtime) {
  expect(runtime.state.value.summary.elementCount, 50000);
  expect(runtime.tools.mode, CanvasInteractionMode.draw);
  expect(runtime.tools.drawStyle.tool, CanvasDrawTool.eraser);
  expect(
    encodeCanvasDocumentToJson(runtime.readDocument()),
    encodeCanvasDocumentToJson(performanceRectDocument(50000)),
  );
}

void _expectEraserDeletionBatchSetup(CanvasRuntime runtime) {
  expect(
    runtime.state.value.summary.elementCount,
    performanceEraserDeletionBatchCount,
  );
  expect(runtime.tools.mode, CanvasInteractionMode.draw);
  expect(runtime.tools.drawStyle.tool, CanvasDrawTool.eraser);
  expect(
    encodeCanvasDocumentToJson(runtime.readDocument()),
    encodeCanvasDocumentToJson(performanceEraserDeletionBatchDocument()),
  );
}

void _expectContextRequestBatchSetup(CanvasRuntime runtime) {
  expect(runtime.state.value.summary.elementCount, 0);
  expect(runtime.tools.mode, CanvasInteractionMode.move);
  expect(
    encodeCanvasDocumentToJson(runtime.readDocument()),
    encodeCanvasDocumentToJson(performanceContextRequestBatchDocument()),
  );
}

Future<
  ({int erasedElementCount, List<CanvasContextActionRequested> contextRequests})
>
_executeBatchWorkloads(IntegrationTestWidgetsFlutterBinding binding) async {
  final eraserController = PerformanceHostController();
  addTearDown(eraserController.dispose);
  await _batchPhaseRun(
    'eraser_delete_many.1k',
    'warm.eraser_delete_many',
  ).runTraced(
    binding: binding,
    host: eraserController,
    pumpFrame: _pumpNoFrame,
    settle: _settleNoop,
    traceAction: (action, {required reportKey}) => action(),
  );
  final erasedElementCount =
      performanceEraserDeletionBatchCount -
      eraserController.runtime.state.value.summary.elementCount;

  final contextController = PerformanceHostController();
  addTearDown(contextController.dispose);
  final contextRequests = <CanvasContextActionRequested>[];
  await _batchPhaseRun(
    'context_request_batch.64',
    'warm.context_request_batch',
  ).runTraced(
    binding: binding,
    host: contextController,
    pumpFrame: _pumpNoFrame,
    settle: _settleNoop,
    traceAction: (action, {required reportKey}) async {
      final subscription = contextController.runtime.contextActionRequests
          .listen(contextRequests.add);
      try {
        await action();
      } finally {
        await subscription.cancel();
      }
    },
  );
  return (
    erasedElementCount: erasedElementCount,
    contextRequests: contextRequests,
  );
}

PerformanceScenarioActionPhaseRun _batchPhaseRun(
  String scenarioGroupId,
  String phaseKey,
) {
  return allPerformanceScenarioActionPhaseRuns.singleWhere(
    (candidate) =>
        candidate.scenarioGroupId == scenarioGroupId &&
        candidate.phaseKey == phaseKey,
  );
}
