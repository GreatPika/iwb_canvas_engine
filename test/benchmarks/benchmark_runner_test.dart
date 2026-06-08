import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

import '../../tool/bench/src/benchmark_case_adapters.dart';
import '../../tool/bench/src/benchmark_manifest.dart';
import '../../tool/bench/src/benchmark_report.dart';
import '../../tool/bench/src/benchmark_runner.dart';

// Runner tests intentionally keep profile behavior, default paths, and manifest
// fingerprint checks together as one report-contract suite.
// ignore: halstead-volume, maintainability-index, source-lines-of-code
void main() {
  group('benchmark runner profiles', () {
    test('exposes CLI help without accepting mixed help arguments', () {
      expect(isBenchmarkRunHelpRequest(['--help']), isTrue);
      expect(isBenchmarkRunHelpRequest(['-h']), isTrue);
      expect(
        isBenchmarkRunHelpRequest(['--profile=dry_run', '--help']),
        isFalse,
      );
      expect(benchmarkRunUsage, contains('Usage:'));
      expect(benchmarkRunUsage, contains('--profile=<profile>'));
      expect(benchmarkRunUsage, contains('--history-label=<label>'));
    });

    test('dry_run covers every manifest scale without timing claims', () {
      final manifest = BenchmarkManifest.load();
      final report = runBenchmarks(manifest: manifest, profileId: 'dry_run');
      final expectedScaleCount = manifest.cases.fold<int>(
        0,
        (count, benchmarkCase) => count + benchmarkCase.scales.length,
      );

      expect(report.profile.id, 'dry_run');
      expect(report.profile.iterations, 1);
      expect(report.profile.repetitions, 1);
      expect(report.profile.timingClaims, isFalse);
      expect(report.cases, hasLength(expectedScaleCount));
      expect(
        report.cases.every((benchmarkCase) => !benchmarkCase.timingClaims),
        isTrue,
      );
    });

    test('case report records boundary metadata and setup diagnostics', () {
      final manifest = _singleCaseManifest();
      final report = runBenchmarks(manifest: manifest, profileId: 'dry_run');
      final benchmarkCase = manifest.cases.first;
      final reportCase = report.cases.first;
      final encodedCase = reportCase.toJson();

      expect(reportCase.actionUsSamples, isNotEmpty);
      expect(reportCase.setupUsSamples, isNotEmpty);
      expect(reportCase.fixtureShape, benchmarkCase.fixtureShape);
      expect(
        reportCase.measurementBoundary.timedScope,
        benchmarkCase.measurementBoundary.timedScope,
      );
      expect(reportCase.setupMetrics, contains('setup_us'));
      expect(
        encodedCase,
        containsPair('measurementBoundary', isA<Map<String, Object?>>()),
      );
      expect(encodedCase, containsPair('actionUsSamples', isA<List<int>>()));
      expect(encodedCase, containsPair('setupUsSamples', isA<List<int>>()));
      expect(
        encodedCase,
        containsPair('setupMetrics', isA<Map<String, Object?>>()),
      );
      expect(
        encodedCase,
        containsPair('fixtureShape', benchmarkCase.fixtureShape),
      );
    });

    test('derives timing metrics only from action samples', () {
      final manifest = _singleCaseManifest();
      final report = runBenchmarks(
        manifest: manifest,
        profileId: 'dry_run',
        adapter: _fakeAdapterWithMetrics(
          {'avg_us': 5000, 'p95_us': 5000, 'max_us': 5000},
          actionUsSamples: [7],
        ),
      );

      expect(report.cases.single.metrics, containsPair('avg_us', 7));
      expect(report.cases.single.metrics, containsPair('p95_us', 7));
      expect(report.cases.single.metrics, containsPair('max_us', 7));
    });

    test('requires setup samples and setup diagnostics', () {
      final manifest = _singleCaseManifest();

      expect(
        () => runBenchmarks(
          manifest: manifest,
          profileId: 'dry_run',
          adapter: _fakeAdapterWithSetupSamples(const []),
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('emitted no setup samples'),
          ),
        ),
      );

      expect(
        () => runBenchmarks(
          manifest: manifest,
          profileId: 'dry_run',
          adapter: _fakeAdapterWithSetupMetrics(const {
            'setup_allocation_bytes': 100,
            'setup_rss_delta_bytes': 100,
          }),
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('missing setup metric setup_us'),
          ),
        ),
      );

      expect(
        () => runBenchmarks(
          manifest: manifest,
          profileId: 'dry_run',
          adapter: _fakeAdapterWithSetupMetrics(const {'setup_us': 5}),
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('missing setup metric setup_allocation_bytes'),
          ),
        ),
      );

      expect(
        () => runBenchmarks(
          manifest: manifest,
          profileId: 'dry_run',
          adapter: _fakeAdapterWithSetupMetrics(const {
            'setup_us': 5,
            'setup_allocation_bytes': '100',
            'setup_rss_delta_bytes': 100,
          }),
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('invalid setup metric setup_allocation_bytes'),
          ),
        ),
      );
    });

    test('requires primary memory metrics from boundary policy', () {
      final manifest = _singleCaseManifest();

      expect(
        () => runBenchmarks(
          manifest: manifest,
          profileId: 'dry_run',
          adapter: _fakeAdapterWithoutRssDelta(),
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('missing primary memory metric rss_delta_bytes'),
          ),
        ),
      );
    });

    test('smoke uses smoke-selected scales and profile parameters', () {
      final manifest = _singleCaseManifest();
      final report = runBenchmarks(manifest: manifest, profileId: 'smoke');
      final expectedSmokeScales = [
        for (final benchmarkCase in manifest.cases)
          for (final scale in benchmarkCase.scales)
            if (scale.profiles.contains('smoke'))
              '${benchmarkCase.id}/${scale.id}',
      ];
      final actualSmokeScales = [
        for (final benchmarkCase in report.cases)
          '${benchmarkCase.id}/${benchmarkCase.scale}',
      ];

      expect(report.profile.warmups, 1);
      expect(report.profile.repetitions, 3);
      expect(report.profile.minimumMeasuredMs, 500);
      expect(report.profile.minimumSamples, 100);
      expect(actualSmokeScales, expectedSmokeScales);
    });

    test(
      'release uses all required scales and the pinned default path',
      () async {
        final manifest = _multiReleaseScaleManifest();
        final outputPath = await runBenchmarkCli([
          '--profile=release',
        ], manifest: manifest);
        final output = File(outputPath);
        final decoded =
            jsonDecode(output.readAsStringSync()) as Map<String, Object?>;
        final cases = decoded['cases'] as List<Object?>;
        final caseScales = [
          for (final entry in cases)
            if (entry case {'id': final String id, 'scale': final String scale})
              '$id/$scale',
        ];
        final firstCase = cases.first as Map<String, Object?>;
        final firstMetrics = firstCase['metrics'] as Map<String, Object?>;

        expect(outputPath, releaseReportPath);
        expect(decoded['profile'], containsPair('id', 'release'));
        expect(caseScales, ['edit.add_element/1k', 'edit.add_element/10k']);
        expect(firstMetrics, containsPair('rss_delta_bytes', isA<int>()));
        expect(firstMetrics.containsKey('legacy_avg_us'), isFalse);
        expect(
          decoded['runtime'],
          containsPair(
            'releaseContour',
            containsPair('runnerLabel', 'ubuntu-24.04'),
          ),
        );
        expect(
          decoded['runtime'],
          containsPair('releaseContour', containsPair('osName', 'Ubuntu')),
        );
        expect(
          decoded['runtime'],
          containsPair('releaseContour', containsPair('osVersion', '24.04')),
        );
        expect(decoded['runtime'], containsPair('osName', isNot('Ubuntu')));
        expect(decoded['runtime'], containsPair('profileId', 'release'));
        expect(decoded['runtime'], containsPair('runtimeMode', 'flutter_test'));
        expect(decoded['runtime'], containsPair('assertionsEnabled', isTrue));
        expect(decoded['runtime'], containsPair('deviceId', isNull));
        output.deleteSync();
      },
    );

    test('writes compact manual history when requested', () async {
      final reportPath = 'build/bench/current/auto_history_report.json';
      final historyRoot = Directory('build/bench/history_test');
      final historyPath = '${historyRoot.path}/auto_history.json';
      _deleteFileIfExists(reportPath);
      if (historyRoot.existsSync()) {
        historyRoot.deleteSync(recursive: true);
      }

      final result = await runBenchmarkCliDetailed([
        '--profile=dry_run',
        '--output=$reportPath',
        '--history-label=auto-history',
        '--history-device-name=Pixel 6',
        '--history-device-os=Android 16',
        '--history-output=$historyPath',
        '--history-root=${historyRoot.path}',
        '--history-allow-dirty',
        '--history-overwrite',
      ], manifest: _singleCaseManifest());
      final historyJson =
          jsonDecode(File(historyPath).readAsStringSync())
              as Map<String, Object?>;
      final historyCase =
          (historyJson['cases'] as List<Object?>).single
              as Map<String, Object?>;

      expect(result.reportPath, reportPath);
      expect(result.historyPath, historyPath);
      expect(historyJson['kind'], 'manual_benchmark_history');
      expect(historyJson['label'], 'auto-history');
      expect(historyCase, isNot(contains('actionUsSamples')));
      expect(historyCase, contains('sampleSummary'));
      expect(
        (historyJson['sources'] as List<Object?>).single,
        containsPair('source', containsPair('sha256', isA<String>())),
      );

      _deleteFileIfExists(reportPath);
      historyRoot.deleteSync(recursive: true);
    });

    test('accepts an explicit device target for real-device probes', () {
      final options = BenchmarkRunOptions.parse([
        '--profile=smoke',
        '--device=23081FDF6000L2',
        '--output=build/bench/current/pixel6_smoke.json',
        '--history-label=device-smoke',
      ]);

      expect(options.profile, 'smoke');
      expect(options.device, '23081FDF6000L2');
      expect(options.output, 'build/bench/current/pixel6_smoke.json');
      expect(options.history?.deviceId, '23081FDF6000L2');
    });

    test('manifest fingerprint covers policy and scale membership', () {
      final manifest = BenchmarkManifest.load();
      final baseline = benchmarkManifestFingerprint(manifest);
      final benchmarkCase = manifest.cases.first;
      final scale = benchmarkCase.scales.first;

      final metricChanged = _withFirstCase(
        manifest,
        _copyCase(
          benchmarkCase,
          requiredMetrics: [...benchmarkCase.requiredMetrics, 'new_metric'],
        ),
      );
      final scaleChanged = _withFirstCase(
        manifest,
        _copyCase(
          benchmarkCase,
          scales: [
            BenchmarkScale(
              id: scale.id,
              label: scale.label,
              profiles: [...scale.profiles, 'extra_profile'],
            ),
            ...benchmarkCase.scales.skip(1),
          ],
        ),
      );
      final fixtureChanged = _withFirstCase(
        manifest,
        _copyCaseWithFixtureShape(benchmarkCase, 'hot_pointer'),
      );

      expect(benchmarkManifestFingerprint(metricChanged), isNot(baseline));
      expect(benchmarkManifestFingerprint(scaleChanged), isNot(baseline));
      expect(benchmarkManifestFingerprint(fixtureChanged), isNot(baseline));
    });

    test('rejects exact invariants without checkable semantics', () {
      final manifest = BenchmarkManifest.load();
      final benchmarkCase = manifest.cases.first;
      final uncheckedInvariantManifest = _withFirstCase(
        _singleCaseManifest(),
        _copyCase(
          benchmarkCase,
          exactInvariants: [
            const BenchmarkExactInvariant(
              name: 'unchecked_test_invariant',
              metric: 'avg_us',
              expected: null,
              max: null,
            ),
          ],
          scales: [benchmarkCase.scales.first],
        ),
      );

      expect(
        () => runBenchmarks(
          manifest: uncheckedInvariantManifest,
          profileId: 'dry_run',
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('has no checkable expected value'),
          ),
        ),
      );
    });

    test('rejects unsupported probe scale ids', () {
      final manifest = BenchmarkManifest.load();
      final benchmarkCase = manifest.cases.first;
      final unsupportedScaleManifest = _withFirstCase(
        _singleCaseManifest(),
        _copyCase(
          benchmarkCase,
          scales: [
            const BenchmarkScale(
              id: 'unknown_scale',
              label: 'unknown scale',
              profiles: ['dry_run', 'release'],
            ),
          ],
        ),
      );

      expect(
        () => runBenchmarks(
          manifest: unsupportedScaleManifest,
          profileId: 'dry_run',
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('Unsupported benchmark scale "unknown_scale"'),
          ),
        ),
      );
    });

    test(
      'rejects non-canonical dry-run spelling and non-transient output',
      () async {
        expect(
          () => runBenchmarks(
            manifest: BenchmarkManifest.load(),
            profileId: 'dry-run',
          ),
          throwsA(isA<FormatException>()),
        );
        await expectLater(
          runBenchmarkCli([
            '--profile=smoke',
            '--output=build/bench/../../tool/bench/report.json',
          ]),
          throwsA(isA<FormatException>()),
        );
        await expectLater(
          runBenchmarkCli([
            '--profile=smoke',
            '--output=build/bench2/report.json',
          ]),
          throwsA(isA<FormatException>()),
        );
        expect(
          () => BenchmarkRunOptions.parse(['--profile=smoke', '--device=']),
          throwsA(isA<FormatException>()),
        );
        expect(
          () => BenchmarkRunOptions.parse([
            '--profile=smoke',
            '--history-label=run',
            '--history-typo=value',
          ]),
          throwsA(isA<FormatException>()),
        );
      },
    );
  });
}

