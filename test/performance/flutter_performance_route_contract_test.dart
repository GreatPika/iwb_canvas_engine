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
    expect(
      integrationSource,
      contains('pumpFrame: ([duration = Duration.zero])'),
    );
    expect(integrationSource, contains('PERF_SCENARIO_START'));
    expect(integrationSource, contains('PERF_SCENARIO_DONE'));
    expect(
      integrationSource,
      contains('settle: () => _settlePerformanceTraceWindow(tester)'),
    );
    expect(integrationSource, contains('tester.runAsync'));
    expect(integrationSource, isNot(contains('traceAction')));
    expect(integrationSource, isNot(contains('settle: tester.pumpAndSettle')));
    _expectTraceSettleIsBounded(integrationSource);
  });
}

void _expectTraceSettleIsBounded(String integrationSource) {
  final helperPattern = RegExp(
    r'Future<void> _settlePerformanceTraceWindow[\s\S]*?\n}\n?$',
  );
  final helperBody = helperPattern.firstMatch(integrationSource)?.group(0);

  expect(helperBody, isNotNull);
  expect(helperBody, contains('_traceSettleFrameCount'));
  expect(helperBody, contains('await tester.pump(_traceSettleFrameStep);'));
  expect(helperBody, isNot(contains('pumpAndSettle')));
  expect(helperBody, isNot(contains('endOfFrame')));
}

void _registerTracedRunnerContractTest() {
  test('traced runner owns report key and settle boundary', () {
    final source = File(_scenarioSourcePath).readAsStringSync();

    expect(source, isNotEmpty);
    _expectTraceActionWrapsScenarioAndSettle(source);
    _expectNoTraceFallback(source);
    _expectScenarioFramePumping(source);
  });
}

void _expectTraceActionWrapsScenarioAndSettle(String source) {
  final traceStart = RegExp(
    r'return\s+request\.binding\s*\.traceAction\(\(\)\s+async\s+\{',
  ).firstMatch(source)?.start;
  final actionCall = source.indexOf('await request.scenario.action(context);');
  final firstSettle = source.indexOf('await request.settle();', actionCall);
  final reportKey = source.indexOf(
    'reportKey: request.scenario.id',
    firstSettle,
  );

  expect(traceStart, isNotNull);
  expect(actionCall, greaterThan(traceStart ?? -1));
  expect(firstSettle, greaterThan(actionCall));
  expect(reportKey, greaterThan(firstSettle));
}

void _expectNoTraceFallback(String source) {
  expect(source, isNot(contains('.onError(')));
  expect(source, isNot(contains('Failed to connect to VM Service')));
  expect(source, isNot(contains('WithoutTimeline')));
}

void _expectScenarioFramePumping(String source) {
  expect(source, contains('PerformanceScenarioTraceRequest'));
  expect(source, contains('required PerformanceScenarioPumpFrame pumpFrame'));
  expect(source, contains('await context.pumpScenarioFrame();'));
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
