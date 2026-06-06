import 'dart:convert';
import 'dart:io';

const manualBenchmarkReferenceDecisionPath =
    'tool/bench/manual/reference_decisions.json';
const _referenceValueOptions = {
  'run',
  'output',
  'reason',
  'policy',
  'decision-log',
  'accepted-at',
};
const _referenceFlagOptions = {
  'allow-dirty-runs',
  'allow-unrecorded-subject',
  'overwrite',
};

Future<String> runManualBenchmarkReferenceCli(List<String> args) async {
  final options = ManualBenchmarkReferenceOptions.parse(args);
  return writeManualBenchmarkReference(
    options: options,
    acceptedAtUtc: options.acceptedAtUtc ?? DateTime.now().toUtc(),
  );
}

String writeManualBenchmarkReference({
  required ManualBenchmarkReferenceOptions options,
  required DateTime acceptedAtUtc,
}) {
  final runs = [for (final path in options.runPaths) _historyRun(path)];
  _validateReferenceInputs(options, runs);
  final reference = _referenceJson(
    options: options,
    runs: runs,
    acceptedAtUtc: acceptedAtUtc,
  );
  final outputFile = File(options.output);
  if (outputFile.existsSync() && !options.overwrite) {
    throw FormatException(
      'Reference report already exists: ${options.output}. '
      'Pass --overwrite to replace.',
    );
  }
  outputFile.parent.createSync(recursive: true);
  outputFile.writeAsStringSync(
    const JsonEncoder.withIndent('  ').convert(reference),
  );
  _appendDecision(
    decisionPath: options.decisionLog,
    referencePath: options.output,
    reference: reference,
    acceptedAtUtc: acceptedAtUtc,
  );
  return options.output;
}

final class ManualBenchmarkReferenceOptions {
  const ManualBenchmarkReferenceOptions({
    required this.runPaths,
    required this.output,
    required this.reason,
    required this.policy,
    required this.decisionLog,
    required this.allowDirtyRuns,
    required this.allowUnrecordedSubject,
    required this.overwrite,
    this.acceptedAtUtc,
  });

  factory ManualBenchmarkReferenceOptions.parse(List<String> args) {
    final values = _parseArgs(args);
    final runs = values.all('run');
    if (runs.isEmpty) {
      throw const FormatException('Pass at least one --run=<history-json>.');
    }
    final output = values.single('output');
    if (output.isEmpty) {
      throw const FormatException('--output must not be empty.');
    }
    final reason = values.single('reason');
    if (reason.trim().isEmpty) {
      throw const FormatException('--reason must not be empty.');
    }
    return ManualBenchmarkReferenceOptions(
      runPaths: runs,
      output: output,
      reason: reason,
      policy: values.optionalSingle('policy') ?? 'stable_window_median_v1',
      decisionLog:
          values.optionalSingle('decision-log') ??
          manualBenchmarkReferenceDecisionPath,
      acceptedAtUtc: _parseDateTime(values.optionalSingle('accepted-at')),
      allowDirtyRuns: values.flag('allow-dirty-runs'),
      allowUnrecordedSubject: values.flag('allow-unrecorded-subject'),
      overwrite: values.flag('overwrite'),
    );
  }

  final List<String> runPaths;
  final String output;
  final String reason;
  final String policy;
  final String decisionLog;
  final bool allowDirtyRuns;
  final bool allowUnrecordedSubject;
  final bool overwrite;
  final DateTime? acceptedAtUtc;
}

void _validateReferenceInputs(
  ManualBenchmarkReferenceOptions options,
  List<_HistoryRun> runs,
) {
  _validateSelectionPolicy(options.policy, runs.length);
  _validateDistinctRunWindow(options.policy, runs);
  final first = runs.first;
  for (final run in runs) {
    _validateRunEligibility(options, run);
    _validateReleaseHistoryRun(run);
    _validateCompatibleRun(first, run);
  }
}

void _validateSelectionPolicy(String policy, int runCount) {
  if (policy == 'stable_window_median_v1' && runCount < 3) {
    throw const FormatException(
      'stable_window_median_v1 requires at least three history runs.',
    );
  }
  if (policy == 'bootstrap_single_run_v1' && runCount != 1) {
    throw const FormatException(
      'bootstrap_single_run_v1 requires exactly one history run.',
    );
  }
  if (policy != 'stable_window_median_v1' &&
      policy != 'bootstrap_single_run_v1') {
    throw FormatException('Unsupported reference policy: $policy');
  }
}