void _deleteFileIfExists(String path) {
  final file = File(path);
  if (file.existsSync()) {
    file.deleteSync();
  }
}

BenchmarkManifest _withFirstCase(
  BenchmarkManifest manifest,
  BenchmarkCase benchmarkCase,
) {
  return BenchmarkManifest(
    manifestVersion: manifest.manifestVersion,
    toolSchemaVersion: manifest.toolSchemaVersion,
    releaseContour: manifest.releaseContour,
    profiles: manifest.profiles,
    budgetClasses: manifest.budgetClasses,
    memoryScopes: manifest.memoryScopes,
    cases: [benchmarkCase, ...manifest.cases.skip(1)],
    postBaselineRegressionCaps: manifest.postBaselineRegressionCaps,
    bootstrapLegacyEquivalence: manifest.bootstrapLegacyEquivalence,
  );
}

BenchmarkManifest _multiReleaseScaleManifest() {
  final manifest = BenchmarkManifest.load();
  final benchmarkCase = manifest.cases.first;
  return BenchmarkManifest(
    manifestVersion: manifest.manifestVersion,
    toolSchemaVersion: manifest.toolSchemaVersion,
    releaseContour: manifest.releaseContour,
    profiles: manifest.profiles,
    budgetClasses: manifest.budgetClasses,
    memoryScopes: manifest.memoryScopes,
    cases: [
      _copyCase(benchmarkCase, scales: benchmarkCase.scales.take(2).toList()),
    ],
    postBaselineRegressionCaps: manifest.postBaselineRegressionCaps,
    bootstrapLegacyEquivalence: manifest.bootstrapLegacyEquivalence,
  );
}

