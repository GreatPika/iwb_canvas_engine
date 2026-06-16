import 'dart:io';

import 'package:test/test.dart';

void main() {
  test(
    'performance driver writes nested artifacts and local summaries',
    () async {
      final runtimeTest = File(
        'example/test/.flutter_performance_driver_writer_runtime_test.dart',
      );
      runtimeTest.writeAsStringSync(_runtimeWriterTestSource());
      addTearDown(() {
        if (runtimeTest.existsSync()) {
          runtimeTest.deleteSync();
        }
      });

      final result = await Process.run('flutter', [
        'test',
        'test/.flutter_performance_driver_writer_runtime_test.dart',
      ], workingDirectory: 'example');

      expect(
        result.exitCode,
        0,
        reason: [
          result.stdout,
          result.stderr,
        ].where((output) => output.toString().isNotEmpty).join('\n'),
      );
    },
  );
}

String _runtimeWriterTestSource() {
  return r'''
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine_example/perf/performance_scenario.dart';

import '../test_driver/perf_driver.dart';

const _forbiddenKeys = {
  'threshold',
  'thresholds',
  'passFail',
  'passed',
  'failed',
  'baseline',
  'baselineId',
  'baselinePath',
  'regression',
  'regressionStatus',
  'isRegression',
  'allowedDelta',
  'budgetMillis',
  'verdict',
};

const _comparisonSummaryFields = {
  'average_frame_build_time_millis',
  'worst_frame_build_time_millis',
  'average_frame_rasterizer_time_millis',
  'worst_frame_rasterizer_time_millis',
  'frame_count',
  'missed_frame_build_budget_count',
  'missed_frame_rasterizer_budget_count',
};

void main() {
  test('writer output follows the performance artifact contract', () async {
    final outputRoot = await Directory.systemTemp.createTemp(
      'flutter_performance_writer_test_',
    );
    addTearDown(() {
      if (outputRoot.existsSync()) {
        outputRoot.deleteSync(recursive: true);
      }
    });

    await writePerformanceTimelines(
      _driverResponse(),
      resultsDirectory: outputRoot,
    );

    final manifest = _readJsonObject(
      File('${outputRoot.path}/performance_run_manifest.json'),
    );
    final comparisonSummary = _readJsonObject(
      File('${outputRoot.path}/comparison_summary.json'),
    );

    expect(manifest.keys.toSet(), {
      'schemaVersion',
      'route',
      'unsupportedClaims',
      'scenarioGroups',
    });
    expect(comparisonSummary.keys.toSet(), {
      'schemaVersion',
      'sourceManifest',
      'routeName',
      'commandFamily',
      'scenarioGroups',
    });
    expect(_containsForbiddenKey(manifest), isFalse);
    expect(_containsForbiddenKey(comparisonSummary), isFalse);

    expect(manifest['schemaVersion'], 1);
    expect(manifest['route'], {
      'name': 'flutter_performance',
      'commandFamily': 'flutter drive --profile --no-dds',
      'driver': 'test_driver/perf_driver.dart',
      'target': 'integration_test/perf_canvas_surface_test.dart',
    });
    expect(manifest['unsupportedClaims'], {
      'numericThresholds': false,
      'passFailPerformance': false,
      'baselines': false,
      'regressionStatusClaims': false,
      'cpuAttribution': false,
      'startup': false,
      'androidMacrobenchmark': false,
    });

    final manifestGroups = _groupsById(manifest);
    final comparisonGroups = _groupsById(comparisonSummary);
    expect(manifestGroups.keys.toSet(), {
      for (final group in allPerformanceScenarioGroups) group.id,
    });
    expect(comparisonGroups.keys.toSet(), manifestGroups.keys.toSet());

    _expectRedesignedWarmAndSteadyManifest(manifestGroups);
    _expectSingleCurrentBehaviorManifest(manifestGroups);
    _expectNestedArtifacts(outputRoot, manifestGroups);
    _expectComparisonSummary(comparisonGroups, outputRoot);
  });
}

Map<String, dynamic> _driverResponse() {
  var offset = 0;
  return {
    for (final phaseRun in allPerformanceScenarioPhaseRuns)
      phaseRun.reportKey: _timelineJsonFor(phaseRun, offset += 1),
  };
}

Map<String, Object?> _timelineJsonFor(
  PerformanceScenarioPhaseRun phaseRun,
  int offset,
) {
  final buildMillis = phaseRun.scenarioGroupId == 'load_document.100k' &&
          phaseRun.phaseKey == 'steady.load_document'
      ? switch (phaseRun.repeat) {
          1 => 1,
          2 => 5,
          3 => 3,
          4 => 2,
          5 => 4,
          _ => offset,
        }
      : offset;
  final rasterMillis = buildMillis + 1;
  return {
    'traceEvents': [
      {'name': 'Frame', 'ph': 'B', 'ts': 0, 'pid': 1, 'tid': 1},
      {
        'name': 'Frame',
        'ph': 'E',
        'ts': buildMillis * 1000,
        'pid': 1,
        'tid': 1,
      },
      {'name': 'GPURasterizer::Draw', 'ph': 'B', 'ts': 0, 'pid': 1, 'tid': 2},
      {
        'name': 'GPURasterizer::Draw',
        'ph': 'E',
        'ts': rasterMillis * 1000,
        'pid': 1,
        'tid': 2,
      },
    ],
  };
}

Map<String, dynamic> _readJsonObject(File file) {
  final value = jsonDecode(file.readAsStringSync());
  expect(value, isA<Map<String, dynamic>>(), reason: file.path);
  return value as Map<String, dynamic>;
}

Map<String, Map<String, dynamic>> _groupsById(Map<String, dynamic> jsonObject) {
  final groups = jsonObject['scenarioGroups'] as List<dynamic>;
  return {
    for (final group in groups.cast<Map<String, dynamic>>())
      group['id'] as String: group,
  };
}

void _expectRedesignedWarmAndSteadyManifest(
  Map<String, Map<String, dynamic>> groups,
) {
  final group = groups['load_document.100k']!;
  expect(group.keys.toSet(), {'id', 'migration', 'phases'});
  expect(group['migration'], 'redesigned');
  final phases = _phasesByKey(group);
  final steady = phases['steady.load_document']!;
  final warm = phases['warm.load_document']!;
  expect(steady.keys.toSet(), {
    'kind',
    'name',
    'comparisonRole',
    'repeats',
  });
  expect(steady['comparisonRole'], 'steady_action');
  expect((steady['repeats'] as List<dynamic>), hasLength(5));
  expect((warm['repeats'] as List<dynamic>), hasLength(1));

  for (final repeat in [
    ...(warm['repeats'] as List<dynamic>),
    ...(steady['repeats'] as List<dynamic>),
  ].cast<Map<String, dynamic>>()) {
    expect(repeat.keys.toSet(), {
      'repeat',
      'reportKey',
      'artifactDirectory',
      'timelineFile',
      'timelineSummaryFile',
      'canonicalPreparation',
      'resetReason',
      'measuredAction',
      'preparationMeasured',
    });
    expect(
      repeat['canonicalPreparation'],
      'empty_runtime_with_prepared_json_fixture',
    );
    expect(repeat['resetReason'], 'load_writes_document_state');
    expect(repeat['measuredAction'], 'load_document');
    expect(repeat['preparationMeasured'], false);
  }
}

void _expectSingleCurrentBehaviorManifest(
  Map<String, Map<String, dynamic>> groups,
) {
  final group = groups['selection_tap.10k']!;
  expect(group['migration'], 'single.current_behavior');
  final phase = _phasesByKey(group)['single.current_behavior']!;
  expect(phase['comparisonRole'], 'current_behavior');
  final repeats = (phase['repeats'] as List<dynamic>)
      .cast<Map<String, dynamic>>();
  expect(repeats, hasLength(1));
  expect(repeats.single.keys.toSet(), {
    'repeat',
    'reportKey',
    'artifactDirectory',
    'timelineFile',
    'timelineSummaryFile',
  });
}

void _expectNestedArtifacts(
  Directory outputRoot,
  Map<String, Map<String, dynamic>> groups,
) {
  for (final group in groups.values) {
    for (final phase in (group['phases'] as List<dynamic>)
        .cast<Map<String, dynamic>>()) {
      for (final repeat in (phase['repeats'] as List<dynamic>)
          .cast<Map<String, dynamic>>()) {
        final artifactDirectory = Directory(
          '${outputRoot.path}/${repeat['artifactDirectory']}',
        );
        expect(artifactDirectory.existsSync(), isTrue);
        final reportKey = repeat['reportKey'] as String;
        expect(
          File('${artifactDirectory.path}/$reportKey.timeline.json').existsSync(),
          isTrue,
        );
        expect(
          File('${artifactDirectory.path}/$reportKey.timeline_summary.json')
              .existsSync(),
          isTrue,
        );
        expect(repeat['timelineFile'], '$reportKey.timeline.json');
        expect(repeat['timelineSummaryFile'], '$reportKey.timeline_summary.json');
      }
    }
  }
}

void _expectComparisonSummary(
  Map<String, Map<String, dynamic>> groups,
  Directory outputRoot,
) {
  final group = groups['load_document.100k']!;
  expect(group.keys.toSet(), {'id', 'phases'});
  final steady = _phasesByKey(group)['steady.load_document']!;
  expect(steady.keys.toSet(), {
    'kind',
    'name',
    'repeatCount',
    'metrics',
  });
  expect(steady['repeatCount'], 5);

  final metrics = {
    for (final metric in (steady['metrics'] as List<dynamic>)
        .cast<Map<String, dynamic>>())
      metric['summaryField'] as String: metric,
  };
  expect(metrics.keys.toSet(), _comparisonSummaryFields);

  final averageBuild = metrics['average_frame_build_time_millis']!;
  expect(averageBuild.keys.toSet(), {
    'summaryField',
    'unit',
    'rawRepeats',
    'median',
    'min',
    'max',
    'interquartileRange',
  });
  expect(averageBuild['unit'], 'millis');
  expect(averageBuild['rawRepeats'], [
    {'repeat': 1, 'value': 1.0},
    {'repeat': 2, 'value': 5.0},
    {'repeat': 3, 'value': 3.0},
    {'repeat': 4, 'value': 2.0},
    {'repeat': 5, 'value': 4.0},
  ]);
  expect(averageBuild['median'], 3.0);
  expect(averageBuild['min'], 1.0);
  expect(averageBuild['max'], 5.0);
  expect(averageBuild['interquartileRange'], 3.0);

  final frameCount = metrics['frame_count']!;
  expect(frameCount['unit'], 'count');
  expect(frameCount['rawRepeats'], [
    {'repeat': 1, 'value': 1},
    {'repeat': 2, 'value': 1},
    {'repeat': 3, 'value': 1},
    {'repeat': 4, 'value': 1},
    {'repeat': 5, 'value': 1},
  ]);
  _expectMetricMatchesSummaryFiles(
    metric: averageBuild,
    outputRoot: outputRoot,
    scenarioGroup: 'load_document.100k',
    phaseKey: 'steady.load_document',
  );
}

void _expectMetricMatchesSummaryFiles({
  required Map<String, dynamic> metric,
  required Directory outputRoot,
  required String scenarioGroup,
  required String phaseKey,
}) {
  final summaryField = metric['summaryField'] as String;
  final expectedRawRepeats = <Map<String, Object?>>[];
  for (final rawRepeat in (metric['rawRepeats'] as List<dynamic>)
      .cast<Map<String, dynamic>>()) {
    final repeat = rawRepeat['repeat'] as int;
    final phaseParts = phaseKey.split('.');
    final reportKey = performanceReportKey(
      scenarioGroup: scenarioGroup,
      phaseKind: phaseParts.first,
      phaseName: phaseParts.last,
      repeat: repeat,
    );
    final summary = _readJsonObject(
      File(
        '${outputRoot.path}/$scenarioGroup/$phaseKey/'
        'repeat_${repeat.toString().padLeft(3, '0')}/'
        '$reportKey.timeline_summary.json',
      ),
    );
    expectedRawRepeats.add({
      'repeat': repeat,
      'value': summary[summaryField],
    });
  }
  expect(metric['rawRepeats'], expectedRawRepeats);
}

Map<String, Map<String, dynamic>> _phasesByKey(Map<String, dynamic> group) {
  final phases = group['phases'] as List<dynamic>;
  return {
    for (final phase in phases.cast<Map<String, dynamic>>())
      '${phase['kind']}.${phase['name']}': phase,
  };
}

bool _containsForbiddenKey(Object? value) {
  if (value is Map) {
    for (final entry in value.entries) {
      if (_forbiddenKeys.contains(entry.key)) {
        return true;
      }
      if (_containsForbiddenKey(entry.value)) {
        return true;
      }
    }
  }
  if (value is Iterable) {
    return value.any(_containsForbiddenKey);
  }
  return false;
}
''';
}
