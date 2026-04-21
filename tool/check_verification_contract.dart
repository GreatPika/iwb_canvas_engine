import 'dart:io';

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
  final runEntries = _parseRunEntries(content);
  final expectedRuns = <String>{
    for (final entry in workflow.runExpectations)
      '${entry.cwd}|${entry.command}',
  };
  final actualRuns = <String>{
    for (final entry in runEntries) '${entry.cwd}|${entry.command}',
  };

  final missingRuns = expectedRuns.difference(actualRuns).toList()..sort();

  for (final run in missingRuns) {
    yield '${workflow.path} is missing expected run entry `$run`.';
  }

  for (final filterEntry in workflow.changeFilters.entries) {
    final actualEntries = _parseFilterEntries(content, filterEntry.key);
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

List<_WorkflowRunEntry> _parseRunEntries(String content) {
  final lines = content.split('\n');
  final entries = <_WorkflowRunEntry>[];
  String currentWorkingDirectory = '.';

  for (final line in lines) {
    final trimmed = line.trimLeft();
    if (trimmed.startsWith('working-directory: ')) {
      currentWorkingDirectory = trimmed
          .substring('working-directory: '.length)
          .trim();
      continue;
    }
    if (trimmed.startsWith('- name: ')) {
      currentWorkingDirectory = '.';
      continue;
    }
    if (trimmed.startsWith('run: ')) {
      entries.add(
        _WorkflowRunEntry(
          cwd: currentWorkingDirectory,
          command: trimmed.substring('run: '.length).trim(),
        ),
      );
    }
  }

  return entries;
}

Set<String> _parseFilterEntries(String content, String filterName) {
  final lines = content.split('\n');
  var filterIndent = -1;
  final entries = <String>{};

  for (final line in lines) {
    final trimmed = line.trimLeft();
    final indent = line.length - trimmed.length;
    if (filterIndent == -1) {
      if (trimmed == '$filterName:') {
        filterIndent = indent;
      }
      continue;
    }
    if (trimmed.isEmpty) {
      continue;
    }
    if (indent <= filterIndent) {
      break;
    }
    if (!trimmed.startsWith('- ')) {
      continue;
    }
    entries.add(_normalizeTriggerEntry(trimmed.substring(2)));
  }

  return entries;
}

String _normalizeTriggerEntry(String value) {
  var normalized = value.trim();
  if (normalized.startsWith("'") && normalized.endsWith("'")) {
    normalized = normalized.substring(1, normalized.length - 1);
  }
  if (normalized.startsWith('"') && normalized.endsWith('"')) {
    normalized = normalized.substring(1, normalized.length - 1);
  }
  if (normalized.startsWith('`') && normalized.endsWith('`')) {
    normalized = normalized.substring(1, normalized.length - 1);
  }
  return normalized;
}

class _WorkflowRunEntry {
  const _WorkflowRunEntry({required this.cwd, required this.command});

  final String cwd;
  final String command;
}
