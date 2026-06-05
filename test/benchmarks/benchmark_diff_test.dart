import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

import '../../tool/bench/src/benchmark_diff.dart';
import '../../tool/bench/src/benchmark_manifest.dart';
import '../../tool/bench/src/benchmark_report.dart';

// The diff policy tests keep the acceptance and rejection matrix in one group
// so every case shares the same deterministic report fixture and baseline path.
// ignore: cyclomatic-complexity, halstead-volume, maximum-nesting-level, maintainability-index, source-lines-of-code
void main() {
  group('benchmark diff policy', () {
    test('passes a same-contour report against an approved baseline', () async {
      final manifest = BenchmarkManifest.load();
      final current = _releaseReport(manifest);
      await _writeTemporaryApprovedBaseline(manifest);
      final baseline =
          jsonDecode(File(approvedReleaseBaselinePath).readAsStringSync())
              as Map<String, Object?>;

      final result = diffBenchmarkReports(
        manifest: manifest,
        profile: 'release',
        baselineJson: baseline,
        currentJson: current,
        baselinePath: approvedReleaseBaselinePath,
        currentPath: 'build/bench/current/release.json',
      );

      expect(result.failures, isEmpty);
      expect(result.report, containsPair('status', 'pass'));
    });

    test('unapproved baseline payload fails closed', () {
      final manifest = BenchmarkManifest.load();
      final placeholder = {
        'schemaVersion': 1,
        'status': 'unapproved',
        'profile': 'release',
        'message': 'not initialized',
      };

      expect(placeholder, containsPair('status', 'unapproved'));
      expect(placeholder, isNot(contains('cases')));
      expect(placeholder, isNot(contains('releaseContour')));
      expect(
        diffBenchmarkReports(
          manifest: manifest,
          profile: 'release',
          baselineJson: placeholder,
          currentJson: _releaseReport(manifest),
          baselinePath: approvedReleaseBaselinePath,
          currentPath: 'current.json',
        ).failures.join('\n'),
        contains('approved baseline is not initialized'),
      );
    });

    test('rejects release contour and schema metadata mismatches', () {
      final manifest = BenchmarkManifest.load();
      final baseline = _releaseReport(manifest);
      final mutations = <String, void Function(Map<String, Object?>)>{
        'osName': (report) => report._runtime['osName'] = 'macOS',
        'osVersion': (report) => report._runtime['osVersion'] = '15.0',
        'flutterVersion': (report) =>
            report._runtime['flutterVersion'] = '3.39.0',
        'dartVersion': (report) =>
            report._runtime['dartVersion'] = 'Dart 3.11.0',
        'runtimeMode': (report) =>
            report._runtime['runtimeMode'] = 'flutter_release',
        'assertionsEnabled': (report) =>
            report._runtime['assertionsEnabled'] = false,
        'debugInvariantMode': (report) =>
            report._runtime['debugInvariantMode'] = true,
        'profile': (report) => report._profile['id'] = 'smoke',
        'manifestVersion': (report) =>
            report['manifestVersion'] = 'other_manifest',
        'manifestFingerprint': (report) =>
            report['manifestFingerprint'] = 'deadbeef',
        'schemaVersion': (report) => report['schemaVersion'] = 2,
      };

      for (final entry in mutations.entries) {
        final current = _clone(baseline);
        entry.value(current);
        final result = diffBenchmarkReports(
          manifest: manifest,
          profile: 'release',
          baselineJson: baseline,
          currentJson: current,
          baselinePath: 'baseline.json',
          currentPath: 'current.json',
        );

        expect(
          result.failures.join('\n'),
          contains(entry.key),
          reason: entry.key,
        );
      }
    });

    test('uses observed runtime only for same-contour comparison', () {
      final manifest = BenchmarkManifest.load();
      final baseline = _releaseReport(manifest);
      final current = _releaseReport(manifest);
      baseline._runtime['osName'] = 'linux';
      baseline._runtime['osVersion'] = 'Linux 6.8 fixture';
      current._runtime['osName'] = 'linux';
      current._runtime['osVersion'] = 'Linux 6.8 fixture';

      expect(
        diffBenchmarkReports(
          manifest: manifest,
          profile: 'release',
          baselineJson: baseline,
          currentJson: current,
          baselinePath: 'baseline.json',
          currentPath: 'current.json',
        ).failures,
        isEmpty,
      );

      current._runtime['osVersion'] = 'Linux 6.9 fixture';
      expect(
        diffBenchmarkReports(
          manifest: manifest,
          profile: 'release',
          baselineJson: baseline,
          currentJson: current,
          baselinePath: 'baseline.json',
          currentPath: 'current.json',
        ).failures.join('\n'),
        contains('runtime metadata mismatch for osVersion'),
      );
    });

    test('rejects baseline approval outside the pinned observed contour', () {
      final manifest = BenchmarkManifest.load();
      final localCandidate = _releaseReport(manifest);
      localCandidate._runtime['runnerLabel'] = 'ubuntu-22.04';
      localCandidate._runtime['osName'] = 'macOS';
      localCandidate._runtime['osVersion'] = '22.04';

      final result = validateFirstBaselineCandidate(
        manifest: manifest,
        profile: 'release',
        candidateJson: localCandidate,
        candidatePath: 'candidate.json',
      );

      expect(result.failures.join('\n'), contains('observed runnerLabel'));
      expect(result.failures.join('\n'), contains('observed osName'));
      expect(result.failures.join('\n'), isNot(contains('observed osVersion')));
    });

    test('rejects missing cases and missing required metrics', () {
      final manifest = BenchmarkManifest.load();
      final baseline = _releaseReport(manifest);
      final missingCase = _clone(baseline);
      (missingCase['cases'] as List<Object?>).removeAt(0);
      missingCase['caseCount'] = (missingCase['cases'] as List<Object?>).length;

      final missingMetric = _clone(baseline);
      final firstCase =
          (missingMetric['cases'] as List<Object?>).first
              as Map<String, Object?>;
      (firstCase['metrics'] as Map<String, Object?>).remove('avg_us');

      expect(
        diffBenchmarkReports(
          manifest: manifest,
          profile: 'release',
          baselineJson: baseline,
          currentJson: missingCase,
          baselinePath: 'baseline.json',
          currentPath: 'current.json',
        ).failures.join('\n'),
        contains('missing case'),
      );
      expect(
        diffBenchmarkReports(
          manifest: manifest,
          profile: 'release',
          baselineJson: baseline,
          currentJson: missingMetric,
          baselinePath: 'baseline.json',
          currentPath: 'current.json',
        ).failures.join('\n'),
        contains('missing metric avg_us'),
      );
    });

    test('rejects absolute time caps and first-baseline memory caps', () {
      final manifest = BenchmarkManifest.load();
      final report = _releaseReport(manifest);
      _metrics(report, 'edit.add_element', '1k')['avg_us'] = 1001;
      expect(
        validateFirstBaselineCandidate(
          manifest: manifest,
          profile: 'release',
          candidateJson: report,
          candidatePath: 'candidate.json',
        ).failures.join('\n'),
        contains('absolute cap'),
      );

      final missingTimeReport = _releaseReport(manifest);
      _metrics(
        missingTimeReport,
        'projection.read_document',
        '1k',
      ).remove('avg_us');
      expect(
        validateFirstBaselineCandidate(
          manifest: manifest,
          profile: 'release',
          candidateJson: missingTimeReport,
          candidatePath: 'candidate.json',
        ).failures.join('\n'),
        contains('candidate projection.read_document/1k missing metric avg_us'),
      );

      final memoryReport = _releaseReport(manifest);
      _metrics(memoryReport, 'edit.add_element', '1k')['allocation_bytes'] =
          1000000;
      expect(
        validateFirstBaselineCandidate(
          manifest: manifest,
          profile: 'release',
          candidateJson: memoryReport,
          candidatePath: 'candidate.json',
        ).failures.join('\n'),
        contains('first-baseline cap'),
      );

      final missingMemoryReport = _releaseReport(manifest);
      final missingMemoryMetrics = _metrics(
        missingMemoryReport,
        'edit.update_visual',
        '1k',
      );
      missingMemoryMetrics.remove('allocation_bytes');
      missingMemoryMetrics.remove('rss_delta_bytes');
      expect(
        validateFirstBaselineCandidate(
          manifest: manifest,
          profile: 'release',
          candidateJson: missingMemoryReport,
          candidatePath: 'candidate.json',
        ).failures.join('\n'),
        allOf(
          contains('missing metric allocation_bytes'),
          contains('missing metric rss_delta_bytes'),
        ),
      );
    });

    test('rejects exact invariant and bootstrap legacy ceiling violations', () {
      final manifest = BenchmarkManifest.load();
      final invariantReport = _releaseReport(manifest);
      final metrics = _metrics(
        invariantReport,
        'diagnostics.disabled_pointer',
        'hot_pointer',
      );
      metrics['allocation_bytes'] = 1;
      final invariant = _invariant(
        invariantReport,
        'diagnostics.disabled_pointer',
        'hot_pointer',
        'allocation_bytes_zero',
      );
      invariant['actual'] = 1;
      invariant['passed'] = false;

      expect(
        validateFirstBaselineCandidate(
          manifest: manifest,
          profile: 'release',
          candidateJson: invariantReport,
          candidatePath: 'candidate.json',
        ).failures.join('\n'),
        contains('invariant allocation_bytes_zero'),
      );

      final bootstrapReport = _releaseReport(manifest);
      final bootstrapMetrics = _metrics(
        bootstrapReport,
        'edit.add_element',
        '1k',
      );
      bootstrapMetrics['avg_us'] = 200;
      bootstrapMetrics['legacy_avg_us'] = 100;

      expect(
        validateFirstBaselineCandidate(
          manifest: manifest,
          profile: 'release',
          candidateJson: bootstrapReport,
          candidatePath: 'candidate.json',
        ).failures.join('\n'),
        contains('legacy_avg_us'),
      );
    });

    test('rejects approved-baseline time, allocation, and RSS regressions', () {
      final manifest = BenchmarkManifest.load();
      final baseline = _releaseReport(manifest);

      final timeMetrics = {'avg_us': 116, 'p95_us': 116, 'max_us': 131};
      for (final entry in timeMetrics.entries) {
        final current = _clone(baseline);
        _metrics(current, 'edit.add_element', '1k')[entry.key] = entry.value;
        expect(
          diffBenchmarkReports(
            manifest: manifest,
            profile: 'release',
            baselineJson: baseline,
            currentJson: current,
            baselinePath: 'baseline.json',
            currentPath: 'current.json',
          ).failures.join('\n'),
          contains('${entry.key} regression'),
        );
      }

      final allocation = _clone(baseline);
      _metrics(allocation, 'edit.add_element', '1k')['allocation_bytes'] =
          70000;
      expect(
        diffBenchmarkReports(
          manifest: manifest,
          profile: 'release',
          baselineJson: baseline,
          currentJson: allocation,
          baselinePath: 'baseline.json',
          currentPath: 'current.json',
        ).failures.join('\n'),
        contains('allocation_bytes regression'),
      );

      final nonRequiredAllocation = _clone(baseline);
      _metrics(
        nonRequiredAllocation,
        'edit.update_visual',
        '1k',
      )['allocation_bytes'] = 70000;
      expect(
        diffBenchmarkReports(
          manifest: manifest,
          profile: 'release',
          baselineJson: baseline,
          currentJson: nonRequiredAllocation,
          baselinePath: 'baseline.json',
          currentPath: 'current.json',
        ).failures.join('\n'),
        contains('edit.update_visual/1k allocation_bytes regression'),
      );

      final nonRequiredTimeMetric = _clone(baseline);
      _metrics(
        nonRequiredTimeMetric,
        'projection.read_document',
        '1k',
      )['avg_us'] = 116;
      expect(
        diffBenchmarkReports(
          manifest: manifest,
          profile: 'release',
          baselineJson: baseline,
          currentJson: nonRequiredTimeMetric,
          baselinePath: 'baseline.json',
          currentPath: 'current.json',
        ).failures.join('\n'),
        contains('projection.read_document/1k avg_us regression'),
      );

      final nonNumeric = _clone(baseline);
      _metrics(nonNumeric, 'edit.add_element', '1k')['avg_us'] = 'not measured';
      expect(
        diffBenchmarkReports(
          manifest: manifest,
          profile: 'release',
          baselineJson: baseline,
          currentJson: nonNumeric,
          baselinePath: 'baseline.json',
          currentPath: 'current.json',
        ).failures.join('\n'),
        contains('current edit.add_element/1k metric avg_us must be numeric'),
      );

      final missingAllocation = _clone(baseline);
      _metrics(
        missingAllocation,
        'edit.update_visual',
        '1k',
      ).remove('allocation_bytes');
      expect(
        diffBenchmarkReports(
          manifest: manifest,
          profile: 'release',
          baselineJson: baseline,
          currentJson: missingAllocation,
          baselinePath: 'baseline.json',
          currentPath: 'current.json',
        ).failures.join('\n'),
        contains(
          'current edit.update_visual/1k missing metric allocation_bytes',
        ),
      );

      final rss = _clone(baseline);
      _metrics(rss, 'edit.add_element', '1k')['rss_delta_bytes'] = 1100000;
      expect(
        diffBenchmarkReports(
          manifest: manifest,
          profile: 'release',
          baselineJson: baseline,
          currentJson: rss,
          baselinePath: 'baseline.json',
          currentPath: 'current.json',
        ).failures.join('\n'),
        contains('rss_delta_bytes regression'),
      );
    });

    test('does not apply first-baseline memory caps during ordinary diff', () {
      final manifest = BenchmarkManifest.load();
      final baseline = _releaseReport(manifest);
      final current = _clone(baseline);
      _metrics(baseline, 'edit.add_element', '1k')['allocation_bytes'] = 262000;
      _metrics(current, 'edit.add_element', '1k')['allocation_bytes'] = 327000;

      final result = diffBenchmarkReports(
        manifest: manifest,
        profile: 'release',
        baselineJson: baseline,
        currentJson: current,
        baselinePath: 'baseline.json',
        currentPath: 'current.json',
      );

      expect(result.failures, isEmpty);
    });

    test(
      'manual device baseline diff tracks regressions without release caps',
      () async {
        final manifest = BenchmarkManifest.load();
        final baseline = _releaseReport(manifest);
        final current = _clone(baseline);
        baseline._runtime['deviceId'] = 'pixel-fixture';
        current._runtime['deviceId'] = 'pixel-fixture';
        _metrics(baseline, 'edit.add_element', '1k')['avg_us'] = 50000;
        _metrics(baseline, 'edit.add_element', '1k')['p95_us'] = 60000;
        _metrics(baseline, 'edit.add_element', '1k')['max_us'] = 70000;
        _metrics(current, 'edit.add_element', '1k')['avg_us'] = 50000;
        _metrics(current, 'edit.add_element', '1k')['p95_us'] = 60000;
        _metrics(current, 'edit.add_element', '1k')['max_us'] = 70000;

        const manualBaselinePath =
            '$manualBenchmarkBaselineRoot/manual_diff_test.json';
        const currentPath = 'build/bench/current/manual_diff_test_current.json';
        const outputPath = 'build/bench/diff/manual_diff_test.json';
        for (final path in [manualBaselinePath, currentPath, outputPath]) {
          addTearDown(() {
            final file = File(path);
            if (file.existsSync()) {
              file.deleteSync();
            }
          });
        }
        File(manualBaselinePath)
          ..parent.createSync(recursive: true)
          ..writeAsStringSync(jsonEncode(baseline));
        File(currentPath)
          ..parent.createSync(recursive: true)
          ..writeAsStringSync(jsonEncode(current));

        final exitCode = await runBenchmarkDiffCli([
          '--profile=release',
          '--baseline=$manualBaselinePath',
          '--current=$currentPath',
          '--output=$outputPath',
        ], manifest: manifest);

        expect(exitCode, 0);
        final diffReport =
            jsonDecode(File(outputPath).readAsStringSync())
                as Map<String, Object?>;
        expect(diffReport['status'], 'pass');
        expect(diffReport['summary'], containsPair('comparedCaseCount', 74));
      },
    );

    test('diff is read-only and update_baseline is the write path', () async {
      final manifest = BenchmarkManifest.load();
      final temp = Directory.systemTemp.createTempSync('bench_diff_test_');
      addTearDown(() => temp.deleteSync(recursive: true));

      final baselinePath = '${temp.path}/baseline.json';
      final currentPath = '${temp.path}/current.json';
      final releaseCurrent = File(releaseCurrentReportPath);
      const outputPath = 'build/bench/diff/benchmark_diff_test.json';
      addTearDown(() {
        final output = File(outputPath);
        if (output.existsSync()) {
          output.deleteSync();
        }
      });
      final releaseCurrentBefore = releaseCurrent.existsSync()
          ? releaseCurrent.readAsStringSync()
          : null;
      addTearDown(() {
        if (releaseCurrentBefore == null) {
          if (releaseCurrent.existsSync()) {
            releaseCurrent.deleteSync();
          }
        } else {
          releaseCurrent.writeAsStringSync(releaseCurrentBefore);
        }
      });
      File(
        baselinePath,
      ).writeAsStringSync(jsonEncode(_releaseReport(manifest)));
      File(currentPath).writeAsStringSync(jsonEncode(_releaseReport(manifest)));
      releaseCurrent
        ..parent.createSync(recursive: true)
        ..writeAsStringSync(jsonEncode(_releaseReport(manifest)));
      final before = File(baselinePath).readAsStringSync();

      await expectLater(
        runBenchmarkDiffCli([
          '--profile=release',
          '--baseline=$baselinePath',
          '--current=$currentPath',
          '--output=$outputPath',
        ], manifest: manifest),
        throwsA(isA<FormatException>()),
      );
      await expectLater(
        runBenchmarkDiffCli([
          '--profile=release',
          '--baseline=$approvedReleaseBaselinePath',
          '--current=$currentPath',
          '--output=$outputPath',
        ], manifest: manifest),
        throwsA(isA<FormatException>()),
      );

      expect(File(baselinePath).readAsStringSync(), before);
      expect(
        () => runBenchmarkBaselineUpdateCli([
          '--profile=release',
          '--candidate=$currentPath',
          '--approved=${temp.path}/approved.json',
        ], manifest: manifest),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => runBenchmarkBaselineUpdateCli([
          '--profile=release',
          '--candidate=$currentPath',
          '--approved=$manualBenchmarkBaselineRoot/update_rejected.json',
        ], manifest: manifest),
        throwsA(isA<FormatException>()),
      );

      final symlinkOutput = File('build/bench/diff/symlink_output.json');
      if (symlinkOutput.existsSync()) {
        symlinkOutput.deleteSync();
      }
      Link(
        symlinkOutput.path,
      ).createSync(File(approvedReleaseBaselinePath).absolute.path);
      addTearDown(() {
        final link = Link(symlinkOutput.path);
        if (link.existsSync()) {
          link.deleteSync();
        }
      });
      await expectLater(
        runBenchmarkDiffCli([
          '--profile=release',
          '--baseline=$approvedReleaseBaselinePath',
          '--current=$releaseCurrentReportPath',
          '--output=${symlinkOutput.path}',
        ], manifest: manifest),
        throwsA(isA<FormatException>()),
      );

      const candidatePath =
          '$releaseCandidateRoot/benchmark_diff_test_candidate.json';
      final approved = File(approvedReleaseBaselinePath);
      final candidate = File(candidatePath)..parent.createSync(recursive: true);
      final approvedExisted = approved.existsSync();
      final approvedBefore = approvedExisted
          ? approved.readAsStringSync()
          : null;
      addTearDown(() {
        if (approvedBefore == null) {
          if (approved.existsSync()) {
            approved.deleteSync();
          }
        } else {
          approved.writeAsStringSync(approvedBefore);
        }
        if (candidate.existsSync()) {
          candidate.deleteSync();
        }
      });
      candidate.writeAsStringSync(jsonEncode(_releaseReport(manifest)));

      final updateExit = await runBenchmarkBaselineUpdateCli([
        '--profile=release',
        '--candidate=$candidatePath',
        '--approved=$approvedReleaseBaselinePath',
      ], manifest: manifest);

      expect(updateExit, 0);
      final approvedBeforeDiff = approved.readAsStringSync();
      final diffExit = await runBenchmarkDiffCli([
        '--profile=release',
        '--baseline=$approvedReleaseBaselinePath',
        '--current=$releaseCurrentReportPath',
        '--output=$outputPath',
      ], manifest: manifest);
      expect(diffExit, 0);
      expect(approved.readAsStringSync(), approvedBeforeDiff);
      expect(File(outputPath).existsSync(), isTrue);
      final approvedJson =
          jsonDecode(approved.readAsStringSync()) as Map<String, Object?>;
      final candidateJson =
          jsonDecode(candidate.readAsStringSync()) as Map<String, Object?>;
      expect(approvedJson['runtime'], candidateJson['runtime']);
      expect(approvedJson['caseCount'], candidateJson['caseCount']);
      final approvedCase =
          (approvedJson['cases'] as List<Object?>).first
              as Map<String, Object?>;
      expect(approvedCase, isNot(contains('classification')));
      expect(approvedCase, isNot(contains('budgetClasses')));
      expect(approvedCase, isNot(contains('memoryScope')));
      final invariantBearing = (approvedJson['cases'] as List<Object?>)
          .cast<Map<String, Object?>>()
          .firstWhere(
            (entry) =>
                (entry['exactInvariants'] as Map<String, Object?>).isNotEmpty,
          );
      final invariant =
          ((invariantBearing['exactInvariants'] as Map<String, Object?>)
                  .values
                  .first)
              as Map<String, Object?>;
      expect(invariant, contains('actual'));
      expect(invariant, contains('passed'));
      expect(invariant, isNot(contains('expected')));
      expect(invariant, isNot(contains('max')));
    });
  });
}

