<!-- GENERATED: docs/tool/sync_generated_docs.dart from docs/_registry/diagrams.yaml -->
# Diagram catalog

Every item below is a required Mermaid deliverable. The catalog links docs to
the planned Mermaid file paths under `docs/diagrams/`.
Frame, cache, lifecycle, and public edit diagrams use the public runtime state
model: `CanvasRuntime.state` carries runtime-visible revisions, runtime view
camera is distinct from persisted document camera, and retired separate public
listener getters are not diagram seams.

Generated graph-backed Mermaid files live under the generated diagrams
subdirectory. Their source of truth is
`docs/architecture/architecture_graph.yaml`; regenerate or check them with:

```bash
dart run tool/architecture_graph/generate_views.dart --phase P4
dart run tool/architecture_graph/generate_views.dart --phase P4 --check
```

Handwritten sequence, state, C4, lifecycle, and data-flow diagrams remain
semantic diagrams and are not replaced by the generated topology views.

Current generated outputs:

- `docs/diagrams/generated/full_architecture.mmd`
- `docs/diagrams/generated/current_phase.mmd`
- `docs/diagrams/generated/future_target.mmd`
- `docs/diagrams/generated/actual_vs_expected_diff.mmd`
- `docs/diagrams/generated/release_verification.mmd`

## c4_context

- Kind: `c4`
- Planned path: `docs/diagrams/c4_context.mmd`
- Related phases: `P0`, `P1`, `P2`, `P7`, `P10`, `P13`, `P14`
- Related sections: `section_00_status_and_scope`, `section_04_public_api_v1`

## c4_container

- Kind: `c4`
- Planned path: `docs/diagrams/c4_container.mmd`
- Related phases: `P0`, `P1`, `P4`, `P14`
- Related sections: `section_00_status_and_scope`, `section_02_architecture_model`, `section_03_package_layout`

## c4_component_runtime

- Kind: `c4`
- Planned path: `docs/diagrams/c4_component_runtime.mmd`
- Related phases: `P0`, `P4`, `P5`, `P6`, `P9`, `P14`
- Related sections: `section_02_architecture_model`, `section_10_runtime_data_model`

## c4_code_edit_kernel

- Kind: `c4`
- Planned path: `docs/diagrams/c4_code_edit_kernel.mmd`
- Related phases: `P5`, `P14`
- Related sections: `section_11_edit_kernel`

## dfd_public_edit

- Kind: `data_flow`
- Planned path: `docs/diagrams/dfd_public_edit.mmd`
- Related phases: `P1`, `P2`, `P5`, `P6`, `P7`, `P10`, `P11`, `P12`, `P13`, `P14`
- Related sections: `section_04_public_api_v1`, `section_11_edit_kernel`

## seq_single_active_surface

- Kind: `sequence`
- Planned path: `docs/diagrams/seq_single_active_surface.mmd`
- Related phases: `P2`, `P13`, `P14`
- Related sections: `section_04_public_api_v1`

## dfd_load_document_success_failure

- Kind: `data_flow`
- Planned path: `docs/diagrams/dfd_load_document_success_failure.mmd`
- Related phases: `P6`, `P10`, `P11`, `P12`, `P14`
- Related sections: `section_12_load_document`

## dfd_pointer_preview_commit

- Kind: `data_flow`
- Planned path: `docs/diagrams/dfd_pointer_preview_commit.mmd`
- Related phases: `P8`, `P9`, `P10`, `P11`, `P12`, `P13`, `P14`
- Related sections: `section_14_interaction_engine`, `section_16_geometry_policy`

## dfd_main_paint_frame

- Kind: `data_flow`
- Planned path: `docs/diagrams/dfd_main_paint_frame.mmd`
- Related phases: `P9`, `P13`, `P14`
- Related sections: `section_15_frame_render_contract`

## dfd_overlay_frame

- Kind: `data_flow`
- Planned path: `docs/diagrams/dfd_overlay_frame.mmd`
- Related phases: `P9`, `P13`, `P14`
- Related sections: `section_15_frame_render_contract`

## dfd_resource_resolution

