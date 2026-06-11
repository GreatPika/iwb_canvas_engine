import 'dart:io';

import 'package:yaml/yaml.dart';

import 'guardrail_violation.dart';
import 'repository_paths.dart';

const releaseBenchmarkReadinessGuardrailId = 'release.benchmark_readiness';

Future<List<GuardrailViolation>> checkReleaseBenchmarkReadiness() async {
  return checkReleaseBenchmarkReadinessSources(
    publicSurfaceSources: [
      GuardrailSourceSnapshot(
        path: 'lib/iwb_canvas_engine.dart',
        content: _readFile('lib/iwb_canvas_engine.dart'),
      ),
      for (final file in dartSourceFilesUnder('lib/src/api'))
        GuardrailSourceSnapshot(
          path: file.path,
          content: File(file.absolutePath).readAsStringSync(),
        ),
    ],
    productionSources: [
      for (final file in dartSourceFilesUnder('lib'))
        GuardrailSourceSnapshot(
          path: file.path,
          content: File(file.absolutePath).readAsStringSync(),
        ),
    ],
    benchmarkSources: [
      for (final file in dartSourceFilesUnder('tool/bench'))
        GuardrailSourceSnapshot(
          path: file.path,
          content: File(file.absolutePath).readAsStringSync(),
        ),
    ],
    workflowFiles: {
      for (final file in Directory('.github/workflows').listSync())
        if (file is File && _isWorkflowPath(file.path))
          relativePath(file): file.readAsStringSync(),
    },
  );
}

List<GuardrailViolation> checkReleaseBenchmarkReadinessSources({
  required Iterable<GuardrailSourceSnapshot> publicSurfaceSources,
  required Iterable<GuardrailSourceSnapshot> productionSources,
  required Iterable<GuardrailSourceSnapshot> benchmarkSources,
  required Map<String, String> workflowFiles,
}) {
  final violations = <GuardrailViolation>[];

  _checkPublicSurfaceSources(publicSurfaceSources, violations);
  _checkProductionSources(productionSources, violations);
  _checkBenchmarkSources(benchmarkSources, violations);
  _checkGitHubPerformanceWorkflowQuarantine(workflowFiles, violations);
  _checkBaselineWriteRoutes(workflowFiles, violations);

  return violations;
}

final class GuardrailSourceSnapshot {
  const GuardrailSourceSnapshot({required this.path, required this.content});

  final String path;
  final String content;
}

void _checkPublicSurfaceSources(
  Iterable<GuardrailSourceSnapshot> publicSurfaceSources,
  List<GuardrailViolation> violations,
) {
  for (final source in publicSurfaceSources) {
    for (final forbidden in const [
      'ReleaseReadiness',
      'tool/bench',
      'benchmark',
      'Benchmark',
      'bench',
      'Bench',
    ]) {
      if (source.content.contains(forbidden)) {
        violations.add(
          GuardrailViolation(
            guardrailId: releaseBenchmarkReadinessGuardrailId,
            path: source.path,
            message: 'public surface must not expose release benchmark tooling',
          ),
        );
      }
    }
  }
}

void _checkProductionSources(
  Iterable<GuardrailSourceSnapshot> productionSources,
  List<GuardrailViolation> violations,
) {
  for (final source in productionSources) {
    for (final forbidden in const [
      'AppCanvasPort',
      'LegacyEngineAdapter',
      'NextEngineAdapter',
      'ReleaseReadiness',
      'tool/bench',
      'benchmark',
      'Benchmark',
      'bench',
      'Bench',
      'releaseMeasurement',
      'ReleaseMeasurement',
    ]) {
      if (source.content.contains(forbidden)) {
        violations.add(
          GuardrailViolation(
            guardrailId: releaseBenchmarkReadinessGuardrailId,
            path: source.path,
            message: 'production source must not contain $forbidden',
          ),
        );
      }
    }
  }
}

void _checkBenchmarkSources(
  Iterable<GuardrailSourceSnapshot> benchmarkSources,
  List<GuardrailViolation> violations,
) {
  final retiredPackageImport = RegExp(
    r'''^\s*(import|export)\s+['"][^'"]*legacy''',
    multiLine: true,
  );
  for (final source in benchmarkSources) {
    if (retiredPackageImport.hasMatch(source.content) ||
        source.content.contains('legacy/')) {
      violations.add(
        GuardrailViolation(
          guardrailId: releaseBenchmarkReadinessGuardrailId,
          path: source.path,
          message:
              'benchmark release proof must not invoke retired package paths',
        ),
      );
    }
    if (_containsForbiddenBenchmarkBaselineWriter(source)) {
      violations.add(
        GuardrailViolation(
          guardrailId: releaseBenchmarkReadinessGuardrailId,
          path: source.path,
          message: 'approved baseline writes must stay behind update_baseline',
        ),
      );
    }
  }
}