Future<void> _writeTemporaryApprovedBaseline(BenchmarkManifest manifest) async {
  const candidatePath =
      '$releaseCandidateRoot/benchmark_diff_test_positive.json';
  final approved = File(approvedReleaseBaselinePath);
  final candidate = File(candidatePath)..parent.createSync(recursive: true);
  final approvedBefore = approved.readAsStringSync();
  addTearDown(() {
    approved.writeAsStringSync(approvedBefore);
    if (candidate.existsSync()) {
      candidate.deleteSync();
    }
  });
  candidate.writeAsStringSync(jsonEncode(_releaseReport(manifest)));
  final exitCode = await runBenchmarkBaselineUpdateCli([
    '--profile=release',
    '--candidate=$candidatePath',
    '--approved=$approvedReleaseBaselinePath',
  ], manifest: manifest);
  expect(exitCode, 0);
}

extension on Map<String, Object?> {
  Map<String, Object?> get _runtime => this['runtime'] as Map<String, Object?>;

  Map<String, Object?> get _profile => this['profile'] as Map<String, Object?>;
}

// The synthetic release report mirrors the complete report schema used by diff
// policy tests; splitting it would make schema drift harder to see.
// ignore: halstead-volume, source-lines-of-code
Map<String, Object?> _releaseReport(BenchmarkManifest manifest) {
  final profile = manifest.profilesById['release']!;
  final cases = [
    for (final benchmarkCase in manifest.cases)
      for (final scale in benchmarkCase.scales)
        if (scale.profiles.contains('release'))
          _caseReport(benchmarkCase, scale, profile),
  ];
  return {
    'schemaVersion': manifest.toolSchemaVersion,
    'manifestVersion': manifest.manifestVersion,
    'manifestFingerprint': benchmarkManifestFingerprint(manifest),
    'profile': {
      'id': profile.id,
      'warmups': profile.warmups,
      'repetitions': profile.repetitions,
      'iterations': profile.iterations,
      'minimumMeasuredMs': profile.minimumMeasuredMs,
      'minimumSamples': profile.minimumSamples,
      'timingClaims': profile.timingClaims,
      'scaleSelection': profile.scaleSelection,
    },
    'runtime': {
      'runnerLabel': manifest.releaseContour.runnerLabel,
      'osName': 'linux',
      'osVersion': 'Linux 6.8 fixture',
      'dartVersion': 'Dart 3.10.4',
      'flutterChannel': manifest.releaseContour.flutterChannel,
      'flutterVersion': manifest.releaseContour.flutterVersion,
      'releaseContour': {
        'runnerLabel': manifest.releaseContour.runnerLabel,
        'osName': manifest.releaseContour.osName,
        'osVersion': manifest.releaseContour.osVersion,
        'flutterChannel': manifest.releaseContour.flutterChannel,
        'flutterVersion': manifest.releaseContour.flutterVersion,
      },
      'runtimeMode': 'flutter_test',
      'assertionsEnabled': true,
      'debugInvariantMode': false,
      'deviceId': null,
    },
    'caseCount': cases.length,
    'cases': cases,
  };
}