BenchmarkManifest _singleCaseManifest() {
  final manifest = BenchmarkManifest.load();
  final benchmarkCase = manifest.cases.first;
  return BenchmarkManifest(
    manifestVersion: manifest.manifestVersion,
    toolSchemaVersion: manifest.toolSchemaVersion,
    releaseContour: manifest.releaseContour,
    profiles: manifest.profiles,
    budgetClasses: manifest.budgetClasses,
    memoryScopes: manifest.memoryScopes,
    cases: [
      _copyCase(benchmarkCase, scales: [benchmarkCase.scales.first]),
    ],
    postBaselineRegressionCaps: manifest.postBaselineRegressionCaps,
    bootstrapLegacyEquivalence: manifest.bootstrapLegacyEquivalence,
  );
}

BenchmarkCase _copyCase(
  BenchmarkCase benchmarkCase, {
  List<String>? requiredMetrics,
  List<BenchmarkExactInvariant>? exactInvariants,
  List<BenchmarkScale>? scales,
}) {
  return BenchmarkCase(
    id: benchmarkCase.id,
    classification: benchmarkCase.classification,
    budgetClasses: benchmarkCase.budgetClasses,
    memoryScope: benchmarkCase.memoryScope,
    measurementBoundary: benchmarkCase.measurementBoundary,
    fixtureShape: benchmarkCase.fixtureShape,
    docsMetricsLabel: benchmarkCase.docsMetricsLabel,
    requiredMetrics: requiredMetrics ?? benchmarkCase.requiredMetrics,
    exactInvariants: exactInvariants ?? benchmarkCase.exactInvariants,
    scales: scales ?? benchmarkCase.scales,
  );
}

