import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_driver/flutter_driver.dart';
import 'package:iwb_canvas_engine_example/perf/performance_scenario_catalog.dart'
    as catalog;
import 'package:integration_test/integration_test_driver.dart';

Future<void> main() {
  return integrationDriver(responseDataCallback: writePerformanceTimelines);
}

const _comparisonSummaryFields = [
  'average_frame_build_time_millis',
  'worst_frame_build_time_millis',
  'average_frame_rasterizer_time_millis',
  'worst_frame_rasterizer_time_millis',
  'frame_count',
  'missed_frame_build_budget_count',
  'missed_frame_rasterizer_budget_count',
];

Future<void> writePerformanceTimelines(
  Map<String, dynamic>? data, {
  Directory? resultsDirectory,
}) async {
  if (data == null) {
    throw StateError('Performance profile run returned no response data.');
  }

  final phaseRuns = _performanceReportPhaseRuns(data);
  if (phaseRuns.isEmpty) {
    throw StateError('Performance profile run returned no scenario timelines.');
  }

  final outputRoot = resultsDirectory ?? Directory('build/flutter_performance');
  _resetResultsDirectory(outputRoot);

  for (final phaseRun in phaseRuns) {
    await _writePhaseRunTimeline(data, phaseRun, resultsDirectory: outputRoot);
  }
  await _writeRunManifest(outputRoot);
  await _writeComparisonSummary(outputRoot);
}

List<catalog.PerformanceScenarioCatalogRun> _performanceReportPhaseRuns(
  Map<String, dynamic> data,
) {
  final phaseRunsByReportKey = {
    for (final phaseRun in catalog.performanceScenarioCatalogRuns)
      phaseRun.reportKey: phaseRun,
  };
  final actualReportKeys = data.keys.toSet();
  final expectedReportKeys = phaseRunsByReportKey.keys.toSet();
  final missingReportKeys =
      expectedReportKeys.difference(actualReportKeys).toList()..sort();
  final unexpectedReportKeys =
      actualReportKeys.difference(expectedReportKeys).toList()..sort();
  if (missingReportKeys.isNotEmpty || unexpectedReportKeys.isNotEmpty) {
    throw StateError(
      'Performance profile report keys did not match the executable catalog. '
      'Missing: $missingReportKeys. Unexpected: $unexpectedReportKeys.',
    );
  }

  return List<catalog.PerformanceScenarioCatalogRun>.unmodifiable(
    catalog.performanceScenarioCatalogRuns,
  );
}

void _resetResultsDirectory(Directory resultsDirectory) {
  if (resultsDirectory.existsSync()) {
    resultsDirectory.deleteSync(recursive: true);
  }
}

Future<void> _writePhaseRunTimeline(
  Map<String, dynamic> data,
  catalog.PerformanceScenarioCatalogRun phaseRun, {
  required Directory resultsDirectory,
}) async {
  final reportKey = phaseRun.reportKey;
  final timelineData = data[reportKey];
  if (timelineData is! Map<String, dynamic>) {
    throw StateError(
      'Performance profile report $reportKey did not contain timeline JSON.',
    );
  }

  final repeatDirectory = Directory(
    _joinPath(resultsDirectory.path, _artifactDirectory(phaseRun)),
  );
  final timeline = Timeline.fromJson(timelineData);
  final summary = TimelineSummary.summarize(timeline);
  await summary.writeTimelineToFile(
    reportKey,
    destinationDirectory: repeatDirectory.path,
    includeSummary: true,
  );
}

Future<void> _writeRunManifest(Directory resultsDirectory) {
  return _writeGeneratedJson(
    File(_joinPath(resultsDirectory.path, 'performance_run_manifest.json')),
    _runManifest(),
  );
}

Map<String, Object?> _runManifest() {
  return {
    'schemaVersion': 1,
    'route': {
      'name': 'flutter_performance',
      'commandFamily': 'flutter drive --profile --no-dds',
      'driver': 'test_driver/perf_driver.dart',
      'target': 'integration_test/perf_canvas_surface_test.dart',
    },
    'unsupportedClaims': {
      'numericThresholds': false,
      'passFailPerformance': false,
      'baselines': false,
      'regressionStatusClaims': false,
      'cpuAttribution': false,
      'startup': false,
      'androidMacrobenchmark': false,
    },
    'scenarioGroups': [
      for (final group in catalog.performanceScenarioCatalogGroups)
        {
          'id': group.id,
          'migration': group.migration,
          'phases': [
            for (final phase in group.phases)
              {
                'kind': phase.kind,
                'name': phase.name,
                'comparisonRole': phase.comparisonRole,
                'repeats': [
                  for (final phaseRun in _phaseRunsFor(group, phase))
                    _manifestRepeat(phaseRun),
                ],
              },
          ],
        },
    ],
  };
}

Map<String, Object?> _manifestRepeat(
  catalog.PerformanceScenarioCatalogRun phaseRun,
) {
  final phase = phaseRun.phase;
  final reportKey = phaseRun.reportKey;
  final repeat = <String, Object?>{
    'repeat': phaseRun.repeat,
    'reportKey': reportKey,
    'artifactDirectory': _artifactDirectory(phaseRun, pathSeparator: '/'),
    'timelineFile': '$reportKey.timeline.json',
    'timelineSummaryFile': '$reportKey.timeline_summary.json',
  };
  if (phase.kind == 'warm' || phase.kind == 'steady') {
    final metadata = _requiredPreparationMetadata(phaseRun);
    repeat.addAll({
      'canonicalPreparation': metadata.canonicalPreparation,
      'resetReason': metadata.resetReason,
      'measuredAction': metadata.measuredAction,
      'preparationMeasured': false,
    });
  }
  return repeat;
}

