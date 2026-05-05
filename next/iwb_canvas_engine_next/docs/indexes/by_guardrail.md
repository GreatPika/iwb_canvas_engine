# By guardrail

Guardrails extracted from split section 22.

## new_api.functional_ledger_complete

- Rule: every functional ledger row has API + tests
- Sections: `section_08_functional_ledger`, `section_22_guardrails_machine_checks`, `section_23_tests`, `section_27_final_release_gates`
- Tests: `test.functional_ledger.row_specific_tests`, `test.guardrails.blocking_suite`

## new_api.integration_surface_complete

- Rule: API has enough public surface for app-level NewEngineAdapter, but adapter is not in package
- Sections: `section_22_guardrails_machine_checks`, `section_27_final_release_gates`
- Tests: `test.guardrails.blocking_suite`

## new_api.v1_scope_gate_green_before_freeze

- Rule: P1.5 scope gate passed before public API freeze starts
- Sections: `section_09_accepted_differences`, `section_22_guardrails_machine_checks`, `section_27_final_release_gates`
- Tests: `test.api_contract.v1_scope_gate`, `test.guardrails.blocking_suite`

## new_api.no_old_public_types

- Rule: old public golden symbols not exported by new package
- Sections: `section_03_package_layout`, `section_22_guardrails_machine_checks`, `section_27_final_release_gates`
- Tests: `test.api_contract.no_old_public_symbols`, `test.guardrails.blocking_suite`

## new_api.public_types_complete

- Rule: all public signatures reference defined public types
- Sections: `section_04_public_api_v1`, `section_22_guardrails_machine_checks`, `section_27_final_release_gates`
- Tests: `test.guardrails.blocking_suite`

## new_api.public_api_compiles_as_written

- Rule: public API declarations compile in an empty consumer package
- Sections: `section_04_public_api_v1`, `section_22_guardrails_machine_checks`, `section_27_final_release_gates`
- Tests: `test.api_contract.public_api_v1_compiles_as_written`, `test.guardrails.blocking_suite`

## new_api.no_undefined_public_type_references

- Rule: every exported signature type is exported or from Flutter/Dart SDK
- Sections: `section_04_public_api_v1`, `section_22_guardrails_machine_checks`, `section_27_final_release_gates`
- Tests: `test.api_contract.no_undefined_public_type_references`, `test.guardrails.blocking_suite`

## new_api.dto_immutability

- Rule: DTO collections defensively copied and unmodifiable
- Sections: `section_04_public_api_v1`, `section_22_guardrails_machine_checks`, `section_27_final_release_gates`
- Tests: `test.api_contract.dto_immutability`, `test.guardrails.blocking_suite`

## new_api.id_validation_no_extension_type_escape

- Rule: ids cannot be publicly constructed without validation
- Sections: `section_04_public_api_v1`, `section_06_validation_limits`, `section_22_guardrails_machine_checks`, `section_27_final_release_gates`
- Tests: `test.validation_limits.constructor_and_schema_limits`, `test.guardrails.blocking_suite`

## new_core.no_legacy_imports

- Rule: no import of old package/runtime
- Sections: `section_00_status_and_scope`, `section_03_package_layout`, `section_22_guardrails_machine_checks`, `section_27_final_release_gates`
- Tests: `test.guardrails.blocking_suite`

## new_core.no_scene_controller_shape_dependency

- Rule: no SceneController concept in core
- Sections: `section_00_status_and_scope`, `section_22_guardrails_machine_checks`, `section_27_final_release_gates`
- Tests: `test.guardrails.blocking_suite`

## new_core.no_node_spec_patch_shape_dependency

- Rule: no old NodeSpec/NodePatch/PatchField in core
- Sections: `section_00_status_and_scope`, `section_22_guardrails_machine_checks`, `section_27_final_release_gates`
- Tests: `test.guardrails.blocking_suite`

## new_core.single_runtime_root

- Rule: exactly one production RuntimeRoot
- Sections: `section_02_architecture_model`, `section_10_runtime_data_model`, `section_22_guardrails_machine_checks`, `section_27_final_release_gates`
- Tests: `test.guardrails.blocking_suite`

## edit.sync_non_nested

