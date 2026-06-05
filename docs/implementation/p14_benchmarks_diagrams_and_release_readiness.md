# P14 - benchmarks, diagrams, and release readiness

## Purpose

Close the implementation by proving that guardrails, diagrams, benchmarks,
donor use, phase alignment, and final release gates all match the target
architecture.

## Build scope

- all required diagrams complete
- public runtime state and view/persisted camera ownership proof remains
  reflected in diagrams, indexes, guardrails, and release gates
- benchmark baselines
- benchmark diff tool
- all guardrails blocking
- full guardrail runner closure
- release checklist
- phase guardrail alignment
- no app adapters inside the engine package.

## Dependencies on earlier phases

- P0-P13 implementation phases are complete and their phase-local exit gates are
  green.

## Read first

- `section_18_cache_policy` -> `docs/contracts/cache_policy.md`
- `section_20_diagnostics_hub` -> `docs/contracts/diagnostics.md`
- `section_22_guardrails_machine_checks` -> `docs/verification/guardrails.md`
- `section_23_tests` -> `docs/verification/tests.md`
- `section_24_benchmarks` -> `docs/verification/benchmarks.md`
- `section_27_final_release_gates` -> `docs/verification/release_gates.md`

## Required donors

- `direct_scan_resistant_cache` - decision: `copy`; target owner: Render cache policy
- `tooling_schema_family_parity` - decision: `adapt`; target owner: Tooling guardrail

## Forbidden donor structure

- `avoid_scene_controller_facades` - decision: `avoid`
- `avoid_interactive_runtime_whole` - decision: `avoid`
- `avoid_scene_builder_public_architecture` - decision: `avoid`
- `avoid_scene_codec_whole` - decision: `avoid`
- `avoid_scene_store_controller_whole` - decision: `avoid`

## Diagrams to read or update

- `c4_code_edit_kernel` -> `docs/diagrams/c4_code_edit_kernel.mmd`
- `c4_component_runtime` -> `docs/diagrams/c4_component_runtime.mmd`
- `c4_container` -> `docs/diagrams/c4_container.mmd`
- `c4_context` -> `docs/diagrams/c4_context.mmd`
- `dfd_cache_invalidation` -> `docs/diagrams/dfd_cache_invalidation.mmd`
- `dfd_diagnostics_error_projection` -> `docs/diagrams/dfd_diagnostics_error_projection.mmd`
- `dfd_load_document_success_failure` -> `docs/diagrams/dfd_load_document_success_failure.mmd`
- `dfd_main_paint_frame` -> `docs/diagrams/dfd_main_paint_frame.mmd`
- `dfd_overlay_frame` -> `docs/diagrams/dfd_overlay_frame.mmd`
- `dfd_pointer_preview_commit` -> `docs/diagrams/dfd_pointer_preview_commit.mmd`
- `dfd_public_edit` -> `docs/diagrams/dfd_public_edit.mmd`
- `dfd_resource_resolution` -> `docs/diagrams/dfd_resource_resolution.mmd`
- `dfd_schema_v1_decode_encode` -> `docs/diagrams/dfd_schema_v1_decode_encode.mmd`
- `dfd_spatial_query_budget` -> `docs/diagrams/dfd_spatial_query_budget.mmd`
- `seq_dispose_during_gesture` -> `docs/diagrams/seq_dispose_during_gesture.mmd`
- `seq_edit_rollback` -> `docs/diagrams/seq_edit_rollback.mmd`
- `seq_edit_success` -> `docs/diagrams/seq_edit_success.mmd`
- `seq_eraser_commit` -> `docs/diagrams/seq_eraser_commit.mmd`
- `seq_eraser_exact_budget` -> `docs/diagrams/seq_eraser_exact_budget.mmd`
- `seq_hit_test_candidate_resolution` -> `docs/diagrams/seq_hit_test_candidate_resolution.mmd`
- `seq_line_two_tap_commit` -> `docs/diagrams/seq_line_two_tap_commit.mmd`
- `seq_load_document_failure` -> `docs/diagrams/seq_load_document_failure.mmd`
- `seq_load_document_success` -> `docs/diagrams/seq_load_document_success.mmd`
- `seq_main_paint` -> `docs/diagrams/seq_main_paint.mmd`
- `seq_marquee_select` -> `docs/diagrams/seq_marquee_select.mmd`
- `seq_overlay_paint` -> `docs/diagrams/seq_overlay_paint.mmd`
- `seq_pencil_marker_commit` -> `docs/diagrams/seq_pencil_marker_commit.mmd`
- `seq_resource_resolution` -> `docs/diagrams/seq_resource_resolution.mmd`
- `seq_schema_v1_decode_encode_order` -> `docs/diagrams/seq_schema_v1_decode_encode_order.mmd`
- `seq_selected_move_cancel` -> `docs/diagrams/seq_selected_move_cancel.mmd`
- `seq_selected_move_preview_commit` -> `docs/diagrams/seq_selected_move_preview_commit.mmd`
- `seq_single_active_surface` -> `docs/diagrams/seq_single_active_surface.mmd`
- `seq_spatial_touched_update` -> `docs/diagrams/seq_spatial_touched_update.mmd`
- `seq_context_action_request` -> `docs/diagrams/seq_context_action_request.mmd`
- `state_edit_session` -> `docs/diagrams/state_edit_session.mmd`
- `state_eraser` -> `docs/diagrams/state_eraser.mmd`
- `state_pencil_marker_draw` -> `docs/diagrams/state_pencil_marker_draw.mmd`
- `state_pending_context_action_request` -> `docs/diagrams/state_pending_context_action_request.mmd`
- `state_pointer_session` -> `docs/diagrams/state_pointer_session.mmd`
- `state_resource_resolution` -> `docs/diagrams/state_resource_resolution.mmd`
- `state_runtime_lifecycle` -> `docs/diagrams/state_runtime_lifecycle.mmd`
- `state_select_marquee` -> `docs/diagrams/state_select_marquee.mmd`
- `state_selected_move` -> `docs/diagrams/state_selected_move.mmd`
- `state_two_tap_line` -> `docs/diagrams/state_two_tap_line.mmd`

