import 'dart:io';

typedef GuardrailAction = Future<GuardrailCheckResult> Function(Directory root);

final class GuardrailDefinition {
  const GuardrailDefinition({
    required this.id,
    required this.suite,
    required this.description,
    required this.run,
  });

  final String id;
  final String suite;
  final String description;
  final GuardrailAction run;
}

final class GuardrailCheckResult {
  const GuardrailCheckResult(this.violations);

  factory GuardrailCheckResult.pass() {
    return const GuardrailCheckResult(<String>[]);
  }

  factory GuardrailCheckResult.fail(Iterable<String> violations) {
    return GuardrailCheckResult(List<String>.unmodifiable(violations));
  }

  final List<String> violations;

  bool get passed => violations.isEmpty;
}
