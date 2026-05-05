<!-- CONTEXT:BEGIN -->
Registry id: `section_23_tests`
Registry source: `docs/_registry/sections.yaml`
Document path: `docs/verification/tests.md`
Owns:
- 23. Tests
Must read before editing:
- `section_04_public_api_v1` -> `docs/contracts/public_api_v1.md`
- `section_05_schema_v1_contract` -> `docs/contracts/schema_v1.md`
- `section_07_resource_lifecycle` -> `docs/contracts/resources.md`
- `section_14_interaction_engine` -> `docs/contracts/interaction_engine.md`
- `section_22_guardrails_machine_checks` -> `docs/verification/guardrails.md`
Feeds phases:
- `P2`
- `P3`
- `P4`
- `P9`
- `P10`
- `P12`
Related donors:
- `direct_numeric_policy`
- `direct_local_bounds_policy`
- `direct_paint_admission`
- `direct_scan_resistant_cache`
- `direct_pointer_tap_tracking`
- `direct_flutter_pointer_routing`
- `direct_gesture_ownership`
- `direct_structure_validation`
- `foundation_transform2d`
- `foundation_core_geometry`
- `foundation_contract_limits`
- `foundation_error_contract`
- `foundation_validators`
- `foundation_tri_state_patch_semantics`
- `foundation_immutable_collections`
- `foundation_pointer_input_contract`
- `foundation_action_event_immutability`
- `geometry_node_geometry`
- `geometry_hit_test`
- `render_geometry_builder`
- `geometry_interactive_geometry`
- `geometry_eraser_exact_hit`
- `spatial_scene_spatial_index`
- `spatial_index_cache`
- `store_scene_controller_read_paths`
- `snapshot_paint_admission_bounds`
- `snapshot_paint_candidates`
- `frame_render_state`
- `scene_view_runtime_fast_path`
- `paint_candidate_stage`
- `scene_painter_frame`
- `scene_render_caches`
- `static_layer_cache`
- `text_stroke_path_metrics_caches`
- `dto_snapshot_behavior`
- `dto_node_spec_behavior`
- `dto_boundary_schema`
- `dto_scene_value_validation`
- `dto_node_boundary_mapping`
- `dto_document_helpers`
- `codec_guards`
- `codec_json_require`
- `codec_json_parse`
- `codec_metadata_decode`
- `codec_layer_decode`
- `codec_node_common_decode`
- `codec_family_decode`
- `codec_scene_codec_flow`
- `codec_validation_path_surface`
- `tooling_schema_family_parity`
- `interaction_pointer_host`
- `interaction_pointer_session`
- `interaction_pointer_normalizer`
- `interaction_event_dispatcher`
- `interaction_double_tap_router`
- `interaction_gesture_runtime`
- `interaction_move_session`
- `interaction_draw_coordinator`
- `interaction_mutation_boundary`
- `staged_load_runtime_materialization`
- `validated_import_draft`
- `interaction_public_controller_behavior`
- `avoid_scene_controller_facades`
- `avoid_interactive_runtime_whole`
- `avoid_scene_builder_public_architecture`
- `avoid_scene_codec_whole`
- `avoid_scene_store_controller_whole`
Related diagrams:
- `none`
Required tests:
- `test.api_contract.public_api_v1_compiles_as_written`
- `test.api_contract.no_undefined_public_type_references`
- `test.api_contract.no_old_public_symbols`
- `test.api_contract.dto_immutability`
- `test.schema_v1.known_fields_validation`
- `test.schema_v1.resources_appkey_only`
- `test.schema_v1.reject_unknown_element_kind`
- `test.schema_v1.reject_unknown_resource_source_kind`
- `test.resources.sync_image_resolver`
- `test.resources.app_owned_image_not_disposed`
- `test.resources.resource_dirty`
- `test.resources.mark_all_resources_dirty`
- `test.events.typed_action_payloads`
- `test.events.low_level_mutations_do_not_emit_actions`
- `test.events.commands_emit_user_actions`
- `test.surface.interactive_false_pointer_routing`
- `test.surface.interactive_false_active_session_cancel`
- `test.functional_ledger.row_specific_tests`
- `test.api_contract.v1_scope_gate`
- `test.validation_limits.constructor_and_schema_limits`
- `test.store.read_document_projection`
- `test.store.no_projection_hot_path`
- `test.edit_kernel.sync_non_nested_async_stale`
- `test.edit_kernel.rollback`
- `test.load_document.staged_success_failure`
- `test.geometry.hit_policy`
- `test.spatial.touched_update`
- `test.frame.main_overlay_capture`
- `test.frame.no_live_runtime_read_in_painters`
- `test.interaction.state_machines`
- `test.interaction.move_resolver_reentrancy`
- `test.surface.widget_paint`
- `test.benchmarks.required_cases`
- `test.diagrams.required_present`
- `test.guardrails.blocking_suite`
Guardrails:
- `api.functional_ledger_complete`
Do not assume:
- no donor reuse without ported or equivalent tests
<!-- CONTEXT:END -->

## 23. Tests

Required tests:

```text
test/api_contract/public_api_v1_compiles_as_written_test.dart
test/api_contract/no_undefined_public_type_references_test.dart
test/api_contract/no_old_public_symbols_test.dart
test/api_contract/dto_immutability_test.dart

test/schema_v1/known_fields_validation_test.dart
test/schema_v1/resources_appkey_only_test.dart
test/schema_v1/reject_unknown_element_kind_test.dart
test/schema_v1/reject_unknown_resource_source_kind_test.dart

test/resources/sync_image_resolver_test.dart
test/resources/app_owned_image_not_disposed_test.dart
test/resources/resource_dirty_test.dart
test/resources/mark_all_resources_dirty_test.dart

test/events/typed_action_payloads_test.dart
test/events/edit_kernel_low_level_mutations_do_not_emit_actions_test.dart
test/events/commands_emit_user_actions_test.dart

test/surface/interactive_false_pointer_routing_test.dart
test/surface/interactive_false_active_session_cancel_test.dart
```

Functional ledger rows still require row-specific tests.
Runtime coverage must include edit_kernel, interaction, frame, spatial, schema_v1, resources, events, surface and diagnostics tests.

---
