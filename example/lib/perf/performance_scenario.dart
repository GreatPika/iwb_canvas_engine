import 'dart:async';
import 'dart:ui';

import 'package:integration_test/integration_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';

import 'performance_fixtures.dart';
import 'performance_host.dart';
import 'performance_scenario_catalog.dart' as catalog;

typedef PerformanceScenarioAction =
    Future<void> Function(PerformanceScenarioContext context);
typedef PerformanceScenarioPreparation =
    Future<PerformancePreparedPhaseAction> Function(
      PerformanceScenarioContext context,
    );

typedef PerformanceScenarioSettle = Future<void> Function();
typedef PerformanceScenarioPumpFrame =
    Future<void> Function([Duration duration]);
typedef PerformancePhasePreparationProbe =
    void Function(PerformancePhasePreparationSnapshot snapshot);
typedef PerformanceScenarioTraceAction =
    Future<void> Function(
      Future<void> Function() action, {
      required String reportKey,
    });
typedef _RedesignedPhaseActions = ({
  PerformanceScenarioActionPlan setup,
  PerformanceScenarioActionPlan warm,
  PerformanceScenarioActionPlan steady,
});
typedef _PointerDragGesture = ({
  Offset from,
  Offset to,
  CanvasDrawTool? drawTool,
  int pointerId,
  bool includeTerminal,
});

const _scenarioFrameStep = Duration(milliseconds: 16);

final class PerformanceScenarioContext {
  const PerformanceScenarioContext({
    required this.host,
    required this.pumpFrame,
  });

  final PerformanceHostController host;
  final PerformanceScenarioPumpFrame pumpFrame;

  CanvasRuntime get runtime => host.runtime;

  Future<void> pumpScenarioFrame([
    Duration duration = _scenarioFrameStep,
  ]) async {
    await pumpFrame(duration);
  }
}

final class PerformanceScenarioActionPlan {
  const PerformanceScenarioActionPlan({
    required this.id,
    required this.action,
    this.afterSettle,
  });

  final String id;
  final PerformanceScenarioAction action;
  final PerformanceScenarioAction? afterSettle;
}

final class PerformancePreparedPhaseAction {
  const PerformancePreparedPhaseAction({
    required this.action,
    required this.fixtureMetadata,
  });

  final PerformanceScenarioAction action;
  final Map<String, Object?> fixtureMetadata;
}

final class PerformanceScenarioActionGroup {
  const PerformanceScenarioActionGroup({
    required this.descriptor,
    required this.phases,
  });

  final catalog.PerformanceScenarioCatalogGroup descriptor;
  final List<PerformanceScenarioActionPhase> phases;

  String get id => descriptor.id;
}

final class PerformanceScenarioActionPhase {
  const PerformanceScenarioActionPhase({
    required this.descriptor,
    required this.action,
    this.prepare,
  });

  final catalog.PerformanceScenarioCatalogPhase descriptor;
  final PerformanceScenarioActionPlan action;
  final PerformanceScenarioPreparation? prepare;

  String get kind => descriptor.kind;
  String get name => descriptor.name;
  String? get canonicalPreparation => descriptor.canonicalPreparation;
  String? get resetReason => descriptor.resetReason;
  String? get measuredAction => descriptor.measuredAction;
}

final class PerformanceScenarioActionPhaseRun {
  const PerformanceScenarioActionPhaseRun({
    required this.descriptor,
    required this.phase,
  });

  final catalog.PerformanceScenarioCatalogRun descriptor;
  final PerformanceScenarioActionPhase phase;

  int get repeat => descriptor.repeat;
  String get reportKey => descriptor.reportKey;
  String get scenarioGroupId => descriptor.scenarioGroupId;
  String get phaseKey => descriptor.phaseKey;

  // Keeping the route dependencies explicit makes the trace boundary easier to
  // audit than hiding binding, host, pumping, settle, and probe in a bag type.
  // ignore: number-of-parameters
  Future<void> runTraced({
    required IntegrationTestWidgetsFlutterBinding binding,
    required PerformanceHostController host,
    required PerformanceScenarioPumpFrame pumpFrame,
    required PerformanceScenarioSettle settle,
    PerformancePhasePreparationProbe? preparationProbe,
    PerformanceScenarioTraceAction? traceAction,
  }) {
    return runPerformanceScenarioActionPhaseTraced(
      PerformanceScenarioActionPhaseTraceRequest(
        binding: binding,
        phaseRun: this,
        host: host,
        pumpFrame: pumpFrame,
        settle: settle,
        preparationProbe: preparationProbe,
        traceAction: traceAction,
      ),
    );
  }
}

final class PerformanceScenarioActionPhaseTraceRequest {
  const PerformanceScenarioActionPhaseTraceRequest({
    required this.binding,
    required this.phaseRun,
    required this.host,
    required this.pumpFrame,
    required this.settle,
    this.preparationProbe,
    this.traceAction,
  });

  final IntegrationTestWidgetsFlutterBinding binding;
  final PerformanceScenarioActionPhaseRun phaseRun;
  final PerformanceHostController host;
  final PerformanceScenarioPumpFrame pumpFrame;
  final PerformanceScenarioSettle settle;
  final PerformancePhasePreparationProbe? preparationProbe;
  final PerformanceScenarioTraceAction? traceAction;
}

