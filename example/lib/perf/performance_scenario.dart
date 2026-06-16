import 'dart:async';
import 'dart:ui';

import 'package:integration_test/integration_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';

import 'performance_fixtures.dart';
import 'performance_host.dart';

typedef PerformanceScenarioAction =
    Future<void> Function(PerformanceScenarioContext context);

typedef PerformanceScenarioSettle = Future<void> Function();
typedef PerformanceScenarioPumpFrame =
    Future<void> Function([Duration duration]);
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

final class PerformanceScenario {
  const PerformanceScenario({
    required this.id,
    required this.action,
    this.afterSettle,
  });

  final String id;
  final PerformanceScenarioAction action;
  final PerformanceScenarioAction? afterSettle;

  Future<void> runTraced({
    required IntegrationTestWidgetsFlutterBinding binding,
    required PerformanceHostController host,
    required PerformanceScenarioPumpFrame pumpFrame,
    required PerformanceScenarioSettle settle,
  }) {
    return runPerformanceScenarioTraced(
      PerformanceScenarioTraceRequest(
        binding: binding,
        scenario: this,
        host: host,
        pumpFrame: pumpFrame,
        settle: settle,
      ),
    );
  }
}

final class PerformanceScenarioTraceRequest {
  const PerformanceScenarioTraceRequest({
    required this.binding,
    required this.scenario,
    required this.host,
    required this.pumpFrame,
    required this.settle,
  });

  final IntegrationTestWidgetsFlutterBinding binding;
  final PerformanceScenario scenario;
  final PerformanceHostController host;
  final PerformanceScenarioPumpFrame pumpFrame;
  final PerformanceScenarioSettle settle;
}

Future<void> runPerformanceScenarioTraced(
  PerformanceScenarioTraceRequest request,
) {
  final context = PerformanceScenarioContext(
    host: request.host,
    pumpFrame: request.pumpFrame,
  );
  return request.binding.traceAction(() async {
    await request.scenario.action(context);
    await request.settle();
    final afterSettle = request.scenario.afterSettle;
    if (afterSettle != null) {
      await afterSettle(context);
      await request.settle();
    }
  }, reportKey: request.scenario.id);
}

final List<PerformanceScenario> allPerformanceScenarios =
    List<PerformanceScenario>.unmodifiable([
      _loadDocumentScenario('load_document.1k', 1000),
      _loadDocumentScenario('load_document.10k', 10000),
      _loadDocumentScenario('load_document.50k', 50000),
      _loadDocumentScenario('load_document.100k', 100000),
      _loadDocumentScenario('first_canvas_frame.50k', 50000),
      _cameraPanScenario('camera_pan.50k', 50000),
      _cameraPanScenario('camera_pan.100k', 100000),
      _selectionTapScenario(),
      _selectionMoveScenario('selection_move.10k', 10000),
      _selectionMoveScenario('selection_move.50k', 50000),
      _marqueeSelectScenario(),
      _drawScenario('pencil_draw.10k', CanvasDrawTool.pencil),
      _drawScenario('marker_draw.10k', CanvasDrawTool.marker),
      _lineTwoTapScenario(),
      _drawScenario('eraser_normal.50k', CanvasDrawTool.eraser),
      _drawScenario('eraser_dense_50k', CanvasDrawTool.eraser),
      _contextDeleteScenario(),
      _textEditOpenCommitScenario(),
      _textStyleChangeScenario(),
      _resourceImageScenario('resource_image_cold', 'cold-image'),
      _resourceImageScenario('resource_image_warm', 'warm-image'),
      _resourceMarkDirtyScenario(),
      _missingResourceScenario(),
      _surfaceRuntimeSwapScenario(),
      _disposeDuringPreviewScenario(),
      _jsonExportScenario(),
    ]);

PerformanceScenario _loadDocumentScenario(String id, int elementCount) {
  return PerformanceScenario(
    id: id,
    action: (context) async {
      context.runtime.edits.loadDocumentFromJson(
        performanceFixtureJson(performanceRectDocument(elementCount)),
      );
      await context.pumpScenarioFrame();
    },
  );
}

