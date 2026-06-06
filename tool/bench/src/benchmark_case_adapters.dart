import 'dart:convert';
import 'dart:io';

import 'benchmark_manifest.dart';

const benchmarkProbePath = 'test/benchmarks/benchmark_probe.dart';
const _probeJsonPrefix = 'BENCHMARK_PROBE_JSON:';

final class BenchmarkAdapterResult {
  const BenchmarkAdapterResult({
    required this.actionUsSamples,
    required this.setupUsSamples,
    required this.metrics,
    required this.setupMetrics,
    required this.measurementBoundary,
    required this.fixtureShape,
    required this.runtime,
  });

  final List<int> actionUsSamples;
  final List<int> setupUsSamples;
  final Map<String, Object?> metrics;
  final Map<String, Object?> setupMetrics;
  final BenchmarkMeasurementBoundary measurementBoundary;
  final String fixtureShape;
  final BenchmarkProbeRuntime runtime;
}

final class BenchmarkProbeRuntime {
  const BenchmarkProbeRuntime({
    required this.profileId,
    required this.runtimeMode,
    required this.assertionsEnabled,
    required this.debugInvariantMode,
  });

  final String profileId;
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
  return decodeBenchmarkProbeResult(
    benchmarkCase,
    scale,
    result.stdout.toString(),
    expectedProfileId: profile.id,
  );
}

final class BenchmarkDeviceTarget {
  const BenchmarkDeviceTarget(this.id);

  final String id;
}

BenchmarkAdapterResult decodeBenchmarkProbeResult(
  BenchmarkCase benchmarkCase,
  BenchmarkScale scale,
  String stdout, {
  String? expectedProfileId,
}) {
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
  if (decoded.containsKey('elapsedUsSamples')) {
    throw StateError(
      '${benchmarkCase.id}/${scale.id} old elapsedUsSamples probe payload.',
    );
  }
  final probeSchemaVersion = decoded['probeSchemaVersion'];
  if (probeSchemaVersion != benchmarkToolSchemaVersion) {
    throw StateError(
      '${benchmarkCase.id}/${scale.id} emitted invalid probeSchemaVersion.',
    );
  }
  final actionUsSamples = _sampleList(
    benchmarkCase,
    scale,
    decoded,
    'actionUsSamples',
  );
  if (actionUsSamples.isEmpty) {
    throw StateError('${benchmarkCase.id}/${scale.id} emitted no samples.');
  }
  final setupUsSamples = _sampleList(
    benchmarkCase,
    scale,
    decoded,
    'setupUsSamples',
  );
  final decodedMetrics = decoded['metrics'];
  if (decodedMetrics is! Map<String, Object?>) {
    throw StateError(
      '${benchmarkCase.id}/${scale.id} emitted invalid metrics.',
    );
  }
  final setupMetrics = decoded['setupMetrics'];
  if (setupMetrics is! Map<String, Object?>) {
    throw StateError(
      '${benchmarkCase.id}/${scale.id} emitted invalid setupMetrics.',
    );
  }
  final boundary = _decodeMeasurementBoundary(
    benchmarkCase,
    scale,
    decoded['measurementBoundary'],
  );
  final fixtureShape = decoded['fixtureShape'];
  if (fixtureShape != benchmarkCase.fixtureShape) {
    throw StateError(
      '${benchmarkCase.id}/${scale.id} emitted invalid fixtureShape.',
    );
  }
  final runtime = _decodeProbeRuntime(
    benchmarkCase,
    scale,
    decoded['runtime'],
    expectedProfileId: expectedProfileId,
  );
  return BenchmarkAdapterResult(
    actionUsSamples: actionUsSamples,
    setupUsSamples: setupUsSamples,
    metrics: decodedMetrics,
    setupMetrics: setupMetrics,
    measurementBoundary: boundary,
    fixtureShape: fixtureShape as String,
    runtime: runtime,
  );
}

List<int> _sampleList(
  BenchmarkCase benchmarkCase,
  BenchmarkScale scale,
  Map<String, Object?> decoded,
  String key,
) {
  final samples = decoded[key];
  if (samples is! List<Object?>) {
    throw StateError('${benchmarkCase.id}/${scale.id} emitted invalid $key.');
  }
  return [
    for (final value in samples)
      if (value is int) value else _invalidSample(key, value),
  ];
}