final class PerformancePhasePreparationSnapshot {
  const PerformancePhasePreparationSnapshot({
    required this.scenarioGroup,
    required this.phaseKey,
    required this.repeat,
    required this.canonicalPreparation,
    required this.resetReason,
    required this.preparationMeasured,
    required this.publicState,
    required this.documentFingerprint,
    required this.cameraOffset,
    required this.toolMode,
    required this.drawTool,
    required this.fixtureMetadata,
  });

  final String scenarioGroup;
  final String phaseKey;
  final int repeat;
  final String canonicalPreparation;
  final String resetReason;
  final bool preparationMeasured;
  final CanvasRuntimeState publicState;
  final String documentFingerprint;
  final Offset cameraOffset;
  final CanvasInteractionMode toolMode;
  final CanvasDrawTool drawTool;
  final Map<String, Object?> fixtureMetadata;
}

Future<void> runPerformanceScenarioActionPhaseTraced(
  PerformanceScenarioActionPhaseTraceRequest request,
) async {
  final context = PerformanceScenarioContext(
    host: request.host,
    pumpFrame: request.pumpFrame,
  );
  final phase = request.phaseRun.phase;
  final prepared = await _preparePhaseAction(context, phase);
  _capturePreparationSnapshot(
    request: request,
    context: context,
    fixtureMetadata: prepared.fixtureMetadata,
  );
  final traceAction =
      request.traceAction ??
      (Future<void> Function() action, {required String reportKey}) {
        return request.binding.traceAction(action, reportKey: reportKey);
      };
  await traceAction(() async {
    await prepared.action(context);
    await request.settle();
    final afterSettle = phase.action.afterSettle;
    if (afterSettle != null) {
      await afterSettle(context);
      await request.settle();
    }
  }, reportKey: request.phaseRun.reportKey);
}

Future<PerformancePreparedPhaseAction> _preparePhaseAction(
  PerformanceScenarioContext context,
  PerformanceScenarioActionPhase phase,
) async {
  final prepare = phase.prepare;
  if (prepare != null) {
    return prepare(context);
  }
  return PerformancePreparedPhaseAction(
    action: phase.action.action,
    fixtureMetadata: const <String, Object?>{},
  );
}

void _capturePreparationSnapshot({
  required PerformanceScenarioActionPhaseTraceRequest request,
  required PerformanceScenarioContext context,
  required Map<String, Object?> fixtureMetadata,
}) {
  final phase = request.phaseRun.phase;
  final preparationProbe = request.preparationProbe;
  if (preparationProbe == null || phase.prepare == null) {
    return;
  }
  preparationProbe(
    _preparationSnapshot(
      phaseRun: request.phaseRun,
      context: context,
      fixtureMetadata: fixtureMetadata,
    ),
  );
}

PerformancePhasePreparationSnapshot _preparationSnapshot({
  required PerformanceScenarioActionPhaseRun phaseRun,
  required PerformanceScenarioContext context,
  required Map<String, Object?> fixtureMetadata,
}) {
  final phase = phaseRun.phase;
  final canonicalPreparation = phase.canonicalPreparation;
  final resetReason = phase.resetReason;
  if (canonicalPreparation == null || resetReason == null) {
    throw StateError('${phaseRun.reportKey} has no canonical preparation.');
  }
  return PerformancePhasePreparationSnapshot(
    scenarioGroup: phaseRun.scenarioGroupId,
    phaseKey: phaseRun.phaseKey,
    repeat: phaseRun.repeat,
    canonicalPreparation: canonicalPreparation,
    resetReason: resetReason,
    preparationMeasured: false,
    publicState: context.runtime.state.value,
    documentFingerprint: encodeCanvasDocumentToJson(
      context.runtime.readDocument(),
    ),
    cameraOffset: context.runtime.camera.offset,
    toolMode: context.runtime.tools.mode,
    drawTool: context.runtime.tools.drawStyle.tool,
    fixtureMetadata: Map<String, Object?>.unmodifiable(fixtureMetadata),
  );
}

