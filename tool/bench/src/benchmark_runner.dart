import 'dart:convert';
import 'dart:io';

import 'benchmark_case_adapters.dart';
import 'benchmark_manifest.dart';
import 'benchmark_report.dart';
import 'manual_benchmark_history.dart';

const releaseReportPath =
    'build/bench/current/release_ubuntu_24_04_flutter_3_38_0.json';

const benchmarkRunUsage = '''
Usage: dart run tool/bench/run.dart --profile=<profile> [options]

Required:
  --profile=<profile>              Benchmark profile from the manifest.

Options:
  --output=<path>                  Report path under build/bench/**.
  --device=<id>                    Device id passed to real-device probes.
  --history-label=<label>          Archive a compact manual history entry.
  --history-device-name=<name>     Device name for the history entry.
  --history-device-id=<id>         Device id for the history entry.
  --history-device-os=<name>       Device OS for the history entry.
  --history-reference=<path>       Manual reference report to compare against.
  --history-baseline=<path>        Alias for --history-reference.
  --history-output=<path>          Explicit history output file.
  --history-root=<path>            History root directory.
  --history-subject-git-head=<sha> Subject commit recorded in history.
  --history-allow-dirty            Allow dirty working tree history capture.
  --history-overwrite              Replace an existing history output file.
  -h, --help                       Print this help and exit.
''';

bool isBenchmarkRunHelpRequest(List<String> args) {
  return args.length == 1 && (args.single == '--help' || args.single == '-h');
}

typedef BenchmarkCaseAdapter =
    BenchmarkAdapterResult Function(
      BenchmarkCase benchmarkCase,
      BenchmarkScale scale,
      BenchmarkProfile profile,
      BenchmarkDeviceTarget? deviceTarget,
    );

Future<String> runBenchmarkCli(
  List<String> args, {
  BenchmarkManifest? manifest,
}) async {
  final result = await runBenchmarkCliDetailed(args, manifest: manifest);
  return result.reportPath;
}

Future<BenchmarkRunCliResult> runBenchmarkCliDetailed(
  List<String> args, {
  BenchmarkManifest? manifest,
}) async {
  final options = BenchmarkRunOptions.parse(args);
  final loadedManifest = manifest ?? BenchmarkManifest.load();
  final outputPath = options.output ?? _defaultOutputPath(options.profile);
  _validateOutputPath(outputPath);
  final device = options.device;
  final report = runBenchmarks(
    manifest: loadedManifest,
    profileId: options.profile,
    deviceTarget: device == null ? null : BenchmarkDeviceTarget(device),
  );
  final outputFile = File(outputPath)..parent.createSync(recursive: true);
  outputFile.writeAsStringSync(
    const JsonEncoder.withIndent('  ').convert(report),
  );
  final historyPath = await _writeHistoryIfRequested(options, outputPath);
  return BenchmarkRunCliResult(
    reportPath: outputPath,
    historyPath: historyPath,
  );
}

Future<String?> _writeHistoryIfRequested(
  BenchmarkRunOptions options,
  String reportPath,
) {
  final history = options.history;
  if (history == null) {
    return Future.value();
  }
  return recordManualBenchmarkHistory(history.toHistoryOptions(reportPath));
}

final class BenchmarkRunCliResult {
  const BenchmarkRunCliResult({
    required this.reportPath,
    required this.historyPath,
  });

  final String reportPath;
  final String? historyPath;
}

