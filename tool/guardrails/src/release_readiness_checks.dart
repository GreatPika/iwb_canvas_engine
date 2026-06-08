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
  _checkReleaseWorkflow(workflowFiles, violations);
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

void _checkReleaseWorkflow(
  Map<String, String> workflowFiles,
  List<GuardrailViolation> violations,
) {
  const releaseWorkflowPath = '.github/workflows/release_benchmarks.yml';
  final job = _releaseWorkflowJob(
    releaseWorkflowPath,
    workflowFiles[releaseWorkflowPath],
    violations,
  );
  if (job == null) {
    return;
  }
  _checkNoBypassFields(releaseWorkflowPath, job, violations);
  if (job['runs-on'] != 'ubuntu-24.04') {
    violations.add(
      const GuardrailViolation(
        guardrailId: releaseBenchmarkReadinessGuardrailId,
        path: releaseWorkflowPath,
        message: 'release workflow must run on ubuntu-24.04',
      ),
    );
  }

  final steps = _workflowSteps(releaseWorkflowPath, job, violations);
  _checkFlutterSetup(releaseWorkflowPath, steps, violations);
  _checkRequiredReleaseCommands(
    releaseWorkflowPath,
    _runCommands(steps),
    violations,
  );
  _checkNoRetiredWorkflowCommands(
    releaseWorkflowPath,
    _runCommands(steps),
    violations,
  );
}

YamlMap? _releaseWorkflowJob(
  String releaseWorkflowPath,
  String? workflow,
  List<GuardrailViolation> violations,
) {
  if (workflow == null) {
    violations.add(
      GuardrailViolation(
        guardrailId: releaseBenchmarkReadinessGuardrailId,
        path: releaseWorkflowPath,
        message: 'release benchmark workflow must exist',
      ),
    );

    return null;
  }
  final parsed = _workflowMap(releaseWorkflowPath, workflow, violations);
  if (parsed == null) {
    return null;
  }

  return _workflowJob(
    releaseWorkflowPath,
    parsed,
    'release-benchmarks',
    violations,
  );
}

void _checkRequiredReleaseCommands(
  String releaseWorkflowPath,
  Set<String> runCommands,
  List<GuardrailViolation> violations,
) {
  for (final required in const [
    'dart run docs/tool/sync_generated_docs.dart --check',
    'dart run docs/tool/check_docs.dart',
    'dart run tool/bench/run.dart --profile=release',
    _releaseDiffCommand,
    'dart run tool/architecture_graph/check.dart',
    'dart run tool/architecture_graph/generate_views.dart --check',
    'dart run tool/guardrails/run.dart',
  ]) {
    if (!runCommands.contains(required)) {
      violations.add(
        GuardrailViolation(
          guardrailId: releaseBenchmarkReadinessGuardrailId,
          path: releaseWorkflowPath,
          message: 'release workflow missing required command: $required',
        ),
      );
    }
  }
}

void _checkNoRetiredWorkflowCommands(
  String releaseWorkflowPath,
  Set<String> runCommands,
  List<GuardrailViolation> violations,
) {
  for (final command in runCommands) {
    if (command.contains('legacy/')) {
      violations.add(
        GuardrailViolation(
          guardrailId: releaseBenchmarkReadinessGuardrailId,
          path: releaseWorkflowPath,
          message:
              'release benchmark workflow must not invoke retired package paths',
        ),
      );
    }
    if (command.contains('--phase') || command.contains('P14')) {
      violations.add(
        GuardrailViolation(
          guardrailId: releaseBenchmarkReadinessGuardrailId,
          path: releaseWorkflowPath,
          message: 'release benchmark workflow must use current graph commands',
        ),
      );
    }
    for (final token in const [
      'PLAN.md',
      'plan/',
      'docs/indexes/by_phase.md',
      'docs/indexes/donor_to_phase.md',
      'docs/donors',
      'docs/implementation',
    ]) {
      if (command.contains(token)) {
        violations.add(
          GuardrailViolation(
            guardrailId: releaseBenchmarkReadinessGuardrailId,
            path: releaseWorkflowPath,
            message:
                'release benchmark workflow must not invoke retired planning routes',
          ),
        );
      }
    }
  }
}

