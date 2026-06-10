import 'dart:convert';
import 'dart:io';

import 'benchmark_manifest.dart';
import 'benchmark_report.dart';
import 'benchmark_sample_summary.dart';

const approvedReleaseBaselinePath =
    'tool/bench/baselines/approved/release_ubuntu_24_04_flutter_3_44_0.json';

const manualBenchmarkReferenceRoot = 'tool/bench/manual/reference_reports';

const releaseCurrentReportPath =
    'build/bench/current/release_ubuntu_24_04_flutter_3_44_0.json';

const releaseDiffPath =
    'build/bench/diff/release_ubuntu_24_04_flutter_3_44_0.json';

const releaseCandidateRoot =
    'build/bench/candidates/release_ubuntu_24_04_flutter_3_44_0';

const benchmarkCurrentRoot = 'build/bench/current';
const schemaImportLoadSuccess50kMaxUs = 574000;

final class BenchmarkDiffOptions {
  const BenchmarkDiffOptions({
    required this.profile,
    required this.baseline,
    required this.current,
    required this.output,
  });

  final String profile;
  final String baseline;
  final String current;
  final String output;

  factory BenchmarkDiffOptions.parse(List<String> args) {
    final values = _parseNamedArgs(
      args,
      requiredKeys: const {'profile', 'baseline', 'current', 'output'},
    );
    return BenchmarkDiffOptions(
      profile: values['profile']!,
      baseline: values['baseline']!,
      current: values['current']!,
      output: values['output']!,
    );
  }
}

final class BenchmarkBaselineUpdateOptions {
  const BenchmarkBaselineUpdateOptions({
    required this.profile,
    required this.candidate,
    required this.approved,
  });

  final String profile;
  final String candidate;
  final String approved;

  factory BenchmarkBaselineUpdateOptions.parse(List<String> args) {
    final values = _parseNamedArgs(
      args,
      requiredKeys: const {'profile', 'candidate', 'approved'},
    );
    return BenchmarkBaselineUpdateOptions(
      profile: values['profile']!,
      candidate: values['candidate']!,
      approved: values['approved']!,
    );
  }
}

final class BenchmarkDiffResult {
  const BenchmarkDiffResult({
    required this.status,
    required this.failures,
    required this.report,
  });

  final String status;
  final List<String> failures;
  final Map<String, Object?> report;

  bool get passed => status == 'pass';
}

// Keep the top-level diff pipeline together so baseline/current validation,
// contour comparison, and regression reporting stay in the same failure order.
// ignore: halstead-volume, number-of-parameters, source-lines-of-code
BenchmarkDiffResult diffBenchmarkReports({
  required BenchmarkManifest manifest,
  required String profile,
  required Map<String, Object?> baselineJson,
  required Map<String, Object?> currentJson,
  required String baselinePath,
  required String currentPath,
  bool enforceAbsoluteCaps = true,
}) {
  final unavailableFailure = _unavailableBaselineFailure(baselineJson);
  if (unavailableFailure != null) {
    return _result(
      profile: profile,
      operation: 'diff',
      baselinePath: baselinePath,
      currentPath: currentPath,
      failures: [unavailableFailure],
      comparedCaseCount: 0,
    );
  }
  final baseline = ParsedBenchmarkReport.parse(baselineJson, baselinePath);
  final current = ParsedBenchmarkReport.parse(currentJson, currentPath);
  final failures = <String>[];
  failures.addAll(
    _validateReportForPolicy(
      manifest: manifest,
      report: baseline,
      profile: profile,
      sourceRole: 'baseline',
      requireReferenceBaselineMetrics: false,
      requireFirstBaselineMemoryCaps: false,
      requireCasePolicyFields: false,
      requireSamples: false,
      requireObservedReleaseContour: false,
      enforceAbsoluteCaps: enforceAbsoluteCaps,
    ),
  );
  failures.addAll(
    _validateReportForPolicy(
      manifest: manifest,
      report: current,
      profile: profile,
      sourceRole: 'current',
      requireReferenceBaselineMetrics: false,
      requireFirstBaselineMemoryCaps: false,
      requireCasePolicyFields: true,
      requireSamples: true,
      requireObservedReleaseContour: false,
      enforceAbsoluteCaps: enforceAbsoluteCaps,
    ),
  );
  if (failures.isEmpty) {
    failures.addAll(_validateSameContour(baseline: baseline, current: current));
    failures.addAll(
      _compareAgainstApprovedBaseline(
        manifest: manifest,
        baseline: baseline,
        current: current,
      ),
    );
  }

  return _result(
    profile: profile,
    operation: 'diff',
    baselinePath: baselinePath,
    currentPath: currentPath,
    failures: failures,
    comparedCaseCount: current.casesByKey.keys
        .toSet()
        .intersection(baseline.casesByKey.keys.toSet())
        .length,
  );
}

String? _unavailableBaselineFailure(Map<String, Object?> baselineJson) {
  final status = baselineJson['status'];
  final message = baselineJson['message'];
  final suffix = message is String && message.isNotEmpty ? ': $message' : '';
  if (status == 'unapproved') {
    return 'approved baseline is not initialized$suffix';
  }
  if (status == 'invalidated_old_schema') {
    return 'benchmark baseline is invalidated old schema$suffix';
  }
  return null;
}

BenchmarkDiffResult validateFirstBaselineCandidate({
  required BenchmarkManifest manifest,
  required String profile,
  required Map<String, Object?> candidateJson,
  required String candidatePath,
}) {
  final candidate = ParsedBenchmarkReport.parse(candidateJson, candidatePath);
  final failures = _validateReportForPolicy(
    manifest: manifest,
    report: candidate,
    profile: profile,
    sourceRole: 'candidate',
    requireReferenceBaselineMetrics: true,
    requireFirstBaselineMemoryCaps: true,
    requireCasePolicyFields: true,
    requireSamples: true,
    requireObservedReleaseContour: true,
    enforceAbsoluteCaps: true,
  );

  return _result(
    profile: profile,
    operation: 'first_baseline_acceptance',
    baselinePath: null,
    currentPath: candidatePath,
    failures: failures,
    comparedCaseCount: candidate.casesByKey.length,
  );
}

Future<int> runBenchmarkDiffCli(
  List<String> args, {
  BenchmarkManifest? manifest,
}) async {
  final options = BenchmarkDiffOptions.parse(args);
  if (options.profile != 'release') {
    throw const FormatException(
      'Benchmark diff supports only profile=release.',
    );
  }
  _validateDiffBaselinePath(options.baseline);
  _validateCurrentReleaseReportPath(options.current);
  _validateTransientOutputPath(options.output);
  final loadedManifest = manifest ?? BenchmarkManifest.load();
  final result = diffBenchmarkReports(
    manifest: loadedManifest,
    profile: options.profile,
    baselineJson: _readJsonObject(options.baseline),
    currentJson: _readJsonObject(options.current),
    baselinePath: options.baseline,
    currentPath: options.current,
    enforceAbsoluteCaps: !_isManualBaselinePath(options.baseline),
  );
  _writeJsonObject(options.output, result.report);
  if (!result.passed) {
    stderr.writeln('FAIL: benchmark diff policy violations detected.');
    for (final failure in result.failures) {
      stderr.writeln('- $failure');
    }
    return 1;
  }
  stdout.writeln('Benchmark diff report written: ${options.output}');
  return 0;
}

Future<int> runBenchmarkBaselineUpdateCli(
  List<String> args, {
  BenchmarkManifest? manifest,
}) async {
  final options = BenchmarkBaselineUpdateOptions.parse(args);
  if (options.profile != 'release') {
    throw const FormatException(
      'Baseline update supports only profile=release.',
    );
  }
  _validateApprovedBaselineWritePath(options.approved);
  _validateBaselineUpdateCandidatePath(options.candidate);
  final candidateJson = _readJsonObject(options.candidate);
  final result = _validateBaselineUpdateCandidate(
    options: options,
    manifest: manifest ?? BenchmarkManifest.load(),
    candidateJson: candidateJson,
  );
  if (!result.passed) {
    stderr.writeln('FAIL: candidate baseline rejected.');
    for (final failure in result.failures) {
      stderr.writeln('- $failure');
    }
    return 1;
  }
  _writeApprovedBaseline(options, candidateJson);
  stdout.writeln('Benchmark baseline written: ${options.approved}');
  return 0;
}

BenchmarkDiffResult _validateBaselineUpdateCandidate({
  required BenchmarkBaselineUpdateOptions options,
  required BenchmarkManifest manifest,
  required Map<String, Object?> candidateJson,
}) {
  return validateFirstBaselineCandidate(
    manifest: manifest,
    profile: options.profile,
    candidateJson: candidateJson,
    candidatePath: options.candidate,
  );
}

