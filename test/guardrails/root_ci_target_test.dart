import 'dart:io';

import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

import '../../tool/guardrails/src/guardrail_registry.dart';

// CI structural tests keep the PR, release, and manual-update workflow checks
// together so bypass and baseline-write rules are reviewed as one CI contract.
// ignore: halstead-volume, source-lines-of-code
void main() {
  test('root workflow runs repository-owned package checks', () {
    final workflowFile = File('.github/workflows/root_package.yml');

    expect(workflowFile.existsSync(), isTrue);

    final workflowContent = workflowFile.readAsStringSync();
    final rootPackageJob = _rootPackageJob(workflowContent);
    final steps = _workflowSteps(rootPackageJob);
    final guardrailStep = _stepNamed(steps, 'Run guardrails');

    _expectRootPackageChecks(steps);
    _expectRootPackageBenchmarkChecks(workflowContent, steps);
    _expectExamplePackageChecks(workflowContent);
    _expectExampleBoundaryDiffEnvironment(steps);
    _expectNoWorkflowBypass(rootPackageJob, steps);
    _expectGuardrailRunnerCannotBeBypassed(rootPackageJob, guardrailStep);
    _expectFullGuardrailRunnerSelection(workflowContent, guardrailStep);
    _expectNoDcmCommandsInCi();
  });

  test('benchmark release workflow is pinned and fail-closed', () {
    final workflowFile = File('.github/workflows/release_benchmarks.yml');

    expect(workflowFile.existsSync(), isTrue);

    final workflowContent = workflowFile.readAsStringSync();
    final releaseJob = _workflowJob(workflowContent, 'release-benchmarks');
    final steps = _workflowSteps(releaseJob);

    _expectNoWorkflowBypass(releaseJob, steps);
    _expectPinnedReleaseContour(releaseJob, steps);
    _expectReleaseBenchmarkCommands(steps);
    _expectNoBaselineWrites(workflowContent);
    _expectNoDcmCommandsInCi();
  });

  test(
    'manual benchmark baseline update stays separate from release checks',
    () {
      final workflowFile = File(
        '.github/workflows/update_benchmark_baseline.yml',
      );

      expect(workflowFile.existsSync(), isTrue);

      final workflowContent = workflowFile.readAsStringSync();
      final updateJob = _workflowJob(
        workflowContent,
        'update-benchmark-baseline',
      );
      final steps = _workflowSteps(updateJob);

      expect(workflowContent, contains('workflow_dispatch:'));
      expect(workflowContent, isNot(contains('pull_request:')));
      expect(workflowContent, isNot(contains('push:')));
      expect(workflowContent, isNot(contains('schedule:')));
      _expectNoWorkflowBypass(updateJob, steps);
      _expectPinnedReleaseContour(updateJob, steps);
      _expectManualBaselineUpdateCommands(workflowContent, steps);
      expect(workflowContent, isNot(contains('git commit')));
      expect(workflowContent, isNot(contains('git push')));
      _expectNoDcmCommandsInCi();
    },
  );
}

void _expectRootPackageChecks(List<YamlMap> steps) {
  final runCommands = _runCommands(steps);
  final usedActions = _usedActions(steps);

  expect(usedActions, contains('actions/checkout@v4'));
  expect(usedActions, contains('subosito/flutter-action@v2'));
  expect(runCommands, contains('flutter pub get'));
  expect(
    runCommands,
    contains(
      "flutter test --concurrency=1 "
      r"$(find test -path test/benchmarks -prune -o -name '*_test.dart' -print)",
    ),
  );
  expect(runCommands, contains('dart analyze'));
  expect(runCommands, contains('dart run tool/guardrails/run.dart'));
}

void _expectExampleBoundaryDiffEnvironment(List<YamlMap> steps) {
  final checkoutStep = _stepNamed(steps, 'Checkout');
  final checkoutWith = checkoutStep['with'] as YamlMap;
  expect(checkoutWith['fetch-depth'], 0);

  final flutterTestStep = _stepNamed(
    steps,
    'Test all non-benchmark Flutter tests',
  );
  final env = flutterTestStep['env'] as YamlMap;
  expect(
    env['EXAMPLE_BOUNDARY_DIFF_BASE'],
    r"${{ github.event_name == 'pull_request' && github.event.pull_request.base.sha || '' }}",
  );
  expect(
    env['EXAMPLE_BOUNDARY_DIFF_HEAD'],
    r"${{ github.event_name == 'pull_request' && github.event.pull_request.head.sha || '' }}",
  );
}

