language: english

# Plan

This file is the active plan index. Each step has a dedicated document so the
roadmap can be updated without mixing execution contracts.

## General Notes

- Step order defines the intended implementation order.
- Detailed scope, closure rules, and verification live only in the linked step
  document.
- When a step is completed, update both this index and the linked step
  document in the same change.

## Step Files

- [x] [Step 103. Optimize `check_coverage` for machine-first workflow triage](plan/step_103_check_coverage_machine_workflow_optimization.md)
- [x] [Step 104. Introduce shell-first machine verification presets](plan/step_104_shell_first_machine_verification_presets.md)
- [x] [Step 105. Seal capability-owner construction and enforce hermetic public signatures](plan/step_105_capability_owner_public_signature_hermeticity.md)
- [x] [Step 106. Align scene boundary diagnostic contracts across import paths](plan/step_106_scene_boundary_diagnostic_contract_alignment.md)
- [x] [Step 107. Seal runtime scene validity ownership before commit](plan/step_107_runtime_scene_validity_ownership.md)
- [x] [Step 108. Seal committed read-side runtime graph leaks](plan/step_108_seal_committed_read_side_runtime_graph_leaks.md) (`SceneSpatialCandidate` / `querySpatialCandidates(...)` exact surface superseded by Step 113; snapshot-only read-side seal remains active)
- [x] [Step 109. Restore frame-authoritative render snapshot resolution](plan/step_109_restore_frame_authoritative_render_snapshot_resolution.md)
- [x] [Step 110. Seal prepared replace-scene payload ownership](plan/step_110_seal_prepared_replace_scene_payload_ownership.md)
- [x] [Step 111. Lift replace-scene orchestration ownership to committed mutation access](plan/step_111_lift_replace_scene_orchestration_ownership_to_committed_mutation_access.md)
- [x] [Step 112. Fix zero-preview move gesture scene notification contract](plan/step_112_fix_zero_preview_move_gesture_scene_notification_contract.md)
- [x] [Step 113. Separate paint and hit-test spatial admission](plan/step_113_separate_paint_and_hit_test_spatial_admission.md) (role split remains active; background paint admission later extended by Step 114)
- [x] [Step 114. Include `backgroundLayer` in shared paint spatial admission](plan/step_114_include_background_layer_in_paint_spatial_index.md)
- [x] [Step 115. Seal controller-owned paint candidate staging and performance contract](plan/step_115_seal_controller_owned_paint_candidate_staging_and_perf_contract.md)
- [x] [Step 116. Harden committed selection invalidation ownership](plan/step_116_harden_committed_selection_invalidation_ownership.md)
- [x] [Step 117. Refactor `example/lib/main.dart` into feature-scoped MVVM layers](plan/step_117_refactor_example_main_into_feature_mvvm_layers.md)
- [ ] [Step 118. Migrate interactive resolver-purity guardrails to resolved AST entrypoint analysis](plan/step_118_migrate_interactive_resolver_purity_guardrails_to_resolved_entrypoint_analysis.md)
- [ ] [Step 119. Migrate interactive mutation-owner guardrails to resolved pre-effect sequencing analysis](plan/step_119_migrate_interactive_mutation_owner_guardrails_to_resolved_pre_effect_analysis.md)
- [ ] [Step 120. Replace interactive boundary-shape token guardrails with resolved architecture-boundary rules](plan/step_120_replace_interactive_boundary_shape_token_guardrails_with_resolved_architecture_boundary_rules.md)
- [ ] [Step 121. Replace controller lexical write-only mutation guardrails with resolved semantics](plan/step_121_replace_controller_lexical_write_only_mutation_guardrails_with_resolved_semantics.md)
- [ ] [Step 122. Close resolved guardrail proof surface and self-guard regressions](plan/step_122_close_resolved_guardrail_proof_surface_and_self_guard_regressions.md)
