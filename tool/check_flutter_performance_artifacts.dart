import 'dart:convert';
import 'dart:io';

// The checker runs from the root package, while the benchmark route catalog is
// owned by the example package that executes the profile drive route.
// ignore: avoid_relative_lib_imports
import '../example/lib/perf/performance_scenario_catalog.dart' as catalog;
import 'src/tool_command_result.dart';

const _manifestFileName = 'performance_run_manifest.json';
const _comparisonSummaryFileName = 'comparison_summary.json';

const _route = {
  'name': 'flutter_performance',
  'commandFamily': 'flutter drive --profile --no-dds',
  'driver': 'test_driver/perf_driver.dart',
  'target': 'integration_test/perf_canvas_surface_test.dart',
};

const _unsupportedClaims = {
  'numericThresholds': false,
  'passFailPerformance': false,
  'baselines': false,
  'regressionStatusClaims': false,
  'cpuAttribution': false,
  'startup': false,
  'androidMacrobenchmark': false,
};

const _manifestTopLevelKeys = {
  'schemaVersion',
  'route',
  'unsupportedClaims',
  'scenarioGroups',
};
const _manifestGroupKeys = {'id', 'migration', 'phases'};
const _manifestPhaseKeys = {'kind', 'name', 'comparisonRole', 'repeats'};
const _manifestBasicRepeatKeys = {
  'repeat',
  'reportKey',
  'artifactDirectory',
  'timelineFile',
  'timelineSummaryFile',
};
const _manifestPreparedRepeatKeys = {
  ..._manifestBasicRepeatKeys,
  'canonicalPreparation',
  'resetReason',
  'measuredAction',
  'preparationMeasured',
};

const _comparisonTopLevelKeys = {
  'schemaVersion',
  'sourceManifest',
  'routeName',
  'commandFamily',
  'scenarioGroups',
};
const _comparisonGroupKeys = {'id', 'phases'};
const _comparisonPhaseKeys = {'kind', 'name', 'repeatCount', 'metrics'};
const _comparisonMetricKeys = {
  'summaryField',
  'unit',
  'rawRepeats',
  'median',
  'min',
  'max',
  'interquartileRange',
};
const _comparisonRawRepeatKeys = {'repeat', 'value'};
const _comparisonSummaryFields = {
  'average_frame_build_time_millis',
  'worst_frame_build_time_millis',
  'average_frame_rasterizer_time_millis',
  'worst_frame_rasterizer_time_millis',
  'frame_count',
  'missed_frame_build_budget_count',
  'missed_frame_rasterizer_budget_count',
};

const _phaseKinds = {'setup', 'warm', 'steady', 'single'};
const _comparisonRoles = {
  'setup_context',
  'first_use_action',
  'steady_action',
  'current_behavior',
};
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

final _reportKeyPattern = RegExp(
  r'^[a-z0-9_.]+__[a-z]+\.[a-z0-9_]+__repeat_\d{3}$',
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

  final failures = <String>[];
  final scenarioGroupCount = _collectArtifactFailures(
    validInvocation.resultsDirectory,
    failures,
  );

  return _renderArtifactCheckResult(scenarioGroupCount, failures);
}

ToolCommandResult _renderArtifactCheckResult(
  int scenarioGroupCount,
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
        'OK: verified $scenarioGroupCount Flutter performance scenario '
        'groups.\n',
  );
}

_Invocation _readInvocation(List<String> args, Directory root) {
  if (_parseStringFlag(args, '--catalog') != null) {
    return _unsupportedCatalogInvocation();
  }

  final resultsPath = _parseStringFlag(args, '--results');
  if (resultsPath == null) {
    return _missingResultsInvocation();
  }

  final resultsDirectory = _resolveDirectory(root, resultsPath);
  final missingResults = _missingResultsDirectoryInvocation(resultsDirectory);
  if (missingResults != null) {
    return missingResults;
  }

  return _ValidInvocation(resultsDirectory: resultsDirectory);
}

_InvalidInvocation _unsupportedCatalogInvocation() {
  return const _InvalidInvocation(
    ToolCommandResult(
      exitCode: 1,
      stderr:
          'FAIL: --catalog is no longer supported; the checker reads the '
          'generated performance run manifest from --results.\n',
    ),
  );
}

_InvalidInvocation _missingResultsInvocation() {
  return const _InvalidInvocation(
    ToolCommandResult(
      exitCode: 1,
      stderr:
          'Usage: dart run tool/check_flutter_performance_artifacts.dart '
          '--results <directory>\n',
    ),
  );
}

_InvalidInvocation? _missingResultsDirectoryInvocation(
  Directory resultsDirectory,
) {
  if (resultsDirectory.existsSync()) {
    return null;
  }
  return _InvalidInvocation(
    ToolCommandResult(
      exitCode: 1,
      stderr:
          'FAIL: performance results directory not found: '
          '${resultsDirectory.path}\n',
    ),
  );
}

int _collectArtifactFailures(
  Directory resultsDirectory,
  List<String> failures,
) {
  final manifest = _readJsonObject(
    File(_joinPath(resultsDirectory.path, _manifestFileName)),
    'run manifest',
    failures,
  );
  final comparison = _readJsonObject(
    File(_joinPath(resultsDirectory.path, _comparisonSummaryFileName)),
    'comparison summary',
    failures,
  );
  final expectedCatalog = _expectedCatalogFromDescriptor();

  final context = _ArtifactValidationContext(
    resultsDirectory: resultsDirectory,
    catalog: expectedCatalog,
    failures: failures,
  );
  _checkExpectedCatalog(expectedCatalog, failures);

  _checkGeneratedRootFiles(resultsDirectory, expectedCatalog, failures);
  final manifestRuns = manifest == null
      ? <String, _ExpectedRun>{}
      : _ManifestArtifactValidator(context).check(manifest);
  _NestedArtifactValidator(context).check();
  if (comparison != null) {
    _ComparisonSummaryValidator(context, manifestRuns).check(comparison);
  }
  return expectedCatalog.groups.length;
}