// The runner builds one report from one manifest/profile pass; splitting the
// loop would separate case execution from the shared runtime metadata it owns.
// ignore: halstead-volume, source-lines-of-code
BenchmarkReport runBenchmarks({
  required BenchmarkManifest manifest,
  required String profileId,
  BenchmarkDeviceTarget? deviceTarget,
  BenchmarkCaseAdapter adapter = runBenchmarkAdapter,
}) {
  final profile = manifest.profilesById[profileId];
  if (profile == null) {
    throw FormatException('Unsupported benchmark profile "$profileId".');
  }

  final caseRuns = <_BenchmarkCaseRun>[];
  for (final benchmarkCase in manifest.cases) {
    for (final scale in benchmarkCase.scales) {
      if (!scale.profiles.contains(profileId)) {
        continue;
      }
      caseRuns.add(
        _runCase((
          benchmarkCase: benchmarkCase,
          scale: scale,
          profile: profile,
          deviceTarget: deviceTarget,
          adapter: adapter,
        )),
      );
    }
  }
  if (caseRuns.isEmpty) {
    throw FormatException('Profile "$profileId" selected no benchmark cases.');
  }
  final probeRuntime = _sharedProbeRuntime(caseRuns);
  final cases = [for (final run in caseRuns) run.report];

  return BenchmarkReport(
    schemaVersion: manifest.toolSchemaVersion,
    manifestVersion: manifest.manifestVersion,
    manifestFingerprint: benchmarkManifestFingerprint(manifest),
    profile: BenchmarkProfileReport(
      id: profile.id,
      warmups: profile.warmups,
      repetitions: profile.repetitions,
      iterations: profile.iterations,
      minimumMeasuredMs: profile.minimumMeasuredMs,
      minimumSamples: profile.minimumSamples,
      timingClaims: profile.timingClaims,
      scaleSelection: profile.scaleSelection,
    ),
    runtime: BenchmarkRuntimeReport(
      runnerLabel: _runnerLabel(manifest.releaseContour),
      osName: Platform.operatingSystem,
      osVersion: Platform.operatingSystemVersion,
      dartVersion: Platform.version,
      flutterChannel: _flutterChannel(),
      flutterVersion: _flutterVersion(),
      releaseContour: BenchmarkReleaseContourReport(
        runnerLabel: manifest.releaseContour.runnerLabel,
        osName: manifest.releaseContour.osName,
        osVersion: manifest.releaseContour.osVersion,
        flutterChannel: manifest.releaseContour.flutterChannel,
        flutterVersion: manifest.releaseContour.flutterVersion,
      ),
      profileId: profile.id,
      runtimeMode: probeRuntime.runtimeMode,
      assertionsEnabled: probeRuntime.assertionsEnabled,
      debugInvariantMode: probeRuntime.debugInvariantMode,
      deviceId: deviceTarget?.id,
    ),
    cases: cases,
  );
}