bool _containsForbiddenBenchmarkBaselineWriter(GuardrailSourceSnapshot source) {
  if (_approvedBaselineImplementationPaths.contains(source.path)) {
    return false;
  }
  for (final forbidden in const [
    _approvedReleaseBaselinePath,
    'approvedReleaseBaselinePath',
    'runBenchmarkBaselineUpdateCli',
    '--approved=',
  ]) {
    if (source.content.contains(forbidden)) {
      return true;
    }
  }

  return false;
}

void _checkGitHubPerformanceWorkflowQuarantine(
  Map<String, String> workflowFiles,
  List<GuardrailViolation> violations,
) {
  for (final path in _quarantinedGitHubPerformanceWorkflowPaths) {
    if (!workflowFiles.containsKey(path)) {
      continue;
    }
    violations.add(
      GuardrailViolation(
        guardrailId: releaseBenchmarkReadinessGuardrailId,
        path: path,
        message: 'GitHub release benchmark workflow is quarantined',
      ),
    );
  }
  for (final entry in workflowFiles.entries) {
    final path = entry.key;
    final content = entry.value;
    if (_containsQuarantinedGitHubPerformanceCommand(path, content)) {
      violations.add(
        GuardrailViolation(
          guardrailId: releaseBenchmarkReadinessGuardrailId,
          path: path,
          message: 'GitHub workflow must not run quarantined benchmark command',
        ),
      );
    }
  }
}

bool _containsQuarantinedGitHubPerformanceCommand(
  String path,
  String workflowContent,
) {
  if (_containsQuarantinedBenchmarkPath(workflowContent)) {
    return true;
  }
  final parsed = _workflowMap(path, workflowContent);
  if (parsed == null) {
    return false;
  }

  final substitutions = _workflowCommandSubstitutions(parsed);
  for (final command in _workflowRunCommands(parsed)) {
    if (_containsQuarantinedBenchmarkPath(command)) {
      return true;
    }
    for (final expanded in _expandWorkflowCommand(command, substitutions)) {
      if (_containsQuarantinedBenchmarkPath(expanded)) {
        return true;
      }
    }
  }

  return false;
}

bool _containsQuarantinedBenchmarkPath(String content) {
  final normalized = _normalizeShellPathSegments(content);
  return normalized.contains('tool/bench/update_baseline.dart') ||
      normalized.contains('tool/bench/run.dart') ||
      normalized.contains('tool/bench/diff.dart');
}

String _normalizeShellPathSegments(String content) {
  return content.replaceAll('"', '').replaceAll("'", '');
}

YamlMap? _workflowMap(String _, String content) {
  try {
    final parsed = loadYaml(content);
    if (parsed is YamlMap) {
      return parsed;
    }
  } on YamlException {
    return null;
  }

  return null;
}

Map<String, Set<String>> _workflowCommandSubstitutions(YamlMap workflow) {
  final substitutions = <String, Set<String>>{};
  _collectWorkflowSubstitutions(workflow, substitutions);

  return substitutions;
}

void _collectWorkflowSubstitutions(
  Object? node,
  Map<String, Set<String>> substitutions,
) {
  if (node is YamlMap) {
    final env = node['env'];
    if (env is YamlMap) {
      _collectNamedScalarValues(env, substitutions);
    }
    final matrix = node['matrix'];
    if (matrix is YamlMap) {
      _collectNamedScalarValues(matrix, substitutions);
    }
    for (final value in node.values) {
      _collectWorkflowSubstitutions(value, substitutions);
    }
    return;
  }
  if (node is YamlList) {
    for (final value in node) {
      _collectWorkflowSubstitutions(value, substitutions);
    }
  }
}

void _collectNamedScalarValues(
  YamlMap values,
  Map<String, Set<String>> substitutions,
) {
  for (final entry in values.entries) {
    final key = entry.key;
    if (key is! String) {
      continue;
    }
    _collectMatrixObjectEntries(entry.value, substitutions);
    final scalarValues = _scalarStrings(entry.value);
    if (scalarValues.isEmpty) {
      continue;
    }
    substitutions.putIfAbsent(key, () => {}).addAll(scalarValues);
  }
}