## Contracts satisfied by this phase

- diagnostics hot-path and sanitizer closure from `section_20_diagnostics_hub`
- mandatory guardrail suite from `section_22_guardrails_machine_checks`
- complete required test inventory from `section_23_tests`
- benchmark policy and required cases from `section_24_benchmarks`
- final release gates from `section_27_final_release_gates`

## Tests and guardrails that prove this phase

- `test.api_contract.app_next_engine_adapter_compile_fixture` -> `test/api_contract/app_next_engine_adapter_compile_fixture_test.dart`
- `test.benchmarks.benchmark_manifest` -> `test/benchmarks/benchmark_manifest_test.dart`
- `test.benchmarks.benchmark_diff` -> `test/benchmarks/benchmark_diff_test.dart`
- `test.benchmarks.benchmark_runner` -> `test/benchmarks/benchmark_runner_test.dart`
- `test.benchmarks.required_cases` -> `test/benchmarks/required_cases_test.dart`
- `test.guardrails.blocking_suite` -> `test/guardrails/blocking_suite_test.dart`
- `dart run tool/guardrails/run.dart` -> full blocking guardrail suite
- `diagnostics.disabled_no_alloc_hot_path`
- `api.integration_surface_complete`
- every guardrail listed in `section_22_guardrails_machine_checks`
- every final release gate listed in `section_27_final_release_gates`

## Exit gate

- schema tests green
- interaction/frame/spatial/resource tests green
- benchmark manifest, required-case, diff, and runner proofs green
- root package CI runs benchmark proofs separately from the non-benchmark
  Flutter test suite so every test uses the correct runner
- no legacy imports
- no legacy facade
- phase guardrail alignment green
- full guardrail runner green
- every mandatory guardrail has a runner entry and executable proof, including
  the external app-adapter compile fixture for `api.integration_surface_complete`
- no app adapters in package
- all final release gates green.
- public runtime state and camera ownership references are consistent across
  registries, indexes, diagram catalog, and final proof docs.

## Risks and trade-offs

- Treating benchmarks, diagrams, or guardrails as optional release polish would
  undercut the architecture. They are release blockers.
- Treating future changed-path runner output as authoritative before impact
  metadata exists would risk false green release checks.
- This phase must not introduce new feature behavior. It proves and packages the
  behavior already implemented in P0-P13.

## Why this phase belongs here

P14 depends on every implementation owner being present. It is the only correct
place to close cross-cutting release proof, benchmark baselines, diagram
coverage, and final guardrail alignment.