void _checkExpectedCatalog(_ExpectedCatalog catalog, List<String> failures) {
  if (catalog.groups.length != 26) {
    failures.add(
      'executable catalog must contain exactly 26 scenario groups; found '
      '${catalog.groups.length}',
    );
  }
  final redesigned = catalog.groups
      .where((group) => group.migration == 'redesigned')
      .length;
  final single = catalog.groups
      .where((group) => group.migration == 'single.current_behavior')
      .length;
  if (redesigned != 7) {
    failures.add('executable catalog must contain 7 redesigned groups');
  }
  if (single != 19) {
    failures.add(
      'executable catalog must contain 19 single.current_behavior groups',
    );
  }
}

void _checkGeneratedRootFiles(
  Directory resultsDirectory,
  _ExpectedCatalog? catalog,
  List<String> failures,
) {
  final entries = resultsDirectory.listSync(followLinks: false);
  _checkUnexpectedEntityTypes(entries, 'results directory', failures);
  final rootFiles = _entryNamesOfType(entries, FileSystemEntityType.file);
  final expectedFiles = {_manifestFileName, _comparisonSummaryFileName};
  for (final missing in _sorted(expectedFiles.difference(rootFiles))) {
    failures.add('missing generated JSON file: $missing');
  }
  for (final extra in _sorted(rootFiles.difference(expectedFiles))) {
    failures.add('unexpected file in results directory: $extra');
  }

  if (catalog == null) {
    return;
  }

  final actualGroupDirs = _entryNamesOfType(
    entries,
    FileSystemEntityType.directory,
  );
  final expectedGroupDirs = catalog.groups.map((group) => group.id).toSet();
  for (final missing in _sorted(
    expectedGroupDirs.difference(actualGroupDirs),
  )) {
    failures.add('missing scenario group directory: $missing');
  }
  for (final extra in _sorted(actualGroupDirs.difference(expectedGroupDirs))) {
    failures.add('unexpected scenario group directory: $extra');
  }
}

final class _ManifestArtifactValidator {
  _ManifestArtifactValidator(this.context) : failures = context.failures;

  final _ArtifactValidationContext context;
  final List<String> failures;
  final _runsByReportKey = <String, _ExpectedRun>{};

  Map<String, _ExpectedRun> check(Map<String, Object?> json) {
    _checkManifestHeader(json);
    _checkGroups(json);
    return _runsByReportKey;
  }

  void _checkManifestHeader(Map<String, Object?> json) {
    _checkForbiddenKeys(json, 'run manifest', failures);
    _checkExactKeys(json, _manifestTopLevelKeys, 'run manifest', failures);
    _checkValue(
      json['schemaVersion'],
      1,
      'run manifest schemaVersion',
      failures,
    );
    _checkMapValue(json['route'], _route, 'run manifest route', failures);
    _checkMapValue(
      json['unsupportedClaims'],
      _unsupportedClaims,
      'run manifest unsupportedClaims',
      failures,
    );
  }

  void _checkGroups(Map<String, Object?> json) {
    final groups = _readListOfMaps(
      json['scenarioGroups'],
      'run manifest scenarioGroups',
      failures,
    );
    final seenGroupIds = <String>{};
    for (final groupJson in groups) {
      _checkGroup(groupJson, seenGroupIds);
    }
    _checkExactIdSet(
      seenGroupIds,
      context.expectedGroupsById.keys.toSet(),
      'run manifest scenario group',
      failures,
    );
  }

  void _checkGroup(Map<String, Object?> groupJson, Set<String> seenGroupIds) {
    _checkExactKeys(
      groupJson,
      _manifestGroupKeys,
      'run manifest group',
      failures,
    );
    final groupId = groupJson['id'];
    if (groupId is! String) {
      failures.add('run manifest group id is not a string');
      return;
    }
    if (!seenGroupIds.add(groupId)) {
      failures.add('duplicate run manifest scenario group: $groupId');
    }
    final expectedGroup = context.expectedGroupsById[groupId];
    if (expectedGroup == null) {
      failures.add('unexpected run manifest scenario group: $groupId');
      return;
    }
    _checkValue(
      groupJson['migration'],
      expectedGroup.migration,
      'run manifest migration for $groupId',
      failures,
    );
    _checkPhases(groupJson, expectedGroup);
  }

  void _checkPhases(
    Map<String, Object?> groupJson,
    _ExpectedGroup expectedGroup,
  ) {
    final phases = _readListOfMaps(
      groupJson['phases'],
      'run manifest phases for ${expectedGroup.id}',
      failures,
    );
    final expectedPhases = expectedGroup.phasesByKey;
    final seenPhaseKeys = <String>{};
    for (final phaseJson in phases) {
      _checkPhase(phaseJson, expectedGroup, expectedPhases, seenPhaseKeys);
    }
    _checkExactIdSet(
      seenPhaseKeys,
      expectedPhases.keys.toSet(),
      'run manifest phase for ${expectedGroup.id}',
      failures,
    );
  }