void _writeApprovedBaseline(
  BenchmarkBaselineUpdateOptions options,
  Map<String, Object?> candidateJson,
) {
  _writeJsonObject(
    options.approved,
    approvedBaselinePayload(candidateJson, sourcePath: options.candidate),
  );
}

Map<String, Object?> approvedBaselinePayload(
  Map<String, Object?> candidateJson, {
  required String sourcePath,
}) {
  final candidate = ParsedBenchmarkReport.parse(candidateJson, sourcePath);
  return {
    'schemaVersion': candidate.schemaVersion,
    'manifestVersion': candidate.manifestVersion,
    'manifestFingerprint': candidate.manifestFingerprint,
    'profile': candidate.profile.toJson(),
    'runtime': candidate.runtime.toJson(),
    'sourceReport': benchmarkSourceFingerprint(sourcePath),
    'caseCount': candidate.cases.length,
    'cases': [
      for (final benchmarkCase in candidate.cases)
        benchmarkCase.toBaselineJson(),
    ],
  };
}

final class ParsedBenchmarkReport {
  const ParsedBenchmarkReport({
    required this.source,
    required this.schemaVersion,
    required this.manifestVersion,
    required this.manifestFingerprint,
    required this.profile,
    required this.runtime,
    required this.cases,
  });

  final String source;
  final int schemaVersion;
  final String manifestVersion;
  final String manifestFingerprint;
  final ParsedProfileReport profile;
  final ParsedRuntimeReport runtime;
  final List<ParsedCaseReport> cases;

  Map<String, ParsedCaseReport> get casesByKey => {
    for (final benchmarkCase in cases) benchmarkCase.key: benchmarkCase,
  };

  factory ParsedBenchmarkReport.parse(
    Map<String, Object?> json,
    String source,
  ) {
    final profile = _map(json, 'profile', source);
    final runtime = _map(json, 'runtime', source);
    final cases = _list(json, 'cases', source);
    final parsedCases = [
      for (final entry in cases)
        ParsedCaseReport.parse(
          _requireMap(entry, '$source cases item'),
          source,
        ),
    ];
    final caseCount = _int(json, 'caseCount', source);
    if (caseCount != parsedCases.length) {
      throw FormatException(
        '$source caseCount=$caseCount does not match cases length '
        '${parsedCases.length}.',
      );
    }
    return ParsedBenchmarkReport(
      source: source,
      schemaVersion: _int(json, 'schemaVersion', source),
      manifestVersion: _string(json, 'manifestVersion', source),
      manifestFingerprint: _string(json, 'manifestFingerprint', source),
      profile: ParsedProfileReport.parse(profile, source),
      runtime: ParsedRuntimeReport.parse(runtime, source),
      cases: parsedCases,
    );
  }
}

final class ParsedProfileReport {
  const ParsedProfileReport({
    required this.id,
    required this.warmups,
    required this.repetitions,
    required this.iterations,
    required this.minimumMeasuredMs,
    required this.minimumSamples,
    required this.timingClaims,
    required this.scaleSelection,
  });

  final String id;
  final int warmups;
  final int repetitions;
  final int? iterations;
  final int minimumMeasuredMs;
  final int minimumSamples;
  final bool timingClaims;
  final String scaleSelection;

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'warmups': warmups,
      'repetitions': repetitions,
      'iterations': iterations,
      'minimumMeasuredMs': minimumMeasuredMs,
      'minimumSamples': minimumSamples,
      'timingClaims': timingClaims,
      'scaleSelection': scaleSelection,
    };
  }

  factory ParsedProfileReport.parse(Map<String, Object?> json, String source) {
    return ParsedProfileReport(
      id: _string(json, 'id', '$source profile'),
      warmups: _int(json, 'warmups', '$source profile'),
      repetitions: _int(json, 'repetitions', '$source profile'),
      iterations: _optionalInt(json, 'iterations', '$source profile'),
      minimumMeasuredMs: _int(json, 'minimumMeasuredMs', '$source profile'),
      minimumSamples: _int(json, 'minimumSamples', '$source profile'),
      timingClaims: _bool(json, 'timingClaims', '$source profile'),
      scaleSelection: _string(json, 'scaleSelection', '$source profile'),
    );
  }
}

final class ParsedRuntimeReport {
  const ParsedRuntimeReport({
    required this.runnerLabel,
    required this.osName,
    required this.osVersion,
    required this.dartVersion,
    required this.flutterChannel,
    required this.flutterVersion,
    required this.releaseContour,
    required this.runtimeMode,
    required this.assertionsEnabled,
    required this.debugInvariantMode,
    required this.deviceId,
  });

  final String runnerLabel;
  final String osName;
  final String osVersion;
  final String dartVersion;
  final String flutterChannel;
  final String flutterVersion;
  final ParsedReleaseContour releaseContour;
  final String runtimeMode;
  final bool assertionsEnabled;
  final bool debugInvariantMode;
  final String? deviceId;

  Map<String, Object?> toJson() {
    return {
      'runnerLabel': runnerLabel,
      'osName': osName,
      'osVersion': osVersion,
      'dartVersion': dartVersion,
      'flutterChannel': flutterChannel,
      'flutterVersion': flutterVersion,
      'releaseContour': releaseContour.toJson(),
      'runtimeMode': runtimeMode,
      'assertionsEnabled': assertionsEnabled,
      'debugInvariantMode': debugInvariantMode,
      'deviceId': deviceId,
    };
  }

  Map<String, Object?> toComparableJson() {
    return {
      'runnerLabel': runnerLabel,
      'osName': osName,
      'osVersion': osVersion,
      'dartVersion': dartVersion,
      'flutterChannel': flutterChannel,
      'flutterVersion': flutterVersion,
      'runtimeMode': runtimeMode,
      'assertionsEnabled': assertionsEnabled,
      'debugInvariantMode': debugInvariantMode,
      'deviceId': deviceId,
      'releaseContour': releaseContour.toJson(),
    };
  }

  factory ParsedRuntimeReport.parse(Map<String, Object?> json, String source) {
    return ParsedRuntimeReport(
      runnerLabel: _string(json, 'runnerLabel', '$source runtime'),
      osName: _string(json, 'osName', '$source runtime'),
      osVersion: _string(json, 'osVersion', '$source runtime'),
      dartVersion: _string(json, 'dartVersion', '$source runtime'),
      flutterChannel: _string(json, 'flutterChannel', '$source runtime'),
      flutterVersion: _string(json, 'flutterVersion', '$source runtime'),
      releaseContour: ParsedReleaseContour.parse(
        _map(json, 'releaseContour', '$source runtime'),
        source,
      ),
      runtimeMode: _string(json, 'runtimeMode', '$source runtime'),
      assertionsEnabled: _bool(json, 'assertionsEnabled', '$source runtime'),
      debugInvariantMode: _bool(json, 'debugInvariantMode', '$source runtime'),
      deviceId: _optionalString(json, 'deviceId', '$source runtime'),
    );
  }
}

final class ParsedReleaseContour {
  const ParsedReleaseContour({
    required this.runnerLabel,
    required this.osName,
    required this.osVersion,
    required this.flutterChannel,
    required this.flutterVersion,
  });

  final String runnerLabel;
  final String osName;
  final String osVersion;
  final String flutterChannel;
  final String flutterVersion;

  Map<String, Object?> toJson() {
    return {
      'runnerLabel': runnerLabel,
      'osName': osName,
      'osVersion': osVersion,
      'flutterChannel': flutterChannel,
      'flutterVersion': flutterVersion,
    };
  }

  factory ParsedReleaseContour.parse(Map<String, Object?> json, String source) {
    return ParsedReleaseContour(
      runnerLabel: _string(json, 'runnerLabel', '$source releaseContour'),
      osName: _string(json, 'osName', '$source releaseContour'),
      osVersion: _string(json, 'osVersion', '$source releaseContour'),
      flutterChannel: _string(json, 'flutterChannel', '$source releaseContour'),
      flutterVersion: _string(json, 'flutterVersion', '$source releaseContour'),
    );
  }
}

final class ParsedCaseReport {
  const ParsedCaseReport({
    required this.id,
    required this.baselinePolicy,
    required this.scale,
    required this.budgetClasses,
    required this.memoryScope,
    required this.measurementBoundary,
    required this.fixtureShape,
    required this.actionUsSamples,
    required this.setupUsSamples,
    required this.metrics,
    required this.setupMetrics,
    required this.exactInvariants,
  });