void _validateDistinctRunWindow(String policy, List<_HistoryRun> runs) {
  if (policy != 'stable_window_median_v1') {
    return;
  }
  if (!_allDistinct([for (final run in runs) run.path])) {
    throw const FormatException(
      'stable_window_median_v1 requires distinct history run paths.',
    );
  }
  if (!_allDistinct([for (final run in runs) run.sourceIdentity])) {
    throw const FormatException(
      'stable_window_median_v1 requires distinct source reports.',
    );
  }
  final sourceFingerprints = [
    for (final run in runs) ...run.sourceFingerprints,
  ];
  if (!_allDistinct(sourceFingerprints)) {
    throw const FormatException(
      'stable_window_median_v1 must not reuse source reports.',
    );
  }
}

void _validateRunEligibility(
  ManualBenchmarkReferenceOptions options,
  _HistoryRun run,
) {
  if (run.repositoryDirty && !options.allowDirtyRuns) {
    throw FormatException('History run is dirty: ${run.path}');
  }
  if (run.subjectGitHead.startsWith('unrecorded-') &&
      !options.allowUnrecordedSubject) {
    throw FormatException('History run has unrecorded subject: ${run.path}');
  }
}

void _validateReleaseHistoryRun(_HistoryRun run) {
  if (run.profile['id'] != 'release') {
    throw FormatException('History run profile is not release: ${run.path}');
  }
  if (run.toolchain['profileId'] != 'release') {
    throw FormatException('History run toolchain is not release: ${run.path}');
  }
}

void _validateCompatibleRun(_HistoryRun expected, _HistoryRun actual) {
  _expectSameMap(expected.device, actual.device, 'device', actual.path);
  _expectSameMap(
    expected.toolchain,
    actual.toolchain,
    'toolchain',
    actual.path,
  );
  _expectSameMap(expected.profile, actual.profile, 'profile', actual.path);
  if (expected.manifestVersion != actual.manifestVersion ||
      expected.manifestFingerprint != actual.manifestFingerprint) {
    throw FormatException('History run manifest differs: ${actual.path}');
  }
  if (!_sameStringSet(expected.caseKeys, actual.caseKeys)) {
    throw FormatException('History run case set differs: ${actual.path}');
  }
}

Map<String, Object?> _referenceJson({
  required ManualBenchmarkReferenceOptions options,
  required List<_HistoryRun> runs,
  required DateTime acceptedAtUtc,
}) {
  final first = runs.first;
  return {
    'kind': 'manual_benchmark_reference',
    'schemaVersion': first.schemaVersion,
    'manifestVersion': first.manifestVersion,
    'manifestFingerprint': first.manifestFingerprint,
    'profile': first.profile,
    'runtime': first.runtime,
    'acceptedAtUtc': acceptedAtUtc.toIso8601String(),
    'acceptedReason': options.reason,
    'selectionPolicy': options.policy,
    'acceptedFromRuns': [for (final run in runs) run.path],
    'caseCount': first.cases.length,
    'cases': _referenceCases(runs),
  };
}

List<Map<String, Object?>> _referenceCases(List<_HistoryRun> runs) {
  final firstCases = runs.first.cases;
  return [
    for (final entry in firstCases.entries)
      _referenceCase(entry.value, [
        for (final run in runs) _requiredCaseFor(run, entry.key),
      ]),
  ];
}

Map<String, Object?> _requiredCaseFor(_HistoryRun run, String key) {
  final benchmarkCase = run.cases[key];
  if (benchmarkCase == null) {
    throw FormatException('History run case set differs: ${run.path}');
  }
  return benchmarkCase;
}

Map<String, Object?> _referenceCase(
  Map<String, Object?> first,
  List<Map<String, Object?>> cases,
) {
  _requireEqualCaseShape(cases);
  return {
    'id': first['id'],
    'scale': first['scale'],
    'measurementBoundary': first['measurementBoundary'],
    'fixtureShape': first['fixtureShape'],
    'sampleSummary': _medianNestedMap(cases, 'sampleSummary'),
    'metrics': _medianMap(cases, 'metrics'),
    'setupMetrics': _medianMap(cases, 'setupMetrics'),
    'exactInvariants': first['exactInvariants'],
  };
}

void _requireEqualCaseShape(List<Map<String, Object?>> cases) {
  final first = cases.first;
  for (final entry in cases.skip(1)) {
    for (final key in [
      'measurementBoundary',
      'fixtureShape',
      'exactInvariants',
    ]) {
      if (jsonEncode(entry[key]) != jsonEncode(first[key])) {
        throw const FormatException('History run case shape differs.');
      }
    }
  }
}

