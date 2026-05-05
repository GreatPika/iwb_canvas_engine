# By test area

Explicit and phase-required tests from the registry, linked to phases, sections and guardrails.

## test.api_contract.public_api_v1_compiles_as_written

- Path: `test/api_contract/public_api_v1_compiles_as_written_test.dart`
- Phases: `P2`
- Sections: `section_04_public_api_v1`, `section_23_tests`
- Guardrails: `new_api.public_api_compiles_as_written`

## test.api_contract.no_undefined_public_type_references

- Path: `test/api_contract/no_undefined_public_type_references_test.dart`
- Phases: `P2`
- Sections: `section_04_public_api_v1`, `section_23_tests`
- Guardrails: `new_api.no_undefined_public_type_references`

## test.api_contract.no_old_public_symbols

- Path: `test/api_contract/no_old_public_symbols_test.dart`
- Phases: `P0`, `P2`
- Sections: `section_03_package_layout`, `section_04_public_api_v1`, `section_23_tests`
- Guardrails: `new_api.no_old_public_types`

## test.api_contract.dto_immutability

- Path: `test/api_contract/dto_immutability_test.dart`
- Phases: `P2`
- Sections: `section_04_public_api_v1`, `section_23_tests`
- Guardrails: `new_api.dto_immutability`

## test.schema_v1.known_fields_validation

- Path: `test/schema_v1/known_fields_validation_test.dart`
- Phases: `P3`
- Sections: `section_05_schema_v1_contract`, `section_23_tests`
- Guardrails: `codec.known_fields_validated`

## test.schema_v1.resources_appkey_only

- Path: `test/schema_v1/resources_appkey_only_test.dart`
- Phases: `P3`, `P4`
- Sections: `section_05_schema_v1_contract`, `section_07_resource_lifecycle`, `section_23_tests`
- Guardrails: `resources.app_key_only`

## test.schema_v1.reject_unknown_element_kind

- Path: `test/schema_v1/reject_unknown_element_kind_test.dart`
- Phases: `P3`
- Sections: `section_05_schema_v1_contract`, `section_23_tests`
- Guardrails: `codec.known_fields_validated`

## test.schema_v1.reject_unknown_resource_source_kind

- Path: `test/schema_v1/reject_unknown_resource_source_kind_test.dart`
- Phases: `P3`, `P4`
- Sections: `section_05_schema_v1_contract`, `section_07_resource_lifecycle`, `section_23_tests`
- Guardrails: `resources.app_key_only`

## test.resources.sync_image_resolver

- Path: `test/resources/sync_image_resolver_test.dart`
- Phases: `P4`, `P10`
- Sections: `section_07_resource_lifecycle`, `section_23_tests`
- Guardrails: `resources.app_key_only`

## test.resources.app_owned_image_not_disposed

- Path: `test/resources/app_owned_image_not_disposed_test.dart`
- Phases: `P4`, `P10`
- Sections: `section_07_resource_lifecycle`, `section_23_tests`
- Guardrails: `resources.app_key_only`

## test.resources.resource_dirty

- Path: `test/resources/resource_dirty_test.dart`
- Phases: `P4`
- Sections: `section_07_resource_lifecycle`, `section_23_tests`
- Guardrails: `resources.dirty_no_document_revision`

## test.resources.mark_all_resources_dirty

- Path: `test/resources/mark_all_resources_dirty_test.dart`
- Phases: `P4`
- Sections: `section_07_resource_lifecycle`, `section_23_tests`
- Guardrails: `resources.dirty_no_document_revision`

## test.events.typed_action_payloads

- Path: `test/events/typed_action_payloads_test.dart`
- Phases: `P2`, `P9`
- Sections: `section_04_public_api_v1`, `section_14_interaction_engine`, `section_23_tests`
- Guardrails: `events.commands_emit_user_actions`

## test.events.low_level_mutations_do_not_emit_actions

- Path: `test/events/edit_kernel_low_level_mutations_do_not_emit_actions_test.dart`
- Phases: `P6`
- Sections: `section_11_edit_kernel`, `section_23_tests`
- Guardrails: `events.low_level_edit_no_user_actions`

## test.events.commands_emit_user_actions

- Path: `test/events/commands_emit_user_actions_test.dart`
- Phases: `P9`
- Sections: `section_14_interaction_engine`, `section_23_tests`
- Guardrails: `events.commands_emit_user_actions`

## test.surface.interactive_false_pointer_routing

- Path: `test/surface/interactive_false_pointer_routing_test.dart`
- Phases: `P10`
- Sections: `section_14_interaction_engine`, `section_23_tests`
- Guardrails: `none`

## test.surface.interactive_false_active_session_cancel

- Path: `test/surface/interactive_false_active_session_cancel_test.dart`
- Phases: `P10`
- Sections: `section_14_interaction_engine`, `section_23_tests`
- Guardrails: `none`

## test.functional_ledger.row_specific_tests

- Path: `functional-ledger row-specific tests`
- Phases: `P1`, `P12`
- Sections: `section_08_functional_ledger`, `section_23_tests`
- Guardrails: `new_api.functional_ledger_complete`

## test.api_contract.v1_scope_gate