BenchmarkCase _copyCaseWithFixtureShape(
  BenchmarkCase benchmarkCase,
  String fixtureShape,
) {
  return BenchmarkCase(
    id: benchmarkCase.id,
    classification: benchmarkCase.classification,
    budgetClasses: benchmarkCase.budgetClasses,
    memoryScope: benchmarkCase.memoryScope,
    measurementBoundary: benchmarkCase.measurementBoundary,
    fixtureShape: fixtureShape,
    docsMetricsLabel: benchmarkCase.docsMetricsLabel,
    requiredMetrics: benchmarkCase.requiredMetrics,
    exactInvariants: benchmarkCase.exactInvariants,
    scales: benchmarkCase.scales,
  );
}

typedef _FakeAdapterData = ({
  Map<String, Object?> metrics,
  Map<String, Object?> setupMetrics,
  List<int> actionUsSamples,
  List<int> setupUsSamples,
  bool includeRssDeltaBytes,
});

BenchmarkCaseAdapter _fakeAdapterWithMetrics(
  Map<String, Object?> metrics, {
  List<int> actionUsSamples = const [5],
}) {
  return _fakeAdapterFrom((
    metrics: metrics,
    setupMetrics: _defaultFakeAdapterData.setupMetrics,
    actionUsSamples: actionUsSamples,
    setupUsSamples: _defaultFakeAdapterData.setupUsSamples,
    includeRssDeltaBytes: true,
  ));
}

