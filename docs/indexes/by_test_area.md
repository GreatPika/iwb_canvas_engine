# By test area

Explicit and phase-required tests from the registry, linked to phases, sections and guardrails.

## test.api_contract.public_api_v1_compiles_as_written

- Path: `test/api_contract/public_api_v1_compiles_as_written_test.dart`
- Phases: `P2`
- Sections: `section_04_public_api_v1`, `section_23_tests`
- Guardrails: `api.public_api_compiles_as_written`, `api.exported_dartdoc_complete`, `api.public_class_modifiers_explicit`

## test.api_contract.app_next_engine_adapter_compile_fixture

- Path: `test/api_contract/app_next_engine_adapter_compile_fixture_test.dart`
- Fixture: `test/api_contract/fixtures/app_next_engine_adapter_compile_fixture.dart`
- Phases: `P1.5`, `P2`, `P14`
- Sections: `section_04_public_api_v1`, `section_22_guardrails_machine_checks`, `section_23_tests`, `section_27_final_release_gates`
- Guardrails: `api.integration_surface_complete`
- Focus: external app-adapter responsibilities compile through only
  `package:iwb_canvas_engine/iwb_canvas_engine.dart`, with forbidden import
  checks for `src/**`, legacy symbols, and internal runtime classes.

## test.api_contract.public_readable_union_variants

- Path: `test/api_contract/public_readable_union_variants_test.dart`
- Phases: `P2`, `P7`
- Sections: `section_04_public_api_v1`, `section_07_resource_lifecycle`, `section_23_tests`
- Guardrails: `api.resource_source_app_key_publicly_readable`, `api.public_exports_complete`, `api.equality_policy_explicit`, `resources.app_key_only`

## test.api_contract.preview_state_sealed_union

- Path: `test/api_contract/preview_state_sealed_union_test.dart`
- Phases: `P2`, `P10`, `P11`, `P12`, `P13`
- Sections: `section_04_public_api_v1`, `section_14_interaction_engine`, `section_15_frame_render_contract`, `section_23_tests`
- Guardrails: `api.preview_state_sealed_union_publicly_readable`
- Focus: public preview state is a sealed union with exported readable variants,
  stable CanvasPreviewKind values, shared CanvasStrokePreview facts, immutable
  iterable payloads, and no public pointer/session/selection-owned payload.

## test.api.canvas_field_update

- Path: `test/api/canvas_field_update_test.dart`
- Phases: `P2`
- Sections: `section_04_public_api_v1`, `section_23_tests`
- Guardrails: `api.equality_policy_explicit`

## test.api_contract.canvas_field_update_static_semantics

- Path: `test/api_contract/canvas_field_update_static_semantics_test.dart`
- Phases: `P2`
- Sections: `section_04_public_api_v1`, `section_23_tests`
- Guardrails: `api.public_api_compiles_as_written`, `api.public_signature_shape`, `api.public_types_complete`

## test.api_contract.no_undefined_public_type_references

- Path: `test/api_contract/no_undefined_public_type_references_test.dart`
- Phases: `P2`
- Sections: `section_04_public_api_v1`, `section_23_tests`
- Guardrails: `api.no_undefined_public_type_references`, `api.public_signature_shape`
- Proof focus: exported signature types, raw JSON/diagnostic dynamic boundaries, and `CanvasMetadata` use for metadata-bearing DTO signatures

## test.api_contract.no_legacy_public_symbols

- Path: `test/api_contract/no_legacy_public_symbols_test.dart`
- Phases: `P0`, `P2`
- Sections: `section_03_package_layout`, `section_04_public_api_v1`, `section_23_tests`
- Guardrails: `api.no_legacy_public_types`

## test.api_contract.dto_immutability

- Path: `test/api_contract/dto_immutability_test.dart`
- Phases: `P2`
- Sections: `section_04_public_api_v1`, `section_23_tests`
- Guardrails: `api.dto_immutability`
- Proof focus: defensive copy, unmodifiable collections, `CanvasMetadata` deep-freeze, invalid public construction rejection, validating-constructor factory policy, and approved const-form drift

