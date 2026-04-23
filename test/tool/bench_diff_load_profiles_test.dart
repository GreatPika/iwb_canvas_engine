@Tags(['tool'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import '../../tool/bench/load_profile_policy.dart';
import '../../tool/bench/diff_load_profiles.dart' as bench_diff;

// INV:INV-ENG-PERFORMANCE-PROOF-CONTOUR

String _smokePrimaryNodeCaseName() =>
    loadProfilePolicyFor('smoke').nodeCases.single.name;

void main() {
  group('tool/bench/diff_load_profiles.dart', () {
    test('diff policy reports smoke as product and full as stress', () {
      final smokeOutput = bench_diff.buildDiffReport(
        baseline: _fullSmokeReport(metricValue: 100),
        current: _fullSmokeReport(metricValue: 100),
        requiredProfile: 'smoke',
        baselinePath: 'baseline.json',
        currentPath: 'current.json',
      );
      final fullOutput = bench_diff.buildDiffReport(
        baseline: _report(
          profile: 'full',
          cases: const <Map<String, Object?>>[],
        ),
        current: _report(
          profile: 'full',
          cases: const <Map<String, Object?>>[],
        ),
        requiredProfile: 'full',
        baselinePath: 'baseline.json',
        currentPath: 'current.json',
      );

      expect(
        (smokeOutput['policy'] as Map<String, Object?>)['profileSemantics'],
        'product_realistic',
      );
      expect(
        (fullOutput['policy'] as Map<String, Object?>)['profileSemantics'],
        'stress_nightly',
      );
    });

    test('diff report carries defect probe values alongside metrics', () {
      final baseline = _fullSmokeReport(metricValue: 100);
      final current = _fullSmokeReport(metricValue: 100);
      final selectionCase =
          ((current['cases'] as List).cast<Map<String, Object?>>()).singleWhere(
            (item) => item['name'] == selectionPathEndToEndPaintCaseName,
          );
      final selectionProbes =
          (selectionCase['probes']
                  as Map<String, Object?>)['paint_with_selection']
              as Map<String, Object?>;
      selectionProbes['saveLayerCount'] = 12;

      final output = bench_diff.buildDiffReport(
        baseline: baseline,
        current: current,
        requiredProfile: 'smoke',
        baselinePath: 'baseline.json',
        currentPath: 'current.json',
      );

      final selectionDiff =
          ((output['cases'] as List).cast<Map<String, Object?>>()).singleWhere(
            (item) => item['name'] == selectionPathEndToEndPaintCaseName,
          );
      final operation =
          ((selectionDiff['operations'] as List).cast<Map<String, Object?>>())
              .singleWhere(
                (item) => item['operation'] == 'paint_with_selection',
              );
      final probe = ((operation['probes'] as List).cast<Map<String, Object?>>())
          .singleWhere((item) => item['probe'] == 'saveLayerCount');

      expect(probe['baselineValue'], 8);
      expect(probe['currentValue'], 12);
      expect(probe['delta'], 4);
    });

    test('builds byte-identical deterministic diff report', () async {
      final sandbox = await _createSandbox();
      try {
        _writeJson(
          sandbox,
          'baseline.json',
          _fullSmokeReportWithNodePatchMetrics(
            singleNodePatchMetrics: _metrics(100, 90, 120, 130),
          ),
        );
        _writeJson(
          sandbox,
          'current.json',
          _fullSmokeReportWithNodePatchMetrics(
            singleNodePatchMetrics: _metrics(110, 95, 130, 140),
          ),
        );

        final first = await _runDiffTool(sandbox);
        expect(first.exitCode, 0, reason: first.stderr.toString());
        final firstRaw = _readOutputRaw(sandbox);
        final firstOutput = _decodeOutput(firstRaw);

        final second = await _runDiffTool(sandbox);
        expect(second.exitCode, 0, reason: second.stderr.toString());
        final secondRaw = _readOutputRaw(sandbox);

        expect(firstRaw, secondRaw);
        expect(firstOutput['profile'], 'smoke');

        final summary = firstOutput['summary'] as Map<String, Object?>;
        expect(
          summary['comparedCases'],
          loadProfilePolicyFor('smoke').requiredCaseNames.length,
        );
        expect(summary['missingInBaseline'], isEmpty);
        expect(summary['missingInCurrent'], isEmpty);

        final cases = firstOutput['cases'] as List<Object?>;
        final case0 = cases.cast<Map<String, Object?>>().singleWhere(
          (item) => item['name'] == _smokePrimaryNodeCaseName(),
        );
        final operations = case0['operations'] as List<Object?>;
        final operation0 = operations.cast<Map<String, Object?>>().singleWhere(
          (item) => item['operation'] == 'single_node_patch',
        );
        final metrics = operation0['metrics'] as List<Object?>;
        final avg =
            metrics.firstWhere((m) {
                  return (m as Map<String, Object?>)['metric'] == 'avgUs';
                })
                as Map<String, Object?>;
        expect((avg['deltaAbsUs'] as num).toDouble(), 10);
        expect((avg['deltaPct'] as num).toDouble(), 10);
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    });

    test('preserves fractional metric precision in diff output', () async {
      final sandbox = await _createSandbox();
      try {
        _writeJson(
          sandbox,
          'baseline.json',
          _fullSmokeReportWithNodePatchMetrics(
            singleNodePatchMetrics: _metrics(100.4, 90.2, 120.8, 130.1),
          ),
        );
        _writeJson(
          sandbox,
          'current.json',
          _fullSmokeReportWithNodePatchMetrics(
            singleNodePatchMetrics: _metrics(101.1, 90.9, 121.3, 131.7),
          ),
        );

        final result = await _runDiffTool(sandbox);
        expect(result.exitCode, 0, reason: result.stderr.toString());

        final output = _decodeOutput(_readOutputRaw(sandbox));
        final metrics =
            (((((output['cases'] as List).cast<Map<String, Object?>>())
                                .singleWhere(
                                  (item) =>
                                      item['name'] ==
                                      _smokePrimaryNodeCaseName(),
                                )['operations']
                            as List)
                        .cast<Map<String, Object?>>())
                    .singleWhere(
                      (item) => item['operation'] == 'single_node_patch',
                    )['metrics']
                as List);
        final avg = metrics.first as Map<String, Object?>;
        expect(avg['metric'], 'avgUs');
        expect((avg['baselineUs'] as num).toDouble(), closeTo(100.4, 0.0001));
        expect((avg['currentUs'] as num).toDouble(), closeTo(101.1, 0.0001));
        expect((avg['deltaAbsUs'] as num).toDouble(), closeTo(0.7, 0.0001));
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    });

    test('reports missing cases in baseline and current', () async {
      final sandbox = await _createSandbox();
      try {
        _writeJson(
          sandbox,
          'baseline.json',
          _report(
            profile: 'smoke',
            cases: <Map<String, Object?>>[
              _caseMetrics(
                _smokePrimaryNodeCaseName(),
                <String, Map<String, num>>{
                  'single_node_patch': _metrics(100, 100, 100, 100),
                  'single_node_transform': _metrics(100, 100, 100, 100),
                  'toggle_selection': _metrics(100, 100, 100, 100),
                  'move_selection': _metrics(100, 100, 100, 100),
                },
              ),
            ],
          ),
        );
        _writeJson(
          sandbox,
          'current.json',
          _report(
            profile: 'smoke',
            cases: <Map<String, Object?>>[
              _caseMetrics('strokes_1000_pts_256', <String, Map<String, num>>{
                'single_node_patch': _metrics(100, 100, 100, 100),
                'single_stroke_patch_thickness': _metrics(100, 100, 100, 100),
                'single_stroke_patch_points': _metrics(100, 100, 100, 100),
                'toggle_selection': _metrics(100, 100, 100, 100),
              }),
            ],
          ),
        );

        final result = await _runDiffTool(sandbox);
        expect(result.exitCode, isNonZero);

        final output = _decodeOutput(_readOutputRaw(sandbox));
        final summary = output['summary'] as Map<String, Object?>;
        expect(summary['comparedCases'], 0);
        expect(summary['missingInBaseline'], <String>['strokes_1000_pts_256']);
        expect(summary['missingInCurrent'], <String>[
          _smokePrimaryNodeCaseName(),
        ]);
        expect(summary['failureCount'], greaterThan(0));
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    });

    test(
      'writes null deltaPct with note when baseline metric is zero',
      () async {
        final sandbox = await _createSandbox();
        try {
          _writeJson(
            sandbox,
            'baseline.json',
            _fullSmokeReportWithNodePatchMetrics(
              singleNodePatchMetrics: _metrics(0, 0, 0, 0),
            ),
          );
          _writeJson(
            sandbox,
            'current.json',
            _fullSmokeReportWithNodePatchMetrics(
              singleNodePatchMetrics: _metrics(10, 10, 10, 10),
            ),
          );

          final result = await _runDiffTool(sandbox);
          expect(result.exitCode, 0, reason: result.stderr.toString());

          final output = _decodeOutput(_readOutputRaw(sandbox));
          final metrics =
              (((((output['cases'] as List).cast<Map<String, Object?>>())
                                  .singleWhere(
                                    (item) =>
                                        item['name'] ==
                                        _smokePrimaryNodeCaseName(),
                                  )['operations']
                              as List)
                          .cast<Map<String, Object?>>())
                      .singleWhere(
                        (item) => item['operation'] == 'single_node_patch',
                      )['metrics']
                  as List);
          final avg = metrics.first as Map<String, Object?>;
          expect(avg['metric'], 'avgUs');
          expect(avg['deltaPct'], isNull);
          expect(avg['deltaPctNote'], 'baseline_is_zero_or_negative');
        } finally {
          sandbox.deleteSync(recursive: true);
        }
      },
    );

    test('fails when required metric key is missing', () async {
      final sandbox = await _createSandbox();
      try {
        final baseline = _report(
          profile: 'smoke',
          cases: <Map<String, Object?>>[
            <String, Object?>{
              'name': _smokePrimaryNodeCaseName(),
              'profile': 'smoke',
              'metrics': <String, Object?>{
                'single_node_patch': <String, Object?>{
                  'avgUs': 1,
                  'minUs': 1,
                  'maxUs': 1,
                },
              },
            },
          ],
        );
        _writeJson(sandbox, 'baseline.json', baseline);
        _writeJson(sandbox, 'current.json', baseline);

        final result = await _runDiffTool(sandbox);
        expect(result.exitCode, isNonZero);
        expect(
          result.stderr.toString(),
          contains(
            'single_node_patch.avgRssDeltaBytes must be a finite number',
          ),
        );
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    });

    test('buildDiffReport fails when metric value is Infinity', () {
      expect(
        () => bench_diff.buildDiffReport(
          baseline: _report(
            profile: 'smoke',
            cases: <Map<String, Object?>>[
              _caseMetrics('nodes_non_finite', <String, Map<String, num>>{
                'single_node_patch': _metrics(double.infinity, 1, 1, 1),
              }),
            ],
          ),
          current: _report(
            profile: 'smoke',
            cases: <Map<String, Object?>>[
              _caseMetrics('nodes_non_finite', <String, Map<String, num>>{
                'single_node_patch': _metrics(1, 1, 1, 1),
              }),
            ],
          ),
          baselinePath: 'baseline.json',
          currentPath: 'current.json',
        ),
        throwsA(
          isA<Exception>().having(
            (error) => error.toString(),
            'message',
            contains('single_node_patch.avgUs must be a finite number'),
          ),
        ),
      );
    });

    test('buildDiffReport fails when metric value is NaN', () {
      expect(
        () => bench_diff.buildDiffReport(
          baseline: _report(
            profile: 'smoke',
            cases: <Map<String, Object?>>[
              _caseMetrics('nodes_non_finite', <String, Map<String, num>>{
                'single_node_patch': _metrics(double.nan, 1, 1, 1),
              }),
            ],
          ),
          current: _report(
            profile: 'smoke',
            cases: <Map<String, Object?>>[
              _caseMetrics('nodes_non_finite', <String, Map<String, num>>{
                'single_node_patch': _metrics(1, 1, 1, 1),
              }),
            ],
          ),
          baselinePath: 'baseline.json',
          currentPath: 'current.json',
        ),
        throwsA(
          isA<Exception>().having(
            (error) => error.toString(),
            'message',
            contains('single_node_patch.avgUs must be a finite number'),
          ),
        ),
      );
    });

    test('matches flat baseline and nested current metrics paths', () {
      final output = bench_diff.buildDiffReport(
        baseline: _report(
          profile: 'smoke',
          cases: <Map<String, Object?>>[
            _caseMetrics('nodes_path_norm', <String, Map<String, num>>{
              'single_node_patch': _metrics(100, 90, 120, 130),
            }),
          ],
        ),
        current: <String, Object?>{
          'profile': 'smoke',
          'caseCount': 1,
          'cases': <Map<String, Object?>>[
            <String, Object?>{
              'name': 'nodes_path_norm',
              'profile': 'smoke',
              'metrics': <String, Object?>{
                'nodeCount': 10000,
                'iterations': 3,
                'metrics': <String, Object?>{
                  'single_node_patch': _metrics(110, 95, 130, 140),
                },
              },
            },
          ],
        },
        baselinePath: 'baseline.json',
        currentPath: 'current.json',
      );

      final case0 = (output['cases'] as List).single as Map<String, Object?>;
      final summary = case0['summary'] as Map<String, Object?>;
      expect(summary['missingOperationsInBaseline'], isEmpty);
      expect(summary['missingOperationsInCurrent'], isEmpty);
      expect(summary['missingRequiredOperationsInBaseline'], isEmpty);
      expect(summary['missingRequiredOperationsInCurrent'], isEmpty);

      final operations = case0['operations'] as List<Object?>;
      expect(operations, hasLength(1));
      final operation = operations.single as Map<String, Object?>;
      expect(operation['operation'], 'single_node_patch');
    });

    test('matches nested baseline and flat current metrics paths', () {
      final output = bench_diff.buildDiffReport(
        baseline: <String, Object?>{
          'profile': 'smoke',
          'caseCount': 1,
          'cases': <Map<String, Object?>>[
            <String, Object?>{
              'name': 'nodes_path_norm',
              'profile': 'smoke',
              'metrics': <String, Object?>{
                'nodeCount': 10000,
                'iterations': 3,
                'metrics': <String, Object?>{
                  'single_node_patch': _metrics(100, 90, 120, 130),
                },
              },
            },
          ],
        },
        current: _report(
          profile: 'smoke',
          cases: <Map<String, Object?>>[
            _caseMetrics('nodes_path_norm', <String, Map<String, num>>{
              'single_node_patch': _metrics(110, 95, 130, 140),
            }),
          ],
        ),
        baselinePath: 'baseline.json',
        currentPath: 'current.json',
      );

      final case0 = (output['cases'] as List).single as Map<String, Object?>;
      final summary = case0['summary'] as Map<String, Object?>;
      expect(summary['missingOperationsInBaseline'], isEmpty);
      expect(summary['missingOperationsInCurrent'], isEmpty);
      expect(summary['missingRequiredOperationsInBaseline'], isEmpty);
      expect(summary['missingRequiredOperationsInCurrent'], isEmpty);

      final operations = case0['operations'] as List<Object?>;
      expect(operations, hasLength(1));
      final operation = operations.single as Map<String, Object?>;
      expect(operation['operation'], 'single_node_patch');
    });

    test('fails when required operation is missing in current report', () {
      final output = bench_diff.buildDiffReport(
        baseline: _report(
          profile: 'smoke',
          cases: <Map<String, Object?>>[
            _caseMetrics(
              _smokePrimaryNodeCaseName(),
              <String, Map<String, num>>{
                'single_node_patch': _metrics(100, 100, 100, 100),
                'single_node_transform': _metrics(100, 100, 100, 100),
                'toggle_selection': _metrics(100, 100, 100, 100),
                'move_selection': _metrics(100, 100, 100, 100),
              },
            ),
            _caseMetrics('strokes_1000_pts_256', <String, Map<String, num>>{
              'single_stroke_patch_thickness': _metrics(100, 100, 100, 100),
              'single_stroke_patch_points': _metrics(100, 100, 100, 100),
              'toggle_selection': _metrics(100, 100, 100, 100),
            }),
            ..._smokeSelectionPathCases(_metrics(100, 100, 100, 100)),
            _caseMetrics(
              backgroundLayerPaintAdmissionCaseName,
              <String, Map<String, num>>{
                'enumerate_viewport': _metrics(100, 100, 100, 100),
                'paint_viewport': _metrics(100, 100, 100, 100),
              },
            ),
          ],
        ),
        current: _report(
          profile: 'smoke',
          cases: <Map<String, Object?>>[
            _caseMetrics(
              _smokePrimaryNodeCaseName(),
              <String, Map<String, num>>{
                'single_node_patch': _metrics(100, 100, 100, 100),
                'single_node_transform': _metrics(100, 100, 100, 100),
                'toggle_selection': _metrics(100, 100, 100, 100),
              },
            ),
            _caseMetrics('strokes_1000_pts_256', <String, Map<String, num>>{
              'single_stroke_patch_thickness': _metrics(100, 100, 100, 100),
              'single_stroke_patch_points': _metrics(100, 100, 100, 100),
              'toggle_selection': _metrics(100, 100, 100, 100),
            }),
            ..._smokeSelectionPathCases(_metrics(100, 100, 100, 100)),
            _caseMetrics(
              backgroundLayerPaintAdmissionCaseName,
              <String, Map<String, num>>{
                'enumerate_viewport': _metrics(100, 100, 100, 100),
                'paint_viewport': _metrics(100, 100, 100, 100),
              },
            ),
          ],
        ),
        requiredProfile: 'smoke',
        baselinePath: 'baseline.json',
        currentPath: 'current.json',
      );

      expect(output['status'], 'fail');
      expect(
        output['failures'],
        contains(
          '${_smokePrimaryNodeCaseName()} missing required operations in '
          'current: move_selection',
        ),
      );
    });

    test('fails when required case is missing in both reports', () {
      final output = bench_diff.buildDiffReport(
        baseline: _report(
          profile: 'smoke',
          cases: <Map<String, Object?>>[
            _caseMetrics(
              _smokePrimaryNodeCaseName(),
              <String, Map<String, num>>{
                'single_node_patch': _metrics(100, 100, 100, 100),
                'single_node_transform': _metrics(100, 100, 100, 100),
                'toggle_selection': _metrics(100, 100, 100, 100),
                'move_selection': _metrics(100, 100, 100, 100),
              },
            ),
            _caseMetrics('strokes_1000_pts_256', <String, Map<String, num>>{
              'single_stroke_patch_thickness': _metrics(100, 100, 100, 100),
              'single_stroke_patch_points': _metrics(100, 100, 100, 100),
              'toggle_selection': _metrics(100, 100, 100, 100),
            }),
            _caseMetrics(
              backgroundLayerPaintAdmissionCaseName,
              <String, Map<String, num>>{
                'enumerate_viewport': _metrics(100, 100, 100, 100),
                'paint_viewport': _metrics(100, 100, 100, 100),
              },
            ),
          ],
        ),
        current: _report(
          profile: 'smoke',
          cases: <Map<String, Object?>>[
            _caseMetrics(
              _smokePrimaryNodeCaseName(),
              <String, Map<String, num>>{
                'single_node_patch': _metrics(100, 100, 100, 100),
                'single_node_transform': _metrics(100, 100, 100, 100),
                'toggle_selection': _metrics(100, 100, 100, 100),
                'move_selection': _metrics(100, 100, 100, 100),
              },
            ),
            _caseMetrics('strokes_1000_pts_256', <String, Map<String, num>>{
              'single_stroke_patch_thickness': _metrics(100, 100, 100, 100),
              'single_stroke_patch_points': _metrics(100, 100, 100, 100),
              'toggle_selection': _metrics(100, 100, 100, 100),
            }),
            _caseMetrics(
              backgroundLayerPaintAdmissionCaseName,
              <String, Map<String, num>>{
                'enumerate_viewport': _metrics(100, 100, 100, 100),
                'paint_viewport': _metrics(100, 100, 100, 100),
              },
            ),
          ],
        ),
        requiredProfile: 'smoke',
        baselinePath: 'baseline.json',
        currentPath: 'current.json',
      );

      expect(output['status'], 'fail');
      final summary = output['summary'] as Map<String, Object?>;
      expect(summary['missingRequiredInBaseline'], <String>[
        selectionPathCandidateStagingCaseName,
        selectionPathEndToEndPaintCaseName,
        selectionPathPainterOnlyCaseName,
        stableVisibleWorkingSetPaintCaseName,
        staticBackgroundCacheCaseName,
        strokePathCacheCaseName,
        textLayoutCacheCaseName,
      ]);
      expect(summary['missingRequiredInCurrent'], <String>[
        selectionPathCandidateStagingCaseName,
        selectionPathEndToEndPaintCaseName,
        selectionPathPainterOnlyCaseName,
        stableVisibleWorkingSetPaintCaseName,
        staticBackgroundCacheCaseName,
        strokePathCacheCaseName,
        textLayoutCacheCaseName,
      ]);
      expect(
        output['failures'],
        contains(
          'missing required cases in baseline: '
          '$selectionPathCandidateStagingCaseName, '
          '$selectionPathEndToEndPaintCaseName, '
          '$selectionPathPainterOnlyCaseName, '
          '$stableVisibleWorkingSetPaintCaseName, '
          '$staticBackgroundCacheCaseName, '
          '$strokePathCacheCaseName, '
          '$textLayoutCacheCaseName',
        ),
      );
      expect(
        output['failures'],
        contains(
          'missing required cases in current: '
          '$selectionPathCandidateStagingCaseName, '
          '$selectionPathEndToEndPaintCaseName, '
          '$selectionPathPainterOnlyCaseName, '
          '$stableVisibleWorkingSetPaintCaseName, '
          '$staticBackgroundCacheCaseName, '
          '$strokePathCacheCaseName, '
          '$textLayoutCacheCaseName',
        ),
      );
    });

    test('fails when gated regression exceeds configured threshold', () {
      final policy = loadProfilePolicyFor('smoke');
      final output = bench_diff.buildDiffReport(
        baseline: _fullSmokeReport(metricValue: 100),
        current: _fullSmokeReport(
          metricValue:
              100 + policy.maxRegressionPctByMetric['avgUs']!.toInt() + 10,
          onlyAvgRegression: true,
        ),
        requiredProfile: 'smoke',
        baselinePath: 'baseline.json',
        currentPath: 'current.json',
      );

      expect(output['status'], 'fail');
      final failures = (output['failures'] as List<Object?>).cast<String>();
      expect(failures.any((item) => item.contains('avgUs regression')), isTrue);
    });

    test('treats memory deltas as diagnostic-only in product diff output', () {
      final output = bench_diff.buildDiffReport(
        baseline: _fullSmokeReportWithNodePatchMetrics(
          singleNodePatchMetrics: _metrics(
            100,
            100,
            100,
            100,
            avgRssDeltaBytes: 1000,
            minRssDeltaBytes: 1000,
            p95RssDeltaBytes: 1000,
            maxRssDeltaBytes: 1000,
          ),
        ),
        current: _fullSmokeReportWithNodePatchMetrics(
          singleNodePatchMetrics: _metrics(
            100,
            100,
            100,
            100,
            avgRssDeltaBytes: 5000,
            minRssDeltaBytes: 1000,
            p95RssDeltaBytes: 1000,
            maxRssDeltaBytes: 1000,
          ),
        ),
        requiredProfile: 'smoke',
        baselinePath: 'baseline.json',
        currentPath: 'current.json',
      );

      expect(output['status'], 'pass');
      final nodeCase = ((output['cases'] as List).cast<Map<String, Object?>>())
          .singleWhere((item) => item['name'] == _smokePrimaryNodeCaseName());
      final nodeOperation =
          ((nodeCase['operations'] as List).cast<Map<String, Object?>>())
              .singleWhere((item) => item['operation'] == 'single_node_patch');
      final memoryMetric =
          ((nodeOperation['metrics'] as List).cast<Map<String, Object?>>())
              .singleWhere((item) => item['metric'] == 'avgRssDeltaBytes');

      expect(memoryMetric['status'], 'not_gated');
      expect(memoryMetric['maxAllowedRegressionPct'], isNull);
      expect(memoryMetric['maxAllowedAbsoluteValue'], isNull);
    });

    test('applies perf policy even when CLI omits --profile', () async {
      final sandbox = await _createSandbox();
      try {
        final policy = loadProfilePolicyFor('smoke');
        _writeJson(
          sandbox,
          'baseline.json',
          _fullSmokeReport(metricValue: 100),
        );
        _writeJson(
          sandbox,
          'current.json',
          _fullSmokeReport(
            metricValue:
                100 + policy.maxRegressionPctByMetric['avgUs']!.toInt() + 10,
            onlyAvgRegression: true,
          ),
        );

        final result = await _runDiffTool(sandbox, includeProfile: false);
        expect(result.exitCode, isNonZero);
        expect(result.stderr.toString(), contains('policy violations'));

        final output = _decodeOutput(_readOutputRaw(sandbox));
        expect(output['status'], 'fail');
        final failures = (output['failures'] as List<Object?>).cast<String>();
        expect(
          failures.any((item) => item.contains('avgUs regression')),
          isTrue,
        );
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    });

    test('writes failure report for unknown profile from json', () async {
      final sandbox = await _createSandbox();
      try {
        final invalidReport = _report(
          profile: 'mystery',
          cases: <Map<String, Object?>>[
            _caseMetrics(
              _smokePrimaryNodeCaseName(),
              <String, Map<String, num>>{
                'single_node_patch': _metrics(100, 100, 100, 100),
                'single_node_transform': _metrics(100, 100, 100, 100),
                'toggle_selection': _metrics(100, 100, 100, 100),
                'move_selection': _metrics(100, 100, 100, 100),
              },
            ),
          ],
        );
        _writeJson(sandbox, 'baseline.json', invalidReport);
        _writeJson(sandbox, 'current.json', invalidReport);

        final result = await _runDiffTool(sandbox, includeProfile: false);
        expect(result.exitCode, isNonZero);
        expect(
          result.stderr.toString(),
          contains('unsupported benchmark profile'),
        );
        expect(
          result.stderr.toString(),
          isNot(contains('Unhandled exception')),
        );

        final output = _decodeOutput(_readOutputRaw(sandbox));
        expect(output['status'], 'fail');
        expect(
          output['failures'],
          contains(
            'unsupported benchmark profile "mystery"; expected smoke or full',
          ),
        );
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    });
  });
}

Future<Directory> _createSandbox() async {
  final sandbox = await Directory.systemTemp.createTemp(
    'iwb_canvas_engine_bench_diff_tool_test_',
  );
  _writeFile(sandbox, 'pubspec.yaml', '''
name: iwb_canvas_engine
environment:
  sdk: ">=3.0.0 <4.0.0"
''');
  _copyFile(
    '${Directory.current.path}/tool/bench/diff_load_profiles.dart',
    '${sandbox.path}/tool/bench/diff_load_profiles.dart',
  );
  _copyFile(
    '${Directory.current.path}/tool/bench/load_profile_policy.dart',
    '${sandbox.path}/tool/bench/load_profile_policy.dart',
  );
  return sandbox;
}

Future<ProcessResult> _runDiffTool(
  Directory sandbox, {
  bool includeProfile = true,
}) {
  final args = <String>[
    'run',
    'tool/bench/diff_load_profiles.dart',
    '--baseline=baseline.json',
    '--current=current.json',
    '--output=out.json',
  ];
  if (includeProfile) {
    args.insert(2, '--profile=smoke');
  }
  return Process.run('dart', args, workingDirectory: sandbox.path);
}

String _readOutputRaw(Directory sandbox) {
  return File('${sandbox.path}/out.json').readAsStringSync();
}

Map<String, Object?> _decodeOutput(String raw) {
  return jsonDecode(raw) as Map<String, Object?>;
}

Map<String, Object?> _report({
  required String profile,
  required List<Map<String, Object?>> cases,
}) {
  return <String, Object?>{
    'profile': profile,
    'caseCount': cases.length,
    'cases': cases,
  };
}

Map<String, Object?> _caseMetrics(
  String name,
  Object metrics, {
  Object? probes,
}) {
  return <String, Object?>{
    'name': name,
    'profile': 'smoke',
    'metrics': metrics,
    ...?(probes == null ? null : <String, Object?>{'probes': probes}),
  };
}

Map<String, Object?> _fullSmokeReport({
  required num metricValue,
  bool onlyAvgRegression = false,
}) {
  final stableMetrics = _metrics(100, 100, 100, 100);
  final regressedMetrics = <String, num>{
    'avgUs': metricValue,
    'minUs': onlyAvgRegression ? 100 : metricValue,
    'p95Us': onlyAvgRegression ? 100 : metricValue,
    'maxUs': onlyAvgRegression ? 100 : metricValue,
    'avgRssDeltaBytes': 1000,
    'minRssDeltaBytes': 1000,
    'p95RssDeltaBytes': 1000,
    'maxRssDeltaBytes': 1000,
  };
  return _report(
    profile: 'smoke',
    cases: <Map<String, Object?>>[
      _caseMetrics(_smokePrimaryNodeCaseName(), <String, Map<String, num>>{
        'single_node_patch': _smokeMetricLeaf(regressedMetrics),
        'single_node_transform': _smokeMetricLeaf(stableMetrics),
        'toggle_selection': _smokeMetricLeaf(stableMetrics),
        'move_selection': _smokeMetricLeaf(stableMetrics),
      }),
      _caseMetrics('strokes_1000_pts_256', <String, Map<String, num>>{
        'single_stroke_patch_thickness': _smokeMetricLeaf(stableMetrics),
        'single_stroke_patch_points': _smokeMetricLeaf(stableMetrics),
        'toggle_selection': _smokeMetricLeaf(stableMetrics),
      }),
      ..._smokeSelectionPathCases(stableMetrics),
      _caseMetrics(
        backgroundLayerPaintAdmissionCaseName,
        <String, Map<String, num>>{
          'enumerate_viewport': _smokeMetricLeaf(stableMetrics),
          'paint_viewport': _smokeMetricLeaf(stableMetrics),
        },
      ),
      ..._smokeCacheCases(stableMetrics),
    ],
  );
}

Map<String, Object?> _fullSmokeReportWithNodePatchMetrics({
  required Map<String, num> singleNodePatchMetrics,
}) {
  final stableMetrics = _metrics(100, 100, 100, 100);
  return _report(
    profile: 'smoke',
    cases: <Map<String, Object?>>[
      _caseMetrics(_smokePrimaryNodeCaseName(), <String, Map<String, num>>{
        'single_node_patch': _smokeMetricLeaf(singleNodePatchMetrics),
        'single_node_transform': _smokeMetricLeaf(stableMetrics),
        'toggle_selection': _smokeMetricLeaf(stableMetrics),
        'move_selection': _smokeMetricLeaf(stableMetrics),
      }),
      _caseMetrics('strokes_1000_pts_256', <String, Map<String, num>>{
        'single_stroke_patch_thickness': _smokeMetricLeaf(stableMetrics),
        'single_stroke_patch_points': _smokeMetricLeaf(stableMetrics),
        'toggle_selection': _smokeMetricLeaf(stableMetrics),
      }),
      ..._smokeSelectionPathCases(stableMetrics),
      _caseMetrics(
        backgroundLayerPaintAdmissionCaseName,
        <String, Map<String, num>>{
          'enumerate_viewport': _smokeMetricLeaf(stableMetrics),
          'paint_viewport': _smokeMetricLeaf(stableMetrics),
        },
      ),
      ..._smokeCacheCases(stableMetrics),
    ],
  );
}

Map<String, num> _smokeMetricLeaf(Map<String, num> metrics) {
  return <String, num>{
    'avgUs': metrics['avgUs']!,
    'minUs': metrics['minUs']!,
    'maxUs': metrics['maxUs']!,
    'avgRssDeltaBytes': metrics['avgRssDeltaBytes']!,
    'minRssDeltaBytes': metrics['minRssDeltaBytes']!,
    'maxRssDeltaBytes': metrics['maxRssDeltaBytes']!,
  };
}

List<Map<String, Object?>> _smokeSelectionPathCases(Map<String, num> metrics) {
  final leaf = _smokeMetricLeaf(metrics);
  return <Map<String, Object?>>[
    _caseMetrics(
      selectionPathPainterOnlyCaseName,
      <String, Map<String, num>>{
        'paint_no_selection': leaf,
        'paint_with_selection': leaf,
      },
      probes: <String, Map<String, num>>{
        'paint_no_selection': _selectionProbeLeaf(0),
        'paint_with_selection': _selectionProbeLeaf(8),
      },
    ),
    _caseMetrics(
      selectionPathCandidateStagingCaseName,
      <String, Map<String, num>>{
        'stage_no_selection': leaf,
        'stage_with_selection': leaf,
      },
    ),
    _caseMetrics(
      selectionPathEndToEndPaintCaseName,
      <String, Map<String, num>>{
        'paint_no_selection': leaf,
        'paint_with_selection': leaf,
      },
      probes: <String, Map<String, num>>{
        'paint_no_selection': _selectionProbeLeaf(0),
        'paint_with_selection': _selectionProbeLeaf(8),
      },
    ),
  ];
}

List<Map<String, Object?>> _smokeCacheCases(Map<String, num> metrics) {
  final leaf = _smokeMetricLeaf(metrics);
  return <Map<String, Object?>>[
    _caseMetrics(
      stableVisibleWorkingSetPaintCaseName,
      <String, Map<String, num>>{
        'paint_cache_miss': leaf,
        'paint_cache_hit': leaf,
      },
      probes: <String, Map<String, num>>{
        'paint_cache_miss': _stableVisibleWorkingSetProbeLeaf(
          geometryBuildDelta: 12,
          geometryHitDelta: 0,
          geometryEvictDelta: 4,
          textBuildDelta: 3,
          textHitDelta: 0,
          textEvictDelta: 1,
          strokeBuildDelta: 3,
          strokeHitDelta: 0,
          strokeEvictDelta: 1,
          pathMetricsBuildDelta: 3,
          pathMetricsHitDelta: 0,
          pathMetricsEvictDelta: 1,
        ),
        'paint_cache_hit': _stableVisibleWorkingSetProbeLeaf(
          geometryBuildDelta: 4,
          geometryHitDelta: 8,
          geometryEvictDelta: 4,
          textBuildDelta: 1,
          textHitDelta: 2,
          textEvictDelta: 1,
          strokeBuildDelta: 1,
          strokeHitDelta: 2,
          strokeEvictDelta: 1,
          pathMetricsBuildDelta: 1,
          pathMetricsHitDelta: 2,
          pathMetricsEvictDelta: 1,
        ),
      },
    ),
    _caseMetrics(
      textLayoutCacheCaseName,
      <String, Map<String, num>>{
        'paint_cache_miss': leaf,
        'paint_cache_hit': leaf,
      },
      probes: <String, Map<String, num>>{
        'paint_cache_miss': _cacheProbeLeaf(buildDelta: 1, hitDelta: 0),
        'paint_cache_hit': _cacheProbeLeaf(buildDelta: 0, hitDelta: 1),
      },
    ),
    _caseMetrics(
      strokePathCacheCaseName,
      <String, Map<String, num>>{
        'paint_cache_miss': leaf,
        'paint_cache_hit': leaf,
      },
      probes: <String, Map<String, num>>{
        'paint_cache_miss': _cacheProbeLeaf(buildDelta: 1, hitDelta: 0),
        'paint_cache_hit': _cacheProbeLeaf(buildDelta: 0, hitDelta: 1),
      },
    ),
    _caseMetrics(
      staticBackgroundCacheCaseName,
      <String, Map<String, num>>{
        'paint_cache_miss': leaf,
        'paint_cache_hit': leaf,
      },
      probes: <String, Map<String, num>>{
        'paint_cache_miss': _staticBackgroundProbeLeaf(
          buildDelta: 1,
          gridLoopIterations: 200,
          gridDrawnLineCount: 200,
        ),
        'paint_cache_hit': _staticBackgroundProbeLeaf(
          buildDelta: 0,
          gridLoopIterations: 0,
          gridDrawnLineCount: 0,
        ),
      },
    ),
  ];
}

Map<String, num> _selectionProbeLeaf(
  num saveLayerCount, {
  num unboundedSaveLayerCount = 0,
  num saveLayerBoundsArea = 0,
}) {
  return <String, num>{
    'saveLayerCount': saveLayerCount,
    'unboundedSaveLayerCount': unboundedSaveLayerCount,
    'saveLayerBoundsArea': saveLayerBoundsArea,
  };
}

Map<String, num> _stableVisibleWorkingSetProbeLeaf({
  required num geometryBuildDelta,
  required num geometryHitDelta,
  required num geometryEvictDelta,
  required num textBuildDelta,
  required num textHitDelta,
  required num textEvictDelta,
  required num strokeBuildDelta,
  required num strokeHitDelta,
  required num strokeEvictDelta,
  required num pathMetricsBuildDelta,
  required num pathMetricsHitDelta,
  required num pathMetricsEvictDelta,
}) {
  return <String, num>{
    'geometryBuildDelta': geometryBuildDelta,
    'geometryHitDelta': geometryHitDelta,
    'geometryEvictDelta': geometryEvictDelta,
    'textBuildDelta': textBuildDelta,
    'textHitDelta': textHitDelta,
    'textEvictDelta': textEvictDelta,
    'strokeBuildDelta': strokeBuildDelta,
    'strokeHitDelta': strokeHitDelta,
    'strokeEvictDelta': strokeEvictDelta,
    'pathMetricsBuildDelta': pathMetricsBuildDelta,
    'pathMetricsHitDelta': pathMetricsHitDelta,
    'pathMetricsEvictDelta': pathMetricsEvictDelta,
  };
}

Map<String, num> _cacheProbeLeaf({
  required num buildDelta,
  required num hitDelta,
  num evictDelta = 0,
}) {
  return <String, num>{
    'buildDelta': buildDelta,
    'hitDelta': hitDelta,
    'evictDelta': evictDelta,
  };
}

Map<String, num> _staticBackgroundProbeLeaf({
  required num buildDelta,
  num gridLoopIterations = 1000,
  num gridDrawnLineCount = 200,
}) {
  return <String, num>{
    'buildDelta': buildDelta,
    'disposeDelta': 0,
    'gridLoopIterations': gridLoopIterations,
    'gridDrawnLineCount': gridDrawnLineCount,
  };
}

Map<String, num> _metrics(
  num avgUs,
  num minUs,
  num p95Us,
  num maxUs, {
  num avgRssDeltaBytes = 1000,
  num minRssDeltaBytes = 1000,
  num p95RssDeltaBytes = 1000,
  num maxRssDeltaBytes = 1000,
}) {
  return <String, num>{
    'avgUs': avgUs,
    'minUs': minUs,
    'p95Us': p95Us,
    'maxUs': maxUs,
    'avgRssDeltaBytes': avgRssDeltaBytes,
    'minRssDeltaBytes': minRssDeltaBytes,
    'p95RssDeltaBytes': p95RssDeltaBytes,
    'maxRssDeltaBytes': maxRssDeltaBytes,
  };
}

void _copyFile(String from, String to) {
  final source = File(from);
  final target = File(to);
  target.parent.createSync(recursive: true);
  source.copySync(target.path);
}

void _writeJson(Directory sandbox, String path, Map<String, Object?> json) {
  _writeFile(
    sandbox,
    path,
    '${const JsonEncoder.withIndent('  ').convert(json)}\n',
  );
}

void _writeFile(Directory root, String relativePath, String content) {
  final file = File('${root.path}/$relativePath');
  file.parent.createSync(recursive: true);
  file.writeAsStringSync(content);
}