Map<String, Object?> _caseReport(
  BenchmarkCase benchmarkCase,
  BenchmarkScale scale,
  BenchmarkProfile profile,
) {
  final metrics = _metricsForCase(benchmarkCase, scale);
  return {
    'id': benchmarkCase.id,
    'classification': benchmarkCase.classification,
    'scale': scale.id,
    'scaleLabel': scale.label,
    'budgetClasses': benchmarkCase.budgetClasses,
    'memoryScope': benchmarkCase.memoryScope,
    'warmups': profile.warmups,
    'repetitions': profile.repetitions,
    'iterations': profile.iterations ?? 1,
    'timingClaims': profile.timingClaims,
    'metrics': metrics,
    'exactInvariants': {
      for (final invariant in benchmarkCase.exactInvariants)
        invariant.name: {
          'metric': invariant.metric,
          'actual': metrics[invariant.metric],
          'expected': invariant.expected,
          'max': invariant.max,
          'passed': true,
        },
    },
  };
}

Map<String, Object?> _metricsForCase(
  BenchmarkCase benchmarkCase,
  BenchmarkScale scale,
) {
  final metrics = <String, Object?>{};
  for (final metric in benchmarkCase.requiredMetrics) {
    metrics[metric] = _metricValue(metric);
  }
  if (_hasTimeBudgetClass(benchmarkCase)) {
    metrics
      ..putIfAbsent('avg_us', () => 100)
      ..putIfAbsent('p95_us', () => 100)
      ..putIfAbsent('max_us', () => 100);
  }
  for (final invariant in benchmarkCase.exactInvariants) {
    metrics[invariant.metric] = _invariantMetricValue(
      invariant.name,
      invariant.metric,
      metrics,
      scale.id,
    );
  }
  metrics.putIfAbsent(
    'allocation_bytes',
    () => benchmarkCase.memoryScope == 'zero_allocation' ? 0 : 1024,
  );
  metrics.putIfAbsent(
    'rss_delta_bytes',
    () => benchmarkCase.memoryScope == 'zero_allocation' ? 0 : 1024,
  );
  if (benchmarkCase.classification == 'equivalent_legacy' &&
      metrics.containsKey('avg_us')) {
    metrics['legacy_avg_us'] = 100;
  }
  return metrics;
}

