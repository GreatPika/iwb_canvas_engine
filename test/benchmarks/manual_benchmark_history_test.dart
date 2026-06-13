import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

import '../../tool/bench/src/manual_benchmark_history.dart';

void main() {
  late Directory sandbox;

  setUp(() {
    sandbox = Directory.systemTemp.createTempSync(
      'manual_benchmark_history_test_',
    );
  });

  tearDown(() {
    sandbox.deleteSync(recursive: true);
  });

  _registerArchiveTests(() => sandbox);
  _registerBoundaryTests(() => sandbox);
}

void _registerArchiveTests(Directory Function() sandbox) {
  test('archives a full benchmark report as committed history', () {
    final history = _archivesFullBenchmarkReport(sandbox());
    expect(history['kind'], 'manual_benchmark_history');
  });

  test('archives a single-case probe log', () {
    final history = _archivesSingleCaseProbeLog(sandbox());
    expect(history['caseCount'], 1);
  });

  test('updates the manual history index without duplicate paths', () {
    final index = _updatesManualHistoryIndex(sandbox());
    expect(index['records'], hasLength(1));
  });
}

void _registerBoundaryTests(Directory Function() sandbox) {
  _registerOptionBoundaryTests();
  _registerSourceBoundaryTests(sandbox);
  _registerProbeFailureTests(sandbox);
  _registerProbeIdentityTests(sandbox);
}

void _registerOptionBoundaryTests() {
  test('rejects unknown manual history options', () {
    expect(
      () => ManualBenchmarkHistoryOptions.parse([
        '--label=run',
        '--report=build/bench/current/report.json',
        '--history-typo=value',
      ]),
      throwsA(isA<FormatException>()),
    );
  });
}

void _registerSourceBoundaryTests(Directory Function() sandbox) {
  test('rejects history sources without valid raw samples', () {
    expect(
      () => _archiveMalformedSamples(sandbox()),
      throwsA(isA<FormatException>()),
    );
  });

  _registerReportSchemaBoundaryTest(sandbox);
  _registerReportPolicyBoundaryTests(sandbox);
}

void _registerReportSchemaBoundaryTest(Directory Function() sandbox) {
  test('rejects stale report schema sources', () {
    expect(
      () => _archiveOldVocabularyReport(
        sandbox(),
        mutate: (report, _) {
          report['schemaVersion'] = 3;
        },
      ),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          contains('schemaVersion must be 4'),
        ),
      ),
    );
  });
}

void _registerReportPolicyBoundaryTests(Directory Function() sandbox) {
  test('rejects retired report case policy fields', () {
    expect(
      () => _archiveOldVocabularyReport(
        sandbox(),
        mutate: (_, benchmarkCase) {
          benchmarkCase
            ..remove('baselinePolicy')
            ..['classification'] = 'equivalent_legacy';
        },
      ),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          contains('retired field classification'),
        ),
      ),
    );
  });

  test('rejects retired report metric fields', () {
    expect(
      () => _archiveOldVocabularyReport(
        sandbox(),
        mutate: (_, benchmarkCase) {
          final metrics = benchmarkCase['metrics'] as Map<String, Object?>;
          metrics['legacy_avg_us'] = 19814;
        },
      ),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          contains('retired metric legacy_avg_us'),
        ),
      ),
    );
  });
}

void _registerProbeFailureTests(Directory Function() sandbox) {
  test('rejects probe logs without identifiable case names', () {
    expect(
      () => _archiveUnidentifiedProbe(sandbox()),
      throwsA(isA<FormatException>()),
    );
  });

  test('rejects retired probe log metric fields', () {
    final probePath = '${sandbox().path}/run_input_draw_preview_1k.log';
    final probe = _probeJson();
    final metrics = probe['metrics'] as Map<String, Object?>;
    metrics['legacy_avg_us'] = 19947;
    File(
      probePath,
    ).writeAsStringSync('BENCHMARK_PROBE_JSON:${jsonEncode(probe)}\n');

    expect(
      () => _archiveProbePath(sandbox(), probePath, 'retired-probe-metric'),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          contains('retired metric legacy_avg_us'),
        ),
      ),
    );
  });
}

