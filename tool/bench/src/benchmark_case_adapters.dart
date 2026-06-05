import 'dart:convert';
import 'dart:io';

import 'benchmark_manifest.dart';

const benchmarkProbePath = 'test/benchmarks/benchmark_probe.dart';
const _probeJsonPrefix = 'BENCHMARK_PROBE_JSON:';

final class BenchmarkAdapterResult {
  const BenchmarkAdapterResult({
    required this.elapsedUsSamples,
    required this.metrics,
    required this.runtime,
  });

  final List<int> elapsedUsSamples;
  final Map<String, Object?> metrics;
  final BenchmarkProbeRuntime runtime;
}

final class BenchmarkProbeRuntime {
  const BenchmarkProbeRuntime({
    required this.runtimeMode,
    required this.assertionsEnabled,
    required this.debugInvariantMode,
  });

  final String runtimeMode;
  final bool assertionsEnabled;
  final bool debugInvariantMode;
}

BenchmarkAdapterResult runBenchmarkAdapter(
  BenchmarkCase benchmarkCase,
  BenchmarkScale scale,
  BenchmarkProfile profile,
  BenchmarkDeviceTarget? deviceTarget,
) {
  final result = Process.runSync(Platform.resolvedExecutable, [
    'run',
    benchmarkProbePath,
    if (deviceTarget != null) '--device=${deviceTarget.id}',
    '--case=${benchmarkCase.id}',
    '--scale=${scale.id}',
    '--profile=${profile.id}',
    '--warmups=${profile.warmups}',
    '--repetitions=${profile.repetitions}',
    '--minimum-ms=${profile.minimumMeasuredMs}',
    '--minimum-samples=${profile.minimumSamples}',
    '--timing-claims=${profile.timingClaims}',
    if (!profile.timingClaims) '--dry-run',
  ]);
  if (result.exitCode != 0) {
    throw StateError(
      'Benchmark probe ${benchmarkCase.id}/${scale.id} failed:\n'
      '${result.stdout}\n${result.stderr}',
    );
  }
  return _decodeProbeResult(benchmarkCase, scale, result.stdout.toString());
}

final class BenchmarkDeviceTarget {
  const BenchmarkDeviceTarget(this.id);

  final String id;
}

BenchmarkAdapterResult _decodeProbeResult(
  BenchmarkCase benchmarkCase,
  BenchmarkScale scale,
  String stdout,
) {
  final jsonLine = stdout
      .split('\n')
      .lastWhere(
        (line) => line.startsWith(_probeJsonPrefix),
        orElse: () => throw StateError(
          '${benchmarkCase.id}/${scale.id} emitted no probe JSON.',
        ),
      )
      .replaceFirst(_probeJsonPrefix, '');
  final decoded = jsonDecode(jsonLine) as Map<String, Object?>;
  final elapsedUsSamples = [
    for (final value in decoded['elapsedUsSamples'] as List<Object?>)
      if (value is int) value else _invalidSample(value),
  ];
  if (elapsedUsSamples.isEmpty) {
    throw StateError('${benchmarkCase.id}/${scale.id} emitted no samples.');
  }
  final decodedMetrics = decoded['metrics'];
  if (decodedMetrics is! Map<String, Object?>) {
    throw StateError(
      '${benchmarkCase.id}/${scale.id} emitted invalid metrics.',
    );
  }
  final runtime = _decodeProbeRuntime(benchmarkCase, scale, decoded['runtime']);
  return BenchmarkAdapterResult(
    elapsedUsSamples: elapsedUsSamples,
    metrics: decodedMetrics,
    runtime: runtime,
  );
}

BenchmarkProbeRuntime _decodeProbeRuntime(
  BenchmarkCase benchmarkCase,
  BenchmarkScale scale,
  Object? runtime,
) {
  if (runtime is! Map<String, Object?>) {
    throw StateError(
      '${benchmarkCase.id}/${scale.id} emitted invalid runtime metadata.',
    );
  }
  return BenchmarkProbeRuntime(
    runtimeMode: _runtimeString(benchmarkCase, scale, runtime, 'runtimeMode'),
    assertionsEnabled: _runtimeBool(
      benchmarkCase,
      scale,
      runtime,
      'assertionsEnabled',
    ),
    debugInvariantMode: _runtimeBool(
      benchmarkCase,
      scale,
      runtime,
      'debugInvariantMode',
    ),
  );
}

String _runtimeString(
  BenchmarkCase benchmarkCase,
  BenchmarkScale scale,
  Map<String, Object?> runtime,
  String key,
) {
  final value = runtime[key];
  if (value is String && value.isNotEmpty) {
    return value;
  }
  throw StateError('${benchmarkCase.id}/${scale.id} emitted invalid $key.');
}

bool _runtimeBool(
  BenchmarkCase benchmarkCase,
  BenchmarkScale scale,
  Map<String, Object?> runtime,
  String key,
) {
  final value = runtime[key];
  if (value is bool) {
    return value;
  }
  throw StateError('${benchmarkCase.id}/${scale.id} emitted invalid $key.');
}

Never _invalidSample(Object? value) {
  throw StateError('Benchmark probe emitted invalid elapsed sample $value.');
}