  final String id;
  final String? baselinePolicy;
  final String scale;
  final List<String>? budgetClasses;
  final String? memoryScope;
  final ParsedMeasurementBoundary? measurementBoundary;
  final String? fixtureShape;
  final List<int>? actionUsSamples;
  final List<int>? setupUsSamples;
  final Map<String, Object?> metrics;
  final Map<String, Object?>? setupMetrics;
  final Map<String, ParsedInvariantReport> exactInvariants;

  String get key => '$id/$scale';

  factory ParsedCaseReport.parse(Map<String, Object?> json, String source) {
    final caseSource = '$source case';
    _rejectRetiredCaseFields(json, caseSource);
    final metadata = _parseCaseMetadata(json, caseSource);
    final samples = _parseCaseSamples(json, caseSource);
    final metrics = Map<String, Object?>.from(
      _map(json, 'metrics', caseSource),
    );
    _rejectRetiredMetricFields(metrics, caseSource);
    return ParsedCaseReport(
      id: metadata.id,
      baselinePolicy: metadata.baselinePolicy,
      scale: metadata.scale,
      budgetClasses: metadata.budgetClasses,
      memoryScope: metadata.memoryScope,
      measurementBoundary: metadata.measurementBoundary,
      fixtureShape: metadata.fixtureShape,
      actionUsSamples: samples.actionUsSamples,
      setupUsSamples: samples.setupUsSamples,
      metrics: metrics,
      setupMetrics: _optionalMap(json, 'setupMetrics', caseSource),
      exactInvariants: _parseExactInvariants(json, source, caseSource),
    );
  }

  Map<String, Object?> toBaselineJson() {
    return {
      'id': id,
      'scale': scale,
      'measurementBoundary': measurementBoundary?.toJson(),
      'fixtureShape': fixtureShape,
      'sampleSummary': {
        'actionUs': benchmarkSampleSummary(actionUsSamples),
        'setupUs': benchmarkSampleSummary(setupUsSamples),
      },
      'metrics': metrics,
      'setupMetrics': setupMetrics,
      'exactInvariants': {
        for (final entry in exactInvariants.entries)
          entry.key: entry.value.toBaselineJson(),
      },
    };
  }
}

void _rejectRetiredCaseFields(Map<String, Object?> json, String source) {
  for (final field in const ['classification']) {
    if (json.containsKey(field)) {
      throw FormatException('$source uses retired field $field');
    }
  }
}

void _rejectRetiredMetricFields(Map<String, Object?> metrics, String source) {
  for (final field in const ['legacy_avg_us']) {
    if (metrics.containsKey(field)) {
      throw FormatException('$source uses retired metric $field');
    }
  }
}

({
  String id,
  String? baselinePolicy,
  String scale,
  List<String>? budgetClasses,
  String? memoryScope,
  ParsedMeasurementBoundary? measurementBoundary,
  String? fixtureShape,
})
_parseCaseMetadata(Map<String, Object?> json, String caseSource) {
  return (
    id: _string(json, 'id', caseSource),
    baselinePolicy: _optionalString(json, 'baselinePolicy', caseSource),
    scale: _string(json, 'scale', caseSource),
    budgetClasses: _optionalStringList(json, 'budgetClasses', caseSource),
    memoryScope: _optionalString(json, 'memoryScope', caseSource),
    measurementBoundary: ParsedMeasurementBoundary.parseOptional(
      json,
      caseSource,
    ),
    fixtureShape: _optionalString(json, 'fixtureShape', caseSource),
  );
}

({List<int>? actionUsSamples, List<int>? setupUsSamples}) _parseCaseSamples(
  Map<String, Object?> json,
  String caseSource,
) {
  return (
    actionUsSamples: _optionalIntList(json, 'actionUsSamples', caseSource),
    setupUsSamples: _optionalIntList(json, 'setupUsSamples', caseSource),
  );
}

Map<String, ParsedInvariantReport> _parseExactInvariants(
  Map<String, Object?> json,
  String source,
  String caseSource,
) {
  return {
    for (final entry in _map(json, 'exactInvariants', caseSource).entries)
      entry.key: ParsedInvariantReport.parse(
        _requireMap(entry.value, '$source exact invariant ${entry.key}'),
        source,
      ),
  };
}

final class ParsedMeasurementBoundary {
  const ParsedMeasurementBoundary({
    required this.timedScope,
    required this.setupScope,
    required this.teardownScope,
    required this.primaryTiming,
    required this.primaryMemory,
    required this.setupMetrics,
    required this.setupMemoryMetrics,
  });

  final String timedScope;
  final String setupScope;
  final String teardownScope;
  final String primaryTiming;
  final String primaryMemory;
  final List<String> setupMetrics;
  final List<String> setupMemoryMetrics;

  Map<String, Object?> toJson() {
    return {
      'timedScope': timedScope,
      'setupScope': setupScope,
      'teardownScope': teardownScope,
      'primaryTiming': primaryTiming,
      'primaryMemory': primaryMemory,
      'setupMetrics': setupMetrics,
      'setupMemoryMetrics': setupMemoryMetrics,
    };
  }

  static ParsedMeasurementBoundary? parseOptional(
    Map<String, Object?> json,
    String source,
  ) {
    final boundary = _optionalMap(json, 'measurementBoundary', source);
    if (boundary == null) {
      return null;
    }
    return _parseMeasurementBoundary(boundary, '$source measurementBoundary');
  }
}

ParsedMeasurementBoundary _parseMeasurementBoundary(
  Map<String, Object?> boundary,
  String source,
) {
  return ParsedMeasurementBoundary(
    timedScope: _string(boundary, 'timedScope', source),
    setupScope: _string(boundary, 'setupScope', source),
    teardownScope: _string(boundary, 'teardownScope', source),
    primaryTiming: _string(boundary, 'primaryTiming', source),
    primaryMemory: _string(boundary, 'primaryMemory', source),
    setupMetrics: _stringList(boundary, 'setupMetrics', source),
    setupMemoryMetrics: _stringList(boundary, 'setupMemoryMetrics', source),
  );
}

final class ParsedInvariantReport {
  const ParsedInvariantReport({
    required this.metric,
    required this.actual,
    required this.expected,
    required this.max,
    required this.passed,
  });

  final String metric;
  final Object? actual;
  final Object? expected;
  final num? max;
  final bool passed;

  Map<String, Object?> toBaselineJson() {
    return {'metric': metric, 'actual': actual, 'passed': passed};
  }

  factory ParsedInvariantReport.parse(
    Map<String, Object?> json,
    String source,
  ) {
    return ParsedInvariantReport(
      metric: _string(json, 'metric', '$source exact invariant'),
      actual: json['actual'],
      expected: json['expected'],
      max: _optionalNumber(json, 'max', '$source exact invariant'),
      passed: _bool(json, 'passed', '$source exact invariant'),
    );
  }
}

// Report validation mirrors the manifest contract in one pass; splitting the
// inventory, runtime, and case checks would obscure the fail-closed order.
// ignore: halstead-volume, number-of-parameters, source-lines-of-code
List<String> _validateReportForPolicy({
  required BenchmarkManifest manifest,
  required ParsedBenchmarkReport report,
  required String profile,
  required String sourceRole,
  required bool requireReferenceBaselineMetrics,
  required bool requireFirstBaselineMemoryCaps,
  required bool requireCasePolicyFields,
  required bool requireSamples,
  required bool requireObservedReleaseContour,
  required bool enforceAbsoluteCaps,
}) {
  final failures = <String>[];
  final manifestProfile = manifest.profilesById[profile];
  if (manifestProfile == null) {
    return ['unsupported profile $profile'];
  }
  final fingerprint = benchmarkManifestFingerprint(manifest);
  _expectEqual(
    failures,
    '$sourceRole schemaVersion',
    report.schemaVersion,
    manifest.toolSchemaVersion,
  );
  _expectEqual(
    failures,
    '$sourceRole manifestVersion',
    report.manifestVersion,
    manifest.manifestVersion,
  );
  _expectEqual(
    failures,
    '$sourceRole manifestFingerprint',
    report.manifestFingerprint,
    fingerprint,
  );
  _expectProfile(failures, sourceRole, report.profile, manifestProfile);
  _expectRuntimeMatchesReleaseContour(
    failures,
    sourceRole,
    report.runtime,
    manifest.releaseContour,
  );
  if (requireObservedReleaseContour) {
    _expectObservedRuntimeMatchesReleaseContour(
      failures,
      sourceRole,
      report.runtime,
      manifest.releaseContour,
    );
  }

  final actualCases = report.casesByKey;
  final expectedCases = _expectedCaseKeys(manifest, profile);
  for (final key
      in expectedCases.difference(actualCases.keys.toSet()).toList()..sort()) {
    failures.add('$sourceRole missing case $key');
  }
  for (final key
      in actualCases.keys.toSet().difference(expectedCases).toList()..sort()) {
    failures.add('$sourceRole unexpected case $key');
  }

  for (final benchmarkCase in manifest.cases) {
    for (final scale in benchmarkCase.scales) {
      if (!scale.profiles.contains(profile)) {
        continue;
      }
      final actual = actualCases['${benchmarkCase.id}/${scale.id}'];
      if (actual == null) {
        continue;
      }
      failures.addAll(
        _validateCaseForPolicy(
          manifest: manifest,
          benchmarkCase: benchmarkCase,
          scale: scale,
          actual: actual,
          sourceRole: sourceRole,
          requireReferenceBaselineMetrics: requireReferenceBaselineMetrics,
          requireFirstBaselineMemoryCaps: requireFirstBaselineMemoryCaps,
          requireCasePolicyFields: requireCasePolicyFields,
          requireSamples: requireSamples,
          enforceAbsoluteCaps: enforceAbsoluteCaps,
        ),
      );
    }
  }
  return failures;
}