## test.api_contract.public_equality_policy

- Path: `test/api_contract/public_equality_policy_test.dart`
- Phases: `P2`
- Sections: `section_04_public_api_v1`, `section_23_tests`
- Guardrails: `api.equality_policy_explicit`

## test.codec.schema_v1.known_fields_validation

- Path: `test/codec/schema_v1/known_fields_validation_test.dart`
- Phases: `P3`
- Sections: `section_05_schema_v1_contract`, `section_23_tests`
- Guardrails: `codec.known_fields_validated`

## test.codec.schema_v1.resources_appkey_only

- Path: `test/codec/schema_v1/resources_appkey_only_test.dart`
- Phases: `P3`, `P7`
- Sections: `section_05_schema_v1_contract`, `section_07_resource_lifecycle`, `section_23_tests`
- Guardrails: `resources.app_key_only`

## test.codec.schema_v1.reject_unknown_element_kind

- Path: `test/codec/schema_v1/reject_unknown_element_kind_test.dart`
- Phases: `P3`
- Sections: `section_05_schema_v1_contract`, `section_23_tests`
- Guardrails: `codec.known_fields_validated`

## test.codec.schema_v1.reject_unknown_resource_source_kind

- Path: `test/codec/schema_v1/reject_unknown_resource_source_kind_test.dart`
- Phases: `P3`, `P7`
- Sections: `section_05_schema_v1_contract`, `section_07_resource_lifecycle`, `section_23_tests`
- Guardrails: `resources.app_key_only`

## test.resources.sync_image_resolver

- Path: `test/resources/sync_image_resolver_test.dart`
- Phases: `P7`, `P13`
- Sections: `section_07_resource_lifecycle`, `section_23_tests`
- Guardrails: `resources.app_key_only`

## test.resources.app_owned_image_not_disposed

- Path: `test/resources/app_owned_image_not_disposed_test.dart`
- Phases: `P7`, `P13`
- Sections: `section_07_resource_lifecycle`, `section_23_tests`
- Guardrails: `resources.app_key_only`

## test.resources.resource_dirty

- Path: `test/resources/resource_dirty_test.dart`
- Phases: `P7`
- Sections: `section_07_resource_lifecycle`, `section_23_tests`
- Guardrails: `resources.dirty_no_document_revision`

## test.resources.mark_all_resources_dirty

- Path: `test/resources/mark_all_resources_dirty_test.dart`
- Phases: `P7`
- Sections: `section_07_resource_lifecycle`, `section_23_tests`
- Guardrails: `resources.dirty_no_document_revision`

## test.resources.resolver_reentrancy_rejected

- Path: `test/resources/resolver_reentrancy_rejected_test.dart`
- Phases: `P7`
- Sections: `section_07_resource_lifecycle`, `section_23_tests`
- Guardrails: `resources.resolver_reentrancy_rejected`

## test.api.typed_action_payloads

- Path: `test/api/typed_action_payloads_test.dart`
- Phases: `P2`, `P10`, `P11`, `P12`
- Sections: `section_04_public_api_v1`, `section_14_interaction_engine`, `section_23_tests`
- Guardrails: `events.commands_emit_user_actions`
- Focus: command and interaction action payload shapes, including
  `CanvasTextEditActionPayload` for `editText` without raw text content.

## test.edit.low_level_mutations_do_not_emit_actions

- Path: `test/edit/low_level_mutations_do_not_emit_actions_test.dart`
- Phases: `P5`
- Sections: `section_11_edit_kernel`, `section_23_tests`
- Guardrails: `events.low_level_edit_no_user_actions`

## test.interaction.commands_emit_user_actions

- Path: `test/interaction/commands_emit_user_actions_test.dart`
- Phases: `P10`, `P11`, `P12`
- Sections: `section_14_interaction_engine`, `section_23_tests`
- Guardrails: `events.commands_emit_user_actions`
- Focus: high-level commands and changed interaction commits, including
  `commitTextEdit`, emit user action notifications only after atomic install.

