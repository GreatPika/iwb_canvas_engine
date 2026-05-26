import 'dart:io';

import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

import '../../tool/guardrails/src/guardrail_registry.dart';

void main() {
  test('root workflow runs repository-owned package checks', () {
    final workflowFile = File('.github/workflows/root_package.yml');

    expect(workflowFile.existsSync(), isTrue);

    final workflowContent = workflowFile.readAsStringSync();
    final rootPackageJob = _rootPackageJob(workflowContent);
    final steps = _workflowSteps(rootPackageJob);
    final guardrailStep = _stepNamed(steps, 'Run guardrails');

    _expectRootPackageChecks(steps);
    _expectGuardrailRunnerCannotBeBypassed(rootPackageJob, guardrailStep);
    _expectFullGuardrailRunnerSelection(workflowContent, guardrailStep);
  });
}

void _expectRootPackageChecks(List<YamlMap> steps) {
  final runCommands = _runCommands(steps);
  final usedActions = _usedActions(steps);

  expect(usedActions, contains('actions/checkout@v4'));
  expect(usedActions, contains('subosito/flutter-action@v2'));
  expect(runCommands, contains('flutter pub get'));
  expect(runCommands, contains('dart analyze'));
  expect(runCommands, contains('dart run tool/guardrails/run.dart'));
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

YamlMap _rootPackageJob(String workflowContent) {
  final workflow = loadYaml(workflowContent) as YamlMap;
  final jobs = workflow['jobs'] as YamlMap;

  return jobs['root-package'] as YamlMap;
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
