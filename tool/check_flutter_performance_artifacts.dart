import 'dart:convert';
import 'dart:io';

import 'src/tool_command_result.dart';

const _timelineSummaryListKeys = {
  'frame_build_times',
  'frame_rasterizer_times',
  'frame_begin_times',
  'frame_rasterizer_begin_times',
};

const _timelineSummaryNumberKeys = {
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
};

const _timelineSummaryNumberKeySet = _TimelineSummaryKeySet(
  keys: _timelineSummaryNumberKeys,
  expectedType: 'number',
  isValidValue: _isJsonNumber,
);

const _timelineSummaryListKeySet = _TimelineSummaryKeySet(
  keys: _timelineSummaryListKeys,
  expectedType: 'list',
  isValidValue: _isJsonList,
);

Future<ToolCommandResult> runFlutterPerformanceArtifactsCheck(
  List<String> args, {
  Directory? root,
}) async {
  final invocation = _readInvocation(args, root ?? Directory.current);
  if (invocation case _InvalidInvocation(:final result)) {
    return result;
  }
  final validInvocation = invocation as _ValidInvocation;

  final scenarioIds = _readScenarioIds(validInvocation.catalogFile);
  final failures = _collectArtifactFailures(
    validInvocation.resultsDirectory,
    scenarioIds,
  );

  return _renderArtifactCheckResult(scenarioIds, failures);
}

ToolCommandResult _renderArtifactCheckResult(
  List<String> scenarioIds,
  List<String> failures,
) {
  if (failures.isNotEmpty) {
    return ToolCommandResult(
      exitCode: 1,
      stderr:
          'FAIL: invalid Flutter performance artifacts:\n'
          '${failures.map((failure) => '- $failure').join('\n')}\n',
    );
  }

  return ToolCommandResult(
    exitCode: 0,
    stdout:
        'OK: verified ${scenarioIds.length} Flutter performance scenario '
        'artifact sets.\n',
  );
}

_Invocation _readInvocation(List<String> args, Directory root) {
  final catalogPath = _parseStringFlag(args, '--catalog');
  final resultsPath = _parseStringFlag(args, '--results');
  if (catalogPath == null || resultsPath == null) {
    return const _InvalidInvocation(
      ToolCommandResult(
        exitCode: 1,
        stderr:
            'Usage: dart run tool/check_flutter_performance_artifacts.dart '
            '--catalog <markdown> --results <directory>\n',
      ),
    );
  }

  final catalogFile = _resolveFile(root, catalogPath);
  if (!catalogFile.existsSync()) {
    return _InvalidInvocation(
      ToolCommandResult(
        exitCode: 1,
        stderr: 'FAIL: performance catalog not found: ${catalogFile.path}\n',
      ),
    );
  }

  final resultsDirectory = _resolveDirectory(root, resultsPath);
  if (!resultsDirectory.existsSync()) {
    return _InvalidInvocation(
      ToolCommandResult(
        exitCode: 1,
        stderr:
            'FAIL: performance results directory not found: '
            '${resultsDirectory.path}\n',
      ),
    );
  }

  return _ValidInvocation(
    catalogFile: catalogFile,
    resultsDirectory: resultsDirectory,
  );
}

List<String> _collectArtifactFailures(
  Directory resultsDirectory,
  List<String> scenarioIds,
) {
  final failures = <String>[
    if (scenarioIds.isEmpty)
      'catalog does not contain any required scenario ids',
  ];
  final expectedIds = scenarioIds.toSet();
  final entries = resultsDirectory.listSync(followLinks: false);

  _checkResultsRoot(entries, expectedIds: expectedIds, failures: failures);
  _checkExpectedScenarioDirectories(
    resultsDirectory,
    expectedIds: expectedIds,
    failures: failures,
  );

  return failures;
}

void _checkResultsRoot(
  List<FileSystemEntity> entries, {
  required Set<String> expectedIds,
  required List<String> failures,
}) {
  for (final file in entries.whereType<File>()) {
    failures.add('unexpected file in results directory: ${file.path}');
  }

  final actualIds = entries.whereType<Directory>().map(_basename).toSet();
  for (final missingId in _sorted(expectedIds.difference(actualIds))) {
    failures.add('missing scenario directory: $missingId');
  }
  for (final extraId in _sorted(actualIds.difference(expectedIds))) {
    failures.add('unexpected scenario directory: $extraId');
  }
}

void _checkExpectedScenarioDirectories(
  Directory resultsDirectory, {
  required Set<String> expectedIds,
  required List<String> failures,
}) {
  for (final scenarioId in _sorted(expectedIds)) {
    final scenarioDirectory = Directory(
      '${resultsDirectory.path}${Platform.pathSeparator}$scenarioId',
    );
    if (scenarioDirectory.existsSync()) {
      _checkScenarioDirectory(
        scenarioDirectory,
        scenarioId: scenarioId,
        failures: failures,
      );
    }
  }
}

Future<void> main(List<String> args) async {
  final result = await runFlutterPerformanceArtifactsCheck(args);
  writeToolCommandResult(result);
  exitCode = result.exitCode;
}

sealed class _Invocation {
  const _Invocation();
}

final class _ValidInvocation extends _Invocation {
  const _ValidInvocation({
    required this.catalogFile,
    required this.resultsDirectory,
  });

  final File catalogFile;
  final Directory resultsDirectory;
}

final class _InvalidInvocation extends _Invocation {
  const _InvalidInvocation(this.result);

  final ToolCommandResult result;
}

