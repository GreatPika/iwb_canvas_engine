import 'dart:convert';
import 'dart:io';

import 'package:characters/characters.dart';

import 'benchmark_manifest.dart';
import 'benchmark_sample_summary.dart';

const manualBenchmarkHistoryRoot = 'tool/bench/manual/run_history';
const manualBenchmarkHistoryIndexPath =
    '$manualBenchmarkHistoryRoot/index.json';
const _manualHistoryValueOptions = {
  'label',
  'report',
  'probe-log',
  'device-name',
  'device-id',
  'device-os',
  'baseline',
  'reference',
  'output',
  'history-root',
  'subject-git-head',
  'recorded-at',
};
const _manualHistoryFlagOptions = {'allow-dirty', 'overwrite'};

Future<String> runManualBenchmarkHistoryCli(List<String> args) {
  final options = ManualBenchmarkHistoryOptions.parse(args);
  return recordManualBenchmarkHistory(options);
}

Future<String> recordManualBenchmarkHistory(
  ManualBenchmarkHistoryOptions options,
) async {
  final git = await _gitState(options);
  if (git.dirty && !options.allowDirty) {
    throw const FormatException(
      'Working tree is dirty; pass --allow-dirty to record that fact.',
    );
  }

  return writeManualBenchmarkHistory(
    options: options,
    git: git,
    recordedAtUtc: options.recordedAtUtc ?? DateTime.now().toUtc(),
  );
}

String writeManualBenchmarkHistory({
  required ManualBenchmarkHistoryOptions options,
  required ManualBenchmarkGitState git,
  required DateTime recordedAtUtc,
}) {
  final sources = _loadSources(options);
  final history = _historyJson(
    options: options,
    git: git,
    sources: sources,
    recordedAtUtc: recordedAtUtc,
  );
  final outputPath = options.output ?? _defaultHistoryPath(options, git);
  final outputFile = File(outputPath);
  if (outputFile.existsSync() && !options.overwrite) {
    throw FormatException(
      'History file already exists: $outputPath. Pass --overwrite to replace.',
    );
  }
  outputFile.parent.createSync(recursive: true);
  outputFile.writeAsStringSync(
    const JsonEncoder.withIndent('  ').convert(history),
  );
  _updateHistoryIndex(
    indexPath: '${options.historyRoot}/index.json',
    outputPath: outputPath,
    history: history,
    recordedAtUtc: recordedAtUtc,
  );

  return outputPath;
}

final class ManualBenchmarkHistoryOptions {
  ManualBenchmarkHistoryOptions({
    required this.label,
    this.reportPaths = const [],
    this.probeLogPaths = const [],
    this.deviceName,
    this.deviceId,
    this.deviceOs,
    this.referencePath,
    this.output,
    this.historyRoot = manualBenchmarkHistoryRoot,
    this.subjectGitHead,
    this.recordedAtUtc,
    this.allowDirty = false,
    this.overwrite = false,
  });

  factory ManualBenchmarkHistoryOptions.parse(List<String> args) {
    final values = _parseArgs(args);
    final label = values.single('label');
    final reportPaths = values.all('report');
    final probeLogPaths = values.all('probe-log');
    if (reportPaths.isEmpty && probeLogPaths.isEmpty) {
      throw const FormatException(
        'Pass at least one --report=<path> or --probe-log=<path>.',
      );
    }

    return ManualBenchmarkHistoryOptions(
      label: label,
      reportPaths: reportPaths,
      probeLogPaths: probeLogPaths,
      deviceName: values.optionalSingle('device-name'),
      deviceId: values.optionalSingle('device-id'),
      deviceOs: values.optionalSingle('device-os'),
      referencePath:
          values.optionalSingle('reference') ??
          values.optionalSingle('baseline'),
      output: values.optionalSingle('output'),
      historyRoot:
          values.optionalSingle('history-root') ?? manualBenchmarkHistoryRoot,
      subjectGitHead: values.optionalSingle('subject-git-head'),
      recordedAtUtc: _parseRecordedAt(values.optionalSingle('recorded-at')),
      allowDirty: values.flag('allow-dirty'),
      overwrite: values.flag('overwrite'),
    );
  }