- Path: `public API v1 scope gate probe`
- Phases: `P1.5`
- Sections: `section_00_status_and_scope`, `section_04_public_api_v1`, `section_23_tests`
- Guardrails: `new_api.v1_scope_gate_green_before_freeze`

## test.validation_limits.constructor_and_schema_limits

- Path: `validation limits tests`
- Phases: `P2`, `P3`
- Sections: `section_06_validation_limits`, `section_23_tests`
- Guardrails: `codec.known_fields_validated`, `new_api.id_validation_no_extension_type_escape`

## test.store.read_document_projection

- Path: `readDocument projection and cache tests`
- Phases: `P5`
- Sections: `section_10_runtime_data_model`, `section_23_tests`
- Guardrails: `none`

## test.store.no_projection_hot_path

- Path: `no projection in hot path tests`
- Phases: `P5`, `P8`
- Sections: `section_10_runtime_data_model`, `section_15_frame_render_contract`, `section_23_tests`
- Guardrails: `none`

## test.edit_kernel.sync_non_nested_async_stale

- Path: `sync, non-nested, async and stale handle tests`
- Phases: `P6`
- Sections: `section_11_edit_kernel`, `section_13_operation_matrix`, `section_23_tests`
- Guardrails: `edit.sync_non_nested`, `edit.stale_handle_rejected`

## test.edit_kernel.rollback

- Path: `rollback safety tests`
- Phases: `P6`
- Sections: `section_11_edit_kernel`, `section_23_tests`
- Guardrails: `edit.rollback_no_effects`

## test.load_document.staged_success_failure

- Path: `staged loadDocument success/failure tests`
- Phases: `P6`, `P9`
- Sections: `section_12_load_document`, `section_23_tests`
- Guardrails: `load.prepares_before_interrupt`, `load.success_interrupts_before_install`

## test.geometry.hit_policy

- Path: `geometry and hit-test policy tests`
- Phases: `P7`
- Sections: `section_16_geometry_policy`, `section_23_tests`
- Guardrails: `none`

## test.spatial.touched_update

- Path: `spatial constants, outlier and touched-only update tests`
- Phases: `P7`
- Sections: `section_17_spatial_kernel`, `section_23_tests`
- Guardrails: `none`

## test.frame.main_overlay_capture

- Path: `main and overlay frame capture tests`
- Phases: `P8`
- Sections: `section_15_frame_render_contract`, `section_23_tests`
- Guardrails: `preview.selected_move_main_repaint`

## test.frame.no_live_runtime_read_in_painters

- Path: `no live runtime read and no CanvasDocument projection in paint tests`
- Phases: `P8`
- Sections: `section_15_frame_render_contract`, `section_23_tests`
- Guardrails: `none`

## test.interaction.state_machines

- Path: `interaction state machine tests`
- Phases: `P9`
- Sections: `section_14_interaction_engine`, `section_23_tests`
- Guardrails: `none`

## test.interaction.move_resolver_reentrancy

- Path: `synchronous move resolver reentrancy guard tests`
- Phases: `P9`
- Sections: `section_14_interaction_engine`, `section_23_tests`
- Guardrails: `none`

## test.surface.widget_paint

- Path: `CanvasSurface empty/populated widget paint tests`
- Phases: `P10`
- Sections: `section_14_interaction_engine`, `section_15_frame_render_contract`, `section_23_tests`
- Guardrails: `none`

## test.benchmarks.required_cases

- Path: `required benchmark case gates`
- Phases: `P12`
- Sections: `section_24_benchmarks`, `section_23_tests`
- Guardrails: `none`

## test.diagrams.required_present

- Path: `required Mermaid files present tests`
- Phases: `P0`, `P12`
- Sections: `section_23_tests`
- Guardrails: `diagrams.all_required_present`

## test.guardrails.blocking_suite

- Path: `blocking guardrail suite`
- Phases: `P0`, `P12`
- Sections: `section_22_guardrails_machine_checks`, `section_23_tests`, `section_27_final_release_gates`
- Guardrails: `new_api.functional_ledger_complete`, `new_api.integration_surface_complete`, `new_api.v1_scope_gate_green_before_freeze`, `new_api.no_old_public_types`, `new_api.public_types_complete`, `new_api.public_api_compiles_as_written`, `new_api.no_undefined_public_type_references`, `new_api.dto_immutability`, `new_api.id_validation_no_extension_type_escape`, `new_core.no_legacy_imports`, `new_core.no_scene_controller_shape_dependency`, `new_core.no_node_spec_patch_shape_dependency`, `new_core.single_runtime_root`, `edit.sync_non_nested`, `edit.rollback_no_effects`, `edit.stale_handle_rejected`, `events.low_level_edit_no_user_actions`, `events.commands_emit_user_actions`, `load.prepares_before_interrupt`, `load.success_interrupts_before_install`, `preview.selected_move_main_repaint`, `resources.mutation_inside_edit_only`, `resources.dirty_no_document_revision`, `resources.app_key_only`, `codec.schema_v1_exact`, `codec.known_fields_validated`, `diagnostics.disabled_no_alloc_hot_path`, `diagrams.all_required_present`
