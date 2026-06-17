import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:iwb_canvas_engine_example/perf/performance_host.dart';
import 'package:iwb_canvas_engine_example/perf/performance_scenario.dart';

typedef PerformanceRouteLog = void Function(String message);

const _traceSettleFrameCount = 8;
const _traceSettleFrameStep = Duration(milliseconds: 16);
const _postSettleRasterDelay = Duration(milliseconds: 500);

final class FlutterPerformanceRouteOptions {
  const FlutterPerformanceRouteOptions({
    this.phaseRuns,
    this.log,
    this.traceAction,
    this.traceSettleFrameCount = _traceSettleFrameCount,
    this.traceSettleFrameStep = _traceSettleFrameStep,
    this.postSettleRasterDelay = _postSettleRasterDelay,
  });

  final Iterable<PerformanceScenarioActionPhaseRun>? phaseRuns;
  final PerformanceRouteLog? log;
  final PerformanceScenarioTraceAction? traceAction;
  final int traceSettleFrameCount;
  final Duration traceSettleFrameStep;
  final Duration postSettleRasterDelay;
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('runs the Flutter performance scenario catalog', (tester) async {
    await runFlutterPerformanceScenarioCatalog(
      binding: binding,
      tester: tester,
    );
    expect(find.byKey(performanceHostSurfaceKey), findsOneWidget);
  }, timeout: Timeout.none);
}

Future<void> runFlutterPerformanceScenarioCatalog({
  required IntegrationTestWidgetsFlutterBinding binding,
  required WidgetTester tester,
  FlutterPerformanceRouteOptions options =
      const FlutterPerformanceRouteOptions(),
}) async {
  final controller = PerformanceHostController();
  addTearDown(controller.dispose);

  await tester.pumpWidget(PerformanceHost(controller: controller));
  await tester.pumpAndSettle();

  final routeLog = options.log ?? debugPrint;
  for (final phaseRun
      in options.phaseRuns ?? allPerformanceScenarioActionPhaseRuns) {
    routeLog('PERF_SCENARIO_START ${phaseRun.reportKey}');
    await phaseRun.runTraced(
      binding: binding,
      host: controller,
      pumpFrame: ([duration = Duration.zero]) =>
          _pumpPerformanceScenarioFrame(tester, duration),
      settle: () => _settlePerformanceTraceWindow(
        tester,
        frameCount: options.traceSettleFrameCount,
        frameStep: options.traceSettleFrameStep,
        postRasterDelay: options.postSettleRasterDelay,
      ),
      traceAction: options.traceAction,
    );
    routeLog('PERF_SCENARIO_DONE ${phaseRun.reportKey}');
    expect(
      find.byKey(performanceHostSurfaceKey),
      findsOneWidget,
      reason: phaseRun.reportKey,
    );
  }
}

Future<void> _pumpPerformanceScenarioFrame(
  WidgetTester tester,
  Duration duration,
) async {
  await tester.pump(duration);
}

Future<void> _settlePerformanceTraceWindow(
  WidgetTester tester, {
  required int frameCount,
  required Duration frameStep,
  required Duration postRasterDelay,
}) async {
  for (var frame = 0; frame < frameCount; frame += 1) {
    await tester.pump(frameStep);
  }
  await tester.runAsync(() async {
    await Future<void>.delayed(postRasterDelay);
  });
}
