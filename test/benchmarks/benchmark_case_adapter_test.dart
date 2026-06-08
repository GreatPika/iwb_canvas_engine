import 'dart:convert';

import 'package:test/test.dart';

import '../../tool/bench/src/benchmark_case_adapters.dart';
import '../../tool/bench/src/benchmark_manifest.dart';

void main() {
  group('benchmark probe adapter', () {
    _registerProbeAdapterTests();
  });
}

void _registerProbeAdapterTests() {
  test('decodes new-schema action and setup payload', () {
    final result = _decodesNewSchemaPayload();
    expect(result.runtime.profileId, 'dry_run');
  });
  test('rejects old elapsedUsSamples probe payload', () {
    expect(_oldPayloadDecode, throwsA(_oldPayloadError()));
  });
  test('accepts setup-scope none with empty boundary diagnostic lists', () {
    final result = _acceptsSetupScopeNone();
    expect(result.measurementBoundary.setupScope, 'none');
  });
  test('rejects mismatched probe profile id', () {
    expect(_mismatchedProfileDecode, throwsA(_mismatchedProfileError()));
  });
}

BenchmarkAdapterResult _decodesNewSchemaPayload() {
  final context = _firstCaseContext();
  final result = decodeBenchmarkProbeResult(
    context.benchmarkCase,
    context.scale,
    _probeStdout(context.benchmarkCase, includeOldElapsedSamples: false),
  );

  expect(result.actionUsSamples, [7]);
  expect(result.runtime.profileId, 'dry_run');
  expect(result.setupUsSamples, [5000]);
  expect(result.metrics, containsPair('avg_us', 7));
  expect(result.setupMetrics, containsPair('setup_us', 5000));
  expect(result.fixtureShape, context.benchmarkCase.fixtureShape);
  expect(
    result.measurementBoundary.timedScope,
    context.benchmarkCase.measurementBoundary.timedScope,
  );
  return result;
}

void _oldPayloadDecode() {
  final context = _firstCaseContext();
  decodeBenchmarkProbeResult(
    context.benchmarkCase,
    context.scale,
    _probeStdout(context.benchmarkCase, includeOldElapsedSamples: true),
  );
}

Matcher _oldPayloadError() {
  final context = _firstCaseContext();
  return isA<StateError>().having(
    (error) => error.message,
    'message',
    contains(
      '${context.benchmarkCase.id}/${context.scale.id} old '
      'elapsedUsSamples probe payload',
    ),
  );
}

BenchmarkAdapterResult _acceptsSetupScopeNone() {
  final manifest = BenchmarkManifest.load();
  final benchmarkCase = _withoutSetup(manifest.cases.first);
  final scale = benchmarkCase.scales.first;
  final result = decodeBenchmarkProbeResult(
    benchmarkCase,
    scale,
    _probeStdout(
      benchmarkCase,
      includeOldElapsedSamples: false,
      setupUsSamples: const [],
      setupMetrics: const {},
    ),
  );

  expect(result.setupUsSamples, isEmpty);
  expect(result.setupMetrics, isEmpty);
  expect(result.measurementBoundary.setupScope, 'none');
  expect(result.measurementBoundary.setupMetrics, isEmpty);
  expect(result.measurementBoundary.setupMemoryMetrics, isEmpty);
  return result;
}

void _mismatchedProfileDecode() {
  final context = _firstCaseContext();
  decodeBenchmarkProbeResult(
    context.benchmarkCase,
    context.scale,
    _probeStdout(context.benchmarkCase, includeOldElapsedSamples: false),
    expectedProfileId: 'release',
  );
}

Matcher _mismatchedProfileError() {
  final context = _firstCaseContext();
  return isA<StateError>().having(
    (error) => error.message,
    'message',
    contains(
      '${context.benchmarkCase.id}/${context.scale.id} emitted profileId '
      'dry_run for expected profile release',
    ),
  );
}

({BenchmarkCase benchmarkCase, BenchmarkScale scale}) _firstCaseContext() {
  final manifest = BenchmarkManifest.load();
  final benchmarkCase = manifest.cases.first;

  return (benchmarkCase: benchmarkCase, scale: benchmarkCase.scales.first);
}

String _probeStdout(
  BenchmarkCase benchmarkCase, {
  required bool includeOldElapsedSamples,
  List<int> setupUsSamples = const [5000],
  Map<String, Object?> setupMetrics = const {
    'setup_us': 5000,
    'setup_allocation_bytes': 1000,
    'setup_rss_delta_bytes': 1000,
  },
}) {
  final payload = <String, Object?>{
    'probeSchemaVersion': benchmarkToolSchemaVersion,
    'actionUsSamples': [7],
    'setupUsSamples': setupUsSamples,
    'metrics': {'avg_us': 7, 'p95_us': 7, 'max_us': 7, 'setup_us': 5000},
    'setupMetrics': setupMetrics,
    'measurementBoundary': _boundaryJson(benchmarkCase.measurementBoundary),
    'fixtureShape': benchmarkCase.fixtureShape,
    'runtime': {
      'profileId': 'dry_run',
      'runtimeMode': 'flutter_test',
      'assertionsEnabled': true,
      'debugInvariantMode': false,
    },
  };
  if (includeOldElapsedSamples) {
    payload['elapsedUsSamples'] = [7];
  }
  return 'BENCHMARK_PROBE_JSON:${jsonEncode(payload)}';
}

Map<String, Object?> _boundaryJson(BenchmarkMeasurementBoundary boundary) {
  return {
    'timedScope': boundary.timedScope,
    'setupScope': boundary.setupScope,
    'teardownScope': boundary.teardownScope,
    'primaryTiming': boundary.primaryTiming,
    'primaryMemory': boundary.primaryMemory,
    'setupMetrics': boundary.setupMetrics,
    'setupMemoryMetrics': boundary.setupMemoryMetrics,
  };
}

BenchmarkCase _withoutSetup(BenchmarkCase benchmarkCase) {
  return BenchmarkCase(
    id: benchmarkCase.id,
    baselinePolicy: benchmarkCase.baselinePolicy,
    budgetClasses: benchmarkCase.budgetClasses,
    memoryScope: benchmarkCase.memoryScope,
    measurementBoundary: BenchmarkMeasurementBoundary(
      timedScope: benchmarkCase.measurementBoundary.timedScope,
      setupScope: 'none',
      teardownScope: benchmarkCase.measurementBoundary.teardownScope,
      primaryTiming: benchmarkCase.measurementBoundary.primaryTiming,
      primaryMemory: benchmarkCase.measurementBoundary.primaryMemory,
      setupMetrics: const [],
      setupMemoryMetrics: const [],
    ),
    fixtureShape: benchmarkCase.fixtureShape,
    docsMetricsLabel: benchmarkCase.docsMetricsLabel,
    requiredMetrics: benchmarkCase.requiredMetrics,
    exactInvariants: benchmarkCase.exactInvariants,
    scales: benchmarkCase.scales,
  );
}
