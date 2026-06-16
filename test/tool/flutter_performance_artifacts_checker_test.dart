import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

// The checker fixture must use the same example-owned route catalog as the
// executable benchmark route without making the root package depend on example.
// ignore: avoid_relative_lib_imports
import '../../example/lib/perf/performance_scenario_catalog.dart' as catalog;
import '../../tool/check_flutter_performance_artifacts.dart';
import '../../tool/src/tool_command_result.dart';

void main() {
  _registerPositiveArtifactTest();
  _registerInvocationTest();
  _registerMalformedArtifactRejectionTest();
  _registerUnexpectedFileSystemEntryRejectionTest();
  _registerMissingOutputRejectionTest();
  _registerManifestRejectionTests();
  _registerMalformedGeneratedJsonRejectionTest();
  _registerGeneratedJsonTopLevelSchemaRejectionTest();
  _registerGeneratedJsonNestedSchemaRejectionTest();
  _registerComparisonSchemaRejectionTest();
  _registerComparisonMathRejectionTest();
}

void _registerPositiveArtifactTest() {
  test(
    'accepts complete nested artifacts for the executable catalog',
    () async {
      final root = await Directory.systemTemp.createTemp('perf_artifacts_ok_');
      addTearDown(() => root.delete(recursive: true));

      _writeValidArtifactSet(root);

      final result = await runFlutterPerformanceArtifactsCheck([
        '--results',
        '${root.path}/results',
      ]);

      expect(result.exitCode, 0, reason: result.stderr);
      expect(
        result.stdout,
        contains('verified 26 Flutter performance scenario'),
      );
    },
  );
}

void _registerInvocationTest() {
  test('rejects the retired markdown catalog input', () async {
    final root = await Directory.systemTemp.createTemp('perf_artifacts_args_');
    addTearDown(() => root.delete(recursive: true));
    _writeValidArtifactSet(root);

    final result = await runFlutterPerformanceArtifactsCheck([
      '--catalog',
      'docs/verification/performance.md',
      '--results',
      '${root.path}/results',
    ]);

    expect(result.exitCode, 1);
    expect(result.stderr, contains('--catalog is no longer supported'));
  });
}

void _registerMalformedArtifactRejectionTest() {
  test('rejects malformed artifacts and unexpected outputs', () async {
    final result = await _runMutatedFixture((root) {
      File(
        '${root.path}/results/load_document.100k/warm.load_document/'
        'repeat_001/load_document.100k__warm.load_document__repeat_001'
        '.timeline.json',
      ).writeAsStringSync('{not json');
      File(
        '${root.path}/results/load_document.100k/warm.load_document/'
        'repeat_001/load_document.100k__warm.load_document__repeat_001'
        '.timeline_summary.json',
      ).writeAsStringSync(jsonEncode({'not_a_timeline_summary': true}));
      File(
        '${root.path}/results/created_by_checker.json',
      ).writeAsStringSync('{}');
      Directory('${root.path}/results/extra_group').createSync();
    });

    expect(result.stderr, contains('malformed timeline JSON'));
    expect(result.stderr, contains('average_frame_build_time_millis'));
    expect(result.stderr, contains('unexpected file in results directory'));
    expect(result.stderr, contains('unexpected scenario group directory'));
  });
}

void _registerUnexpectedFileSystemEntryRejectionTest() {
  test('rejects symlink entries in generated artifact directories', () async {
    final result = await _runMutatedFixture((root) {
      Link(
        '${root.path}/results/linked_manifest.json',
      ).createSync('performance_run_manifest.json');
      Link(
        '${root.path}/results/load_document.100k/warm.load_document/'
        'repeat_001/linked_timeline.json',
      ).createSync(
        'load_document.100k__warm.load_document__repeat_001.timeline.json',
      );
    });

    expect(result.stderr, contains('unexpected file system entry'));
  });
}

void _registerMissingOutputRejectionTest() {
  test(
    'rejects missing repeats, unsupported phases, and incomplete catalog',
    () async {
      final result = await _runMutatedFixture(_removeRepeatAndCatalogGroup);
      expect(result.exitCode, 1);
      _expectMissingOutputFailures(result);
    },
  );
}