  final String label;
  final List<String> reportPaths;
  final List<String> probeLogPaths;
  final String? deviceName;
  final String? deviceId;
  final String? deviceOs;
  final String? referencePath;
  final String? output;
  final String historyRoot;
  final String? subjectGitHead;
  final DateTime? recordedAtUtc;
  final bool allowDirty;
  final bool overwrite;
}

final class ManualBenchmarkGitState {
  const ManualBenchmarkGitState({required this.head, required this.dirty});

  final String head;
  final bool dirty;
}

Map<String, Object?> _historyJson({
  required ManualBenchmarkHistoryOptions options,
  required ManualBenchmarkGitState git,
  required List<_HistorySource> sources,
  required DateTime recordedAtUtc,
}) {
  final firstRuntime = sources.first.runtime;
  final profile = _profileJson(sources);

  return {
    'schemaVersion': benchmarkToolSchemaVersion,
    'kind': 'manual_benchmark_history',
    'recordedAtUtc': recordedAtUtc.toIso8601String(),
    'label': options.label,
    'subjectGitHead': options.subjectGitHead ?? git.head,
    'repositoryDirty': git.dirty,
    'device': _deviceJson(options, sources),
    'profile': profile,
    'toolchain': _toolchainJson(firstRuntime, profile),
    'referenceReport': {
      'kind': options.referencePath == null ? null : 'manual',
      'path': options.referencePath,
    },
    'sources': [for (final source in sources) source.toJson()],
    'caseCount': _caseCount(sources),
    'cases': _casesJson(sources),
  };
}

Map<String, Object?> _deviceJson(
  ManualBenchmarkHistoryOptions options,
  List<_HistorySource> sources,
) {
  return {
    'name': options.deviceName,
    'id': options.deviceId ?? _deviceId(sources),
    'os': options.deviceOs,
  };
}

int _caseCount(List<_HistorySource> sources) {
  return sources.fold<int>(0, (count, source) => count + source.cases.length);
}

List<Map<String, Object?>> _casesJson(List<_HistorySource> sources) {
  return [
    for (final source in sources)
      for (final benchmarkCase in source.cases) benchmarkCase,
  ];
}

List<_HistorySource> _loadSources(ManualBenchmarkHistoryOptions options) {
  return [
    for (final path in options.reportPaths) _loadReportSource(path),
    for (final path in options.probeLogPaths) _loadProbeLogSource(path),
  ];
}

_HistorySource _loadReportSource(String path) {
  final json = _readJsonFile(path);
  _validateReportSchema(path, json);
  final cases = (json['cases'] as List<Object?>? ?? const [])
      .whereType<Map<String, Object?>>()
      .map((entry) => _caseJson(path: path, json: entry))
      .toList();

  return _HistorySource(
    path: path,
    kind: 'report',
    manifestVersion: json['manifestVersion'] as String?,
    manifestFingerprint: json['manifestFingerprint'] as String?,
    sourceFingerprint: benchmarkSourceFingerprint(path),
    profile: _map(json['profile']),
    runtime: _map(json['runtime']),
    cases: cases,
  );
}

_HistorySource _loadProbeLogSource(String path) {
  final line = File(path)
      .readAsLinesSync()
      .where((line) => line.startsWith('BENCHMARK_PROBE_JSON:'))
      .lastOrNull;
  if (line == null) {
    throw FormatException(
      'Probe log does not contain BENCHMARK_PROBE_JSON: $path',
    );
  }
  final json = jsonDecode(line.replaceFirst('BENCHMARK_PROBE_JSON:', ''));
  if (json is! Map<String, Object?>) {
    throw FormatException('Probe log JSON root must be an object: $path');
  }

  return _HistorySource(
    path: path,
    kind: 'probe_log',
    manifestVersion: null,
    manifestFingerprint: null,
    sourceFingerprint: benchmarkSourceFingerprint(path),
    profile: null,
    runtime: _map(json['runtime']),
    cases: [_probeCaseJson(path: path, json: json)],
  );
}