final List<PerformanceScenarioActionGroup> _performanceScenarioActionGroups =
    List<PerformanceScenarioActionGroup>.unmodifiable([
      _redesignedGroup(
        descriptor: _catalogGroup('load_document.100k'),
        actions: (
          setup: _setupLoadDocumentJsonScenario(100000),
          warm: _loadDocumentFromPreparedJsonScenario(),
          steady: _loadDocumentFromPreparedJsonScenario(),
        ),
        prepare: _prepareLoadDocument100k,
      ),
      _redesignedGroup(
        descriptor: _catalogGroup('first_canvas_frame.50k'),
        actions: (
          setup: _firstCanvasFrameSetupScenario(),
          warm: _firstCanvasFrameScenario(),
          steady: _firstCanvasFrameScenario(),
        ),
        prepare: _prepareFirstCanvasFrame50k,
      ),
      _redesignedGroup(
        descriptor: _catalogGroup('camera_pan.100k'),
        actions: (
          setup: _loadDocumentScenario('camera_pan.100k', 100000),
          warm: _cameraPanActionScenario('camera_pan.100k'),
          steady: _cameraPanActionScenario('camera_pan.100k'),
        ),
        prepare: _prepareCameraPan100k,
      ),
      _redesignedGroup(
        descriptor: _catalogGroup('selection_move.50k'),
        actions: (
          setup: _selectionMoveSetupScenario(),
          warm: _selectionMoveActionScenario('selection_move.50k'),
          steady: _selectionMoveActionScenario('selection_move.50k'),
        ),
        prepare: _prepareSelectionMove50k,
      ),
      _redesignedGroup(
        descriptor: _catalogGroup('marquee_select.50k'),
        actions: (
          setup: _marqueeSelectSetupScenario(),
          warm: _marqueeSelectActionScenario(),
          steady: _marqueeSelectActionScenario(),
        ),
        prepare: _prepareMarqueeSelect50k,
      ),
      _redesignedGroup(
        descriptor: _catalogGroup('json_export.50k'),
        actions: (
          setup: _loadDocumentScenario('json_export.50k', 50000),
          warm: _jsonExportActionScenario(),
          steady: _jsonExportActionScenario(),
        ),
        prepare: _prepareJsonExport50k,
      ),
      _redesignedGroup(
        descriptor: _catalogGroup('eraser_dense_50k'),
        actions: (
          setup: _eraserDenseSetupScenario(),
          warm: _eraserDenseActionScenario(),
          steady: _eraserDenseActionScenario(),
        ),
        prepare: _prepareEraserDense50k,
      ),
      _redesignedGroup(
        descriptor: _catalogGroup('eraser_delete_many.1k'),
        actions: (
          setup: _eraserDeletionBatchSetupScenario(),
          warm: _eraserDeletionBatchActionScenario(),
          steady: _eraserDeletionBatchActionScenario(),
        ),
        prepare: _prepareEraserDeletionBatch1k,
      ),
      _redesignedGroup(
        descriptor: _catalogGroup('context_request_batch.64'),
        actions: (
          setup: _contextRequestBatchSetupScenario(),
          warm: _contextRequestBatchActionScenario(),
          steady: _contextRequestBatchActionScenario(),
        ),
        prepare: _prepareContextRequestBatch64,
      ),
      for (final action in _singleCurrentBehaviorActions)
        _singleCurrentBehaviorGroup(action),
    ]);

final List<PerformanceScenarioActionPhaseRun>
allPerformanceScenarioActionPhaseRuns =
    List<PerformanceScenarioActionPhaseRun>.unmodifiable([
      for (final descriptor in catalog.performanceScenarioCatalogRuns)
        PerformanceScenarioActionPhaseRun(
          descriptor: descriptor,
          phase: _actionPhaseForCatalogRun(descriptor),
        ),
    ]);

final List<PerformanceScenarioActionPlan> _singleCurrentBehaviorActions =
    List<PerformanceScenarioActionPlan>.unmodifiable([
      _loadDocumentScenario('load_document.1k', 1000),
      _loadDocumentScenario('load_document.10k', 10000),
      _loadDocumentScenario('load_document.50k', 50000),
      _cameraPanScenario('camera_pan.50k', 50000),
      _selectionTapScenario(),
      _selectionMoveScenario('selection_move.10k', 10000),
      _drawScenario('pencil_draw.10k', CanvasDrawTool.pencil),
      _drawScenario('marker_draw.10k', CanvasDrawTool.marker),
      _lineTwoTapScenario(),
      _drawScenario('eraser_normal.50k', CanvasDrawTool.eraser),
      _contextDeleteScenario(),
      _textEditOpenCommitScenario(),
      _textStyleChangeScenario(),
      _resourceImageScenario('resource_image_cold', 'cold-image'),
      _resourceImageScenario('resource_image_warm', 'warm-image'),
      _resourceMarkDirtyScenario(),
      _missingResourceScenario(),
      _surfaceRuntimeSwapScenario(),
      _disposeDuringPreviewScenario(),
    ]);

PerformanceScenarioActionGroup _redesignedGroup({
  required catalog.PerformanceScenarioCatalogGroup descriptor,
  required _RedesignedPhaseActions actions,
  required PerformanceScenarioPreparation prepare,
}) {
  final phases = descriptor.phases;
  return PerformanceScenarioActionGroup(
    descriptor: descriptor,
    phases: [
      _phase(descriptor: phases[0], action: actions.setup),
      _phase(descriptor: phases[1], action: actions.warm, prepare: prepare),
      _phase(descriptor: phases[2], action: actions.steady, prepare: prepare),
    ],
  );
}

PerformanceScenarioActionPhase _phase({
  required catalog.PerformanceScenarioCatalogPhase descriptor,
  required PerformanceScenarioActionPlan action,
  PerformanceScenarioPreparation? prepare,
}) {
  return PerformanceScenarioActionPhase(
    descriptor: descriptor,
    action: action,
    prepare: prepare,
  );
}