bool _hasTimeBudgetClass(BenchmarkCase benchmarkCase) {
  return benchmarkCase.budgetClasses.any(_timeBudgetClassIds.contains);
}

const _timeBudgetClassIds = {
  'hot_input',
  'incremental_edit',
  'frame_capture',
  'query_read',
  'resource_budgeted',
  'bulk_io',
};

Object _metricValue(String metric) {
  return switch (metric) {
    'avg_us' => 100,
    'p95_us' => 100,
    'max_us' => 100,
    'first_read_us' => 100,
    'cache_hit_us' => 100,
    'allocation_bytes' => 1024,
    'allocation_records' => 0,
    'error_payload' => 'valid',
    _ => 1,
  };
}

// Fixture invariant values are a closed mapping from manifest invariant names
// to deterministic numbers so policy tests fail on unknown invariants.
// ignore: cyclomatic-complexity
Object? _invariantMetricValue(
  String invariant,
  String metric,
  Map<String, Object?> metrics,
  String scaleId,
) {
  return switch (invariant) {
    'selected_count_matches_input' => _boundedScale(scaleId, max: 16),
    'cached_preview_delta_absent' => 0,
    'scene_repaint_count_bounded' => 1,
    'overlay_repaint_count_bounded' => 1,
    'point_count_matches_input' => 2,
    'eraser_exact_checks_match_candidates' => metrics['candidate_count'],
    'resolver_calls_bounded' => 1,
    'target_session_cache_invalidation_bounded' => 1,
    'all_entry_session_cache_invalidation_bounded' => 1,
    'error_payload_matches_fixture' => 'valid',
    'fallback_count_bounded' => 0,
    'rebuilt_pages_match_touched_set' => _boundedScale(scaleId, max: 64),
    _ when invariant.endsWith('_zero') => 0,
    _ => metrics[metric] ?? 1,
  };
}

