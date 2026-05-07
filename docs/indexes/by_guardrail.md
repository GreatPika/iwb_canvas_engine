# By guardrail

Guardrails extracted from split section 22.

## api.functional_ledger_complete

- Rule: every functional ledger row has API + tests
- Sections: `section_08_functional_ledger`, `section_22_guardrails_machine_checks`, `section_23_tests`, `section_27_final_release_gates`
- Tests: `test.functional_ledger.row_specific_tests`, `test.guardrails.blocking_suite`

## api.integration_surface_complete

- Rule: API has enough public surface for app-level NextEngineAdapter, but adapter is not in package
- Sections: `section_22_guardrails_machine_checks`, `section_27_final_release_gates`
- Tests: `test.guardrails.blocking_suite`

## api.v1_scope_gate_green_before_freeze

- Rule: P1.5 scope gate passed before public API freeze starts
- Sections: `section_09_accepted_differences`, `section_22_guardrails_machine_checks`, `section_27_final_release_gates`
- Tests: `test.api_contract.v1_scope_gate`, `test.guardrails.blocking_suite`

## api.no_legacy_public_types

- Rule: legacy public golden symbols not exported by root package
- Sections: `section_03_package_layout`, `section_22_guardrails_machine_checks`, `section_27_final_release_gates`
- Tests: `test.api_contract.no_legacy_public_symbols`, `test.guardrails.blocking_suite`

## api.public_types_complete

- Rule: all public signatures reference defined public types
- Sections: `section_04_public_api_v1`, `section_22_guardrails_machine_checks`, `section_27_final_release_gates`
- Tests: `test.guardrails.blocking_suite`

## api.public_api_compiles_as_written

- Rule: public API declarations compile in an empty consumer package
- Sections: `section_04_public_api_v1`, `section_22_guardrails_machine_checks`, `section_27_final_release_gates`
- Tests: `test.api_contract.public_api_v1_compiles_as_written`, `test.guardrails.blocking_suite`

## api.no_undefined_public_type_references

- Rule: every exported signature type is exported or from Flutter/Dart SDK
- Sections: `section_04_public_api_v1`, `section_22_guardrails_machine_checks`, `section_27_final_release_gates`
- Tests: `test.api_contract.no_undefined_public_type_references`, `test.guardrails.blocking_suite`

## api.dto_immutability

- Rule: DTO collections defensively copied and unmodifiable
- Sections: `section_04_public_api_v1`, `section_22_guardrails_machine_checks`, `section_27_final_release_gates`
- Tests: `test.api_contract.dto_immutability`, `test.guardrails.blocking_suite`

## api.id_validation_no_extension_type_escape

- Rule: ids cannot be publicly constructed without validation
- Sections: `section_04_public_api_v1`, `section_06_validation_limits`, `section_22_guardrails_machine_checks`, `section_27_final_release_gates`
- Tests: `test.codec.constructor_and_schema_limits`, `test.guardrails.blocking_suite`

## core.no_legacy_imports

- Rule: no import of legacy package/runtime
- Sections: `section_00_status_and_scope`, `section_03_package_layout`, `section_22_guardrails_machine_checks`, `section_27_final_release_gates`
- Tests: `test.guardrails.blocking_suite`

## core.no_scene_controller_shape_dependency

- Rule: no SceneController concept in core
- Sections: `section_00_status_and_scope`, `section_22_guardrails_machine_checks`, `section_27_final_release_gates`
- Tests: `test.guardrails.blocking_suite`

## core.no_node_spec_patch_shape_dependency

- Rule: no legacy NodeSpec/NodePatch/PatchField in core
- Sections: `section_00_status_and_scope`, `section_22_guardrails_machine_checks`, `section_27_final_release_gates`
- Tests: `test.guardrails.blocking_suite`

## core.single_runtime_root