PerformanceScenarioActionGroup _singleCurrentBehaviorGroup(
  PerformanceScenarioActionPlan action,
) {
  final descriptor = _catalogGroup(action.id);
  return PerformanceScenarioActionGroup(
    descriptor: descriptor,
    phases: [_phase(descriptor: descriptor.phases.single, action: action)],
  );
}

PerformanceScenarioActionPhase _actionPhaseForCatalogRun(
  catalog.PerformanceScenarioCatalogRun descriptor,
) {
  final group = _performanceScenarioActionGroups.singleWhere(
    (candidate) => candidate.id == descriptor.scenarioGroupId,
  );
  return group.phases.singleWhere(
    (phase) => phase.descriptor.key == descriptor.phaseKey,
  );
}

catalog.PerformanceScenarioCatalogGroup _catalogGroup(String id) {
  return catalog.performanceScenarioCatalogGroups.singleWhere(
    (group) => group.id == id,
  );
}

PerformanceScenarioActionPlan _loadDocumentScenario(
  String id,
  int elementCount,
) {
  return PerformanceScenarioActionPlan(
    id: id,
    action: (context) async {
      context.runtime.edits.loadDocumentFromJson(
        performanceFixtureJson(performanceRectDocument(elementCount)),
      );
      await context.pumpScenarioFrame();
    },
  );
}

PerformanceScenarioActionPlan _setupLoadDocumentJsonScenario(int elementCount) {
  return PerformanceScenarioActionPlan(
    id: 'setup.fixture_json',
    action: (context) async {
      final json = performanceFixtureJson(
        performanceRectDocument(elementCount),
      );
      if (json.isEmpty) {
        throw StateError('setup.fixture_json produced an empty fixture.');
      }
      await context.pumpScenarioFrame();
    },
  );
}

PerformanceScenarioActionPlan _loadDocumentFromPreparedJsonScenario() {
  return PerformanceScenarioActionPlan(
    id: 'warm.load_document',
    action: (context) async {
      context.runtime.edits.loadDocumentFromJson(
        performanceFixtureJson(performanceRectDocument(100000)),
      );
      await context.pumpScenarioFrame();
    },
  );
}

PerformanceScenarioActionPlan _cameraPanScenario(String id, int elementCount) {
  return PerformanceScenarioActionPlan(
    id: id,
    action: (context) async {
      _loadDocument(context.runtime, performanceRectDocument(elementCount));
      await context.pumpScenarioFrame();
      await _panCamera(context);
    },
  );
}

PerformanceScenarioActionPlan _cameraPanActionScenario(String id) {
  return PerformanceScenarioActionPlan(id: id, action: _panCamera);
}

Future<void> _panCamera(PerformanceScenarioContext context) async {
  for (var index = 0; index < 12; index += 1) {
    context.runtime.camera.panBy(Offset(8 + index.toDouble(), 4));
    await context.pumpScenarioFrame();
  }
}

PerformanceScenarioActionPlan _selectionTapScenario() {
  return PerformanceScenarioActionPlan(
    id: 'selection_tap.10k',
    action: (context) async {
      _loadDocument(context.runtime, performanceRectDocument(10000));
      await context.pumpScenarioFrame();
      context.runtime.selection.setSelection([
        CanvasElementId(performancePrimaryRectId),
      ]);
      await context.pumpScenarioFrame();
    },
  );
}

PerformanceScenarioActionPlan _selectionMoveScenario(
  String id,
  int elementCount,
) {
  return PerformanceScenarioActionPlan(
    id: id,
    action: (context) async {
      _loadDocument(context.runtime, performanceRectDocument(elementCount));
      await context.pumpScenarioFrame();
      context.runtime.selection.setSelection([
        CanvasElementId(performancePrimaryRectId),
      ]);
      await context.pumpScenarioFrame();
      await _moveSelection(context);
    },
  );
}

PerformanceScenarioActionPlan _selectionMoveSetupScenario() {
  return PerformanceScenarioActionPlan(
    id: 'selection_move.50k',
    action: (context) async {
      _loadDocument(context.runtime, performanceRectDocument(50000));
      await context.pumpScenarioFrame();
      context.runtime.selection.setSelection([
        CanvasElementId(performancePrimaryRectId),
      ]);
      await context.pumpScenarioFrame();
    },
  );
}

PerformanceScenarioActionPlan _selectionMoveActionScenario(String id) {
  return PerformanceScenarioActionPlan(id: id, action: _moveSelection);
}

Future<void> _moveSelection(PerformanceScenarioContext context) async {
  context.runtime.selection.moveSelection(
    const Offset(16, 12),
    timestampMs: 20,
  );
  await context.pumpScenarioFrame();
}

PerformanceScenarioActionPlan _marqueeSelectSetupScenario() {
  return PerformanceScenarioActionPlan(
    id: 'marquee_select.50k',
    action: (context) async {
      _loadDocument(context.runtime, performanceRectDocument(50000));
      context.runtime.selection.clearSelection();
      context.runtime.tools.setMode(CanvasInteractionMode.move);
      await context.pumpScenarioFrame();
    },
  );
}

