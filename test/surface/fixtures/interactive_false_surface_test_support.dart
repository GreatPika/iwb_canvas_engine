// The surface lifecycle proof needs its frame, interaction, geometry, and read
// owners in one file; hiding them behind an import wrapper would weaken it.
// ignore_for_file: number-of-imports

import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';

import 'package:iwb_canvas_engine/src/api/canvas_runtime_frame_bridge.dart';
import 'package:iwb_canvas_engine/src/geometry/geometry_policy.dart';
import 'package:iwb_canvas_engine/src/geometry/spatial_kernel.dart';
import 'package:iwb_canvas_engine/src/interaction/eraser_machine.dart';
import 'package:iwb_canvas_engine/src/interaction/interaction_engine.dart';
import 'package:iwb_canvas_engine/src/runtime/runtime_interaction_read_adapter.dart';
import 'package:iwb_canvas_engine/src/surface/pointer_adapter.dart';
import '../../support/runtime_with_document.dart';

Future<void> expectInteractiveFalsePointerRouting(WidgetTester tester) async {
  final runtime = _runtime();
  addTearDown(runtime.dispose);
  runtime.tools.setMode(CanvasInteractionMode.draw);
  final monitor = _RuntimeMonitor(runtime);
  addTearDown(monitor.dispose);

  await tester.pumpWidget(_SurfaceHost(runtime: runtime, interactive: false));
  expect(find.byType(CanvasSurfacePointerAdapter), findsNothing);
  await _tapPaintHost(tester, const Offset(8, 9));
  await tester.pump();

  expect(runtime.preview, isA<CanvasNoPreview>());
  expect(_paintHosts(), findsOneWidget);
  monitor.expectNoRuntimeEffects(runtime);
}

Future<void> expectInteractiveFalseActiveSessionCancel(
  WidgetTester tester,
) async {
  final runtime = _runtime();
  addTearDown(runtime.dispose);
  runtime.tools.setMode(CanvasInteractionMode.draw);

  final gesture = await _startActiveStrokeSession(tester, runtime);
  await _expectInteractiveFalseCancelsActiveSession(tester, runtime);
  await _expectInteractiveTrueResumesOnlyFutureEvents(
    tester,
    runtime,
    staleGesture: gesture,
  );
  await _expectInteractiveFalseReleasesActiveEraser(tester, runtime);
}