- Rule: exactly one production RuntimeRoot
- Sections: `section_02_architecture_model`, `section_10_runtime_data_model`, `section_22_guardrails_machine_checks`, `section_27_final_release_gates`
- Tests: `test.guardrails.blocking_suite`

## edit.sync_non_nested

- Rule: nested/async edit rejected
- Sections: `section_11_edit_kernel`, `section_13_operation_matrix`, `section_22_guardrails_machine_checks`, `section_27_final_release_gates`
- Tests: `test.edit.sync_non_nested_async_stale`, `test.guardrails.blocking_suite`

## edit.rollback_no_effects

- Rule: rollback discards events/repaint/resources/spatial
- Sections: `section_11_edit_kernel`, `section_13_operation_matrix`, `section_22_guardrails_machine_checks`, `section_27_final_release_gates`
- Tests: `test.edit.rollback`, `test.guardrails.blocking_suite`

## edit.stale_handle_rejected

- Rule: stale edit handle throws
- Sections: `section_11_edit_kernel`, `section_13_operation_matrix`, `section_22_guardrails_machine_checks`, `section_27_final_release_gates`
- Tests: `test.edit.sync_non_nested_async_stale`, `test.guardrails.blocking_suite`

## edit.typed_effects_no_frame_dependency

- Rule: CommitCompiler produces typed effects and does not depend on concrete FrameEngine
- Sections: `section_11_edit_kernel`, `section_22_guardrails_machine_checks`, `section_27_final_release_gates`
- Tests: `test.edit.typed_effects_no_frame_dependency`, `test.guardrails.blocking_suite`

## events.low_level_edit_no_user_actions

- Rule: CanvasEdit.removeElement/clearContent emit no user action events
- Sections: `section_11_edit_kernel`, `section_22_guardrails_machine_checks`, `section_27_final_release_gates`
- Tests: `test.edit.low_level_mutations_do_not_emit_actions`, `test.guardrails.blocking_suite`

## events.commands_emit_user_actions

- Rule: high-level commands and interaction commits own user action events
- Sections: `section_14_interaction_engine`, `section_22_guardrails_machine_checks`, `section_27_final_release_gates`
- Tests: `test.api.typed_action_payloads`, `test.interaction.commands_emit_user_actions`, `test.guardrails.blocking_suite`

## load.prepares_before_interrupt

- Rule: failed load does not interrupt gesture
- Sections: `section_12_load_document`, `section_14_interaction_engine`, `section_22_guardrails_machine_checks`, `section_27_final_release_gates`
- Tests: `test.edit.staged_document_load_success_failure`, `test.guardrails.blocking_suite`

## load.success_interrupts_before_install

- Rule: success interrupt happens before atomic install
- Sections: `section_12_load_document`, `section_14_interaction_engine`, `section_22_guardrails_machine_checks`, `section_27_final_release_gates`
- Tests: `test.edit.staged_document_load_success_failure`, `test.guardrails.blocking_suite`

## preview.selected_move_main_repaint

- Rule: selected move preview increments main repaint, not overlay
- Sections: `section_14_interaction_engine`, `section_15_frame_render_contract`, `section_22_guardrails_machine_checks`, `section_27_final_release_gates`
- Tests: `test.frame.main_overlay_capture`, `test.guardrails.blocking_suite`

## spatial.fallback_budget_enforced

- Rule: fallback candidate union enforces maxFallbackCandidates, diagnostic counter, and typed budget-exceeded result
- Sections: `section_17_spatial_kernel`, `section_22_guardrails_machine_checks`, `section_27_final_release_gates`
- Tests: `test.spatial.fallback_budget_enforced`, `test.guardrails.blocking_suite`

## cache.hot_caches_have_capacity_eviction

- Rule: hot caches declare capacity, eviction policy, invalidation owner, and metric/probe
- Sections: `section_18_cache_policy`, `section_22_guardrails_machine_checks`, `section_27_final_release_gates`
- Tests: `test.frame.cache_capacity_eviction_policy`, `test.guardrails.blocking_suite`