PerformanceScenarioActionPlan _marqueeSelectActionScenario() {
  return const PerformanceScenarioActionPlan(
    id: 'marquee_select.50k',
    action: _dragMarquee,
  );
}

Future<void> _dragMarquee(PerformanceScenarioContext context) {
  return _pointerDrag(context, (
    from: const Offset(0, 0),
    to: const Offset(180, 180),
    drawTool: null,
    pointerId: 1,
    includeTerminal: true,
  ), configureTool: false);
}

PerformanceScenarioActionPlan _drawScenario(
  String id,
  CanvasDrawTool drawTool,
) {
  final count = id.endsWith('.10k') ? 10000 : 50000;

  return PerformanceScenarioActionPlan(
    id: id,
    action: (context) async {
      _loadDocument(context.runtime, performanceRectDocument(count));
      await context.pumpScenarioFrame();
      await _pointerDrag(context, (
        from: const Offset(10, 10),
        to: const Offset(130, 40),
        drawTool: drawTool,
        pointerId: 1,
        includeTerminal: true,
      ));
    },
  );
}

PerformanceScenarioActionPlan _eraserDenseSetupScenario() {
  return PerformanceScenarioActionPlan(
    id: 'eraser_dense_50k',
    action: (context) async {
      _loadDocument(context.runtime, performanceRectDocument(50000));
      context.runtime.tools
        ..setMode(CanvasInteractionMode.draw)
        ..setDrawTool(CanvasDrawTool.eraser);
      await context.pumpScenarioFrame();
    },
  );
}

PerformanceScenarioActionPlan _eraserDenseActionScenario() {
  return PerformanceScenarioActionPlan(
    id: 'eraser_dense_50k',
    action: (context) {
      return _pointerDrag(context, (
        from: const Offset(10, 10),
        to: const Offset(130, 40),
        drawTool: CanvasDrawTool.eraser,
        pointerId: 1,
        includeTerminal: true,
      ), configureTool: false);
    },
  );
}

PerformanceScenarioActionPlan _eraserDeletionBatchSetupScenario() {
  return const PerformanceScenarioActionPlan(
    id: 'eraser_delete_many.1k',
    action: _loadEraserDeletionBatchDocument,
  );
}

PerformanceScenarioActionPlan _eraserDeletionBatchActionScenario() {
  return PerformanceScenarioActionPlan(
    id: 'eraser_delete_many.1k',
    action: (context) => _pointerDrag(context, (
      from: const Offset(20, 24),
      to: const Offset(108, 24),
      drawTool: CanvasDrawTool.eraser,
      pointerId: 1,
      includeTerminal: true,
    ), configureTool: false),
  );
}

PerformanceScenarioActionPlan _contextRequestBatchSetupScenario() {
  return const PerformanceScenarioActionPlan(
    id: 'context_request_batch.64',
    action: _loadContextRequestBatchDocument,
  );
}

PerformanceScenarioActionPlan _contextRequestBatchActionScenario() {
  return const PerformanceScenarioActionPlan(
    id: 'context_request_batch.64',
    action: _dispatchContextRequestBatch,
  );
}

PerformanceScenarioActionPlan _lineTwoTapScenario() {
  return PerformanceScenarioActionPlan(
    id: 'line_two_tap.50k',
    action: (context) async {
      _loadDocument(context.runtime, performanceRectDocument(50000));
      await context.pumpScenarioFrame();
      context.runtime.tools
        ..setMode(CanvasInteractionMode.draw)
        ..setDrawTool(CanvasDrawTool.line);
      for (final sample in [
        _pointer(1, CanvasPointerLifecyclePhase.down, const Offset(20, 20), 10),
        _pointer(1, CanvasPointerLifecyclePhase.up, const Offset(20, 20), 18),
        _pointer(
          2,
          CanvasPointerLifecyclePhase.down,
          const Offset(140, 80),
          40,
        ),
        _pointer(2, CanvasPointerLifecyclePhase.up, const Offset(140, 80), 48),
      ]) {
        context.runtime.tools.handlePointer(sample);
        await context.pumpScenarioFrame();
      }
    },
  );
}

PerformanceScenarioActionPlan _contextDeleteScenario() {
  return PerformanceScenarioActionPlan(
    id: 'context_delete.10k',
    action: (context) async {
      _loadDocument(context.runtime, performanceRectDocument(10000));
      await context.pumpScenarioFrame();
      context.runtime.selection.setSelection([
        CanvasElementId(performancePrimaryRectId),
      ]);
      await context.pumpScenarioFrame();
      context.runtime.selection.deleteSelection(timestampMs: 30);
      await context.pumpScenarioFrame();
    },
  );
}

PerformanceScenarioActionPlan _textEditOpenCommitScenario() {
  final requests = <CanvasContextActionRequested>[];
  StreamSubscription<CanvasContextActionRequested>? subscription;

  return PerformanceScenarioActionPlan(
    id: 'text_edit.open_commit',
    action: (context) async {
      _loadDocument(context.runtime, createPerformanceHostSmokeDocument());
      await context.pumpScenarioFrame();
      context.runtime.camera.setOffset(Offset.zero);
      context.runtime.tools.setMode(CanvasInteractionMode.move);
      subscription = context.runtime.contextActionRequests.listen(requests.add);
      context.runtime.tools.handleDoubleTap(
        position: const Offset(8, 40),
        timestampMs: 40,
      );
      await context.pumpScenarioFrame();
    },
    afterSettle: (context) async {
      await _commitTextEditRequest(context, requests, subscription);
    },
  );
}

