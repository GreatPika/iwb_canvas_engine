import 'dart:convert';
import 'dart:io';

import 'benchmark_case_adapters.dart';
import 'benchmark_manifest.dart';
import 'benchmark_report.dart';

const releaseReportPath =
    'build/bench/current/release_ubuntu_24_04_flutter_3_38_0.json';

Future<String> runBenchmarkCli(
  List<String> args, {
  BenchmarkManifest? manifest,
}) async {
  final options = BenchmarkRunOptions.parse(args);
  final loadedManifest = manifest ?? BenchmarkManifest.load();
  final outputPath = options.output ?? _defaultOutputPath(options.profile);
  _validateOutputPath(outputPath);
  final report = runBenchmarks(
    manifest: loadedManifest,
    profileId: options.profile,
  );
  final outputFile = File(outputPath)..parent.createSync(recursive: true);
  outputFile.writeAsStringSync(
    const JsonEncoder.withIndent('  ').convert(report),
  );
  return outputPath;
}

// The runner builds one report from one manifest/profile pass; splitting the
// loop would separate case execution from the shared runtime metadata it owns.
// ignore: halstead-volume, source-lines-of-code
BenchmarkReport runBenchmarks({
  required BenchmarkManifest manifest,
  required String profileId,
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
      caseRuns.add(_runCase(benchmarkCase, scale, profile));
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
      runtimeMode: probeRuntime.runtimeMode,
      assertionsEnabled: probeRuntime.assertionsEnabled,
      debugInvariantMode: probeRuntime.debugInvariantMode,
    ),
    cases: cases,
  );
}

// A case run validates required metrics and exact invariants before report
// construction so the adapter boundary remains all-or-nothing per case.
// ignore: halstead-volume, source-lines-of-code
_BenchmarkCaseRun _runCase(
  BenchmarkCase benchmarkCase,
  BenchmarkScale scale,
  BenchmarkProfile profile,
) {
  final adapterResult = runBenchmarkAdapter(benchmarkCase, scale, profile);
  final metrics = <String, Object?>{};
  for (final metric in benchmarkCase.requiredMetrics) {
    if (!adapterResult.metrics.containsKey(metric)) {
      throw StateError(
        '${benchmarkCase.id}/${scale.id} missing metric $metric.',
      );
    }
  }
  metrics.addAll(adapterResult.metrics);
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
      classification: benchmarkCase.classification,
      scale: scale.id,
      scaleLabel: scale.label,
      budgetClasses: benchmarkCase.budgetClasses,
      memoryScope: benchmarkCase.memoryScope,
      warmups: profile.warmups,
      repetitions: profile.repetitions,
      iterations: profile.iterations ?? 1,
      timingClaims: profile.timingClaims,
      metrics: metrics,
      exactInvariants: invariants,
    ),
    runtime: adapterResult.runtime,
  );
}

BenchmarkProbeRuntime _sharedProbeRuntime(List<_BenchmarkCaseRun> caseRuns) {
  final first = caseRuns.first.runtime;
  for (final run in caseRuns.skip(1)) {
    final runtime = run.runtime;
    if (runtime.runtimeMode != first.runtimeMode ||
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
    'overlay_repaint_count_bounded' => actual is num && actual <= 1,
    'point_count_matches_input' => actual == 2,
    'eraser_exact_checks_match_candidates' =>
      actual == metrics['candidate_count'],
    'resolver_calls_bounded' =>
      actual is num && actual <= _boundedScaleForInvariant(scale.id, max: 1000),
    'target_session_cache_invalidation_bounded' => actual is num && actual <= 1,
    'all_entry_session_cache_invalidation_bounded' =>
      actual is num && actual <= 1,
    'error_payload_matches_fixture' => actual == 'valid',
    'fallback_count_bounded' => actual is num && actual <= 0,
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
  const BenchmarkRunOptions({required this.profile, required this.output});

  final String profile;
  final String? output;

  factory BenchmarkRunOptions.parse(List<String> args) {
    String? profile;
    String? output;
    for (final arg in args) {
      if (arg.startsWith('--profile=')) {
        profile = _argumentValue(arg, '--profile=');
      } else if (arg.startsWith('--output=')) {
        output = _argumentValue(arg, '--output=');
      } else {
        throw FormatException('Unsupported benchmark runner argument "$arg".');
      }
    }
    if (profile == null || profile.isEmpty) {
      throw const FormatException('Missing required --profile=<profile>.');
    }
    return BenchmarkRunOptions(profile: profile, output: output);
  }
}

String _argumentValue(String argument, String prefix) {
  return argument.replaceFirst(prefix, '');
}