void _validateReportSchema(String path, Map<String, Object?> json) {
  if (json['schemaVersion'] != benchmarkToolSchemaVersion) {
    throw FormatException(
      'Benchmark report schemaVersion must be $benchmarkToolSchemaVersion: $path',
    );
  }
}

Map<String, Object?> _caseJson({
  required String path,
  required Map<String, Object?> json,
}) {
  _rejectRetiredReportCaseFields(path: path, json: json);
  final metrics = _map(json['metrics']);
  _rejectRetiredMetricFields(path: path, metrics: metrics);
  final baselinePolicy = json['baselinePolicy'];
  if (baselinePolicy is! String || baselinePolicy.isEmpty) {
    throw FormatException('Report case missing baselinePolicy: $path');
  }

  return {
    'id': json['id'],
    'scale': json['scale'],
    'baselinePolicy': baselinePolicy,
    'fixtureShape': json['fixtureShape'],
    'measurementBoundary': json['measurementBoundary'],
    'sampleSummary': {
      'actionUs': benchmarkSampleSummary(
        _requiredIntList(
          json,
          'actionUsSamples',
          'report case',
          allowEmpty: false,
        ),
      ),
      'setupUs': benchmarkSampleSummary(
        _requiredIntList(
          json,
          'setupUsSamples',
          'report case',
          allowEmpty: _setupScope(json) == 'none',
        ),
      ),
    },
    'metrics': metrics,
    'setupMetrics': json['setupMetrics'],
    'exactInvariants': json['exactInvariants'] ?? const <String, Object?>{},
  };
}

void _rejectRetiredReportCaseFields({
  required String path,
  required Map<String, Object?> json,
}) {
  for (final field in const ['classification']) {
    if (json.containsKey(field)) {
      throw FormatException('Report case uses retired field $field: $path');
    }
  }
}

void _rejectRetiredMetricFields({
  required String path,
  required Map<String, Object?> metrics,
}) {
  for (final field in const ['legacy_avg_us']) {
    if (metrics.containsKey(field)) {
      throw FormatException('Report case uses retired metric $field: $path');
    }
  }
}

Map<String, Object?> _probeCaseJson({
  required String path,
  required Map<String, Object?> json,
}) {
  final identity = _probeIdentityFromPath(path);
  final metrics = _map(json['metrics']);
  _rejectRetiredMetricFields(path: path, metrics: metrics);
  return {
    'id': identity.caseId,
    'scale': identity.scale,
    'baselinePolicy': identity.baselinePolicy,
    'fixtureShape': json['fixtureShape'],
    'measurementBoundary': json['measurementBoundary'],
    'sampleSummary': {
      'actionUs': benchmarkSampleSummary(
        _requiredIntList(
          json,
          'actionUsSamples',
          'probe log $path',
          allowEmpty: false,
        ),
      ),
      'setupUs': benchmarkSampleSummary(
        _requiredIntList(
          json,
          'setupUsSamples',
          'probe log $path',
          allowEmpty: _setupScope(json) == 'none',
        ),
      ),
    },
    'metrics': metrics,
    'setupMetrics': json['setupMetrics'],
    'exactInvariants': json['exactInvariants'] ?? const <String, Object?>{},
  };
}

Map<String, Object?> _toolchainJson(
  Map<String, Object?> runtime,
  Map<String, Object?>? profile,
) {
  return {
    'profileId': runtime['profileId'] ?? profile?['id'],
    'runtimeMode': runtime['runtimeMode'],
    'assertionsEnabled': runtime['assertionsEnabled'],
    'debugInvariantMode': runtime['debugInvariantMode'],
    'runnerLabel': runtime['runnerLabel'],
    'osName': runtime['osName'],
    'osVersion': runtime['osVersion'],
    'dartVersion': runtime['dartVersion'],
    'flutterChannel': runtime['flutterChannel'],
    'flutterVersion': runtime['flutterVersion'],
    'releaseContour': runtime['releaseContour'],
  };
}

Map<String, Object?>? _profileJson(List<_HistorySource> sources) {
  for (final source in sources) {
    final profile = source.profile;
    if (profile != null && profile.isNotEmpty) {
      return profile;
    }
  }

  return null;
}

