import 'dart:io';

import 'core_boundary_checks.dart';
import 'guardrail_violation.dart';
import 'owner_dag_import_checks.dart';
import 'public_api_checks.dart';
import 'public_api_contract_checks.dart';
import 'public_api_declaration_checks.dart';
import 'public_api_import_cycle_checks.dart';
import 'selection_boundary_checks.dart';
import 'store_projection_checks.dart';

typedef GuardrailProofRunner =
    Future<int> Function(String guardrailId, String path);
typedef GuardrailViolationRunner = Future<List<GuardrailViolation>> Function();

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
  Map<String, GuardrailViolationRunner>? violationChecks,
}) async {
  final ran = <String>[];
  final proofExitCodes = <String, Future<int>>{};
  final structuralChecks = violationChecks ?? _violationChecks;

  for (final id in ids) {
    ran.add(id);
    final exitCode = await _runGuardrail(
      id,
      proofExitCodes: proofExitCodes,
      runDartTest: runDartTest,
      violationChecks: structuralChecks,
    );
    if (exitCode != 0) {
      return GuardrailRunResult(ranGuardrailIds: ran, exitCode: exitCode);
    }
  }

  return GuardrailRunResult(ranGuardrailIds: ran, exitCode: 0);
}

GuardrailRoute? guardrailRouteFor(String id) {
  final proofPaths = _testProofPaths[id];
  if (proofPaths != null) {
    return GuardrailRoute.dartTest(proofPaths.join(', '));
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
  required Map<String, GuardrailViolationRunner> violationChecks,
}) async {
  final proofPath = _testProofPaths[id];
  if (proofPath != null) {
    for (final path in proofPath) {
      final cacheKey = 'dart-test:$path';
      final exitCode = await proofExitCodes.putIfAbsent(
        cacheKey,
        () => runDartTest(id, path),
      );
      if (exitCode != 0) {
        return exitCode;
      }
    }

    final violationCheck = violationChecks[id];
    if (violationCheck != null) {
      return _reportViolations(id, await violationCheck());
    }

    return 0;
  }

  final violationCheck = violationChecks[id];
  if (violationCheck != null) {
    return _reportViolations(id, await violationCheck());
  }

  if (_coreBoundaryIds.contains(id)) {
    return _reportViolations(id, await checkCoreBoundaries());
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

const _testProofPaths = {
  'api.integration_surface_complete': [
    'test/api_contract/app_next_engine_adapter_compile_fixture_test.dart',
  ],
  'api.public_api_compiles_as_written': [
    'test/api_contract/public_api_v1_compiles_as_written_test.dart',
  ],
  'api.facades_do_not_export_internal': [
    'test/api_contract/api_facades_do_not_export_internal_test.dart',
  ],
  'api.resource_source_app_key_publicly_readable': [
    'test/api_contract/public_readable_union_variants_test.dart',
  ],
  'api.preview_state_sealed_union_publicly_readable': [
    'test/api_contract/public_readable_union_variants_test.dart',
  ],
  'api.exported_dartdoc_complete': [
    'test/guardrails/public_api_declaration_checks_test.dart',
  ],
  'api.public_class_modifiers_explicit': [
    'test/guardrails/public_api_declaration_checks_test.dart',
  ],
  'api.no_public_api_import_cycles': [
    'test/guardrails/public_api_import_cycles_test.dart',
  ],
  'core.owner_dag_import_boundaries': [
    'test/guardrails/owner_dag_import_boundaries_test.dart',
  ],
  'api.dto_immutability': ['test/api_contract/dto_immutability_test.dart'],
  'api.equality_policy_explicit': [
    'test/api_contract/public_equality_policy_test.dart',
  ],
  'api.id_validation_no_extension_type_escape': [
    'test/api_contract/id_validation_no_extension_type_escape_test.dart',
  ],
  'codec.schema_v1_exact': ['test/codec/schema_v1'],
  'codec.known_fields_validated': ['test/codec/schema_v1'],
  'codec.no_runtime_side_effects': [
    'test/codec/decode_encode_no_runtime_side_effects_test.dart',
    'test/guardrails/codec_no_runtime_imports_test.dart',
  ],
  'diagnostics.disabled_no_alloc_hot_path': [
    'test/diagnostics/disabled_no_alloc_hot_path_test.dart',
  ],
  'diagnostics.sanitized_public_projection': [
    'test/diagnostics/sanitizer_and_public_projection_test.dart',
    'test/diagnostics/diagnostics_public_surface_test.dart',
  ],
  'store.no_public_document_live_state': [
    'test/store/public_document_is_projection_only_test.dart',
    'test/guardrails/store_projection_checks_test.dart',
  ],
  'projection.only_explicit_read_paths': [
    'test/store/no_projection_hot_path_test.dart',
    'test/guardrails/store_projection_checks_test.dart',
  ],
  'selection.owner_separate_from_document': [
    'test/selection/runtime_owner_separation_test.dart',
    'test/guardrails/selection_boundary_checks_test.dart',
  ],
  'edit.sync_non_nested': ['test/edit/sync_non_nested_async_stale_test.dart'],
  'edit.rollback_no_effects': [
    'test/edit/rollback_test.dart',
    'test/edit/edit_matrix_effects_test.dart',
  ],
  'edit.stale_handle_rejected': [
    'test/edit/sync_non_nested_async_stale_test.dart',
  ],
  'edit.operation_matrix_complete': [
    'test/edit/edit_matrix_effects_test.dart',
    'test/edit/field_update_admission_effects_test.dart',
    'test/edit/exact_touched_invalidation_test.dart',
  ],
  'edit.no_global_invalidation_except_replacement': [
    'test/edit/exact_touched_invalidation_test.dart',
    'test/edit/edit_matrix_effects_test.dart',
  ],
  'edit.typed_effects_no_frame_dependency': [
    'test/edit/typed_effects_no_frame_dependency_test.dart',
  ],
  'events.low_level_edit_no_user_actions': [
    'test/edit/low_level_mutations_do_not_emit_actions_test.dart',
  ],
  'load.prepares_before_interrupt': [
    'test/runtime/load_document_ordering_test.dart',
    'test/runtime/load_document_ordering_fixture_shape_test.dart',
  ],
  'load.success_interrupts_before_install': [
    'test/runtime/load_document_ordering_test.dart',
    'test/runtime/load_document_ordering_fixture_shape_test.dart',
  ],
  'resources.resolver_boundary_owned_by_surface_session': [
    'test/guardrails/import_boundaries_test.dart',
    'test/contracts/internal_seam_shape_test.dart',
    'test/resources/resource_resolver_adapter_shape_test.dart',
  ],
  'resources.resolver_frame_budget': [
    'test/resources/resolver_frame_budget_test.dart',
  ],
  'resources.no_same_frame_missing_retry': [
    'test/resources/missing_result_suppressed_per_frame_test.dart',
  ],
  'resources.resolver_reentrancy_rejected': [
    'test/resources/resolver_reentrancy_rejected_test.dart',
  ],
};

final Map<String, GuardrailViolationRunner> _violationChecks = {
  'api.no_legacy_public_types': checkNoLegacyPublicTypes,
  'api.public_exports_complete': checkPublicExportsComplete,
  'api.facades_do_not_export_internal': checkApiFacadesDoNotExportInternal,
  'api.public_types_complete': checkPublicTypesComplete,
  'api.public_signature_shape': checkPublicSignatureShape,
  'api.exported_dartdoc_complete': checkExportedDartdocComplete,
  'api.public_class_modifiers_explicit': checkPublicClassModifiersExplicit,
  'api.no_public_api_import_cycles': checkNoPublicApiImportCycles,
  'api.no_undefined_public_type_references':
      checkNoUndefinedPublicTypeReferences,
  'core.single_runtime_root': () async => checkSingleRuntimeRoot(),
  'store.no_public_document_live_state': checkNoPublicDocumentLiveState,
  'projection.only_explicit_read_paths': checkProjectionOnlyExplicitReadPaths,
  'selection.owner_separate_from_document': checkSelectionOwnerSeparation,
  ownerDagGuardrailId: checkOwnerDagImportBoundaries,
  'resources.resolver_boundary_owned_by_surface_session': checkCoreBoundaries,
};

const _structuralDescriptions = {
  'api.no_legacy_public_types': 'resolved public legacy symbol check',
  'api.public_exports_complete': 'public registry parity check',
  'api.facades_do_not_export_internal':
      'resolved src/api facade internal export check',
  'api.public_types_complete': 'resolved public type closure check',
  'api.public_signature_shape': 'resolved public signature shape check',
  'api.exported_dartdoc_complete': 'exported public dartdoc summary check',
  'api.public_class_modifiers_explicit': 'exported public class modifier check',
  'api.no_public_api_import_cycles': 'public API import-cycle graph check',
  'api.no_undefined_public_type_references':
      'resolved undefined public type reference check',
  'core.single_runtime_root': 'single runtime root declaration check',
  'store.no_public_document_live_state':
      'resolved public document live-state check',
  'projection.only_explicit_read_paths':
      'resolved public projection read-path check',
  'selection.owner_separate_from_document':
      'resolved selection ownership boundary check',
  ownerDagGuardrailId: 'owner DAG import/export boundary check',
  'resources.resolver_boundary_owned_by_surface_session':
      'resource resolver ownership and import-boundary checks',
};

const _coreBoundaryIds = {
  'core.no_legacy_imports',
  'core.import_boundaries',
  'core.no_unapproved_part_files',
  'core.no_scene_controller_shape_dependency',
  'core.no_node_spec_patch_shape_dependency',
};