// Per-case policy validation keeps the accepted/rejected report-row order stable
// while delegating each policy family to a focused helper.
// ignore: number-of-parameters
List<String> _validateCaseForPolicy({
  required BenchmarkManifest manifest,
  required BenchmarkCase benchmarkCase,
  required BenchmarkScale scale,
  required ParsedCaseReport actual,
  required String sourceRole,
  required bool requireReferenceBaselineMetrics,
  required bool requireFirstBaselineMemoryCaps,
  required bool requireCasePolicyFields,
  required bool requireSamples,
  required bool enforceAbsoluteCaps,
}) {
  final failures = <String>[];
  final caseName = '$sourceRole ${actual.key}';
  if (requireCasePolicyFields) {
    _validateCasePolicyFields(failures, benchmarkCase, actual, caseName);
  }
  failures.addAll(
    _validateCaseBoundaryFields(
      benchmarkCase: benchmarkCase,
      actual: actual,
      caseName: caseName,
      requireSamples: requireSamples,
    ),
  );
  _validateRequiredMetrics(failures, benchmarkCase, actual, caseName);
  failures.addAll(_validateExactInvariants(benchmarkCase, actual, caseName));
  _validateCaseCaps((
    failures: failures,
    manifest: manifest,
    benchmarkCase: benchmarkCase,
    scale: scale,
    actual: actual,
    caseName: caseName,
    enforceAbsoluteCaps: enforceAbsoluteCaps,
    requireFirstBaselineMemoryCaps: requireFirstBaselineMemoryCaps,
  ));
  if (requireReferenceBaselineMetrics) {
    _validateReferenceBaselineMetrics((
      failures: failures,
      manifest: manifest,
      benchmarkCase: benchmarkCase,
      actual: actual,
      caseName: caseName,
    ));
  }
  return failures;
}

void _validateCasePolicyFields(
  List<String> failures,
  BenchmarkCase benchmarkCase,
  ParsedCaseReport actual,
  String caseName,
) {
  _expectEqual(
    failures,
    '$caseName baselinePolicy',
    actual.baselinePolicy,
    benchmarkCase.baselinePolicy,
  );
  _expectEqual(
    failures,
    '$caseName memoryScope',
    actual.memoryScope,
    benchmarkCase.memoryScope,
  );
  final budgetClasses = actual.budgetClasses;
  if (budgetClasses == null ||
      !_sameStringSet(budgetClasses, benchmarkCase.budgetClasses)) {
    failures.add(
      '$caseName budgetClasses mismatch: actual=$budgetClasses '
      'expected=${benchmarkCase.budgetClasses}',
    );
  }
}

void _validateRequiredMetrics(
  List<String> failures,
  BenchmarkCase benchmarkCase,
  ParsedCaseReport actual,
  String caseName,
) {
  for (final metric in benchmarkCase.requiredMetrics) {
    if (!actual.metrics.containsKey(metric)) {
      failures.add('$caseName missing metric $metric');
    }
  }
}

void _validateCaseCaps(
  ({
    List<String> failures,
    BenchmarkManifest manifest,
    BenchmarkCase benchmarkCase,
    BenchmarkScale scale,
    ParsedCaseReport actual,
    String caseName,
    bool enforceAbsoluteCaps,
    bool requireFirstBaselineMemoryCaps,
  })
  input,
) {
  input.failures.addAll(
    _validateSchemaImportLoadAcceptanceGate(
      actual: input.actual,
      caseName: input.caseName,
    ),
  );
  if (input.enforceAbsoluteCaps) {
    input.failures.addAll(
      _validateAbsoluteCaps(
        manifest: input.manifest,
        benchmarkCase: input.benchmarkCase,
        scale: input.scale,
        actual: input.actual,
        caseName: input.caseName,
      ),
    );
  }
  if (input.requireFirstBaselineMemoryCaps) {
    input.failures.addAll(
      _validateFirstBaselineMemoryCaps(
        manifest: input.manifest,
        benchmarkCase: input.benchmarkCase,
        scale: input.scale,
        actual: input.actual,
        caseName: input.caseName,
      ),
    );
  }
}

List<String> _validateSchemaImportLoadAcceptanceGate({
  required ParsedCaseReport actual,
  required String caseName,
}) {
  if (actual.id != 'load_document.success' || actual.scale != '50k') {
    return const [];
  }
  const metric = 'schema_import_load_us';
  if (!actual.metrics.containsKey(metric)) {
    return const [];
  }
  final value = actual.metrics[metric];
  if (value is! num) {
    return ['$caseName metric $metric must be numeric'];
  }
  if (value >= schemaImportLoadSuccess50kMaxUs) {
    return [
      '$caseName $metric=$value must be < '
          '$schemaImportLoadSuccess50kMaxUs',
    ];
  }

  return const [];
}

void _validateReferenceBaselineMetrics(
  ({
    List<String> failures,
    BenchmarkManifest manifest,
    BenchmarkCase benchmarkCase,
    ParsedCaseReport actual,
    String caseName,
  })
  input,
) {
  final actual = input.actual;
  if (input.benchmarkCase.baselinePolicy != 'reference_comparison' ||
      !actual.metrics.containsKey('avg_us')) {
    return;
  }
  final avg = _metricNumber(actual, 'avg_us');
  final reference = _metricNumber(actual, 'reference_avg_us');
  if (reference == null) {
    input.failures.add('${input.caseName} missing metric reference_avg_us');
    return;
  }
  if (avg == null) {
    return;
  }
  final multiplier =
      input.manifest.firstBaselineReferenceLimits['avg_us_multiplier']!;
  if (avg > reference * multiplier) {
    input.failures.add(
      '${input.caseName} avg_us $avg exceeds reference_avg_us $reference * $multiplier',
    );
  }
}

List<String> _validateCaseBoundaryFields({
  required BenchmarkCase benchmarkCase,
  required ParsedCaseReport actual,
  required String caseName,
  required bool requireSamples,
}) {
  final failures = <String>[];
  _validateMeasurementBoundaryFields(
    failures: failures,
    benchmarkCase: benchmarkCase,
    actual: actual,
    caseName: caseName,
  );
  _expectEqual(
    failures,
    '$caseName fixtureShape',
    actual.fixtureShape,
    benchmarkCase.fixtureShape,
  );
  if (requireSamples) {
    _validateCaseSamples(
      failures: failures,
      benchmarkCase: benchmarkCase,
      actual: actual,
      caseName: caseName,
    );
  }
  _validatePrimaryMemoryMetrics(benchmarkCase, actual, caseName, failures);
  _validateSetupMetrics(benchmarkCase, actual, caseName, failures);
  return failures;
}

void _validateMeasurementBoundaryFields({
  required List<String> failures,
  required BenchmarkCase benchmarkCase,
  required ParsedCaseReport actual,
  required String caseName,
}) {
  final boundary = actual.measurementBoundary;
  if (boundary == null) {
    failures.add('$caseName missing measurementBoundary');
    return;
  }
  _validateMeasurementBoundaryScalars(
    failures: failures,
    benchmarkCase: benchmarkCase,
    boundary: boundary,
    caseName: caseName,
  );
  _validateMeasurementBoundaryLists(
    failures: failures,
    benchmarkCase: benchmarkCase,
    boundary: boundary,
    caseName: caseName,
  );
}