void _registerManifestRejectionTests() {
  test(
    'rejects manifest schema drift and preparation metadata drift',
    () async {
      final result = await _runMutatedFixture((root) {
        final manifest = _readRootJson(root, 'performance_run_manifest.json');
        manifest['threshold'] = 10;
        manifest.remove('unsupportedClaims');
        final warmRepeat = _manifestRepeat(
          manifest,
          groupId: 'load_document.100k',
          phaseKey: 'steady.load_document',
          repeat: 1,
        );
        warmRepeat.remove('canonicalPreparation');
        warmRepeat['resetReason'] = 'wrong_reset';
        warmRepeat['preparationMeasured'] = true;
        _writeRootJson(root, 'performance_run_manifest.json', manifest);
      });

      expect(result.stderr, contains('forbidden key threshold'));
      expect(result.stderr, contains('run manifest is missing key'));
      expect(result.stderr, contains('canonicalPreparation'));
      expect(result.stderr, contains('resetReason'));
      expect(result.stderr, contains('preparationMeasured'));
    },
  );
}

void _registerMalformedGeneratedJsonRejectionTest() {
  test('rejects malformed generated manifest and comparison JSON', () async {
    final result = await _runMutatedFixture(_malformGeneratedJsonFiles);

    expect(result.stderr, contains('malformed run manifest'));
    expect(result.stderr, contains('malformed comparison summary'));
  });
}

void _registerGeneratedJsonTopLevelSchemaRejectionTest() {
  test('rejects non-forbidden top-level generated JSON schema drift', () async {
    final result = await _runMutatedFixture(_breakGeneratedJsonTopLevelSchema);

    expect(result.stderr, contains('run manifest has unexpected key: notes'));
    expect(result.stderr, contains('run manifest is missing key: route'));
    expect(
      result.stderr,
      contains('comparison summary has unexpected key: notes'),
    );
    expect(
      result.stderr,
      contains('comparison summary is missing key: routeName'),
    );
  });
}

void _registerGeneratedJsonNestedSchemaRejectionTest() {
  test('rejects non-forbidden nested generated JSON schema drift', () async {
    final result = await _runMutatedFixture(_breakGeneratedJsonNestedSchema);

    expect(result.stderr, contains('run manifest group has unexpected key'));
    expect(result.stderr, contains('run manifest group is missing key'));
    expect(result.stderr, contains('run manifest phase for'));
    expect(result.stderr, contains('is missing key: comparisonRole'));
    expect(result.stderr, contains('has unexpected key: notes'));
    expect(result.stderr, contains('run manifest repeat for'));
    expect(result.stderr, contains('is missing key: timelineFile'));
    expect(
      result.stderr,
      contains('comparison summary group has unexpected key'),
    );
    expect(result.stderr, contains('comparison summary phase for'));
    expect(result.stderr, contains('is missing key: repeatCount'));
    expect(result.stderr, contains('comparison summary metric for'));
    expect(result.stderr, contains('is missing key: max'));
    expect(result.stderr, contains('raw repeat for'));
    expect(result.stderr, contains('is missing key: value'));
  });
}

void _registerComparisonSchemaRejectionTest() {
  test('rejects comparison schema drift and unsupported metrics', () async {
    final result = await _runMutatedFixture((root) {
      final comparison = _readRootJson(root, 'comparison_summary.json');
      comparison['baseline'] = 'local';
      comparison.remove('sourceManifest');
      final metrics = _comparisonMetrics(
        comparison,
        groupId: 'load_document.100k',
        phaseKey: 'steady.load_document',
      );
      metrics.add({
        'summaryField': 'custom_benchmark_score',
        'unit': 'count',
        'rawRepeats': <Object?>[],
        'median': 0,
        'min': 0,
        'max': 0,
        'interquartileRange': 0,
      });
      _writeRootJson(root, 'comparison_summary.json', comparison);
    });

    expect(result.stderr, contains('forbidden key baseline'));
    expect(result.stderr, contains('comparison summary is missing key'));
    expect(result.stderr, contains('unsupported comparison summary metric'));
  });
}