// A case run validates required metrics and exact invariants before report
// construction so the adapter boundary remains all-or-nothing per case.
// ignore: halstead-volume, source-lines-of-code
_BenchmarkCaseRun _runCase(
  ({
    BenchmarkCase benchmarkCase,
    BenchmarkScale scale,
    BenchmarkProfile profile,
    BenchmarkDeviceTarget? deviceTarget,
    BenchmarkCaseAdapter adapter,
  })
  input,
) {
  final benchmarkCase = input.benchmarkCase;
  final scale = input.scale;
  final profile = input.profile;
  final adapterResult = input.adapter(
    benchmarkCase,
    scale,
    profile,
    input.deviceTarget,
  );
  _validateAdapterBoundary(benchmarkCase, scale, adapterResult);
  final metrics = <String, Object?>{
    ...adapterResult.metrics,
    ..._timingMetrics(adapterResult.actionUsSamples),
  };
  final setupMetrics = <String, Object?>{...adapterResult.setupMetrics};
  _validateSetupDiagnostics(benchmarkCase, scale, setupMetrics);
  _applySetupTiming((
    adapterResult: adapterResult,
    metrics: metrics,
    setupMetrics: setupMetrics,
    caseKey: '${benchmarkCase.id}/${scale.id}',
    setupScope: benchmarkCase.measurementBoundary.setupScope,
  ));
  for (final metric in benchmarkCase.requiredMetrics) {
    if (!metrics.containsKey(metric)) {
      throw StateError(
        '${benchmarkCase.id}/${scale.id} missing metric $metric.',
      );
    }
  }
  _validatePrimaryMemoryMetrics(benchmarkCase, scale, metrics);
  final invariants = <String, BenchmarkInvariantReport>{};
  for (final invariant in benchmarkCase.exactInvariants) {
    final actual = metrics[invariant.metric];
    invariants[invariant.name] = BenchmarkInvariantReport(
      metric: invariant.metric,
      actual: actual,
      expected: invariant.expected,
      max: invariant.max,
      passed: _invariantPassed(
        benchmarkCase: benchmarkCase,
        scale: scale,
        metrics: metrics,
        invariant: invariant,
      ),
    );
  }
  if (invariants.values.any((invariant) => !invariant.passed)) {
    throw StateError('${benchmarkCase.id}/${scale.id} invariant failed.');
  }

  return _BenchmarkCaseRun(
    report: BenchmarkCaseReport(
      id: benchmarkCase.id,
      baselinePolicy: benchmarkCase.baselinePolicy,
      scale: scale.id,
      scaleLabel: scale.label,
      budgetClasses: benchmarkCase.budgetClasses,
      memoryScope: benchmarkCase.memoryScope,
      warmups: profile.warmups,
      repetitions: profile.repetitions,
      iterations: profile.iterations ?? 1,
      timingClaims: profile.timingClaims,
      measurementBoundary: adapterResult.measurementBoundary,
      fixtureShape: adapterResult.fixtureShape,
      actionUsSamples: adapterResult.actionUsSamples,
      setupUsSamples: adapterResult.setupUsSamples,
      metrics: metrics,
      setupMetrics: setupMetrics,
      exactInvariants: invariants,
    ),
    runtime: adapterResult.runtime,
  );
}

Map<String, int> _timingMetrics(List<int> samples) {
  final sortedSamples = [...samples]..sort();
  final p95Us = sortedSamples[((sortedSamples.length - 1) * 0.95).round()];
  final maxUs = sortedSamples.last;
  return {'avg_us': _avgUs(samples), 'p95_us': p95Us, 'max_us': maxUs};
}

void _applySetupTiming(
  ({
    BenchmarkAdapterResult adapterResult,
    Map<String, Object?> metrics,
    Map<String, Object?> setupMetrics,
    String caseKey,
    String setupScope,
  })
  input,
) {
  if (input.setupScope == 'none') {
    return;
  }
  if (input.adapterResult.setupUsSamples.isEmpty) {
    throw StateError('${input.caseKey} emitted no setup samples.');
  }
  final setupUs = _avgUs(input.adapterResult.setupUsSamples);
  if (input.setupMetrics['setup_us'] != setupUs) {
    throw StateError('${input.caseKey} invalid setup metric setup_us.');
  }
  input.metrics['setup_us'] = setupUs;
}

int _avgUs(List<int> samples) {
  return (samples.reduce((a, b) => a + b) / samples.length).round();
}

void _validateAdapterBoundary(
  BenchmarkCase benchmarkCase,
  BenchmarkScale scale,
  BenchmarkAdapterResult adapterResult,
) {
  final boundary = adapterResult.measurementBoundary;
  final expected = benchmarkCase.measurementBoundary;
  if (boundary.timedScope != expected.timedScope ||
      boundary.setupScope != expected.setupScope ||
      boundary.teardownScope != expected.teardownScope ||
      boundary.primaryTiming != expected.primaryTiming ||
      boundary.primaryMemory != expected.primaryMemory ||
      !_sameStringList(boundary.setupMetrics, expected.setupMetrics) ||
      !_sameStringList(
        boundary.setupMemoryMetrics,
        expected.setupMemoryMetrics,
      ) ||
      adapterResult.fixtureShape != benchmarkCase.fixtureShape) {
    throw StateError(
      '${benchmarkCase.id}/${scale.id} benchmark boundary metadata drift.',
    );
  }
  if (adapterResult.actionUsSamples.isEmpty) {
    throw StateError('${benchmarkCase.id}/${scale.id} missing action samples.');
  }
}