## test.interaction.runtime_created_timestamps_monotonic

- Path: `test/interaction/runtime_created_timestamps_monotonic_test.dart`
- Phases: `P10`, `P11`, `P12`
- Sections: `section_13_operation_matrix`, `section_14_interaction_engine`, `section_23_tests`
- Guardrails: `events.runtime_created_timestamps_monotonic`
- Focus: action events, text edit requests, pending line start previews, and
  selected move resolver requests resolve nullable or backwards `timestampMs`
  hints through one runtime-local monotonic cursor, while no-output paths create
  no timestamped action or text request.

## test.flutter_bridge.interactive_false_pointer_routing

- Path: `test/flutter_bridge/interactive_false_pointer_routing_test.dart`
- Phases: `P13`
- Sections: `section_14_interaction_engine`, `section_23_tests`
- Guardrails: `surface.interactive_false_pending_line_preserved`

## test.flutter_bridge.interactive_false_active_session_cancel

- Path: `test/flutter_bridge/interactive_false_active_session_cancel_test.dart`
- Phases: `P13`
- Sections: `section_14_interaction_engine`, `section_23_tests`
- Guardrails: `surface.interactive_false_pending_line_preserved`

## test.flutter_bridge.interactive_false_pending_line_preserved

- Path: `test/flutter_bridge/interactive_false_pending_line_preserved_test.dart`
- Phases: `P13`
- Sections: `section_04_public_api_v1`, `section_14_interaction_engine`, `section_23_tests`
- Guardrails: `surface.interactive_false_pending_line_preserved`

## test.flutter_bridge.interactive_false_state_isolation

- Path: `test/flutter_bridge/interactive_false_state_isolation_test.dart`
- Phases: `P13`
- Sections: `section_04_public_api_v1`, `section_14_interaction_engine`, `section_23_tests`
- Guardrails: `surface.interactive_false_pending_line_preserved`
- Focus: toggling interactive=false does not mutate runtime mode, committed
  document, selection, or resources while active pointer cleanup remains scoped
  to pointer-owned preview state.

## test.flutter_bridge.single_active_surface

- Path: `test/flutter_bridge/single_active_surface_test.dart`
- Phases: `P13`
- Sections: `section_04_public_api_v1`, `section_23_tests`
- Guardrails: `none`

## test.flutter_bridge.surface_resource_session_lifecycle

- Path: `test/flutter_bridge/surface_resource_session_lifecycle_test.dart`
- Phases: `P13`
- Sections: `section_04_public_api_v1`, `section_07_resource_lifecycle`, `section_23_tests`
- Guardrails: `resources.resolver_boundary_owned_by_surface_session`

## test.functional_ledger.legacy_capability_inventory

- Path: `test/functional_ledger/legacy_capability_inventory_test.dart`
- Phases: `P1`
- Sections: `section_08_legacy_capability_inventory`, `section_23_tests`
- Guardrails: `oracle.legacy_capability_inventory_complete`

## test.functional_ledger.row_specific_tests

- Path: `test/functional_ledger/row_specific_tests_test.dart`
- Phases: `P1.5`, `P14`
- Sections: `section_08_functional_ledger`, `section_23_tests`
- Guardrails: `api.functional_ledger_complete`

## test.api_contract.v1_scope_gate

- Path: `test/api_contract/v1_scope_gate_test.dart`
- Phases: `P1.5`
- Sections: `section_00_status_and_scope`, `section_04_public_api_v1`, `section_09_accepted_differences`, `section_23_tests`
- Guardrails: `api.v1_scope_gate_green_before_freeze`

## test.codec.constructor_and_schema_limits

- Path: `test/codec/constructor_and_schema_limits_test.dart`
- Phases: `P2`, `P3`
- Sections: `section_06_validation_limits`, `section_23_tests`
- Guardrails: `codec.known_fields_validated`, `api.id_validation_no_extension_type_escape`
- Focus: public DTO construction and schema decode reject non-invertible
  element transforms with `fieldMustBeInvertible` while `CanvasTransform`
  remains the general affine value type.