void _expectRootPackageBenchmarkChecks(
  String workflowContent,
  List<YamlMap> steps,
) {
  final runCommands = _runCommands(steps);
  final benchmarkTestCommand = runCommands.singleWhere(
    _isDynamicBenchmarkTestCommand,
    orElse: () => '',
  );

  expect(
    runCommands,
    contains('dart run docs/tool/sync_generated_docs.dart --check'),
  );
  expect(runCommands, contains('dart run docs/tool/check_docs.dart'));
  expect(benchmarkTestCommand, _expectedBenchmarkTestCommand);
  for (final benchmarkTest in _benchmarkTestPaths()) {
    expect(
      _benchmarkCommandCoversPath(benchmarkTestCommand, benchmarkTest),
      isTrue,
      reason: benchmarkTest,
    );
  }
  expect(workflowContent, isNot(contains('tool/bench/update_baseline.dart')));
  expect(
    workflowContent,
    isNot(contains('tool/bench/run.dart --profile=release')),
  );
  expect(workflowContent, isNot(contains('paths-ignore:')));
  expect(workflowContent, isNot(contains('paths:')));
}

void _expectExamplePackageChecks(String workflowContent) {
  final workflow = _workflowYaml(workflowContent);
  final jobs = workflow['jobs'] as YamlMap;
  expect(jobs.containsKey('example-package'), isTrue);
  final exampleJob = jobs['example-package'] as YamlMap;
  final steps = _workflowSteps(exampleJob);
  final runCommands = _runCommands(steps);

  _expectNoWorkflowBypass(exampleJob, steps);
  expect(runCommands, contains('flutter pub get'));
  expect(runCommands, contains('flutter test'));
  expect(runCommands, contains('flutter analyze'));
  for (final stepName in [
    'Install example dependencies',
    'Test example package',
    'Analyze example package',
  ]) {
    expect(_stepNamed(steps, stepName)['working-directory'], 'example');
  }
}

void _expectGuardrailRunnerCannotBeBypassed(
  YamlMap rootPackageJob,
  YamlMap guardrailStep,
) {
  expect(rootPackageJob.containsKey('continue-on-error'), isFalse);
  expect(rootPackageJob.containsKey('if'), isFalse);
  expect(guardrailStep.containsKey('continue-on-error'), isFalse);
  expect(guardrailStep.containsKey('if'), isFalse);
}

void _expectFullGuardrailRunnerSelection(
  String workflowContent,
  YamlMap guardrailStep,
) {
  expect(
    (guardrailStep['run'] as String).trim(),
    equals('dart run tool/guardrails/run.dart'),
  );
  expect(workflowContent, isNot(contains('--guardrail=')));
  expect(workflowContent, isNot(contains('--suite=')));
  for (final id in guardrailInventory().keys) {
    expect(workflowContent, isNot(contains(id)));
  }
}

void _expectNoWorkflowBypass(YamlMap job, List<YamlMap> steps) {
  expect(job.containsKey('continue-on-error'), isFalse);
  expect(job.containsKey('if'), isFalse);
  for (final step in steps) {
    expect(step.containsKey('continue-on-error'), isFalse);
    expect(step.containsKey('if'), isFalse);
  }
}

void _expectPinnedReleaseContour(YamlMap job, List<YamlMap> steps) {
  expect(job['runs-on'], 'ubuntu-24.04');
  final flutterStep = _stepNamed(steps, 'Set up Flutter');
  expect(flutterStep['uses'], 'subosito/flutter-action@v2');
  final withConfig = flutterStep['with'] as YamlMap;
  expect(withConfig['channel'], 'stable');
  expect(withConfig['flutter-version'], '3.38.5');
}