PerformanceScenarioActionPlan _textStyleChangeScenario() {
  return PerformanceScenarioActionPlan(
    id: 'text_style_change.10k',
    action: (context) async {
      _loadDocument(context.runtime, performanceTextDocument(rectCount: 9999));
      await context.pumpScenarioFrame();
      context.runtime.edits.edit((edit) {
        edit.updateElement(
          CanvasTextElementUpdate(
            id: CanvasElementId(performancePrimaryTextId),
            isBold: const CanvasFieldSet(true),
            isItalic: const CanvasFieldSet(true),
            isUnderline: const CanvasFieldSet(true),
            color: const CanvasFieldSet(Color(0xFF00695C)),
            fontSize: const CanvasFieldSet(28),
          ),
        );
      });
      await context.pumpScenarioFrame();
    },
  );
}

PerformanceScenarioActionPlan _resourceImageScenario(String id, String appKey) {
  return PerformanceScenarioActionPlan(
    id: id,
    action: (context) async {
      _loadDocument(
        context.runtime,
        performanceResourceDocument(
          resourceId: performancePrimaryResourceId,
          appKey: appKey,
        ),
      );
      await context.pumpScenarioFrame();
      context.runtime.resources.markAllResourcesDirty();
      await context.pumpScenarioFrame();
    },
  );
}

PerformanceScenarioActionPlan _resourceMarkDirtyScenario() {
  return PerformanceScenarioActionPlan(
    id: 'resource_mark_dirty',
    action: (context) async {
      _loadDocument(
        context.runtime,
        performanceResourceDocument(
          resourceId: performancePrimaryResourceId,
          appKey: 'dirty-image',
        ),
      );
      await context.pumpScenarioFrame();
      context.runtime.resources.markResourceDirty(
        CanvasResourceId(performancePrimaryResourceId),
      );
      await context.pumpScenarioFrame();
    },
  );
}

PerformanceScenarioActionPlan _missingResourceScenario() {
  return PerformanceScenarioActionPlan(
    id: 'missing_resource',
    action: (context) async {
      _loadDocument(context.runtime, performanceMissingResourceDocument());
      await context.pumpScenarioFrame();
      context.runtime.resources.markAllResourcesDirty();
      await context.pumpScenarioFrame();
    },
  );
}

PerformanceScenarioActionPlan _surfaceRuntimeSwapScenario() {
  return PerformanceScenarioActionPlan(
    id: 'surface_runtime_swap',
    action: (context) async {
      final replacement = CanvasRuntime(config: _acceptDeletionRuntimeConfig());
      _loadDocument(replacement, performanceRectDocument(1000));
      context.host.swapRuntime(replacement);
      await context.pumpScenarioFrame();
    },
  );
}

PerformanceScenarioActionPlan _disposeDuringPreviewScenario() {
  return PerformanceScenarioActionPlan(
    id: 'dispose_during_preview',
    action: (context) async {
      _loadDocument(context.runtime, performanceRectDocument(1000));
      await context.pumpScenarioFrame();
      await _pointerDrag(context, (
        from: const Offset(10, 10),
        to: const Offset(90, 30),
        drawTool: CanvasDrawTool.pencil,
        pointerId: 1,
        includeTerminal: false,
      ));
      final replacement = CanvasRuntime(config: _acceptDeletionRuntimeConfig());
      _loadDocument(replacement, performanceRectDocument(1000));
      context.host.swapRuntime(replacement);
      await context.pumpScenarioFrame();
    },
  );
}

Future<void> _commitTextEditRequest(
  PerformanceScenarioContext context,
  List<CanvasContextActionRequested> requests,
  StreamSubscription<CanvasContextActionRequested>? subscription,
) async {
  await subscription?.cancel();
  if (requests.isEmpty) {
    throw StateError('text_edit.open_commit did not request editing.');
  }
  final session =
      context.runtime.textEditing.activeSession.value ??
      context.runtime.textEditing.startFromContextAction(requests.single);
  if (session == null) {
    throw StateError('text_edit.open_commit was not admitted.');
  }
  session.commit(timestampMs: 44);
  await context.pumpScenarioFrame();
}

PerformanceScenarioActionPlan _jsonExportActionScenario() {
  return PerformanceScenarioActionPlan(
    id: 'json_export.50k',
    action: (context) async {
      final json = context.runtime.edits.edit((edit) {
        return performanceFixtureJson(edit.readDraftDocument());
      });
      if (json.isEmpty) {
        throw StateError('json_export.50k produced an empty document.');
      }
      await context.pumpScenarioFrame();
    },
  );
}