## test.store.read_document_projection

- Path: `test/store/read_document_projection_test.dart`
- Phases: `P4`
- Sections: `section_10_runtime_data_model`, `section_23_tests`
- Guardrails: `projection.only_explicit_read_paths`

## test.runtime.dispose_lifecycle

- Path: `test/runtime/dispose_lifecycle_test.dart`
- Phases: `P4`
- Sections: `section_04_public_api_v1`, `section_10_runtime_data_model`, `section_23_tests`
- Guardrails: `none`

## test.runtime.runtime_state_publication

- Path: `test/runtime/runtime_state_publication_test.dart`
- Phases: `P5`
- Sections: `section_04_public_api_v1`, `section_10_runtime_data_model`, `section_11_edit_kernel`, `section_23_tests`
- Guardrails: `none`
- Focus: ordinary document edits publish one coherent CanvasRuntimeState, while
  no-op edits and no-op runtime operations remain public-state silent.

## test.runtime.load_document_state_publication

- Path: `test/runtime/load_document_state_publication_test.dart`
- Phases: `P6`
- Sections: `section_10_runtime_data_model`, `section_12_load_document`, `section_23_tests`
- Guardrails: `none`
- Focus: successful loadDocument publishes exactly one post-install
  CanvasRuntimeState with document, selection, viewCamera, epoch, and
  conditional preview cleanup revisions; failed loads publish none.

## test.runtime.interaction_settings_state

- Path: `test/runtime/interaction_settings_state_test.dart`
- Phases: `P11`
- Sections: `section_04_public_api_v1`, `section_10_runtime_data_model`, `section_14_interaction_engine`, `section_23_tests`
- Guardrails: `none`
- Focus: interaction setting changes publish interaction revision changes and
  only advance selection or preview revisions when the same operation owns
  draw-mode selection clear or active preview cleanup.

## test.store.no_projection_hot_path

- Path: `test/store/no_projection_hot_path_test.dart`
- Phases: `P4`, `P9`
- Sections: `section_10_runtime_data_model`, `section_15_frame_render_contract`, `section_23_tests`
- Guardrails: `projection.only_explicit_read_paths`

## test.edit.sync_non_nested_async_stale

- Path: `test/edit/sync_non_nested_async_stale_test.dart`
- Phases: `P5`
- Sections: `section_11_edit_kernel`, `section_13_operation_matrix`, `section_23_tests`
- Guardrails: `edit.sync_non_nested`, `edit.stale_handle_rejected`

## test.edit.rollback

- Path: `test/edit/rollback_test.dart`
- Phases: `P5`
- Sections: `section_11_edit_kernel`, `section_23_tests`
- Guardrails: `edit.rollback_no_effects`

## test.edit.field_update_nullable_semantics

- Path: `test/edit/field_update_nullable_semantics_test.dart`
- Phases: `P5`
- Sections: `section_04_public_api_v1`, `section_11_edit_kernel`, `section_23_tests`
- Guardrails: `edit.operation_matrix_complete`, `edit.no_global_invalidation_except_replacement`
- Focus: generated and dynamic `CanvasElementUpdate.transform` values reject
  non-invertible element transforms before draft mutation.

## test.edit.typed_effects_no_frame_dependency

- Path: `test/edit/typed_effects_no_frame_dependency_test.dart`
- Phases: `P5`
- Sections: `section_11_edit_kernel`, `section_23_tests`
- Guardrails: `edit.typed_effects_no_frame_dependency`

## test.edit.staged_document_load_success_failure

- Path: `test/edit/staged_document_load_success_failure_test.dart`
- Phases: `P6`, `P10`, `P11`, `P12`
- Sections: `section_12_load_document`, `section_23_tests`
- Guardrails: `load.prepares_before_interrupt`, `load.success_interrupts_before_install`
- Focus: `loadDocument` rejects non-invertible element transforms before
  `PreparedDocumentLoad` success, interaction interruption, repaint, action
  events, or public state publication.

## test.geometry.hit_policy

