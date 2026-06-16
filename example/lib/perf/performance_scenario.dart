import 'package:integration_test/integration_test.dart';

import 'performance_host.dart';

typedef PerformanceScenarioAction =
    Future<void> Function(PerformanceHostController host);

typedef PerformanceScenarioSettle = Future<void> Function();

final class PerformanceScenario {
  const PerformanceScenario({required this.id, required this.action});

  final String id;
  final PerformanceScenarioAction action;

  Future<void> runTraced({
    required IntegrationTestWidgetsFlutterBinding binding,
    required PerformanceHostController host,
    required PerformanceScenarioSettle settle,
  }) {
    return binding.traceAction(() async {
      await action(host);
      await settle();
    }, reportKey: id);
  }
}
