// GuardrailExecutor is the route table for cross-domain guardrail proof owners,
// so the domain check imports stay visible here instead of being hidden behind
// metric-shaped route fragments.
// ignore_for_file: number-of-imports

import 'dart:io';

import 'core_boundary_checks.dart';
import 'frame_cache_guardrail_checks.dart';
import 'geometry_spatial_guardrail_checks.dart';
import 'guardrail_violation.dart';
import 'owner_dag_import_checks.dart';
import 'interaction_guardrail_checks.dart';
import 'public_api_guardrail_checks.dart';
import 'release_readiness_checks.dart';
import 'selection_boundary_checks.dart';
import 'selection_move_guardrail_suite.dart';
import 'store_projection_checks.dart';
import 'text_surface_guardrail_checks.dart';

typedef GuardrailProofRunner =
    Future<int> Function(String guardrailId, String path);
typedef GuardrailViolationRunner = Future<List<GuardrailViolation>> Function();

final class GuardrailRunOptions {
  const GuardrailRunOptions({this.publicApiLibraryPath});

  final String? publicApiLibraryPath;
}

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

Future<GuardrailRunResult> runGuardrails(
  Iterable<String> ids, {
  GuardrailRunOptions options = const GuardrailRunOptions(),
}) {
  return runGuardrailsWithProofRunner(
    ids,
    runDartTest: _runDartTest,
    options: options,
  );
}

