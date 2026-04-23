@Tags(['tool'])
library;

import 'dart:io';

import 'package:test/test.dart';

import '../../tool/bench/load_profile_policy.dart';
import '../../tool/bench/run_load_profiles.dart' as run_load_profiles;

// INV:INV-ENG-PERFORMANCE-PROOF-CONTOUR

String _extractMethodBody({
  required String source,
  required String methodStart,
}) {
  final startIndex = source.indexOf(methodStart);
  if (startIndex < 0) {
    throw StateError('Method signature not found: $methodStart');
  }
  var bodyStart = -1;
  var parenDepth = 0;
  for (var i = startIndex; i < source.length; i++) {
    final char = source[i];
    if (char == '(') {
      parenDepth += 1;
    } else if (char == ')') {
      if (parenDepth > 0) {
        parenDepth -= 1;
      }
    } else if (char == '{' && parenDepth == 0) {
      bodyStart = i;
      break;
    }
  }
  if (bodyStart < 0) {
    throw StateError('Method body start not found: $methodStart');
  }

  var depth = 1;
  for (var i = bodyStart + 1; i < source.length; i++) {
    final char = source[i];
    if (char == '{') {
      depth += 1;
    } else if (char == '}') {
      depth -= 1;
      if (depth == 0) {
        return source.substring(bodyStart + 1, i);
      }
    }
  }
  throw StateError('Method body end not found: $methodStart');
}