void _validateMeasurementBoundaryScalars({
  required List<String> failures,
  required BenchmarkCase benchmarkCase,
  required ParsedMeasurementBoundary boundary,
  required String caseName,
}) {
  final expected = benchmarkCase.measurementBoundary;
  _expectEqual(
    failures,
    '$caseName measurementBoundary.timedScope',
    boundary.timedScope,
    expected.timedScope,
  );
  _expectEqual(
    failures,
    '$caseName measurementBoundary.setupScope',
    boundary.setupScope,
    expected.setupScope,
  );
  _expectEqual(
    failures,
    '$caseName measurementBoundary.teardownScope',
    boundary.teardownScope,
    expected.teardownScope,
  );
  _expectEqual(
    failures,
    '$caseName measurementBoundary.primaryTiming',
    boundary.primaryTiming,
    expected.primaryTiming,
  );
  _expectEqual(
    failures,
    '$caseName measurementBoundary.primaryMemory',
    boundary.primaryMemory,
    expected.primaryMemory,
  );
}

void _validateMeasurementBoundaryLists({
  required List<String> failures,
  required BenchmarkCase benchmarkCase,
  required ParsedMeasurementBoundary boundary,
  required String caseName,
}) {
  final expected = benchmarkCase.measurementBoundary;
  _expectStringList(
    failures,
    '$caseName measurementBoundary.setupMetrics',
    boundary.setupMetrics,
    expected.setupMetrics,
  );
  _expectStringList(
    failures,
    '$caseName measurementBoundary.setupMemoryMetrics',
    boundary.setupMemoryMetrics,
    expected.setupMemoryMetrics,
  );
}

void _validateCaseSamples({
  required List<String> failures,
  required BenchmarkCase benchmarkCase,
  required ParsedCaseReport actual,
  required String caseName,
}) {
  final actionSamples = actual.actionUsSamples;
  if (actionSamples == null) {
    failures.add('$caseName missing actionUsSamples');
  } else if (actionSamples.isEmpty) {
    failures.add('$caseName actionUsSamples must not be empty');
  }
  final setupSamples = actual.setupUsSamples;
  if (setupSamples == null) {
    failures.add('$caseName missing setupUsSamples');
  } else if (benchmarkCase.measurementBoundary.setupScope != 'none' &&
      setupSamples.isEmpty) {
    failures.add('$caseName setupUsSamples must not be empty');
  }
}

void _validatePrimaryMemoryMetrics(
  BenchmarkCase benchmarkCase,
  ParsedCaseReport actual,
  String caseName,
  List<String> failures,
) {
  if (benchmarkCase.measurementBoundary.primaryMemory == 'none') {
    return;
  }
  for (final metric in _primaryMemoryMetricsForCase(benchmarkCase)) {
    _requiredMetricNumber(actual, metric, caseName, failures);
  }
}

void _validateSetupMetrics(
  BenchmarkCase benchmarkCase,
  ParsedCaseReport actual,
  String caseName,
  List<String> failures,
) {
  final setupMetrics = actual.setupMetrics;
  if (setupMetrics == null) {
    failures.add('$caseName missing setupMetrics');
    return;
  }
  if (benchmarkCase.measurementBoundary.setupScope == 'none') {
    if (setupMetrics.isNotEmpty) {
      failures.add('$caseName setupMetrics must be empty for setupScope none');
    }
    return;
  }
  final requiredSetupMetrics = [
    ...benchmarkCase.measurementBoundary.setupMetrics,
    ...benchmarkCase.measurementBoundary.setupMemoryMetrics,
  ];
  for (final metric in requiredSetupMetrics) {
    final value = setupMetrics[metric];
    if (value == null) {
      failures.add('$caseName missing setup metric $metric');
    } else if (value is! num) {
      failures.add('$caseName setup metric $metric must be numeric');
    }
  }
  for (final metric in benchmarkCase.measurementBoundary.setupMetrics) {
    final value = actual.metrics[metric];
    if (value == null) {
      failures.add('$caseName missing metric $metric');
    } else if (value is! num) {
      failures.add('$caseName metric $metric must be numeric');
    }
  }
}

// Exact-invariant validation intentionally keeps missing, mismatched, and
// unexpected invariant checks together so fixture failures remain local.
// ignore: cyclomatic-complexity, halstead-volume, source-lines-of-code
List<String> _validateExactInvariants(
  BenchmarkCase benchmarkCase,
  ParsedCaseReport actual,
  String caseName,
) {
  final failures = <String>[];
  for (final expected in benchmarkCase.exactInvariants) {
    final invariant = actual.exactInvariants[expected.name];
    if (invariant == null) {
      failures.add('$caseName missing invariant ${expected.name}');
      continue;
    }
    if (invariant.metric != expected.metric) {
      failures.add(
        '$caseName invariant ${expected.name} metric mismatch: '
        'actual=${invariant.metric} expected=${expected.metric}',
      );
    }
    if (expected.expected != null && invariant.actual != expected.expected) {
      failures.add(
        '$caseName invariant ${expected.name} actual=${invariant.actual} '
        'expected=${expected.expected}',
      );
    }
    if (expected.max != null) {
      final max = expected.max;
      final actualNumber = _metricNumber(actual, expected.metric);
      if (max != null && (actualNumber == null || actualNumber > max)) {
        failures.add(
          '$caseName invariant ${expected.name} actual=$actualNumber '
          'exceeds max=$max',
        );
      }
    }
    if (!invariant.passed) {
      failures.add('$caseName invariant ${expected.name} failed');
    }
  }
  for (final name in actual.exactInvariants.keys) {
    if (!benchmarkCase.exactInvariants.any(
      (expected) => expected.name == name,
    )) {
      failures.add('$caseName unexpected invariant $name');
    }
  }
  return failures;
}

// Absolute cap checks keep cap-key selection, scale mapping, missing-metric
// fail-closed handling, and comparison in one pass so report-policy drift is
// visible at the owning benchmark case instead of split across helper branches.
// ignore: cyclomatic-complexity, halstead-volume, number-of-parameters
List<String> _validateAbsoluteCaps({
  required BenchmarkManifest manifest,
  required BenchmarkCase benchmarkCase,
  required BenchmarkScale scale,
  required ParsedCaseReport actual,
  required String caseName,
}) {
  final failures = <String>[];
  final budgetClasses = {
    for (final budgetClass in manifest.budgetClasses)
      budgetClass.id: budgetClass,
  };
  for (final budgetClassId in benchmarkCase.budgetClasses) {
    final budgetClass = budgetClasses[budgetClassId]!;
    for (final entry in budgetClass.absoluteCaps.entries) {
      if (entry.key.startsWith('zero_') &&
          benchmarkCase.memoryScope != 'zero_allocation') {
        continue;
      }
      final metric = _capMetricForScale(entry.key);
      if (metric == null) {
        continue;
      }
      final cap = _capValueForScale(entry.key, entry.value, scale.id);
      if (cap == null) {
        continue;
      }
      if (!actual.metrics.containsKey(metric)) {
        if (_mustRequireAbsoluteCapMetric(benchmarkCase, metric)) {
          failures.add('$caseName missing metric $metric');
        }
        continue;
      }
      final value = _requiredMetricNumber(actual, metric, caseName, failures);
      if (value == null) {
        continue;
      }
      if (!_withinCap(value, cap)) {
        failures.add('$caseName $metric=$value exceeds absolute cap $cap');
      }
    }
  }
  return failures;
}

// First-baseline memory checks keep allocation and RSS policy adjacent because
// both gates define one approval boundary for a candidate report.
// ignore: halstead-volume, number-of-parameters
List<String> _validateFirstBaselineMemoryCaps({
  required BenchmarkManifest manifest,
  required BenchmarkCase benchmarkCase,
  required BenchmarkScale scale,
  required ParsedCaseReport actual,
  required String caseName,
}) {
  final failures = <String>[];
  final scope = manifest.memoryScopes.firstWhere(
    (candidate) => candidate.id == benchmarkCase.memoryScope,
  );
  final allocationCap = _allocationCap(scope, actual, scale.id);
  if (allocationCap != null) {
    final allocationBytes = _metricNumber(actual, 'allocation_bytes');
    if (allocationBytes == null) {
      failures.add('$caseName missing metric allocation_bytes');
    } else if (allocationBytes > allocationCap) {
      failures.add(
        '$caseName allocation_bytes=$allocationBytes exceeds first-baseline '
        'cap $allocationCap',
      );
    }
  }
  final rssCap = _rssCap(scope, actual, scale.id);
  if (rssCap != null) {
    final rssDeltaBytes = _metricNumber(actual, 'rss_delta_bytes');
    if (rssDeltaBytes == null) {
      failures.add('$caseName missing metric rss_delta_bytes');
    } else if (rssDeltaBytes > rssCap) {
      failures.add(
        '$caseName rss_delta_bytes=$rssDeltaBytes exceeds first-baseline '
        'cap $rssCap',
      );
    }
  }
  if (scope.id == 'zero_allocation') {
    final allocationRecords = _metricNumber(actual, 'allocation_records');
    if (allocationRecords != null && allocationRecords != 0) {
      failures.add(
        '$caseName allocation_records=$allocationRecords exceeds '
        'first-baseline cap 0',
      );
    }
  }
  return failures;
}

