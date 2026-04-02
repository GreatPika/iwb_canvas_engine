import 'dart:io';

const String _ciWorkflowPath = '.github/workflows/ci.yaml';
const String _verificationPath = 'VERIFICATION.md';
const String _verificationTriggerListAnchor =
    'list in this file must stay identical to `.github/workflows/ci.yaml`:';
const Set<String> _requiredTriggerEntries = <String>{
  'lib/iwb_canvas_engine.dart',
};

Future<void> main(List<String> _) async {
  final ciEntries = _parseCiToolTestEntries(File(_ciWorkflowPath));
  final verificationEntries = _parseVerificationToolTestEntries(
    File(_verificationPath),
  );

  final failures = <String>[
    ..._validateRequiredEntries(
      sourceLabel: _ciWorkflowPath,
      entries: ciEntries,
    ),
    ..._validateRequiredEntries(
      sourceLabel: _verificationPath,
      entries: verificationEntries,
    ),
    ..._validateDrift(ciEntries, verificationEntries),
  ];

  if (failures.isNotEmpty) {
    stderr.writeln('FAIL: tool-test trigger surface drift detected.');
    for (final failure in failures) {
      stderr.writeln('- $failure');
    }
    exitCode = 1;
    return;
  }

  stdout.writeln(
    'Tool-test trigger surface OK '
    '(${ciEntries.length} synchronized entries).',
  );
}

Set<String> _parseCiToolTestEntries(File file) {
  final lines = file.readAsLinesSync();
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

    entries.add(_normalizePathEntry(trimmed.substring(2)));
  }

  if (toolTestsIndent == -1) {
    throw StateError('Failed to find `tool_tests:` block in $_ciWorkflowPath.');
  }
  if (entries.isEmpty) {
    throw StateError(
      'Expected $_ciWorkflowPath to define at least one `tool_tests` entry.',
    );
  }
  return entries;
}

Set<String> _parseVerificationToolTestEntries(File file) {
  final lines = file.readAsLinesSync();
  final anchorIndex = lines.indexWhere(
    (line) => line.contains(_verificationTriggerListAnchor),
  );
  if (anchorIndex == -1) {
    throw StateError(
      'Failed to find tool-test trigger list anchor in $_verificationPath.',
    );
  }

  final entries = <String>{};
  for (final line in lines.skip(anchorIndex + 1)) {
    if (!line.startsWith('  - ')) {
      break;
    }

    entries.add(_normalizePathEntry(line.substring(4)));
  }

  if (entries.isEmpty) {
    throw StateError(
      'Expected $_verificationPath to document at least one tool-test '
      'trigger entry.',
    );
  }
  return entries;
}

Iterable<String> _validateRequiredEntries({
  required String sourceLabel,
  required Set<String> entries,
}) sync* {
  for (final requiredEntry in _requiredTriggerEntries) {
    if (!entries.contains(requiredEntry)) {
      yield '$sourceLabel is missing required trigger entry '
          '`$requiredEntry`.';
    }
  }
}

Iterable<String> _validateDrift(
  Set<String> ciEntries,
  Set<String> docEntries,
) sync* {
  final ciOnly = ciEntries.difference(docEntries).toList()..sort();
  final verificationOnly = docEntries.difference(ciEntries).toList()..sort();

  if (ciOnly.isNotEmpty) {
    yield 'Entries present only in $_ciWorkflowPath: ${ciOnly.join(', ')}';
  }
  if (verificationOnly.isNotEmpty) {
    yield 'Entries present only in $_verificationPath: '
        '${verificationOnly.join(', ')}';
  }
}

String _normalizePathEntry(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) {
    throw StateError('Encountered an empty trigger-surface entry.');
  }

  var value = trimmed;
  if (value.startsWith('`') && value.endsWith('`') && value.length >= 2) {
    value = value.substring(1, value.length - 1);
  }
  if (value.startsWith("'") && value.endsWith("'") && value.length >= 2) {
    value = value.substring(1, value.length - 1);
  }
  if (value.startsWith('"') && value.endsWith('"') && value.length >= 2) {
    value = value.substring(1, value.length - 1);
  }

  return value.trim();
}