- Kind: `data_flow`
- Planned path: `docs/diagrams/dfd_resource_resolution.mmd`
- Related phases: `P7`, `P9`, `P13`, `P14`
- Related sections: `section_07_resource_lifecycle`

## dfd_schema_v1_decode_encode

- Kind: `data_flow`
- Planned path: `docs/diagrams/dfd_schema_v1_decode_encode.mmd`
- Related phases: `P3`, `P14`
- Related sections: `section_05_schema_v1_contract`, `section_19_codec_boundary`

## seq_schema_v1_decode_encode_order

- Kind: `sequence`
- Planned path: `docs/diagrams/seq_schema_v1_decode_encode_order.mmd`
- Related phases: `P3`, `P14`
- Related sections: `section_05_schema_v1_contract`, `section_19_codec_boundary`

## dfd_cache_invalidation

- Kind: `data_flow`
- Planned path: `docs/diagrams/dfd_cache_invalidation.mmd`
- Related phases: `P4`, `P5`, `P6`, `P7`, `P8`, `P9`, `P13`, `P14`
- Related sections: `section_10_runtime_data_model`, `section_17_spatial_kernel`, `section_18_cache_policy`

## dfd_spatial_query_budget

- Kind: `data_flow`
- Planned path: `docs/diagrams/dfd_spatial_query_budget.mmd`
- Related phases: `P8`, `P9`, `P14`
- Related sections: `section_17_spatial_kernel`

## seq_spatial_touched_update

- Kind: `sequence`
- Planned path: `docs/diagrams/seq_spatial_touched_update.mmd`
- Related phases: `P8`, `P14`
- Related sections: `section_17_spatial_kernel`

## seq_hit_test_candidate_resolution

- Kind: `sequence`
- Planned path: `docs/diagrams/seq_hit_test_candidate_resolution.mmd`
- Related phases: `P8`, `P10`, `P14`
- Related sections: `section_16_geometry_policy`, `section_17_spatial_kernel`

## seq_eraser_exact_budget

- Kind: `sequence`
- Planned path: `docs/diagrams/seq_eraser_exact_budget.mmd`
- Related phases: `P8`, `P12`, `P14`
- Related sections: `section_16_geometry_policy`, `section_17_spatial_kernel`

## dfd_diagnostics_error_projection

- Kind: `data_flow`
- Planned path: `docs/diagrams/dfd_diagnostics_error_projection.mmd`
- Related phases: `P1`, `P2`, `P3`, `P14`
- Related sections: `section_06_validation_limits`, `section_20_diagnostics_hub`

## seq_edit_success

- Kind: `sequence`
- Planned path: `docs/diagrams/seq_edit_success.mmd`
- Related phases: `P5`, `P14`
- Related sections: `section_11_edit_kernel`, `section_13_operation_matrix`

## seq_edit_rollback

- Kind: `sequence`
- Planned path: `docs/diagrams/seq_edit_rollback.mmd`
- Related phases: `P5`, `P14`
- Related sections: `section_11_edit_kernel`, `section_13_operation_matrix`

## seq_load_document_success

- Kind: `sequence`
- Planned path: `docs/diagrams/seq_load_document_success.mmd`
- Related phases: `P6`, `P10`, `P11`, `P12`, `P14`
- Related sections: `section_12_load_document`

## seq_load_document_failure

- Kind: `sequence`
- Planned path: `docs/diagrams/seq_load_document_failure.mmd`
- Related phases: `P6`, `P10`, `P11`, `P12`, `P14`
- Related sections: `section_12_load_document`

## seq_selected_move_preview_commit

- Kind: `sequence`
- Planned path: `docs/diagrams/seq_selected_move_preview_commit.mmd`
- Related phases: `P9`, `P10`, `P13`, `P14`
- Related sections: `section_14_interaction_engine`

## seq_selected_move_cancel

- Kind: `sequence`
- Planned path: `docs/diagrams/seq_selected_move_cancel.mmd`
- Related phases: `P9`, `P10`, `P13`, `P14`
- Related sections: `section_14_interaction_engine`

## seq_marquee_select

- Kind: `sequence`
- Planned path: `docs/diagrams/seq_marquee_select.mmd`
- Related phases: `P10`, `P13`, `P14`
- Related sections: `section_14_interaction_engine`