Map<String, Object?> _medianNestedMap(
  List<Map<String, Object?>> cases,
  String key,
) {
  final first = _map(firstValue(cases, key), key);
  return {
    for (final entry in first.entries)
      entry.key: _medianMap([
        for (final item in cases) _map(_map(item[key], key)[entry.key], key),
      ], ''),
  };
}

Object? firstValue(List<Map<String, Object?>> cases, String key) {
  return cases.first[key];
}

Map<String, Object?> _medianMap(List<Map<String, Object?>> cases, String key) {
  final maps = key.isEmpty
      ? cases
      : [for (final item in cases) _map(item[key], key)];
  final first = maps.first;
  return {
    for (final entry in first.entries)
      entry.key: _medianValue([for (final item in maps) item[entry.key]]),
  };
}

Object? _medianValue(List<Object?> values) {
  if (values.every((value) => value is num)) {
    final sorted = [
      for (final value in values)
        if (value is num) value,
    ]..sort();
    return sorted[sorted.length ~/ 2];
  }
  for (final value in values.skip(1)) {
    if (jsonEncode(value) != jsonEncode(values.first)) {
      throw const FormatException('History run non-numeric values differ.');
    }
  }
  return values.first;
}

_HistoryRun _historyRun(String path) {
  final json = _readJson(path);
  if (json['kind'] != 'manual_benchmark_history') {
    throw FormatException('Not a manual benchmark history record: $path');
  }
  final cases = _historyCases(json);
  final sources = _historySources(json);
  final firstSource = sources.first;
  return _HistoryRun(
    path: path,
    schemaVersion: 3,
    manifestVersion: _string(firstSource['manifestVersion'], 'manifestVersion'),
    manifestFingerprint: _string(
      firstSource['manifestFingerprint'],
      'manifestFingerprint',
    ),
    profile: _map(json['profile'], 'profile'),
    runtime: _runtimeFromHistory(json),
    device: _map(json['device'], 'device'),
    toolchain: _map(json['toolchain'], 'toolchain'),
    subjectGitHead: _string(json['subjectGitHead'], 'subjectGitHead'),
    repositoryDirty: json['repositoryDirty'] == true,
    sourceFingerprints: _sourceFingerprints(sources),
    sourceIdentity: _sourceIdentity(sources),
    cases: cases,
  );
}

Map<String, Map<String, Object?>> _historyCases(Map<String, Object?> json) {
  final cases = <String, Map<String, Object?>>{};
  for (final entry in _list(json['cases'], 'cases')) {
    final benchmarkCase = _map(entry, 'case');
    cases['${benchmarkCase['id']}/${benchmarkCase['scale']}'] = benchmarkCase;
  }
  return cases;
}

List<Map<String, Object?>> _historySources(Map<String, Object?> json) {
  return _list(
    json['sources'],
    'sources',
  ).map((entry) => _map(entry, 'source')).toList();
}

String _sourceIdentity(List<Map<String, Object?>> sources) {
  final identities = _sourceFingerprints(sources);
  identities.sort();
  return identities.join('|');
}

List<String> _sourceFingerprints(List<Map<String, Object?>> sources) {
  return [for (final source in sources) _sourceFingerprint(source)];
}

String _sourceFingerprint(Map<String, Object?> source) {
  final fingerprint = _map(source['source'], 'source.source');
  final sha256 = fingerprint['sha256'];
  return sha256 is String ? sha256 : jsonEncode(fingerprint);
}

Map<String, Object?> _runtimeFromHistory(Map<String, Object?> json) {
  final toolchain = _map(json['toolchain'], 'toolchain');
  return {
    'runnerLabel': toolchain['runnerLabel'],
    'osName': toolchain['osName'],
    'osVersion': toolchain['osVersion'],
    'dartVersion': toolchain['dartVersion'],
    'flutterChannel': toolchain['flutterChannel'],
    'flutterVersion': toolchain['flutterVersion'],
    'releaseContour': toolchain['releaseContour'],
    'runtimeMode': toolchain['runtimeMode'],
    'assertionsEnabled': toolchain['assertionsEnabled'],
    'debugInvariantMode': toolchain['debugInvariantMode'],
    'deviceId': _map(json['device'], 'device')['id'],
  };
}

