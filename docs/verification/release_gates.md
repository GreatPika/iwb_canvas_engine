<!-- CONTEXT:BEGIN -->
Registry id: `section_27_final_release_gates`
Registry source: `docs/_registry/sections.yaml`
Document path: `docs/verification/release_gates.md`
Owns:
- 27. Final release gates
Must read before editing:
- `section_22_guardrails_machine_checks` -> `docs/verification/guardrails.md`
- `section_23_tests` -> `docs/verification/tests.md`
- `section_24_benchmarks` -> `docs/verification/benchmarks.md`
Feeds phases:
- `P14`
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
- `oracle.legacy_capability_inventory_complete`
- `api.functional_ledger_complete`
- `api.integration_surface_complete`
- `api.v1_scope_gate_green_before_freeze`
- `api.no_legacy_public_types`
- `api.public_exports_complete`
- `api.public_types_complete`
- `api.public_api_compiles_as_written`
- `api.resource_source_app_key_publicly_readable`
- `api.exported_dartdoc_complete`
- `api.public_class_modifiers_explicit`
- `api.public_signature_shape`
- `api.no_undefined_public_type_references`
- `api.dto_immutability`
- `api.equality_policy_explicit`
- `api.id_validation_no_extension_type_escape`
- `core.no_legacy_imports`
- `core.import_boundaries`
- `core.no_unapproved_part_files`
- `core.no_scene_controller_shape_dependency`
- `core.no_node_spec_patch_shape_dependency`
- `core.single_runtime_root`
- `store.no_public_document_live_state`
- `selection.owner_separate_from_document`
- `projection.only_explicit_read_paths`
- `edit.sync_non_nested`
- `edit.rollback_no_effects`
- `edit.stale_handle_rejected`
- `edit.operation_matrix_complete`
- `edit.no_global_invalidation_except_replacement`
- `edit.typed_effects_no_frame_dependency`
- `events.low_level_edit_no_user_actions`
- `events.commands_emit_user_actions`
- `load.prepares_before_interrupt`
- `load.success_interrupts_before_install`
- `preview.selected_move_main_repaint`
- `interaction.no_concrete_store_imports`
- `interaction.no_concrete_selection_imports`
- `interaction.no_resolver_on_cancel_paths`
- `interaction.no_stale_terminal_commit`
- `geometry.no_legacy_scene_order`
- `geometry.eraser_exact_budget_no_partial`
- `spatial.no_full_clone_ordinary_edit`
- `spatial.stale_candidate_rejected`
- `spatial.fallback_budget_enforced`
- `frame.no_global_scene_sort`
- `frame.paint_plan_excludes_preview_delta`
- `frame.paint_plan_excludes_selection_state`
- `cache.keys_use_next_revisions_only`
- `cache.background_grid_not_element_visual`
- `cache.hot_caches_have_capacity_eviction`
- `resources.mutation_inside_edit_only`
- `resources.dirty_no_document_revision`
- `resources.app_key_only`
- `resources.resolver_boundary_owned_by_surface_session`
- `resources.resolver_frame_budget`
- `resources.no_same_frame_missing_retry`
- `resources.resolver_reentrancy_rejected`
- `codec.schema_v1_exact`
- `codec.known_fields_validated`
- `codec.no_runtime_side_effects`
- `diagnostics.disabled_no_alloc_hot_path`
- `diagnostics.sanitized_public_projection`
- `surface.pointer_samples_normalized_before_runtime`
- `surface.interactive_false_pending_line_preserved`
- `diagrams.all_required_present`
Do not assume:
- no release with legacy imports, legacy facade, or unlinked donor reuse
<!-- CONTEXT:END -->

## 27. Final release gates

Release is blocked unless all statements are true:

```text
1. oracle.legacy_capability_inventory_complete is green.
2. api.functional_ledger_complete is green.
3. P1.5 v1 scope gate is green.
4. api.public_exports_complete is green.
5. api.public_types_complete is green.
6. api.public_api_compiles_as_written is green, including the
   `CanvasRuntime.state` surface and exported runtime state snapshot types.
7. public dartdoc, class modifier, and public signature shape guardrails are green.
8. api.no_legacy_public_types is green.
9. core.no_legacy_imports is green.
10. core.import_boundaries and core.no_unapproved_part_files are green.
11. core.single_runtime_root is green.
12. store/projection/selection ownership tests are green.
13. schema v1 encode/decode contract is green.
14. codec no-runtime-side-effect tests are green.
15. validation limits are green.
16. diagnostics disabled hot-path allocation and sanitizer tests are green.
17. resource lifecycle, resolver-boundary, and resolver-frame-budget tests are green.
18. edit rollback/stale/nested/async tests are green.
19. operation matrix and exact touched invalidation tests are green.
20. loadDocument staged success/failure tests are green.
21. public runtime state publication, load publication, interaction settings state,
    preview public state, and dispose lifecycle tests are green.
22. geometry/spatial parity, eraser exact-budget, stale-candidate, and fallback-budget tests are green.
23. frame capture, cache-key, cache-policy, frame-meta, paint-plan,
    runtime-view-camera vs persisted-document-camera separation,
    selection-state cache independence, and selected supplement staging tests are green.
24. selected move preview main repaint test is green.
25. overlay preview repaint split tests are green.
26. text edit request integration tests are green.
27. action typed payload tests are green.
28. low-level edit emits no user action events tests are green.
29. interaction stale terminal, selection-boundary import, resolver-cancel, and interactive=false pending-line tests are green.
30. surface single-active-surface and pointer normalization tests are green.
31. DTO immutability, `CanvasMetadata` deep-freeze, const-policy, and public
    equality policy tests are green, including runtime state snapshot value
    equality.
32. no CanvasDocument projection in paint/pointer/hit tests are green.
33. all required diagrams exist and match owners.
34. phase guardrail alignment is green.
35. full `dart run tool/guardrails/run.dart` is green.
36. every mandatory guardrail has a runner entry and executable proof.
37. changed-aware guardrail routing has conservative fallback coverage.
38. benchmark gates pass.
39. AppCanvasPort, LegacyEngineAdapter and NextEngineAdapter are not present in the engine package.
```

---