void _registerProbeIdentityTests(Directory Function() sandbox) {
  test('allows empty setup samples only for setup-scope none', () {
    final history = _archiveNoSetupProbe(sandbox());
    final benchmarkCase =
        (history['cases'] as List<Object?>).single as Map<String, Object?>;
    final sampleSummary =
        benchmarkCase['sampleSummary'] as Map<String, Object?>;
    expect(sampleSummary['setupUs'], containsPair('count', 0));
  });

  test('accepts non-edit probe case owners', () {
    final history = _archiveInputProbe(sandbox());
    final benchmarkCase =
        (history['cases'] as List<Object?>).single as Map<String, Object?>;
    expect(benchmarkCase['id'], 'input.draw_preview');
  });

  test('accepts non-numeric manifest scale ids', () {
    final history = _archiveFrameScaleProbe(sandbox());
    final benchmarkCase =
        (history['cases'] as List<Object?>).single as Map<String, Object?>;
    expect(benchmarkCase['scale'], 'active_previews');
  });
}

void _archiveMalformedSamples(Directory sandbox) {
  final outputPath = '${sandbox.path}/history/malformed.json';
  final reportPath = '${sandbox.path}/pixel6_release.json';
  final report = _reportJson();
  final benchmarkCase =
      (report['cases'] as List<Object?>).single as Map<String, Object?>;
  benchmarkCase['actionUsSamples'] = [100, 'bad'];
  File(reportPath).writeAsStringSync(jsonEncode(report));

  writeManualBenchmarkHistory(
    options: ManualBenchmarkHistoryOptions(
      label: 'bad-samples',
      reportPaths: [reportPath],
      output: outputPath,
      historyRoot: '${sandbox.path}/history',
    ),
    git: const ManualBenchmarkGitState(head: '9369b6f2', dirty: false),
    recordedAtUtc: DateTime.utc(2026, 6, 6, 17, 42),
  );
}

void _archiveOldVocabularyReport(
  Directory sandbox, {
  required void Function(
    Map<String, Object?> report,
    Map<String, Object?> benchmarkCase,
  )
  mutate,
}) {
  final outputPath = '${sandbox.path}/history/old-vocabulary.json';
  final reportPath = '${sandbox.path}/old_vocabulary_release.json';
  final report = _reportJson();
  final benchmarkCase =
      (report['cases'] as List<Object?>).single as Map<String, Object?>;
  mutate(report, benchmarkCase);
  File(reportPath).writeAsStringSync(jsonEncode(report));

  writeManualBenchmarkHistory(
    options: ManualBenchmarkHistoryOptions(
      label: 'old-vocabulary',
      reportPaths: [reportPath],
      output: outputPath,
      historyRoot: '${sandbox.path}/history',
    ),
    git: const ManualBenchmarkGitState(head: '9369b6f2', dirty: false),
    recordedAtUtc: DateTime.utc(2026, 6, 6, 17, 42),
  );
}

void _archiveUnidentifiedProbe(Directory sandbox) {
  final probePath = '${sandbox.path}/probe.log';
  File(
    probePath,
  ).writeAsStringSync('BENCHMARK_PROBE_JSON:${jsonEncode(_probeJson())}\n');

  writeManualBenchmarkHistory(
    options: ManualBenchmarkHistoryOptions(
      label: 'bad-probe-name',
      probeLogPaths: [probePath],
      output: '${sandbox.path}/history/probe.json',
      historyRoot: '${sandbox.path}/history',
    ),
    git: const ManualBenchmarkGitState(head: '9369b6f2', dirty: false),
    recordedAtUtc: DateTime.utc(2026, 6, 6, 17, 42),
  );
}

Map<String, Object?> _archiveNoSetupProbe(Directory sandbox) {
  final probePath =
      '${sandbox.path}/run_diagnostics_disabled_pointer_hot_pointer.log';
  final probe = _probeJson()
    ..['measurementBoundary'] = {
      'timedScope': 'action_only',
      'setupScope': 'none',
    }
    ..['setupUsSamples'] = const [];
  File(
    probePath,
  ).writeAsStringSync('BENCHMARK_PROBE_JSON:${jsonEncode(probe)}\n');
  return _archiveProbePath(sandbox, probePath, 'no-setup');
}

Map<String, Object?> _archiveInputProbe(Directory sandbox) {
  final probePath = '${sandbox.path}/run_input_draw_preview_1k.log';
  File(
    probePath,
  ).writeAsStringSync('BENCHMARK_PROBE_JSON:${jsonEncode(_probeJson())}\n');
  return _archiveProbePath(sandbox, probePath, 'input-owner');
}

Map<String, Object?> _archiveFrameScaleProbe(Directory sandbox) {
  final probePath =
      '${sandbox.path}/run_frame_overlay_capture_active_previews.log';
  File(
    probePath,
  ).writeAsStringSync('BENCHMARK_PROBE_JSON:${jsonEncode(_probeJson())}\n');
  return _archiveProbePath(sandbox, probePath, 'frame-scale');
}