({String canonicalPreparation, String resetReason, String measuredAction})
_requiredPreparationMetadata(catalog.PerformanceScenarioCatalogRun phaseRun) {
  final phase = phaseRun.phase;
  final canonicalPreparation = phase.canonicalPreparation;
  final resetReason = phase.resetReason;
  final measuredAction = phase.measuredAction;
  if (canonicalPreparation == null ||
      resetReason == null ||
      measuredAction == null) {
    throw StateError(
      '${phaseRun.reportKey} must declare preparation metadata.',
    );
  }
  return (
    canonicalPreparation: canonicalPreparation,
    resetReason: resetReason,
    measuredAction: measuredAction,
  );
}

Future<void> _writeComparisonSummary(Directory resultsDirectory) async {
  final scenarioGroups = <Map<String, Object?>>[];
  for (final group in catalog.performanceScenarioCatalogGroups) {
    scenarioGroups.add({
      'id': group.id,
      'phases': [
        for (final phase in group.phases)
          {
            'kind': phase.kind,
            'name': phase.name,
            'repeatCount': phase.repeats,
            'metrics': [
              for (final field in _comparisonSummaryFields)
                _comparisonMetric(
                  field,
                  await _rawRepeatsFor(
                    resultsDirectory: resultsDirectory,
                    group: group,
                    phase: phase,
                    summaryField: field,
                  ),
                ),
            ],
          },
      ],
    });
  }
  await _writeGeneratedJson(
    File(_joinPath(resultsDirectory.path, 'comparison_summary.json')),
    {
      'schemaVersion': 1,
      'sourceManifest': 'performance_run_manifest.json',
      'routeName': 'flutter_performance',
      'commandFamily': 'flutter drive --profile --no-dds',
      'scenarioGroups': scenarioGroups,
    },
  );
}

Future<List<_RawRepeat>> _rawRepeatsFor({
  required Directory resultsDirectory,
  required catalog.PerformanceScenarioCatalogGroup group,
  required catalog.PerformanceScenarioCatalogPhase phase,
  required String summaryField,
}) async {
  final rawRepeats = <_RawRepeat>[];
  for (final phaseRun in _phaseRunsFor(group, phase)) {
    final summaryFile = File(
      _joinPath(
        resultsDirectory.path,
        _artifactDirectory(phaseRun),
        '${phaseRun.reportKey}.timeline_summary.json',
      ),
    );
    final summaryJson = jsonDecode(await summaryFile.readAsString());
    if (summaryJson is! Map<String, dynamic>) {
      throw StateError('${summaryFile.path} did not contain a JSON object.');
    }
    final value = summaryJson[summaryField];
    if (value is! num) {
      throw StateError('${summaryFile.path} did not contain $summaryField.');
    }
    rawRepeats.add(_RawRepeat(repeat: phaseRun.repeat, value: value));
  }
  return rawRepeats;
}

Map<String, Object?> _comparisonMetric(
  String summaryField,
  List<_RawRepeat> rawRepeats,
) {
  final values = rawRepeats.map((repeat) => repeat.value).toList()..sort();
  final q1q3 = _quartiles(values);
  return {
    'summaryField': summaryField,
    'unit': summaryField.endsWith('_millis') ? 'millis' : 'count',
    'rawRepeats': [
      for (final repeat in rawRepeats)
        {'repeat': repeat.repeat, 'value': repeat.value},
    ],
    'median': _median(values),
    'min': values.first,
    'max': values.last,
    'interquartileRange': q1q3.q3 - q1q3.q1,
  };
}

({num q1, num q3}) _quartiles(List<num> sortedValues) {
  if (sortedValues.length == 1) {
    return (q1: sortedValues.single, q3: sortedValues.single);
  }
  if (sortedValues.length == 2) {
    return (q1: sortedValues.first, q3: sortedValues.last);
  }
  final midpoint = sortedValues.length ~/ 2;
  final lowerHalf = sortedValues.sublist(0, midpoint);
  final upperHalf = sortedValues.length.isOdd
      ? sortedValues.sublist(midpoint + 1)
      : sortedValues.sublist(midpoint);
  return (q1: _median(lowerHalf), q3: _median(upperHalf));
}

num _median(List<num> sortedValues) {
  final midpoint = sortedValues.length ~/ 2;
  if (sortedValues.length.isOdd) {
    return sortedValues[midpoint];
  }
  return (sortedValues[midpoint - 1] + sortedValues[midpoint]) / 2;
}

Iterable<catalog.PerformanceScenarioCatalogRun> _phaseRunsFor(
  catalog.PerformanceScenarioCatalogGroup group,
  catalog.PerformanceScenarioCatalogPhase phase,
) sync* {
  for (final phaseRun in catalog.performanceScenarioCatalogRuns) {
    if (phaseRun.scenarioGroup == group && phaseRun.phase == phase) {
      yield phaseRun;
    }
  }
}

Future<void> _writeGeneratedJson(
  File file,
  Map<String, Object?> jsonObject,
) async {
  await file.parent.create(recursive: true);
  await file.writeAsString(
    const JsonEncoder.withIndent('  ').convert(jsonObject),
  );
}

String _artifactDirectory(
  catalog.PerformanceScenarioCatalogRun phaseRun, {
  String? pathSeparator,
}) {
  final separator = pathSeparator ?? Platform.pathSeparator;
  return [
    phaseRun.scenarioGroupId,
    phaseRun.phaseKey,
    'repeat_${phaseRun.repeat.toString().padLeft(3, '0')}',
  ].join(separator);
}

String _joinPath(String part, String other, [String? third]) {
  final parts = [part, other, ?third];
  return parts.join(Platform.pathSeparator);
}

final class _RawRepeat {
  const _RawRepeat({required this.repeat, required this.value});

  final int repeat;
  final num value;
}
