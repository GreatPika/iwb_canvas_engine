enum VerificationMode {
  preset('preset'),
  scope('scope'),
  toolTests('tool_tests'),
  toolTestFile('tool_test_file');

  const VerificationMode(this.code);

  final String code;
}

enum VerificationStepKind {
  shell('shell'),
  toolTests('tool_tests'),
  driftCheck('drift_check');

  const VerificationStepKind(this.code);

  final String code;
}

class VerificationStepDefinition {
  const VerificationStepDefinition({
    required this.id,
    required this.kind,
    required this.command,
    this.cwd = '.',
  });

  final String id;
  final VerificationStepKind kind;
  final String command;
  final String cwd;
}

class VerificationRunExpectation {
  const VerificationRunExpectation({required this.command, this.cwd = '.'});

  final String command;
  final String cwd;
}

class ResolvedVerificationStep {
  const ResolvedVerificationStep({
    required this.id,
    required this.kind,
    required this.command,
    required this.cwd,
    required this.reason,
  });

  final String id;
  final VerificationStepKind kind;
  final String command;
  final String cwd;
  final String reason;
}

class ResolvedVerificationPlan {
  const ResolvedVerificationPlan({
    required this.mode,
    required this.selectors,
    required this.steps,
  });

  final VerificationMode mode;
  final List<String> selectors;
  final List<ResolvedVerificationStep> steps;
}

class VerificationInvocation {
  const VerificationInvocation({
    required this.command,
    required this.format,
    required this.preset,
    required this.scopes,
    required this.toolTests,
    required this.toolTestFiles,
    required this.changedPathsFile,
    required this.changedPaths,
  });

  final VerificationCommand command;
  final String? format;
  final String? preset;
  final List<String> scopes;
  final bool toolTests;
  final List<String> toolTestFiles;
  final String? changedPathsFile;
  final List<String> changedPaths;
}

enum VerificationCommand { resolve, run }

class VerificationExit implements Exception {
  const VerificationExit({required this.exitCode, required this.message});

  final int exitCode;
  final String message;
}