List<String> _validateSameContour({
  required ParsedBenchmarkReport baseline,
  required ParsedBenchmarkReport current,
}) {
  final failures = <String>[];
  _expectEqual(failures, 'profile id', baseline.profile.id, current.profile.id);
  _expectEqual(
    failures,
    'schemaVersion',
    baseline.schemaVersion,
    current.schemaVersion,
  );
  _expectEqual(
    failures,
    'manifestVersion',
    baseline.manifestVersion,
    current.manifestVersion,
  );
  _expectEqual(
    failures,
    'manifestFingerprint',
    baseline.manifestFingerprint,
    current.manifestFingerprint,
  );
  final baselineRuntime = baseline.runtime.toComparableJson();
  final currentRuntime = current.runtime.toComparableJson();
  for (final key in baselineRuntime.keys) {
    final baselineValue = baselineRuntime[key];
    final currentValue = currentRuntime[key];
    if (jsonEncode(baselineValue) != jsonEncode(currentValue)) {
      failures.add(
        'runtime metadata mismatch for $key: baseline=$baselineValue '
        'current=$currentValue',
      );
    }
  }
  return failures;
}

// Approved-baseline comparison is kept cohesive so time, allocation/RSS, and
// exact-invariant regressions are evaluated over one shared case traversal.
// ignore: cyclomatic-complexity, halstead-volume, maximum-nesting-level, maintainability-index, source-lines-of-code
List<String> _compareAgainstApprovedBaseline({
  required BenchmarkManifest manifest,
  required ParsedBenchmarkReport baseline,
  required ParsedBenchmarkReport current,
}) {
  final failures = <String>[];
  final caps = manifest.postBaselineRegressionCaps;
  for (final benchmarkCase in manifest.cases) {
    for (final scale in benchmarkCase.scales) {
      if (!scale.profiles.contains(current.profile.id)) {
        continue;
      }
      final key = '${benchmarkCase.id}/${scale.id}';
      final baselineCase = baseline.casesByKey[key];
      final currentCase = current.casesByKey[key];
      if (baselineCase == null || currentCase == null) {
        continue;
      }
      for (final metric in _regressionMetricsForCase(benchmarkCase)) {
        final baselineValue = _requiredMetricNumber(
          baselineCase,
          metric,
          'baseline $key',
          failures,
        );
        final currentValue = _requiredMetricNumber(
          currentCase,
          metric,
          'current $key',
          failures,
        );
        if (baselineValue == null || currentValue == null) {
          continue;
        }
        final failure = _regressionFailure(
          key: key,
          metric: metric,
          baselineValue: baselineValue,
          currentValue: currentValue,
          caps: caps,
        );
        if (failure != null) {
          failures.add(failure);
        }
      }
      failures.addAll(
        _validateExactInvariantRegression(
          benchmarkCase: benchmarkCase,
          baseline: baselineCase,
          current: currentCase,
        ),
      );
    }
  }
  return failures;
}

const _regressionMetricKeys = {
  'avg_us',
  'p95_us',
  'max_us',
  'allocation_bytes',
  'rss_delta_bytes',
};

Iterable<String> _regressionMetricsForCase(BenchmarkCase benchmarkCase) {
  return {
    for (final metric in benchmarkCase.requiredMetrics)
      if (_regressionMetricKeys.contains(metric)) metric,
    for (final metric in _absoluteCapMetricsForCase(benchmarkCase)) metric,
    for (final metric in _primaryMemoryMetricsForCase(benchmarkCase)) metric,
  };
}

Iterable<String> _absoluteCapMetricsForCase(BenchmarkCase benchmarkCase) {
  return switch (_hasTimeBudgetClass(benchmarkCase)) {
    true => const ['avg_us', 'p95_us', 'max_us'],
    false => const <String>[],
  };
}

bool _hasTimeBudgetClass(BenchmarkCase benchmarkCase) {
  return benchmarkCase.budgetClasses.any(_timeBudgetClassIds.contains);
}

bool _mustRequireAbsoluteCapMetric(BenchmarkCase benchmarkCase, String metric) {
  return _absoluteCapMetricsForCase(benchmarkCase).contains(metric);
}

const _timeBudgetClassIds = {
  'hot_input',
  'incremental_edit',
  'frame_capture',
  'query_read',
  'resource_budgeted',
  'bulk_io',
};

Iterable<String> _primaryMemoryMetricsForCase(BenchmarkCase benchmarkCase) {
  return switch (benchmarkCase.measurementBoundary.primaryMemory) {
    'action' || 'lifecycle' => const ['allocation_bytes', 'rss_delta_bytes'],
    'none' => const <String>[],
    _ => const <String>[],
  };
}

num? _requiredMetricNumber(
  ParsedCaseReport report,
  String metric,
  String caseName,
  List<String> failures,
) {
  if (!report.metrics.containsKey(metric)) {
    failures.add('$caseName missing metric $metric');
    return null;
  }
  final value = report.metrics[metric];
  if (value is num) {
    return value;
  }
  failures.add('$caseName metric $metric must be numeric');
  return null;
}

List<String> _validateExactInvariantRegression({
  required BenchmarkCase benchmarkCase,
  required ParsedCaseReport baseline,
  required ParsedCaseReport current,
}) {
  final failures = <String>[];
  for (final invariant in benchmarkCase.exactInvariants) {
    if (invariant.expected != null || invariant.max != null) {
      continue;
    }
    final baselineValue = _metricNumber(baseline, invariant.metric);
    final currentValue = _metricNumber(current, invariant.metric);
    if (baselineValue != null &&
        currentValue != null &&
        currentValue > baselineValue) {
      failures.add(
        '${current.key} ${invariant.metric} positive drift '
        '$baselineValue -> $currentValue is not allowed',
      );
    }
  }
  return failures;
}

// Regression failure formatting keeps the metric-specific caps and floors next
// to the emitted message so threshold mistakes are reviewable in one place.
// ignore: cyclomatic-complexity, number-of-parameters
String? _regressionFailure({
  required String key,
  required String metric,
  required num baselineValue,
  required num currentValue,
  required Map<String, num> caps,
}) {
  final percentCap = switch (metric) {
    'avg_us' => caps['avg_us_percent'],
    'p95_us' => caps['p95_us_percent'],
    'max_us' => caps['max_us_percent'],
    'allocation_bytes' ||
    'rss_delta_bytes' => caps['allocation_or_rss_percent'],
    _ => null,
  };
  if (percentCap == null) {
    return null;
  }
  final floor = switch (metric) {
    'allocation_bytes' => caps['allocation_floor_bytes'] ?? 0,
    'rss_delta_bytes' => caps['rss_floor_bytes'] ?? 0,
    _ => 0,
  };
  final allowed = _allowedRegressionValue(
    baselineValue: baselineValue,
    percentCap: percentCap,
    floor: floor,
  );
  if (currentValue > allowed) {
    return '$key $metric regression: baseline=$baselineValue '
        'current=$currentValue allowed=$allowed';
  }
  return null;
}

num _allowedRegressionValue({
  required num baselineValue,
  required num percentCap,
  required num floor,
}) {
  final percentLimit = baselineValue * (1 + percentCap / 100);
  final floorLimit = baselineValue + floor;
  return percentLimit > floorLimit ? percentLimit : floorLimit;
}

String? _capMetricForScale(String capKey) {
  if (capKey.endsWith('_by_scale')) {
    return capKey.replaceFirst(RegExp(r'_by_scale$'), '');
  }
  if (capKey == 'failure_mutation_count') {
    return 'committed_mutation_count';
  }
  if (capKey == 'cold_sync_resolver_calls') {
    return 'session_budget_resolver_calls';
  }
  if (capKey == 'required_counts_match_manifest' ||
      capKey == 'positive_drift_allowed') {
    return null;
  }
  if (capKey.startsWith('zero_')) {
    return capKey.replaceFirst('zero_', '');
  }
  return capKey;
}

Object? _capValueForScale(String capKey, Object? capValue, String scaleId) {
  if (!capKey.endsWith('_by_scale')) {
    return capValue;
  }
  if (capValue is! Map<String, Object?>) {
    return null;
  }
  return capValue[_documentScaleKey(scaleId)];
}

bool _withinCap(Object? value, Object? cap) {
  if (cap is bool) {
    return value == cap;
  }
  if (cap is num && value is num) {
    return value <= cap;
  }
  return true;
}