## resources.mutation_inside_edit_only

- Rule: resource descriptor mutation only via CanvasEdit
- Sections: `section_07_resource_lifecycle`, `section_22_guardrails_machine_checks`, `section_27_final_release_gates`
- Tests: `test.guardrails.blocking_suite`

## resources.dirty_no_document_revision

- Rule: markResourceDirty does not increment documentRevision
- Sections: `section_07_resource_lifecycle`, `section_22_guardrails_machine_checks`, `section_27_final_release_gates`
- Tests: `test.resources.resource_dirty`, `test.resources.mark_all_resources_dirty`, `test.guardrails.blocking_suite`

## resources.app_key_only

- Rule: resource descriptors use appKey only
- Sections: `section_07_resource_lifecycle`, `section_22_guardrails_machine_checks`, `section_27_final_release_gates`
- Tests: `test.codec.schema_v1.resources_appkey_only`, `test.codec.schema_v1.reject_unknown_resource_source_kind`, `test.resources.sync_image_resolver`, `test.resources.app_owned_image_not_disposed`, `test.guardrails.blocking_suite`

## resources.resolver_reentrancy_rejected

- Rule: public runtime mutation from inside CanvasResourceResolver throws StateError without runtime effects
- Sections: `section_07_resource_lifecycle`, `section_22_guardrails_machine_checks`, `section_27_final_release_gates`
- Tests: `test.resources.resolver_reentrancy_rejected`, `test.guardrails.blocking_suite`

## codec.schema_v1_exact

- Rule: only schema v1 read/write
- Sections: `section_05_schema_v1_contract`, `section_19_codec_boundary`, `section_22_guardrails_machine_checks`, `section_27_final_release_gates`
- Tests: `test.guardrails.blocking_suite`

## codec.known_fields_validated

- Rule: known schema v1 fields are validated and canonical encoder writes only v1 fields
- Sections: `section_05_schema_v1_contract`, `section_06_validation_limits`, `section_19_codec_boundary`, `section_22_guardrails_machine_checks`, `section_27_final_release_gates`
- Tests: `test.codec.schema_v1.known_fields_validation`, `test.codec.schema_v1.reject_unknown_element_kind`, `test.codec.constructor_and_schema_limits`, `test.guardrails.blocking_suite`

## diagnostics.disabled_no_alloc_hot_path

- Rule: no record allocation on successful hot path
- Sections: `section_20_diagnostics_hub`, `section_22_guardrails_machine_checks`, `section_27_final_release_gates`
- Tests: `test.guardrails.blocking_suite`

## diagrams.all_required_present

- Rule: required Mermaid files exist
- Sections: `section_22_guardrails_machine_checks`, `section_27_final_release_gates`
- Tests: `test.guardrails.required_diagrams_present`, `test.guardrails.blocking_suite`

## surface.interactive_false_pending_line_preserved

- Rule: interactive=false cancels active routed pointers but preserves pending line state not owned by an active routed pointer
- Sections: `section_04_public_api_v1`, `section_14_interaction_engine`, `section_22_guardrails_machine_checks`, `section_27_final_release_gates`
- Tests: `test.flutter_bridge.interactive_false_pointer_routing`, `test.flutter_bridge.interactive_false_active_session_cancel`, `test.flutter_bridge.interactive_false_pending_line_preserved`, `test.guardrails.blocking_suite`

## cache.keys_use_next_revisions_only

- Rule: cache keys use next-owned revision facts and stable inputs, not legacy snapshot shapes
- Sections: `section_18_cache_policy`, `section_22_guardrails_machine_checks`, `section_27_final_release_gates`
- Tests: `test.frame.cache_keys_do_not_use_legacy_snapshot_shape`, `test.guardrails.blocking_suite`

## cache.frame_meta_not_element_visual