- Path: `test/geometry/hit_policy_test.dart`
- Phases: `P8`
- Sections: `section_16_geometry_policy`, `section_23_tests`
- Guardrails: `none`
- Focus: corrupted committed rows with non-invertible element transforms return
  miss, record only policy-gated diagnostics, continue candidate scanning, and
  have no coarse fallback acceptance.

## test.spatial.touched_update

- Path: `test/spatial/touched_update_test.dart`
- Phases: `P8`
- Sections: `section_17_spatial_kernel`, `section_23_tests`
- Guardrails: `none`

## test.spatial.fallback_budget_enforced

- Path: `test/spatial/fallback_budget_enforced_test.dart`
- Phases: `P8`
- Sections: `section_17_spatial_kernel`, `section_23_tests`
- Guardrails: `spatial.fallback_budget_enforced`

## test.frame.main_overlay_capture

- Path: `test/frame/main_overlay_capture_test.dart`
- Phases: `P9`
- Sections: `section_15_frame_render_contract`, `section_23_tests`
- Guardrails: `preview.selected_move_main_repaint`, `frame.committed_facts_via_frame_facts_port`
- Focus: main frame capture obtains committed frame revision facts through
  `FrameFactsPort` while selection facts remain behind `SelectionFactsPort`.

## test.frame.no_live_runtime_read_in_painters

- Path: `test/frame/no_live_runtime_read_in_painters_test.dart`
- Phases: `P9`
- Sections: `section_15_frame_render_contract`, `section_23_tests`
- Guardrails: `frame.committed_facts_via_frame_facts_port`
- Focus: painters receive immutable frame records and resolved assets only;
  production frame code obtains committed row facts and descriptor facts through
  `FrameFactsPort` instead of concrete store imports.

## test.frame.cache_capacity_eviction_policy

- Path: `test/frame/cache_capacity_eviction_policy_test.dart`
- Phases: `P9`
- Sections: `section_18_cache_policy`, `section_23_tests`
- Guardrails: `cache.hot_caches_have_capacity_eviction`

## test.frame.paint_plan_excludes_preview_delta

- Path: `test/frame/paint_plan_excludes_preview_delta_test.dart`
- Phases: `P9`
- Sections: `section_15_frame_render_contract`, `section_18_cache_policy`, `section_23_tests`
- Guardrails: `frame.paint_plan_excludes_preview_delta`

## test.frame.paint_plan_excludes_selection_state

- Path: `test/frame/paint_plan_excludes_selection_state_test.dart`
- Phases: `P9`
- Sections: `section_15_frame_render_contract`, `section_18_cache_policy`, `section_23_tests`
- Guardrails: `frame.paint_plan_excludes_selection_state`

## test.frame.camera_pan_preserves_ordinary_paint_plan

- Path: `test/frame/camera_pan_preserves_ordinary_paint_plan_test.dart`
- Phases: `P9`
- Sections: `section_15_frame_render_contract`, `section_18_cache_policy`, `section_23_tests`
- Guardrails: `cache.background_grid_not_element_visual`
- Focus: runtime view camera preserves ordinary paint plans while backgroundRevision
  and gridRevision invalidate StaticBackgroundCache without entering ordinary
  PaintPlanCache identity; persisted document camera remains edit-owned.

## test.interaction.preview_public_state

- Path: `test/interaction/preview_public_state_test.dart`
- Phases: `P10`, `P11`, `P12`
- Sections: `section_14_interaction_engine`, `section_23_tests`
- Guardrails: `none`
- Focus: preview-only pointer changes and active preview cleanup publish
  state.revisions.preview without document, selection, resourceVisual,
  interaction, viewCamera, or action effects; empty cleanup is silent.

## test.interaction.state_machines

- Path: `test/interaction/state_machines_test.dart`
- Phases: `P10`, `P11`, `P12`
- Sections: `section_14_interaction_engine`, `section_23_tests`
- Guardrails: `interaction.no_concrete_store_imports`

## test.interaction.move_resolver_reentrancy