num? _allocationCap(
  BenchmarkMemoryScope scope,
  ParsedCaseReport actual,
  String scaleId,
) {
  final direct = scope.caps['allocation_bytes_cap'];
  if (direct is num) {
    return direct;
  }
  final byScale = _numberByScale(
    scope.caps['allocation_bytes_cap_by_scale'],
    scaleId,
  );
  if (byScale != null) {
    return byScale;
  }
  final base = scope.caps['allocation_base_bytes'];
  final perItem = scope.caps['allocation_per_reported_item_bytes'];
  if (base is num && perItem is num) {
    return base + perItem * _reportedItemCount(actual.metrics);
  }
  final min = scope.caps['allocation_min_bytes'];
  final multiplier = scope.caps['allocation_encoded_input_multiplier'];
  if (min is num && multiplier is num) {
    final encoded = _metricNumber(actual, 'encoded_input_bytes') ?? 0;
    final scaled = encoded * multiplier;
    return scaled > min ? scaled : min;
  }
  return null;
}

num? _rssCap(
  BenchmarkMemoryScope scope,
  ParsedCaseReport actual,
  String scaleId,
) {
  final direct = scope.caps['rss_delta_bytes_cap'];
  if (direct is num) {
    return direct;
  }
  final byScale = _numberByScale(
    scope.caps['rss_delta_bytes_cap_by_scale'],
    scaleId,
  );
  if (byScale != null) {
    return byScale;
  }
  final min = scope.caps['rss_min_bytes'];
  final multiplier = scope.caps['rss_encoded_input_multiplier'];
  if (min is num && multiplier is num) {
    final encoded = _metricNumber(actual, 'encoded_input_bytes') ?? 0;
    final scaled = encoded * multiplier;
    return scaled > min ? scaled : min;
  }
  return null;
}

num? _numberByScale(Object? value, String scaleId) {
  if (value is! Map<String, Object?>) {
    return null;
  }
  final cap = value[_documentScaleKey(scaleId)];
  return cap is num ? cap : null;
}

int _reportedItemCount(Map<String, Object?> metrics) {
  const countMetrics = {
    'candidate_count',
    'touched_count',
    'selected_count',
    'rebuilt_ids',
    'rebuilt_pages',
    'spatial_touched_pages',
    'surface_resource_session_resolver_calls',
    'session_budget_resolver_calls',
    'repaint_count',
  };
  var count = 0;
  for (final entry in metrics.entries) {
    final entryValue = entry.value;
    if (countMetrics.contains(entry.key) && entryValue is num) {
      final value = entryValue.round();
      if (value > count) {
        count = value;
      }
    }
  }
  return count;
}

String _documentScaleKey(String scaleId) {
  if (scaleId.contains('100k')) {
    return '100k';
  }
  if (scaleId.contains('50k')) {
    return '50k';
  }
  if (scaleId.contains('10k')) {
    return '10k';
  }
  return '1k';
}

Set<String> _expectedCaseKeys(BenchmarkManifest manifest, String profile) {
  return {
    for (final benchmarkCase in manifest.cases)
      for (final scale in benchmarkCase.scales)
        if (scale.profiles.contains(profile)) '${benchmarkCase.id}/${scale.id}',
  };
}

// Profile comparison lists every profile field explicitly; a data-driven loop
// would make the expected report schema less obvious in failure output.
// ignore: source-lines-of-code
void _expectProfile(
  List<String> failures,
  String sourceRole,
  ParsedProfileReport actual,
  BenchmarkProfile expected,
) {
  _expectEqual(failures, '$sourceRole profile', actual.id, expected.id);
  _expectEqual(
    failures,
    '$sourceRole warmups',
    actual.warmups,
    expected.warmups,
  );
  _expectEqual(
    failures,
    '$sourceRole repetitions',
    actual.repetitions,
    expected.repetitions,
  );
  _expectEqual(
    failures,
    '$sourceRole iterations',
    actual.iterations,
    expected.iterations,
  );
  _expectEqual(
    failures,
    '$sourceRole minimumMeasuredMs',
    actual.minimumMeasuredMs,
    expected.minimumMeasuredMs,
  );
  _expectEqual(
    failures,
    '$sourceRole minimumSamples',
    actual.minimumSamples,
    expected.minimumSamples,
  );
  _expectEqual(
    failures,
    '$sourceRole timingClaims',
    actual.timingClaims,
    expected.timingClaims,
  );
  _expectEqual(
    failures,
    '$sourceRole scaleSelection',
    actual.scaleSelection,
    expected.scaleSelection,
  );
}

void _expectRuntimeMatchesReleaseContour(
  List<String> failures,
  String sourceRole,
  ParsedRuntimeReport actual,
  BenchmarkReleaseContour expected,
) {
  _expectPresent(failures, '$sourceRole runnerLabel', actual.runnerLabel);
  _expectPresent(failures, '$sourceRole osName', actual.osName);
  _expectPresent(failures, '$sourceRole osVersion', actual.osVersion);
  _expectPresent(failures, '$sourceRole dartVersion', actual.dartVersion);
  _expectPresent(failures, '$sourceRole flutterChannel', actual.flutterChannel);
  _expectPresent(failures, '$sourceRole flutterVersion', actual.flutterVersion);
  _expectPresent(failures, '$sourceRole runtimeMode', actual.runtimeMode);
  _expectEqual(
    failures,
    '$sourceRole releaseContour.runnerLabel',
    actual.releaseContour.runnerLabel,
    expected.runnerLabel,
  );
  _expectEqual(
    failures,
    '$sourceRole releaseContour.osName',
    actual.releaseContour.osName,
    expected.osName,
  );
  _expectEqual(
    failures,
    '$sourceRole releaseContour.osVersion',
    actual.releaseContour.osVersion,
    expected.osVersion,
  );
  _expectEqual(
    failures,
    '$sourceRole releaseContour.flutterChannel',
    actual.releaseContour.flutterChannel,
    expected.flutterChannel,
  );
  _expectEqual(
    failures,
    '$sourceRole releaseContour.flutterVersion',
    actual.releaseContour.flutterVersion,
    expected.flutterVersion,
  );
}

void _expectObservedRuntimeMatchesReleaseContour(
  List<String> failures,
  String sourceRole,
  ParsedRuntimeReport actual,
  BenchmarkReleaseContour expected,
) {
  _expectEqual(
    failures,
    '$sourceRole observed runnerLabel',
    actual.runnerLabel,
    expected.runnerLabel,
  );
  _expectEqual(failures, '$sourceRole observed osName', actual.osName, 'linux');
  _expectPresent(failures, '$sourceRole observed osVersion', actual.osVersion);
  _expectEqual(
    failures,
    '$sourceRole observed flutterChannel',
    actual.flutterChannel,
    expected.flutterChannel,
  );
  _expectEqual(
    failures,
    '$sourceRole observed flutterVersion',
    actual.flutterVersion,
    expected.flutterVersion,
  );
}

void _expectPresent(List<String> failures, String field, String actual) {
  if (actual.isEmpty) {
    failures.add('$field must be present');
  }
}

void _expectEqual(
  List<String> failures,
  String field,
  Object? actual,
  Object? expected,
) {
  if (actual != expected) {
    failures.add('$field mismatch: actual=$actual expected=$expected');
  }
}

void _expectStringList(
  List<String> failures,
  String field,
  List<String> actual,
  List<String> expected,
) {
  if (!_sameStringList(actual, expected)) {
    failures.add('$field mismatch: actual=$actual expected=$expected');
  }
}

bool _sameStringSet(List<String> actual, List<String> expected) {
  return actual.toSet().containsAll(expected) &&
      expected.toSet().containsAll(actual);
}

bool _sameStringList(List<String> actual, List<String> expected) {
  if (actual.length != expected.length) {
    return false;
  }
  for (var index = 0; index < actual.length; index++) {
    if (actual[index] != expected[index]) {
      return false;
    }
  }
  return true;
}

num? _metricNumber(ParsedCaseReport report, String metric) {
  final value = report.metrics[metric];
  return value is num ? value : null;
}

// Result construction takes the complete command context so CLI and tests emit
// the same JSON schema without an intermediate mutable builder.
// ignore: number-of-parameters
BenchmarkDiffResult _result({
  required String profile,
  required String operation,
  required String? baselinePath,
  required String currentPath,
  required List<String> failures,
  required int comparedCaseCount,
}) {
  final status = failures.isEmpty ? 'pass' : 'fail';
  return BenchmarkDiffResult(
    status: status,
    failures: failures,
    report: {
      'schemaVersion': 1,
      'operation': operation,
      'profile': profile,
      'status': status,
      'baselinePath': baselinePath,
      'currentPath': currentPath,
      'failureCount': failures.length,
      'failures': failures,
      'summary': {'comparedCaseCount': comparedCaseCount},
    },
  );
}

