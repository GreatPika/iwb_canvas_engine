import 'dart:io';

import 'verification_contract_models.dart';
import 'verification_contract_registry.dart';

const String verificationPresetUsage = '''
Usage:
  dart run tool/run_verification_preset.dart resolve --format=json --preset=required_code_change --changed-paths-file=<path>
  dart run tool/run_verification_preset.dart run --preset=required_code_change --changed-paths-file=<path>
  dart run tool/run_verification_preset.dart resolve --scope=<scope> [--scope=<scope>...]
  dart run tool/run_verification_preset.dart run --scope=<scope> [--scope=<scope>...]
  dart run tool/run_verification_preset.dart resolve --tool-tests --changed-paths-file=<path>
  dart run tool/run_verification_preset.dart run --tool-tests --changed-paths-file=<path>
  dart run tool/run_verification_preset.dart resolve --tool-test-file=<path> [--tool-test-file=<path>...]
  dart run tool/run_verification_preset.dart run --tool-test-file=<path> [--tool-test-file=<path>...]
''';

VerificationInvocation parseVerificationInvocation(List<String> args) {
  if (args.isEmpty) {
    _failUsage('Missing command.');
  }

  final command = switch (args.first) {
    'resolve' => VerificationCommand.resolve,
    'run' => VerificationCommand.run,
    _ => _failUsage('Unknown command: ${args.first}'),
  };

  String? format;
  String? preset;
  final scopes = <String>[];
  var toolTests = false;
  final toolTestFiles = <String>[];
  String? changedPathsFile;
  final changedPaths = <String>[];

  for (final arg in args.skip(1)) {
    if (arg == '--help' || arg == '-h') {
      throw const VerificationExit(
        exitCode: 0,
        message: verificationPresetUsage,
      );
    }
    if (arg.startsWith('--format=')) {
      format = arg.substring('--format='.length);
      continue;
    }
    if (arg.startsWith('--preset=')) {
      preset = arg.substring('--preset='.length);
      continue;
    }
    if (arg.startsWith('--scope=')) {
      scopes.add(_normalizePathValue(arg.substring('--scope='.length)));
      continue;
    }
    if (arg == '--tool-tests') {
      toolTests = true;
      continue;
    }
    if (arg.startsWith('--tool-test-file=')) {
      toolTestFiles.add(
        _normalizePathValue(arg.substring('--tool-test-file='.length)),
      );
      continue;
    }
    if (arg.startsWith('--changed-paths-file=')) {
      if (changedPathsFile != null) {
        _failUsage('Repeat --changed-paths-file at most once.');
      }
      changedPathsFile = _normalizePathValue(
        arg.substring('--changed-paths-file='.length),
      );
      continue;
    }
    if (arg.startsWith('--changed-path=')) {
      changedPaths.add(
        _normalizePathValue(arg.substring('--changed-path='.length)),
      );
      continue;
    }
    _failUsage('Unsupported option: $arg');
  }

  return VerificationInvocation(
    command: command,
    format: format,
    preset: preset,
    scopes: List<String>.unmodifiable(scopes),
    toolTests: toolTests,
    toolTestFiles: List<String>.unmodifiable(toolTestFiles),
    changedPathsFile: changedPathsFile,
    changedPaths: List<String>.unmodifiable(
      _mergeChangedPathInputs(
        changedPathsFile: changedPathsFile,
        paths: changedPaths,
      ),
    ),
  );
}

ResolvedVerificationPlan resolveVerificationPlan(
  VerificationInvocation invocation,
) {
  final selectorModes = <VerificationMode>[
    if (invocation.preset != null) VerificationMode.preset,
    if (invocation.scopes.isNotEmpty) VerificationMode.scope,
    if (invocation.toolTests) VerificationMode.toolTests,
    if (invocation.toolTestFiles.isNotEmpty) VerificationMode.toolTestFile,
  ];
  if (selectorModes.isEmpty) {
    _failUsage('Choose exactly one selector mode.');
  }
  if (selectorModes.length != 1) {
    _failUsage('Selector modes cannot be mixed.');
  }

  return switch (selectorModes.single) {
    VerificationMode.preset => _resolvePreset(invocation),
    VerificationMode.scope => _resolveScopes(invocation),
    VerificationMode.toolTests => _resolveToolTests(invocation),
    VerificationMode.toolTestFile => _resolveToolTestFiles(invocation),
  };
}

ResolvedVerificationPlan _resolvePreset(VerificationInvocation invocation) {
  if (invocation.preset != requiredCodeChangePreset) {
    _failUsage('Unknown --preset value: ${invocation.preset}');
  }
  final changedPaths = _normalizeUnique(invocation.changedPaths);
  if (changedPaths.isEmpty) {
    _failUsage(
      '--preset required_code_change requires --changed-paths-file or at '
      'least one --changed-path.',
    );
  }

  final steps = <ResolvedVerificationStep>[
    for (final stepId in requiredCodeChangeStepIds)
      _resolvedStep(stepId, reason: 'preset:$requiredCodeChangePreset'),
    if (_shouldRunToolTests(changedPaths))
      _resolvedStep(
        'tool_tests',
        reason: 'preset:$requiredCodeChangePreset:tool_tests',
      ),
  ];

  return ResolvedVerificationPlan(
    mode: VerificationMode.preset,
    selectors: const <String>[requiredCodeChangePreset],
    steps: steps,
  );
}

