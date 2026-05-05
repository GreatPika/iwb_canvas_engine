# P12 - benchmarks, diagrams, release readiness

Sequence note: no P11 phase is currently defined; P12 is the final
release-readiness gate after P10.

## Build

- all required diagrams complete
- benchmark baselines
- benchmark diff tool
- all guardrails blocking
- release checklist.

## Read first

- `section_08_functional_ledger` -> `docs/verification/functional_ledger.md`
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
- `seq_dispose_during_gesture` -> `docs/diagrams/seq_dispose_during_gesture.mmd`
- `seq_edit_rollback` -> `docs/diagrams/seq_edit_rollback.mmd`
- `seq_edit_success` -> `docs/diagrams/seq_edit_success.mmd`
- `seq_eraser_commit` -> `docs/diagrams/seq_eraser_commit.mmd`
- `seq_line_two_tap_commit` -> `docs/diagrams/seq_line_two_tap_commit.mmd`
- `seq_load_document_failure` -> `docs/diagrams/seq_load_document_failure.mmd`
- `seq_load_document_success` -> `docs/diagrams/seq_load_document_success.mmd`
- `seq_main_paint` -> `docs/diagrams/seq_main_paint.mmd`
- `seq_marquee_select` -> `docs/diagrams/seq_marquee_select.mmd`
- `seq_overlay_paint` -> `docs/diagrams/seq_overlay_paint.mmd`
- `seq_pencil_marker_commit` -> `docs/diagrams/seq_pencil_marker_commit.mmd`
- `seq_resource_resolution` -> `docs/diagrams/seq_resource_resolution.mmd`
- `seq_selected_move_cancel` -> `docs/diagrams/seq_selected_move_cancel.mmd`
- `seq_selected_move_preview_commit` -> `docs/diagrams/seq_selected_move_preview_commit.mmd`
- `seq_text_edit_request` -> `docs/diagrams/seq_text_edit_request.mmd`
- `state_edit_session` -> `docs/diagrams/state_edit_session.mmd`
- `state_eraser` -> `docs/diagrams/state_eraser.mmd`
- `state_pencil_marker_draw` -> `docs/diagrams/state_pencil_marker_draw.mmd`
- `state_pending_text_edit_request` -> `docs/diagrams/state_pending_text_edit_request.mmd`
- `state_pointer_session` -> `docs/diagrams/state_pointer_session.mmd`
- `state_resource_resolution` -> `docs/diagrams/state_resource_resolution.mmd`
- `state_runtime_lifecycle` -> `docs/diagrams/state_runtime_lifecycle.mmd`
- `state_select_marquee` -> `docs/diagrams/state_select_marquee.mmd`
- `state_selected_move` -> `docs/diagrams/state_selected_move.mmd`
- `state_two_tap_line` -> `docs/diagrams/state_two_tap_line.mmd`

## Guardrails

- `diagnostics.disabled_no_alloc_hot_path` - no record allocation on successful hot path
- `diagrams.all_required_present` - required Mermaid files exist
- `api.functional_ledger_complete` - every functional ledger row has API + tests

## Tests

- `test.functional_ledger.row_specific_tests` -> `functional-ledger row-specific tests`
- `test.benchmarks.required_cases` -> `required benchmark case gates`
- `test.diagrams.required_present` -> `required Mermaid files present tests`
- `test.guardrails.blocking_suite` -> `blocking guardrail suite`

## Exit gate

- functional ledger complete
- schema tests green
- interaction/frame/spatial/resource tests green
- benchmarks pass
- no legacy imports
- no legacy facade
- no app adapters in package.
