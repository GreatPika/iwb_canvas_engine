import 'dart:io';

import 'package:test/test.dart';

import '../../tool/bench/src/benchmark_manifest.dart';
import '../../tool/bench/src/benchmark_runner.dart';

// Required-case proof keeps inventory, metrics, invariants, and benchmark owner
// dependency checks in one suite because together they define benchmark
// executability.
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
          expect(reportCase.actionUsSamples, isNotEmpty);
          expect(reportCase.setupUsSamples, isNotEmpty);
          expect(
            reportCase.measurementBoundary.timedScope,
            manifestCase.measurementBoundary.timedScope,
          );
          expect(
            reportCase.measurementBoundary.setupScope,
            manifestCase.measurementBoundary.setupScope,
          );
          expect(
            reportCase.measurementBoundary.primaryMemory,
            manifestCase.measurementBoundary.primaryMemory,
          );
          expect(reportCase.fixtureShape, manifestCase.fixtureShape);
          if (manifestCase.measurementBoundary.setupScope != 'none') {
            expect(
              reportCase.setupMetrics.keys,
              containsAll([
                ...manifestCase.measurementBoundary.setupMetrics,
                ...manifestCase.measurementBoundary.setupMemoryMetrics,
              ]),
            );
          }
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
      final manifest = BenchmarkManifest.load();
      final report = runBenchmarks(manifest: manifest, profileId: 'dry_run');
      final encoded = report.toJson();

      expect(encoded['schemaVersion'], manifest.toolSchemaVersion);
      expect(encoded['manifestVersion'], isA<String>());
      expect(encoded['manifestFingerprint'], isA<String>());
      expect(encoded['profile'], isA<Map<String, Object?>>());
      expect(encoded['runtime'], isA<Map<String, Object?>>());
      expect(encoded['caseCount'], report.cases.length);
    });

    test('benchmark owner code does not reference retired package paths', () {
      expect(_retiredBenchmarkPathReferences(), isEmpty);
    });
  });
}

List<String> _retiredBenchmarkPathReferences() {
  final references = <String>[];
  final retiredPathTokens = _retiredBenchmarkPathTokens();

  for (final file in _benchmarkDartFiles()) {
    final text = file.readAsStringSync();
    for (final token in retiredPathTokens) {
      if (text.contains(token)) {
        references.add('${file.path}: $token');
      }
    }
  }

  return references;
}

List<String> _retiredBenchmarkPathTokens() {
  final legacyPath = ['legacy', '/'].join();
  return [
    legacyPath,
    ['../', legacyPath].join(),
    ['../../', legacyPath].join(),
    ['package:', legacyPath].join(),
    ['legacy', '/', 'iwb_canvas_engine'].join(),
  ];
}

Iterable<File> _benchmarkDartFiles() sync* {
  for (final root in const ['tool/bench', 'test/benchmarks']) {
    yield* Directory(root)
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'));
  }
}