  void _checkPhase(
    Map<String, Object?> phaseJson,
    _ExpectedGroup group,
    Map<String, _ExpectedPhase> expectedPhases,
    Set<String> seenPhaseKeys,
  ) {
    _checkExactKeys(
      phaseJson,
      _manifestPhaseKeys,
      'run manifest phase for ${group.id}',
      failures,
    );
    final phaseIdentity = _readPhaseIdentity(
      phaseJson,
      'run manifest phase',
      failures,
    );
    if (phaseIdentity == null) {
      return;
    }
    _checkManifestPhaseKind(phaseIdentity.kind);
    if (!seenPhaseKeys.add(phaseIdentity.key)) {
      failures.add(
        'duplicate run manifest phase: ${group.id}/${phaseIdentity.key}',
      );
    }
    final expectedPhase = expectedPhases[phaseIdentity.key];
    if (expectedPhase == null) {
      failures.add(
        'unsupported run manifest phase: ${group.id}/${phaseIdentity.key}',
      );
      return;
    }
    _checkManifestPhaseRole(phaseJson, group, expectedPhase);
    _checkRepeats(phaseJson, group, expectedPhase);
  }

  void _checkManifestPhaseKind(String kind) {
    if (!_phaseKinds.contains(kind)) {
      failures.add('unsupported run manifest phase kind: $kind');
    }
  }

  void _checkManifestPhaseRole(
    Map<String, Object?> phaseJson,
    _ExpectedGroup group,
    _ExpectedPhase phase,
  ) {
    if (!_comparisonRoles.contains(phaseJson['comparisonRole'])) {
      failures.add(
        'unsupported run manifest comparisonRole for ${group.id}/${phase.key}',
      );
    }
    _checkValue(
      phaseJson['comparisonRole'],
      phase.comparisonRole,
      'run manifest comparisonRole for ${group.id}/${phase.key}',
      failures,
    );
  }

  void _checkRepeats(
    Map<String, Object?> phaseJson,
    _ExpectedGroup group,
    _ExpectedPhase phase,
  ) {
    _ManifestRepeatValidator(
      failures: failures,
      runsByReportKey: _runsByReportKey,
      scope: _ManifestRepeatScope(group: group, phase: phase),
    ).check(phaseJson);
  }
}

final class _ManifestRepeatValidator {
  const _ManifestRepeatValidator({
    required this.failures,
    required this.runsByReportKey,
    required this.scope,
  });

  final List<String> failures;
  final Map<String, _ExpectedRun> runsByReportKey;
  final _ManifestRepeatScope scope;

  void check(Map<String, Object?> phaseJson) {
    final repeats = _readListOfMaps(
      phaseJson['repeats'],
      'run manifest repeats for ${scope.path}',
      failures,
    );
    _checkCardinality(repeats);
    final seen = _ManifestRepeatSeen();
    for (final repeatJson in repeats) {
      _checkRepeat(repeatJson, seen);
    }
    _checkMissingRepeats(seen.repeats);
  }

  void _checkCardinality(List<Map<String, Object?>> repeats) {
    if (repeats.length == scope.phase.repeats) {
      return;
    }
    failures.add(
      'run manifest repeat cardinality for ${scope.path} expected '
      '${scope.phase.repeats} but found ${repeats.length}',
    );
  }

  void _checkRepeat(Map<String, Object?> repeatJson, _ManifestRepeatSeen seen) {
    final expectedKeys = scope.phase.requiresPreparationMetadata
        ? _manifestPreparedRepeatKeys
        : _manifestBasicRepeatKeys;
    _checkExactKeys(
      repeatJson,
      expectedKeys,
      'run manifest repeat for ${scope.path}',
      failures,
    );
    final repeat = _readRepeatNumber(repeatJson);
    if (repeat == null) {
      return;
    }
    if (!_checkRepeatRange(repeat, seen)) {
      return;
    }
    final expectedRun = _ExpectedRun(
      group: scope.group,
      phase: scope.phase,
      repeat: repeat,
      reportKey: scope.group.catalogReportKey(
        phaseKey: scope.phase.key,
        repeat: repeat,
      ),
    );
    final reportKey = repeatJson['reportKey'];
    if (reportKey is! String) {
      failures.add('run manifest reportKey is not a string');
      return;
    }
    _checkReportKeyIdentity(reportKey, expectedRun, seen);
    _checkArtifactNames(repeatJson, reportKey, expectedRun);
    _checkPreparationMetadata(repeatJson, expectedRun);
  }

  int? _readRepeatNumber(Map<String, Object?> repeatJson) {
    final repeat = repeatJson['repeat'];
    if (repeat is int) {
      return repeat;
    }
    failures.add('run manifest repeat is not an integer for ${scope.path}');
    return null;
  }

  bool _checkRepeatRange(int repeat, _ManifestRepeatSeen seen) {
    var isValid = true;
    if (!seen.repeats.add(repeat)) {
      failures.add('duplicate run manifest repeat for ${scope.path}: $repeat');
    }
    if (repeat < 1 || repeat > scope.phase.repeats) {
      failures.add('unexpected run manifest repeat for ${scope.path}: $repeat');
      isValid = false;
    }
    return isValid;
  }

  void _checkReportKeyIdentity(
    String reportKey,
    _ExpectedRun expectedRun,
    _ManifestRepeatSeen seen,
  ) {
    if (!seen.reportKeys.add(reportKey)) {
      failures.add('duplicate run manifest reportKey: $reportKey');
    }
    if (runsByReportKey.containsKey(reportKey)) {
      failures.add('overwritten run manifest reportKey: $reportKey');
    }
    runsByReportKey[reportKey] = expectedRun;
    _checkReportKey(reportKey, expectedRun, failures);
  }

  void _checkArtifactNames(
    Map<String, Object?> repeatJson,
    String reportKey,
    _ExpectedRun expectedRun,
  ) {
    _checkValue(
      repeatJson['artifactDirectory'],
      expectedRun.artifactDirectory,
      'run manifest artifactDirectory for $reportKey',
      failures,
    );
    _checkValue(
      repeatJson['timelineFile'],
      '$reportKey.timeline.json',
      'run manifest timelineFile for $reportKey',
      failures,
    );
    _checkValue(
      repeatJson['timelineSummaryFile'],
      '$reportKey.timeline_summary.json',
      'run manifest timelineSummaryFile for $reportKey',
      failures,
    );
  }