void _registerComparisonMathRejectionTest() {
  test(
    'rejects incorrect comparison math for single and repeated phases',
    () async {
      final result = await _runMutatedFixture(_breakComparisonMath);
      expect(result.exitCode, 1);
      _expectComparisonMathFailures(result);
    },
  );

  test('rejects duplicate and overwritten repeat identity', () async {
    final result = await _runMutatedFixture((root) {
      final manifest = _readRootJson(root, 'performance_run_manifest.json');
      final phase = _manifestPhase(
        manifest,
        groupId: 'load_document.100k',
        phaseKey: 'steady.load_document',
      );
      final repeats = _jsonList(phase['repeats']);
      repeats[1] = Map<String, Object?>.from(repeats.first);
      _writeRootJson(root, 'performance_run_manifest.json', manifest);
    });

    expect(result.stderr, contains('duplicate run manifest repeat'));
    expect(result.stderr, contains('duplicate run manifest reportKey'));
    expect(result.stderr, contains('overwritten run manifest reportKey'));
  });
}

void _removeRepeatAndCatalogGroup(Directory root) {
  Directory(
    '${root.path}/results/camera_pan.100k/steady.camera_pan/repeat_005',
  ).deleteSync(recursive: true);
  Directory(
    '${root.path}/results/camera_pan.100k/unsupported.phase/repeat_001',
  ).createSync(recursive: true);
  final manifest = _readRootJson(root, 'performance_run_manifest.json');
  final groups = _jsonList(manifest['scenarioGroups']);
  groups.removeWhere((group) => group['id'] == 'dispose_during_preview');
  final camera = groups.singleWhere(
    (group) => group['id'] == 'camera_pan.100k',
  );
  _jsonList(camera['phases']).add({
    'kind': 'unsupported',
    'name': 'phase',
    'comparisonRole': 'steady_action',
    'repeats': <Object?>[],
  });
  _writeRootJson(root, 'performance_run_manifest.json', manifest);
}

void _expectMissingOutputFailures(ToolCommandResult result) {
  expect(result.stderr, contains('missing repeat'));
  expect(result.stderr, contains('missing repeat directory'));
  expect(result.stderr, contains('unsupported run manifest phase'));
  expect(result.stderr, contains('missing run manifest scenario group'));
}

void _breakComparisonMath(Directory root) {
  final comparison = _readRootJson(root, 'comparison_summary.json');
  final singleMetric = _metric(
    comparison,
    groupId: 'selection_tap.10k',
    phaseKey: 'single.current_behavior',
    summaryField: 'frame_count',
  );
  singleMetric['median'] = 999;
  singleMetric['min'] = 999;
  singleMetric['max'] = 999;
  singleMetric['interquartileRange'] = 999;

  final steadyPhase = _comparisonPhase(
    comparison,
    groupId: 'load_document.100k',
    phaseKey: 'steady.load_document',
  );
  steadyPhase['repeatCount'] = 2;
  final twoRepeatMetric = _metric(
    comparison,
    groupId: 'load_document.100k',
    phaseKey: 'steady.load_document',
    summaryField: 'average_frame_build_time_millis',
  );
  twoRepeatMetric['rawRepeats'] = _jsonList(
    twoRepeatMetric['rawRepeats'],
  ).take(2).toList();
  twoRepeatMetric['median'] = 999;
  twoRepeatMetric['min'] = 999;
  twoRepeatMetric['max'] = 999;
  twoRepeatMetric['interquartileRange'] = 999;
  _writeRootJson(root, 'comparison_summary.json', comparison);
}

void _expectComparisonMathFailures(ToolCommandResult result) {
  expect(result.stderr, contains('median expected'));
  expect(result.stderr, contains('min expected'));
  expect(result.stderr, contains('max expected'));
  expect(result.stderr, contains('interquartileRange expected'));
  expect(result.stderr, contains('expected 5 but found 2'));
}

void _malformGeneratedJsonFiles(Directory root) {
  File(
    '${root.path}/results/performance_run_manifest.json',
  ).writeAsStringSync('{not json');
  File(
    '${root.path}/results/comparison_summary.json',
  ).writeAsStringSync('{also not json');
}

void _breakGeneratedJsonTopLevelSchema(Directory root) {
  final manifest = _readRootJson(root, 'performance_run_manifest.json');
  manifest['notes'] = 'local-only';
  manifest.remove('route');
  _writeRootJson(root, 'performance_run_manifest.json', manifest);

  final comparison = _readRootJson(root, 'comparison_summary.json');
  comparison['notes'] = 'local-only';
  comparison.remove('routeName');
  _writeRootJson(root, 'comparison_summary.json', comparison);
}