Map<String, Object?> _archiveProbePath(
  Directory sandbox,
  String probePath,
  String label,
) {
  final outputPath = '${sandbox.path}/history/$label.json';
  writeManualBenchmarkHistory(
    options: ManualBenchmarkHistoryOptions(
      label: label,
      probeLogPaths: [probePath],
      output: outputPath,
      historyRoot: '${sandbox.path}/history',
    ),
    git: const ManualBenchmarkGitState(head: '9369b6f2', dirty: false),
    recordedAtUtc: DateTime.utc(2026, 6, 6, 17, 42),
  );
  return _readJson(outputPath);
}

Map<String, Object?> _archivesFullBenchmarkReport(Directory sandbox) {
  final outputPath = '${sandbox.path}/history/pixel6.json';

  final writtenPath = writeManualBenchmarkHistory(
    options: _fullReportOptions(sandbox, outputPath),
    git: const ManualBenchmarkGitState(head: '9369b6f2', dirty: false),
    recordedAtUtc: DateTime.utc(2026, 6, 6, 17, 42),
  );

  expect(writtenPath, outputPath);
  final history = _readJson(outputPath);
  _expectFullReportHistory(history);
  return history;
}

ManualBenchmarkHistoryOptions _fullReportOptions(
  Directory sandbox,
  String outputPath,
) {
  final reportPath = '${sandbox.path}/pixel6_release.json';
  File(reportPath).writeAsStringSync(jsonEncode(_reportJson()));

  return ManualBenchmarkHistoryOptions(
    label: 'sparse-update-source',
    reportPaths: [reportPath],
    deviceName: 'Pixel 6',
    deviceOs: 'Android 16',
    referencePath:
        'tool/bench/manual/reference_reports/xiaomi_22081283g_android14_flutter_3_44_0.json',
    output: outputPath,
    historyRoot: '${sandbox.path}/history',
  );
}

void _expectFullReportHistory(Map<String, Object?> history) {
  expect(history['kind'], 'manual_benchmark_history');
  expect(history['label'], 'sparse-update-source');
  expect(history['subjectGitHead'], '9369b6f2');
  expect(history['caseCount'], 1);
  expect(history['device'], {
    'name': 'Pixel 6',
    'id': '23081FDF6000L2',
    'os': 'Android 16',
  });
  expect(history['profile'], containsPair('id', 'release'));
  _expectSingleSourceFingerprint(history);
  _expectSingleCaseId(history, 'edit.update_transform');
}

Map<String, Object?> _archivesSingleCaseProbeLog(Directory sandbox) {
  final probePath =
      '${sandbox.path}/step57_after_source_bound_edit_update_visual_rerun_100k.log';
  File(
    probePath,
  ).writeAsStringSync('BENCHMARK_PROBE_JSON:${jsonEncode(_probeJson())}\n');
  final outputPath = '${sandbox.path}/history/probe.json';

  writeManualBenchmarkHistory(
    options: ManualBenchmarkHistoryOptions(
      label: 'visual-rerun',
      probeLogPaths: [probePath],
      deviceName: 'Pixel 6',
      deviceId: '23081FDF6000L2',
      output: outputPath,
      historyRoot: '${sandbox.path}/history',
    ),
    git: const ManualBenchmarkGitState(head: '9369b6f2', dirty: true),
    recordedAtUtc: DateTime.utc(2026, 6, 6, 17, 50),
  );

  final history = _readJson(outputPath);
  expect(history['repositoryDirty'], isTrue);
  expect(history['device'], {
    'name': 'Pixel 6',
    'id': '23081FDF6000L2',
    'os': null,
  });
  _expectSingleProbeCase(history);
  return history;
}

Map<String, Object?> _updatesManualHistoryIndex(Directory sandbox) {
  final reportPath = '${sandbox.path}/pixel6_release.json';
  File(reportPath).writeAsStringSync(jsonEncode(_reportJson()));
  final outputPath = '${sandbox.path}/manual/pixel6.json';
  _writeIndexedHistoryTwice(sandbox, reportPath, outputPath);

  final index = _readJson('${sandbox.path}/manual/index.json');
  _expectSingleIndexedHistoryRecord(index, outputPath);
  return index;
}

void _writeIndexedHistoryTwice(
  Directory sandbox,
  String reportPath,
  String outputPath,
) {
  for (var run = 0; run < 2; run += 1) {
    writeManualBenchmarkHistory(
      options: ManualBenchmarkHistoryOptions(
        label: 'indexed-run',
        reportPaths: [reportPath],
        output: outputPath,
        historyRoot: '${sandbox.path}/manual',
        overwrite: true,
      ),
      git: const ManualBenchmarkGitState(head: '9369b6f2', dirty: false),
      recordedAtUtc: DateTime.utc(2026, 6, 6, 18, run),
    );
  }
}