BenchmarkMeasurementBoundary _decodeMeasurementBoundary(
  BenchmarkCase benchmarkCase,
  BenchmarkScale scale,
  Object? boundary,
) {
  if (boundary is! Map<String, Object?>) {
    throw StateError(
      '${benchmarkCase.id}/${scale.id} emitted invalid measurementBoundary.',
    );
  }
  final setupScope = _boundaryString(
    benchmarkCase,
    scale,
    boundary,
    'setupScope',
  );
  final decoded = BenchmarkMeasurementBoundary(
    timedScope: _boundaryString(benchmarkCase, scale, boundary, 'timedScope'),
    setupScope: setupScope,
    teardownScope: _boundaryString(
      benchmarkCase,
      scale,
      boundary,
      'teardownScope',
    ),
    primaryTiming: _boundaryString(
      benchmarkCase,
      scale,
      boundary,
      'primaryTiming',
    ),
    primaryMemory: _boundaryString(
      benchmarkCase,
      scale,
      boundary,
      'primaryMemory',
    ),
    setupMetrics: _boundaryStringList(
      benchmarkCase,
      scale,
      boundary,
      'setupMetrics',
      allowEmpty: setupScope == 'none',
    ),
    setupMemoryMetrics: _boundaryStringList(
      benchmarkCase,
      scale,
      boundary,
      'setupMemoryMetrics',
      allowEmpty: setupScope == 'none',
    ),
  );
  if (!_sameBoundary(decoded, benchmarkCase.measurementBoundary)) {
    throw StateError(
      '${benchmarkCase.id}/${scale.id} emitted measurementBoundary drift.',
    );
  }
  return decoded;
}

bool _sameBoundary(
  BenchmarkMeasurementBoundary left,
  BenchmarkMeasurementBoundary right,
) {
  return left.timedScope == right.timedScope &&
      left.setupScope == right.setupScope &&
      left.teardownScope == right.teardownScope &&
      left.primaryTiming == right.primaryTiming &&
      left.primaryMemory == right.primaryMemory &&
      _sameStringList(left.setupMetrics, right.setupMetrics) &&
      _sameStringList(left.setupMemoryMetrics, right.setupMemoryMetrics);
}

bool _sameStringList(List<String> left, List<String> right) {
  if (left.length != right.length) {
    return false;
  }
  for (var index = 0; index < left.length; index++) {
    if (left[index] != right[index]) {
      return false;
    }
  }
  return true;
}

String _boundaryString(
  BenchmarkCase benchmarkCase,
  BenchmarkScale scale,
  Map<String, Object?> boundary,
  String key,
) {
  final value = boundary[key];
  if (value is String && value.isNotEmpty) {
    return value;
  }
  throw StateError(
    '${benchmarkCase.id}/${scale.id} emitted invalid measurementBoundary.$key.',
  );
}

List<String> _boundaryStringList(
  BenchmarkCase benchmarkCase,
  BenchmarkScale scale,
  Map<String, Object?> boundary,
  String key, {
  required bool allowEmpty,
}) {
  final values = boundary[key];
  if (values is! List<Object?>) {
    throw StateError(
      '${benchmarkCase.id}/${scale.id} emitted invalid measurementBoundary.$key.',
    );
  }
  if (values.isEmpty) {
    if (allowEmpty) {
      return const [];
    }
    throw StateError(
      '${benchmarkCase.id}/${scale.id} emitted invalid measurementBoundary.$key.',
    );
  }
  return [
    for (final value in values)
      if (value is String && value.isNotEmpty)
        value
      else
        throw StateError(
          '${benchmarkCase.id}/${scale.id} emitted invalid '
          'measurementBoundary.$key.',
        ),
  ];
}

BenchmarkProbeRuntime _decodeProbeRuntime(
  BenchmarkCase benchmarkCase,
  BenchmarkScale scale,
  Object? runtime, {
  String? expectedProfileId,
}) {
  if (runtime is! Map<String, Object?>) {
    throw StateError(
      '${benchmarkCase.id}/${scale.id} emitted invalid runtime metadata.',
    );
  }
  final profileId = _runtimeString(benchmarkCase, scale, runtime, 'profileId');
  if (expectedProfileId != null && profileId != expectedProfileId) {
    throw StateError(
      '${benchmarkCase.id}/${scale.id} emitted profileId $profileId '
      'for expected profile $expectedProfileId.',
    );
  }
  return BenchmarkProbeRuntime(
    profileId: profileId,
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

Never _invalidSample(String key, Object? value) {
  throw StateError('Benchmark probe emitted invalid $key sample $value.');
}
