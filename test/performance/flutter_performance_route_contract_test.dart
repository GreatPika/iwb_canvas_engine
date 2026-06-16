import 'dart:io';

import 'package:test/test.dart';

const _performanceDocPath = 'docs/verification/performance.md';
const _scenarioSourcePath = 'example/lib/perf/performance_scenario.dart';
const _integrationTestPath =
    'example/integration_test/perf_canvas_surface_test.dart';

const _retiredRouteKeys = [
  'startup',
  'benchmark',
  'SceneController',
  'SceneView',
  'CanvasMode',
  'DrawTool',
];

void main() {
  _registerCatalogContractTest();
  _registerIntegrationRouteContractTest();
  _registerTracedRunnerContractTest();
}

void _registerCatalogContractTest() {
  test('Flutter performance scenario descriptors match the docs catalog', () {
    final docScenarioIds = _performanceDocScenarioIds();
    final descriptorIds = _performanceScenarioDescriptorIds();

    expect(descriptorIds, unorderedEquals(docScenarioIds));
    expect(
      descriptorIds,
      isNot(anyElement(contains('startup'))),
      reason: 'startup scenarios are Android Macrobenchmark scope.',
    );
    _expectNoRetiredRouteKeys(File(_scenarioSourcePath).readAsStringSync());
  });
}

void _registerIntegrationRouteContractTest() {
  test('integration route uses the single traced scenario runner', () {
    final integrationSource = File(_integrationTestPath).readAsStringSync();

    expect(integrationSource, contains('allPerformanceScenarios'));
    expect(integrationSource, contains('scenario.runTraced('));
    expect(integrationSource, isNot(contains('traceAction')));
  });
}

void _registerTracedRunnerContractTest() {
  test('traced runner owns report key and settle boundary', () {
    final source = File(_scenarioSourcePath).readAsStringSync();
    final traceStart = RegExp(
      r'return\s+binding\s*\.traceAction\(\(\)\s+async\s+\{',
    ).firstMatch(source)?.start;
    final actionCall = source.indexOf('await scenario.action(host);');
    final firstSettle = source.indexOf('await settle();', actionCall);
    final reportKey = source.indexOf('reportKey: scenario.id', firstSettle);

    expect(traceStart, isNotNull);
    expect(actionCall, greaterThan(traceStart ?? -1));
    expect(firstSettle, greaterThan(actionCall));
    expect(reportKey, greaterThan(firstSettle));
    expect(source, isNot(contains('.onError(')));
    expect(source, isNot(contains('Failed to connect to VM Service')));
    expect(source, isNot(contains('WithoutTimeline')));
  });
}

List<String> _performanceDocScenarioIds() {
  final source = File(_performanceDocPath).readAsStringSync();
  final ids = <String>[];
  final rowPattern = RegExp(r'^\| `([^`]+)` \| required(?:[^|]*)\|$');
  for (final line in source.split('\n')) {
    final match = rowPattern.firstMatch(line.trim());
    if (match != null) {
      ids.add(match.group(1) ?? fail('scenario id row did not capture id'));
    }
  }

  expect(ids, isNotEmpty);

  return ids;
}

List<String> _performanceScenarioDescriptorIds() {
  final source = File(_scenarioSourcePath).readAsStringSync();
  final descriptorPattern = RegExp(r"id: '([^']+)'");
  final directIds = descriptorPattern
      .allMatches(source)
      .map((match) => match.group(1) ?? fail('descriptor id did not capture'))
      .toList();
  final helperPattern = RegExp(
    r"_loadDocumentScenario\('([^']+)'|_cameraPanScenario\('([^']+)'|"
    r"_selectionMoveScenario\('([^']+)'|_drawScenario\('([^']+)'|"
    r"_resourceImageScenario\('([^']+)'",
  );
  final helperIds = helperPattern.allMatches(source).map((match) {
    return match.groups([1, 2, 3, 4, 5]).nonNulls.single;
  });

  return [...helperIds, ...directIds];
}

void _expectNoRetiredRouteKeys(String source) {
  for (final key in _retiredRouteKeys) {
    final pattern = RegExp(
      '(?<![A-Za-z0-9_])${RegExp.escape(key)}'
      '(?![A-Za-z0-9_])',
    );
    expect(pattern.hasMatch(source), isFalse, reason: key);
  }
}
