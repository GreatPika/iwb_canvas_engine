import 'dart:async';
import 'dart:io';

import 'package:flutter_driver/flutter_driver.dart';
import 'package:integration_test/integration_test_driver.dart';

Future<void> main() {
  return integrationDriver(responseDataCallback: _writePerformanceTimelines);
}

Future<void> _writePerformanceTimelines(Map<String, dynamic>? data) async {
  if (data == null) {
    throw StateError('Performance profile run returned no response data.');
  }

  final scenarios = _performanceReportScenarios(data);
  if (scenarios.isEmpty) {
    throw StateError('Performance profile run returned no scenario timelines.');
  }
  _resetResultsDirectory();

  for (final scenario in scenarios) {
    await _writeScenarioTimeline(data, scenario);
  }
}

List<_PerformanceReportScenario> _performanceReportScenarios(
  Map<String, dynamic> data,
) {
  final ids = data.keys.toList()..sort();

  return [for (final id in ids) _PerformanceReportScenario(id)];
}

void _resetResultsDirectory() {
  final resultsDirectory = Directory('build/flutter_performance');
  if (resultsDirectory.existsSync()) {
    resultsDirectory.deleteSync(recursive: true);
  }
}

Future<void> _writeScenarioTimeline(
  Map<String, dynamic> data,
  _PerformanceReportScenario scenario,
) async {
  final timelineData = data[scenario.id];
  if (timelineData is! Map<String, dynamic>) {
    throw StateError(
      'Performance profile report ${scenario.id} did not contain timeline '
      'JSON.',
    );
  }

  final scenarioDirectory = Directory(
    'build/flutter_performance${Platform.pathSeparator}${scenario.id}',
  );
  final timeline = Timeline.fromJson(timelineData);
  final summary = TimelineSummary.summarize(timeline);
  await summary.writeTimelineToFile(
    scenario.id,
    destinationDirectory: scenarioDirectory.path,
    includeSummary: true,
  );
}

final class _PerformanceReportScenario {
  const _PerformanceReportScenario(this.id);

  final String id;
}
