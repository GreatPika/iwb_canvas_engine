import 'dart:io';

import 'core_boundary_checks.dart';
import 'guardrail_registry.dart';
import 'guardrail_violation.dart';
import 'public_api_checks.dart';
import 'public_api_contract_checks.dart';

typedef GuardrailProofRunner =
    Future<int> Function(String guardrailId, String path);

final class GuardrailRoute {
  const GuardrailRoute._({required this.kind, required this.target});

  const GuardrailRoute.dartTest(String path)
    : this._(kind: 'dart test', target: path);

  const GuardrailRoute.structural(String description)
    : this._(kind: 'structural', target: description);

  final String kind;
  final String target;

  String get description => '$kind $target';
}

final class GuardrailRunResult {
  const GuardrailRunResult({
    required this.ranGuardrailIds,
    required this.exitCode,
  });

  final List<String> ranGuardrailIds;
  final int exitCode;
}

Future<GuardrailRunResult> runGuardrails(Iterable<String> ids) {
  return runGuardrailsWithProofRunner(ids, runDartTest: _runDartTest);
}

Future<GuardrailRunResult> runGuardrailsWithProofRunner(
  Iterable<String> ids, {
  required GuardrailProofRunner runDartTest,
}) async {
  final ran = <String>[];
  final proofExitCodes = <String, Future<int>>{};

  for (final id in ids) {
    ran.add(id);
    final exitCode = await _runGuardrail(
      id,
      proofExitCodes: proofExitCodes,
      runDartTest: runDartTest,
    );
    if (exitCode != 0) {
      return GuardrailRunResult(ranGuardrailIds: ran, exitCode: exitCode);
    }
  }

  return GuardrailRunResult(ranGuardrailIds: ran, exitCode: 0);
}

GuardrailRoute? guardrailRouteFor(String id) {
  final proofPath = _testProofPaths[id];
  if (proofPath != null) {
    return GuardrailRoute.dartTest(proofPath);
  }

  if (_violationChecks.containsKey(id)) {
    return GuardrailRoute.structural(_structuralDescriptions[id] ?? id);
  }

  if (_coreBoundaryIds.contains(id)) {
    return const GuardrailRoute.structural('core boundary checks');
  }

  return null;
}

Future<int> _runGuardrail(
  String id, {
  required Map<String, Future<int>> proofExitCodes,
  required GuardrailProofRunner runDartTest,
}) async {
  final proofPath = _testProofPaths[id];
  if (proofPath != null) {
    final cacheKey = 'dart-test:$proofPath';

    return proofExitCodes.putIfAbsent(
      cacheKey,
      () => runDartTest(id, proofPath),
    );
  }

  final violationCheck = _violationChecks[id];
  if (violationCheck != null) {
    return _reportViolations(id, await violationCheck());
  }

  if (_coreBoundaryIds.contains(id)) {
    return _reportViolations(id, [
      ...await checkCoreBoundaries(),
      ..._negativeFixtureViolationsFor(id),
    ]);
  }

  stderr.writeln('Unknown guardrail: $id');

  return 64;
}

Future<int> _runDartTest(String id, String path) async {
  final result = await Process.run('dart', ['test', path]);
  if (result.exitCode == 0) {
    return 0;
  }

  stderr
    ..writeln('Guardrail proof failed: $id')
    ..writeln(result.stdout)
    ..writeln(result.stderr);

  return result.exitCode;
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

const _testProofPaths = {
  'api.integration_surface_complete':
      'test/api_contract/app_next_engine_adapter_compile_fixture_test.dart',
  'api.public_api_compiles_as_written':
      'test/api_contract/public_api_v1_compiles_as_written_test.dart',
  'api.resource_source_app_key_publicly_readable':
      'test/api_contract/public_readable_union_variants_test.dart',
  'api.preview_state_sealed_union_publicly_readable':
      'test/api_contract/public_readable_union_variants_test.dart',
  'api.dto_immutability': 'test/api_contract/dto_immutability_test.dart',
  'api.equality_policy_explicit':
      'test/api_contract/public_equality_policy_test.dart',
  'api.id_validation_no_extension_type_escape':
      'test/api_contract/id_validation_no_extension_type_escape_test.dart',
  'codec.known_fields_validated':
      'test/codec/constructor_and_schema_limits_test.dart',
};

final Map<String, Future<List<GuardrailViolation>> Function()>
_violationChecks = {
  'api.no_legacy_public_types': checkNoLegacyPublicTypes,
  'api.public_exports_complete': checkPublicExportsComplete,
  'api.public_types_complete': checkPublicTypesComplete,
  'api.public_signature_shape': checkPublicSignatureShape,
  'api.no_undefined_public_type_references':
      checkNoUndefinedPublicTypeReferences,
  'core.single_runtime_root': () async => checkSingleRuntimeRoot(),
};

const _structuralDescriptions = {
  'api.no_legacy_public_types': 'resolved public legacy symbol check',
  'api.public_exports_complete': 'public registry parity check',
  'api.public_types_complete': 'resolved public type closure check',
  'api.public_signature_shape': 'resolved public signature shape check',
  'api.no_undefined_public_type_references':
      'resolved undefined public type reference check',
  'core.single_runtime_root': 'single runtime root declaration check',
};

const _coreBoundaryIds = {
  'core.no_legacy_imports',
  'core.import_boundaries',
  'core.no_unapproved_part_files',
  'core.no_scene_controller_shape_dependency',
  'core.no_node_spec_patch_shape_dependency',
};