void _expectSingleIndexedHistoryRecord(
  Map<String, Object?> index,
  String outputPath,
) {
  final records = index['records'] as List<Object?>;
  final matching = records.whereType<Map<String, Object?>>().where(
    (record) => record['path'] == outputPath,
  );
  expect(matching, hasLength(1));
  _expectIndexedSourceFingerprint(matching.single);
}

void _expectIndexedSourceFingerprint(Map<String, Object?> record) {
  final indexedSource =
      (record['sources'] as List<Object?>).single as Map<String, Object?>;
  expect(indexedSource['manifestFingerprint'], 'e244be03');
  expect(indexedSource['source'], contains('sha256'));
}

void _expectSingleCaseId(Map<String, Object?> history, String id) {
  final cases = history['cases'] as List<Object?>;
  expect((cases.single as Map<String, Object?>)['id'], id);
}

void _expectSingleProbeCase(Map<String, Object?> history) {
  final cases = history['cases'] as List<Object?>;
  final benchmarkCase = cases.single as Map<String, Object?>;
  expect(benchmarkCase['id'], 'edit.update_visual');
  expect(benchmarkCase['scale'], '100k');
  expect(benchmarkCase['baselinePolicy'], 'reference_comparison');
  expect(benchmarkCase, isNot(contains('actionUsSamples')));
  expect(benchmarkCase, isNot(contains('setupUsSamples')));
  final sampleSummary = benchmarkCase['sampleSummary'] as Map<String, Object?>;
  expect(sampleSummary['actionUs'], containsPair('count', 3));
  expect(sampleSummary['actionUs'], containsPair('avg_us', 20030));
  expect(sampleSummary['actionUs'], containsPair('p95_us', 20356));
}

void _expectSingleSourceFingerprint(Map<String, Object?> history) {
  final sources = history['sources'] as List<Object?>;
  final source = (sources.single as Map<String, Object?>)['source'];
  expect(source, containsPair('sizeBytes', isA<int>()));
  expect(source, containsPair('sha256', isA<String>()));
}

Map<String, Object?> _reportJson() {
  return {
    'schemaVersion': 4,
    'manifestVersion': 'benchmark_measurement_boundary_v3',
    'manifestFingerprint': 'e244be03',
    'profile': {
      'id': 'release',
      'warmups': 1,
      'repetitions': 5,
      'iterations': null,
      'minimumMeasuredMs': 2000,
      'minimumSamples': 0,
      'timingClaims': true,
      'scaleSelection': 'all_required_scales',
    },
    'runtime': _runtimeJson(deviceId: '23081FDF6000L2'),
    'cases': [
      {
        'id': 'edit.update_transform',
        'scale': '100k',
        'baselinePolicy': 'reference_comparison',
        'fixtureShape': 'normal_spread',
        'measurementBoundary': {
          'timedScope': 'action_only',
          'setupScope': 'per_sample_prepared_fixture',
        },
        'metrics': {
          'avg_us': 19814,
          'p95_us': 21492,
          'max_us': 21492,
          'allocation_bytes': 11780096,
        },
        'setupMetrics': {'setup_us': 987718},
        'actionUsSamples': [21492, 20300, 17264],
        'setupUsSamples': [990000, 980000, 970000],
      },
    ],
  };
}

Map<String, Object?> _probeJson() {
  return {
    'runtime': _runtimeJson(),
    'fixtureShape': 'normal_spread',
    'measurementBoundary': {
      'timedScope': 'action_only',
      'setupScope': 'per_sample_prepared_fixture',
    },
    'metrics': {
      'avg_us': 19947,
      'p95_us': 20356,
      'max_us': 20356,
      'allocation_bytes': 11780096,
    },
    'setupMetrics': {'setup_us': 1000000},
    'actionUsSamples': [20356, 20248, 19487],
    'setupUsSamples': [1010000, 1000000, 990000],
  };
}

Map<String, Object?> _runtimeJson({String? deviceId}) {
  return {
    'runnerLabel': 'local',
    'osName': 'macos',
    'osVersion': 'Version 15.5',
    'dartVersion': '3.12.0',
    'flutterChannel': 'stable',
    'flutterVersion': '3.44.0',
    'releaseContour': {'flutterVersion': '3.44.0'},
    'profileId': 'release',
    'runtimeMode': 'flutter_test',
    'assertionsEnabled': true,
    'debugInvariantMode': false,
    'deviceId': deviceId,
  };
}

Map<String, Object?> _readJson(String path) {
  return jsonDecode(File(path).readAsStringSync()) as Map<String, Object?>;
}
