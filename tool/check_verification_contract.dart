import 'dart:io';

import 'package:yaml/yaml.dart';

import 'src/verification_contract/verification_contract_models.dart';
import 'src/verification_contract/verification_contract_registry.dart';

Future<void> main(List<String> _) async {
  final failures = <String>[
    ..._checkWorkflow(File(ciWorkflowPath), ciWorkflowDefinition),
    ..._checkWorkflow(
      File(perfNightlyWorkflowPath),
      perfNightlyWorkflowDefinition,
    ),
  ];

  if (failures.isNotEmpty) {
    stderr.writeln('FAIL: verification contract drift detected.');
    for (final failure in failures) {
      stderr.writeln('- $failure');
    }
    exitCode = 1;
    return;
  }

  stdout.writeln(
    'Verification contract OK '
    '(${toolTestTriggerEntries.length} trigger entries, '
    '${ciWorkflowRunExpectations.length} CI run entries).',
  );
}

Iterable<String> _checkWorkflow(
  File file,
  VerificationWorkflowDefinition workflow,
) sync* {
  if (!file.existsSync()) {
    yield 'Missing ${workflow.path}.';
    return;
  }

  final content = file.readAsStringSync();
  late final _WorkflowDocument workflowDocument;
  try {
    workflowDocument = _parseWorkflowDocument(content);
  } on _WorkflowParseException catch (error) {
    yield '${workflow.path} ${error.message}';
    return;
  }
  final expectedRuns = <String>[
    for (final entry in workflow.runExpectations)
      '${entry.cwd}|${entry.command}',
  ];
  final actualRuns = <String>[
    for (final entry in workflowDocument.runEntries)
      '${entry.cwd}|${entry.command}',
  ];

  final missingRuns = _multisetDifference(expectedRuns, actualRuns);
  final unexpectedRuns = workflow.ownsEntireExecutableRunSurface
      ? _multisetDifference(actualRuns, expectedRuns)
      : const <String>[];

  for (final run in missingRuns) {
    yield '${workflow.path} is missing expected run entry `$run`.';
  }
  for (final run in unexpectedRuns) {
    yield '${workflow.path} has unexpected executable run entry `$run`.';
  }

  for (final filterEntry in workflow.changeFilters.entries) {
    final actualEntries = workflowDocument.filterEntries(filterEntry.key);
    final expectedEntries = filterEntry.value.toSet();
    final extraEntries = actualEntries.difference(expectedEntries).toList()
      ..sort();
    final missingEntries = expectedEntries.difference(actualEntries).toList()
      ..sort();
    if (missingEntries.isNotEmpty) {
      yield 'Entries missing from ${workflow.path} ${filterEntry.key}: ${missingEntries.join(', ')}';
    }
    if (extraEntries.isNotEmpty) {
      yield 'Unexpected ${workflow.path} ${filterEntry.key} entries: ${extraEntries.join(', ')}';
    }
  }
}

List<String> _multisetDifference(
  Iterable<String> left,
  Iterable<String> right,
) {
  final remaining = <String, int>{};
  for (final value in right) {
    remaining.update(value, (count) => count + 1, ifAbsent: () => 1);
  }

  final difference = <String>[];
  for (final value in left) {
    final available = remaining[value] ?? 0;
    if (available == 0) {
      difference.add(value);
      continue;
    }
    if (available == 1) {
      remaining.remove(value);
      continue;
    }
    remaining[value] = available - 1;
  }

  difference.sort();
  return difference;
}