  void _checkPreparationMetadata(
    Map<String, Object?> repeatJson,
    _ExpectedRun expectedRun,
  ) {
    final phase = expectedRun.phase;
    if (!phase.requiresPreparationMetadata) {
      return;
    }
    _checkValue(
      repeatJson['canonicalPreparation'],
      phase.canonicalPreparation,
      'canonicalPreparation for ${expectedRun.reportKey}',
      failures,
    );
    _checkValue(
      repeatJson['resetReason'],
      phase.resetReason,
      'resetReason for ${expectedRun.reportKey}',
      failures,
    );
    _checkValue(
      repeatJson['measuredAction'],
      phase.measuredAction,
      'measuredAction for ${expectedRun.reportKey}',
      failures,
    );
    _checkValue(
      repeatJson['preparationMeasured'],
      false,
      'preparationMeasured for ${expectedRun.reportKey}',
      failures,
    );
  }

  void _checkMissingRepeats(Set<int> seenRepeats) {
    for (var repeat = 1; repeat <= scope.phase.repeats; repeat += 1) {
      if (!seenRepeats.contains(repeat)) {
        failures.add(
          'missing repeat for ${scope.path}: '
          'repeat_${repeat.toString().padLeft(3, '0')}',
        );
      }
    }
  }
}

final class _NestedArtifactValidator {
  const _NestedArtifactValidator(this.context);

  final _ArtifactValidationContext context;

  List<String> get failures => context.failures;

  void check() {
    for (final group in context.catalog.groups) {
      _checkGroupDirectory(group);
    }
  }

  void _checkGroupDirectory(_ExpectedGroup group) {
    final groupDirectory = Directory(
      _joinPath(context.resultsDirectory.path, group.id),
    );
    if (!groupDirectory.existsSync()) {
      return;
    }
    final entries = groupDirectory.listSync(followLinks: false);
    _checkUnexpectedEntityTypes(
      entries,
      'scenario group directory for ${group.id}',
      failures,
    );
    _checkUnexpectedEntriesOfType(
      entries,
      FileSystemEntityType.file,
      'file in scenario group directory',
      failures,
    );
    _checkExactIdSet(
      _entryNamesOfType(entries, FileSystemEntityType.directory),
      group.phases.map((phase) => phase.key).toSet(),
      'phase directory for ${group.id}',
      failures,
    );
    for (final phase in group.phases) {
      _checkPhaseDirectory(groupDirectory, group, phase);
    }
  }

  void _checkPhaseDirectory(
    Directory groupDirectory,
    _ExpectedGroup group,
    _ExpectedPhase phase,
  ) {
    final phaseDirectory = Directory(_joinPath(groupDirectory.path, phase.key));
    if (!phaseDirectory.existsSync()) {
      return;
    }
    final entries = phaseDirectory.listSync(followLinks: false);
    _checkUnexpectedEntityTypes(
      entries,
      'phase directory for ${group.id}/${phase.key}',
      failures,
    );
    _checkUnexpectedEntriesOfType(
      entries,
      FileSystemEntityType.file,
      'file in phase directory',
      failures,
    );
    _checkExactIdSet(
      _entryNamesOfType(entries, FileSystemEntityType.directory),
      _expectedRepeatDirectoryNames(phase),
      'repeat directory for ${group.id}/${phase.key}',
      failures,
    );
    for (var repeat = 1; repeat <= phase.repeats; repeat += 1) {
      _checkRepeatDirectory(
        context.resultsDirectory,
        _ExpectedRun(
          group: group,
          phase: phase,
          repeat: repeat,
          reportKey: group.catalogReportKey(
            phaseKey: phase.key,
            repeat: repeat,
          ),
        ),
        failures,
      );
    }
  }

  Set<String> _expectedRepeatDirectoryNames(_ExpectedPhase phase) {
    return {
      for (var repeat = 1; repeat <= phase.repeats; repeat += 1)
        'repeat_${repeat.toString().padLeft(3, '0')}',
    };
  }
}

void _checkRepeatDirectory(
  Directory resultsDirectory,
  _ExpectedRun run,
  List<String> failures,
) {
  final repeatDirectory = Directory(
    _joinPath(resultsDirectory.path, run.artifactDirectory),
  );
  if (!repeatDirectory.existsSync()) {
    return;
  }
  final entries = repeatDirectory.listSync(followLinks: false);
  _checkUnexpectedEntityTypes(
    entries,
    'repeat directory for ${run.reportKey}',
    failures,
  );
  _checkUnexpectedEntriesOfType(
    entries,
    FileSystemEntityType.directory,
    'nested directory',
    failures,
  );
  _checkRepeatArtifactFiles(repeatDirectory, entries, run, failures);
}

void _checkRepeatArtifactFiles(
  Directory repeatDirectory,
  List<FileSystemEntity> entries,
  _ExpectedRun run,
  List<String> failures,
) {
  final expectedFiles = {
    '${run.reportKey}.timeline.json',
    '${run.reportKey}.timeline_summary.json',
  };
  _checkExactIdSet(
    _entryNamesOfType(entries, FileSystemEntityType.file),
    expectedFiles,
    'artifact file for ${run.reportKey}',
    failures,
  );
  _checkTimelineJson(
    File(_joinPath(repeatDirectory.path, '${run.reportKey}.timeline.json')),
    'timeline JSON for ${run.reportKey}',
    failures,
  );
  _checkTimelineSummaryJson(
    File(
      _joinPath(repeatDirectory.path, '${run.reportKey}.timeline_summary.json'),
    ),
    'TimelineSummary JSON for ${run.reportKey}',
    failures,
  );
}