ResolvedVerificationPlan _resolveScopes(VerificationInvocation invocation) {
  if (invocation.changedPaths.isNotEmpty) {
    _failUsage(
      '--changed-path and --changed-paths-file are only supported with '
      '--preset or --tool-tests.',
    );
  }
  final requestedScopes = _normalizeUnique(invocation.scopes);
  final selectedScopes = <String>[
    for (final scope in verificationScopes)
      if (requestedScopes.contains(scope)) scope,
  ];
  final unknownScopes = requestedScopes
      .where((scope) => !verificationScopeStepIds.containsKey(scope))
      .toList();
  if (unknownScopes.isNotEmpty) {
    _failUsage('Unknown --scope value: ${unknownScopes.first}');
  }

  return ResolvedVerificationPlan(
    mode: VerificationMode.scope,
    selectors: selectedScopes,
    steps: <ResolvedVerificationStep>[
      for (final scope in selectedScopes)
        _resolvedStep(verificationScopeStepIds[scope]!, reason: 'scope:$scope'),
    ],
  );
}

ResolvedVerificationPlan _resolveToolTests(VerificationInvocation invocation) {
  if (invocation.changedPaths.isEmpty) {
    _failUsage(
      '--tool-tests requires --changed-paths-file or at least one '
      '--changed-path.',
    );
  }
  final changedPaths = _normalizeUnique(invocation.changedPaths);

  return ResolvedVerificationPlan(
    mode: VerificationMode.toolTests,
    selectors: changedPaths,
    steps: _shouldRunToolTests(changedPaths)
        ? <ResolvedVerificationStep>[
            _resolvedStep('tool_tests', reason: 'tool_tests:changed_path'),
          ]
        : const <ResolvedVerificationStep>[],
  );
}

ResolvedVerificationPlan _resolveToolTestFiles(
  VerificationInvocation invocation,
) {
  if (invocation.changedPaths.isNotEmpty) {
    _failUsage(
      '--changed-path and --changed-paths-file are not supported with '
      '--tool-test-file.',
    );
  }

  final files = _normalizeUniquePreserveOrder(invocation.toolTestFiles);
  final validatedFiles = <String>[];
  for (final file in files) {
    if (!_isValidToolTestFileSelection(file)) {
      _failUsage('Unknown --tool-test-file path: $file');
    }
    validatedFiles.add(file);
  }

  final command = StringBuffer(verificationSteps['tool_tests']!.command);
  for (final file in validatedFiles) {
    command.write(' $file');
  }

  return ResolvedVerificationPlan(
    mode: VerificationMode.toolTestFile,
    selectors: validatedFiles,
    steps: <ResolvedVerificationStep>[
      ResolvedVerificationStep(
        id: 'tool_tests',
        kind: VerificationStepKind.toolTests,
        command: command.toString(),
        cwd: '.',
        reason: 'tool_test_file:explicit',
      ),
    ],
  );
}

ResolvedVerificationStep _resolvedStep(
  String stepId, {
  required String reason,
}) {
  final definition = verificationSteps[stepId];
  if (definition == null) {
    throw StateError('Unknown verification step id: $stepId');
  }
  return ResolvedVerificationStep(
    id: definition.id,
    kind: definition.kind,
    command: definition.command,
    cwd: definition.cwd,
    reason: reason,
  );
}

bool shouldRunToolTestsForChangedPaths(List<String> changedPaths) {
  return _shouldRunToolTests(changedPaths);
}

bool _shouldRunToolTests(List<String> changedPaths) {
  for (final changedPath in changedPaths) {
    for (final trigger in toolTestTriggerEntries) {
      if (_matchesTrigger(changedPath, trigger)) {
        return true;
      }
    }
  }
  return false;
}

bool _matchesTrigger(String path, String trigger) {
  if (trigger.endsWith('/**')) {
    final prefix = trigger.substring(0, trigger.length - 3);
    return path == prefix || path.startsWith('$prefix/');
  }
  return path == trigger;
}

List<String> normalizeChangedPaths(Iterable<String> paths) {
  return _normalizeUnique(paths);
}

List<String> _mergeChangedPathInputs({
  required String? changedPathsFile,
  required List<String> paths,
}) {
  if (changedPathsFile == null) {
    return paths;
  }

  final file = File(changedPathsFile);
  if (!file.existsSync()) {
    _failUsage('Changed paths file not found: $changedPathsFile');
  }

  return <String>[
    ...paths,
    ...file
        .readAsLinesSync()
        .map(_normalizePathValue)
        .where((line) => line.isNotEmpty),
  ];
}

List<String> _normalizeUnique(Iterable<String> values) {
  final seen = <String>{};
  final normalized = <String>[];
  for (final value in values) {
    final candidate = _normalizePathValue(value);
    if (candidate.isEmpty || !seen.add(candidate)) {
      continue;
    }
    normalized.add(candidate);
  }
  normalized.sort();
  return normalized;
}

List<String> _normalizeUniquePreserveOrder(Iterable<String> values) {
  final seen = <String>{};
  final normalized = <String>[];
  for (final value in values) {
    final candidate = _normalizePathValue(value);
    if (candidate.isEmpty || !seen.add(candidate)) {
      continue;
    }
    normalized.add(candidate);
  }
  return normalized;
}

String _normalizePathValue(String value) {
  var normalized = value.replaceAll(r'\', '/').trim();
  while (normalized.startsWith('./')) {
    normalized = normalized.substring(2);
  }
  if (normalized.endsWith('/')) {
    normalized = normalized.substring(0, normalized.length - 1);
  }
  return normalized;
}

bool _isValidToolTestFileSelection(String path) {
  if (!path.startsWith('test/tool/') || !path.endsWith('_test.dart')) {
    return false;
  }
  if (path.contains('/support/')) {
    return false;
  }
  return File(path).existsSync();
}

Never _failUsage(String message) {
  throw VerificationExit(
    exitCode: 64,
    message: '$message\n$verificationPresetUsage',
  );
}
