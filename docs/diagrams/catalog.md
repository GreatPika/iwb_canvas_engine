<!-- GENERATED: docs/tool/sync_generated_docs.dart from docs/_registry/diagrams.yaml -->
# Diagram catalog

Every item below is a required Mermaid deliverable. The catalog links docs to
the Mermaid files under `docs/diagrams/`.

Generated graph-backed Mermaid files live under the generated diagrams
subdirectory. Their source of truth is
`docs/architecture/architecture_graph.yaml`; regenerate or check them with:

```bash
dart run tool/architecture_graph/generate_views.dart
dart run tool/architecture_graph/generate_views.dart --check
```

Handwritten sequence, state, C4, lifecycle, and data-flow diagrams remain
semantic diagrams and are not replaced by the generated topology views.

Current generated outputs:

- `generated/full_architecture`
  - File: `docs/diagrams/generated/full_architecture.mmd`
  - Kind: `architecture_graph_view`
  - Classification: `generated`
  - Related owners: `architecture`
  - Related sections: `section_02_architecture_model`
  - Graph view source: `docs/architecture/architecture_graph.yaml`
- `generated/actual_vs_expected_diff`
  - File: `docs/diagrams/generated/actual_vs_expected_diff.mmd`
  - Kind: `architecture_graph_view`
  - Classification: `generated`
  - Related owners: `architecture`
  - Related sections: `section_02_architecture_model`
  - Graph view source: `docs/architecture/architecture_graph.yaml`

## c4_context

- Kind: `c4`
- Classification: `semantic`
- File: `docs/diagrams/c4_context.mmd`
- Related owners: `architecture`, `contract`
- Related sections: `section_00_status_and_scope`, `section_04_public_api_v1`
- Graph view source: `none`

## c4_container

- Kind: `c4`
- Classification: `semantic`
- File: `docs/diagrams/c4_container.mmd`
- Related owners: `architecture`
- Related sections: `section_00_status_and_scope`, `section_02_architecture_model`, `section_03_package_layout`
- Graph view source: `none`

## c4_component_runtime

- Kind: `c4`
- Classification: `semantic`
- File: `docs/diagrams/c4_component_runtime.mmd`
- Related owners: `architecture`
- Related sections: `section_02_architecture_model`, `section_10_runtime_data_model`
- Graph view source: `none`

## c4_code_edit_kernel

- Kind: `c4`
- Classification: `semantic`
- File: `docs/diagrams/c4_code_edit_kernel.mmd`
- Related owners: `contract`
- Related sections: `section_11_edit_kernel`
- Graph view source: `none`

## dfd_public_edit

- Kind: `data_flow`
- Classification: `semantic`
- File: `docs/diagrams/dfd_public_edit.mmd`
- Related owners: `contract`
- Related sections: `section_04_public_api_v1`, `section_11_edit_kernel`
- Graph view source: `none`

## seq_single_active_surface

- Kind: `sequence`
- Classification: `semantic`
- File: `docs/diagrams/seq_single_active_surface.mmd`
- Related owners: `contract`
- Related sections: `section_04_public_api_v1`
- Graph view source: `none`

## dfd_load_document_success_failure

- Kind: `data_flow`
- Classification: `semantic`
- File: `docs/diagrams/dfd_load_document_success_failure.mmd`
- Related owners: `contract`
- Related sections: `section_12_load_document`
- Graph view source: `none`

## dfd_pointer_preview_commit

- Kind: `data_flow`
- Classification: `semantic`
- File: `docs/diagrams/dfd_pointer_preview_commit.mmd`
- Related owners: `contract`
- Related sections: `section_14_interaction_engine`, `section_16_geometry_policy`
- Graph view source: `none`

## dfd_main_paint_frame

- Kind: `data_flow`
- Classification: `semantic`
- File: `docs/diagrams/dfd_main_paint_frame.mmd`
- Related owners: `contract`
- Related sections: `section_15_frame_render_contract`
- Graph view source: `none`

## dfd_overlay_frame

- Kind: `data_flow`
- Classification: `semantic`
- File: `docs/diagrams/dfd_overlay_frame.mmd`
- Related owners: `contract`
- Related sections: `section_15_frame_render_contract`
- Graph view source: `none`

## dfd_resource_resolution

- Kind: `data_flow`
- Classification: `semantic`
- File: `docs/diagrams/dfd_resource_resolution.mmd`
- Related owners: `contract`
- Related sections: `section_07_resource_lifecycle`
- Graph view source: `none`