final class _ComparisonSummaryValidator {
  _ComparisonSummaryValidator(this.context, this.manifestRuns)
    : failures = context.failures;

  final _ArtifactValidationContext context;
  final Map<String, _ExpectedRun> manifestRuns;
  final List<String> failures;

  void check(Map<String, Object?> json) {
    _checkHeader(json);
    _checkGroups(json);
  }

  void _checkHeader(Map<String, Object?> json) {
    _checkForbiddenKeys(json, 'comparison summary', failures);
    _checkExactKeys(
      json,
      _comparisonTopLevelKeys,
      'comparison summary',
      failures,
    );
    _checkValue(
      json['schemaVersion'],
      1,
      'comparison summary schemaVersion',
      failures,
    );
    _checkValue(
      json['sourceManifest'],
      _manifestFileName,
      'comparison summary sourceManifest',
      failures,
    );
    _checkValue(
      json['routeName'],
      _route['name'],
      'comparison summary routeName',
      failures,
    );
    _checkValue(
      json['commandFamily'],
      _route['commandFamily'],
      'comparison summary commandFamily',
      failures,
    );
  }

  void _checkGroups(Map<String, Object?> json) {
    final groups = _readListOfMaps(
      json['scenarioGroups'],
      'comparison summary scenarioGroups',
      failures,
    );
    final seenGroupIds = <String>{};
    for (final groupJson in groups) {
      _checkGroup(groupJson, seenGroupIds);
    }
    _checkExactIdSet(
      seenGroupIds,
      context.expectedGroupsById.keys.toSet(),
      'comparison summary scenario group',
      failures,
    );
  }

  void _checkGroup(Map<String, Object?> groupJson, Set<String> seenGroupIds) {
    _checkExactKeys(
      groupJson,
      _comparisonGroupKeys,
      'comparison summary group',
      failures,
    );
    final groupId = groupJson['id'];
    if (groupId is! String) {
      failures.add('comparison summary group id is not a string');
      return;
    }
    if (!seenGroupIds.add(groupId)) {
      failures.add('duplicate comparison summary scenario group: $groupId');
    }
    final expectedGroup = context.expectedGroupsById[groupId];
    if (expectedGroup == null) {
      failures.add('unexpected comparison summary scenario group: $groupId');
      return;
    }
    _checkPhases(groupJson, expectedGroup);
  }

  void _checkPhases(
    Map<String, Object?> groupJson,
    _ExpectedGroup expectedGroup,
  ) {
    final phases = _readListOfMaps(
      groupJson['phases'],
      'comparison summary phases for ${expectedGroup.id}',
      failures,
    );
    final seenPhaseKeys = <String>{};
    for (final phaseJson in phases) {
      _checkPhase(phaseJson, expectedGroup, seenPhaseKeys);
    }
    _checkExactIdSet(
      seenPhaseKeys,
      expectedGroup.phasesByKey.keys.toSet(),
      'comparison summary phase for ${expectedGroup.id}',
      failures,
    );
  }

  void _checkPhase(
    Map<String, Object?> phaseJson,
    _ExpectedGroup expectedGroup,
    Set<String> seenPhaseKeys,
  ) {
    _checkExactKeys(
      phaseJson,
      _comparisonPhaseKeys,
      'comparison summary phase for ${expectedGroup.id}',
      failures,
    );
    final phaseIdentity = _readPhaseIdentity(
      phaseJson,
      'comparison summary phase',
      failures,
    );
    if (phaseIdentity == null) {
      return;
    }
    if (!seenPhaseKeys.add(phaseIdentity.key)) {
      failures.add(
        'duplicate comparison summary phase: '
        '${expectedGroup.id}/${phaseIdentity.key}',
      );
    }
    final expectedPhase = expectedGroup.phasesByKey[phaseIdentity.key];
    if (expectedPhase == null) {
      failures.add(
        'unsupported comparison summary phase: '
        '${expectedGroup.id}/${phaseIdentity.key}',
      );
      return;
    }
    _checkValue(
      phaseJson['repeatCount'],
      expectedPhase.repeats,
      'comparison summary repeatCount for '
      '${expectedGroup.id}/${expectedPhase.key}',
      failures,
    );
    _checkMetrics(
      phaseJson,
      _ComparisonPhaseScope(group: expectedGroup, phase: expectedPhase),
    );
  }

  void _checkMetrics(
    Map<String, Object?> phaseJson,
    _ComparisonPhaseScope scope,
  ) {
    final metrics = _readListOfMaps(
      phaseJson['metrics'],
      'comparison summary metrics for ${scope.path}',
      failures,
    );
    final seenFields = <String>{};
    for (final metric in metrics) {
      _checkMetric(metric, scope, seenFields);
    }
    _checkExactIdSet(
      seenFields,
      _comparisonSummaryFields,
      'comparison summary metric for ${scope.path}',
      failures,
    );
  }

  void _checkMetric(
    Map<String, Object?> metric,
    _ComparisonPhaseScope scope,
    Set<String> seenFields,
  ) {
    _checkExactKeys(
      metric,
      _comparisonMetricKeys,
      'comparison summary metric for ${scope.path}',
      failures,
    );
    final summaryField = _readSummaryField(metric, seenFields);
    if (summaryField == null) {
      return;
    }
    _checkValue(
      metric['unit'],
      summaryField.endsWith('_millis') ? 'millis' : 'count',
      'comparison summary unit for $summaryField',
      failures,
    );
    _ComparisonMetricValidator(
      context: context,
      manifestRuns: manifestRuns,
      scope: scope.withSummaryField(summaryField),
    ).check(metric);
  }

