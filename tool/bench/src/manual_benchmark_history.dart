import 'dart:convert';
import 'dart:io';

import 'package:characters/characters.dart';

import 'benchmark_diff.dart' show schemaImportLoadSuccess50kMaxUs;
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
    'schemaVersion': 1,
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
    'bridgeComparisons': _bridgeComparisons(options: options, sources: sources),
    'sources': [for (final source in sources) source.toJson()],
    'caseCount': _caseCount(sources),
    'cases': _casesJson(sources),
  };
}

List<Map<String, Object?>> _bridgeComparisons({
  required ManualBenchmarkHistoryOptions options,
  required List<_HistorySource> sources,
}) {
  final referencePath = options.referencePath;
  if (referencePath == null || !File(referencePath).existsSync()) {
    return const [];
  }
  final legacy = _legacyLoadBridge(referencePath);
  if (legacy == null) {
    return const [];
  }
  for (final source in sources) {
    final current = _currentSchemaImportLoadBridge(source);
    if (current != null) {
      return [_bridgeComparisonJson(legacy, current)];
    }
  }

  return const [];
}

_LegacyLoadBridge? _legacyLoadBridge(String referencePath) {
  final referenceBreakdown = _findReportCase(
    _readJsonFile(referencePath),
    id: 'load_document.breakdown',
    scale: '50k',
  );
  if (referenceBreakdown == null) {
    return null;
  }
  final metrics = _map(referenceBreakdown['metrics']);
  final decodeUs = metrics['decode_us'];
  final loadUs = metrics['load_document_us'];
  if (decodeUs is! int || loadUs is! int) {
    return null;
  }

  return _LegacyLoadBridge(
    source: referencePath,
    decodeUs: decodeUs,
    loadDocumentUs: loadUs,
  );
}

_CurrentSchemaImportLoadBridge? _currentSchemaImportLoadBridge(
  _HistorySource source,
) {
  final currentSuccess = _findSourceCase(
    source,
    id: 'load_document.success',
    scale: '50k',
  );
  if (currentSuccess == null) {
    return null;
  }
  final loadUs = _map(currentSuccess['metrics'])['schema_import_load_us'];
  if (loadUs is! int) {
    return null;
  }

  return _CurrentSchemaImportLoadBridge(source: source.path, loadUs: loadUs);
}

Map<String, Object?> _bridgeComparisonJson(
  _LegacyLoadBridge legacy,
  _CurrentSchemaImportLoadBridge current,
) {
  final legacyTotalUs = legacy.decodeUs + legacy.loadDocumentUs;

  return {
    'id': 'step58_xiaomi_50k_public_json_load',
    'legacy': {
      'source': legacy.source,
      'decode_us': legacy.decodeUs,
      'load_document_us': legacy.loadDocumentUs,
      'decode_plus_load_us': legacyTotalUs,
    },
    'current': {
      'source': current.source,
      'schema_import_load_us': current.loadUs,
    },
    'threshold': {
      'metric': 'schema_import_load_us',
      'max_exclusive_us': schemaImportLoadSuccess50kMaxUs,
      'passed': current.loadUs < schemaImportLoadSuccess50kMaxUs,
    },
    'improvement': {
      'absolute_us': legacyTotalUs - current.loadUs,
      'relative_percent':
          ((legacyTotalUs - current.loadUs) / legacyTotalUs * 1000).round() /
          10,
    },
  };
}

Map<String, Object?>? _findReportCase(
  Map<String, Object?> report, {
  required String id,
  required String scale,
}) {
  final cases = report['cases'];
  if (cases is! List<Object?>) {
    return null;
  }
  for (final benchmarkCase in cases.whereType<Map<String, Object?>>()) {
    if (benchmarkCase['id'] == id && benchmarkCase['scale'] == scale) {
      return benchmarkCase;
    }
  }

  return null;
}

Map<String, Object?>? _findSourceCase(
  _HistorySource source, {
  required String id,
  required String scale,
}) {
  for (final benchmarkCase in source.cases) {
    if (benchmarkCase['id'] == id && benchmarkCase['scale'] == scale) {
      return benchmarkCase;
    }
  }

  return null;
}

final class _LegacyLoadBridge {
  const _LegacyLoadBridge({
    required this.source,
    required this.decodeUs,
    required this.loadDocumentUs,
  });

  final String source;
  final int decodeUs;
  final int loadDocumentUs;
}

final class _CurrentSchemaImportLoadBridge {
  const _CurrentSchemaImportLoadBridge({
    required this.source,
    required this.loadUs,
  });

  final String source;
  final int loadUs;
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
  final cases = (json['cases'] as List<Object?>? ?? const [])
      .whereType<Map<String, Object?>>()
      .map(_caseJson)
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

Map<String, Object?> _caseJson(Map<String, Object?> json) {
  return {
    'id': json['id'],
    'scale': json['scale'],
    'classification': json['classification'],
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
    'metrics': json['metrics'],
    'setupMetrics': json['setupMetrics'],
    'exactInvariants': json['exactInvariants'] ?? const <String, Object?>{},
  };
}

Map<String, Object?> _probeCaseJson({
  required String path,
  required Map<String, Object?> json,
}) {
  final identity = _probeIdentityFromPath(path);
  return {
    'id': identity.caseId,
    'scale': identity.scale,
    'classification': null,
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
    'metrics': json['metrics'],
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
  };
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

({String caseId, String scale}) _probeIdentityFromPath(String path) {
  final name = path.split(Platform.pathSeparator).last;
  if (!name.endsWith('.log')) {
    throw FormatException('Probe log filename does not identify case: $path');
  }

  for (final entry in _manifestCaseScaleSuffixes()) {
    if (name.endsWith(entry.suffix)) {
      return (caseId: entry.caseId, scale: entry.scale);
    }
  }

  throw FormatException('Probe log filename does not identify case: $path');
}

List<({String caseId, String scale, String suffix})>
_manifestCaseScaleSuffixes() {
  final suffixes = <({String caseId, String scale, String suffix})>[];
  for (final benchmarkCase in BenchmarkManifest.load().cases) {
    final caseFilePart = benchmarkCase.id.replaceAll('.', '_');
    for (final scale in benchmarkCase.scales) {
      suffixes
        ..add((
          caseId: benchmarkCase.id,
          scale: scale.id,
          suffix: '_${caseFilePart}_${scale.id}.log',
        ))
        ..add((
          caseId: benchmarkCase.id,
          scale: scale.id,
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