void _validateSetupDiagnostics(
  BenchmarkCase benchmarkCase,
  BenchmarkScale scale,
  Map<String, Object?> setupMetrics,
) {
  if (benchmarkCase.measurementBoundary.setupScope == 'none') {
    return;
  }
  final requiredSetupMetrics = [
    ...benchmarkCase.measurementBoundary.setupMetrics,
    ...benchmarkCase.measurementBoundary.setupMemoryMetrics,
  ];
  for (final metric in requiredSetupMetrics) {
    final value = setupMetrics[metric];
    if (value == null) {
      throw StateError(
        '${benchmarkCase.id}/${scale.id} missing setup metric $metric.',
      );
    }
    if (value is! num) {
      throw StateError(
        '${benchmarkCase.id}/${scale.id} invalid setup metric $metric.',
      );
    }
  }
}

void _validatePrimaryMemoryMetrics(
  BenchmarkCase benchmarkCase,
  BenchmarkScale scale,
  Map<String, Object?> metrics,
) {
  if (benchmarkCase.measurementBoundary.primaryMemory == 'none') {
    return;
  }
  for (final metric in const ['allocation_bytes', 'rss_delta_bytes']) {
    final value = metrics[metric];
    if (value == null) {
      throw StateError(
        '${benchmarkCase.id}/${scale.id} missing primary memory metric $metric.',
      );
    }
    if (value is! num) {
      throw StateError(
        '${benchmarkCase.id}/${scale.id} invalid primary memory metric $metric.',
      );
    }
  }
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

BenchmarkProbeRuntime _sharedProbeRuntime(List<_BenchmarkCaseRun> caseRuns) {
  final first = caseRuns.first.runtime;
  for (final run in caseRuns.skip(1)) {
    final runtime = run.runtime;
    if (runtime.profileId != first.profileId ||
        runtime.runtimeMode != first.runtimeMode ||
        runtime.assertionsEnabled != first.assertionsEnabled ||
        runtime.debugInvariantMode != first.debugInvariantMode) {
      throw StateError('Benchmark probes reported inconsistent runtime modes.');
    }
  }
  return first;
}

final class _BenchmarkCaseRun {
  const _BenchmarkCaseRun({required this.report, required this.runtime});

  final BenchmarkCaseReport report;
  final BenchmarkProbeRuntime runtime;
}

// Invariant semantics are intentionally centralized so adding a manifest
// invariant requires one explicit runner-side semantic decision.
// ignore: cyclomatic-complexity, halstead-volume
bool _invariantPassed({
  required BenchmarkCase benchmarkCase,
  required BenchmarkScale scale,
  required Map<String, Object?> metrics,
  required BenchmarkExactInvariant invariant,
}) {
  final actual = metrics[invariant.metric];
  final expected = invariant.expected;
  if (expected != null) {
    return actual == expected;
  }
  final max = invariant.max;
  if (max != null && actual is num) {
    return actual <= max;
  }
  return switch (invariant.name) {
    'selected_count_matches_input' =>
      actual == _boundedScaleForInvariant(scale.id, max: 16),
    'scene_repaint_count_bounded' => actual is num && actual <= 1,
    'overlay_repaint_count_bounded' => actual is num && actual <= 2,
    'point_count_matches_input' => actual == 2,
    'eraser_exact_checks_match_candidates' =>
      actual == metrics['candidate_count'],
    'resolver_calls_bounded' =>
      actual is num && actual <= _boundedScaleForInvariant(scale.id, max: 1000),
    'target_session_cache_invalidation_bounded' => actual is num && actual <= 1,
    'all_entry_session_cache_invalidation_bounded' =>
      actual is num && actual <= 2,
    'error_payload_matches_fixture' => actual == 'valid',
    'fallback_count_bounded' =>
      actual is num &&
          actual <= _boundedScaleForInvariant(scale.id, max: 10000),
    'rebuilt_pages_match_touched_set' =>
      actual == _boundedScaleForInvariant(scale.id, max: 64),
    _ => throw StateError(
      '${benchmarkCase.id}/${scale.id} invariant ${invariant.name} has no '
      'checkable expected value, max, or runner semantic.',
    ),
  };
}

// Scale normalization is a closed manifest mapping; keeping it as a switch
// makes unsupported benchmark scales fail at the runner boundary.
// ignore: cyclomatic-complexity
int _boundedScaleForInvariant(String scaleId, {required int max}) {
  final count = switch (scaleId) {
    '100k' => 100000,
    '50k' || 'dense_50k' || 'invalid_50k' => 50000,
    '10k' || 'invalid_10k' => 10000,
    '1k' ||
    'invalid_1k' ||
    '1k_resources' ||
    '1k_uncached_image_records' => 1000,
    'active_previews' || 'all_fixtures' => 1,
    _ => throw StateError('Unknown benchmark scale "$scaleId".'),
  };
  return count > max ? max : count;
}

String _runnerLabel(BenchmarkReleaseContour releaseContour) {
  final imageOs = Platform.environment['ImageOS'];
  if (imageOs == 'ubuntu24') {
    return releaseContour.runnerLabel;
  }
  return Platform.environment['RUNNER_OS'] ?? 'local';
}

String _flutterChannel() {
  final decoded = _flutterVersionMetadata();
  final channel = decoded['channel'];
  if (channel is String && channel.isNotEmpty) {
    return channel;
  }
  return 'unknown';
}

String _flutterVersion() {
  final decoded = _flutterVersionMetadata();
  final version = decoded['frameworkVersion'];
  if (version is String && version.isNotEmpty) {
    return version;
  }
  return 'unknown';
}

Map<String, Object?> _flutterVersionMetadata() {
  final cached = _cachedFlutterVersionMetadata;
  if (cached != null) {
    return cached;
  }
  final result = Process.runSync('flutter', ['--version', '--machine']);
  if (result.exitCode != 0) {
    return _cachedFlutterVersionMetadata = const {};
  }
  final stdoutText = result.stdout.toString();
  final Object? decoded;
  try {
    decoded = jsonDecode(stdoutText);
  } on FormatException {
    return _cachedFlutterVersionMetadata = const {};
  }
  if (decoded is Map<String, Object?>) {
    return _cachedFlutterVersionMetadata = decoded;
  }
  return _cachedFlutterVersionMetadata = const {};
}

Map<String, Object?>? _cachedFlutterVersionMetadata;

String _defaultOutputPath(String profile) {
  if (profile == 'release') {
    return releaseReportPath;
  }
  return 'build/bench/current/$profile.json';
}

void _validateOutputPath(String path) {
  final root = _withoutTrailingSlash(
    Directory('build/bench').absolute.uri.normalizePath().path,
  );
  final target = File(path).absolute.uri.normalizePath().path;
  final contained = target == root || target.startsWith('$root/');
  if (!contained) {
    throw FormatException(
      'Benchmark output must be under build/bench/**, got "$path".',
    );
  }
}

String _withoutTrailingSlash(String path) {
  return path.replaceFirst(RegExp(r'/$'), '');
}

final class BenchmarkRunOptions {
  const BenchmarkRunOptions({
    required this.profile,
    required this.output,
    required this.device,
    required this.history,
  });

  final String profile;
  final String? output;
  final String? device;
  final BenchmarkRunHistoryOptions? history;

  factory BenchmarkRunOptions.parse(List<String> args) {
    String? profile;
    String? output;
    String? device;
    final history = BenchmarkRunHistoryOptionsBuilder();
    for (final arg in args) {
      if (arg.startsWith('--profile=')) {
        profile = _argumentValue(arg, '--profile=');
      } else if (arg.startsWith('--output=')) {
        output = _argumentValue(arg, '--output=');
      } else if (arg.startsWith('--device=')) {
        device = _argumentValue(arg, '--device=');
      } else if (history.accepts(arg)) {
        history.add(arg);
      } else {
        throw FormatException('Unsupported benchmark runner argument "$arg".');
      }
    }
    if (profile == null || profile.isEmpty) {
      throw const FormatException('Missing required --profile=<profile>.');
    }
    if (device != null && device.isEmpty) {
      throw const FormatException('--device must not be empty.');
    }
    return BenchmarkRunOptions(
      profile: profile,
      output: output,
      device: device,
      history: history.build(defaultDeviceId: device),
    );
  }
}

final class BenchmarkRunHistoryOptions {
  const BenchmarkRunHistoryOptions({
    required this.label,
    required this.deviceName,
    required this.deviceId,
    required this.deviceOs,
    required this.referencePath,
    required this.output,
    required this.historyRoot,
    required this.subjectGitHead,
    required this.allowDirty,
    required this.overwrite,
  });

  final String label;
  final String? deviceName;
  final String? deviceId;
  final String? deviceOs;
  final String? referencePath;
  final String? output;
  final String historyRoot;
  final String? subjectGitHead;
  final bool allowDirty;
  final bool overwrite;

  ManualBenchmarkHistoryOptions toHistoryOptions(String reportPath) {
    return ManualBenchmarkHistoryOptions(
      label: label,
      reportPaths: [reportPath],
      deviceName: deviceName,
      deviceId: deviceId,
      deviceOs: deviceOs,
      referencePath: referencePath,
      output: output,
      historyRoot: historyRoot,
      subjectGitHead: subjectGitHead,
      allowDirty: allowDirty,
      overwrite: overwrite,
    );
  }
}

final class BenchmarkRunHistoryOptionsBuilder {
  final _values = <String, String>{};
  final _flags = <String>{};

  bool accepts(String arg) => arg.startsWith('--history-');

  void add(String arg) {
    const flagOptions = {'--history-allow-dirty', '--history-overwrite'};
    const valueOptions = {
      '--history-label',
      '--history-device-name',
      '--history-device-id',
      '--history-device-os',
      '--history-baseline',
      '--history-reference',
      '--history-output',
      '--history-root',
      '--history-subject-git-head',
    };
    if (flagOptions.contains(arg)) {
      _flags.add(arg);
      return;
    }
    final parts = arg.split('=');
    if (parts.length < 2) {
      throw FormatException('Unsupported benchmark runner argument "$arg".');
    }
    if (!valueOptions.contains(parts.first)) {
      throw FormatException('Unsupported benchmark runner argument "$arg".');
    }
    _values[parts.first] = parts.skip(1).join('=');
  }

  BenchmarkRunHistoryOptions? build({required String? defaultDeviceId}) {
    final label = _values['--history-label'];
    if (label == null) {
      return null;
    }
    if (label.isEmpty) {
      throw const FormatException('--history-label must not be empty.');
    }
    return BenchmarkRunHistoryOptions(
      label: label,
      deviceName: _values['--history-device-name'],
      deviceId: _values['--history-device-id'] ?? defaultDeviceId,
      deviceOs: _values['--history-device-os'],
      referencePath:
          _values['--history-reference'] ?? _values['--history-baseline'],
      output: _values['--history-output'],
      historyRoot: _values['--history-root'] ?? manualBenchmarkHistoryRoot,
      subjectGitHead: _values['--history-subject-git-head'],
      allowDirty: _flags.contains('--history-allow-dirty'),
      overwrite: _flags.contains('--history-overwrite'),
    );
  }
}

String _argumentValue(String argument, String prefix) {
  return argument.replaceFirst(prefix, '');
}