  String? _readSummaryField(
    Map<String, Object?> metric,
    Set<String> seenFields,
  ) {
    final summaryField = metric['summaryField'];
    if (summaryField is! String) {
      failures.add('comparison summary metric summaryField is not a string');
      return null;
    }
    if (!seenFields.add(summaryField)) {
      failures.add('duplicate comparison summary metric: $summaryField');
    }
    if (!_comparisonSummaryFields.contains(summaryField)) {
      failures.add('unsupported comparison summary metric: $summaryField');
      return null;
    }
    return summaryField;
  }
}

final class _ComparisonMetricValidator {
  const _ComparisonMetricValidator({
    required this.context,
    required this.manifestRuns,
    required this.scope,
  });

  final _ArtifactValidationContext context;
  final Map<String, _ExpectedRun> manifestRuns;
  final _ComparisonMetricScope scope;

  List<String> get failures => context.failures;

  void check(Map<String, Object?> metric) {
    final rawRepeats = _readListOfMaps(
      metric['rawRepeats'],
      'raw repeats for ${scope.path}',
      failures,
    );
    _checkRawRepeatCardinality(rawRepeats);
    final values = _checkRawRepeats(rawRepeats);
    if (values.isEmpty) {
      return;
    }
    _checkDerivedMetric(metric, _derivedMetric(values));
  }

  void _checkRawRepeatCardinality(List<Map<String, Object?>> rawRepeats) {
    if (rawRepeats.length == scope.phase.repeats) {
      return;
    }
    failures.add(
      'raw repeat cardinality for ${scope.path} expected '
      '${scope.phase.repeats} but found ${rawRepeats.length}',
    );
  }

  List<num> _checkRawRepeats(List<Map<String, Object?>> rawRepeats) {
    final seenRepeats = <int>{};
    final values = <num>[];
    for (final rawRepeat in rawRepeats) {
      final value = _checkRawRepeat(rawRepeat, seenRepeats);
      if (value != null) {
        values.add(value);
      }
    }
    _checkMissingRawRepeats(seenRepeats);
    return values;
  }

  num? _checkRawRepeat(Map<String, Object?> rawRepeat, Set<int> seenRepeats) {
    _checkExactKeys(
      rawRepeat,
      _comparisonRawRepeatKeys,
      'raw repeat for ${scope.path}',
      failures,
    );
    final repeat = rawRepeat['repeat'];
    final value = rawRepeat['value'];
    if (repeat is! int || value is! num) {
      failures.add(
        'raw repeat for ${scope.path} must contain integer repeat and '
        'numeric value',
      );
      return null;
    }
    if (!seenRepeats.add(repeat)) {
      failures.add('duplicate raw repeat for ${scope.path}: $repeat');
    }
    if (repeat < 1 || repeat > scope.phase.repeats) {
      failures.add('unexpected raw repeat for ${scope.path}: $repeat');
      return null;
    }
    _checkRawRepeatSourceValue(scope.run(repeat), value);
    return value;
  }

  void _checkRawRepeatSourceValue(_ExpectedRun run, num value) {
    if (!manifestRuns.containsKey(run.reportKey)) {
      failures.add(
        'raw repeat references missing manifest run: ${run.reportKey}',
      );
    }
    final summaryValue = _readTimelineSummaryValue(
      context.resultsDirectory,
      run,
      scope.summaryField,
      failures,
    );
    if (summaryValue == null || summaryValue == value) {
      return;
    }
    failures.add(
      'raw repeat value for ${run.reportKey}/${scope.summaryField} expected '
      '$summaryValue but found $value',
    );
  }

  void _checkMissingRawRepeats(Set<int> seenRepeats) {
    for (var repeat = 1; repeat <= scope.phase.repeats; repeat += 1) {
      if (!seenRepeats.contains(repeat)) {
        failures.add('missing raw repeat for ${scope.path}: $repeat');
      }
    }
  }

  void _checkDerivedMetric(
    Map<String, Object?> metric,
    ({num median, num min, num max, num interquartileRange}) derived,
  ) {
    _checkNumberValue(metric['median'], derived.median, 'median', failures);
    _checkNumberValue(metric['min'], derived.min, 'min', failures);
    _checkNumberValue(metric['max'], derived.max, 'max', failures);
    _checkNumberValue(
      metric['interquartileRange'],
      derived.interquartileRange,
      'interquartileRange',
      failures,
    );
  }
}

num? _readTimelineSummaryValue(
  Directory resultsDirectory,
  _ExpectedRun run,
  String summaryField,
  List<String> failures,
) {
  final file = File(
    _joinPath(
      resultsDirectory.path,
      run.artifactDirectory,
      '${run.reportKey}.timeline_summary.json',
    ),
  );
  final json = _readJsonObject(
    file,
    'TimelineSummary JSON for ${run.reportKey}',
    failures,
  );
  final value = json?[summaryField];
  if (json != null && value is! num) {
    failures.add(
      'TimelineSummary JSON for ${run.reportKey} field $summaryField is not a '
      'JSON number: ${file.path}',
    );
  }
  return value is num ? value : null;
}

void _checkTimelineJson(File file, String description, List<String> failures) {
  final json = _readJsonObject(file, description, failures);
  if (json == null) {
    return;
  }
  if (json['traceEvents'] is! List<Object?>) {
    failures.add('$description is missing traceEvents: ${file.path}');
  }
}

