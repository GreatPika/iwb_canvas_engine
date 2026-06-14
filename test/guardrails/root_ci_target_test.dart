import 'dart:io';

import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

import '../../tool/guardrails/src/guardrail_registry.dart';

// CI structural tests keep root package checks and bypass rules together so the
// workflow contract is reviewed in one place.
// ignore: halstead-volume, source-lines-of-code
void main() {
  test('root workflow runs repository-owned package checks', () {
    final workflowFile = File('.github/workflows/root_package.yml');

    expect(workflowFile.existsSync(), isTrue);

    final workflowContent = workflowFile.readAsStringSync();
    final rootPackageJob = _rootPackageJob(workflowContent);
    final steps = _workflowSteps(rootPackageJob);
    final guardrailStep = _stepNamed(steps, 'Run guardrails');

    _expectRootPackageChecks(workflowContent, steps);
    _expectRootPackageBenchmarkChecks(workflowContent, steps);
    _expectExamplePackageChecks(workflowContent);
    _expectExampleBoundaryDiffEnvironment(steps);
    _expectNoWorkflowBypass(rootPackageJob, steps);
    _expectGuardrailRunnerCannotBeBypassed(rootPackageJob, guardrailStep);
    _expectFullGuardrailRunnerSelection(workflowContent, guardrailStep);
    _expectNoDcmCommandsInCi();
  });
}

void _expectRootPackageChecks(String workflowContent, List<YamlMap> steps) {
  final runCommands = _runCommands(steps);

  _expectPinnedActionStep(
    workflowContent,
    steps,
    stepName: 'Checkout',
    actionName: 'actions/checkout',
    versionComment: '# v4',
  );
  _expectPinnedActionStep(
    workflowContent,
    steps,
    stepName: 'Set up Flutter',
    actionName: 'subosito/flutter-action',
    versionComment: '# v2',
  );
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

void _expectPinnedActionStep(
  String workflowContent,
  List<YamlMap> steps, {
  required String stepName,
  required String actionName,
  required String versionComment,
}) {
  final uses = _stepNamed(steps, stepName)['uses'] as String;
  final prefix = '$actionName@';

  expect(uses.startsWith(prefix), isTrue);
  final pinnedRef = uses.replaceFirst(prefix, '');
  expect(pinnedRef, matches(RegExp(r'^[0-9a-f]{40}$')));
  expect(
    workflowContent.split('\n').map((line) => line.trim()),
    contains('uses: $uses $versionComment'),
  );
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
