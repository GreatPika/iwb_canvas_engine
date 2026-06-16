import 'dart:async';
import 'dart:ui';

import 'package:integration_test/integration_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';

import 'performance_fixtures.dart';
import 'performance_host.dart';

typedef PerformanceScenarioAction =
    Future<void> Function(PerformanceHostController host);

typedef PerformanceScenarioSettle = Future<void> Function();
typedef _PointerDragGesture = ({
  Offset from,
  Offset to,
  CanvasDrawTool? drawTool,
  int pointerId,
  bool includeTerminal,
});

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
    required PerformanceScenarioSettle settle,
  }) {
    return runPerformanceScenarioTraced(
      binding: binding,
      scenario: this,
      host: host,
      settle: settle,
    );
  }
}

Future<void> runPerformanceScenarioTraced({
  required IntegrationTestWidgetsFlutterBinding binding,
  required PerformanceScenario scenario,
  required PerformanceHostController host,
  required PerformanceScenarioSettle settle,
}) {
  return binding.traceAction(() async {
    await scenario.action(host);
    await settle();
    final afterSettle = scenario.afterSettle;
    if (afterSettle != null) {
      await afterSettle(host);
      await settle();
    }
  }, reportKey: scenario.id);
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
    action: (host) async {
      host.runtime.edits.loadDocumentFromJson(
        performanceFixtureJson(performanceRectDocument(elementCount)),
      );
    },
  );
}

PerformanceScenario _cameraPanScenario(String id, int elementCount) {
  return PerformanceScenario(
    id: id,
    action: (host) async {
      _loadDocument(host.runtime, performanceRectDocument(elementCount));
      for (var index = 0; index < 12; index += 1) {
        host.runtime.camera.panBy(Offset(8 + index.toDouble(), 4));
      }
    },
  );
}

PerformanceScenario _selectionTapScenario() {
  return PerformanceScenario(
    id: 'selection_tap.10k',
    action: (host) async {
      _loadDocument(host.runtime, performanceRectDocument(10000));
      host.runtime.selection.setSelection([
        CanvasElementId(performancePrimaryRectId),
      ]);
    },
  );
}

PerformanceScenario _selectionMoveScenario(String id, int elementCount) {
  return PerformanceScenario(
    id: id,
    action: (host) async {
      _loadDocument(host.runtime, performanceRectDocument(elementCount));
      host.runtime.selection.setSelection([
        CanvasElementId(performancePrimaryRectId),
      ]);
      host.runtime.selection.moveSelection(
        const Offset(16, 12),
        timestampMs: 20,
      );
    },
  );
}