void _breakGeneratedJsonNestedSchema(Directory root) {
  final manifest = _readRootJson(root, 'performance_run_manifest.json');
  final manifestGroup = _jsonList(manifest['scenarioGroups']).first;
  manifestGroup['notes'] = 'local-only';
  manifestGroup.remove('migration');
  final manifestPhase = _jsonList(manifestGroup['phases']).first;
  manifestPhase['notes'] = 'local-only';
  manifestPhase.remove('comparisonRole');
  final manifestRepeat = _jsonList(manifestPhase['repeats']).first;
  manifestRepeat['notes'] = 'local-only';
  manifestRepeat.remove('timelineFile');
  _writeRootJson(root, 'performance_run_manifest.json', manifest);

  final comparison = _readRootJson(root, 'comparison_summary.json');
  final comparisonGroup = _jsonList(comparison['scenarioGroups']).first;
  comparisonGroup['notes'] = 'local-only';
  final comparisonPhase = _jsonList(comparisonGroup['phases']).first;
  comparisonPhase.remove('repeatCount');
  final comparisonMetric = _jsonList(comparisonPhase['metrics']).first;
  comparisonMetric.remove('max');
  final rawRepeat = _jsonList(comparisonMetric['rawRepeats']).first;
  rawRepeat.remove('value');
  _writeRootJson(root, 'comparison_summary.json', comparison);
}

Future<ToolCommandResult> _runMutatedFixture(
  void Function(Directory root) mutate,
) async {
  final root = await Directory.systemTemp.createTemp('perf_artifacts_bad_');
  addTearDown(() => root.delete(recursive: true));
  _writeValidArtifactSet(root);
  mutate(root);

  final result = await runFlutterPerformanceArtifactsCheck([
    '--results',
    '${root.path}/results',
  ]);
  expect(result.exitCode, 1);
  return result;
}

void _writeValidArtifactSet(Directory root) {
  _ArtifactFixtureWriter(root).write();
}

final class _ArtifactFixtureWriter {
  _ArtifactFixtureWriter(Directory root)
    : results = Directory('${root.path}/results')..createSync(recursive: true);

  final Directory results;
  final manifestGroups = <Map<String, Object?>>[];
  final comparisonGroups = <Map<String, Object?>>[];
  int _valueSeed = 0;

  void write() {
    for (final group in _catalog) {
      _writeGroup(group);
    }
    _writeGeneratedJson('performance_run_manifest.json', _manifestJson());
    _writeGeneratedJson('comparison_summary.json', _comparisonJson());
  }

  void _writeGroup(_FixtureGroup group) {
    final manifestPhases = <Map<String, Object?>>[];
    final comparisonPhases = <Map<String, Object?>>[];
    for (final phase in group.phases) {
      final phaseArtifacts = _writePhaseArtifacts(group, phase);
      manifestPhases.add(_manifestPhaseJson(phase, phaseArtifacts.repeats));
      comparisonPhases.add(
        _comparisonPhaseJson(phase, phaseArtifacts.rawByField),
      );
    }
    manifestGroups.add({
      'id': group.id,
      'migration': group.migration,
      'phases': manifestPhases,
    });
    comparisonGroups.add({'id': group.id, 'phases': comparisonPhases});
  }

  ({
    List<Map<String, Object?>> repeats,
    Map<String, List<Map<String, Object?>>> rawByField,
  })
  _writePhaseArtifacts(_FixtureGroup group, _FixturePhase phase) {
    final manifestRepeats = <Map<String, Object?>>[];
    final rawByField = {
      for (final field in _comparisonSummaryFields)
        field: <Map<String, Object?>>[],
    };
    for (var repeat = 1; repeat <= phase.repeats; repeat += 1) {
      final run = _FixtureRun(group: group, phase: phase, repeat: repeat);
      _valueSeed += 1;
      final summary = _timelineSummaryJson(_valueSeed);
      _writeRunArtifacts(results, run, summary);
      manifestRepeats.add(_manifestRepeatJson(run));
      _recordRawRepeats(rawByField, repeat, summary);
    }
    return (repeats: manifestRepeats, rawByField: rawByField);
  }

