# P9 - interaction engine

## Build

- pointer session lifecycle
- move/select/marquee machine
- pencil/marker draw machine
- two-tap line machine
- eraser machine
- text double-tap router
- terminal cleanup
- synchronous move resolver guard.

## Read first

- `section_04_public_api_v1` -> `docs/contracts/public_api_v1.md`
- `section_12_load_document` -> `docs/contracts/load_document.md`
- `section_14_interaction_engine` -> `docs/contracts/interaction_engine.md`
- `section_23_tests` -> `docs/verification/tests.md`

## Required donors

- `direct_pointer_tap_tracking` - decision: `copy`; target owner: Pointer session tap tracking
- `direct_gesture_ownership` - decision: `copy`; target owner: InteractionEngine gesture ownership
- `foundation_pointer_input_contract` - decision: `copy/adapt`; target owner: Canvas pointer API and InteractionEngine
- `foundation_action_event_immutability` - decision: `adapt`; target owner: CanvasActionEvent and text edit events
- `geometry_interactive_geometry` - decision: `copy/adapt`; target owner: Draw and eraser geometry helpers
- `geometry_eraser_exact_hit` - decision: `adapt`; target owner: Eraser exact-hit engine
- `interaction_pointer_session` - decision: `adapt`; target owner: InteractionEngine pointer session
- `interaction_pointer_normalizer` - decision: `copy/adapt`; target owner: Pointer sample normalizer
- `interaction_event_dispatcher` - decision: `adapt`; target owner: Interaction event dispatch
- `interaction_double_tap_router` - decision: `adapt`; target owner: Text edit request router
- `interaction_gesture_runtime` - decision: `adapt`; target owner: InteractionEngine dispatch order and cleanup
- `interaction_move_session` - decision: `adapt`; target owner: Move and marquee interaction machines
- `interaction_draw_coordinator` - decision: `adapt/rewrite`; target owner: Draw, line and eraser machines
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
- `seq_eraser_commit` -> `docs/diagrams/seq_eraser_commit.mmd`
- `seq_line_two_tap_commit` -> `docs/diagrams/seq_line_two_tap_commit.mmd`
- `seq_load_document_failure` -> `docs/diagrams/seq_load_document_failure.mmd`
- `seq_load_document_success` -> `docs/diagrams/seq_load_document_success.mmd`
- `seq_marquee_select` -> `docs/diagrams/seq_marquee_select.mmd`
- `seq_pencil_marker_commit` -> `docs/diagrams/seq_pencil_marker_commit.mmd`
- `seq_selected_move_cancel` -> `docs/diagrams/seq_selected_move_cancel.mmd`
- `seq_selected_move_preview_commit` -> `docs/diagrams/seq_selected_move_preview_commit.mmd`
- `seq_text_edit_request` -> `docs/diagrams/seq_text_edit_request.mmd`
- `state_eraser` -> `docs/diagrams/state_eraser.mmd`
- `state_pencil_marker_draw` -> `docs/diagrams/state_pencil_marker_draw.mmd`
- `state_pending_text_edit_request` -> `docs/diagrams/state_pending_text_edit_request.mmd`
- `state_pointer_session` -> `docs/diagrams/state_pointer_session.mmd`
- `state_select_marquee` -> `docs/diagrams/state_select_marquee.mmd`
- `state_selected_move` -> `docs/diagrams/state_selected_move.mmd`
- `state_two_tap_line` -> `docs/diagrams/state_two_tap_line.mmd`

## Guardrails

- `load.prepares_before_interrupt` - failed load does not interrupt gesture
- `load.success_interrupts_before_install` - success interrupt happens before atomic install
- `api.dto_immutability` - DTO collections defensively copied and unmodifiable
- `api.functional_ledger_complete` - every functional ledger row has API + tests
- `api.id_validation_no_extension_type_escape` - ids cannot be publicly constructed without validation
- `api.no_undefined_public_type_references` - every exported signature type is exported or from Flutter/Dart SDK
- `api.public_api_compiles_as_written` - public API declarations compile in an empty consumer package
- `api.public_types_complete` - all public signatures reference defined public types
- `preview.selected_move_main_repaint` - selected move preview increments main repaint, not overlay

## Tests

- `test.events.typed_action_payloads` -> `test/events/typed_action_payloads_test.dart`
- `test.events.commands_emit_user_actions` -> `test/events/commands_emit_user_actions_test.dart`
- `test.load_document.staged_success_failure` -> `staged loadDocument success/failure tests`
- `test.interaction.state_machines` -> `interaction state machine tests`
- `test.interaction.move_resolver_reentrancy` -> `synchronous move resolver reentrancy guard tests`

## Exit gate

- all interaction state tests green
- pending line preview exposed
- text edit event emitted
- resolver cannot reenter mutation
- loadDocument failure preserves gesture
- loadDocument success clears gesture.