void _expectReleaseBenchmarkCommands(List<YamlMap> steps) {
  final runCommands = _runCommands(steps);

  expect(
    runCommands,
    contains('dart run tool/bench/run.dart --profile=release'),
  );
  expect(
    runCommands,
    contains(
      'dart run tool/bench/diff.dart --profile=release '
      '--baseline=tool/bench/baselines/approved/'
      'release_ubuntu_24_04_flutter_3_38_5.json '
      '--current=build/bench/current/'
      'release_ubuntu_24_04_flutter_3_38_5.json '
      '--output=build/bench/diff/'
      'release_ubuntu_24_04_flutter_3_38_5.json',
    ),
  );
  expect(runCommands, contains('dart run tool/architecture_graph/check.dart'));
  expect(
    runCommands,
    contains('dart run tool/architecture_graph/generate_views.dart --check'),
  );
  expect(runCommands, contains('dart run tool/guardrails/run.dart'));
}

void _expectManualBaselineUpdateCommands(
  String workflowContent,
  List<YamlMap> steps,
) {
  final runCommands = _runCommands(steps);

  expect(
    workflowContent,
    contains(
      'build/bench/candidates/release_ubuntu_24_04_flutter_3_38_5/'
      r'${{ github.run_id }}.json',
    ),
  );
  expect(
    workflowContent,
    contains(
      'tool/bench/baselines/approved/'
      'release_ubuntu_24_04_flutter_3_38_5.json',
    ),
  );
  expect(
    runCommands,
    contains(
      'dart run tool/bench/run.dart --profile=release '
      r'--output=${CANDIDATE_PATH}',
    ),
  );
  expect(
    runCommands,
    contains(
      'dart run tool/bench/update_baseline.dart --profile=release '
      r'--candidate=${CANDIDATE_PATH} --approved=${APPROVED_PATH}',
    ),
  );
}

void _expectNoBaselineWrites(String workflowContent) {
  expect(workflowContent, isNot(contains('tool/bench/update_baseline.dart')));
  expect(workflowContent, isNot(contains('--approved=')));
}

void _expectNoDcmCommandsInCi() {
  for (final workflow in Directory('.github/workflows').listSync()) {
    if (workflow is! File || !_isWorkflowFile(workflow)) {
      continue;
    }
    final content = workflow.readAsStringSync();
    expect(content, isNot(contains('dcm analyze')));
    expect(content, isNot(contains('dcm calculate-metrics')));
  }
}

bool _isWorkflowFile(File workflow) {
  return workflow.path.endsWith('.yml') || workflow.path.endsWith('.yaml');
}

YamlMap _rootPackageJob(String workflowContent) {
  return _workflowJob(workflowContent, 'root-package');
}

YamlMap _workflowJob(String workflowContent, String jobId) {
  final workflow = _workflowYaml(workflowContent);
  final jobs = workflow['jobs'] as YamlMap;

  return jobs[jobId] as YamlMap;
}

YamlMap _workflowYaml(String workflowContent) {
  return loadYaml(workflowContent) as YamlMap;
}

List<YamlMap> _workflowSteps(YamlMap rootPackageJob) {
  return (rootPackageJob['steps'] as YamlList).cast<YamlMap>();
}

YamlMap _stepNamed(List<YamlMap> steps, String name) {
  return steps.singleWhere((step) => step['name'] == name);
}

Set<String> _runCommands(List<YamlMap> steps) {
  return steps
      .map((step) => step['run'])
      .whereType<String>()
      .map((command) => command.trim())
      .toSet();
}

Set<String> _usedActions(List<YamlMap> steps) {
  return steps
      .map((step) => step['uses'])
      .whereType<String>()
      .map((action) => action.trim())
      .toSet();
}

List<String> _benchmarkTestPaths() {
  return Directory('test/benchmarks')
      .listSync(followLinks: false)
      .whereType<File>()
      .map((file) => file.path.replaceAll('\\', '/'))
      .where((path) => path.endsWith('_test.dart'))
      .toList()
    ..sort();
}

bool _benchmarkCommandCoversPath(String command, String path) {
  const benchmarkDirectory = 'test/benchmarks/';
  final benchmarkFileName = path.replaceFirst(benchmarkDirectory, '');

  return command == _expectedBenchmarkTestCommand &&
      path.startsWith(benchmarkDirectory) &&
      !benchmarkFileName.contains('/') &&
      path.endsWith('_test.dart');
}

bool _isDynamicBenchmarkTestCommand(String command) {
  return command == _expectedBenchmarkTestCommand;
}

const _expectedBenchmarkTestCommand =
    "dart test \$(find test/benchmarks -maxdepth 1 -name '*_test.dart' -print | sort)";
