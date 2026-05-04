<!-- CONTEXT:BEGIN -->
Registry id: `section_27_final_release_gates`
Registry source: `docs/_registry/sections.yaml`
Document path: `docs/verification/release_gates.md`
Owns:
- 27. Final release gates
Must read before editing:
- `section_21_diagrams` -> `docs/architecture/diagrams.md`
- `section_22_guardrails_machine_checks` -> `docs/verification/guardrails.md`
- `section_23_tests` -> `docs/verification/tests.md`
- `section_24_benchmarks` -> `docs/verification/benchmarks.md`
- `section_26_implementation_phases` -> `docs/planning/implementation_phases.md`
Feeds phases:
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
- `test.guardrails.blocking_suite`
Guardrails:
- `new_api.functional_ledger_complete`
- `new_api.integration_surface_complete`
- `new_api.v1_scope_gate_green_before_freeze`
- `new_api.no_old_public_types`
- `new_api.public_types_complete`
- `new_api.public_api_compiles_as_written`
- `new_api.no_undefined_public_type_references`
- `new_api.dto_immutability`
- `new_api.id_validation_no_extension_type_escape`
- `new_core.no_legacy_imports`
- `new_core.no_scene_controller_shape_dependency`
- `new_core.no_node_spec_patch_shape_dependency`
- `new_core.single_runtime_root`
- `edit.sync_non_nested`
- `edit.rollback_no_effects`
- `edit.stale_handle_rejected`
- `events.low_level_edit_no_user_actions`
- `events.commands_emit_user_actions`
- `load.prepares_before_interrupt`
- `load.success_interrupts_before_install`
- `preview.selected_move_main_repaint`
- `resources.mutation_inside_edit_only`
- `resources.dirty_no_document_revision`
- `resources.app_key_only`
- `codec.schema_v1_exact`
- `codec.known_fields_validated`
- `diagnostics.disabled_no_alloc_hot_path`
- `diagrams.all_required_present`
Do not assume:
- no release with old imports, legacy facade, or unlinked donor reuse
<!-- CONTEXT:END -->

## 27. Final release gates

Release is blocked unless all statements are true:

```text
1. new_api.functional_ledger_complete is green.
2. P1.5 v1 scope gate is green.
3. new_api.public_types_complete is green.
4. new_api.public_api_compiles_as_written is green.
5. new_api.no_old_public_types is green.
6. new_core.no_legacy_imports is green.
7. new_core.single_runtime_root is green.
8. schema v1 encode/decode contract is green.
9. validation limits are green.
10. resource lifecycle tests are green.
11. edit rollback/stale/nested/async tests are green.
12. loadDocument staged success/failure tests are green.
13. geometry/spatial parity tests are green.
14. selected move preview main repaint test is green.
15. overlay preview repaint split tests are green.
16. text edit request integration tests are green.
17. action typed payload tests are green.
18. low-level edit emits no user action events tests are green.
19. DTO immutability tests are green.
20. no CanvasDocument projection in paint/pointer/hit tests are green.
21. diagnostics disabled hot-path allocation tests are green.
22. all required diagrams exist and match owners.
23. migration tool handles old schema v7 fixtures without silent loss.
24. benchmark gates pass.
25. AppCanvasPort, OldEngineAdapter and NewEngineAdapter are not present in the engine package.
```

---