String? _setupScope(Map<String, Object?> json) {
  final boundary = json['measurementBoundary'];
  if (boundary is Map<String, Object?>) {
    return boundary['setupScope'] as String?;
  }
  return null;
}

String? _deviceId(List<_HistorySource> sources) {
  for (final source in sources) {
    final deviceId = source.runtime['deviceId'];
    if (deviceId is String && deviceId.isNotEmpty) {
      return deviceId;
    }
  }

  return null;
}

String _defaultHistoryPath(
  ManualBenchmarkHistoryOptions options,
  ManualBenchmarkGitState git,
) {
  final date = (options.recordedAtUtc ?? DateTime.now().toUtc())
      .toIso8601String()
      .split('T')
      .first;
  final device = _slug(options.deviceName ?? 'manual-device');
  final head = _slug(
    (options.subjectGitHead ?? git.head).characters.take(8).toString(),
  );
  final label = _slug(options.label);

  return '${options.historyRoot}/${date}_${device}_${head}_$label.json';
}

void _updateHistoryIndex({
  required String indexPath,
  required String outputPath,
  required Map<String, Object?> history,
  required DateTime recordedAtUtc,
}) {
  final records = _readHistoryIndexRecords(indexPath);
  records.removeWhere((record) => record['path'] == outputPath);
  records.add(_indexRecord(outputPath: outputPath, history: history));
  records.sort(_compareRecordedAt);
  _writeHistoryIndex(
    indexPath: indexPath,
    records: records,
    recordedAtUtc: recordedAtUtc,
  );
}

List<Map<String, Object?>> _readHistoryIndexRecords(String indexPath) {
  if (!File(indexPath).existsSync()) {
    return [];
  }
  final existing = _readJsonFile(indexPath);

  return (existing['records'] as List<Object?>? ?? const [])
      .whereType<Map<String, Object?>>()
      .toList();
}

Map<String, Object?> _indexRecord({
  required String outputPath,
  required Map<String, Object?> history,
}) {
  return {
    'path': outputPath,
    'label': history['label'],
    'recordedAtUtc': history['recordedAtUtc'],
    'subjectGitHead': history['subjectGitHead'],
    'repositoryDirty': history['repositoryDirty'],
    'device': history['device'],
    'caseCount': history['caseCount'],
    'sources': _indexSources(history),
  };
}

List<Map<String, Object?>> _indexSources(Map<String, Object?> history) {
  final sources = history['sources'];
  if (sources is! List<Object?>) {
    return const [];
  }

  return [
    for (final source in sources)
      if (source is Map<String, Object?>)
        {
          'path': source['path'],
          'kind': source['kind'],
          'source': source['source'],
          'manifestVersion': source['manifestVersion'],
          'manifestFingerprint': source['manifestFingerprint'],
          'caseCount': source['caseCount'],
        },
  ];
}

int _compareRecordedAt(Map<String, Object?> left, Map<String, Object?> right) {
  return (left['recordedAtUtc'] as String).compareTo(
    right['recordedAtUtc'] as String,
  );
}

void _writeHistoryIndex({
  required String indexPath,
  required List<Map<String, Object?>> records,
  required DateTime recordedAtUtc,
}) {
  final indexFile = File(indexPath);
  indexFile.parent.createSync(recursive: true);
  indexFile.writeAsStringSync(
    const JsonEncoder.withIndent('  ').convert({
      'schemaVersion': 1,
      'updatedAtUtc': recordedAtUtc.toIso8601String(),
      'records': records,
    }),
  );
}

Future<ManualBenchmarkGitState> _gitState(
  ManualBenchmarkHistoryOptions options,
) async {
  final head =
      options.subjectGitHead ??
      (await _git(['rev-parse', 'HEAD'])).stdout.toString().trim();
  final status = (await _git(['status', '--porcelain'])).stdout.toString();

  return ManualBenchmarkGitState(head: head, dirty: status.trim().isNotEmpty);
}

Future<ProcessResult> _git(List<String> args) async {
  final result = await Process.run('git', args);
  if (result.exitCode != 0) {
    throw FormatException('git ${args.join(' ')} failed: ${result.stderr}');
  }

  return result;
}