void _checkTimelineSummaryJson(
  File file,
  String description,
  List<String> failures,
) {
  final json = _readJsonObject(file, description, failures);
  if (json == null) {
    return;
  }
  for (final key in _sorted(_timelineSummaryNumberKeys)) {
    if (!json.containsKey(key)) {
      failures.add('$description is missing $key: ${file.path}');
    } else if (json[key] is! num) {
      failures.add(
        '$description field $key is not a JSON number: ${file.path}',
      );
    }
  }
  for (final key in _sorted(_timelineSummaryListKeys)) {
    if (!json.containsKey(key)) {
      failures.add('$description is missing $key: ${file.path}');
    } else if (json[key] is! List<Object?>) {
      failures.add('$description field $key is not a JSON list: ${file.path}');
    }
  }
}

Map<String, Object?>? _readJsonObject(
  File file,
  String description,
  List<String> failures,
) {
  if (!file.existsSync()) {
    failures.add('missing $description: ${file.path}');
    return null;
  }
  Object? decoded;
  try {
    decoded = jsonDecode(file.readAsStringSync());
  } on FormatException catch (error) {
    failures.add('malformed $description: ${file.path}: ${error.message}');
    return null;
  }
  if (decoded is! Map<String, Object?>) {
    failures.add('$description is not a JSON object: ${file.path}');
    return null;
  }
  return decoded;
}

List<Map<String, Object?>> _readListOfMaps(
  Object? value,
  String description,
  List<String> failures,
) {
  if (value is! List<Object?>) {
    failures.add('$description is not a JSON array');
    return const [];
  }
  final maps = <Map<String, Object?>>[];
  for (final item in value) {
    if (item is Map<String, Object?>) {
      maps.add(item);
    } else {
      failures.add('$description contains a non-object entry');
    }
  }
  return maps;
}

_PhaseIdentity? _readPhaseIdentity(
  Map<String, Object?> json,
  String description,
  List<String> failures,
) {
  final kind = json['kind'];
  final name = json['name'];
  if (kind is String && name is String) {
    return _PhaseIdentity(kind: kind, name: name);
  }
  failures.add('$description kind/name is not a string');
  return null;
}

_ExpectedCatalog _expectedCatalogFromDescriptor() {
  return _ExpectedCatalog(
    groups: [
      for (final group in catalog.performanceScenarioCatalogGroups)
        _ExpectedGroup(
          id: group.id,
          migration: group.migration,
          reportKeysByPhaseAndRepeat: {
            for (final run in catalog.performanceScenarioCatalogRuns.where(
              (run) => run.scenarioGroupId == group.id,
            ))
              _repeatIdentity(phaseKey: run.phaseKey, repeat: run.repeat):
                  run.reportKey,
          },
          phases: [
            for (final phase in group.phases)
              _ExpectedPhase(
                kind: phase.kind,
                name: phase.name,
                comparisonRole: phase.comparisonRole,
                repeats: phase.repeats,
                canonicalPreparation: phase.canonicalPreparation,
                resetReason: phase.resetReason,
                measuredAction: phase.measuredAction,
              ),
          ],
        ),
    ],
  );
}

void _checkReportKey(
  String reportKey,
  _ExpectedRun expectedRun,
  List<String> failures,
) {
  if (!_reportKeyPattern.hasMatch(reportKey)) {
    failures.add('invalid report key grammar: $reportKey');
  }
  _checkValue(
    reportKey,
    expectedRun.reportKey,
    'report key for ${expectedRun.group.id}/${expectedRun.phase.key}/'
    '${expectedRun.repeat}',
    failures,
  );
}

void _checkExactKeys(
  Map<String, Object?> value,
  Set<String> expected,
  String description,
  List<String> failures,
) {
  final actual = value.keys.toSet();
  for (final missing in _sorted(expected.difference(actual))) {
    failures.add('$description is missing key: $missing');
  }
  for (final extra in _sorted(actual.difference(expected))) {
    failures.add('$description has unexpected key: $extra');
  }
}

void _checkExactIdSet(
  Set<String> actual,
  Set<String> expected,
  String description,
  List<String> failures,
) {
  for (final missing in _sorted(expected.difference(actual))) {
    failures.add('missing $description: $missing');
  }
  for (final extra in _sorted(actual.difference(expected))) {
    failures.add('unexpected $description: $extra');
  }
}

void _checkMapValue(
  Object? actual,
  Map<String, Object?> expected,
  String description,
  List<String> failures,
) {
  if (actual is! Map<String, Object?>) {
    failures.add('$description is not a JSON object');
    return;
  }
  _checkExactKeys(actual, expected.keys.toSet(), description, failures);
  for (final entry in expected.entries) {
    _checkValue(
      actual[entry.key],
      entry.value,
      '$description.${entry.key}',
      failures,
    );
  }
}

void _checkValue(
  Object? actual,
  Object? expected,
  String description,
  List<String> failures,
) {
  if (actual != expected) {
    failures.add('$description expected $expected but found $actual');
  }
}

void _checkNumberValue(
  Object? actual,
  num expected,
  String description,
  List<String> failures,
) {
  if (actual is! num || actual != expected) {
    failures.add('$description expected $expected but found $actual');
  }
}

void _checkForbiddenKeys(
  Object? value,
  String description,
  List<String> failures, [
  String path = r'$',
]) {
  if (value is Map) {
    for (final entry in value.entries) {
      final key = entry.key;
      final nextPath = '$path.$key';
      if (_forbiddenKeys.contains(key)) {
        failures.add('$description contains forbidden key $key at $nextPath');
      }
      _checkForbiddenKeys(entry.value, description, failures, nextPath);
    }
  } else if (value is Iterable) {
    var index = 0;
    for (final item in value) {
      _checkForbiddenKeys(item, description, failures, '$path[$index]');
      index += 1;
    }
  }
}

