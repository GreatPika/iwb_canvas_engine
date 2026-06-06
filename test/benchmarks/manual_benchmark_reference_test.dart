import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

import '../../tool/bench/src/manual_benchmark_reference.dart';

void main() {
  late Directory sandbox;

  setUp(() {
    sandbox = Directory.systemTemp.createTempSync(
      'manual_benchmark_reference_test_',
    );
  });

  tearDown(() {
    sandbox.deleteSync(recursive: true);
  });

  _registerReferenceAcceptanceTests(() => sandbox);
  _registerReferenceBoundaryTests(() => sandbox);
}

void _registerReferenceAcceptanceTests(Directory Function() sandbox) {
  _registerBootstrapReferenceTest(sandbox);
  _registerStableWindowReferenceTest(sandbox);
}

void _registerBootstrapReferenceTest(Directory Function() sandbox) {
  test('bootstraps a manual reference from an explicit history run', () {
    final runPath = _writeHistoryRun(sandbox(), 'run1', avgUs: 100);
    final outputPath = '${sandbox().path}/reference/pixel.json';

    _acceptBootstrapReference(sandbox(), runPath, outputPath);
    final reference = _readJson(outputPath);

    expect(reference['kind'], 'manual_benchmark_reference');
    expect(reference['selectionPolicy'], 'bootstrap_single_run_v1');
    expect(reference['acceptedReason'], 'initial reference');
    expect(reference['acceptedFromRuns'], [runPath]);
  });
}

void _registerStableWindowReferenceTest(Directory Function() sandbox) {
  test('stable window uses median numeric metrics', () {
    final runs = [
      _writeHistoryRun(
        sandbox(),
        'run1',
        avgUs: 120,
        fixture: _cleanReleaseHistoryFixture,
      ),
      _writeHistoryRun(
        sandbox(),
        'run2',
        avgUs: 100,
        fixture: _cleanReleaseHistoryFixture,
      ),
      _writeHistoryRun(
        sandbox(),
        'run3',
        avgUs: 110,
        fixture: _cleanReleaseHistoryFixture,
      ),
    ];
    final outputPath = '${sandbox().path}/reference/stable.json';

    _acceptStableReference(sandbox(), runs, outputPath);
    final reference = _readJson(outputPath);
    final benchmarkCase =
        (reference['cases'] as List<Object?>).single as Map<String, Object?>;
    final metrics = benchmarkCase['metrics'] as Map<String, Object?>;

    expect(reference['selectionPolicy'], 'stable_window_median_v1');
    expect(metrics['avg_us'], 110);
  });
}

void _acceptBootstrapReference(
  Directory sandbox,
  String runPath,
  String outputPath,
) {
  writeManualBenchmarkReference(
    options: ManualBenchmarkReferenceOptions(
      runPaths: [runPath],
      output: outputPath,
      reason: 'initial reference',
      policy: 'bootstrap_single_run_v1',
      decisionLog: '${sandbox.path}/reference_decisions.json',
      allowDirtyRuns: true,
      allowUnrecordedSubject: true,
      overwrite: false,
    ),
    acceptedAtUtc: DateTime.utc(2026, 6, 6, 19, 50),
  );
}

void _acceptStableReference(
  Directory sandbox,
  List<String> runPaths,
  String outputPath,
) {
  writeManualBenchmarkReference(
    options: ManualBenchmarkReferenceOptions(
      runPaths: runPaths,
      output: outputPath,
      reason: 'stable window',
      policy: 'stable_window_median_v1',
      decisionLog: '${sandbox.path}/reference_decisions.json',
      allowDirtyRuns: false,
      allowUnrecordedSubject: false,
      overwrite: false,
    ),
    acceptedAtUtc: DateTime.utc(2026, 6, 6, 20),
  );
}

void _registerReferenceBoundaryTests(Directory Function() sandbox) {
  _registerStableWindowSizeTest(sandbox);
  _registerStableWindowDistinctRunTest(sandbox);
  _registerStableWindowDistinctSourceTest(sandbox);
  _registerReleaseProfileRequiredTest(sandbox);
  _registerDirtyHistoryRejectionTest(sandbox);
  _registerUnknownOptionRejectionTest();
}

