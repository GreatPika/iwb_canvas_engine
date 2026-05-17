# P10 - selection, marquee, and selected move

## Purpose

Implement the move-mode interaction slice: selection APIs, marquee selection,
selected move preview, selected move commit/cancel, move resolver safety, and
typed user action events.

## Build scope

- `CanvasSelectionPort`
- `SelectionKernel` or the equivalent internal selection owner introduced by
  the runtime spine
- selection set/toggle/clear/selectAll behavior
- selection move/rotate/flip/delete commands
- pointer session lifecycle needed for move mode
- pointer sample normalization and terminal cleanup
- move/select/marquee state machines
- selected move main-scene preview
- selected move resolver called only on valid terminal commit
- selected move cancel paths never call resolver
- stale terminal samples cannot commit
- interaction commits only through `EditKernel`
- interaction reads selection/document facts only through batched
  intent-specific immutable query ports
- typed selection, transform, delete, and move action payloads
- loadDocument success/failure interaction ordering for active move sessions.

## Dependencies on earlier phases

- P5 edit core owns all committed mutations.
- P6 loadDocument owns staged replacement and interrupt ordering.
- P8 geometry/spatial provides hit-testing and marquee candidates.
- P9 frame rendering provides selected supplement staging and main repaint path.

## Read first

- `section_04_public_api_v1` -> `docs/contracts/public_api_v1.md`
- `section_12_load_document` -> `docs/contracts/load_document.md`
- `section_14_interaction_engine` -> `docs/contracts/interaction_engine.md`
- `section_16_geometry_policy` -> `docs/contracts/geometry.md`
- `section_23_tests` -> `docs/verification/tests.md`

## Required donors

- `direct_pointer_tap_tracking` - decision: `copy`; target owner: Pointer session tap tracking
- `direct_gesture_ownership` - decision: `copy`; target owner: InteractionEngine gesture ownership
- `foundation_pointer_input_contract` - decision: `copy/adapt`; target owner: Canvas pointer API and InteractionEngine
- `foundation_action_event_immutability` - decision: `adapt`; target owner: CanvasActionEvent and text edit events
- `geometry_interactive_geometry` - decision: `copy/adapt`; target owner: Draw and eraser geometry helpers
- `interaction_pointer_session` - decision: `adapt`; target owner: InteractionEngine pointer session
- `interaction_pointer_normalizer` - decision: `copy/adapt`; target owner: Pointer sample normalizer
- `interaction_event_dispatcher` - decision: `adapt`; target owner: Interaction event dispatch
- `interaction_gesture_runtime` - decision: `adapt`; target owner: InteractionEngine dispatch order and cleanup
- `interaction_move_session` - decision: `adapt`; target owner: Move and marquee interaction machines
- `interaction_mutation_boundary` - decision: `adapt`; target owner: Interaction-owned mutation bridge into EditKernel
- `staged_load_runtime_materialization` - decision: `adapt`; target owner: loadDocument staged materialization

## Forbidden donor structure

- `avoid_scene_controller_facades` - decision: `avoid`
- `avoid_interactive_runtime_whole` - decision: `avoid`
- `avoid_scene_builder_public_architecture` - decision: `avoid`
- `avoid_scene_codec_whole` - decision: `avoid`
- `avoid_scene_store_controller_whole` - decision: `avoid`

## Diagrams to read or update