Future<GuardrailRunResult> runGuardrailsWithProofRunner(
  Iterable<String> ids, {
  required GuardrailProofRunner runDartTest,
  GuardrailRunOptions options = const GuardrailRunOptions(),
  Map<String, GuardrailViolationRunner>? violationChecks,
}) async {
  final ran = <String>[];
  final proofExitCodes = <String, Future<int>>{};
  final structuralChecks = violationChecks ?? _violationChecksFor(options);

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

  if (_violationChecksFor(const GuardrailRunOptions()).containsKey(id)) {
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
    'test/guardrails/edit_sparse_routes_no_eager_projection_guardrail_test.dart',
  ],
  'selection.owner_separate_from_document': [
    'test/selection/runtime_owner_separation_test.dart',
    'test/guardrails/selection_boundary_checks_test.dart',
  ],
  interactionNoConcreteStoreImportsGuardrailId: [
    'test/guardrails/import_boundaries_test.dart',
    'test/guardrails/interaction_guardrail_enforcement_test.dart',
  ],
  interactionNoConcreteSelectionImportsGuardrailId: [
    'test/guardrails/import_boundaries_test.dart',
    'test/guardrails/interaction_guardrail_enforcement_test.dart',
  ],
  interactionReadPortImmutableFactsGuardrailId: [
    'test/interaction/interaction_read_port_test.dart',
    'test/guardrails/interaction_guardrail_enforcement_test.dart',
  ],
  interactionNoCommandFactsImportGuardrailId: [
    'test/guardrails/import_boundaries_test.dart',
    'test/guardrails/interaction_guardrail_enforcement_test.dart',
  ],
  interactionCleanupCoordinatorDependencyBansGuardrailId: [
    'test/guardrails/import_boundaries_test.dart',
    'test/guardrails/interaction_guardrail_enforcement_test.dart',
  ],
  'interaction.pointer_cleanup_coordinator_only': [
    'test/guardrails/import_boundaries_test.dart',
    'test/interaction/pointer_tool_cleanup_coordinator_test.dart',
  ],
  interactionNoResolverOnCancelPathsGuardrailId: [
    'test/interaction/move_resolver_not_called_on_cancel_cleanup_test.dart',
  ],
  interactionNoStaleTerminalCommitGuardrailId: [
    'test/interaction/move_machine_test.dart',
    'test/interaction/draw_stroke_interaction_routing_test.dart',
    'test/interaction/line_interaction_routing_test.dart',
    'test/interaction/eraser_context_action_routing_test.dart',
  ],
  interactionTextEditStaleCommitGuardrailId: [
    'test/interaction/text_edit_stale_commit_guard_test.dart',
    'test/guardrails/interaction_guardrail_enforcement_test.dart',
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
  'events.commands_emit_user_actions': [
    'test/interaction/commands_emit_user_actions_test.dart',
    'test/api/typed_action_payloads_test.dart',
    'test/guardrails/action_after_state_guardrail_test.dart',
  ],
  eventsActionAfterStateOrderGuardrailId: [
    'test/interaction/commands_emit_user_actions_test.dart',
    'test/guardrails/action_after_state_guardrail_test.dart',
  ],
  'events.runtime_created_timestamps_monotonic': [
    'test/api/runtime_timestamp_order_test.dart',
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
  'resources.app_key_only': [
    'test/api_contract/public_readable_union_variants_test.dart',
    'test/resources/resource_resolver_adapter_shape_test.dart',
  ],
  'resources.dirty_no_document_revision': [
    'test/resources/resource_dirty_port_test.dart',
    'test/resources/mark_all_resources_dirty_test.dart',
  ],
  'resources.mutation_inside_edit_only': [
    'test/edit/edit_matrix_effects_test.dart',
    'test/edit/sync_non_nested_async_stale_test.dart',
  ],
  'surface.pointer_samples_normalized_before_runtime': [
    'test/guardrails/import_boundaries_test.dart',
    'test/surface/pointer_adapter_finite_normalization_test.dart',
  ],
  'surface.interactive_false_pending_line_preserved': [
    'test/guardrails/import_boundaries_test.dart',
    'test/surface/interactive_false_pointer_routing_test.dart',
    'test/surface/interactive_false_active_session_cancel_test.dart',
    'test/surface/interactive_false_pending_line_preserved_test.dart',
    'test/surface/interactive_false_state_isolation_test.dart',
  ],
  'preview.selected_move_main_repaint': [
    'test/guardrails/preview_selected_move_main_repaint_guardrail_test.dart',
  ],
  selectedMoveMainOnlyPreviewGuardrailId: [
    'test/guardrails/preview_selected_move_main_repaint_guardrail_test.dart',
  ],
  marqueeOverlayOnlyPreviewGuardrailId: [
    'test/frame/marquee_overlay_repaint_test.dart',
  ],
  toolPortCompatibilityGuardrailId: [
    'test/api/tool_port_settings_test.dart',
    'test/api/command_port_actions_test.dart',
    'test/api/typed_action_payloads_test.dart',
  ],
  'frame.committed_facts_via_frame_facts_port': [
    'test/guardrails/import_boundaries_test.dart',
    'test/frame/main_overlay_capture_test.dart',
    'test/frame/paint_asset_binding_service_test.dart',
  ],
  'frame.no_global_scene_sort': [
    'test/frame/selected_supplement_staging_no_global_sort_test.dart',
  ],
  'frame.paint_plan_excludes_preview_delta': [
    'test/frame/paint_plan_excludes_preview_delta_test.dart',
  ],
  'frame.paint_plan_excludes_selection_state': [
    'test/frame/paint_plan_excludes_selection_state_test.dart',
  ],
  textSingleMeasuredLayoutSourceGuardrailId: [
    'test/frame/measured_text_layout_test.dart',
    'test/guardrails/text_surface_guardrail_checks_test.dart',
  ],
  textNoOverlayTextPainterMeasurementGuardrailId: [
    'test/surface/text_editing_overlay_test.dart',
    'test/guardrails/text_surface_guardrail_checks_test.dart',
  ],
  surfaceEditableTextSurfaceOnlyGuardrailId: [
    'test/surface/text_editing_overlay_test.dart',
    'test/guardrails/text_surface_guardrail_checks_test.dart',
  ],
  'cache.keys_use_next_revisions_only': [
    'test/frame/cache_keys_do_not_use_legacy_snapshot_shape_test.dart',
  ],
  'cache.background_grid_not_element_visual': [
    'test/frame/camera_pan_preserves_ordinary_paint_plan_test.dart',
    'test/frame/static_background_plan_test.dart',
  ],
  'cache.hot_caches_have_capacity_eviction': [
    'test/frame/cache_capacity_eviction_policy_test.dart',
  ],
  geometryNoLegacySceneOrderGuardrailId: [
    'test/guardrails/geometry_no_legacy_scene_order_guardrail_test.dart',
  ],
  geometryEraserExactBudgetGuardrailId: [
    'test/guardrails/geometry_eraser_exact_budget_inputs_guardrail_test.dart',
  ],
  spatialNoFullCloneGuardrailId: [
    'test/guardrails/spatial_no_full_clone_ordinary_edit_guardrail_test.dart',
  ],
  spatialStaleCandidateGuardrailId: [
    'test/guardrails/spatial_stale_candidate_rejected_guardrail_test.dart',
  ],
  spatialFallbackBudgetGuardrailId: [
    'test/guardrails/spatial_fallback_budget_enforced_guardrail_test.dart',
  ],
  releaseBenchmarkReadinessGuardrailId: [
    'test/benchmarks/benchmark_diff_test.dart',
    'test/guardrails/release_readiness_guardrail_test.dart',
  ],
};

Map<String, GuardrailViolationRunner> _violationChecksFor(
  GuardrailRunOptions options,
) {
  return {
    'api.no_retired_public_exports': () {
      return checkNoRetiredPublicExports(
        libraryPath: options.publicApiLibraryPath,
      );
    },
    ..._baseViolationChecks,
  };
}

final Map<String, GuardrailViolationRunner> _baseViolationChecks = {
  'api.public_exports_complete': checkPublicExportsComplete,
  'api.no_retired_public_load_routes': checkNoRetiredPublicLoadRoutes,
  'api.no_unapproved_document_load_inputs': checkNoUnapprovedDocumentLoadInputs,
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
  interactionNoConcreteStoreImportsGuardrailId:
      checkInteractionImportBoundaries,
  interactionNoConcreteSelectionImportsGuardrailId:
      checkInteractionImportBoundaries,
  interactionReadPortImmutableFactsGuardrailId:
      checkInteractionReadPortImmutableFacts,
  interactionNoCommandFactsImportGuardrailId: checkInteractionImportBoundaries,
  interactionCleanupCoordinatorDependencyBansGuardrailId:
      checkCleanupCoordinatorDependencyBans,
  'interaction.pointer_cleanup_coordinator_only':
      checkPointerCleanupCoordinatorCallerOrigins,
  interactionTextEditStaleCommitGuardrailId: checkTextEditStaleCommitGuard,
  ownerDagGuardrailId: checkOwnerDagImportBoundaries,
  'resources.resolver_boundary_owned_by_surface_session': checkCoreBoundaries,
  'surface.pointer_samples_normalized_before_runtime':
      checkSurfacePointerReservedBoundary,
  'surface.interactive_false_pending_line_preserved':
      checkSurfaceInteractiveDisabledReservedBoundary,
  'frame.committed_facts_via_frame_facts_port': checkCoreBoundaries,
  frameNoGlobalSceneSortGuardrailId: checkFrameNoGlobalSceneSort,
  framePaintPlanExcludesPreviewGuardrailId: checkPaintPlanExcludesPreviewDelta,
  framePaintPlanExcludesSelectionGuardrailId:
      checkPaintPlanExcludesSelectionState,
  textSingleMeasuredLayoutSourceGuardrailId:
      checkTextSingleMeasuredLayoutSource,
  textNoOverlayTextPainterMeasurementGuardrailId:
      checkNoOverlayTextPainterMeasurement,
  surfaceEditableTextSurfaceOnlyGuardrailId: checkEditableTextSurfaceOnly,
  cacheKeysUseNextRevisionsGuardrailId: checkCacheKeysUseNextRevisionsOnly,
  cacheBackgroundGridGuardrailId: checkCacheBackgroundGridNotElementVisual,
  cacheHotCachesCapacityGuardrailId: checkCacheHotCachesHaveCapacityEviction,
  geometryNoLegacySceneOrderGuardrailId: checkNoLegacySceneOrder,
  geometryEraserExactBudgetGuardrailId: checkGeometryEraserExactBudgetInputs,
  spatialNoFullCloneGuardrailId: checkSpatialNoFullCloneOrdinaryEdit,
  spatialStaleCandidateGuardrailId: checkSpatialStaleCandidateRejected,
  spatialFallbackBudgetGuardrailId: checkSpatialFallbackBudgetEnforced,
  releaseBenchmarkReadinessGuardrailId: checkReleaseBenchmarkReadiness,
};

const _structuralDescriptions = {
  'api.no_retired_public_exports': 'resolved retired public export check',
  'api.public_exports_complete': 'public registry parity check',
  'api.no_retired_public_load_routes':
      'public load/decode route retirement check',
  'api.no_unapproved_document_load_inputs':
      'production CanvasDocument load-input allowlist check',
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
  interactionNoConcreteStoreImportsGuardrailId:
      'selection-and-move interaction concrete-store import boundary check',
  interactionNoConcreteSelectionImportsGuardrailId:
      'selection-and-move interaction concrete-selection import boundary check',
  interactionReadPortImmutableFactsGuardrailId:
      'selection-and-move interaction read-port immutable fact exposure check',
  interactionNoCommandFactsImportGuardrailId:
      'selection-and-move interaction command-facts import boundary check',
  interactionCleanupCoordinatorDependencyBansGuardrailId:
      'selection-and-move cleanup coordinator dependency boundary check',
  'interaction.pointer_cleanup_coordinator_only':
      'interaction pointer cleanup coordinator caller-origin check',
  interactionTextEditStaleCommitGuardrailId:
      'P12 text edit stale commit guard ordering check',
  ownerDagGuardrailId: 'owner DAG import/export boundary check',
  'resources.resolver_boundary_owned_by_surface_session':
      'resource resolver ownership and import-boundary checks',
  'surface.pointer_samples_normalized_before_runtime':
      'surface pointer adapter reserved-path structural boundary check',
  'surface.interactive_false_pending_line_preserved':
      'surface interactive-disabled cleanup reserved-path boundary check',
  'frame.committed_facts_via_frame_facts_port':
      'frame facts and asset-binding session ownership checks',
  frameNoGlobalSceneSortGuardrailId:
      'frame selected supplement global sort check',
  framePaintPlanExcludesPreviewGuardrailId:
      'ordinary paint-plan preview exclusion check',
  framePaintPlanExcludesSelectionGuardrailId:
      'ordinary paint-plan selection exclusion check',
  textSingleMeasuredLayoutSourceGuardrailId:
      'single measured text layout source structural check',
  textNoOverlayTextPainterMeasurementGuardrailId:
      'surface/example overlay TextPainter measurement exclusion check',
  surfaceEditableTextSurfaceOnlyGuardrailId:
      'EditableText production owner boundary check',
  cacheKeysUseNextRevisionsGuardrailId:
      'frame cache key legacy snapshot-shape check',
  cacheBackgroundGridGuardrailId:
      'ordinary paint-plan background/grid/camera exclusion check',
  cacheHotCachesCapacityGuardrailId:
      'hot frame cache capacity and eviction probe check',
  geometryNoLegacySceneOrderGuardrailId:
      'geometry/spatial committed order-token structural check',
  geometryEraserExactBudgetGuardrailId:
      'P8 eraser primitive and exact-check budget-input check',
  spatialNoFullCloneGuardrailId:
      'ordinary spatial update full-frame enumeration check',
  spatialStaleCandidateGuardrailId:
      'spatial stale candidate typed-result and handle-remap check',
  spatialFallbackBudgetGuardrailId:
      'spatial fallback budget no-partial result check',
  releaseBenchmarkReadinessGuardrailId:
      'P14 benchmark release-readiness workflow and compatibility check',
};

const _coreBoundaryIds = {
  'core.no_legacy_imports',
  'core.import_boundaries',
  'core.no_unapproved_part_files',
  'core.no_scene_controller_shape_dependency',
  'core.no_node_spec_patch_shape_dependency',
};