  void _recordRawRepeats(
    Map<String, List<Map<String, Object?>>> rawByField,
    int repeat,
    Map<String, Object?> summary,
  ) {
    for (final field in _comparisonSummaryFields) {
      rawByField[field]!.add({'repeat': repeat, 'value': summary[field]});
    }
  }

  Map<String, Object?> _manifestPhaseJson(
    _FixturePhase phase,
    List<Map<String, Object?>> repeats,
  ) {
    return {
      'kind': phase.kind,
      'name': phase.name,
      'comparisonRole': phase.comparisonRole,
      'repeats': repeats,
    };
  }

  Map<String, Object?> _comparisonPhaseJson(
    _FixturePhase phase,
    Map<String, List<Map<String, Object?>>> rawByField,
  ) {
    return {
      'kind': phase.kind,
      'name': phase.name,
      'repeatCount': phase.repeats,
      'metrics': [
        for (final field in _comparisonSummaryFields)
          _comparisonMetricJson(field, rawByField[field]!),
      ],
    };
  }

  Map<String, Object?> _manifestJson() {
    return {
      'schemaVersion': 1,
      'route': _route,
      'unsupportedClaims': _unsupportedClaims,
      'scenarioGroups': manifestGroups,
    };
  }

  Map<String, Object?> _comparisonJson() {
    return {
      'schemaVersion': 1,
      'sourceManifest': 'performance_run_manifest.json',
      'routeName': 'flutter_performance',
      'commandFamily': 'flutter drive --profile --no-dds',
      'scenarioGroups': comparisonGroups,
    };
  }

  void _writeGeneratedJson(String fileName, Map<String, Object?> json) {
    File('${results.path}/$fileName').writeAsStringSync(jsonEncode(json));
  }
}

void _writeRunArtifacts(
  Directory results,
  _FixtureRun run,
  Map<String, Object?> summary,
) {
  final directory = Directory('${results.path}/${run.artifactDirectory}')
    ..createSync(recursive: true);
  File('${directory.path}/${run.reportKey}.timeline.json').writeAsStringSync(
    jsonEncode({
      'traceEvents': [
        {
          'name': 'frame',
          'ph': 'X',
          'ts': 1,
          'pid': 1,
          'tid': 1,
          'args': {'threshold': 'official_trace_payload'},
        },
      ],
    }),
  );
  File(
    '${directory.path}/${run.reportKey}.timeline_summary.json',
  ).writeAsStringSync(jsonEncode(summary));
}

Map<String, Object?> _manifestRepeatJson(_FixtureRun run) {
  final repeat = <String, Object?>{
    'repeat': run.repeat,
    'reportKey': run.reportKey,
    'artifactDirectory': run.artifactDirectory,
    'timelineFile': '${run.reportKey}.timeline.json',
    'timelineSummaryFile': '${run.reportKey}.timeline_summary.json',
  };
  if (run.phase.requiresPreparationMetadata) {
    repeat.addAll({
      'canonicalPreparation': run.phase.canonicalPreparation,
      'resetReason': run.phase.resetReason,
      'measuredAction': run.phase.measuredAction,
      'preparationMeasured': false,
    });
  }
  return repeat;
}

Map<String, Object?> _comparisonMetricJson(
  String summaryField,
  List<Map<String, Object?>> rawRepeats,
) {
  final values = rawRepeats.map((repeat) => repeat['value']! as num).toList()
    ..sort();
  final q1q3 = _quartiles(values);
  return {
    'summaryField': summaryField,
    'unit': summaryField.endsWith('_millis') ? 'millis' : 'count',
    'rawRepeats': rawRepeats,
    'median': _median(values),
    'min': values.first,
    'max': values.last,
    'interquartileRange': q1q3.q3 - q1q3.q1,
  };
}

Map<String, Object?> _timelineSummaryJson(int seed) {
  return {
    for (final key in _representativeTimelineSummaryNumberKeys) key: seed,
    'average_frame_build_time_millis': seed.toDouble(),
    'worst_frame_build_time_millis': seed.toDouble() + 1,
    'average_frame_rasterizer_time_millis': seed.toDouble() + 2,
    'worst_frame_rasterizer_time_millis': seed.toDouble() + 3,
    'frame_count': seed,
    'missed_frame_build_budget_count': seed + 1,
    'missed_frame_rasterizer_budget_count': seed + 2,
    'frame_build_times': [1000],
    'frame_rasterizer_times': [1000],
    'frame_begin_times': [0],
    'frame_rasterizer_begin_times': [0],
    'baseline': 'official_summary_payload',
  };
}

