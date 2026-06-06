import 'dart:convert';

import 'package:test/test.dart';

import '../../tool/bench/src/benchmark_case_adapters.dart';
import '../../tool/bench/src/benchmark_manifest.dart';

void main() {
  group('benchmark probe adapter', () {
    test('decodes new-schema action and setup payload', () {
      final manifest = BenchmarkManifest.load();
      final benchmarkCase = manifest.cases.first;
      final scale = benchmarkCase.scales.first;
      final result = decodeBenchmarkProbeResult(
        benchmarkCase,
        scale,
        _probeStdout(benchmarkCase, includeOldElapsedSamples: false),
      );

      expect(result.actionUsSamples, [7]);
      expect(result.setupUsSamples, [5000]);
      expect(result.metrics, containsPair('avg_us', 7));
      expect(result.setupMetrics, containsPair('setup_us', 5000));
      expect(result.fixtureShape, benchmarkCase.fixtureShape);
      expect(
        result.measurementBoundary.timedScope,
        benchmarkCase.measurementBoundary.timedScope,
      );
    });

    test('rejects old elapsedUsSamples probe payload', () {
      final manifest = BenchmarkManifest.load();
      final benchmarkCase = manifest.cases.first;
      final scale = benchmarkCase.scales.first;

      expect(
        () => decodeBenchmarkProbeResult(
          benchmarkCase,
          scale,
          _probeStdout(benchmarkCase, includeOldElapsedSamples: true),
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains(
              '${benchmarkCase.id}/${scale.id} old elapsedUsSamples '
              'probe payload',
            ),
          ),
        ),
      );
    });

    test('accepts setup-scope none with empty boundary diagnostic lists', () {
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
    });
  });
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
    classification: benchmarkCase.classification,
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
