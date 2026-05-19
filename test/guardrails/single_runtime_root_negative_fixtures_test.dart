import 'package:test/test.dart';

import '../../tool/guardrails/src/core_boundary_checks.dart';

void main() {
  test('RuntimeRoot is owned by the internal runtime path', () {
    final violations = checkRuntimeRootDeclarations([
      'lib/src/api/runtime_root.dart',
    ]);

    expect(violations.map((violation) => violation.guardrailId), [
      'core.single_runtime_root',
    ]);
  });

  test('exactly one RuntimeRoot is required', () {
    final violations = checkRuntimeRootDeclarations([
      'lib/src/runtime/runtime_root.dart',
      'lib/src/runtime/duplicate_runtime_root.dart',
    ]);

    expect(violations.map((violation) => violation.guardrailId), [
      'core.single_runtime_root',
    ]);
  });

  test('non-class RuntimeRoot declarations are duplicates', () {
    final duplicateDeclarations = runtimeRootDeclarationsForFile(
      path: 'lib/src/runtime/runtime_root_alias.dart',
      content: 'typedef RuntimeRoot = Object;',
    );
    final violations = checkRuntimeRootDeclarations([
      'lib/src/runtime/runtime_root.dart',
      ...duplicateDeclarations,
    ]);

    expect(violations.map((violation) => violation.guardrailId), [
      'core.single_runtime_root',
    ]);
  });
}