## dfd_schema_v1_import_encode

- Kind: `data_flow`
- Classification: `semantic`
- File: `docs/diagrams/dfd_schema_v1_import_encode.mmd`
- Related owners: `contract`
- Related sections: `section_05_schema_v1_contract`, `section_19_codec_boundary`
- Graph view source: `none`

## seq_schema_v1_import_encode_order

- Kind: `sequence`
- Classification: `semantic`
- File: `docs/diagrams/seq_schema_v1_import_encode_order.mmd`
- Related owners: `contract`
- Related sections: `section_05_schema_v1_contract`, `section_19_codec_boundary`
- Graph view source: `none`

## dfd_cache_invalidation

- Kind: `data_flow`
- Classification: `semantic`
- File: `docs/diagrams/dfd_cache_invalidation.mmd`
- Related owners: `architecture`, `contract`
- Related sections: `section_10_runtime_data_model`, `section_17_spatial_kernel`, `section_18_cache_policy`
- Graph view source: `none`

## dfd_spatial_query_budget

- Kind: `data_flow`
- Classification: `semantic`
- File: `docs/diagrams/dfd_spatial_query_budget.mmd`
- Related owners: `contract`
- Related sections: `section_17_spatial_kernel`
- Graph view source: `none`

## seq_spatial_touched_update

- Kind: `sequence`
- Classification: `semantic`
- File: `docs/diagrams/seq_spatial_touched_update.mmd`
- Related owners: `contract`
- Related sections: `section_17_spatial_kernel`
- Graph view source: `none`

## seq_hit_test_candidate_resolution

- Kind: `sequence`
- Classification: `semantic`
- File: `docs/diagrams/seq_hit_test_candidate_resolution.mmd`
- Related owners: `contract`
- Related sections: `section_16_geometry_policy`, `section_17_spatial_kernel`
- Graph view source: `none`

## seq_eraser_exact_budget

- Kind: `sequence`
- Classification: `semantic`
- File: `docs/diagrams/seq_eraser_exact_budget.mmd`
- Related owners: `contract`
- Related sections: `section_16_geometry_policy`, `section_17_spatial_kernel`
- Graph view source: `none`

## dfd_diagnostics_error_projection

- Kind: `data_flow`
- Classification: `semantic`
- File: `docs/diagrams/dfd_diagnostics_error_projection.mmd`
- Related owners: `contract`
- Related sections: `section_06_validation_limits`, `section_20_diagnostics_hub`
- Graph view source: `none`

## seq_edit_success

- Kind: `sequence`
- Classification: `semantic`
- File: `docs/diagrams/seq_edit_success.mmd`
- Related owners: `contract`
- Related sections: `section_11_edit_kernel`, `section_13_operation_matrix`
- Graph view source: `none`

## seq_edit_rollback

- Kind: `sequence`
- Classification: `semantic`
- File: `docs/diagrams/seq_edit_rollback.mmd`
- Related owners: `contract`
- Related sections: `section_11_edit_kernel`, `section_13_operation_matrix`
- Graph view source: `none`

## seq_load_document_success

- Kind: `sequence`
- Classification: `semantic`
- File: `docs/diagrams/seq_load_document_success.mmd`
- Related owners: `contract`
- Related sections: `section_12_load_document`
- Graph view source: `none`

## seq_load_document_failure

- Kind: `sequence`
- Classification: `semantic`
- File: `docs/diagrams/seq_load_document_failure.mmd`
- Related owners: `contract`
- Related sections: `section_12_load_document`
- Graph view source: `none`

## seq_selected_move_preview_commit

- Kind: `sequence`
- Classification: `semantic`
- File: `docs/diagrams/seq_selected_move_preview_commit.mmd`
- Related owners: `contract`
- Related sections: `section_14_interaction_engine`
- Graph view source: `none`

## seq_selected_move_cancel

- Kind: `sequence`
- Classification: `semantic`
- File: `docs/diagrams/seq_selected_move_cancel.mmd`
- Related owners: `contract`
- Related sections: `section_14_interaction_engine`
- Graph view source: `none`

## seq_marquee_select

- Kind: `sequence`
- Classification: `semantic`
- File: `docs/diagrams/seq_marquee_select.mmd`
- Related owners: `contract`
- Related sections: `section_14_interaction_engine`
- Graph view source: `none`

## seq_pencil_marker_commit

