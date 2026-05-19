language: english

# Plan

This file is the active plan index. Each step has a dedicated document so the
roadmap can be updated without mixing execution contracts.

Step entry template: `- [ ] [Step <number>. <Short step title>](plan/step_<number>_<short_snake_case_summary>.md)`

## General Notes

- Step order defines the intended implementation order.
- Detailed scope, closure rules, and verification live only in the linked step
  document.
- Completed step contracts are historical records. They may reference paths,
  APIs, or checks that were later retired; use the current document map and
  active step contracts for current navigation.
- When a step is completed, update both this index and the linked step
  document in the same change.

## Step Files

- [ ] [Step 1. P0 package skeleton and hard boundaries](plan/step_1_package_skeleton_and_hard_boundaries.md)
- [x] [Step 2. Public readable union variants](plan/step_2_public_readable_union_variants.md)
- [x] [Step 3. CanvasFieldUpdate patch semantics](plan/step_3_canvas_field_update_patch_semantics.md)
- [x] [Step 4. DTO metadata immutability and const policy](plan/step_4_dto_metadata_immutability_and_const_policy.md)
- [x] [Step 5. Selection runtime ownership documentation](plan/step_5_selection_runtime_ownership_documentation.md)
- [x] [Step 6. Public runtime state and view camera ownership](plan/step_6_public_runtime_state_and_view_camera_ownership.md)
- [x] [Step 7. Frame cache invalidation facts split](plan/step_7_frame_cache_invalidation_facts_split.md)
- [x] [Step 8. Resource resolver cache surface session](plan/step_8_resource_resolver_cache_surface_session.md)
- [x] [Step 9. Canvas preview state sealed union](plan/step_9_canvas_preview_state_sealed_union.md)
- [x] [Step 10. Interaction request text edit stale guard](plan/step_10_interaction_request_text_edit_stale_guard.md)
- [x] [Step 11. Operation matrix field-effect taxonomy](plan/step_11_operation_matrix_field_effect_taxonomy.md)
- [x] [Step 12. Non-invertible transform admission](plan/step_12_non_invertible_transform_admission.md)
- [x] [Step 13. Public error code contract prose](plan/step_13_public_error_code_contract_prose.md)
- [x] [Step 14. Public API contract consistency follow-up](plan/step_14_public_api_contract_consistency_followup.md)
- [x] [Step 15. Runtime-created timestamp monotonic proof mapping](plan/step_15_runtime_created_timestamp_monotonic_proof_mapping.md)
- [x] [Step 16. FrameFactsPort committed frame facts boundary](plan/step_16_frame_facts_port_committed_frame_facts_boundary.md)
- [x] [Step 17. FrameEngine internal collaborator split](plan/step_17_frame_engine_internal_collaborator_split.md)
- [x] [Step 18. Pointer tool cleanup coordinator documentation](plan/step_18_pointer_tool_cleanup_coordinator.md)