void _registerStableWindowSizeTest(Directory Function() sandbox) {
  test('stable reference requires at least three runs', () {
    final runPath = _writeHistoryRun(sandbox(), 'run1', avgUs: 100);

    expect(
      () => writeManualBenchmarkReference(
        options: ManualBenchmarkReferenceOptions(
          runPaths: [runPath],
          output: '${sandbox().path}/reference/fail.json',
          reason: 'too small',
          policy: 'stable_window_median_v1',
          decisionLog: '${sandbox().path}/reference_decisions.json',
          allowDirtyRuns: true,
          allowUnrecordedSubject: true,
          overwrite: false,
        ),
        acceptedAtUtc: DateTime.utc(2026, 6, 6, 20),
      ),
      throwsA(isA<FormatException>()),
    );
  });
}

void _registerStableWindowDistinctRunTest(Directory Function() sandbox) {
  test('stable reference rejects repeated history runs', () {
    final runPath = _writeHistoryRun(
      sandbox(),
      'run1',
      avgUs: 100,
      fixture: _cleanReleaseHistoryFixture,
    );

    expect(
      () => _acceptStableReference(sandbox(), [
        runPath,
        runPath,
        runPath,
      ], '${sandbox().path}/reference/fail.json'),
      throwsA(isA<FormatException>()),
    );
  });
}

void _registerStableWindowDistinctSourceTest(Directory Function() sandbox) {
  test('stable reference rejects reused source fingerprints', () {
    final runs = [
      _writeCleanMultiSourceHistoryRun(sandbox(), 'run1', 100, const [
        'shared',
        'run1-only',
      ]),
      _writeCleanMultiSourceHistoryRun(sandbox(), 'run2', 110, const [
        'shared',
        'run2-only',
      ]),
      _writeCleanMultiSourceHistoryRun(sandbox(), 'run3', 120, const [
        'run3-a',
        'run3-b',
      ]),
    ];

    expect(
      () => _acceptStableReference(
        sandbox(),
        runs,
        '${sandbox().path}/reference/fail.json',
      ),
      throwsA(isA<FormatException>()),
    );
  });
}

String _writeCleanMultiSourceHistoryRun(
  Directory sandbox,
  String name,
  int avgUs,
  List<String> sourceShas,
) {
  return _writeHistoryRun(
    sandbox,
    name,
    avgUs: avgUs,
    fixture: (dirty: false, profileId: 'release', sourceShas: sourceShas),
  );
}

void _registerReleaseProfileRequiredTest(Directory Function() sandbox) {
  test('reference rejects non-release history', () {
    final runPath = _writeHistoryRun(
      sandbox(),
      'run1',
      avgUs: 100,
      fixture: _dryRunHistoryFixture,
    );

    expect(
      () => _acceptBootstrapReference(
        sandbox(),
        runPath,
        '${sandbox().path}/reference/fail.json',
      ),
      throwsA(isA<FormatException>()),
    );
  });
}

void _registerDirtyHistoryRejectionTest(Directory Function() sandbox) {
  test('reference rejects dirty history without explicit override', () {
    final runPath = _writeHistoryRun(sandbox(), 'run1', avgUs: 100);

    expect(
      () => writeManualBenchmarkReference(
        options: ManualBenchmarkReferenceOptions(
          runPaths: [runPath],
          output: '${sandbox().path}/reference/fail.json',
          reason: 'dirty',
          policy: 'bootstrap_single_run_v1',
          decisionLog: '${sandbox().path}/reference_decisions.json',
          allowDirtyRuns: false,
          allowUnrecordedSubject: true,
          overwrite: false,
        ),
        acceptedAtUtc: DateTime.utc(2026, 6, 6, 20),
      ),
      throwsA(isA<FormatException>()),
    );
  });
}

void _registerUnknownOptionRejectionTest() {
  test('reference CLI rejects unknown options', () {
    expect(
      () => ManualBenchmarkReferenceOptions.parse(const ['--typo=value']),
      throwsA(isA<FormatException>()),
    );
    expect(
      () => ManualBenchmarkReferenceOptions.parse(const ['--allow-magic']),
      throwsA(isA<FormatException>()),
    );
  });
}

String _writeHistoryRun(
  Directory sandbox,
  String name, {
  required int avgUs,
  ({bool dirty, String profileId, List<String> sourceShas}) fixture =
      _defaultHistoryFixture,
}) {
  final path = '${sandbox.path}/$name.json';
  final sourceShas = fixture.sourceShas.isEmpty
      ? ['sha-$name']
      : fixture.sourceShas;
  File(path).writeAsStringSync(
    jsonEncode(
      _historyJson(
        avgUs: avgUs,
        dirty: fixture.dirty,
        profileId: fixture.profileId,
        sourceShas: sourceShas,
      ),
    ),
  );
  return path;
}

