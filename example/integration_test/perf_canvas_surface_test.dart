import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:iwb_canvas_engine_example/perf/performance_host.dart';
import 'package:iwb_canvas_engine_example/perf/performance_scenario.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('runs the Flutter performance scenario catalog', (tester) async {
    final controller = PerformanceHostController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(PerformanceHost(controller: controller));
    await tester.pumpAndSettle();

    for (final scenario in allPerformanceScenarios) {
      await scenario.runTraced(
        binding: binding,
        host: controller,
        settle: tester.pumpAndSettle,
      );
      expect(
        find.byKey(performanceHostSurfaceKey),
        findsOneWidget,
        reason: scenario.id,
      );
    }
  }, timeout: Timeout.none);
}
