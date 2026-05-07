<!-- CONTEXT:BEGIN -->
Registry id: `section_23_tests`
Registry source: `docs/_registry/sections.yaml`
Document path: `docs/verification/tests.md`
Owns:
- 23. Tests
Must read before editing:
- `section_04_public_api_v1` -> `docs/contracts/public_api_v1.md`
- `section_22_guardrails_machine_checks` -> `docs/verification/guardrails.md`
Feeds phases:
- `P0`
- `P2`
- `P3`
- `P4`
- `P5`
- `P6`
- `P7`
- `P8`
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
- `test.api_contract.no_legacy_public_symbols`
- `test.api_contract.dto_immutability`
- `test.api_contract.public_equality_policy`
- `test.guardrails.import_boundaries`
- `test.codec.schema_v1.known_fields_validation`
- `test.codec.schema_v1.resources_appkey_only`
- `test.codec.schema_v1.reject_unknown_element_kind`
- `test.codec.schema_v1.reject_unknown_resource_source_kind`
- `test.codec.decode_encode_no_runtime_side_effects`
- `test.diagnostics.sanitizer_and_public_projection`
- `test.resources.sync_image_resolver`
- `test.resources.app_owned_image_not_disposed`
- `test.resources.resource_dirty`
- `test.resources.mark_all_resources_dirty`
- `test.resources.painter_never_calls_resolver_directly`
- `test.resources.missing_result_cached_per_revision`
- `test.resources.resolver_frame_budget`
- `test.resources.resolver_reentrancy_rejected`
- `test.api.typed_action_payloads`
- `test.edit.low_level_mutations_do_not_emit_actions`
- `test.interaction.commands_emit_user_actions`
- `test.flutter_bridge.interactive_false_pointer_routing`
- `test.flutter_bridge.interactive_false_active_session_cancel`
- `test.flutter_bridge.interactive_false_pending_line_preserved`
- `test.flutter_bridge.pointer_adapter_finite_normalization`
- `test.functional_ledger.row_specific_tests`
- `test.api_contract.v1_scope_gate`
- `test.codec.constructor_and_schema_limits`
- `test.store.read_document_projection`
- `test.store.no_projection_hot_path`
- `test.store.public_document_is_projection_only`
- `test.edit.sync_non_nested_async_stale`
- `test.edit.rollback`
- `test.edit.operation_matrix_effects`
- `test.edit.exact_touched_invalidation`
- `test.edit.typed_effects_no_frame_dependency`
- `test.edit.staged_document_load_success_failure`
- `test.geometry.hit_policy`
- `test.geometry.no_legacy_scene_order`
- `test.geometry.eraser_exact_budget_no_partial_commit`
- `test.spatial.touched_update`
- `test.spatial.no_full_clone_for_touched_update`
- `test.spatial.stale_generation_rejected`
- `test.spatial.fallback_budget_enforced`
- `test.frame.main_overlay_capture`
- `test.frame.no_live_runtime_read_in_painters`
- `test.frame.paint_plan_excludes_preview_delta`
- `test.frame.camera_pan_preserves_ordinary_paint_plan`
- `test.frame.cache_keys_do_not_use_legacy_snapshot_shape`
- `test.frame.cache_capacity_eviction_policy`
- `test.frame.selected_supplement_staging_no_global_sort`
- `test.interaction.state_machines`
- `test.interaction.move_resolver_reentrancy`
- `test.interaction.move_resolver_not_called_on_cancel_cleanup`
- `test.interaction.no_stale_terminal_commit`
- `test.flutter_bridge.widget_paint`
- `test.benchmarks.required_cases`
- `test.guardrails.required_diagrams_present`
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
test/api_contract/no_legacy_public_symbols_test.dart
test/api_contract/dto_immutability_test.dart
test/api_contract/public_equality_policy_test.dart
test/api_contract/v1_scope_gate_test.dart
test/guardrails/import_boundaries_test.dart
test/guardrails/required_diagrams_present_test.dart
test/guardrails/blocking_suite_test.dart
test/functional_ledger/row_specific_tests_test.dart
test/benchmarks/required_cases_test.dart

test/codec/schema_v1/known_fields_validation_test.dart
test/codec/schema_v1/resources_appkey_only_test.dart
test/codec/schema_v1/reject_unknown_element_kind_test.dart
test/codec/schema_v1/reject_unknown_resource_source_kind_test.dart
test/codec/decode_encode_no_runtime_side_effects_test.dart
test/codec/constructor_and_schema_limits_test.dart
test/diagnostics/sanitizer_and_public_projection_test.dart

test/resources/sync_image_resolver_test.dart
test/resources/app_owned_image_not_disposed_test.dart
test/resources/resource_dirty_test.dart
test/resources/mark_all_resources_dirty_test.dart
test/resources/painter_never_calls_resolver_directly_test.dart
test/resources/missing_result_cached_per_revision_test.dart
test/resources/resolver_frame_budget_test.dart
test/resources/resolver_reentrancy_rejected_test.dart

test/api/typed_action_payloads_test.dart
test/edit/low_level_mutations_do_not_emit_actions_test.dart
test/interaction/commands_emit_user_actions_test.dart

test/flutter_bridge/interactive_false_pointer_routing_test.dart
test/flutter_bridge/interactive_false_active_session_cancel_test.dart
test/flutter_bridge/interactive_false_pending_line_preserved_test.dart
test/flutter_bridge/pointer_adapter_finite_normalization_test.dart
test/flutter_bridge/widget_paint_test.dart

test/store/read_document_projection_test.dart
test/store/no_projection_hot_path_test.dart
test/store/public_document_is_projection_only_test.dart
test/edit/sync_non_nested_async_stale_test.dart
test/edit/rollback_test.dart
test/edit/operation_matrix_effects_test.dart
test/edit/exact_touched_invalidation_test.dart
test/edit/typed_effects_no_frame_dependency_test.dart
test/edit/staged_document_load_success_failure_test.dart
test/geometry/hit_policy_test.dart
test/geometry/no_legacy_scene_order_test.dart
test/geometry/eraser_exact_budget_no_partial_commit_test.dart
test/spatial/touched_update_test.dart
test/spatial/no_full_clone_for_touched_update_test.dart
test/spatial/stale_generation_rejected_test.dart
test/spatial/fallback_budget_enforced_test.dart
test/frame/main_overlay_capture_test.dart
test/frame/no_live_runtime_read_in_painters_test.dart
test/frame/cache_keys_do_not_use_legacy_snapshot_shape_test.dart
test/frame/cache_capacity_eviction_policy_test.dart
test/frame/paint_plan_excludes_preview_delta_test.dart
test/frame/camera_pan_preserves_ordinary_paint_plan_test.dart
test/frame/selected_supplement_staging_no_global_sort_test.dart
test/interaction/state_machines_test.dart
test/interaction/move_resolver_reentrancy_test.dart
test/interaction/move_resolver_not_called_on_cancel_cleanup_test.dart
test/interaction/no_stale_terminal_commit_test.dart
```

Functional ledger rows still require row-specific tests.
Runtime coverage must include api, edit, interaction, frame, spatial, geometry, codec/schema_v1, resources, flutter_bridge, and diagnostics tests.

---
