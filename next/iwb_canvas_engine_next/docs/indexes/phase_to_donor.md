# Phase to donor

Inverse map from phase to required donor records. Avoid records are listed under forbidden donor structure in `by_phase.md`.

## P0 - package skeleton and hard boundaries

- `none`

## P1 - old capability inventory and oracle lock

- `interaction_public_controller_behavior`

## P1.5 - v1 scope gate before public API freeze

- `foundation_contract_limits`

## P2 - public API v1 freeze

- `direct_numeric_policy`
- `direct_structure_validation`
- `foundation_transform2d`
- `foundation_contract_limits`
- `foundation_error_contract`
- `foundation_validators`
- `foundation_tri_state_patch_semantics`
- `foundation_immutable_collections`
- `foundation_pointer_input_contract`
- `foundation_action_event_immutability`
- `dto_snapshot_behavior`
- `dto_node_spec_behavior`
- `dto_boundary_schema`
- `dto_scene_value_validation`
- `interaction_public_controller_behavior`

## P3 - schema v1 DTO validation and codec skeleton

- `direct_structure_validation`
- `foundation_transform2d`
- `foundation_contract_limits`
- `foundation_error_contract`
- `foundation_validators`
- `dto_boundary_schema`
- `dto_scene_value_validation`
- `dto_node_boundary_mapping`
- `codec_guards`
- `codec_json_require`
- `codec_json_parse`
- `codec_metadata_decode`
- `codec_layer_decode`
- `codec_node_common_decode`
- `codec_family_decode`
- `codec_scene_codec_flow`
- `codec_validation_path_surface`
- `validated_import_draft`

## P4 - resources

- `none`

## P5 - store kernel and projection cache

- `store_scene_controller_read_paths`
- `dto_node_boundary_mapping`
- `dto_document_helpers`

## P6 - edit kernel

- `dto_document_helpers`
- `interaction_mutation_boundary`
- `staged_load_runtime_materialization`
- `validated_import_draft`

## P7 - spatial and geometry

- `direct_numeric_policy`
- `direct_local_bounds_policy`
- `direct_paint_admission`
- `foundation_transform2d`
- `foundation_core_geometry`
- `geometry_node_geometry`
- `geometry_hit_test`
- `render_geometry_builder`
- `geometry_interactive_geometry`
- `geometry_eraser_exact_hit`
- `spatial_scene_spatial_index`
- `spatial_index_cache`
- `store_scene_controller_read_paths`

## P8 - frame engine and render caches

- `direct_local_bounds_policy`
- `direct_paint_admission`
- `direct_scan_resistant_cache`
- `render_geometry_builder`
- `spatial_index_cache`
- `snapshot_paint_admission_bounds`
- `snapshot_paint_candidates`
- `frame_render_state`
- `scene_view_runtime_fast_path`
- `paint_candidate_stage`
- `scene_painter_frame`
- `scene_render_caches`
- `static_layer_cache`
- `text_stroke_path_metrics_caches`

## P9 - interaction engine

- `direct_pointer_tap_tracking`
- `direct_gesture_ownership`
- `foundation_pointer_input_contract`
- `foundation_action_event_immutability`
- `geometry_interactive_geometry`
- `geometry_eraser_exact_hit`
- `interaction_pointer_session`
- `interaction_pointer_normalizer`
- `interaction_event_dispatcher`
- `interaction_double_tap_router`
- `interaction_gesture_runtime`
- `interaction_move_session`
- `interaction_draw_coordinator`
- `interaction_mutation_boundary`
- `staged_load_runtime_materialization`

## P10 - Flutter surface

- `direct_flutter_pointer_routing`
- `scene_painter_frame`
- `scene_render_caches`
- `static_layer_cache`
- `interaction_pointer_host`
- `interaction_pointer_session`

## P11 - migration tool package

- `codec_metadata_decode`
- `codec_node_common_decode`
- `codec_family_decode`
- `codec_scene_codec_flow`
- `codec_validation_path_surface`

## P12 - benchmarks, diagrams, release readiness

- `direct_scan_resistant_cache`
- `tooling_schema_family_parity`
