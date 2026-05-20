import 'dart:io';

import 'core_boundary_checks.dart';
import 'guardrail_registry.dart';
import 'guardrail_violation.dart';
import 'public_api_checks.dart';

final class GuardrailRunResult {
  const GuardrailRunResult({
    required this.ranGuardrailIds,
    required this.exitCode,
  });

  final List<String> ranGuardrailIds;
  final int exitCode;
}

Future<GuardrailRunResult> runGuardrails(Iterable<String> ids) async {
  final ran = <String>[];

  for (final id in ids) {
    ran.add(id);
    final exitCode = await _runGuardrail(id);
    if (exitCode != 0) {
      return GuardrailRunResult(ranGuardrailIds: ran, exitCode: exitCode);
    }
  }

  return GuardrailRunResult(ranGuardrailIds: ran, exitCode: 0);
}

Future<int> _runGuardrail(String id) async {
  switch (id) {
    case 'api.no_legacy_public_types':
      return _reportViolations(id, await checkNoLegacyPublicTypes());
    case 'api.public_exports_complete':
      return _reportViolations(id, await checkPublicExportsComplete());
    case 'api.public_types_complete':
      return _reportViolations(id, await checkPublicTypesComplete());
    case 'core.no_legacy_imports':
    case 'core.import_boundaries':
    case 'core.no_unapproved_part_files':
    case 'core.no_scene_controller_shape_dependency':
    case 'core.no_node_spec_patch_shape_dependency':
      return _reportViolations(id, [
        ...await checkCoreBoundaries(),
        ..._negativeFixtureViolationsFor(id),
      ]);
    case 'core.single_runtime_root':
      return _reportViolations(id, checkSingleRuntimeRoot());
  }

  stderr.writeln('Unknown guardrail: $id');

  return 64;
}

int _reportViolations(String id, Iterable<GuardrailViolation> violations) {
  final matching = violations.where((violation) => violation.guardrailId == id);
  if (matching.isEmpty) {
    return 0;
  }

  for (final violation in matching) {
    stderr.writeln(violation);
  }

  return 1;
}

Iterable<GuardrailViolation> _negativeFixtureViolationsFor(String id) {
  if (!blockingGuardrailIds().contains(id)) {
    return const [];
  }

  return const [];
}