- Path: `test/interaction/move_resolver_reentrancy_test.dart`
- Phases: `P10`
- Sections: `section_14_interaction_engine`, `section_23_tests`
- Guardrails: `none`

## test.flutter_bridge.widget_paint

- Path: `test/flutter_bridge/widget_paint_test.dart`
- Phases: `P13`
- Sections: `section_14_interaction_engine`, `section_15_frame_render_contract`, `section_23_tests`
- Guardrails: `none`

## test.benchmarks.required_cases

- Path: `test/benchmarks/required_cases_test.dart`
- Phases: `P14`
- Sections: `section_24_benchmarks`, `section_23_tests`
- Guardrails: `none`

## test.guardrails.required_diagrams_present

- Path: `test/guardrails/required_diagrams_present_test.dart`
- Phases: `P0`, `P14`
- Sections: `section_23_tests`
- Guardrails: `diagrams.all_required_present`

## test.guardrails.frame_committed_facts_via_frame_facts_port

- Path: `test/guardrails/frame_committed_facts_via_frame_facts_port_test.dart`
- Phases: `P9`, `P14`
- Sections: `section_03_package_layout`, `section_15_frame_render_contract`, `section_22_guardrails_machine_checks`, `section_23_tests`
- Guardrails: `frame.committed_facts_via_frame_facts_port`
- Focus: production `lib/src/frame/**` imports no concrete store internals for
  committed frame reads, and frame capture, row resolution, descriptor lookup,
  and `resourceRevision` access route through `FrameFactsPort`.

## test.guardrails.blocking_suite

- Path: `test/guardrails/blocking_suite_test.dart`
- Phases: `P0`, `P14`
- Sections: `section_02_architecture_model`, `section_22_guardrails_machine_checks`, `section_23_tests`, `section_27_final_release_gates`
- Guardrails: `oracle.legacy_capability_inventory_complete`, `api.functional_ledger_complete`, `api.integration_surface_complete`, `api.v1_scope_gate_green_before_freeze`, `api.no_legacy_public_types`, `api.public_exports_complete`, `api.public_types_complete`, `api.public_api_compiles_as_written`, `api.exported_dartdoc_complete`, `api.public_class_modifiers_explicit`, `api.public_signature_shape`, `api.no_undefined_public_type_references`, `api.dto_immutability`, `api.equality_policy_explicit`, `api.id_validation_no_extension_type_escape`, `core.no_legacy_imports`, `core.import_boundaries`, `core.no_unapproved_part_files`, `core.no_scene_controller_shape_dependency`, `core.no_node_spec_patch_shape_dependency`, `core.single_runtime_root`, `store.no_public_document_live_state`, `selection.owner_separate_from_document`, `projection.only_explicit_read_paths`, `edit.sync_non_nested`, `edit.rollback_no_effects`, `edit.stale_handle_rejected`, `edit.operation_matrix_complete`, `edit.no_global_invalidation_except_replacement`, `edit.typed_effects_no_frame_dependency`, `events.low_level_edit_no_user_actions`, `events.commands_emit_user_actions`, `events.runtime_created_timestamps_monotonic`, `load.prepares_before_interrupt`, `load.success_interrupts_before_install`, `preview.selected_move_main_repaint`, `interaction.no_concrete_store_imports`, `interaction.no_concrete_selection_imports`, `interaction.no_resolver_on_cancel_paths`, `interaction.no_stale_terminal_commit`, `interaction.text_edit_stale_commit_guard`, `geometry.no_legacy_scene_order`, `geometry.eraser_exact_budget_no_partial`, `spatial.no_full_clone_ordinary_edit`, `spatial.stale_candidate_rejected`, `spatial.fallback_budget_enforced`, `frame.committed_facts_via_frame_facts_port`, `frame.no_global_scene_sort`, `frame.paint_plan_excludes_preview_delta`, `frame.paint_plan_excludes_selection_state`, `cache.keys_use_next_revisions_only`, `cache.background_grid_not_element_visual`, `cache.hot_caches_have_capacity_eviction`, `resources.mutation_inside_edit_only`, `resources.dirty_no_document_revision`, `resources.app_key_only`, `resources.resolver_boundary_owned_by_surface_session`, `resources.resolver_frame_budget`, `resources.no_same_frame_missing_retry`, `resources.resolver_reentrancy_rejected`, `codec.schema_v1_exact`, `codec.known_fields_validated`, `codec.no_runtime_side_effects`, `diagnostics.disabled_no_alloc_hot_path`, `diagnostics.sanitized_public_projection`, `surface.pointer_samples_normalized_before_runtime`, `surface.interactive_false_pending_line_preserved`, `diagrams.all_required_present`