Map<String, Object?> _readJsonFile(String path) {
  final decoded = jsonDecode(File(path).readAsStringSync());
  if (decoded is! Map<String, Object?>) {
    throw FormatException('JSON root must be an object: $path');
  }

  return decoded;
}

Map<String, Object?> _map(Object? value) {
  if (value is Map<String, Object?>) {
    return value;
  }

  return const {};
}

({String caseId, String scale, String baselinePolicy}) _probeIdentityFromPath(
  String path,
) {
  final name = path.split(Platform.pathSeparator).last;
  if (!name.endsWith('.log')) {
    throw FormatException('Probe log filename does not identify case: $path');
  }

  for (final entry in _manifestCaseScaleSuffixes()) {
    if (name.endsWith(entry.suffix)) {
      return (
        caseId: entry.caseId,
        scale: entry.scale,
        baselinePolicy: entry.baselinePolicy,
      );
    }
  }

  throw FormatException('Probe log filename does not identify case: $path');
}

List<({String caseId, String scale, String baselinePolicy, String suffix})>
_manifestCaseScaleSuffixes() {
  final suffixes =
      <({String caseId, String scale, String baselinePolicy, String suffix})>[];
  for (final benchmarkCase in BenchmarkManifest.load().cases) {
    final caseFilePart = benchmarkCase.id.replaceAll('.', '_');
    for (final scale in benchmarkCase.scales) {
      suffixes
        ..add((
          caseId: benchmarkCase.id,
          scale: scale.id,
          baselinePolicy: benchmarkCase.baselinePolicy,
          suffix: '_${caseFilePart}_${scale.id}.log',
        ))
        ..add((
          caseId: benchmarkCase.id,
          scale: scale.id,
          baselinePolicy: benchmarkCase.baselinePolicy,
          suffix: '_${caseFilePart}_rerun_${scale.id}.log',
        ));
    }
  }
  suffixes.sort(
    (left, right) => right.suffix.length.compareTo(left.suffix.length),
  );
  return suffixes;
}

String _slug(String value) {
  return value
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'^_+|_+$'), '');
}

DateTime? _parseRecordedAt(String? value) {
  if (value == null) {
    return null;
  }

  return DateTime.parse(value).toUtc();
}

final class _HistorySource {
  const _HistorySource({
    required this.path,
    required this.kind,
    required this.manifestVersion,
    required this.manifestFingerprint,
    required this.sourceFingerprint,
    required this.profile,
    required this.runtime,
    required this.cases,
  });

  final String path;
  final String kind;
  final String? manifestVersion;
  final String? manifestFingerprint;
  final Map<String, Object?> sourceFingerprint;
  final Map<String, Object?>? profile;
  final Map<String, Object?> runtime;
  final List<Map<String, Object?>> cases;

  Map<String, Object?> toJson() {
    return {
      'path': path,
      'kind': kind,
      'source': sourceFingerprint,
      'manifestVersion': manifestVersion,
      'manifestFingerprint': manifestFingerprint,
      'caseCount': cases.length,
    };
  }
}

List<int> _requiredIntList(
  Map<String, Object?> json,
  String key,
  String source, {
  required bool allowEmpty,
}) {
  final value = json[key];
  if (value is! List<Object?>) {
    throw FormatException('$source requires $key as an integer array.');
  }
  final samples = <int>[];
  for (final item in value) {
    if (item is! int) {
      throw FormatException('$source requires $key as an integer array.');
    }
    samples.add(item);
  }
  if (samples.isEmpty && !allowEmpty) {
    throw FormatException('$source requires non-empty $key.');
  }
  return samples;
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
      if (!_manualHistoryFlagOptions.contains(option)) {
        throw FormatException('Unsupported manual history flag "--$option".');
      }
      flags.add(option);
      continue;
    }
    final name = parts.first;
    if (!_manualHistoryValueOptions.contains(name)) {
      throw FormatException('Unsupported manual history option "--$name".');
    }
    final value = parts.skip(1).join('=');
    values.putIfAbsent(name, () => []).add(value);
  }

  return _ParsedArgs(values, flags);
}