const _defaultHistoryFixture = (
  dirty: true,
  profileId: 'release',
  sourceShas: <String>[],
);
const _cleanReleaseHistoryFixture = (
  dirty: false,
  profileId: 'release',
  sourceShas: <String>[],
);
const _dryRunHistoryFixture = (
  dirty: true,
  profileId: 'dry_run',
  sourceShas: <String>[],
);

Map<String, Object?> _historyJson({
  required int avgUs,
  required bool dirty,
  required String profileId,
  required List<String> sourceShas,
}) {
  return {
    'schemaVersion': 1,
    'kind': 'manual_benchmark_history',
    'recordedAtUtc': '2026-06-06T19:42:05Z',
    'label': 'run',
    'subjectGitHead': dirty ? 'unrecorded-local' : '9369b6f2',
    'repositoryDirty': dirty,
    'device': {'name': 'Pixel 6', 'id': 'device', 'os': 'Android 16'},
    'profile': _profileJson(profileId),
    'toolchain': _toolchainJson(profileId),
    'referenceReport': {'kind': null, 'path': null},
    'sources': [
      for (final sourceSha in sourceShas)
        {
          'path': 'build/bench/current/pixel.json',
          'kind': 'report',
          'source': {
            'path': 'build/bench/current/pixel.json',
            'sha256': sourceSha,
          },
          'manifestVersion': 'p14_benchmark_measurement_boundary_v2',
          'manifestFingerprint': 'e244be03',
          'caseCount': 1,
        },
    ],
    'caseCount': 1,
    'cases': [_caseJson(avgUs)],
  };
}

Map<String, Object?> _profileJson(String profileId) {
  return {
    'id': profileId,
    'warmups': profileId == 'release' ? 1 : 0,
    'repetitions': profileId == 'release' ? 5 : 1,
    'iterations': profileId == 'release' ? null : 1,
    'minimumMeasuredMs': profileId == 'release' ? 2000 : 0,
    'minimumSamples': 0,
    'timingClaims': profileId == 'release',
    'scaleSelection': profileId == 'release'
        ? 'all_required_scales'
        : 'all_manifest_scales',
  };
}

Map<String, Object?> _toolchainJson(String profileId) {
  return {
    'profileId': profileId,
    'runtimeMode': 'flutter_test',
    'assertionsEnabled': true,
    'debugInvariantMode': false,
    'runnerLabel': 'local',
    'osName': 'macos',
    'osVersion': 'Version 15.5',
    'dartVersion': '3.12.0',
    'flutterChannel': 'stable',
    'flutterVersion': '3.44.0',
    'releaseContour': {'flutterVersion': '3.38.0'},
  };
}

Map<String, Object?> _caseJson(int avgUs) {
  return {
    'id': 'edit.update_visual',
    'scale': '100k',
    'classification': 'equivalent_legacy',
    'fixtureShape': 'normal_spread',
    'measurementBoundary': {
      'timedScope': 'action_only',
      'setupScope': 'per_sample_prepared_fixture',
      'teardownScope': 'excluded',
      'primaryTiming': 'action',
      'primaryMemory': 'action',
      'setupMetrics': ['setup_us'],
      'setupMemoryMetrics': ['setup_allocation_bytes', 'setup_rss_delta_bytes'],
    },
    'sampleSummary': {
      'actionUs': {'available': true, 'count': 3, 'avg_us': avgUs},
      'setupUs': {'available': true, 'count': 3, 'avg_us': 1000},
    },
    'metrics': {
      'avg_us': avgUs,
      'p95_us': avgUs,
      'max_us': avgUs,
      'allocation_bytes': 100,
      'rss_delta_bytes': 100,
      'legacy_avg_us': avgUs,
      'setup_us': 1000,
    },
    'setupMetrics': {
      'setup_us': 1000,
      'setup_allocation_bytes': 10,
      'setup_rss_delta_bytes': 10,
    },
    'exactInvariants': {},
  };
}

Map<String, Object?> _readJson(String path) {
  return jsonDecode(File(path).readAsStringSync()) as Map<String, Object?>;
}