_WorkflowDocument _parseWorkflowDocument(String content) {
  final document = _loadYamlMap(content, context: 'contains invalid YAML');
  if (document is! YamlMap) {
    return const _WorkflowDocument();
  }

  final runEntries = <_WorkflowRunEntry>[];
  final filterEntriesByName = <String, Set<String>>{};

  final topLevelDefaults = _defaultsRunMap(document['defaults']);
  final jobsNode = document['jobs'];
  if (jobsNode is! YamlMap) {
    return _WorkflowDocument(
      runEntries: runEntries,
      filterEntriesByName: filterEntriesByName,
    );
  }

  for (final jobNode in jobsNode.nodes.values) {
    if (jobNode is! YamlMap) {
      continue;
    }

    final jobDefaults = _defaultsRunMap(jobNode['defaults']);
    final jobWorkingDirectory =
        _stringFromYaml(jobDefaults?['working-directory']) ??
        _stringFromYaml(topLevelDefaults?['working-directory']) ??
        '.';

    final stepsNode = jobNode['steps'];
    if (stepsNode is! YamlList) {
      continue;
    }

    for (final stepNode in stepsNode.nodes) {
      if (stepNode is! YamlMap) {
        continue;
      }

      final stepWorkingDirectory =
          _stringFromYaml(stepNode['working-directory']) ?? jobWorkingDirectory;
      final runCommand = _stringFromYaml(stepNode['run']);
      if (runCommand != null) {
        runEntries.add(
          _WorkflowRunEntry(cwd: stepWorkingDirectory, command: runCommand),
        );
      }

      final withNode = stepNode['with'];
      if (withNode is! YamlMap) {
        continue;
      }

      for (final withEntry in withNode.nodes.entries) {
        final filterDocument = _stringFromYaml(withEntry.value);
        if (filterDocument == null) {
          continue;
        }
        final filterName = _stringFromYaml(withEntry.key) ?? 'unknown';
        final parsedFilters = _parseNestedFilterDocument(
          filterDocument,
          filterName: filterName,
        );
        for (final parsedEntry in parsedFilters.entries) {
          final bucket = filterEntriesByName.putIfAbsent(
            parsedEntry.key,
            () => <String>{},
          );
          bucket.addAll(parsedEntry.value);
        }
      }
    }
  }

  return _WorkflowDocument(
    runEntries: runEntries,
    filterEntriesByName: filterEntriesByName,
  );
}

Map<String, Set<String>> _parseNestedFilterDocument(
  String content, {
  required String filterName,
}) {
  final document = _loadYamlMap(
    content,
    context: 'has invalid YAML in `$filterName` filter definition',
  );
  if (document is! YamlMap) {
    return const <String, Set<String>>{};
  }

  final parsed = <String, Set<String>>{};
  for (final entry in document.nodes.entries) {
    final name = _stringFromYaml(entry.key);
    final value = entry.value;
    if (name == null || value is! YamlList) {
      continue;
    }
    parsed[name] = <String>{
      for (final item in value.nodes)
        if (_stringFromYaml(item) case final filterEntry?) filterEntry,
    };
  }
  return parsed;
}

YamlNode _loadYamlMap(String content, {required String context}) {
  try {
    return loadYamlNode(content);
  } on YamlException catch (error) {
    throw _WorkflowParseException('$context (${error.message.trim()})');
  }
}

YamlMap? _defaultsRunMap(Object? node) {
  if (node is! YamlMap) {
    return null;
  }
  final runNode = node['run'];
  return runNode is YamlMap ? runNode : null;
}

String? _stringFromYaml(Object? node) {
  if (node == null) {
    return null;
  }
  if (node is YamlScalar) {
    final value = node.value;
    return value?.toString().trimRight();
  }
  if (node is String) {
    return node.trimRight();
  }
  return node.toString().trimRight();
}

class _WorkflowRunEntry {
  const _WorkflowRunEntry({required this.cwd, required this.command});

  final String cwd;
  final String command;
}

class _WorkflowDocument {
  const _WorkflowDocument({
    this.runEntries = const <_WorkflowRunEntry>[],
    this.filterEntriesByName = const <String, Set<String>>{},
  });

  final List<_WorkflowRunEntry> runEntries;
  final Map<String, Set<String>> filterEntriesByName;

  Set<String> filterEntries(String name) =>
      filterEntriesByName[name] ?? const <String>{};
}

class _WorkflowParseException implements Exception {
  const _WorkflowParseException(this.message);

  final String message;
}