BenchmarkCaseAdapter _fakeAdapterWithSetupSamples(List<int> setupUsSamples) {
  return _fakeAdapterFrom((
    metrics: _defaultFakeAdapterData.metrics,
    setupMetrics: _defaultFakeAdapterData.setupMetrics,
    actionUsSamples: _defaultFakeAdapterData.actionUsSamples,
    setupUsSamples: setupUsSamples,
    includeRssDeltaBytes: true,
  ));
}

BenchmarkCaseAdapter _fakeAdapterWithSetupMetrics(
  Map<String, Object?> setupMetrics,
) {
  return _fakeAdapterFrom((
    metrics: _defaultFakeAdapterData.metrics,
    setupMetrics: setupMetrics,
    actionUsSamples: _defaultFakeAdapterData.actionUsSamples,
    setupUsSamples: _defaultFakeAdapterData.setupUsSamples,
    includeRssDeltaBytes: true,
  ));
}

BenchmarkCaseAdapter _fakeAdapterWithoutRssDelta() {
  return _fakeAdapterFrom((
    metrics: _defaultFakeAdapterData.metrics,
    setupMetrics: _defaultFakeAdapterData.setupMetrics,
    actionUsSamples: _defaultFakeAdapterData.actionUsSamples,
    setupUsSamples: _defaultFakeAdapterData.setupUsSamples,
    includeRssDeltaBytes: false,
  ));
}

const _FakeAdapterData _defaultFakeAdapterData = (
  metrics: {},
  setupMetrics: {
    'setup_us': 5,
    'setup_allocation_bytes': 100,
    'setup_rss_delta_bytes': 100,
  },
  actionUsSamples: [5],
  setupUsSamples: [5],
  includeRssDeltaBytes: true,
);

BenchmarkCaseAdapter _fakeAdapterFrom(_FakeAdapterData data) {
  return (
    BenchmarkCase benchmarkCase,
    BenchmarkScale scale,
    BenchmarkProfile profile,
    BenchmarkDeviceTarget? deviceTarget,
  ) {
    final primaryMetrics = <String, Object?>{'allocation_bytes': 10};
    if (data.includeRssDeltaBytes) {
      primaryMetrics['rss_delta_bytes'] = 10;
    }
    return BenchmarkAdapterResult(
      actionUsSamples: data.actionUsSamples,
      setupUsSamples: data.setupUsSamples,
      metrics: {...primaryMetrics, ...data.metrics},
      setupMetrics: data.setupMetrics,
      measurementBoundary: benchmarkCase.measurementBoundary,
      fixtureShape: benchmarkCase.fixtureShape,
      runtime: const BenchmarkProbeRuntime(
        profileId: 'dry_run',
        runtimeMode: 'flutter_test',
        assertionsEnabled: true,
        debugInvariantMode: false,
      ),
    );
  };
}