PerformanceScenario _cameraPanScenario(String id, int elementCount) {
  return PerformanceScenario(
    id: id,
    action: (context) async {
      _loadDocument(context.runtime, performanceRectDocument(elementCount));
      await context.pumpScenarioFrame();
      for (var index = 0; index < 12; index += 1) {
        context.runtime.camera.panBy(Offset(8 + index.toDouble(), 4));
        await context.pumpScenarioFrame();
      }
    },
  );
}

PerformanceScenario _selectionTapScenario() {
  return PerformanceScenario(
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

PerformanceScenario _selectionMoveScenario(String id, int elementCount) {
  return PerformanceScenario(
    id: id,
    action: (context) async {
      _loadDocument(context.runtime, performanceRectDocument(elementCount));
      await context.pumpScenarioFrame();
      context.runtime.selection.setSelection([
        CanvasElementId(performancePrimaryRectId),
      ]);
      await context.pumpScenarioFrame();
      context.runtime.selection.moveSelection(
        const Offset(16, 12),
        timestampMs: 20,
      );
      await context.pumpScenarioFrame();
    },
  );
}

PerformanceScenario _marqueeSelectScenario() {
  return PerformanceScenario(
    id: 'marquee_select.50k',
    action: (context) async {
      _loadDocument(context.runtime, performanceRectDocument(50000));
      await context.pumpScenarioFrame();
      await _pointerDrag(context, (
        from: const Offset(0, 0),
        to: const Offset(180, 180),
        drawTool: null,
        pointerId: 1,
        includeTerminal: true,
      ));
    },
  );
}

PerformanceScenario _drawScenario(String id, CanvasDrawTool drawTool) {
  final count = id.endsWith('.10k') ? 10000 : 50000;

  return PerformanceScenario(
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

PerformanceScenario _lineTwoTapScenario() {
  return PerformanceScenario(
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

PerformanceScenario _contextDeleteScenario() {
  return PerformanceScenario(
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

PerformanceScenario _textEditOpenCommitScenario() {
  final requests = <CanvasContextActionRequested>[];
  StreamSubscription<CanvasContextActionRequested>? subscription;

  return PerformanceScenario(
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

PerformanceScenario _textStyleChangeScenario() {
  return PerformanceScenario(
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

PerformanceScenario _resourceImageScenario(String id, String appKey) {
  return PerformanceScenario(
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

PerformanceScenario _resourceMarkDirtyScenario() {
  return PerformanceScenario(
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

PerformanceScenario _missingResourceScenario() {
  return PerformanceScenario(
    id: 'missing_resource',
    action: (context) async {
      _loadDocument(context.runtime, performanceMissingResourceDocument());
      await context.pumpScenarioFrame();
      context.runtime.resources.markAllResourcesDirty();
      await context.pumpScenarioFrame();
    },
  );
}

PerformanceScenario _surfaceRuntimeSwapScenario() {
  return PerformanceScenario(
    id: 'surface_runtime_swap',
    action: (context) async {
      final replacement = CanvasRuntime();
      _loadDocument(replacement, performanceRectDocument(1000));
      context.host.swapRuntime(replacement);
      await context.pumpScenarioFrame();
    },
  );
}

PerformanceScenario _disposeDuringPreviewScenario() {
  return PerformanceScenario(
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
      final replacement = CanvasRuntime();
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

PerformanceScenario _jsonExportScenario() {
  return PerformanceScenario(
    id: 'json_export.50k',
    action: (context) async {
      _loadDocument(context.runtime, performanceRectDocument(50000));
      await context.pumpScenarioFrame();
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

void _loadDocument(CanvasRuntime runtime, CanvasDocument document) {
  runtime.edits.edit((edit) {
    edit.replaceDraftDocument(document);
  });
}

Future<void> _pointerDrag(
  PerformanceScenarioContext context,
  _PointerDragGesture gesture,
) async {
  final runtime = context.runtime;
  final drawTool = gesture.drawTool;
  if (drawTool == null) {
    runtime.tools.setMode(CanvasInteractionMode.move);
  } else {
    runtime.tools
      ..setMode(CanvasInteractionMode.draw)
      ..setDrawTool(drawTool);
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
