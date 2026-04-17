@Tags(['tool'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import '../../tool/bench/load_profile_policy.dart';
import '../../tool/bench/diff_load_profiles.dart' as bench_diff;

void main() {
  group('tool/bench/diff_load_profiles.dart', () {
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
        expect(summary['comparedCases'], 4);
        expect(summary['missingInBaseline'], isEmpty);
        expect(summary['missingInCurrent'], isEmpty);

        final cases = firstOutput['cases'] as List<Object?>;
        final case0 = cases.cast<Map<String, Object?>>().singleWhere(
          (item) => item['name'] == 'nodes_10000',
        );
        final operations = case0['operations'] as List<Object?>;
        final operation0 = operations.cast<Map<String, Object?>>().singleWhere(
          (item) => item['operation'] == 'single_node_patch',
        );
        final metrics = operation0['metrics'] as List<Object?>;
        final p95 =
            metrics.firstWhere((m) {
                  return (m as Map<String, Object?>)['metric'] == 'p95Us';
                })
                as Map<String, Object?>;
        expect((p95['deltaAbsUs'] as num).toDouble(), 10);
        expect((p95['deltaPct'] as num).toDouble(), 8.333);
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
                                  (item) => item['name'] == 'nodes_10000',
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
              _caseMetrics('nodes_10000', <String, Map<String, num>>{
                'single_node_patch': _metrics(100, 100, 100, 100),
                'single_node_transform': _metrics(100, 100, 100, 100),
                'toggle_selection': _metrics(100, 100, 100, 100),
                'move_selection': _metrics(100, 100, 100, 100),
              }),
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
        expect(summary['missingInCurrent'], <String>['nodes_10000']);
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
                                    (item) => item['name'] == 'nodes_10000',
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
              'name': 'nodes_10000',
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
          contains('single_node_patch.p95Us must be a finite number'),
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
            _caseMetrics('nodes_10000', <String, Map<String, num>>{
              'single_node_patch': _metrics(100, 100, 100, 100),
              'single_node_transform': _metrics(100, 100, 100, 100),
              'toggle_selection': _metrics(100, 100, 100, 100),
              'move_selection': _metrics(100, 100, 100, 100),
            }),
            _caseMetrics('strokes_1000_pts_256', <String, Map<String, num>>{
              'single_stroke_patch_thickness': _metrics(100, 100, 100, 100),
              'single_stroke_patch_points': _metrics(100, 100, 100, 100),
              'toggle_selection': _metrics(100, 100, 100, 100),
            }),
            _caseMetrics(selectionPathCaseName, <String, Map<String, num>>{
              'paint_no_selection': _metrics(100, 100, 100, 100),
              'paint_with_selection': _metrics(100, 100, 100, 100),
            }),
            _caseMetrics(
              worstCaseName,
              _worstCaseMetrics(_metrics(100, 100, 100, 100)),
            ),
          ],
        ),
        current: _report(
          profile: 'smoke',
          cases: <Map<String, Object?>>[
            _caseMetrics('nodes_10000', <String, Map<String, num>>{
              'single_node_patch': _metrics(100, 100, 100, 100),
              'single_node_transform': _metrics(100, 100, 100, 100),
              'toggle_selection': _metrics(100, 100, 100, 100),
            }),
            _caseMetrics('strokes_1000_pts_256', <String, Map<String, num>>{
              'single_stroke_patch_thickness': _metrics(100, 100, 100, 100),
              'single_stroke_patch_points': _metrics(100, 100, 100, 100),
              'toggle_selection': _metrics(100, 100, 100, 100),
            }),
            _caseMetrics(selectionPathCaseName, <String, Map<String, num>>{
              'paint_no_selection': _metrics(100, 100, 100, 100),
              'paint_with_selection': _metrics(100, 100, 100, 100),
            }),
            _caseMetrics(
              worstCaseName,
              _worstCaseMetrics(_metrics(100, 100, 100, 100)),
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
          'nodes_10000 missing required operations in current: move_selection',
        ),
      );
    });

    test('fails when required case is missing in both reports', () {
      final output = bench_diff.buildDiffReport(
        baseline: _report(
          profile: 'smoke',
          cases: <Map<String, Object?>>[
            _caseMetrics('nodes_10000', <String, Map<String, num>>{
              'single_node_patch': _metrics(100, 100, 100, 100),
              'single_node_transform': _metrics(100, 100, 100, 100),
              'toggle_selection': _metrics(100, 100, 100, 100),
              'move_selection': _metrics(100, 100, 100, 100),
            }),
            _caseMetrics('strokes_1000_pts_256', <String, Map<String, num>>{
              'single_stroke_patch_thickness': _metrics(100, 100, 100, 100),
              'single_stroke_patch_points': _metrics(100, 100, 100, 100),
              'toggle_selection': _metrics(100, 100, 100, 100),
            }),
            _caseMetrics(
              worstCaseName,
              _worstCaseMetrics(_metrics(100, 100, 100, 100)),
            ),
          ],
        ),
        current: _report(
          profile: 'smoke',
          cases: <Map<String, Object?>>[
            _caseMetrics('nodes_10000', <String, Map<String, num>>{
              'single_node_patch': _metrics(100, 100, 100, 100),
              'single_node_transform': _metrics(100, 100, 100, 100),
              'toggle_selection': _metrics(100, 100, 100, 100),
              'move_selection': _metrics(100, 100, 100, 100),
            }),
            _caseMetrics('strokes_1000_pts_256', <String, Map<String, num>>{
              'single_stroke_patch_thickness': _metrics(100, 100, 100, 100),
              'single_stroke_patch_points': _metrics(100, 100, 100, 100),
              'toggle_selection': _metrics(100, 100, 100, 100),
            }),
            _caseMetrics(
              worstCaseName,
              _worstCaseMetrics(_metrics(100, 100, 100, 100)),
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
        selectionPathCaseName,
      ]);
      expect(summary['missingRequiredInCurrent'], <String>[
        selectionPathCaseName,
      ]);
      expect(
        output['failures'],
        contains('missing required cases in baseline: $selectionPathCaseName'),
      );
      expect(
        output['failures'],
        contains('missing required cases in current: $selectionPathCaseName'),
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

    test('fails when gated memory regression exceeds configured threshold', () {
      final policy = loadProfilePolicyFor('smoke');
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
            avgRssDeltaBytes:
                1000 +
                (1000 *
                        policy.maxRegressionPctByMetric['avgRssDeltaBytes']! /
                        100)
                    .round() +
                100,
            minRssDeltaBytes: 1000,
            p95RssDeltaBytes: 1000,
            maxRssDeltaBytes: 1000,
          ),
        ),
        requiredProfile: 'smoke',
        baselinePath: 'baseline.json',
        currentPath: 'current.json',
      );

      expect(output['status'], 'fail');
      final failures = (output['failures'] as List<Object?>).cast<String>();
      expect(
        failures.any((item) => item.contains('avgRssDeltaBytes regression')),
        isTrue,
      );
    });

    test(
      'fails when zero-baseline memory delta exceeds absolute threshold',
      () {
        final policy = loadProfilePolicyFor('smoke');
        final output = bench_diff.buildDiffReport(
          baseline: _fullSmokeReportWithNodePatchMetrics(
            singleNodePatchMetrics: _metrics(
              100,
              100,
              100,
              100,
              avgRssDeltaBytes: 0,
              minRssDeltaBytes: 0,
              p95RssDeltaBytes: 0,
              maxRssDeltaBytes: 0,
            ),
          ),
          current: _fullSmokeReportWithNodePatchMetrics(
            singleNodePatchMetrics: _metrics(
              100,
              100,
              100,
              100,
              avgRssDeltaBytes:
                  policy.maxAbsoluteValueByMetric['avgRssDeltaBytes']!.toInt() +
                  1,
              minRssDeltaBytes: 0,
              p95RssDeltaBytes: 0,
              maxRssDeltaBytes: 0,
            ),
          ),
          requiredProfile: 'smoke',
          baselinePath: 'baseline.json',
          currentPath: 'current.json',
        );

        expect(output['status'], 'fail');
        final failures = (output['failures'] as List<Object?>).cast<String>();
        expect(
          failures.any(
            (item) => item.contains('avgRssDeltaBytes current value'),
          ),
          isTrue,
        );
      },
    );

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
            _caseMetrics('nodes_10000', <String, Map<String, num>>{
              'single_node_patch': _metrics(100, 100, 100, 100),
              'single_node_transform': _metrics(100, 100, 100, 100),
              'toggle_selection': _metrics(100, 100, 100, 100),
              'move_selection': _metrics(100, 100, 100, 100),
            }),
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

Map<String, Object?> _caseMetrics(String name, Object metrics) {
  return <String, Object?>{
    'name': name,
    'profile': 'smoke',
    'metrics': metrics,
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
      _caseMetrics('nodes_10000', <String, Map<String, num>>{
        'single_node_patch': regressedMetrics,
        'single_node_transform': stableMetrics,
        'toggle_selection': stableMetrics,
        'move_selection': stableMetrics,
      }),
      _caseMetrics('strokes_1000_pts_256', <String, Map<String, num>>{
        'single_stroke_patch_thickness': stableMetrics,
        'single_stroke_patch_points': stableMetrics,
        'toggle_selection': stableMetrics,
      }),
      _caseMetrics(selectionPathCaseName, <String, Map<String, num>>{
        'paint_no_selection': stableMetrics,
        'paint_with_selection': stableMetrics,
      }),
      _caseMetrics(worstCaseName, _worstCaseMetrics(stableMetrics)),
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
      _caseMetrics('nodes_10000', <String, Map<String, num>>{
        'single_node_patch': singleNodePatchMetrics,
        'single_node_transform': stableMetrics,
        'toggle_selection': stableMetrics,
        'move_selection': stableMetrics,
      }),
      _caseMetrics('strokes_1000_pts_256', <String, Map<String, num>>{
        'single_stroke_patch_thickness': stableMetrics,
        'single_stroke_patch_points': stableMetrics,
        'toggle_selection': stableMetrics,
      }),
      _caseMetrics(selectionPathCaseName, <String, Map<String, num>>{
        'paint_no_selection': stableMetrics,
        'paint_with_selection': stableMetrics,
      }),
      _caseMetrics(worstCaseName, _worstCaseMetrics(stableMetrics)),
    ],
  );
}

Map<String, Object?> _worstCaseMetrics(Map<String, num> stableMetrics) {
  return <String, Object?>{
    'huge_bounds': <String, Object?>{
      'query': stableMetrics,
      'move_selection': stableMetrics,
    },
    'huge_rect_select': stableMetrics,
    'very_long_path': <String, Object?>{
      'patch_svg_path': stableMetrics,
      'query_candidates': stableMetrics,
    },
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