## test.codec.decode_encode_no_runtime_side_effects

- Path: `test/codec/decode_encode_no_runtime_side_effects_test.dart`
- Phases: `P3`
- Sections: `section_19_codec_boundary`, `section_23_tests`
- Guardrails: `codec.no_runtime_side_effects`

## test.diagnostics.sanitizer_and_public_projection

- Path: `test/diagnostics/sanitizer_and_public_projection_test.dart`
- Phases: `P3`, `P14`
- Sections: `section_20_diagnostics_hub`, `section_23_tests`
- Guardrails: `diagnostics.disabled_no_alloc_hot_path`, `diagnostics.sanitized_public_projection`
- Focus: corrupted-row diagnostic details are sanitized and diagnostics
  disabled hot paths allocate no records.

## test.edit.exact_touched_invalidation

- Path: `test/edit/exact_touched_invalidation_test.dart`
- Phases: `P5`
- Sections: `section_11_edit_kernel`, `section_23_tests`
- Guardrails: `edit.no_global_invalidation_except_replacement`

## test.edit.operation_matrix_effects

- Path: `test/edit/operation_matrix_effects_test.dart`
- Phases: `P5`
- Sections: `section_13_operation_matrix`, `section_23_tests`
- Guardrails: `edit.operation_matrix_complete`
- Scope: expanded operation matrix dimensions: touched state, public state revisions, internal revisions, spatial, projection, resource effects, repaint, user-action events, no-op behavior, and rollback behavior

## test.frame.cache_keys_do_not_use_legacy_snapshot_shape

- Path: `test/frame/cache_keys_do_not_use_legacy_snapshot_shape_test.dart`
- Phases: `P9`
- Sections: `section_18_cache_policy`, `section_23_tests`
- Guardrails: `cache.keys_use_next_revisions_only`

## test.frame.selected_supplement_staging_no_global_sort

- Path: `test/frame/selected_supplement_staging_no_global_sort_test.dart`
- Phases: `P9`
- Sections: `section_15_frame_render_contract`, `section_23_tests`
- Guardrails: `frame.no_global_scene_sort`

## test.geometry.no_legacy_scene_order

- Path: `test/geometry/no_legacy_scene_order_test.dart`
- Phases: `P8`
- Sections: `section_16_geometry_policy`, `section_23_tests`
- Guardrails: `geometry.no_legacy_scene_order`

## test.geometry.eraser_exact_budget_no_partial_commit

- Path: `test/geometry/eraser_exact_budget_no_partial_commit_test.dart`
- Phases: `P12`
- Sections: `section_16_geometry_policy`, `section_23_tests`
- Guardrails: `geometry.eraser_exact_budget_no_partial`

## test.guardrails.import_boundaries

- Path: `test/guardrails/import_boundaries_test.dart`
- Phases: `P0`
- Sections: `section_03_package_layout`, `section_23_tests`
- Guardrails: `core.import_boundaries`, `core.no_unapproved_part_files`

## test.interaction.move_resolver_not_called_on_cancel_cleanup

- Path: `test/interaction/move_resolver_not_called_on_cancel_cleanup_test.dart`
- Phases: `P10`, `P11`, `P12`
- Sections: `section_14_interaction_engine`, `section_23_tests`
- Guardrails: `interaction.no_resolver_on_cancel_paths`

## test.interaction.no_stale_terminal_commit

