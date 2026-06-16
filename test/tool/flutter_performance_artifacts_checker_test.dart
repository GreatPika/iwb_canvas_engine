import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

import '../../tool/check_flutter_performance_artifacts.dart';

void main() {
  _registerAcceptsExactArtifactsTest();
  _registerRejectsInvalidArtifactsTest();
}

void _registerAcceptsExactArtifactsTest() {
  test(
    'accepts exact Flutter timeline artifacts for catalog scenarios',
    () async {
      final root = await Directory.systemTemp.createTemp('perf_artifacts_ok_');
      addTearDown(() => root.delete(recursive: true));

      _writeCatalog(root, ['load_document.1k', 'camera_pan.50k']);
      _writeScenarioArtifacts(root, 'load_document.1k');
      _writeScenarioArtifacts(root, 'camera_pan.50k');

      final result = await runFlutterPerformanceArtifactsCheck([
        '--catalog',
        'performance.md',
        '--results',
        'results',
      ], root: root);

      expect(result.exitCode, 0, reason: result.stderr);
      expect(
        result.stdout,
        contains('verified 2 Flutter performance scenario'),
      );
    },
  );
}

void _registerRejectsInvalidArtifactsTest() {
  test('rejects missing, malformed, and unexpected artifacts', () async {
    final root = await Directory.systemTemp.createTemp('perf_artifacts_bad_');
    addTearDown(() => root.delete(recursive: true));

    _writeInvalidArtifactSet(root);

    final result = await runFlutterPerformanceArtifactsCheck([
      '--catalog=performance.md',
      '--results=results',
    ], root: root);

    expect(result.exitCode, 1);
    expect(result.stderr, contains('unexpected scenario directory'));
    expect(result.stderr, contains('created_by_checker.json'));
    expect(result.stderr, contains('missing artifact for camera_pan.50k'));
    expect(result.stderr, contains('malformed timeline JSON'));
    expect(result.stderr, contains('average_frame_build_time_millis'));
  });
}

void _writeInvalidArtifactSet(Directory root) {
  _writeCatalog(root, ['load_document.1k', 'camera_pan.50k']);
  _writeScenarioArtifacts(root, 'load_document.1k');
  _writeScenarioArtifacts(root, 'extra_scenario');
  File(
    '${root.path}/results/load_document.1k/'
    'load_document.1k.timeline_summary.json',
  ).writeAsStringSync(jsonEncode({'not_a_timeline_summary': true}));
  File('${root.path}/results/load_document.1k/created_by_checker.json')
    ..createSync()
    ..writeAsStringSync('{}');
  Directory('${root.path}/results/camera_pan.50k').createSync(recursive: true);
  File(
      '${root.path}/results/camera_pan.50k/'
      'camera_pan.50k.timeline.json',
    )
    ..createSync()
    ..writeAsStringSync('{not json');
}

void _writeCatalog(Directory root, List<String> scenarioIds) {
  final rows = scenarioIds.map((id) => '| `$id` | required |').join('\n');
  File('${root.path}/performance.md').writeAsStringSync('''
| Scenario id | Release gate status |
|---|---|
$rows
''');
}

void _writeScenarioArtifacts(Directory root, String scenarioId) {
  final directory = Directory('${root.path}/results/$scenarioId')
    ..createSync(recursive: true);
  File(
    '${directory.path}/$scenarioId.timeline_summary.json',
  ).writeAsStringSync(jsonEncode(_representativeTimelineSummaryJson()));
  File('${directory.path}/$scenarioId.timeline.json').writeAsStringSync(
    jsonEncode({
      'traceEvents': [
        {'name': 'frame', 'ph': 'X', 'ts': 1, 'pid': 1, 'tid': 1},
      ],
    }),
  );
}

Map<String, Object?> _representativeTimelineSummaryJson() {
  return {
    for (final key in _representativeTimelineSummaryNumberKeys) key: 1,
    'frame_build_times': [1000],
    'frame_rasterizer_times': [1000],
    'frame_begin_times': [0],
    'frame_rasterizer_begin_times': [0],
  };
}

const _representativeTimelineSummaryNumberKeys = [
  'average_frame_build_time_millis',
  '90th_percentile_frame_build_time_millis',
  '99th_percentile_frame_build_time_millis',
  'worst_frame_build_time_millis',
  'missed_frame_build_budget_count',
  'average_frame_rasterizer_time_millis',
  'stddev_frame_rasterizer_time_millis',
  '90th_percentile_frame_rasterizer_time_millis',
  '99th_percentile_frame_rasterizer_time_millis',
  'worst_frame_rasterizer_time_millis',
  'missed_frame_rasterizer_budget_count',
  'frame_count',
  'frame_rasterizer_count',
  'new_gen_gc_count',
  'old_gen_gc_count',
  'average_vsync_transitions_missed',
  '90th_percentile_vsync_transitions_missed',
  '99th_percentile_vsync_transitions_missed',
  'average_vsync_frame_lag',
  '90th_percentile_vsync_frame_lag',
  '99th_percentile_vsync_frame_lag',
  'average_layer_cache_count',
  '90th_percentile_layer_cache_count',
  '99th_percentile_layer_cache_count',
  'average_frame_request_pending_latency',
  '90th_percentile_frame_request_pending_latency',
  '99th_percentile_frame_request_pending_latency',
  'worst_layer_cache_count',
  'average_layer_cache_memory',
  '90th_percentile_layer_cache_memory',
  '99th_percentile_layer_cache_memory',
  'worst_layer_cache_memory',
  'average_picture_cache_count',
  '90th_percentile_picture_cache_count',
  '99th_percentile_picture_cache_count',
  'worst_picture_cache_count',
  'average_picture_cache_memory',
  '90th_percentile_picture_cache_memory',
  '99th_percentile_picture_cache_memory',
  'worst_picture_cache_memory',
  'total_ui_gc_time',
  '30hz_frame_percentage',
  '60hz_frame_percentage',
  '80hz_frame_percentage',
  '90hz_frame_percentage',
  '120hz_frame_percentage',
  'illegal_refresh_rate_frame_count',
  'average_gpu_frame_time',
  '90th_percentile_gpu_frame_time',
  '99th_percentile_gpu_frame_time',
  'worst_gpu_frame_time',
  'average_gpu_memory_mb',
  '90th_percentile_gpu_memory_mb',
  '99th_percentile_gpu_memory_mb',
  'worst_gpu_memory_mb',
];
