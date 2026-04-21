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

class VerificationScopeDefinition {
  const VerificationScopeDefinition({required this.id, required this.stepId});

  final String id;
  final String stepId;
}

class VerificationPresetDefinition {
  const VerificationPresetDefinition({
    required this.id,
    required this.stepIds,
    this.runsToolTestsOnMatchingChanges = false,
  });

  final String id;
  final List<String> stepIds;
  final bool runsToolTestsOnMatchingChanges;
}

class VerificationWorkflowDefinition {
  const VerificationWorkflowDefinition({
    required this.path,
    required this.runExpectations,
    this.changeFilters = const <String, List<String>>{},
  });

  final String path;
  final List<VerificationRunExpectation> runExpectations;
  final Map<String, List<String>> changeFilters;
}

class VerificationGraph {
  const VerificationGraph({
    required this.steps,
    required this.scopes,
    required this.presets,
    required this.workflows,
  });

  final Map<String, VerificationStepDefinition> steps;
  final List<VerificationScopeDefinition> scopes;
  final Map<String, VerificationPresetDefinition> presets;
  final Map<String, VerificationWorkflowDefinition> workflows;

  List<String> get scopeIds =>
      List<String>.unmodifiable(scopes.map((scope) => scope.id));

  Map<String, String> get scopeStepIds => Map<String, String>.unmodifiable(
    <String, String>{for (final scope in scopes) scope.id: scope.stepId},
  );

  String? scopeStepIdForScope(String scopeId) {
    for (final scope in scopes) {
      if (scope.id == scopeId) {
        return scope.stepId;
      }
    }
    return null;
  }

  VerificationPresetDefinition? preset(String presetId) => presets[presetId];

  VerificationWorkflowDefinition? workflow(String path) => workflows[path];
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