## seq_pencil_marker_commit

- Kind: `sequence`
- Planned path: `docs/diagrams/seq_pencil_marker_commit.mmd`
- Related phases: `P11`, `P13`, `P14`
- Related sections: `section_14_interaction_engine`

## seq_line_two_tap_commit

- Kind: `sequence`
- Planned path: `docs/diagrams/seq_line_two_tap_commit.mmd`
- Related phases: `P11`, `P13`, `P14`
- Related sections: `section_14_interaction_engine`

## seq_eraser_commit

- Kind: `sequence`
- Planned path: `docs/diagrams/seq_eraser_commit.mmd`
- Related phases: `P12`, `P13`, `P14`
- Related sections: `section_14_interaction_engine`

## seq_context_action_request

- Kind: `sequence`
- Planned path: `docs/diagrams/seq_context_action_request.mmd`
- Related phases: `P12`, `P13`, `P14`
- Related sections: `section_14_interaction_engine`

## seq_main_paint

- Kind: `sequence`
- Planned path: `docs/diagrams/seq_main_paint.mmd`
- Related phases: `P9`, `P13`, `P14`
- Related sections: `section_15_frame_render_contract`

## seq_overlay_paint

- Kind: `sequence`
- Planned path: `docs/diagrams/seq_overlay_paint.mmd`
- Related phases: `P9`, `P13`, `P14`
- Related sections: `section_15_frame_render_contract`

## seq_resource_resolution

- Kind: `sequence`
- Planned path: `docs/diagrams/seq_resource_resolution.mmd`
- Related phases: `P7`, `P9`, `P13`, `P14`
- Related sections: `section_07_resource_lifecycle`

## seq_dispose_during_gesture

- Kind: `sequence`
- Planned path: `docs/diagrams/seq_dispose_during_gesture.mmd`
- Related phases: `P10`, `P11`, `P12`, `P13`, `P14`
- Related sections: `section_14_interaction_engine`

## state_runtime_lifecycle

- Kind: `state`
- Planned path: `docs/diagrams/state_runtime_lifecycle.mmd`
- Related phases: `P4`, `P6`, `P14`
- Related sections: `section_02_architecture_model`

## state_edit_session

- Kind: `state`
- Planned path: `docs/diagrams/state_edit_session.mmd`
- Related phases: `P5`, `P6`, `P14`
- Related sections: `section_11_edit_kernel`

## state_pointer_session

- Kind: `state`
- Planned path: `docs/diagrams/state_pointer_session.mmd`
- Related phases: `P10`, `P11`, `P12`, `P13`, `P14`
- Related sections: `section_14_interaction_engine`

## state_select_marquee

- Kind: `state`
- Planned path: `docs/diagrams/state_select_marquee.mmd`
- Related phases: `P10`, `P13`, `P14`
- Related sections: `section_14_interaction_engine`

## state_selected_move

- Kind: `state`
- Planned path: `docs/diagrams/state_selected_move.mmd`
- Related phases: `P10`, `P13`, `P14`
- Related sections: `section_14_interaction_engine`

## state_pencil_marker_draw

- Kind: `state`
- Planned path: `docs/diagrams/state_pencil_marker_draw.mmd`
- Related phases: `P11`, `P13`, `P14`
- Related sections: `section_14_interaction_engine`

## state_two_tap_line

- Kind: `state`
- Planned path: `docs/diagrams/state_two_tap_line.mmd`
- Related phases: `P11`, `P13`, `P14`
- Related sections: `section_14_interaction_engine`

## state_eraser

- Kind: `state`
- Planned path: `docs/diagrams/state_eraser.mmd`
- Related phases: `P12`, `P13`, `P14`
- Related sections: `section_14_interaction_engine`

## state_pending_context_action_request

- Kind: `state`
- Planned path: `docs/diagrams/state_pending_context_action_request.mmd`
- Related phases: `P12`, `P13`, `P14`
- Related sections: `section_14_interaction_engine`

## state_resource_resolution

- Kind: `state`
- Planned path: `docs/diagrams/state_resource_resolution.mmd`
- Related phases: `P7`, `P13`, `P14`
- Related sections: `section_07_resource_lifecycle`