PerformanceScenarioActionPlan _firstCanvasFrameSetupScenario() {
  return PerformanceScenarioActionPlan(
    id: 'first_canvas_frame.50k',
    action: (context) async {
      _loadDocument(context.runtime, performanceRectDocument(50000));
      await context.pumpScenarioFrame();
    },
  );
}

PerformanceScenarioActionPlan _firstCanvasFrameScenario() {
  return PerformanceScenarioActionPlan(
    id: 'first_canvas_frame.50k',
    action: (context) async {
      await context.pumpScenarioFrame();
    },
  );
}

Future<PerformancePreparedPhaseAction> _prepareLoadDocument100k(
  PerformanceScenarioContext context,
) async {
  context.host.swapRuntime(
    CanvasRuntime(config: _acceptDeletionRuntimeConfig()),
  );
  await context.pumpScenarioFrame();
  final preparedJson = performanceFixtureJson(performanceRectDocument(100000));
  return PerformancePreparedPhaseAction(
    action: (actionContext) async {
      actionContext.runtime.edits.loadDocumentFromJson(preparedJson);
      await actionContext.pumpScenarioFrame();
    },
    fixtureMetadata: {
      'preparedJsonElementCount': 100000,
      'targetElementCountBeforeAction': 0,
      'targetSelectedCountBeforeAction': 0,
    },
  );
}

Future<PerformancePreparedPhaseAction> _prepareFirstCanvasFrame50k(
  PerformanceScenarioContext context,
) async {
  final runtime = CanvasRuntime(config: _acceptDeletionRuntimeConfig());
  _loadDocument(runtime, performanceRectDocument(50000));
  context.host.swapRuntime(runtime);
  return PerformancePreparedPhaseAction(
    action: _firstCanvasFrameScenario().action,
    fixtureMetadata: {
      'loadedElementCount': 50000,
      'surfaceRenderState': 'not_rendered_by_measured_surface',
    },
  );
}

Future<PerformancePreparedPhaseAction> _prepareCameraPan100k(
  PerformanceScenarioContext context,
) async {
  _loadDocument(context.runtime, performanceRectDocument(100000));
  context.runtime.camera.setOffset(Offset.zero);
  await context.pumpScenarioFrame();
  return const PerformancePreparedPhaseAction(
    action: _panCamera,
    fixtureMetadata: {
      'loadedElementCount': 100000,
      'cameraOffsetBeforeAction': Offset.zero,
    },
  );
}

Future<PerformancePreparedPhaseAction> _prepareSelectionMove50k(
  PerformanceScenarioContext context,
) async {
  _loadDocument(context.runtime, performanceRectDocument(50000));
  context.runtime.selection.setSelection([
    CanvasElementId(performancePrimaryRectId),
  ]);
  await context.pumpScenarioFrame();
  return const PerformancePreparedPhaseAction(
    action: _moveSelection,
    fixtureMetadata: {
      'loadedElementCount': 50000,
      'selectedElementId': performancePrimaryRectId,
      'selectedElementGeometry': 'original',
    },
  );
}

Future<PerformancePreparedPhaseAction> _prepareMarqueeSelect50k(
  PerformanceScenarioContext context,
) async {
  _loadDocument(context.runtime, performanceRectDocument(50000));
  context.runtime.selection.clearSelection();
  context.runtime.tools.setMode(CanvasInteractionMode.move);
  await context.pumpScenarioFrame();
  return const PerformancePreparedPhaseAction(
    action: _dragMarquee,
    fixtureMetadata: {
      'loadedElementCount': 50000,
      'selectedCountBeforeAction': 0,
      'toolModeBeforeAction': 'move',
    },
  );
}

Future<PerformancePreparedPhaseAction> _prepareJsonExport50k(
  PerformanceScenarioContext context,
) async {
  _loadDocument(context.runtime, performanceRectDocument(50000));
  await context.pumpScenarioFrame();
  return PerformancePreparedPhaseAction(
    action: _jsonExportActionScenario().action,
    fixtureMetadata: const {
      'loadedElementCount': 50000,
      'documentOrder': 'stable',
      'pendingEditSession': false,
    },
  );
}

Future<PerformancePreparedPhaseAction> _prepareEraserDense50k(
  PerformanceScenarioContext context,
) async {
  _loadDocument(context.runtime, performanceRectDocument(50000));
  context.runtime.tools
    ..setMode(CanvasInteractionMode.draw)
    ..setDrawTool(CanvasDrawTool.eraser);
  await context.pumpScenarioFrame();
  return PerformancePreparedPhaseAction(
    action: _eraserDenseActionScenario().action,
    fixtureMetadata: const {
      'loadedElementCount': 50000,
      'toolModeBeforeAction': 'draw',
      'drawToolBeforeAction': 'eraser',
      'erasedElementCountBeforeAction': 0,
    },
  );
}

Future<PerformancePreparedPhaseAction> _prepareEraserDeletionBatch1k(
  PerformanceScenarioContext context,
) async {
  await _loadEraserDeletionBatchDocument(context);
  return PerformancePreparedPhaseAction(
    action: _eraserDeletionBatchActionScenario().action,
    fixtureMetadata: const {
      'loadedElementCount': performanceEraserDeletionBatchCount,
      'expectedErasedElementCount': performanceEraserDeletionBatchCount,
      'toolModeBeforeAction': 'draw',
      'drawToolBeforeAction': 'eraser',
    },
  );
}