Map<String, Object?> _readRootJson(Directory root, String fileName) {
  return (jsonDecode(File('${root.path}/results/$fileName').readAsStringSync())
          as Map<String, dynamic>)
      .cast<String, Object?>();
}

void _writeRootJson(
  Directory root,
  String fileName,
  Map<String, Object?> value,
) {
  File('${root.path}/results/$fileName').writeAsStringSync(jsonEncode(value));
}

Map<String, Object?> _manifestPhase(
  Map<String, Object?> manifest, {
  required String groupId,
  required String phaseKey,
}) {
  final group = _jsonList(
    manifest['scenarioGroups'],
  ).singleWhere((group) => group['id'] == groupId);
  return _jsonList(
    group['phases'],
  ).singleWhere((phase) => '${phase['kind']}.${phase['name']}' == phaseKey);
}

Map<String, Object?> _manifestRepeat(
  Map<String, Object?> manifest, {
  required String groupId,
  required String phaseKey,
  required int repeat,
}) {
  final phase = _manifestPhase(manifest, groupId: groupId, phaseKey: phaseKey);
  return _jsonList(
    phase['repeats'],
  ).singleWhere((repeatJson) => repeatJson['repeat'] == repeat);
}

List<Map<String, Object?>> _comparisonMetrics(
  Map<String, Object?> comparison, {
  required String groupId,
  required String phaseKey,
}) {
  return _jsonList(
    _comparisonPhase(
      comparison,
      groupId: groupId,
      phaseKey: phaseKey,
    )['metrics'],
  );
}

Map<String, Object?> _comparisonPhase(
  Map<String, Object?> comparison, {
  required String groupId,
  required String phaseKey,
}) {
  final group = _jsonList(
    comparison['scenarioGroups'],
  ).singleWhere((group) => group['id'] == groupId);
  return _jsonList(
    group['phases'],
  ).singleWhere((phase) => '${phase['kind']}.${phase['name']}' == phaseKey);
}

Map<String, Object?> _metric(
  Map<String, Object?> comparison, {
  required String groupId,
  required String phaseKey,
  required String summaryField,
}) {
  return _comparisonMetrics(
    comparison,
    groupId: groupId,
    phaseKey: phaseKey,
  ).singleWhere((metric) => metric['summaryField'] == summaryField);
}

List<Map<String, Object?>> _jsonList(Object? value) {
  if (value is! List<Object?>) {
    throw StateError('Expected a JSON array in test fixture.');
  }
  return value.cast<Map<String, Object?>>();
}

({num q1, num q3}) _quartiles(List<num> sortedValues) {
  if (sortedValues.length == 1) {
    return (q1: sortedValues.single, q3: sortedValues.single);
  }
  if (sortedValues.length == 2) {
    return (q1: sortedValues.first, q3: sortedValues.last);
  }
  final midpoint = sortedValues.length ~/ 2;
  final lowerHalf = sortedValues.sublist(0, midpoint);
  final upperHalf = sortedValues.length.isOdd
      ? sortedValues.sublist(midpoint + 1)
      : sortedValues.sublist(midpoint);
  return (q1: _median(lowerHalf), q3: _median(upperHalf));
}

num _median(List<num> sortedValues) {
  final midpoint = sortedValues.length ~/ 2;
  if (sortedValues.length.isOdd) {
    return sortedValues[midpoint];
  }
  return (sortedValues[midpoint - 1] + sortedValues[midpoint]) / 2;
}

const _route = {
  'name': 'flutter_performance',
  'commandFamily': 'flutter drive --profile --no-dds',
  'driver': 'test_driver/perf_driver.dart',
  'target': 'integration_test/perf_canvas_surface_test.dart',
};

const _unsupportedClaims = {
  'numericThresholds': false,
  'passFailPerformance': false,
  'baselines': false,
  'regressionStatusClaims': false,
  'cpuAttribution': false,
  'startup': false,
  'androidMacrobenchmark': false,
};

const _comparisonSummaryFields = [
  'average_frame_build_time_millis',
  'worst_frame_build_time_millis',
  'average_frame_rasterizer_time_millis',
  'worst_frame_rasterizer_time_millis',
  'frame_count',
  'missed_frame_build_budget_count',
  'missed_frame_rasterizer_budget_count',
];