void _collectMatrixObjectEntries(
  Object? value,
  Map<String, Set<String>> substitutions,
) {
  if (value is! YamlList) {
    return;
  }
  for (final element in value) {
    if (element is YamlMap) {
      _collectNamedScalarValues(element, substitutions);
    }
  }
}

Set<String> _scalarStrings(Object? value) {
  if (value is String) {
    return {value};
  }
  if (value is num || value is bool) {
    return {'$value'};
  }
  if (value is YamlList) {
    return {
      for (final element in value)
        if (element is String || element is num || element is bool) '$element',
    };
  }

  return const {};
}

Iterable<String> _workflowRunCommands(Object? node) sync* {
  if (node is YamlMap) {
    final run = node['run'];
    if (run is String) {
      yield run;
    }
    for (final value in node.values) {
      yield* _workflowRunCommands(value);
    }
    return;
  }
  if (node is YamlList) {
    for (final value in node) {
      yield* _workflowRunCommands(value);
    }
  }
}

Set<String> _expandWorkflowCommand(
  String command,
  Map<String, Set<String>> substitutions,
) {
  var expanded = <String>{command};
  var changed = true;
  var pass = 0;
  while (changed && pass < _maxWorkflowCommandExpansionPasses) {
    changed = false;
    final next = <String>{...expanded};
    for (final candidate in expanded) {
      for (final entry in substitutions.entries) {
        for (final value in entry.value) {
          next.addAll(
            _replaceWorkflowVariableForms(candidate, entry.key, value),
          );
        }
      }
    }
    if (next.length != expanded.length || !expanded.containsAll(next)) {
      changed = true;
    }
    expanded = next.take(_maxWorkflowCommandExpansions).toSet();
    pass += 1;
  }

  return expanded;
}

Set<String> _replaceWorkflowVariableForms(
  String command,
  String key,
  String value,
) {
  return {
    command.replaceAll('\${$key}', value),
    command.replaceAll('\$$key', value),
    command.replaceAll(_githubExpression('env', key), value),
    command.replaceAll(_githubExpression('matrix', key), value),
  };
}

RegExp _githubExpression(String context, String key) {
  return RegExp(
    r'\$\{\{\s*' +
        RegExp.escape(context) +
        r'\.' +
        RegExp.escape(key) +
        r'\s*\}\}',
  );
}

void _checkBaselineWriteRoutes(
  Map<String, String> workflowFiles,
  List<GuardrailViolation> violations,
) {
  for (final entry in workflowFiles.entries) {
    final path = entry.key;
    final content = entry.value;

    if (_containsForbiddenBaselineWrite(content)) {
      violations.add(
        GuardrailViolation(
          guardrailId: releaseBenchmarkReadinessGuardrailId,
          path: path,
          message: 'approved baselines may only be written manually',
        ),
      );
    }
  }
}

bool _containsForbiddenBaselineWrite(String workflowContent) {
  if (workflowContent.contains('tool/bench/update_baseline.dart') ||
      workflowContent.contains('--approved=')) {
    return true;
  }
  final approvedPathMentions = _linesContaining(
    workflowContent,
    _approvedReleaseBaselinePath,
  );

  return approvedPathMentions.any(
    (line) => !line.contains(_releaseDiffCommand),
  );
}

Iterable<String> _linesContaining(String content, String pattern) {
  return content.split('\n').where((line) => line.contains(pattern));
}

bool _isWorkflowPath(String path) {
  return path.endsWith('.yml') || path.endsWith('.yaml');
}

String _readFile(String path) {
  return File(path).readAsStringSync();
}

const _releaseDiffCommand =
    'dart run tool/bench/diff.dart --profile=release '
    '--baseline=tool/bench/baselines/approved/'
    'release_ubuntu_24_04_flutter_3_44_0.json '
    '--current=build/bench/current/'
    'release_ubuntu_24_04_flutter_3_44_0.json '
    '--output=build/bench/diff/'
    'release_ubuntu_24_04_flutter_3_44_0.json';

const _approvedReleaseBaselinePath =
    'tool/bench/baselines/approved/release_ubuntu_24_04_flutter_3_44_0.json';

const _quarantinedGitHubPerformanceWorkflowPaths = {
  '.github/workflows/release_benchmarks.yml',
  '.github/workflows/update_benchmark_baseline.yml',
};

const _maxWorkflowCommandExpansions = 128;
const _maxWorkflowCommandExpansionPasses = 8;

const _approvedBaselineImplementationPaths = {
  'tool/bench/update_baseline.dart',
  'tool/bench/src/benchmark_diff.dart',
};