- Path: `test/interaction/no_stale_terminal_commit_test.dart`
- Phases: `P10`
- Sections: `section_14_interaction_engine`, `section_23_tests`
- Guardrails: `interaction.no_stale_terminal_commit`

## test.interaction.text_edit_stale_commit_guard

- Path: `test/interaction/text_edit_stale_commit_guard_test.dart`
- Phases: `P12`
- Sections: `section_04_public_api_v1`, `section_13_operation_matrix`, `section_14_interaction_engine`, `section_23_tests`
- Guardrails: `interaction.text_edit_stale_commit_guard`, `events.commands_emit_user_actions`
- Focus: `CanvasInteractionRequestId`-keyed text commits reject stale request
  facts without effects, allow unrelated `documentRevision` changes, retire
  accepted requests, and emit `editText` only for changed text.

## test.selection.runtime_owner_separation

- Path: `test/selection/runtime_owner_separation_test.dart`
- Phases: `P4`, `P5`, `P6`, `P9`, `P10`
- Sections: `section_02_architecture_model`, `section_10_runtime_data_model`, `section_23_tests`
- Guardrails: `selection.owner_separate_from_document`

## test.guardrails.selection_boundary_imports

- Path: `test/guardrails/selection_boundary_imports_test.dart`
- Phases: `P0`, `P10`
- Sections: `section_03_package_layout`, `section_14_interaction_engine`, `section_23_tests`
- Guardrails: `interaction.no_concrete_selection_imports`

## test.resources.missing_result_suppressed_per_frame

- Path: `test/resources/missing_result_suppressed_per_frame_test.dart`
- Phases: `P7`
- Sections: `section_07_resource_lifecycle`, `section_23_tests`
- Guardrails: `resources.no_same_frame_missing_retry`

## test.resources.resolver_swap_starts_fresh_cache

- Path: `test/resources/resolver_swap_starts_fresh_cache_test.dart`
- Phases: `P7`
- Sections: `section_07_resource_lifecycle`, `section_23_tests`
- Guardrails: `resources.resolver_boundary_owned_by_surface_session`

## test.resources.surface_session_cache_lifecycle

- Path: `test/resources/surface_session_cache_lifecycle_test.dart`
- Phases: `P7`, `P13`
- Sections: `section_07_resource_lifecycle`, `section_23_tests`
- Guardrails: `resources.resolver_boundary_owned_by_surface_session`

## test.resources.painter_never_calls_resolver_directly

- Path: `test/resources/painter_never_calls_resolver_directly_test.dart`
- Phases: `P7`
- Sections: `section_07_resource_lifecycle`, `section_23_tests`
- Guardrails: `resources.resolver_boundary_owned_by_surface_session`

## test.resources.resolver_frame_budget

- Path: `test/resources/resolver_frame_budget_test.dart`
- Phases: `P7`, `P9`, `P13`
- Sections: `section_07_resource_lifecycle`, `section_23_tests`
- Guardrails: `resources.resolver_frame_budget`

## test.spatial.no_full_clone_for_touched_update

- Path: `test/spatial/no_full_clone_for_touched_update_test.dart`
- Phases: `P8`
- Sections: `section_17_spatial_kernel`, `section_23_tests`
- Guardrails: `spatial.no_full_clone_ordinary_edit`

## test.spatial.stale_generation_rejected

- Path: `test/spatial/stale_generation_rejected_test.dart`
- Phases: `P8`
- Sections: `section_17_spatial_kernel`, `section_23_tests`
- Guardrails: `spatial.stale_candidate_rejected`

## test.store.public_document_is_projection_only

- Path: `test/store/public_document_is_projection_only_test.dart`
- Phases: `P4`
- Sections: `section_10_runtime_data_model`, `section_23_tests`
- Guardrails: `store.no_public_document_live_state`

## test.flutter_bridge.pointer_adapter_finite_normalization

- Path: `test/flutter_bridge/pointer_adapter_finite_normalization_test.dart`
- Phases: `P13`
- Sections: `section_14_interaction_engine`, `section_23_tests`
- Guardrails: `surface.pointer_samples_normalized_before_runtime`
