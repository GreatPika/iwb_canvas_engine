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

String _smokePrimaryNodeCaseName() =>
    loadProfilePolicyFor('smoke').nodeCases.single.name;

Map<String, Object?> _probeRecord(String name, Map<String, Object?> probes) {
  return <String, Object?>{'name': name, 'probes': probes};
}

void main() {
  group('tool/bench/run_load_profiles.dart', () {
    test('locks smoke as product profile and full as stress profile', () {
      final smoke = loadProfilePolicyFor('smoke');
      final full = loadProfilePolicyFor('full');
      final smokeMetadata = smoke.reportMetadata;
      final fullMetadata = full.reportMetadata;

      expect(smoke.nodeCases.map((c) => c.nodeCount), <int>[1000]);
      expect(smokeMetadata['profileSemantics'], 'product_realistic');
      expect(smoke.requiredCaseNames, isNot(contains(worstCaseName)));
      expect(smokeMetadata['backgroundViewport'], <String, int>{
        'width': 3840,
        'height': 2160,
      });
      expect(full.requiredCaseNames, contains(worstCaseName));
      expect(full.nodeCases.map((c) => c.nodeCount), <int>[
        10000,
        50000,
        100000,
      ]);
      expect(fullMetadata['profileSemantics'], 'stress_nightly');
    });

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
          <String, Object?>{'name': _smokePrimaryNodeCaseName()},
          <String, Object?>{'name': 'strokes_1000_pts_256'},
          <String, Object?>{'name': backgroundLayerPaintAdmissionCaseName},
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
          <String, Object?>{'name': _smokePrimaryNodeCaseName()},
          <String, Object?>{'name': _smokePrimaryNodeCaseName()},
          <String, Object?>{'name': 'strokes_1000_pts_256'},
          <String, Object?>{'name': selectionPathPainterOnlyCaseName},
          <String, Object?>{'name': 'unexpected_case'},
        ],
      );

      expect(
        issues,
        contains('duplicate benchmark cases: ${_smokePrimaryNodeCaseName()}'),
      );
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
        final nodeContract = policy.contractForCase(
          _smokePrimaryNodeCaseName(),
        );
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
        expect(policySource, contains('probeKeys'));
        expect(policySource, contains('gatedMetrics'));
        expect(policySource, contains('diagnosticMetrics'));
        expect(casesSource, isNot(contains('includePercentiles')));
      },
    );

    test('fails when required defect probes are missing from smoke report', () {
      final policy = loadProfilePolicyFor('smoke');

      final issues = run_load_profiles.validateCollectedBenchmarkCaseContracts(
        policy: policy,
        parsedCases: <Map<String, Object?>>[
          _probeRecord(textLayoutCacheCaseName, const <String, Object?>{}),
          _probeRecord(
            selectionPathEndToEndPaintCaseName,
            const <String, Object?>{},
          ),
          _probeRecord(
            staticBackgroundCacheCaseName,
            const <String, Object?>{},
          ),
        ],
      );

      expect(
        issues,
        contains(
          'benchmark case "$textLayoutCacheCaseName" is missing probes for '
          '"paint_cache_miss"',
        ),
      );
      expect(
        issues,
        contains(
          'benchmark case "$selectionPathEndToEndPaintCaseName" is missing '
          'probes for "paint_no_selection"',
        ),
      );
      expect(
        issues,
        contains(
          'benchmark case "$staticBackgroundCacheCaseName" is missing probes '
          'for "paint_cache_hit"',
        ),
      );
    });

    test('accepts required defect probes for smoke report surfaces', () {
      final policy = loadProfilePolicyFor('smoke');

      final issues = run_load_profiles.validateCollectedBenchmarkCaseContracts(
        policy: policy,
        parsedCases: <Map<String, Object?>>[
          _probeRecord(textLayoutCacheCaseName, <String, Object?>{
            'paint_cache_miss': <String, Object?>{
              'buildDelta': 1,
              'hitDelta': 0,
              'evictDelta': 0,
            },
            'paint_cache_hit': <String, Object?>{
              'buildDelta': 0,
              'hitDelta': 1,
              'evictDelta': 0,
            },
          }),
          _probeRecord(selectionPathEndToEndPaintCaseName, <String, Object?>{
            'paint_no_selection': <String, Object?>{'saveLayerCount': 0},
            'paint_with_selection': <String, Object?>{'saveLayerCount': 8},
          }),
          _probeRecord(staticBackgroundCacheCaseName, <String, Object?>{
            'paint_cache_miss': <String, Object?>{
              'buildDelta': 1,
              'disposeDelta': 0,
              'gridLoopIterations': 1000,
              'gridDrawnLineCount': 200,
            },
            'paint_cache_hit': <String, Object?>{
              'buildDelta': 0,
              'disposeDelta': 0,
              'gridLoopIterations': 0,
              'gridDrawnLineCount': 0,
            },
          }),
        ],
      );

      expect(issues, isEmpty);
    });

    test('worst_case contract stays in the stress profile only', () {
      final smokePolicy = loadProfilePolicyFor('smoke');
      final fullPolicy = loadProfilePolicyFor('full');

      final fullContract = fullPolicy.contractForCase(worstCaseName);
      final fullOperation =
          ((fullContract['operations']
                  as Map<String, Object?>)['huge_bounds.query'])
              as Map<String, Object?>;

      expect(smokePolicy.requiredCaseNames, isNot(contains(worstCaseName)));
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
        final painterSource = File(
          'lib/src/render/scene_painter.dart',
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

        expect(
          painterOnlyBody,
          contains('_createProductionBenchmarkRenderState('),
        );
        expect(
          painterOnlyBody,
          contains('final noSelectionPrepared = painter.prepareForPaint('),
        );
        expect(
          painterOnlyBody,
          contains('_paintPreparedScene(painter, noSelectionPrepared);'),
        );
        expect(
          painterOnlyBody,
          contains('final withSelectionPrepared = painter.prepareForPaint('),
        );
        expect(
          painterOnlyBody,
          contains('_paintPreparedScene(painter, withSelectionPrepared);'),
        );
        expect(painterOnlyBody, contains('_captureSelectionSaveLayerProbe('));
        expect(painterSource, contains('class ScenePainterPreparedScene'));
        expect(
          painterSource,
          contains('ScenePainterPreparedScene prepareForPaint('),
        );
        expect(painterSource, contains('void paintPrepared('));
        expect(
          source,
          isNot(contains('class _PainterOnlyBenchmarkRenderState')),
        );
        expect(source, isNot(contains('_benchmarkPaintCandidates(')));
        expect(
          source,
          contains(
            'captureFramePreview: () => SceneViewFramePreview.captureSnapshot(',
          ),
        );
        expect(source, isNot(contains('readPreviewDeltaResolver')));
      },
    );
  });
}