- Kind: `sequence`
- Classification: `semantic`
- File: `docs/diagrams/seq_pencil_marker_commit.mmd`
- Related owners: `contract`
- Related sections: `section_14_interaction_engine`
- Graph view source: `none`

## seq_line_two_tap_commit

- Kind: `sequence`
- Classification: `semantic`
- File: `docs/diagrams/seq_line_two_tap_commit.mmd`
- Related owners: `contract`
- Related sections: `section_14_interaction_engine`
- Graph view source: `none`

## seq_eraser_commit

- Kind: `sequence`
- Classification: `semantic`
- File: `docs/diagrams/seq_eraser_commit.mmd`
- Related owners: `contract`
- Related sections: `section_14_interaction_engine`
- Graph view source: `none`

## seq_context_action_request

- Kind: `sequence`
- Classification: `semantic`
- File: `docs/diagrams/seq_context_action_request.mmd`
- Related owners: `contract`
- Related sections: `section_14_interaction_engine`
- Graph view source: `none`

## seq_main_paint

- Kind: `sequence`
- Classification: `semantic`
- File: `docs/diagrams/seq_main_paint.mmd`
- Related owners: `contract`
- Related sections: `section_15_frame_render_contract`
- Graph view source: `none`

## seq_overlay_paint

- Kind: `sequence`
- Classification: `semantic`
- File: `docs/diagrams/seq_overlay_paint.mmd`
- Related owners: `contract`
- Related sections: `section_15_frame_render_contract`
- Graph view source: `none`

## seq_resource_resolution

- Kind: `sequence`
- Classification: `semantic`
- File: `docs/diagrams/seq_resource_resolution.mmd`
- Related owners: `contract`
- Related sections: `section_07_resource_lifecycle`
- Graph view source: `none`

## seq_dispose_during_gesture

- Kind: `sequence`
- Classification: `semantic`
- File: `docs/diagrams/seq_dispose_during_gesture.mmd`
- Related owners: `contract`
- Related sections: `section_14_interaction_engine`
- Graph view source: `none`

## state_runtime_lifecycle

- Kind: `state`
- Classification: `semantic`
- File: `docs/diagrams/state_runtime_lifecycle.mmd`
- Related owners: `architecture`
- Related sections: `section_02_architecture_model`
- Graph view source: `none`

## state_edit_session

- Kind: `state`
- Classification: `semantic`
- File: `docs/diagrams/state_edit_session.mmd`
- Related owners: `contract`
- Related sections: `section_11_edit_kernel`
- Graph view source: `none`

## state_pointer_session

- Kind: `state`
- Classification: `semantic`
- File: `docs/diagrams/state_pointer_session.mmd`
- Related owners: `contract`
- Related sections: `section_14_interaction_engine`
- Graph view source: `none`

## state_select_marquee

- Kind: `state`
- Classification: `semantic`
- File: `docs/diagrams/state_select_marquee.mmd`
- Related owners: `contract`
- Related sections: `section_14_interaction_engine`
- Graph view source: `none`

## state_selected_move

- Kind: `state`
- Classification: `semantic`
- File: `docs/diagrams/state_selected_move.mmd`
- Related owners: `contract`
- Related sections: `section_14_interaction_engine`
- Graph view source: `none`

## state_pencil_marker_draw

- Kind: `state`
- Classification: `semantic`
- File: `docs/diagrams/state_pencil_marker_draw.mmd`
- Related owners: `contract`
- Related sections: `section_14_interaction_engine`
- Graph view source: `none`

## state_two_tap_line

- Kind: `state`
- Classification: `semantic`
- File: `docs/diagrams/state_two_tap_line.mmd`
- Related owners: `contract`
- Related sections: `section_14_interaction_engine`
- Graph view source: `none`

## state_eraser

- Kind: `state`
- Classification: `semantic`
- File: `docs/diagrams/state_eraser.mmd`
- Related owners: `contract`
- Related sections: `section_14_interaction_engine`
- Graph view source: `none`

## state_pending_context_action_request

- Kind: `state`
- Classification: `semantic`
- File: `docs/diagrams/state_pending_context_action_request.mmd`
- Related owners: `contract`
- Related sections: `section_14_interaction_engine`
- Graph view source: `none`

## state_resource_resolution

- Kind: `state`
- Classification: `semantic`
- File: `docs/diagrams/state_resource_resolution.mmd`
- Related owners: `contract`
- Related sections: `section_07_resource_lifecycle`
- Graph view source: `none`