Future<PerformancePreparedPhaseAction> _prepareContextRequestBatch64(
  PerformanceScenarioContext context,
) async {
  await _loadContextRequestBatchDocument(context);
  return PerformancePreparedPhaseAction(
    action: _contextRequestBatchActionScenario().action,
    fixtureMetadata: const {
      'loadedElementCount': 0,
      'contextRequestBatchCount': performanceContextRequestBatchCount,
      'toolModeBeforeAction': 'move',
    },
  );
}

Future<void> _loadEraserDeletionBatchDocument(
  PerformanceScenarioContext context,
) async {
  _loadDocument(context.runtime, performanceEraserDeletionBatchDocument());
  context.runtime.tools
    ..setMode(CanvasInteractionMode.draw)
    ..setDrawTool(CanvasDrawTool.eraser);
  await context.pumpScenarioFrame();
}

Future<void> _loadContextRequestBatchDocument(
  PerformanceScenarioContext context,
) async {
  _loadDocument(context.runtime, performanceContextRequestBatchDocument());
  context.runtime.tools.setMode(CanvasInteractionMode.move);
  await context.pumpScenarioFrame();
}

Future<void> _dispatchContextRequestBatch(
  PerformanceScenarioContext context,
) async {
  final requests = <CanvasContextActionRequested>[];
  final delivered = Completer<void>();
  var yieldedDuringDispatch = false;
  final subscription = context.runtime.contextActionRequests.listen((request) {
    requests.add(request);
    if (requests.length == performanceContextRequestBatchCount) {
      delivered.complete();
    }
  });
  try {
    scheduleMicrotask(() {
      yieldedDuringDispatch = true;
    });
    for (
      var index = 0;
      index < performanceContextRequestBatchCount;
      index += 1
    ) {
      context.runtime.tools.handleDoubleTap(
        position: const Offset(200, 200),
        timestampMs: index,
      );
    }
    if (yieldedDuringDispatch) {
      throw StateError('context request batch yielded during dispatch');
    }
    await context.pumpScenarioFrame();
    await delivered.future;
    if (requests.length != performanceContextRequestBatchCount) {
      throw StateError('context request batch delivery was incomplete');
    }
  } finally {
    await subscription.cancel();
  }
}

void _loadDocument(CanvasRuntime runtime, CanvasDocument document) {
  runtime.edits.edit((edit) {
    edit.replaceDraftDocument(document);
  });
}

Future<void> _pointerDrag(
  PerformanceScenarioContext context,
  _PointerDragGesture gesture, {
  bool configureTool = true,
}) async {
  final runtime = context.runtime;
  final drawTool = gesture.drawTool;
  if (configureTool) {
    if (drawTool == null) {
      runtime.tools.setMode(CanvasInteractionMode.move);
    } else {
      runtime.tools
        ..setMode(CanvasInteractionMode.draw)
        ..setDrawTool(drawTool);
    }
  }

  final samples = [
    _pointer(
      gesture.pointerId,
      CanvasPointerLifecyclePhase.down,
      gesture.from,
      10,
    ),
    _pointer(
      gesture.pointerId,
      CanvasPointerLifecyclePhase.move,
      _midpoint(gesture.from, gesture.to),
      18,
    ),
    if (gesture.includeTerminal)
      _pointer(
        gesture.pointerId,
        CanvasPointerLifecyclePhase.up,
        gesture.to,
        34,
      ),
  ];
  for (final sample in samples) {
    runtime.tools.handlePointer(sample);
    await context.pumpScenarioFrame();
  }
}

Offset _midpoint(Offset from, Offset to) {
  return Offset((from.dx + to.dx) / 2, (from.dy + to.dy) / 2);
}

CanvasPointerSample _pointer(
  int pointerId,
  CanvasPointerLifecyclePhase phase,
  Offset position,
  int timestampMs,
) {
  return CanvasPointerSample(
    pointerId: pointerId,
    position: position,
    phase: phase,
    kind: PointerDeviceKind.touch,
    timestampMs: timestampMs,
  );
}

const _scenarioCommitLease = _ScenarioCommitLease();

CanvasCommitResolution _acceptScenarioCommit(CanvasCommitRequest request) =>
    switch (request) {
      CanvasMoveCommitRequest(:final proposedDelta) => CanvasMoveCommitAccept(
        delta: proposedDelta,
        lease: _scenarioCommitLease,
      ),
      _ => const CanvasCommitAccept(lease: _scenarioCommitLease),
    };

CanvasRuntimeConfig _acceptDeletionRuntimeConfig() =>
    const CanvasRuntimeConfig(commitResolver: _acceptScenarioCommit);

final class _ScenarioCommitLease implements CanvasCommitLease {
  const _ScenarioCommitLease();

  @override
  void aborted() => _ignoreLeaseOutcome();

  @override
  void committed() => _ignoreLeaseOutcome();
}

void _ignoreLeaseOutcome() => Object.hash(null, null);