- Rule: camera/background/grid use frameMetaRevision and must not invalidate ordinary element paint plans
- Sections: `section_15_frame_render_contract`, `section_18_cache_policy`, `section_22_guardrails_machine_checks`, `section_27_final_release_gates`
- Tests: `test.frame.camera_pan_preserves_ordinary_paint_plan`, `test.guardrails.blocking_suite`

## codec.no_runtime_side_effects

- Rule: schema v1 decode/encode validates and materializes DTOs without mutating runtime or store state
- Sections: `section_19_codec_boundary`, `section_22_guardrails_machine_checks`, `section_27_final_release_gates`
- Tests: `test.codec.decode_encode_no_runtime_side_effects`, `test.guardrails.blocking_suite`

## core.import_boundaries

- Rule: package-owned source paths obey the forbidden import matrix from `section_03_package_layout`
- Sections: `section_03_package_layout`, `section_22_guardrails_machine_checks`, `section_27_final_release_gates`
- Tests: `test.guardrails.import_boundaries`, `test.guardrails.blocking_suite`

## diagnostics.sanitized_public_projection

- Rule: diagnostic details expose only sanitized bounded public data and never runtime objects, images, closures, or full scene dumps
- Sections: `section_20_diagnostics_hub`, `section_22_guardrails_machine_checks`, `section_27_final_release_gates`
- Tests: `test.diagnostics.sanitizer_and_public_projection`, `test.guardrails.blocking_suite`

## edit.no_global_invalidation_except_replacement

- Rule: ordinary edits compile exact touched invalidation; only document replacement may use global invalidation
- Sections: `section_11_edit_kernel`, `section_22_guardrails_machine_checks`, `section_27_final_release_gates`
- Tests: `test.edit.exact_touched_invalidation`, `test.guardrails.blocking_suite`

## edit.operation_matrix_complete

- Rule: every operation matrix row has an executable effect assertion for revisions, spatial, projection, repaint, and events
- Sections: `section_13_operation_matrix`, `section_22_guardrails_machine_checks`, `section_27_final_release_gates`
- Tests: `test.edit.operation_matrix_effects`, `test.guardrails.blocking_suite`

## frame.no_global_scene_sort

- Rule: selected supplement staging merges by orderToken and does not globally sort all scene elements
- Sections: `section_15_frame_render_contract`, `section_22_guardrails_machine_checks`, `section_27_final_release_gates`
- Tests: `test.frame.selected_supplement_staging_no_global_sort`, `test.guardrails.blocking_suite`

## frame.paint_plan_excludes_preview_delta

- Rule: PaintPlanCache stores ordinary committed records only and excludes selectedMoveDelta/previewDelta from keys and values
- Sections: `section_15_frame_render_contract`, `section_18_cache_policy`, `section_22_guardrails_machine_checks`, `section_27_final_release_gates`
- Tests: `test.frame.paint_plan_excludes_preview_delta`, `test.guardrails.blocking_suite`

## geometry.no_legacy_scene_order

- Rule: geometry and hit-test policy does not reuse legacy SceneNode traversal or legacy scene order logic
- Sections: `section_16_geometry_policy`, `section_22_guardrails_machine_checks`, `section_27_final_release_gates`
- Tests: `test.geometry.no_legacy_scene_order`, `test.guardrails.blocking_suite`

## geometry.eraser_exact_budget_no_partial

- Rule: eraser exact-check budget exceeded paths produce corridor-only preview or terminal no-op cleanup, never partial erase
- Sections: `section_16_geometry_policy`, `section_22_guardrails_machine_checks`, `section_27_final_release_gates`
- Tests: `test.geometry.eraser_exact_budget_no_partial_commit`, `test.guardrails.blocking_suite`

## interaction.no_concrete_store_imports

- Rule: InteractionEngine uses EditKernel and narrow read-only query ports, not concrete store imports or mutations
- Sections: `section_14_interaction_engine`, `section_22_guardrails_machine_checks`, `section_27_final_release_gates`
- Tests: `test.interaction.state_machines`, `test.guardrails.blocking_suite`