Map<String, Object?> _readJsonObject(String path) {
  final decoded = jsonDecode(File(path).readAsStringSync());
  if (decoded is Map<String, Object?>) {
    return decoded;
  }
  throw FormatException('$path must contain a JSON object.');
}

void _writeJsonObject(String path, Map<String, Object?> json) {
  final file = File(path)..parent.createSync(recursive: true);
  file.writeAsStringSync(
    '${const JsonEncoder.withIndent('  ').convert(json)}\n',
  );
}

void _validateTransientOutputPath(String path) {
  _validateContainedPath(path, rootPath: 'build/bench');
  _validateNoSymlinkWritePath(path);
}

void _validateCandidatePath(String path) {
  _validateContainedPath(path, rootPath: releaseCandidateRoot);
}

void _validateBaselineUpdateCandidatePath(String candidate) {
  _validateCandidatePath(candidate);
}

void _validateDiffBaselinePath(String path) {
  final approved = File(
    approvedReleaseBaselinePath,
  ).absolute.uri.normalizePath();
  final target = File(path).absolute.uri.normalizePath();
  final manualBaseline = _isManualBaselinePath(path);
  if (target.path != approved.path && !manualBaseline) {
    throw const FormatException(
      'Approved benchmark baseline path must be '
      '$approvedReleaseBaselinePath or a JSON file under '
      '$manualBenchmarkReferenceRoot.',
    );
  }
}

void _validateApprovedBaselineWritePath(String path) {
  _validateNoParentTraversal(path);
  final approved = File(
    approvedReleaseBaselinePath,
  ).absolute.uri.normalizePath();
  final target = File(path).absolute.uri.normalizePath();
  if (target.path != approved.path) {
    throw const FormatException(
      'Approved benchmark baseline write path must be '
      '$approvedReleaseBaselinePath. Manual device references must be accepted '
      'through tool/bench/accept_manual_reference.dart.',
    );
  }
  _validateNoSymlinkWritePath(path);
}

void _validateNoParentTraversal(String path) {
  if (path.split(RegExp(r'[\\/]')).contains('..')) {
    throw FormatException('Path $path must not contain parent traversal.');
  }
}

bool _isManualBaselinePath(String path) {
  final target = File(path).absolute.uri.normalizePath();
  final manualRoot = Directory(
    manualBenchmarkReferenceRoot,
  ).absolute.uri.normalizePath().path;
  final normalizedManualRoot = manualRoot.endsWith('/')
      ? manualRoot.replaceFirst(RegExp(r'/$'), '')
      : manualRoot;
  return target.path.startsWith('$normalizedManualRoot/') &&
      target.path.endsWith('.json');
}

void _validateCurrentReleaseReportPath(String path) {
  final current = File(releaseCurrentReportPath).absolute.uri.normalizePath();
  final target = File(path).absolute.uri.normalizePath();
  final currentRoot = Directory(
    'build/bench/current',
  ).absolute.uri.normalizePath().path;
  final normalizedCurrentRoot = currentRoot.endsWith('/')
      ? currentRoot.replaceFirst(RegExp(r'/$'), '')
      : currentRoot;
  final currentReport =
      target.path.startsWith('$normalizedCurrentRoot/') &&
      target.path.endsWith('.json');
  if (target.path != current.path && !currentReport) {
    throw const FormatException(
      'Current benchmark release report path must be '
      '$releaseCurrentReportPath or a JSON file under build/bench/current.',
    );
  }
}

void _validateContainedPath(String path, {required String rootPath}) {
  final root = Directory(rootPath).absolute.uri.normalizePath().path;
  final target = File(path).absolute.uri.normalizePath().path;
  final normalizedRoot = root.endsWith('/')
      ? root.replaceFirst(RegExp(r'/$'), '')
      : root;
  if (target != normalizedRoot && !target.startsWith('$normalizedRoot/')) {
    throw FormatException('Path $path must stay under $rootPath.');
  }
}

void _validateNoSymlinkWritePath(String path) {
  final targetPath = File(path).absolute.uri.normalizePath().toFilePath();
  final targetUri = Uri.file(targetPath);
  var current = targetUri.path.startsWith('/') ? '/' : Directory.current.path;
  for (final segment in targetUri.pathSegments) {
    current = Directory(current).uri.resolve(segment).toFilePath();
    if (FileSystemEntity.typeSync(current, followLinks: false) ==
        FileSystemEntityType.link) {
      throw FormatException('Path $path must not contain symlinks.');
    }
  }
}

// CLI parsing is kept local and explicit because these tools intentionally
// accept only a tiny fixed set of named arguments.
// ignore: halstead-volume
Map<String, String> _parseNamedArgs(
  List<String> args, {
  required Set<String> requiredKeys,
}) {
  final values = <String, String>{};
  for (final arg in args) {
    if (!arg.startsWith('--') || !arg.contains('=')) {
      throw FormatException('Unsupported argument "$arg".');
    }
    final parts = arg.replaceFirst(RegExp(r'^--'), '').split('=');
    if (parts.length != 2) {
      throw FormatException('Unsupported argument "$arg".');
    }
    final key = parts.first;
    final value = parts.last;
    if (value.isEmpty) {
      throw FormatException('Argument --$key must not be empty.');
    }
    values[key] = value;
  }
  final missing = requiredKeys.difference(values.keys.toSet());
  if (missing.isNotEmpty) {
    throw FormatException(
      'Missing arguments: ${missing.map((key) => '--$key').join(', ')}.',
    );
  }
  final unknown = values.keys.toSet().difference(requiredKeys);
  if (unknown.isNotEmpty) {
    throw FormatException(
      'Unsupported arguments: ${unknown.map((key) => '--$key').join(', ')}.',
    );
  }
  return values;
}

Map<String, Object?> _map(
  Map<String, Object?> json,
  String key,
  String source,
) {
  return _requireMap(json[key], '$source $key');
}

Map<String, Object?>? _optionalMap(
  Map<String, Object?> json,
  String key,
  String source,
) {
  if (!json.containsKey(key) || json[key] == null) {
    return null;
  }
  return _requireMap(json[key], '$source $key');
}

Map<String, Object?> _requireMap(Object? value, String source) {
  if (value is Map<String, Object?>) {
    return value;
  }
  throw FormatException('$source must be a JSON object.');
}

List<Object?> _list(Map<String, Object?> json, String key, String source) {
  final value = json[key];
  if (value is List<Object?>) {
    return value;
  }
  throw FormatException('$source $key must be a JSON list.');
}

String _string(Map<String, Object?> json, String key, String source) {
  final value = json[key];
  if (value is String && value.isNotEmpty) {
    return value;
  }
  throw FormatException('$source $key must be a non-empty string.');
}

String? _optionalString(Map<String, Object?> json, String key, String source) {
  if (!json.containsKey(key) || json[key] == null) {
    return null;
  }
  return _string(json, key, source);
}

int _int(Map<String, Object?> json, String key, String source) {
  final value = json[key];
  if (value is int) {
    return value;
  }
  throw FormatException('$source $key must be an integer.');
}

int? _optionalInt(Map<String, Object?> json, String key, String source) {
  if (!json.containsKey(key) || json[key] == null) {
    return null;
  }
  return _int(json, key, source);
}

bool _bool(Map<String, Object?> json, String key, String source) {
  final value = json[key];
  if (value is bool) {
    return value;
  }
  throw FormatException('$source $key must be a boolean.');
}

num? _optionalNumber(Map<String, Object?> json, String key, String source) {
  if (!json.containsKey(key) || json[key] == null) {
    return null;
  }
  final value = json[key];
  if (value is num) {
    return value;
  }
  throw FormatException('$source $key must be a number.');
}

List<String> _stringList(Map<String, Object?> json, String key, String source) {
  final value = json[key];
  if (value is! List<Object?>) {
    throw FormatException('$source $key must be a list.');
  }
  return [
    for (final item in value)
      if (item is String)
        item
      else
        throw FormatException('$source $key must contain strings.'),
  ];
}

List<String>? _optionalStringList(
  Map<String, Object?> json,
  String key,
  String source,
) {
  if (!json.containsKey(key) || json[key] == null) {
    return null;
  }
  return _stringList(json, key, source);
}

List<int>? _optionalIntList(
  Map<String, Object?> json,
  String key,
  String source,
) {
  if (!json.containsKey(key) || json[key] == null) {
    return null;
  }
  final value = json[key];
  if (value is! List<Object?>) {
    throw FormatException('$source $key must be a list.');
  }
  return [
    for (final item in value)
      if (item is int)
        item
      else
        throw FormatException('$source $key must contain integers.'),
  ];
}
