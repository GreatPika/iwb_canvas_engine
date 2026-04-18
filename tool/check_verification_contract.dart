import 'dart:io';

import 'src/verification_contract/verification_contract_registry.dart';

const String _agentsPath = 'AGENTS.md';
const String _ciWorkflowPath = '.github/workflows/ci.yaml';
const String _perfNightlyWorkflowPath = perfNightlyWorkflowPath;

Future<void> main(List<String> _) async {
  final failures = <String>[
    ..._checkAgents(File(_agentsPath)),
    ..._checkCiWorkflow(File(_ciWorkflowPath)),
    ..._checkPerfNightlyWorkflow(File(_perfNightlyWorkflowPath)),
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

Iterable<String> _checkAgents(File file) sync* {
  if (!file.existsSync()) {
    yield 'Missing $_agentsPath.';
    return;
  }

  final content = file.readAsStringSync();
  if (content.contains('VERIFICATION.md')) {
    yield '$_agentsPath still references VERIFICATION.md.';
  }

  final verificationSection = _extractSection(content, '## Verification');
  if (verificationSection == null) {
    yield 'Failed to find `## Verification` section in $_agentsPath.';
    return;
  }

  final normalizedSection = _normalizeMarkdownText(verificationSection);
  final normalizedExpected = _normalizeMarkdownText(
    agentsVerificationInstruction,
  );
  if (!normalizedSection.startsWith(normalizedExpected)) {
    yield 'Verification instruction drifted in $_agentsPath.';
  }
}

Iterable<String> _checkCiWorkflow(File file) sync* {
  if (!file.existsSync()) {
    yield 'Missing $_ciWorkflowPath.';
    return;
  }

  final content = file.readAsStringSync();
  final runEntries = _parseRunEntries(content);
  final triggerEntries = _parseToolTestEntries(content);

  final expectedRuns = <String>{
    for (final entry in ciWorkflowRunExpectations)
      '${entry.cwd}|${entry.command}',
  };
  final actualRuns = <String>{
    for (final entry in runEntries) '${entry.cwd}|${entry.command}',
  };

  final missingRuns = expectedRuns.difference(actualRuns).toList()..sort();
  final extraTriggers =
      triggerEntries.difference(toolTestTriggerEntries.toSet()).toList()
        ..sort();
  final missingTriggers =
      toolTestTriggerEntries.toSet().difference(triggerEntries).toList()
        ..sort();

  for (final run in missingRuns) {
    yield '$_ciWorkflowPath is missing expected run entry `$run`.';
  }
  if (missingTriggers.isNotEmpty) {
    yield 'Entries missing from $_ciWorkflowPath tool_tests: ${missingTriggers.join(', ')}';
  }
  if (extraTriggers.isNotEmpty) {
    yield 'Unexpected $_ciWorkflowPath tool_tests entries: ${extraTriggers.join(', ')}';
  }
}

Iterable<String> _checkPerfNightlyWorkflow(File file) sync* {
  if (!file.existsSync()) {
    yield 'Missing $_perfNightlyWorkflowPath.';
    return;
  }

  final content = file.readAsStringSync();
  final runEntries = _parseRunEntries(content);
  final expectedRuns = <String>{
    for (final entry in perfNightlyWorkflowRunExpectations)
      '${entry.cwd}|${entry.command}',
  };
  final actualRuns = <String>{
    for (final entry in runEntries) '${entry.cwd}|${entry.command}',
  };
  final missingRuns = expectedRuns.difference(actualRuns).toList()..sort();

  for (final run in missingRuns) {
    yield '$_perfNightlyWorkflowPath is missing expected run entry `$run`.';
  }
}

String? _extractSection(String content, String heading) {
  final lines = content.split('\n');
  final startIndex = lines.indexOf(heading);
  if (startIndex == -1) {
    return null;
  }

  final buffer = StringBuffer();
  for (final line in lines.skip(startIndex + 1)) {
    if (line.startsWith('## ')) {
      break;
    }
    if (buffer.isNotEmpty) {
      buffer.writeln();
    }
    buffer.write(line);
  }
  return buffer.toString().trim();
}

String _normalizeMarkdownText(String value) {
  return value.split(RegExp(r'\s+')).where((part) => part.isNotEmpty).join(' ');
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

Set<String> _parseToolTestEntries(String content) {
  final lines = content.split('\n');
  var toolTestsIndent = -1;
  final entries = <String>{};

  for (final line in lines) {
    final trimmed = line.trimLeft();
    final indent = line.length - trimmed.length;
    if (toolTestsIndent == -1) {
      if (trimmed == 'tool_tests:') {
        toolTestsIndent = indent;
      }
      continue;
    }
    if (trimmed.isEmpty) {
      continue;
    }
    if (indent <= toolTestsIndent) {
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
