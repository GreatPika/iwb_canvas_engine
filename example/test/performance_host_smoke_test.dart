import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine_example/perf/performance_host.dart';

void main() {
  testWidgets('performance host drives the public canvas surface', (
    tester,
  ) async {
    final controller = PerformanceHostController()..loadSmokeDocument();
    final contextActions = <CanvasContextActionRequested>[];
    final subscription = controller.runtime.contextActionRequests.listen(
      contextActions.add,
    );
    addTearDown(() async {
      await subscription.cancel();
      controller.dispose();
    });

    await tester.pumpWidget(PerformanceHost(controller: controller));
    await tester.pump();

    _expectMountedHost(controller);
    _expectPublicResourceResolution(controller);
    await _exercisePublicCommand(tester, controller.runtime);
    _exercisePublicToolSwitch(controller.runtime);
    await _exercisePublicTextEditingPath(
      tester,
      controller.runtime,
      contextActions,
    );
    expect(tester.takeException(), isNull);
  });
}

void _expectMountedHost(PerformanceHostController controller) {
  expect(find.byType(CanvasSurface), findsOneWidget);
  expect(find.byKey(performanceHostSurfaceKey), findsOneWidget);
  expect(find.byKey(performanceHostTextOverlayKey), findsOneWidget);
  expect(controller.runtime.state.value.summary.elementCount, 3);
}

void _expectPublicResourceResolution(PerformanceHostController controller) {
  expect(
    controller.resourceResolver.resolvedAppKeys,
    contains(performanceHostResourceAppKey),
  );
}

Future<void> _exercisePublicCommand(
  WidgetTester tester,
  CanvasRuntime runtime,
) async {
  expect(removePerformanceCommandTarget(runtime), isTrue);
  await tester.pump();
  expect(runtime.state.value.summary.elementCount, 2);
}

void _exercisePublicToolSwitch(CanvasRuntime runtime) {
  switchPerformanceMarkerTool(runtime);
  expect(runtime.tools.mode, CanvasInteractionMode.draw);
  expect(runtime.tools.drawStyle.tool, CanvasDrawTool.marker);
}

Future<void> _exercisePublicTextEditingPath(
  WidgetTester tester,
  CanvasRuntime runtime,
  List<CanvasContextActionRequested> contextActions,
) async {
  runtime.tools.handleDoubleTap(position: const Offset(8, 40), timestampMs: 2);
  await tester.pump();

  final session = startPerformanceTextEditingFromContextAction(
    runtime,
    contextActions.single,
  );
  await tester.pump();

  expect(session, isNotNull);
  expect(runtime.textEditing.activeSession.value, same(session));
  expect(find.byType(CanvasTextEditingOverlay), findsOneWidget);
}