## interaction.no_resolver_on_cancel_paths

- Rule: selected-move resolver is not called on cancel, load, mode-change, `interactive=false`, stale terminal, or dispose paths
- Sections: `section_14_interaction_engine`, `section_22_guardrails_machine_checks`, `section_27_final_release_gates`
- Tests: `test.interaction.move_resolver_not_called_on_cancel_cleanup`, `test.guardrails.blocking_suite`

## interaction.no_stale_terminal_commit

- Rule: stale or controllerEpoch-mismatched terminal samples cannot create commit intent
- Sections: `section_14_interaction_engine`, `section_22_guardrails_machine_checks`, `section_27_final_release_gates`
- Tests: `test.interaction.no_stale_terminal_commit`, `test.guardrails.blocking_suite`

## projection.only_explicit_read_paths

- Rule: `CanvasDocument` projection is built only by read/encode/test/tool or explicit draft-read paths, never pointer/hit/paint hot paths
- Sections: `section_10_runtime_data_model`, `section_22_guardrails_machine_checks`, `section_27_final_release_gates`
- Tests: `test.store.read_document_projection`, `test.store.no_projection_hot_path`, `test.guardrails.blocking_suite`

## resources.no_same_frame_missing_retry

- Rule: missing/null resource resolve results are cached by resourceId and resourceRevision for the frame instead of retried immediately
- Sections: `section_07_resource_lifecycle`, `section_22_guardrails_machine_checks`, `section_27_final_release_gates`
- Tests: `test.resources.missing_result_cached_per_revision`, `test.guardrails.blocking_suite`

## resources.resolver_boundary_owned_by_resource_kernel

- Rule: painters and frame code never call CanvasResourceResolver directly; ResourceKernel owns resolver access
- Sections: `section_07_resource_lifecycle`, `section_22_guardrails_machine_checks`, `section_27_final_release_gates`
- Tests: `test.resources.painter_never_calls_resolver_directly`, `test.guardrails.blocking_suite`

## resources.resolver_frame_budget

- Rule: ResourceKernel enforces per-frame sync resolver call budget and budget-exceeded placeholders are not cached as null/missing
- Sections: `section_07_resource_lifecycle`, `section_22_guardrails_machine_checks`, `section_27_final_release_gates`
- Tests: `test.resources.resolver_frame_budget`, `test.guardrails.blocking_suite`

## spatial.no_full_clone_ordinary_edit

- Rule: ordinary spatial updates touch only changed ids/pages; full rebuild is reserved for replacement/load paths
- Sections: `section_17_spatial_kernel`, `section_22_guardrails_machine_checks`, `section_27_final_release_gates`
- Tests: `test.spatial.no_full_clone_for_touched_update`, `test.guardrails.blocking_suite`

## spatial.stale_candidate_rejected

- Rule: stale candidate handles are rejected by generation and structuralRevision checks before frame/hit use
- Sections: `section_17_spatial_kernel`, `section_22_guardrails_machine_checks`, `section_27_final_release_gates`
- Tests: `test.spatial.stale_generation_rejected`, `test.guardrails.blocking_suite`

## store.no_public_document_live_state

- Rule: DocumentStoreKernel stores compact committed tables, not a live mutable `CanvasDocument`
- Sections: `section_10_runtime_data_model`, `section_22_guardrails_machine_checks`, `section_27_final_release_gates`
- Tests: `test.store.public_document_is_projection_only`, `test.guardrails.blocking_suite`

## surface.pointer_samples_normalized_before_runtime

- Rule: Flutter surface adapters pass only normalized finite pointer samples into runtime routing
- Sections: `section_14_interaction_engine`, `section_22_guardrails_machine_checks`, `section_27_final_release_gates`
- Tests: `test.flutter_bridge.pointer_adapter_finite_normalization`, `test.guardrails.blocking_suite`