void _appendDecision({
  required String decisionPath,
  required String referencePath,
  required Map<String, Object?> reference,
  required DateTime acceptedAtUtc,
}) {
  final records = File(decisionPath).existsSync()
      ? _list(
          _readJson(decisionPath)['records'],
          'records',
        ).whereType<Map<String, Object?>>().toList()
      : <Map<String, Object?>>[];
  records.removeWhere((record) => record['referencePath'] == referencePath);
  records.add({
    'referencePath': referencePath,
    'acceptedAtUtc': acceptedAtUtc.toIso8601String(),
    'acceptedReason': reference['acceptedReason'],
    'selectionPolicy': reference['selectionPolicy'],
    'acceptedFromRuns': reference['acceptedFromRuns'],
  });
  final file = File(decisionPath)..parent.createSync(recursive: true);
  file.writeAsStringSync(
    const JsonEncoder.withIndent('  ').convert({
      'schemaVersion': 1,
      'updatedAtUtc': acceptedAtUtc.toIso8601String(),
      'records': records,
    }),
  );
}

Map<String, Object?> _readJson(String path) {
  final decoded = jsonDecode(File(path).readAsStringSync());
  return _map(decoded, path);
}

Map<String, Object?> _map(Object? value, String source) {
  if (value is Map<String, Object?>) {
    return value;
  }
  throw FormatException('$source must be an object.');
}

List<Object?> _list(Object? value, String source) {
  if (value is List<Object?>) {
    return value;
  }
  throw FormatException('$source must be a list.');
}

String _string(Object? value, String source) {
  if (value is String && value.isNotEmpty) {
    return value;
  }
  throw FormatException('$source must be a non-empty string.');
}

void _expectSameMap(
  Map<String, Object?> expected,
  Map<String, Object?> actual,
  String label,
  String path,
) {
  if (jsonEncode(expected) != jsonEncode(actual)) {
    throw FormatException('History run $label differs: $path');
  }
}

bool _sameStringSet(Iterable<String> left, Iterable<String> right) {
  return left.toSet().containsAll(right) && right.toSet().containsAll(left);
}

bool _allDistinct(List<String> values) =>
    values.toSet().length == values.length;

DateTime? _parseDateTime(String? value) {
  if (value == null) {
    return null;
  }
  return DateTime.parse(value).toUtc();
}

final class _HistoryRun {
  const _HistoryRun({
    required this.path,
    required this.schemaVersion,
    required this.manifestVersion,
    required this.manifestFingerprint,
    required this.profile,
    required this.runtime,
    required this.device,
    required this.toolchain,
    required this.subjectGitHead,
    required this.repositoryDirty,
    required this.sourceFingerprints,
    required this.sourceIdentity,
    required this.cases,
  });

  final String path;
  final int schemaVersion;
  final String manifestVersion;
  final String manifestFingerprint;
  final Map<String, Object?> profile;
  final Map<String, Object?> runtime;
  final Map<String, Object?> device;
  final Map<String, Object?> toolchain;
  final String subjectGitHead;
  final bool repositoryDirty;
  final List<String> sourceFingerprints;
  final String sourceIdentity;
  final Map<String, Map<String, Object?>> cases;

  Iterable<String> get caseKeys => cases.keys;
}

final class _ParsedArgs {
  _ParsedArgs(this._values, this._flags);

  final Map<String, List<String>> _values;
  final Set<String> _flags;

  List<String> all(String name) => _values[name] ?? const [];

  String single(String name) {
    final values = all(name);
    if (values.length != 1) {
      throw FormatException('Pass exactly one --$name=<value>.');
    }
    return values.single;
  }

  String? optionalSingle(String name) {
    final values = all(name);
    if (values.length > 1) {
      throw FormatException('Pass at most one --$name=<value>.');
    }
    return values.singleOrNull;
  }

  bool flag(String name) => _flags.contains(name);
}

_ParsedArgs _parseArgs(List<String> args) {
  final values = <String, List<String>>{};
  final flags = <String>{};
  for (final arg in args) {
    if (!arg.startsWith('--')) {
      throw FormatException('Unsupported positional argument "$arg".');
    }
    final option = arg.replaceFirst('--', '');
    final parts = option.split('=');
    if (parts.length == 1) {
      if (!_referenceFlagOptions.contains(option)) {
        throw FormatException('Unsupported reference flag "--$option".');
      }
      flags.add(option);
      continue;
    }
    if (!_referenceValueOptions.contains(parts.first)) {
      throw FormatException('Unsupported reference option "--${parts.first}".');
    }
    values.putIfAbsent(parts.first, () => []).add(parts.skip(1).join('='));
  }
  return _ParsedArgs(values, flags);
}