void _checkBaselineWriteRoutes(
  Map<String, String> workflowFiles,
  List<GuardrailViolation> violations,
) {
  for (final entry in workflowFiles.entries) {
    final path = entry.key;
    final content = entry.value;
    final isManualUpdate =
        path == '.github/workflows/update_benchmark_baseline.yml';
    if (isManualUpdate) {
      final parsed = _workflowMap(path, content, violations);
      if (parsed == null) {
        continue;
      }
      final triggers = _workflowTriggers(parsed);
      final allowedTrigger =
          triggers.length == 1 && triggers.contains('workflow_dispatch');
      if (!allowedTrigger ||
          !content.contains('dart run tool/bench/update_baseline.dart')) {
        violations.add(
          GuardrailViolation(
            guardrailId: releaseBenchmarkReadinessGuardrailId,
            path: path,
            message: 'manual baseline update workflow is incomplete',
          ),
        );
      }
      continue;
    }

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

YamlMap? _workflowMap(
  String path,
  String content,
  List<GuardrailViolation> violations,
) {
  try {
    final parsed = loadYaml(content);
    if (parsed is YamlMap) {
      return parsed;
    }
  } on YamlException {
    // Report below through the common malformed-workflow violation.
  }
  violations.add(
    GuardrailViolation(
      guardrailId: releaseBenchmarkReadinessGuardrailId,
      path: path,
      message: 'workflow must be valid YAML mapping',
    ),
  );

  return null;
}

YamlMap? _workflowJob(
  String path,
  YamlMap workflow,
  String jobId,
  List<GuardrailViolation> violations,
) {
  final jobs = workflow['jobs'];
  if (jobs is YamlMap && jobs[jobId] is YamlMap) {
    return jobs[jobId] as YamlMap;
  }
  violations.add(
    GuardrailViolation(
      guardrailId: releaseBenchmarkReadinessGuardrailId,
      path: path,
      message: 'workflow missing job $jobId',
    ),
  );

  return null;
}

List<YamlMap> _workflowSteps(
  String path,
  YamlMap job,
  List<GuardrailViolation> violations,
) {
  final steps = job['steps'];
  if (steps is YamlList) {
    return steps.whereType<YamlMap>().toList();
  }
  violations.add(
    GuardrailViolation(
      guardrailId: releaseBenchmarkReadinessGuardrailId,
      path: path,
      message: 'workflow job must declare executable steps',
    ),
  );

  return const [];
}

void _checkNoBypassFields(
  String path,
  YamlMap job,
  List<GuardrailViolation> violations,
) {
  for (final forbidden in const ['if', 'continue-on-error']) {
    if (job.containsKey(forbidden)) {
      violations.add(
        GuardrailViolation(
          guardrailId: releaseBenchmarkReadinessGuardrailId,
          path: path,
          message: 'release benchmark job must not use $forbidden',
        ),
      );
    }
  }
  for (final step in _workflowSteps(path, job, violations)) {
    for (final forbidden in const ['if', 'continue-on-error']) {
      if (step.containsKey(forbidden)) {
        violations.add(
          GuardrailViolation(
            guardrailId: releaseBenchmarkReadinessGuardrailId,
            path: path,
            message: 'release benchmark step must not use $forbidden',
          ),
        );
      }
    }
  }
}

Set<String> _runCommands(List<YamlMap> steps) {
  return steps
      .map((step) => step['run'])
      .whereType<String>()
      .map((command) => command.trim())
      .toSet();
}

void _checkFlutterSetup(
  String path,
  List<YamlMap> steps,
  List<GuardrailViolation> violations,
) {
  for (final step in steps) {
    if (step['uses'] != 'subosito/flutter-action@v2') {
      continue;
    }
    final config = step['with'];
    if (config is YamlMap &&
        config['channel'] == 'stable' &&
        config['flutter-version'] == '3.38.0') {
      return;
    }
  }
  violations.add(
    GuardrailViolation(
      guardrailId: releaseBenchmarkReadinessGuardrailId,
      path: path,
      message: 'release workflow must pin Flutter 3.38.0 stable',
    ),
  );
}

Set<String> _workflowTriggers(YamlMap workflow) {
  final triggers = workflow['on'];
  if (triggers is String) {
    return {triggers};
  }
  if (triggers is YamlList) {
    return triggers.whereType<String>().toSet();
  }
  if (triggers is YamlMap) {
    return triggers.keys.whereType<String>().toSet();
  }

  return const {};
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
    'release_ubuntu_24_04_flutter_3_38_0.json '
    '--current=build/bench/current/'
    'release_ubuntu_24_04_flutter_3_38_0.json '
    '--output=build/bench/diff/'
    'release_ubuntu_24_04_flutter_3_38_0.json';

const _approvedReleaseBaselinePath =
    'tool/bench/baselines/approved/release_ubuntu_24_04_flutter_3_38_0.json';

const _approvedBaselineImplementationPaths = {
  'tool/bench/update_baseline.dart',
  'tool/bench/src/benchmark_diff.dart',
};