int _boundedScale(String scaleId, {required int max}) {
  final value = switch (scaleId) {
    '100k' => 100000,
    '50k' || 'dense_50k' || 'invalid_50k' => 50000,
    '10k' || 'invalid_10k' => 10000,
    _ => 1000,
  };
  return value > max ? max : value;
}

Map<String, Object?> _clone(Map<String, Object?> report) {
  return jsonDecode(jsonEncode(report)) as Map<String, Object?>;
}

Map<String, Object?> _metrics(
  Map<String, Object?> report,
  String id,
  String scale,
) {
  final cases = report['cases'] as List<Object?>;
  for (final entry in cases.cast<Map<String, Object?>>()) {
    if (entry['id'] == id && entry['scale'] == scale) {
      return entry['metrics'] as Map<String, Object?>;
    }
  }
  throw StateError('Missing fixture case $id/$scale.');
}

Map<String, Object?> _invariant(
  Map<String, Object?> report,
  String id,
  String scale,
  String invariant,
) {
  final cases = report['cases'] as List<Object?>;
  for (final entry in cases.cast<Map<String, Object?>>()) {
    if (entry['id'] == id && entry['scale'] == scale) {
      final invariants = entry['exactInvariants'] as Map<String, Object?>;
      return invariants[invariant] as Map<String, Object?>;
    }
  }
  throw StateError('Missing fixture invariant $id/$scale $invariant.');
}