final _catalog = [
  for (final group in catalog.performanceScenarioCatalogGroups)
    _FixtureGroup(
      id: group.id,
      migration: group.migration,
      phases: [
        for (final phase in group.phases)
          _FixturePhase(
            kind: phase.kind,
            name: phase.name,
            comparisonRole: phase.comparisonRole,
            repeats: phase.repeats,
            canonicalPreparation: phase.canonicalPreparation,
            resetReason: phase.resetReason,
            measuredAction: phase.measuredAction,
          ),
      ],
    ),
];

const _representativeTimelineSummaryNumberKeys = [
  'average_frame_build_time_millis',
  '90th_percentile_frame_build_time_millis',
  '99th_percentile_frame_build_time_millis',
  'worst_frame_build_time_millis',
  'missed_frame_build_budget_count',
  'average_frame_rasterizer_time_millis',
  'stddev_frame_rasterizer_time_millis',
  '90th_percentile_frame_rasterizer_time_millis',
  '99th_percentile_frame_rasterizer_time_millis',
  'worst_frame_rasterizer_time_millis',
  'missed_frame_rasterizer_budget_count',
  'frame_count',
  'frame_rasterizer_count',
  'new_gen_gc_count',
  'old_gen_gc_count',
  'average_vsync_transitions_missed',
  '90th_percentile_vsync_transitions_missed',
  '99th_percentile_vsync_transitions_missed',
  'average_vsync_frame_lag',
  '90th_percentile_vsync_frame_lag',
  '99th_percentile_vsync_frame_lag',
  'average_layer_cache_count',
  '90th_percentile_layer_cache_count',
  '99th_percentile_layer_cache_count',
  'average_frame_request_pending_latency',
  '90th_percentile_frame_request_pending_latency',
  '99th_percentile_frame_request_pending_latency',
  'worst_layer_cache_count',
  'average_layer_cache_memory',
  '90th_percentile_layer_cache_memory',
  '99th_percentile_layer_cache_memory',
  'worst_layer_cache_memory',
  'average_picture_cache_count',
  '90th_percentile_picture_cache_count',
  '99th_percentile_picture_cache_count',
  'worst_picture_cache_count',
  'average_picture_cache_memory',
  '90th_percentile_picture_cache_memory',
  '99th_percentile_picture_cache_memory',
  'worst_picture_cache_memory',
  'total_ui_gc_time',
  '30hz_frame_percentage',
  '60hz_frame_percentage',
  '80hz_frame_percentage',
  '90hz_frame_percentage',
  '120hz_frame_percentage',
  'illegal_refresh_rate_frame_count',
  'average_gpu_frame_time',
  '90th_percentile_gpu_frame_time',
  '99th_percentile_gpu_frame_time',
  'worst_gpu_frame_time',
  'average_gpu_memory_mb',
  '90th_percentile_gpu_memory_mb',
  '99th_percentile_gpu_memory_mb',
  'worst_gpu_memory_mb',
];

final class _FixtureGroup {
  const _FixtureGroup({
    required this.id,
    required this.migration,
    required this.phases,
  });

  final String id;
  final String migration;
  final List<_FixturePhase> phases;
}

final class _FixturePhase {
  const _FixturePhase({
    required this.kind,
    required this.name,
    required this.comparisonRole,
    this.repeats = 1,
    this.canonicalPreparation,
    this.resetReason,
    this.measuredAction,
  });

  final String kind;
  final String name;
  final String comparisonRole;
  final int repeats;
  final String? canonicalPreparation;
  final String? resetReason;
  final String? measuredAction;

  String get key => '$kind.$name';

  bool get requiresPreparationMetadata => kind == 'warm' || kind == 'steady';
}

final class _FixtureRun {
  const _FixtureRun({
    required this.group,
    required this.phase,
    required this.repeat,
  });

  final _FixtureGroup group;
  final _FixturePhase phase;
  final int repeat;

  String get reportKey =>
      '${group.id}__${phase.key}__repeat_${repeat.toString().padLeft(3, '0')}';

  String get artifactDirectory =>
      '${group.id}/${phase.key}/repeat_${repeat.toString().padLeft(3, '0')}';
}