void main() {
  group('tool/bench/run_load_profiles.dart', () {
    test('accepts exact smoke case set from policy', () {
      final policy = loadProfilePolicyFor('smoke');

      final issues = run_load_profiles.validateCollectedBenchmarkCases(
        policy: policy,
        parsedCases: <Map<String, Object?>>[
          for (final caseName in policy.requiredCaseNames)
            <String, Object?>{'name': caseName},
        ],
      );

      expect(issues, isEmpty);
    });

    test('fails when a required smoke case is missing', () {
      final policy = loadProfilePolicyFor('smoke');

      final issues = run_load_profiles.validateCollectedBenchmarkCases(
        policy: policy,
        parsedCases: <Map<String, Object?>>[
          <String, Object?>{'name': 'nodes_10000'},
          <String, Object?>{'name': 'strokes_1000_pts_256'},
          <String, Object?>{'name': backgroundLayerPaintAdmissionCaseName},
          <String, Object?>{'name': worstCaseName},
        ],
      );

      expect(
        issues,
        contains(
          'missing required benchmark cases: '
          '$selectionPathCandidateStagingCaseName, '
          '$selectionPathEndToEndPaintCaseName, '
          '$selectionPathPainterOnlyCaseName, '
          '$staticBackgroundCacheCaseName, '
          '$strokePathCacheCaseName, '
          '$textLayoutCacheCaseName',
        ),
      );
    });

    test('fails on duplicate and unexpected case names', () {
      final policy = loadProfilePolicyFor('smoke');

      final issues = run_load_profiles.validateCollectedBenchmarkCases(
        policy: policy,
        parsedCases: <Map<String, Object?>>[
          <String, Object?>{'name': 'nodes_10000'},
          <String, Object?>{'name': 'nodes_10000'},
          <String, Object?>{'name': 'strokes_1000_pts_256'},
          <String, Object?>{'name': selectionPathPainterOnlyCaseName},
          <String, Object?>{'name': worstCaseName},
          <String, Object?>{'name': 'unexpected_case'},
        ],
      );

      expect(issues, contains('duplicate benchmark cases: nodes_10000'));
      expect(issues, contains('unexpected benchmark cases: unexpected_case'));
    });

    test('fails when a parsed case omits its name', () {
      final policy = loadProfilePolicyFor('smoke');

      final issues = run_load_profiles.validateCollectedBenchmarkCases(
        policy: policy,
        parsedCases: <Map<String, Object?>>[
          <String, Object?>{'name': ''},
        ],
      );

      expect(issues, <String>[
        'benchmark case #0 is missing a non-empty "name"',
      ]);
    });

    test('uses truthful metric schema without fake percentile keys', () {
      final fullPolicy = loadProfilePolicyFor('full');
      final smokePolicy = loadProfilePolicyFor('smoke');

      expect(fullPolicy.requiredMetricKeys, <String>[
        'avgUs',
        'minUs',
        'maxUs',
        'avgRssDeltaBytes',
        'minRssDeltaBytes',
        'maxRssDeltaBytes',
      ]);
      expect(smokePolicy.requiredMetricKeys, <String>[
        'avgUs',
        'minUs',
        'maxUs',
        'avgRssDeltaBytes',
        'minRssDeltaBytes',
        'maxRssDeltaBytes',
      ]);
      expect(
        fullPolicy.maxRegressionPctByMetric.keys,
        isNot(contains('p95Us')),
      );
      expect(
        fullPolicy.maxRegressionPctByMetric.keys,
        isNot(contains('p95RssDeltaBytes')),
      );
      expect(
        fullPolicy.maxAbsoluteValueByMetric.keys,
        isNot(contains('p95RssDeltaBytes')),
      );
    });

    test('checked-in baselines do not retain fake percentile keys', () {
      final smokeBaseline = File(
        'tool/bench/baselines/load_profiles_smoke_baseline.json',
      ).readAsStringSync();
      final fullBaseline = File(
        'tool/bench/baselines/load_profiles_full_baseline.json',
      ).readAsStringSync();

      expect(smokeBaseline, isNot(contains('"p95Us"')));
      expect(smokeBaseline, isNot(contains('"p95RssDeltaBytes"')));
      expect(fullBaseline, isNot(contains('"p95Us"')));
      expect(fullBaseline, isNot(contains('"p95RssDeltaBytes"')));
    });

    test(
      'cache benchmark cases keep production owners and warm up steady-state hits',
      () {
        final source = File(
          'tool/bench/load_profiles_cases_test.dart',
        ).readAsStringSync();
        final textBody = _extractMethodBody(
          source: source,
          methodStart: 'Map<String, Object?> _runTextLayoutCacheCase({',
        );
        final strokeBody = _extractMethodBody(
          source: source,
          methodStart: 'Map<String, Object?> _runStrokePathCacheCase({',
        );
        final staticBody = _extractMethodBody(
          source: source,
          methodStart: 'Map<String, Object?> _runStaticBackgroundCacheCase({',
        );

        expect(textBody, contains('_createProductionBenchmarkRenderState('));
        expect(textBody, contains('warmUp: () {'));
        expect(textBody, isNot(contains('_BenchmarkControllerRenderState(')));

        expect(strokeBody, contains('_createProductionBenchmarkRenderState('));
        expect(strokeBody, contains('warmUp: () {'));
        expect(strokeBody, isNot(contains('_BenchmarkControllerRenderState(')));

        expect(staticBody, contains('SceneControllerSceneViewRenderState('));
        expect(staticBody, contains('warmUp: () {'));
        expect(staticBody, isNot(contains('_BenchmarkControllerRenderState(')));
      },
    );

    test(
      'load-profile source emits explicit cold/steady taxonomy metadata',
      () {
        final casesSource = File(
          'tool/bench/load_profiles_cases_test.dart',
        ).readAsStringSync();
        final policySource = File(
          'tool/bench/load_profile_policy.dart',
        ).readAsStringSync();
        final policy = loadProfilePolicyFor('smoke');
        final nodeContract = policy.contractForCase('nodes_10000');
        final textContract = policy.contractForCase(textLayoutCacheCaseName);

        expect(
          (((nodeContract['operations']
                  as Map<String, Object?>)['single_node_patch']
              as Map<String, Object?>)['executionMode']),
          'cold_start',
        );
        expect(
          (((textContract['operations']
                  as Map<String, Object?>)['paint_cache_hit']
              as Map<String, Object?>)['executionMode']),
          'steady_state',
        );
        expect(casesSource, contains("'contract': contract"));
        expect(policySource, contains('warmupIterations'));
        expect(policySource, contains('measuredIterations'));
        expect(policySource, contains('gatedMetrics'));
        expect(policySource, contains('diagnosticMetrics'));
        expect(casesSource, isNot(contains('includePercentiles')));
      },
    );

    test('worst_case contract reports its own measured iteration count', () {
      final smokePolicy = loadProfilePolicyFor('smoke');
      final fullPolicy = loadProfilePolicyFor('full');

      final smokeContract = smokePolicy.contractForCase(worstCaseName);
      final fullContract = fullPolicy.contractForCase(worstCaseName);

      final smokeOperation =
          ((smokeContract['operations']
                  as Map<String, Object?>)['huge_bounds.query'])
              as Map<String, Object?>;
      final fullOperation =
          ((fullContract['operations']
                  as Map<String, Object?>)['huge_bounds.query'])
              as Map<String, Object?>;

      expect(smokeOperation['measuredIterations'], 2);
      expect(fullOperation['measuredIterations'], 3);
    });

    test(
      'background paint benchmark is wired through SceneControllerSceneViewRenderState instead of benchmark-only render state',
      () {
        final source = File(
          'tool/bench/load_profiles_cases_test.dart',
        ).readAsStringSync();
        final body = _extractMethodBody(
          source: source,
          methodStart:
              'Map<String, Object?> _runBackgroundLayerPaintAdmissionCase({',
        );

        expect(body, contains('SceneControllerSceneViewRenderState('));
        expect(body, contains('captureFramePreview: () =>'));
        expect(body, contains('SceneViewFramePreview.captureSnapshot('));
        expect(body, isNot(contains('_BenchmarkControllerRenderState(')));
        expect(
          source,
          contains('load profile background-layer-paint profile=\$profile'),
        );
      },
    );

    test(
      'selection-path staging benchmarks keep production committed staging and painter-only isolation',
      () {
        final source = File(
          'tool/bench/load_profiles_cases_test.dart',
        ).readAsStringSync();
        final stagingBody = _extractMethodBody(
          source: source,
          methodStart:
              'Map<String, Object?> _runSelectionPathCandidateStagingCase({',
        );
        final endToEndBody = _extractMethodBody(
          source: source,
          methodStart:
              'Map<String, Object?> _runSelectionPathEndToEndPaintCase({',
        );
        final painterOnlyBody = _extractMethodBody(
          source: source,
          methodStart:
              'Map<String, Object?> _runSelectionPathPainterOnlyCase({',
        );

        expect(stagingBody, contains('_createProductionBenchmarkRenderState('));
        expect(
          stagingBody,
          contains(
            'renderState.preparePaintPlan(renderState.captureFrameRead(), query);',
          ),
        );
        expect(
          stagingBody,
          isNot(contains('_BenchmarkControllerRenderState(')),
        );
        expect(stagingBody, isNot(contains('_benchmarkPaintCandidates(')));

        expect(
          endToEndBody,
          contains('_createProductionBenchmarkRenderState('),
        );
        expect(endToEndBody, contains('_paintScene(painter, canvasSize);'));

        expect(painterOnlyBody, contains('_BenchmarkControllerRenderState('));
        expect(
          source,
          contains('preview: SceneViewFramePreview.captureSnapshot('),
        );
        expect(source, isNot(contains('readPreviewDeltaResolver')));
      },
    );
  });
}
