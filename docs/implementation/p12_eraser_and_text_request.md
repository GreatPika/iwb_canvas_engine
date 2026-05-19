# P12 - eraser and context-action request

## Purpose

Implement the remaining interaction behaviors with the highest deletion and
hit-test risk: eraser preview/commit with exact-check budgets, and
context-action double-tap request routing.

## Build scope

- eraser state machine
- `CanvasEraserPreview` corridor preview
- eraser exact-hit engine integration
- eraser terminal commit through `EditKernel`
- eraser budget-exceeded behavior: corridor-only preview or terminal cleanup/no-op
  with no partial erase
- typed erase action payload
- context-action double-tap router for direct host-recognized
  `handleDoubleTap` and engine-owned pointer-sample two-tap recognition
- context-action target read model through narrow query ports
- `CanvasContextActionRequested` event emission for content-element and
  empty-canvas targets
- `CanvasInteractionRequestId` issuance through the interaction request registry
- guarded `CanvasCommandPort.commitTextEdit` semantics for request-originated
  text changes from text content-target requests
- terminal cleanup and stale terminal rejection for eraser/context routes.

P12 must consume the existing P10 `PointerToolCleanupCoordinator` seam for
eraser and context-request cleanup. Eraser and context-action routing may create
typed cleanup requests for `InteractionEngine`, but must not call the
coordinator directly or own shared cleanup policy. Eraser cleanup outcomes
classify overlay or no-preview cleanup and emit no erase action or document
state on cleanup-only paths. Context tap cleanup outcomes clear pending tap
history without preview, repaint, action, context request, document, selection,
spatial, projection, or resource effects.

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
- `foundation_action_event_immutability` - decision: `adapt`; target owner: CanvasActionEvent and context-action request events
- `geometry_interactive_geometry` - decision: `copy/adapt`; target owner: Draw and eraser geometry helpers
- `geometry_eraser_exact_hit` - decision: `adapt`; target owner: Eraser exact-hit engine
- `interaction_pointer_session` - decision: `adapt`; target owner: InteractionEngine pointer session
- `interaction_pointer_normalizer` - decision: `copy/adapt`; target owner: Pointer sample normalizer
- `interaction_event_dispatcher` - decision: `adapt`; target owner: Interaction event dispatch
- `interaction_double_tap_router` - decision: `adapt`; target owner: Context-action double-tap router
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
- `seq_eraser_exact_budget` -> `docs/diagrams/seq_eraser_exact_budget.mmd`
- `seq_context_action_request` -> `docs/diagrams/seq_context_action_request.mmd`
- `state_eraser` -> `docs/diagrams/state_eraser.mmd`
- `state_pending_context_action_request` -> `docs/diagrams/state_pending_context_action_request.mmd`
- `state_pointer_session` -> `docs/diagrams/state_pointer_session.mmd`

## Contracts satisfied by this phase

- eraser policy, exact-check budgets, and no-partial-commit behavior from
  `section_16_geometry_policy`
- eraser and context-action interaction behavior from
  `section_14_interaction_engine`
- `CanvasEraserPreview`, context-action request event, guarded text edit
  commit, editText action payload API, and erase action payload API from
  `section_04_public_api_v1`
- operation matrix rows for eraser preview/commit and context request behavior
  from `section_13_operation_matrix`

## Tests and guardrails that prove this phase

- `test.geometry.eraser_exact_budget_no_partial_commit` -> `test/geometry/eraser_exact_budget_no_partial_commit_test.dart`
- `test.api.typed_action_payloads` -> `test/api/typed_action_payloads_test.dart`
- `test.api_contract.preview_state_sealed_union` -> `test/api_contract/preview_state_sealed_union_test.dart`
- `test.interaction.commands_emit_user_actions` -> `test/interaction/commands_emit_user_actions_test.dart`
- `test.interaction.preview_public_state` -> `test/interaction/preview_public_state_test.dart`
- `test.interaction.state_machines` -> `test/interaction/state_machines_test.dart`
- `test.interaction.no_stale_terminal_commit` -> `test/interaction/no_stale_terminal_commit_test.dart`
- `test.interaction.context_action_request` -> `test/interaction/context_action_request_test.dart`
- `test.interaction.text_edit_stale_commit_guard` -> `test/interaction/text_edit_stale_commit_guard_test.dart`
- `test.interaction.pointer_cleanup_coordinator_outcomes` -> `test/interaction/pointer_cleanup_coordinator_outcomes_test.dart`
- `geometry.eraser_exact_budget_no_partial`
- `api.preview_state_sealed_union_publicly_readable`
- `events.commands_emit_user_actions`
- `interaction.no_concrete_store_imports`
- `interaction.no_stale_terminal_commit`
- `interaction.pointer_cleanup_coordinator_only`
- `interaction.text_edit_stale_commit_guard`
- `load.prepares_before_interrupt`
- `load.success_interrupts_before_install`

## Exit gate

- eraser preview tests green
- eraser preview publishes `CanvasEraserPreview` with an immutable corridor and
  thickness, while context-action requests remain outside preview state
- eraser preview and active eraser cleanup publish `state.revisions.preview`
  without document, selection, resourceVisual, interaction, viewCamera, or action
  effects; empty cleanup is silent
- eraser and context cleanup-capable machines consume the existing coordinator
  seam and do not own shared cleanup policy or call the coordinator directly
- eraser commit tests green
- eraser exact-check budget exceeded produces no partial erase
- eraser action is emitted only when elements are erased after atomic install
- double-tap on eligible content emits one `CanvasContextActionRequested` with a
  content-element target, including non-selectable visible content, for both
  direct `handleDoubleTap` and pointer-sample recognition
- direct `handleDoubleTap` on empty canvas or background-only coverage emits one
  `CanvasContextActionRequested` with an empty-canvas target without pending
  first-tap history
- direct `handleDoubleTap` rejects non-finite positions before timestamped
  request emission, current-target resolution, cleanup, or effects
- direct `handleDoubleTap` clears any existing pending context tap history
  through `PointerToolCleanupCoordinator` before current-target resolution, and
  still emits at most one request for the current content or empty-canvas target
- pointer-sample two-tap recognition remains separate and still revalidates the
  second tap against the pending target class and current target facts
- context-action double-tap request delivery does not mutate document or
  selection by itself
- context cleanup clears pending tap history without preview, repaint, action,
  context request, document, selection, spatial, projection, or resource effects
- request-originated text commits use `commitTextEdit`, reject stale request
  facts, empty-canvas request ids, non-text request ids, retired request ids,
  missing targets, and family-mismatched targets without side effects, do not
  treat unrelated `documentRevision` changes as stale, and emit `editText` only
  for changed text after atomic install
- context request ids use the generic `CanvasInteractionRequestId`
- stale terminal samples do not commit
- loadDocument success clears eraser/context gesture state and failure preserves
  it where required.

## Risks and trade-offs

- Eraser deletion is the easiest interaction path to partially mutate state.
  Budget-exceeded terminal behavior must be cleanup/no-op, never partial commit.
- Context menus and text editing UI remain application-owned; the engine only
  emits the request.

## Why this phase belongs here

Eraser and context-action request both need geometry, spatial, frame preview,
pointer session, event dispatch, and edit safety. They should be implemented
after move and draw tools, when shared interaction machinery is already proven.