// The CanvasSurface route owns this public toggle; the existing frame bridge
// recovers its already-attached root solely for owner-level lifecycle proof.
// ignore: halstead-volume, source-lines-of-code
Future<void> _expectInteractiveFalseReleasesActiveEraser(
  WidgetTester tester,
  CanvasRuntime runtime,
) async {
  runtime.tools.setDrawTool(CanvasDrawTool.eraser);
  final gesture = await _downOnPaintHost(tester, const Offset(4, 5));
  await gesture.moveTo(tester.getTopLeft(_paintHosts()) + const Offset(7, 8));
  await tester.pump();
  final root = canvasRuntimeFrameRootForSurface(runtime);
  if (root == null) {
    fail('CanvasSurface did not attach its runtime frame root.');
  }
  final capture = root.interactionEngine.activeSession?.eraserCapture;
  if (capture == null) {
    fail('interactive false did not begin with an eraser capture.');
  }
  final captureEvents = <Object>[];
  final interactionEvents = <Object>[];
  final readEvents = <Object>[];
  final cleanupEvents = <InteractionCleanupWorkEvent>[];
  final geometryEvents = <GeometryPolicyEraserWorkEvent>[];
  final spatialEvents = <SpatialKernelEraserWorkEvent>[];

  await GeometryPolicy.observeEraserWork(
    geometryEvents.add,
    () => SpatialKernel.observeEraserWork(
      spatialEvents.add,
      () => InteractionEngine.observeCleanupWork(
        cleanupEvents.add,
        () => PointerEraserCapture.observeWork(
          captureEvents.add,
          () => InteractionEngine.observeEraserRouteWork(
            interactionEvents.add,
            () => RuntimeInteractionReadAdapter.observeEraserEntryRouteWork(
              readEvents.add,
              () => tester.pumpWidget(
                _SurfaceHost(runtime: runtime, interactive: false),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();

  expect(root.interactionEngine.activeSession, isNull);
  expect(capture.points, const [Offset(4, 5), Offset(7, 8)]);
  expect(runtime.preview, isA<CanvasNoPreview>());
  expect(captureEvents, isEmpty);
  expect(interactionEvents, isEmpty);
  expect(readEvents, isEmpty);
  expect(geometryEvents, isEmpty);
  expect(spatialEvents, isEmpty);
  expect(cleanupEvents, contains(InteractionCleanupWorkEvent.sessionReleased));
  await gesture.removePointer();
}

Future<void> expectInteractiveFalsePendingLinePreserved(
  WidgetTester tester,
) async {
  final runtime = _runtime();
  final replacementRuntime = _runtime();
  addTearDown(runtime.dispose);
  addTearDown(replacementRuntime.dispose);
  runtime.tools.setMode(CanvasInteractionMode.draw);
  runtime.tools.setDrawStyle(
    CanvasDrawStyle(tool: CanvasDrawTool.line, lineThickness: 4),
  );

  final pendingLine = await _createPendingLine(tester, runtime);
  final probe = (pendingLine: pendingLine, monitor: _RuntimeMonitor(runtime));
  addTearDown(probe.monitor.dispose);

  await _expectPendingLineSurvivesInteractiveFalse(tester, runtime, probe);
  await _expectPendingLineSurvivesRuntimeSwap(
    tester,
    runtime,
    replacementRuntime,
    probe,
  );
}

Future<void> expectInteractiveFalseStateIsolation(WidgetTester tester) async {
  final inactiveRuntime = _runtime();
  final activeRuntime = _runtime();
  addTearDown(inactiveRuntime.dispose);
  addTearDown(activeRuntime.dispose);
  inactiveRuntime.tools.setMode(CanvasInteractionMode.draw);
  activeRuntime.tools.setMode(CanvasInteractionMode.draw);
  inactiveRuntime.selection.setSelection([CanvasElementId('rect-a')]);
  activeRuntime.selection.setSelection([CanvasElementId('rect-a')]);

  await _expectNoActiveCleanupHasNoEffects(tester, inactiveRuntime);
  await _expectActiveCleanupKeepsCoreState(tester, activeRuntime);
}

Future<TestGesture> _startActiveStrokeSession(
  WidgetTester tester,
  CanvasRuntime runtime,
) async {
  await tester.pumpWidget(_SurfaceHost(runtime: runtime, interactive: true));
  final gesture = await _downOnPaintHost(tester, const Offset(4, 5));
  await tester.pump();
  expect(runtime.preview, isA<CanvasPencilStrokePreview>());

  return gesture;
}

Future<void> _expectInteractiveFalseCancelsActiveSession(
  WidgetTester tester,
  CanvasRuntime runtime,
) async {
  final monitor = _RuntimeMonitor(runtime);
  addTearDown(monitor.dispose);
  await tester.pumpWidget(_SurfaceHost(runtime: runtime, interactive: false));
  await tester.pump();

  expect(runtime.preview, isA<CanvasNoPreview>());
  expect(find.byType(CanvasSurfacePointerAdapter), findsNothing);
  monitor.expectNoDocumentSelectionResourceModeOrActionMutation(runtime);
  expect(
    runtime.state.value.revisions.preview,
    monitor.beforeState.revisions.preview + 1,
  );
  expect(monitor.stateTicks, 1);
}

Future<void> _expectInteractiveTrueResumesOnlyFutureEvents(
  WidgetTester tester,
  CanvasRuntime runtime, {
  required TestGesture staleGesture,
}) async {
  await tester.pumpWidget(_SurfaceHost(runtime: runtime, interactive: true));
  await tester.pump();
  expect(runtime.preview, isA<CanvasNoPreview>());

  final monitor = _RuntimeMonitor(runtime);
  addTearDown(monitor.dispose);
  await staleGesture.up(timeStamp: const Duration(milliseconds: 80));
  await tester.pump();
  monitor.expectNoRuntimeEffects(runtime);

  final nextGesture = await _downOnPaintHost(tester, const Offset(6, 7));
  await tester.pump();
  expect(runtime.preview, isA<CanvasPencilStrokePreview>());
  await nextGesture.up();
}

Future<CanvasPendingLineStartPreview> _createPendingLine(
  WidgetTester tester,
  CanvasRuntime runtime,
) async {
  await tester.pumpWidget(_SurfaceHost(runtime: runtime, interactive: true));
  await _tapPaintHost(tester, const Offset(11, 12), timestampMs: 30);
  final pendingLine = runtime.preview as CanvasPendingLineStartPreview;
  expect(pendingLine.start, const Offset(11, 12));

  return pendingLine;
}

Future<void> _expectPendingLineSurvivesInteractiveFalse(
  WidgetTester tester,
  CanvasRuntime runtime,
  _PendingLineProbe probe,
) async {
  await tester.pumpWidget(_SurfaceHost(runtime: runtime, interactive: false));
  await tester.pump();
  _expectSamePendingLine(runtime.preview, probe.pendingLine);
  probe.monitor.expectNoRuntimeEffects(runtime);
}

Future<void> _expectPendingLineSurvivesRuntimeSwap(
  WidgetTester tester,
  CanvasRuntime runtime,
  CanvasRuntime replacementRuntime,
  _PendingLineProbe probe,
) async {
  await tester.pumpWidget(_SurfaceHost(runtime: runtime, interactive: true));
  await tester.pumpWidget(
    _SurfaceHost(runtime: replacementRuntime, interactive: true),
  );
  await tester.pump();
  _expectSamePendingLine(runtime.preview, probe.pendingLine);
  probe.monitor.expectNoRuntimeEffects(runtime);
}

Future<void> _expectNoActiveCleanupHasNoEffects(
  WidgetTester tester,
  CanvasRuntime runtime,
) async {
  await tester.pumpWidget(_SurfaceHost(runtime: runtime, interactive: true));
  final monitor = _RuntimeMonitor(runtime);
  addTearDown(monitor.dispose);
  await tester.pumpWidget(_SurfaceHost(runtime: runtime, interactive: false));
  await tester.pump();
  monitor.expectNoRuntimeEffects(runtime);
}

Future<void> _expectActiveCleanupKeepsCoreState(
  WidgetTester tester,
  CanvasRuntime runtime,
) async {
  await tester.pumpWidget(_SurfaceHost(runtime: runtime, interactive: true));
  final gesture = await _downOnPaintHost(tester, const Offset(13, 14));
  await tester.pump();
  final monitor = _RuntimeMonitor(runtime);
  addTearDown(monitor.dispose);
  await tester.pumpWidget(_SurfaceHost(runtime: runtime, interactive: false));
  await tester.pump();

  expect(runtime.preview, isA<CanvasNoPreview>());
  monitor.expectNoDocumentSelectionResourceModeOrActionMutation(runtime);
  expect(monitor.actions, isEmpty);
  await gesture.removePointer();
}

Finder _paintHosts() {
  return find.byKey(const ValueKey<String>('iwb_canvas_surface.paint_host'));
}

Future<void> _tapPaintHost(
  WidgetTester tester,
  Offset localPosition, {
  int timestampMs = 1,
}) async {
  final gesture = await _downOnPaintHost(
    tester,
    localPosition,
    timestampMs: timestampMs,
  );
  await gesture.up(timeStamp: Duration(milliseconds: timestampMs + 1));
  await tester.pump();
}

Future<TestGesture> _downOnPaintHost(
  WidgetTester tester,
  Offset localPosition, {
  int timestampMs = 1,
}) async {
  final gesture = await tester.createGesture(kind: PointerDeviceKind.touch);
  await gesture.down(
    tester.getTopLeft(_paintHosts()) + localPosition,
    timeStamp: Duration(milliseconds: timestampMs),
  );

  return gesture;
}

void _expectSamePendingLine(
  CanvasPreviewState actual,
  CanvasPendingLineStartPreview expected,
) {
  final pendingLine = actual as CanvasPendingLineStartPreview;
  expect(pendingLine.start, expected.start);
  expect(pendingLine.timestampMs, expected.timestampMs);
  expect(pendingLine.color, expected.color);
  expect(pendingLine.thickness, expected.thickness);
}

final class _SurfaceHost extends StatelessWidget {
  const _SurfaceHost({required this.runtime, required this.interactive});

  final CanvasRuntime runtime;
  final bool interactive;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: SizedBox(
        width: 100,
        height: 100,
        child: CanvasSurface(runtime: runtime, interactive: interactive),
      ),
    );
  }
}

CanvasRuntime _runtime() {
  return runtimeWithDocument(_document());
}

CanvasDocument _document() {
  return CanvasDocument(
    resources: [
      CanvasImageResource(
        id: CanvasResourceId('resource-a'),
        source: CanvasResourceSource.appKey('image-a'),
      ),
    ],
    layers: [
      CanvasLayer(
        id: CanvasLayerId('layer-a'),
        elements: [
          CanvasRectElement(
            id: CanvasElementId('rect-a'),
            size: const Size(10, 10),
            fillColor: const Color(0xFF336699),
          ),
        ],
      ),
    ],
  );
}

// The monitor snapshots every public side-effect surface that interactive
// cleanup must preserve; splitting it would weaken the invariant assertion.
// ignore: coupling-between-object-classes
final class _RuntimeMonitor {
  _RuntimeMonitor(this._runtime)
    : beforeDocument = _runtime.readDocument(),
      beforeState = _runtime.state.value,
      beforePreview = _runtime.preview,
      beforeMode = _runtime.tools.mode,
      beforeDrawStyle = _runtime.tools.drawStyle,
      beforeSelection = Set<CanvasElementId>.of(
        _runtime.selection.selectedElementIds,
      ),
      beforeResources = _resourceFacts(_runtime.resources.resources) {
    _cancelSubscription = _runtime.actions.listen(actions.add).cancel;
    _runtime.state.addListener(_countStateTick);
  }

  final CanvasRuntime _runtime;
  final CanvasDocument beforeDocument;
  final CanvasRuntimeState beforeState;
  final CanvasPreviewState beforePreview;
  final CanvasInteractionMode beforeMode;
  final CanvasDrawStyle beforeDrawStyle;
  final Set<CanvasElementId> beforeSelection;
  final List<_ResourceFact> beforeResources;
  final List<CanvasActionCommitted> actions = [];
  late final void Function() _cancelSubscription;
  int stateTicks = 0;

  void expectNoRuntimeEffects(CanvasRuntime runtime) {
    expect(runtime.preview, same(beforePreview));
    expect(runtime.state.value, same(beforeState));
    expectNoDocumentSelectionResourceModeOrActionMutation(runtime);
    expect(stateTicks, 0);
  }

  void expectNoDocumentSelectionResourceModeOrActionMutation(
    CanvasRuntime runtime,
  ) {
    expect(runtime.readDocument(), same(beforeDocument));
    expect(runtime.tools.mode, beforeMode);
    expect(runtime.tools.drawStyle, beforeDrawStyle);
    expect(runtime.selection.selectedElementIds, beforeSelection);
    expect(_resourceFacts(runtime.resources.resources), beforeResources);
    expect(actions, isEmpty);
  }

  void dispose() {
    _runtime.state.removeListener(_countStateTick);
    _cancelSubscription();
  }

  void _countStateTick() {
    stateTicks += 1;
  }
}

List<_ResourceFact> _resourceFacts(List<CanvasResource> resources) {
  return [
    for (final resource in resources)
      (
        id: resource.id,
        source: resource.source,
        contentHash: resource.contentHash,
        byteLength: resource.byteLength,
      ),
  ];
}

typedef _ResourceFact = ({
  CanvasResourceId id,
  CanvasResourceSource source,
  String? contentHash,
  int? byteLength,
});

typedef _PendingLineProbe = ({
  CanvasPendingLineStartPreview pendingLine,
  _RuntimeMonitor monitor,
});
