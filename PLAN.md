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

- [x] [Step 1. P0 package skeleton and hard boundaries](plan/step_1_package_skeleton_and_hard_boundaries.md)
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
- [x] [Step 19. Direct double-tap context action documentation](plan/step_19_double_tap_context_action_documentation.md)
- [x] [Step 20. Guardrail proof hardening](plan/step_20_guardrail_proof_hardening.md)
- [x] [Step 21. P1 v1 scope gate before public API freeze](plan/step_21_v1_scope_gate_before_public_api_freeze.md)
- [x] [Step 22. P2 public API freeze hardening](plan/step_22_p2_public_api_freeze_hardening.md)
- [x] [Step 23. P3 schema v1 DTO validation and codec skeleton](plan/step_23_p3_schema_v1_dto_validation_and_codec_skeleton.md)
- [x] [Step 24. P4 runtime spine, store, and projection cache](plan/step_24_p4_runtime_spine_store_and_projection_cache.md)
- [x] [Step 25. Architecture graph closure checker](plan/step_25_architecture_graph_closure_checker.md)
- [x] [Step 26. Documentation portal and generated navigation](plan/step_26_documentation_portal_and_generated_navigation.md)
- [x] [Step 27. P3/P4 graph closure repair](plan/step_27_p3_p4_graph_closure_repair.md)
- [x] [Step 28. Public incremental smoke test](plan/step_28_public_incremental_smoke_test.md)
- [x] [Step 29. P5 edit core rollback-safe commits](plan/step_29_p5_edit_core_rollback_safe_commits.md)
- [x] [Step 30. P5 edit core repair effect delivery seam](plan/step_30_p5_edit_core_repair_effect_delivery_seam.md)
- [x] [Step 31. Diagnostics public surface registry guard](plan/step_31_diagnostics_public_surface_registry_guard.md)
- [x] [Step 32. Schema v1 roundtrip and metadata proof hardening](plan/step_32_schema_v1_roundtrip_and_metadata_proof_hardening.md)
- [x] [Step 33. Guardrail runner handoff cleanup](plan/step_33_guardrail_runner_handoff_cleanup.md)
- [x] [Step 34. Fixture naming scope cleanup](plan/step_34_fixture_naming_scope_cleanup.md)
- [x] [Step 35. P6 handoff cleanup](plan/step_35_p6_handoff_cleanup.md)
- [x] [Step 36. P6 load document](plan/step_36_p6_load_document.md)
- [x] [Step 37. P6 prepared load cleanup seam repair](plan/step_37_p6_prepared_load_cleanup_seam_repair.md)
- [x] [Step 38. Acyclic runtime public API architecture](plan/step_38_acyclic_runtime_public_api_architecture.md)
- [x] [Step 39. P7 resource kernel read seam and dirty orchestration](plan/step_39_p7_resource_kernel_read_seam_and_dirty_orchestration.md)
- [x] [Step 40. DiagnosticsHub SSOT routing table](plan/step_40_diagnostics_hub_ssot_routing_table.md)
- [x] [Step 41. P7 resource session resolver lifecycle](plan/step_41_p7_resource_session_resolver_lifecycle.md)
- [x] [Step 42. P8 geometry and spatial kernels](plan/step_42_p8_geometry_and_spatial_kernels.md)
- [x] [Step 43. P9 frame rendering and caches](plan/step_43_p9_frame_rendering_and_caches.md)
- [x] [Step 44. Skill rule vocabulary normalization](plan/step_44_skill_rule_vocabulary_normalization.md)
- [x] [Step 45. Skill rule proof and ownership normalization](plan/step_45_skill_rule_proof_and_ownership_normalization.md)
- [x] [Step 46. P9 frame rendering findings closure](plan/step_46_p9_frame_rendering_findings_closure.md)
- [x] [Step 47. P10 selection and move](plan/step_47_p10_selection_and_move.md)
- [x] [Step 48. P11 draw tools](plan/step_48_p11_draw_tools.md)
- [x] [Step 49. P12 eraser and context-action request](plan/step_49_p12_eraser_and_context_action_request.md)
- [x] [Step 50. P12 findings closure](plan/step_50_p12_findings_closure.md)
- [x] [Step 51. P13 Flutter surface](plan/step_51_p13_flutter_surface.md)
