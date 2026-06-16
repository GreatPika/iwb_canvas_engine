import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:iwb_canvas_engine_example/perf/performance_host.dart';
import 'package:iwb_canvas_engine_example/perf/performance_scenario.dart';

const _traceSettleFrameCount = 8;
const _traceSettleFrameStep = Duration(milliseconds: 16);
const _postSettleRasterDelay = Duration(milliseconds: 500);

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('runs the Flutter performance scenario catalog', (tester) async {
    final controller = PerformanceHostController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(PerformanceHost(controller: controller));
    await tester.pumpAndSettle();

    for (final scenario in allPerformanceScenarios) {
      debugPrint('PERF_SCENARIO_START ${scenario.id}');
      await scenario.runTraced(
        binding: binding,
        host: controller,
        pumpFrame: ([duration = Duration.zero]) =>
            _pumpPerformanceScenarioFrame(tester, duration),
        settle: () => _settlePerformanceTraceWindow(tester),
      );
      debugPrint('PERF_SCENARIO_DONE ${scenario.id}');
      expect(
        find.byKey(performanceHostSurfaceKey),
        findsOneWidget,
        reason: scenario.id,
      );
    }
  }, timeout: Timeout.none);
}

Future<void> _pumpPerformanceScenarioFrame(
  WidgetTester tester,
  Duration duration,
) async {
  await tester.pump(duration);
}

Future<void> _settlePerformanceTraceWindow(WidgetTester tester) async {
  for (var frame = 0; frame < _traceSettleFrameCount; frame += 1) {
    await tester.pump(_traceSettleFrameStep);
  }
  await tester.runAsync(() async {
    await Future<void>.delayed(_postSettleRasterDelay);
  });
}
