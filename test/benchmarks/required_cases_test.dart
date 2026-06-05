import 'dart:io';

import 'package:test/test.dart';

import '../../tool/bench/src/benchmark_manifest.dart';
import '../../tool/bench/src/benchmark_runner.dart';

// Required-case proof keeps inventory, metrics, invariants, and legacy-ban
// checks in one suite because together they define benchmark executability.
// ignore: halstead-volume, maximum-nesting-level, maintainability-index, source-lines-of-code
void main() {
  group('required benchmark cases', () {
    test('dry-run emits every manifest case scale with required metrics', () {
      final manifest = BenchmarkManifest.load();
      final report = runBenchmarks(manifest: manifest, profileId: 'dry_run');
      final reportsByCaseScale = {
        for (final benchmarkCase in report.cases)
          '${benchmarkCase.id}/${benchmarkCase.scale}': benchmarkCase,
      };

      for (final manifestCase in manifest.cases) {
        for (final scale in manifestCase.scales) {
          final reportCase =
              reportsByCaseScale['${manifestCase.id}/${scale.id}'];
          expect(
            reportCase,
            isNotNull,
            reason: '${manifestCase.id}/${scale.id}',
          );
          if (reportCase == null) {
            continue;
          }
          expect(
            reportCase.metrics.keys,
            containsAll(manifestCase.requiredMetrics),
          );
          expect(reportCase.timingClaims, isFalse);
          for (final invariant in manifestCase.exactInvariants) {
            final invariantReport = reportCase.exactInvariants[invariant.name];
            expect(invariantReport, isNotNull, reason: invariant.name);
            if (invariantReport == null) {
              continue;
            }
            expect(invariantReport.metric, invariant.metric);
            expect(invariantReport.passed, isTrue);
          }
        }
      }
    });

    test('report records schema, profile, runtime, and manifest metadata', () {
      final report = runBenchmarks(
        manifest: BenchmarkManifest.load(),
        profileId: 'dry_run',
      );
      final encoded = report.toJson();

      expect(encoded['schemaVersion'], 1);
      expect(encoded['manifestVersion'], isA<String>());
      expect(encoded['manifestFingerprint'], isA<String>());
      expect(encoded['profile'], isA<Map<String, Object?>>());
      expect(encoded['runtime'], isA<Map<String, Object?>>());
      expect(encoded['caseCount'], report.cases.length);
    });

    test('current benchmark proof does not depend on legacy tooling', () {
      const legacyOwner = 'legacy';
      final legacyPathToken = '$legacyOwner/';
      final legacyImportToken = '$legacyOwner.';
      final benchFiles = [
        for (final root in ['tool/bench', 'test/benchmarks'])
          ...Directory(root)
              .listSync(recursive: true)
              .whereType<File>()
              .where((file) => file.path.endsWith('.dart')),
      ];

      for (final file in benchFiles) {
        final text = file.readAsStringSync();
        expect(text, isNot(contains(legacyPathToken)), reason: file.path);
        expect(text, isNot(contains(legacyImportToken)), reason: file.path);
      }
    });
  });
}