List<String> _readScenarioIds(File catalogFile) {
  final ids = <String>[];
  final rowPattern = RegExp(r'^\| `([^`]+)` \| required(?:[^|]*)\|$');
  for (final line in catalogFile.readAsLinesSync()) {
    final match = rowPattern.firstMatch(line.trim());
    final scenarioId = match?.group(1);
    if (scenarioId != null) {
      ids.add(scenarioId);
    }
  }

  return ids;
}

void _checkScenarioDirectory(
  Directory scenarioDirectory, {
  required String scenarioId,
  required List<String> failures,
}) {
  final expectedFiles = {
    '$scenarioId.timeline.json',
    '$scenarioId.timeline_summary.json',
  };
  final entries = scenarioDirectory.listSync(followLinks: false);
  for (final directory in entries.whereType<Directory>()) {
    failures.add('unexpected nested directory: ${directory.path}');
  }

  final fileNames = entries.whereType<File>().map(_basename).toSet();
  for (final missingFile in _sorted(expectedFiles.difference(fileNames))) {
    failures.add('missing artifact for $scenarioId: $missingFile');
  }
  for (final extraFile in _sorted(fileNames.difference(expectedFiles))) {
    failures.add('unexpected artifact for $scenarioId: $extraFile');
  }

  _checkJsonObject(
    File(
      '${scenarioDirectory.path}${Platform.pathSeparator}'
      '$scenarioId.timeline_summary.json',
    ),
    description: 'TimelineSummary JSON for $scenarioId',
    expectedShape: _ExpectedJsonShape.timelineSummary,
    failures: failures,
  );
  _checkJsonObject(
    File(
      '${scenarioDirectory.path}${Platform.pathSeparator}'
      '$scenarioId.timeline.json',
    ),
    description: 'timeline JSON for $scenarioId',
    expectedShape: _ExpectedJsonShape.timeline,
    failures: failures,
  );
}

void _checkJsonObject(
  File file, {
  required String description,
  required _ExpectedJsonShape expectedShape,
  required List<String> failures,
}) {
  if (!file.existsSync()) {
    return;
  }

  Object? decoded;
  try {
    decoded = jsonDecode(file.readAsStringSync());
  } on FormatException catch (error) {
    failures.add('malformed $description: ${file.path}: ${error.message}');
    return;
  }

  if (decoded is! Map<String, Object?>) {
    failures.add('$description is not a JSON object: ${file.path}');
    return;
  }

  final context = _JsonArtifactCheck(
    description: description,
    file: file,
    failures: failures,
  );
  switch (expectedShape) {
    case _ExpectedJsonShape.timeline:
      _checkTimelineJson(decoded, context);
    case _ExpectedJsonShape.timelineSummary:
      _checkTimelineSummaryJson(decoded, context);
  }
}

void _checkTimelineJson(Map<String, Object?> json, _JsonArtifactCheck context) {
  if (json['traceEvents'] is! List<Object?>) {
    context.failures.add(
      '${context.description} is missing traceEvents: ${context.file.path}',
    );
  }
}

void _checkTimelineSummaryJson(
  Map<String, Object?> json,
  _JsonArtifactCheck context,
) {
  _checkTimelineSummaryKeys(json, _timelineSummaryNumberKeySet, context);
  _checkTimelineSummaryKeys(json, _timelineSummaryListKeySet, context);
}

void _checkTimelineSummaryKeys(
  Map<String, Object?> json,
  _TimelineSummaryKeySet keySet,
  _JsonArtifactCheck context,
) {
  for (final key in _sorted(keySet.keys)) {
    if (!json.containsKey(key)) {
      context.failures.add(
        '${context.description} is missing $key: ${context.file.path}',
      );
    } else if (!keySet.isValidValue(json[key])) {
      context.failures.add(
        '${context.description} field $key is not a JSON '
        '${keySet.expectedType}: ${context.file.path}',
      );
    }
  }
}

File _resolveFile(Directory root, String path) {
  if (path.startsWith('/')) {
    return File(path);
  }

  return File('${root.path}${Platform.pathSeparator}$path');
}

Directory _resolveDirectory(Directory root, String path) {
  if (path.startsWith('/')) {
    return Directory(path);
  }

  return Directory('${root.path}${Platform.pathSeparator}$path');
}

String? _parseStringFlag(List<String> args, String flag) {
  for (var index = 0; index < args.length; index += 1) {
    final arg = args[index];
    if (arg == flag && index + 1 < args.length) {
      return args[index + 1];
    }
    final prefix = '$flag=';
    if (arg.startsWith(prefix)) {
      return arg.replaceFirst(prefix, '');
    }
  }

  return null;
}

String _basename(FileSystemEntity entity) {
  return entity.uri.pathSegments.where((segment) => segment.isNotEmpty).last;
}

List<String> _sorted(Iterable<String> values) {
  return values.toList()..sort();
}

enum _ExpectedJsonShape { timeline, timelineSummary }

final class _TimelineSummaryKeySet {
  const _TimelineSummaryKeySet({
    required this.keys,
    required this.expectedType,
    required this.isValidValue,
  });

  final Set<String> keys;
  final String expectedType;
  final bool Function(Object? value) isValidValue;
}

final class _JsonArtifactCheck {
  const _JsonArtifactCheck({
    required this.description,
    required this.file,
    required this.failures,
  });

  final String description;
  final File file;
  final List<String> failures;
}

bool _isJsonNumber(Object? value) {
  return value is num;
}

bool _isJsonList(Object? value) {
  return value is List<Object?>;
}