({num median, num min, num max, num interquartileRange}) _derivedMetric(
  List<num> rawValues,
) {
  final values = rawValues.toList()..sort();
  final q1q3 = _quartiles(values);
  return (
    median: _median(values),
    min: values.first,
    max: values.last,
    interquartileRange: q1q3.q3 - q1q3.q1,
  );
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

Directory _resolveDirectory(Directory root, String path) {
  if (path.startsWith('/')) {
    return Directory(path);
  }

  return Directory(_joinPath(root.path, path));
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

Set<String> _entryNamesOfType(
  List<FileSystemEntity> entries,
  FileSystemEntityType expectedType,
) {
  return {
    for (final entry in entries)
      if (FileSystemEntity.typeSync(entry.path, followLinks: false) ==
          expectedType)
        _basename(entry),
  };
}

void _checkUnexpectedEntityTypes(
  List<FileSystemEntity> entries,
  String description,
  List<String> failures,
) {
  for (final entry in entries) {
    final type = FileSystemEntity.typeSync(entry.path, followLinks: false);
    if (type != FileSystemEntityType.file &&
        type != FileSystemEntityType.directory) {
      failures.add(
        'unexpected file system entry in $description: ${entry.path}',
      );
    }
  }
}

void _checkUnexpectedEntriesOfType(
  List<FileSystemEntity> entries,
  FileSystemEntityType unexpectedType,
  String description,
  List<String> failures,
) {
  for (final entry in entries) {
    if (FileSystemEntity.typeSync(entry.path, followLinks: false) ==
        unexpectedType) {
      failures.add('unexpected $description: ${entry.path}');
    }
  }
}

String _joinPath(String part, String other, [String? third]) {
  return [part, other, ?third].join(Platform.pathSeparator);
}

List<String> _sorted(Iterable<String> values) {
  return values.toList()..sort();
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
  const _ValidInvocation({required this.resultsDirectory});

  final Directory resultsDirectory;
}

final class _InvalidInvocation extends _Invocation {
  const _InvalidInvocation(this.result);

  final ToolCommandResult result;
}

final class _ArtifactValidationContext {
  _ArtifactValidationContext({
    required this.resultsDirectory,
    required this.catalog,
    required this.failures,
  }) : expectedGroupsById = {
         for (final group in catalog.groups) group.id: group,
       };

  final Directory resultsDirectory;
  final _ExpectedCatalog catalog;
  final List<String> failures;
  final Map<String, _ExpectedGroup> expectedGroupsById;
}

final class _ExpectedCatalog {
  const _ExpectedCatalog({required this.groups});

  final List<_ExpectedGroup> groups;
}

final class _ExpectedGroup {
  const _ExpectedGroup({
    required this.id,
    required this.migration,
    required this.reportKeysByPhaseAndRepeat,
    required this.phases,
  });

  final String id;
  final String migration;
  final Map<String, String> reportKeysByPhaseAndRepeat;
  final List<_ExpectedPhase> phases;

  Map<String, _ExpectedPhase> get phasesByKey => {
    for (final phase in phases) phase.key: phase,
  };

  String catalogReportKey({required String phaseKey, required int repeat}) {
    return reportKeysByPhaseAndRepeat[_repeatIdentity(
      phaseKey: phaseKey,
      repeat: repeat,
    )]!;
  }
}

final class _ExpectedPhase {
  const _ExpectedPhase({
    required this.kind,
    required this.name,
    required this.comparisonRole,
    required this.repeats,
    this.canonicalPreparation,
    this.resetReason,
    this.measuredAction,
  });

  final String kind;
  final String name;
  final String comparisonRole;
  final int repeats;
  final String? canonicalPreparation;
  final String? resetReason;
  final String? measuredAction;

  String get key => '$kind.$name';

  bool get requiresPreparationMetadata => kind == 'warm' || kind == 'steady';
}

final class _ExpectedRun {
  const _ExpectedRun({
    required this.group,
    required this.phase,
    required this.repeat,
    required this.reportKey,
  });

  final _ExpectedGroup group;
  final _ExpectedPhase phase;
  final int repeat;
  final String reportKey;

  String get artifactDirectory => [
    group.id,
    phase.key,
    'repeat_${repeat.toString().padLeft(3, '0')}',
  ].join('/');
}

final class _ManifestRepeatScope {
  const _ManifestRepeatScope({required this.group, required this.phase});

  final _ExpectedGroup group;
  final _ExpectedPhase phase;

  String get path => '${group.id}/${phase.key}';
}

final class _ManifestRepeatSeen {
  final repeats = <int>{};
  final reportKeys = <String>{};
}

final class _ComparisonPhaseScope {
  const _ComparisonPhaseScope({required this.group, required this.phase});

  final _ExpectedGroup group;
  final _ExpectedPhase phase;

  String get path => '${group.id}/${phase.key}';

  _ComparisonMetricScope withSummaryField(String summaryField) {
    return _ComparisonMetricScope(
      group: group,
      phase: phase,
      summaryField: summaryField,
    );
  }
}

final class _ComparisonMetricScope {
  const _ComparisonMetricScope({
    required this.group,
    required this.phase,
    required this.summaryField,
  });

  final _ExpectedGroup group;
  final _ExpectedPhase phase;
  final String summaryField;

  String get path => '${group.id}/${phase.key}/$summaryField';

  _ExpectedRun run(int repeat) {
    return _ExpectedRun(
      group: group,
      phase: phase,
      repeat: repeat,
      reportKey: group.catalogReportKey(phaseKey: phase.key, repeat: repeat),
    );
  }
}

String _repeatIdentity({required String phaseKey, required int repeat}) {
  return '$phaseKey#$repeat';
}

final class _PhaseIdentity {
  const _PhaseIdentity({required this.kind, required this.name});

  final String kind;
  final String name;

  String get key => '$kind.$name';
}
