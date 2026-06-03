final class GuardrailEntry {
  const GuardrailEntry({
    required this.id,
    required this.suites,
    this.requiresRunnerStructuralProof = false,
  });

  final String id;
  final Set<String> suites;
  final bool requiresRunnerStructuralProof;
}

Map<String, GuardrailEntry> guardrailInventory() {
  return {for (final entry in _blockingEntries) entry.id: entry};
}

Set<String> blockingGuardrailIds() {
  return _blockingEntries.map((entry) => entry.id).toSet();
}

Set<String> suiteGuardrailIds(String suite) {
  return guardrailInventory().values
      .where((entry) => entry.suites.contains(suite))
      .map((entry) => entry.id)
      .toSet();
}

Set<String> runnerStructuralProofGuardrailIds() {
  return guardrailInventory().values
      .where((entry) => entry.requiresRunnerStructuralProof)
      .map((entry) => entry.id)
      .toSet();
}

const _blockingEntries = [
  GuardrailEntry(
    id: 'api.integration_surface_complete',
    suites: {'blocking', 'api'},
  ),
  GuardrailEntry(id: 'api.no_legacy_public_types', suites: {'blocking', 'api'}),
  GuardrailEntry(
    id: 'api.public_exports_complete',
    suites: {'blocking', 'api'},
  ),
  GuardrailEntry(
    id: 'api.facades_do_not_export_internal',
    suites: {'blocking', 'api'},
  ),
  GuardrailEntry(id: 'api.public_types_complete', suites: {'blocking', 'api'}),
  GuardrailEntry(
    id: 'api.public_api_compiles_as_written',
    suites: {'blocking', 'api'},
  ),
  GuardrailEntry(
    id: 'api.resource_source_app_key_publicly_readable',
    suites: {'blocking', 'api'},
  ),
  GuardrailEntry(
    id: 'api.preview_state_sealed_union_publicly_readable',
    suites: {'blocking', 'api'},
  ),
  GuardrailEntry(
    id: 'api.exported_dartdoc_complete',
    suites: {'blocking', 'api'},
  ),
  GuardrailEntry(
    id: 'api.public_class_modifiers_explicit',
    suites: {'blocking', 'api'},
  ),
  GuardrailEntry(
    id: 'api.no_public_api_import_cycles',
    suites: {'blocking', 'api'},
  ),
  GuardrailEntry(id: 'api.public_signature_shape', suites: {'blocking', 'api'}),
  GuardrailEntry(
    id: 'api.no_undefined_public_type_references',
    suites: {'blocking', 'api'},
  ),
  GuardrailEntry(id: 'api.dto_immutability', suites: {'blocking', 'api'}),
  GuardrailEntry(
    id: 'api.equality_policy_explicit',
    suites: {'blocking', 'api'},
  ),
  GuardrailEntry(
    id: 'api.id_validation_no_extension_type_escape',
    suites: {'blocking', 'api'},
  ),
  GuardrailEntry(id: 'codec.schema_v1_exact', suites: {'blocking', 'codec'}),
  GuardrailEntry(
    id: 'codec.known_fields_validated',
    suites: {'blocking', 'codec'},
  ),
  GuardrailEntry(
    id: 'codec.no_runtime_side_effects',
    suites: {'blocking', 'codec'},
  ),
  GuardrailEntry(
    id: 'diagnostics.disabled_no_alloc_hot_path',
    suites: {'blocking', 'diagnostics'},
  ),
  GuardrailEntry(
    id: 'diagnostics.sanitized_public_projection',
    suites: {'blocking', 'diagnostics'},
  ),
  GuardrailEntry(id: 'core.no_legacy_imports', suites: {'blocking', 'core'}),
  GuardrailEntry(id: 'core.import_boundaries', suites: {'blocking', 'core'}),
  GuardrailEntry(
    id: 'core.no_unapproved_part_files',
    suites: {'blocking', 'core'},
  ),
  GuardrailEntry(
    id: 'core.no_scene_controller_shape_dependency',
    suites: {'blocking', 'core'},
  ),
  GuardrailEntry(
    id: 'core.no_node_spec_patch_shape_dependency',
    suites: {'blocking', 'core'},
  ),
  GuardrailEntry(id: 'core.single_runtime_root', suites: {'blocking', 'core'}),
  GuardrailEntry(
    id: 'core.owner_dag_import_boundaries',
    suites: {'blocking', 'core'},
    requiresRunnerStructuralProof: true,
  ),
  GuardrailEntry(
    id: 'store.no_public_document_live_state',
    suites: {'blocking', 'store'},
    requiresRunnerStructuralProof: true,
  ),
  GuardrailEntry(
    id: 'projection.only_explicit_read_paths',
    suites: {'blocking', 'store', 'projection'},
    requiresRunnerStructuralProof: true,
  ),
  GuardrailEntry(
    id: 'selection.owner_separate_from_document',
    suites: {'blocking', 'selection'},
    requiresRunnerStructuralProof: true,
  ),
  GuardrailEntry(
    id: 'interaction.no_concrete_store_imports',
    suites: {'blocking', 'interaction'},
    requiresRunnerStructuralProof: true,
  ),
  GuardrailEntry(
    id: 'interaction.no_concrete_selection_imports',
    suites: {'blocking', 'interaction'},
    requiresRunnerStructuralProof: true,
  ),
  GuardrailEntry(
    id: 'interaction.read_port_immutable_facts',
    suites: {'blocking', 'interaction'},
    requiresRunnerStructuralProof: true,
  ),
  GuardrailEntry(
    id: 'interaction.no_command_facts_import',
    suites: {'blocking', 'interaction'},
    requiresRunnerStructuralProof: true,
  ),
  GuardrailEntry(
    id: 'interaction.cleanup_coordinator_dependency_bans',
    suites: {'blocking', 'interaction'},
    requiresRunnerStructuralProof: true,
  ),
  GuardrailEntry(
    id: 'interaction.pointer_cleanup_coordinator_only',
    suites: {'blocking', 'interaction'},
    requiresRunnerStructuralProof: true,
  ),
  GuardrailEntry(
    id: 'interaction.no_resolver_on_cancel_paths',
    suites: {'blocking', 'interaction'},
  ),
  GuardrailEntry(
    id: 'interaction.no_stale_terminal_commit',
    suites: {'blocking', 'interaction'},
  ),
  GuardrailEntry(
    id: 'interaction.text_edit_stale_commit_guard',
    suites: {'blocking', 'interaction'},
    requiresRunnerStructuralProof: true,
  ),
  GuardrailEntry(id: 'edit.sync_non_nested', suites: {'blocking', 'edit'}),
  GuardrailEntry(id: 'edit.rollback_no_effects', suites: {'blocking', 'edit'}),
  GuardrailEntry(
    id: 'edit.stale_handle_rejected',
    suites: {'blocking', 'edit'},
  ),
  GuardrailEntry(
    id: 'edit.operation_matrix_complete',
    suites: {'blocking', 'edit'},
  ),
  GuardrailEntry(
    id: 'edit.no_global_invalidation_except_replacement',
    suites: {'blocking', 'edit'},
  ),
  GuardrailEntry(
    id: 'edit.typed_effects_no_frame_dependency',
    suites: {'blocking', 'edit'},
  ),
  GuardrailEntry(
    id: 'events.low_level_edit_no_user_actions',
    suites: {'blocking', 'events'},
  ),
  GuardrailEntry(
    id: 'events.commands_emit_user_actions',
    suites: {'blocking', 'events'},
  ),
  GuardrailEntry(
    id: 'events.action_after_state_order',
    suites: {'blocking', 'events'},
  ),
  GuardrailEntry(
    id: 'events.runtime_created_timestamps_monotonic',
    suites: {'blocking', 'events'},
  ),
  GuardrailEntry(
    id: 'load.prepares_before_interrupt',
    suites: {'blocking', 'load'},
  ),
  GuardrailEntry(
    id: 'load.success_interrupts_before_install',
    suites: {'blocking', 'load'},
  ),
  GuardrailEntry(
    id: 'resources.resolver_boundary_owned_by_surface_session',
    suites: {'blocking', 'resources'},
    requiresRunnerStructuralProof: true,
  ),
  GuardrailEntry(
    id: 'resources.app_key_only',
    suites: {'blocking', 'resources'},
  ),
  GuardrailEntry(
    id: 'resources.dirty_no_document_revision',
    suites: {'blocking', 'resources'},
  ),
  GuardrailEntry(
    id: 'resources.mutation_inside_edit_only',
    suites: {'blocking', 'resources'},
  ),
  GuardrailEntry(
    id: 'resources.resolver_frame_budget',
    suites: {'blocking', 'resources'},
  ),
  GuardrailEntry(
    id: 'resources.no_same_frame_missing_retry',
    suites: {'blocking', 'resources'},
  ),
  GuardrailEntry(
    id: 'resources.resolver_reentrancy_rejected',
    suites: {'blocking', 'resources'},
  ),
  GuardrailEntry(
    id: 'preview.selected_move_main_repaint',
    suites: {'blocking', 'preview'},
  ),
  GuardrailEntry(
    id: 'preview.selected_move_main_only',
    suites: {'blocking', 'preview'},
  ),
  GuardrailEntry(
    id: 'preview.marquee_overlay_only',
    suites: {'blocking', 'preview'},
  ),
  GuardrailEntry(
    id: 'surface.pointer_samples_normalized_before_runtime',
    suites: {'blocking', 'surface'},
    requiresRunnerStructuralProof: true,
  ),
  GuardrailEntry(
    id: 'surface.interactive_false_pending_line_preserved',
    suites: {'blocking', 'surface'},
    requiresRunnerStructuralProof: true,
  ),
  GuardrailEntry(id: 'tools.p10_compatibility', suites: {'blocking', 'tools'}),
  GuardrailEntry(
    id: 'frame.committed_facts_via_frame_facts_port',
    suites: {'blocking', 'frame'},
  ),
  GuardrailEntry(
    id: 'frame.no_global_scene_sort',
    suites: {'blocking', 'frame'},
  ),
  GuardrailEntry(
    id: 'frame.paint_plan_excludes_preview_delta',
    suites: {'blocking', 'frame'},
  ),
  GuardrailEntry(
    id: 'frame.paint_plan_excludes_selection_state',
    suites: {'blocking', 'frame'},
  ),
  GuardrailEntry(
    id: 'cache.keys_use_next_revisions_only',
    suites: {'blocking', 'cache'},
  ),
  GuardrailEntry(
    id: 'cache.background_grid_not_element_visual',
    suites: {'blocking', 'cache'},
  ),
  GuardrailEntry(
    id: 'cache.hot_caches_have_capacity_eviction',
    suites: {'blocking', 'cache'},
  ),
  GuardrailEntry(
    id: 'geometry.no_legacy_scene_order',
    suites: {'blocking', 'geometry'},
    requiresRunnerStructuralProof: true,
  ),
  GuardrailEntry(
    id: 'geometry.eraser_exact_budget_no_partial',
    suites: {'blocking', 'geometry'},
    requiresRunnerStructuralProof: true,
  ),
  GuardrailEntry(
    id: 'spatial.no_full_clone_ordinary_edit',
    suites: {'blocking', 'spatial'},
    requiresRunnerStructuralProof: true,
  ),
  GuardrailEntry(
    id: 'spatial.stale_candidate_rejected',
    suites: {'blocking', 'spatial'},
    requiresRunnerStructuralProof: true,
  ),
  GuardrailEntry(
    id: 'spatial.fallback_budget_enforced',
    suites: {'blocking', 'spatial'},
    requiresRunnerStructuralProof: true,
  ),
];