- `c4_context` -> `docs/diagrams/c4_context.mmd`
- `dfd_load_document_success_failure` -> `docs/diagrams/dfd_load_document_success_failure.mmd`
- `dfd_pointer_preview_commit` -> `docs/diagrams/dfd_pointer_preview_commit.mmd`
- `dfd_public_edit` -> `docs/diagrams/dfd_public_edit.mmd`
- `seq_dispose_during_gesture` -> `docs/diagrams/seq_dispose_during_gesture.mmd`
- `seq_hit_test_candidate_resolution` -> `docs/diagrams/seq_hit_test_candidate_resolution.mmd`
- `seq_load_document_failure` -> `docs/diagrams/seq_load_document_failure.mmd`
- `seq_load_document_success` -> `docs/diagrams/seq_load_document_success.mmd`
- `seq_marquee_select` -> `docs/diagrams/seq_marquee_select.mmd`
- `seq_selected_move_cancel` -> `docs/diagrams/seq_selected_move_cancel.mmd`
- `seq_selected_move_preview_commit` -> `docs/diagrams/seq_selected_move_preview_commit.mmd`
- `state_pointer_session` -> `docs/diagrams/state_pointer_session.mmd`
- `state_select_marquee` -> `docs/diagrams/state_select_marquee.mmd`
- `state_selected_move` -> `docs/diagrams/state_selected_move.mmd`

## Contracts satisfied by this phase

- pointer session lifecycle, selected move preview target, resolver rules, and
  move/marquee interaction behavior from `section_14_interaction_engine`
- load success/failure interaction ordering from `section_12_load_document`
- selection, command, action event, and move resolver API from
  `section_04_public_api_v1`
- selection owner, selectionRevision, and document/selection separation from
  `section_02_architecture_model` and `section_10_runtime_data_model`
- selected move repaint/caching interaction with `section_15_frame_render_contract`

## Tests and guardrails that prove this phase

- `test.api.typed_action_payloads` -> `test/api/typed_action_payloads_test.dart`
- `test.interaction.commands_emit_user_actions` -> `test/interaction/commands_emit_user_actions_test.dart`
- `test.edit.staged_document_load_success_failure` -> `test/edit/staged_document_load_success_failure_test.dart`
- `test.interaction.preview_public_state` -> `test/interaction/preview_public_state_test.dart`
- `test.interaction.state_machines` -> `test/interaction/state_machines_test.dart`
- `test.interaction.move_resolver_reentrancy` -> `test/interaction/move_resolver_reentrancy_test.dart`
- `test.interaction.move_resolver_not_called_on_cancel_cleanup` -> `test/interaction/move_resolver_not_called_on_cancel_cleanup_test.dart`
- `test.interaction.no_stale_terminal_commit` -> `test/interaction/no_stale_terminal_commit_test.dart`
- `test.selection.runtime_owner_separation` -> `test/selection/runtime_owner_separation_test.dart`
- `test.guardrails.selection_boundary_imports` -> `test/guardrails/selection_boundary_imports_test.dart`
- `preview.selected_move_main_repaint`
- `events.commands_emit_user_actions`
- `load.prepares_before_interrupt`
- `load.success_interrupts_before_install`
- `interaction.no_concrete_store_imports`
- `interaction.no_concrete_selection_imports`
- `interaction.no_resolver_on_cancel_paths`
- `interaction.no_stale_terminal_commit`

## Exit gate

- selection API behavior is green
- selection-only API behavior updates `state.revisions.selection` without
  `state.revisions.document`, projection eviction, or spatial updates
- preview-only move/marquee cleanup publishes `state.revisions.preview` only
  when preview state actually changes
- marquee selection commits through `EditKernel`
- selected move preview increments main repaint, not overlay repaint
- selected move commit emits typed move action only after atomic install
- resolver cannot reenter mutation
- resolver is not called on cancel, load, mode change, dispose, or stale terminal cleanup paths
- stale terminal samples do not commit
- loadDocument failure preserves active move gesture
- loadDocument success clears active move gesture.
- interaction has no concrete imports of store or selection owners.

## Risks and trade-offs

- Interaction must not read or mutate store or selection owners directly. Every
  committed mutation goes through `EditKernel`; every committed document or
  selection fact comes through narrow query ports.
- Selected move is intentionally separated from draw and eraser to keep preview,
  resolver, and frame-staging proof focused.

## Why this phase belongs here

Selection and move are the first user-visible interaction paths that need
geometry, spatial queries, edit commits, load interruption, and frame preview
support. They should land before draw and eraser machines reuse pointer/session
infrastructure.