- Rule: nested/async edit rejected
- Sections: `section_11_edit_kernel`, `section_13_operation_matrix`, `section_22_guardrails_machine_checks`, `section_27_final_release_gates`
- Tests: `test.edit_kernel.sync_non_nested_async_stale`, `test.guardrails.blocking_suite`

## edit.rollback_no_effects

- Rule: rollback discards events/repaint/resources/spatial
- Sections: `section_11_edit_kernel`, `section_13_operation_matrix`, `section_22_guardrails_machine_checks`, `section_27_final_release_gates`
- Tests: `test.edit_kernel.rollback`, `test.guardrails.blocking_suite`

## edit.stale_handle_rejected

- Rule: stale edit handle throws
- Sections: `section_11_edit_kernel`, `section_13_operation_matrix`, `section_22_guardrails_machine_checks`, `section_27_final_release_gates`
- Tests: `test.edit_kernel.sync_non_nested_async_stale`, `test.guardrails.blocking_suite`

## events.low_level_edit_no_user_actions

- Rule: CanvasEdit.removeElement/clearContent emit no user action events
- Sections: `section_11_edit_kernel`, `section_22_guardrails_machine_checks`, `section_27_final_release_gates`
- Tests: `test.events.low_level_mutations_do_not_emit_actions`, `test.guardrails.blocking_suite`

## events.commands_emit_user_actions

- Rule: high-level commands and interaction commits own user action events
- Sections: `section_22_guardrails_machine_checks`, `section_27_final_release_gates`
- Tests: `test.events.typed_action_payloads`, `test.events.commands_emit_user_actions`, `test.guardrails.blocking_suite`

## load.prepares_before_interrupt

- Rule: failed load does not interrupt gesture
- Sections: `section_12_load_document`, `section_14_interaction_engine`, `section_22_guardrails_machine_checks`, `section_27_final_release_gates`
- Tests: `test.load_document.staged_success_failure`, `test.guardrails.blocking_suite`

## load.success_interrupts_before_install

- Rule: success interrupt happens before atomic install
- Sections: `section_12_load_document`, `section_14_interaction_engine`, `section_22_guardrails_machine_checks`, `section_27_final_release_gates`
- Tests: `test.load_document.staged_success_failure`, `test.guardrails.blocking_suite`

## preview.selected_move_main_repaint

- Rule: selected move preview increments main repaint, not overlay
- Sections: `section_14_interaction_engine`, `section_15_frame_render_contract`, `section_22_guardrails_machine_checks`, `section_27_final_release_gates`
- Tests: `test.frame.main_overlay_capture`, `test.guardrails.blocking_suite`

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
- Tests: `test.schema_v1.resources_appkey_only`, `test.schema_v1.reject_unknown_resource_source_kind`, `test.resources.sync_image_resolver`, `test.resources.app_owned_image_not_disposed`, `test.guardrails.blocking_suite`

## codec.schema_v1_exact

- Rule: only schema v1 read/write
- Sections: `section_05_schema_v1_contract`, `section_19_codec_boundary`, `section_22_guardrails_machine_checks`, `section_27_final_release_gates`
- Tests: `test.guardrails.blocking_suite`

## codec.known_fields_validated

- Rule: known schema v1 fields are validated and canonical encoder writes only v1 fields
- Sections: `section_05_schema_v1_contract`, `section_06_validation_limits`, `section_19_codec_boundary`, `section_22_guardrails_machine_checks`, `section_27_final_release_gates`
- Tests: `test.schema_v1.known_fields_validation`, `test.schema_v1.reject_unknown_element_kind`, `test.validation_limits.constructor_and_schema_limits`, `test.guardrails.blocking_suite`

## diagnostics.disabled_no_alloc_hot_path

- Rule: no record allocation on successful hot path
- Sections: `section_20_diagnostics_hub`, `section_22_guardrails_machine_checks`, `section_27_final_release_gates`
- Tests: `test.guardrails.blocking_suite`

## diagrams.all_required_present

- Rule: required Mermaid files exist
- Sections: `section_22_guardrails_machine_checks`, `section_27_final_release_gates`
- Tests: `test.diagrams.required_present`, `test.guardrails.blocking_suite`
