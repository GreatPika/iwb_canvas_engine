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

final class _ProbeDecodeContext {
  const _ProbeDecodeContext({required this.benchmarkCase, required this.scale});

  final BenchmarkCase benchmarkCase;
  final BenchmarkScale scale;

  String get caseKey => '${benchmarkCase.id}/${scale.id}';
}

BenchmarkAdapterResult decodeBenchmarkProbeResult(
  BenchmarkCase benchmarkCase,
  BenchmarkScale scale,
  String stdout, {
  String? expectedProfileId,
}) {
  final context = _ProbeDecodeContext(
    benchmarkCase: benchmarkCase,
    scale: scale,
  );
  final decoded = _decodeProbePayload(context, stdout);
  final payload = _probePayloadFields(context, decoded);
  final runtime = _decodeProbeRuntime(
    context,
    decoded['runtime'],
    expectedProfileId: expectedProfileId,
  );

  return BenchmarkAdapterResult(
    actionUsSamples: payload.actionUsSamples,
    setupUsSamples: payload.setupUsSamples,
    metrics: payload.metrics,
    setupMetrics: payload.setupMetrics,
    measurementBoundary: payload.boundary,
    fixtureShape: payload.fixtureShape,
    runtime: runtime,
  );
}

Map<String, Object?> _decodeProbePayload(
  _ProbeDecodeContext context,
  String stdout,
) {
  final jsonLine = stdout
      .split('\n')
      .lastWhere(
        (line) => line.startsWith(_probeJsonPrefix),
        orElse: () =>
            throw StateError('${context.caseKey} emitted no probe JSON.'),
      )
      .replaceFirst(_probeJsonPrefix, '');
  final decoded = jsonDecode(jsonLine) as Map<String, Object?>;
  if (decoded.containsKey('elapsedUsSamples')) {
    throw StateError('${context.caseKey} old elapsedUsSamples probe payload.');
  }
  final probeSchemaVersion = decoded['probeSchemaVersion'];
  if (probeSchemaVersion != benchmarkToolSchemaVersion) {
    throw StateError('${context.caseKey} emitted invalid probeSchemaVersion.');
  }

  return decoded;
}

({
  List<int> actionUsSamples,
  List<int> setupUsSamples,
  Map<String, Object?> metrics,
  Map<String, Object?> setupMetrics,
  BenchmarkMeasurementBoundary boundary,
  String fixtureShape,
})
_probePayloadFields(_ProbeDecodeContext context, Map<String, Object?> decoded) {
  final actionUsSamples = _sampleList(context, decoded, 'actionUsSamples');
  if (actionUsSamples.isEmpty) {
    throw StateError('${context.caseKey} emitted no samples.');
  }
  final setupUsSamples = _sampleList(context, decoded, 'setupUsSamples');
  final decodedMetrics = _objectMap(context, decoded, 'metrics');
  final setupMetrics = _objectMap(context, decoded, 'setupMetrics');
  final boundary = _decodeMeasurementBoundary(
    context,
    decoded['measurementBoundary'],
  );
  final fixtureShape = decoded['fixtureShape'];
  if (fixtureShape != context.benchmarkCase.fixtureShape) {
    throw StateError('${context.caseKey} emitted invalid fixtureShape.');
  }

  return (
    actionUsSamples: actionUsSamples,
    setupUsSamples: setupUsSamples,
    metrics: decodedMetrics,
    setupMetrics: setupMetrics,
    boundary: boundary,
    fixtureShape: fixtureShape as String,
  );
}

List<int> _sampleList(
  _ProbeDecodeContext context,
  Map<String, Object?> decoded,
  String key,
) {
  final samples = decoded[key];
  if (samples is! List<Object?>) {
    throw StateError('${context.caseKey} emitted invalid $key.');
  }
  return [
    for (final value in samples)
      if (value is int) value else _invalidSample(key, value),
  ];
}

Map<String, Object?> _objectMap(
  _ProbeDecodeContext context,
  Map<String, Object?> decoded,
  String key,
) {
  final value = decoded[key];
  if (value is Map<String, Object?>) {
    return value;
  }

  throw StateError('${context.caseKey} emitted invalid $key.');
}

