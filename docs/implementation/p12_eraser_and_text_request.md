# P12 - eraser and text edit request

## Purpose

Implement the remaining interaction behaviors with the highest deletion and
hit-test risk: eraser preview/commit with exact-check budgets, and text
double-tap request routing.

## Build scope

- eraser state machine
- eraser corridor preview
- eraser exact-hit engine integration
- eraser terminal commit through `EditKernel`
- eraser budget-exceeded behavior: corridor-only preview or terminal cleanup/no-op
  with no partial erase
- typed erase action payload
- text double-tap router
- text hit-test read model through narrow query ports
- `CanvasTextEditRequested` event emission
- terminal cleanup and stale terminal rejection for eraser/text routes.

## Dependencies on earlier phases

- P5 edit core owns deletion commits and rollback.
- P8 geometry/spatial provides exact hit and candidate budget primitives.
- P9 frame rendering provides overlay preview capture.
- P10 pointer session and move interaction safety are available.
- P11 draw-mode pointer and preview infrastructure are available.

## Read first

- `section_04_public_api_v1` -> `docs/contracts/public_api_v1.md`
- `section_14_interaction_engine` -> `docs/contracts/interaction_engine.md`
- `section_16_geometry_policy` -> `docs/contracts/geometry.md`
- `section_23_tests` -> `docs/verification/tests.md`

## Required donors

- `foundation_pointer_input_contract` - decision: `copy/adapt`; target owner: Canvas pointer API and InteractionEngine
- `foundation_action_event_immutability` - decision: `adapt`; target owner: CanvasActionEvent and text edit events
- `geometry_interactive_geometry` - decision: `copy/adapt`; target owner: Draw and eraser geometry helpers
- `geometry_eraser_exact_hit` - decision: `adapt`; target owner: Eraser exact-hit engine
- `interaction_pointer_session` - decision: `adapt`; target owner: InteractionEngine pointer session
- `interaction_pointer_normalizer` - decision: `copy/adapt`; target owner: Pointer sample normalizer
- `interaction_event_dispatcher` - decision: `adapt`; target owner: Interaction event dispatch
- `interaction_double_tap_router` - decision: `adapt`; target owner: Text edit request router
- `interaction_gesture_runtime` - decision: `adapt`; target owner: InteractionEngine dispatch order and cleanup
- `interaction_draw_coordinator` - decision: `adapt/rewrite`; target owner: Draw, line and eraser machines
- `interaction_mutation_boundary` - decision: `adapt`; target owner: Interaction-owned mutation bridge into EditKernel

## Forbidden donor structure

- `avoid_scene_controller_facades` - decision: `avoid`
- `avoid_interactive_runtime_whole` - decision: `avoid`
- `avoid_scene_builder_public_architecture` - decision: `avoid`
- `avoid_scene_codec_whole` - decision: `avoid`
- `avoid_scene_store_controller_whole` - decision: `avoid`

## Diagrams to read or update

- `dfd_pointer_preview_commit` -> `docs/diagrams/dfd_pointer_preview_commit.mmd`
- `dfd_public_edit` -> `docs/diagrams/dfd_public_edit.mmd`
- `seq_eraser_commit` -> `docs/diagrams/seq_eraser_commit.mmd`
- `seq_text_edit_request` -> `docs/diagrams/seq_text_edit_request.mmd`
- `state_eraser` -> `docs/diagrams/state_eraser.mmd`
- `state_pending_text_edit_request` -> `docs/diagrams/state_pending_text_edit_request.mmd`
- `state_pointer_session` -> `docs/diagrams/state_pointer_session.mmd`

## Contracts satisfied by this phase

- eraser policy, exact-check budgets, and no-partial-commit behavior from
  `section_16_geometry_policy`
- eraser and text interaction behavior from `section_14_interaction_engine`
- text edit event and erase action payload API from `section_04_public_api_v1`
- operation matrix rows for eraser preview/commit and text request behavior from
  `section_13_operation_matrix`

## Tests and guardrails that prove this phase

- `test.geometry.eraser_exact_budget_no_partial_commit` -> `test/geometry/eraser_exact_budget_no_partial_commit_test.dart`
- `test.api.typed_action_payloads` -> `test/api/typed_action_payloads_test.dart`
- `test.interaction.commands_emit_user_actions` -> `test/interaction/commands_emit_user_actions_test.dart`
- `test.interaction.state_machines` -> `test/interaction/state_machines_test.dart`
- `test.interaction.no_stale_terminal_commit` -> `test/interaction/no_stale_terminal_commit_test.dart`
- `geometry.eraser_exact_budget_no_partial`
- `events.commands_emit_user_actions`
- `interaction.no_concrete_store_imports`
- `interaction.no_stale_terminal_commit`
- `load.prepares_before_interrupt`
- `load.success_interrupts_before_install`

## Exit gate

- eraser preview tests green
- eraser commit tests green
- eraser exact-check budget exceeded produces no partial erase
- eraser action is emitted only when elements are erased after atomic install
- text double-tap on selectable text emits `CanvasTextEditRequested`
- text double-tap does not mutate document or selection by itself
- stale terminal samples do not commit
- loadDocument success clears eraser/text gesture state and failure preserves it
  where required.

## Risks and trade-offs

- Eraser deletion is the easiest interaction path to partially mutate state.
  Budget-exceeded terminal behavior must be cleanup/no-op, never partial commit.
- Text editing UI remains application-owned; the engine only emits the request.

## Why this phase belongs here

Eraser and text request both need geometry, spatial, frame preview, pointer
session, event dispatch, and edit safety. They should be implemented after move
and draw tools, when shared interaction machinery is already proven.
