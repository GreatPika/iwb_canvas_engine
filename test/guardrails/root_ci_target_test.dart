import 'dart:io';

import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

import '../../tool/guardrails/src/guardrail_registry.dart';

void main() {
  test('root workflow runs repository-owned package checks', () {
    final workflowFile = File('.github/workflows/root_package.yml');

    expect(workflowFile.existsSync(), isTrue);

    final workflowContent = workflowFile.readAsStringSync();
    final steps = _workflowSteps(workflowContent);
    final runCommands = _runCommands(steps);
    final usedActions = _usedActions(steps);

    expect(usedActions, contains('actions/checkout@v4'));
    expect(usedActions, contains('subosito/flutter-action@v2'));
    expect(runCommands, contains('flutter pub get'));
    expect(runCommands, contains('dart analyze'));
    expect(runCommands, contains('dart run tool/guardrails/run.dart'));
    expect(workflowContent, isNot(contains('--guardrail=')));
    expect(workflowContent, isNot(contains('--suite=')));
    for (final id in guardrailInventory().keys) {
      expect(workflowContent, isNot(contains(id)));
    }
  });
}

List<YamlMap> _workflowSteps(String workflowContent) {
  final workflow = loadYaml(workflowContent) as YamlMap;
  final jobs = workflow['jobs'] as YamlMap;
  final rootPackageJob = jobs['root-package'] as YamlMap;

  return (rootPackageJob['steps'] as YamlList).cast<YamlMap>();
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