BenchmarkMeasurementBoundary _decodeMeasurementBoundary(
  _ProbeDecodeContext context,
  Object? boundary,
) {
  if (boundary is! Map<String, Object?>) {
    throw StateError('${context.caseKey} emitted invalid measurementBoundary.');
  }
  final setupScope = _boundaryString(context, boundary, 'setupScope');
  final decoded = BenchmarkMeasurementBoundary(
    timedScope: _boundaryString(context, boundary, 'timedScope'),
    setupScope: setupScope,
    teardownScope: _boundaryString(context, boundary, 'teardownScope'),
    primaryTiming: _boundaryString(context, boundary, 'primaryTiming'),
    primaryMemory: _boundaryString(context, boundary, 'primaryMemory'),
    setupMetrics: _boundaryStringList((
      context: context,
      boundary: boundary,
      key: 'setupMetrics',
      allowEmpty: setupScope == 'none',
    )),
    setupMemoryMetrics: _boundaryStringList((
      context: context,
      boundary: boundary,
      key: 'setupMemoryMetrics',
      allowEmpty: setupScope == 'none',
    )),
  );
  if (!_sameBoundary(decoded, context.benchmarkCase.measurementBoundary)) {
    throw StateError('${context.caseKey} emitted measurementBoundary drift.');
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
  _ProbeDecodeContext context,
  Map<String, Object?> boundary,
  String key,
) {
  final value = boundary[key];
  if (value is String && value.isNotEmpty) {
    return value;
  }
  throw StateError(
    '${context.caseKey} emitted invalid measurementBoundary.$key.',
  );
}

List<String> _boundaryStringList(
  ({
    _ProbeDecodeContext context,
    Map<String, Object?> boundary,
    String key,
    bool allowEmpty,
  })
  input,
) {
  final values = input.boundary[input.key];
  if (values is! List<Object?>) {
    throw StateError(
      '${input.context.caseKey} emitted invalid measurementBoundary.${input.key}.',
    );
  }
  if (values.isEmpty) {
    if (input.allowEmpty) {
      return const [];
    }
    throw StateError(
      '${input.context.caseKey} emitted invalid measurementBoundary.${input.key}.',
    );
  }
  return [
    for (final value in values)
      if (value is String && value.isNotEmpty)
        value
      else
        throw StateError(
          '${input.context.caseKey} emitted invalid '
          'measurementBoundary.${input.key}.',
        ),
  ];
}

BenchmarkProbeRuntime _decodeProbeRuntime(
  _ProbeDecodeContext context,
  Object? runtime, {
  String? expectedProfileId,
}) {
  if (runtime is! Map<String, Object?>) {
    throw StateError('${context.caseKey} emitted invalid runtime metadata.');
  }
  final profileId = _runtimeString(context, runtime, 'profileId');
  if (expectedProfileId != null && profileId != expectedProfileId) {
    throw StateError(
      '${context.caseKey} emitted profileId $profileId '
      'for expected profile $expectedProfileId.',
    );
  }
  return BenchmarkProbeRuntime(
    profileId: profileId,
    runtimeMode: _runtimeString(context, runtime, 'runtimeMode'),
    assertionsEnabled: _runtimeBool(context, runtime, 'assertionsEnabled'),
    debugInvariantMode: _runtimeBool(context, runtime, 'debugInvariantMode'),
  );
}

String _runtimeString(
  _ProbeDecodeContext context,
  Map<String, Object?> runtime,
  String key,
) {
  final value = runtime[key];
  if (value is String && value.isNotEmpty) {
    return value;
  }
  throw StateError('${context.caseKey} emitted invalid $key.');
}

bool _runtimeBool(
  _ProbeDecodeContext context,
  Map<String, Object?> runtime,
  String key,
) {
  final value = runtime[key];
  if (value is bool) {
    return value;
  }
  throw StateError('${context.caseKey} emitted invalid $key.');
}

Never _invalidSample(String key, Object? value) {
  throw StateError('Benchmark probe emitted invalid $key sample $value.');
}