PerformanceScenario _marqueeSelectScenario() {
  return PerformanceScenario(
    id: 'marquee_select.50k',
    action: (host) async {
      _loadDocument(host.runtime, performanceRectDocument(50000));
      _pointerDrag(host.runtime, (
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
    action: (host) async {
      _loadDocument(host.runtime, performanceRectDocument(count));
      _pointerDrag(host.runtime, (
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
    action: (host) async {
      _loadDocument(host.runtime, performanceRectDocument(50000));
      host.runtime.tools
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
        host.runtime.tools.handlePointer(sample);
      }
    },
  );
}

PerformanceScenario _contextDeleteScenario() {
  return PerformanceScenario(
    id: 'context_delete.10k',
    action: (host) async {
      _loadDocument(host.runtime, performanceRectDocument(10000));
      host.runtime.selection.setSelection([
        CanvasElementId(performancePrimaryRectId),
      ]);
      host.runtime.selection.deleteSelection(timestampMs: 30);
    },
  );
}

PerformanceScenario _textEditOpenCommitScenario() {
  final requests = <CanvasContextActionRequested>[];
  StreamSubscription<CanvasContextActionRequested>? subscription;

  return PerformanceScenario(
    id: 'text_edit.open_commit',
    action: (host) async {
      _loadDocument(host.runtime, createPerformanceHostSmokeDocument());
      host.runtime.camera.setOffset(Offset.zero);
      host.runtime.tools.setMode(CanvasInteractionMode.move);
      subscription = host.runtime.contextActionRequests.listen(requests.add);
      host.runtime.tools.handleDoubleTap(
        position: const Offset(8, 40),
        timestampMs: 40,
      );
    },
    afterSettle: (host) async {
      await _commitTextEditRequest(host, requests, subscription);
    },
  );
}

PerformanceScenario _textStyleChangeScenario() {
  return PerformanceScenario(
    id: 'text_style_change.10k',
    action: (host) async {
      _loadDocument(host.runtime, performanceTextDocument(rectCount: 9999));
      host.runtime.edits.edit((edit) {
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
    },
  );
}

PerformanceScenario _resourceImageScenario(String id, String appKey) {
  return PerformanceScenario(
    id: id,
    action: (host) async {
      _loadDocument(
        host.runtime,
        performanceResourceDocument(
          resourceId: performancePrimaryResourceId,
          appKey: appKey,
        ),
      );
      host.runtime.resources.markAllResourcesDirty();
    },
  );
}

PerformanceScenario _resourceMarkDirtyScenario() {
  return PerformanceScenario(
    id: 'resource_mark_dirty',
    action: (host) async {
      _loadDocument(
        host.runtime,
        performanceResourceDocument(
          resourceId: performancePrimaryResourceId,
          appKey: 'dirty-image',
        ),
      );
      host.runtime.resources.markResourceDirty(
        CanvasResourceId(performancePrimaryResourceId),
      );
    },
  );
}

PerformanceScenario _missingResourceScenario() {
  return PerformanceScenario(
    id: 'missing_resource',
    action: (host) async {
      _loadDocument(host.runtime, performanceMissingResourceDocument());
      host.runtime.resources.markAllResourcesDirty();
    },
  );
}

PerformanceScenario _surfaceRuntimeSwapScenario() {
  return PerformanceScenario(
    id: 'surface_runtime_swap',
    action: (host) async {
      final replacement = CanvasRuntime();
      _loadDocument(replacement, performanceRectDocument(1000));
      host.swapRuntime(replacement);
    },
  );
}

PerformanceScenario _disposeDuringPreviewScenario() {
  return PerformanceScenario(
    id: 'dispose_during_preview',
    action: (host) async {
      _loadDocument(host.runtime, performanceRectDocument(1000));
      _pointerDrag(host.runtime, (
        from: const Offset(10, 10),
        to: const Offset(90, 30),
        drawTool: CanvasDrawTool.pencil,
        pointerId: 1,
        includeTerminal: false,
      ));
      final replacement = CanvasRuntime();
      _loadDocument(replacement, performanceRectDocument(1000));
      host.swapRuntime(replacement);
    },
  );
}

Future<void> _commitTextEditRequest(
  PerformanceHostController host,
  List<CanvasContextActionRequested> requests,
  StreamSubscription<CanvasContextActionRequested>? subscription,
) async {
  await subscription?.cancel();
  if (requests.isEmpty) {
    throw StateError('text_edit.open_commit did not request editing.');
  }
  final session =
      host.runtime.textEditing.activeSession.value ??
      host.runtime.textEditing.startFromContextAction(requests.single);
  if (session == null) {
    throw StateError('text_edit.open_commit was not admitted.');
  }
  session.commit(timestampMs: 44);
}

PerformanceScenario _jsonExportScenario() {
  return PerformanceScenario(
    id: 'json_export.50k',
    action: (host) async {
      _loadDocument(host.runtime, performanceRectDocument(50000));
      final json = host.runtime.edits.edit((edit) {
        return performanceFixtureJson(edit.readDraftDocument());
      });
      if (json.isEmpty) {
        throw StateError('json_export.50k produced an empty document.');
      }
    },
  );
}

void _loadDocument(CanvasRuntime runtime, CanvasDocument document) {
  runtime.edits.edit((edit) {
    edit.replaceDraftDocument(document);
  });
}

void _pointerDrag(CanvasRuntime runtime, _PointerDragGesture gesture) {
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
