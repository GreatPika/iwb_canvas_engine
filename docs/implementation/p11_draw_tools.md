# P11 - pencil, marker, and line draw tools

## Purpose

Implement draw-mode creation tools after pointer sessions, edit commits, geometry
helpers, and overlay frame capture exist.

## Build scope

- draw mode state machine for pencil
- draw mode state machine for marker
- two-tap line state machine
- pointer preview lifecycle for pencil, marker, and line
- `CanvasPencilStrokePreview`, `CanvasMarkerStrokePreview`,
  `CanvasPendingLineStartPreview`, and `CanvasLinePreview` preview state
- overlay repaint for draw previews
- stroke and line commit through `EditKernel`
- draw and line cleanup consumes the existing P10
  `PointerToolCleanupCoordinator` seam
- draw style validation and adoption
- draw mode/style/tool/color changes publish `state.revisions.interaction`
- typed draw action payloads for pencil, marker, and line
- terminal cleanup and stale terminal rejection for draw sessions.

P11 must not introduce draw-local cleanup policy. Pencil, marker, and line
machines return typed cleanup requests to `InteractionEngine`; only
`InteractionEngine` calls `PointerToolCleanupCoordinator`. Draw and line work
must consume the P10 coordinator for cancel, mode/tool change, load success,
`interactive=false`, stale terminal, invalid terminal, no-op terminal, edit
failure, and post-successful-commit cleanup. Line cleanup requests must carry
ownership context so line-owned cleanup clears pending line state while
non-owned pending line state remains preserved on `interactive=false`.

## Dependencies on earlier phases

- P5 edit core owns atomic stroke/line commits.
- P8 geometry provides draw geometry helpers and bounds.
- P9 frame rendering provides overlay frame capture.
- P10 pointer session, event dispatch, and load interrupt behavior are available.

## Read first

- `section_04_public_api_v1` -> `docs/contracts/public_api_v1.md`
- `section_14_interaction_engine` -> `docs/contracts/interaction_engine.md`
- `section_16_geometry_policy` -> `docs/contracts/geometry.md`
- `section_23_tests` -> `docs/verification/tests.md`

## Required donors

- `foundation_pointer_input_contract` - decision: `copy/adapt`; target owner: Canvas pointer API and InteractionEngine
- `foundation_action_event_immutability` - decision: `adapt`; target owner: CanvasActionEvent and text edit events
- `geometry_interactive_geometry` - decision: `copy/adapt`; target owner: Draw and eraser geometry helpers
- `interaction_pointer_session` - decision: `adapt`; target owner: InteractionEngine pointer session
- `interaction_pointer_normalizer` - decision: `copy/adapt`; target owner: Pointer sample normalizer
- `interaction_event_dispatcher` - decision: `adapt`; target owner: Interaction event dispatch
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
- `seq_line_two_tap_commit` -> `docs/diagrams/seq_line_two_tap_commit.mmd`
- `seq_pencil_marker_commit` -> `docs/diagrams/seq_pencil_marker_commit.mmd`
- `state_pencil_marker_draw` -> `docs/diagrams/state_pencil_marker_draw.mmd`
- `state_pointer_session` -> `docs/diagrams/state_pointer_session.mmd`
- `state_two_tap_line` -> `docs/diagrams/state_two_tap_line.mmd`

## Contracts satisfied by this phase

- draw tool, draw style, pointer, preview, and action payload API from
  `section_04_public_api_v1`
- `CanvasStrokePreview` shared pencil/marker facts and sealed draw preview
  variants from `section_04_public_api_v1`
- pointer session lifecycle and draw/line preview behavior from
  `section_14_interaction_engine`
- draw geometry helper behavior from `section_16_geometry_policy`
- operation matrix rows for pencil, marker, and line preview/commit from
  `section_13_operation_matrix`

## Tests and guardrails that prove this phase

- `test.api.typed_action_payloads` -> `test/api/typed_action_payloads_test.dart`
- `test.runtime.interaction_settings_state` -> `test/runtime/interaction_settings_state_test.dart`
- `test.api_contract.preview_state_sealed_union` -> `test/api_contract/preview_state_sealed_union_test.dart`
- `test.interaction.preview_public_state` -> `test/interaction/preview_public_state_test.dart`
- `test.interaction.commands_emit_user_actions` -> `test/interaction/commands_emit_user_actions_test.dart`
- `test.interaction.state_machines` -> `test/interaction/state_machines_test.dart`
- `test.interaction.no_stale_terminal_commit` -> `test/interaction/no_stale_terminal_commit_test.dart`
- `test.interaction.pointer_cleanup_coordinator_outcomes` -> `test/interaction/pointer_cleanup_coordinator_outcomes_test.dart`
- `events.commands_emit_user_actions`
- `api.preview_state_sealed_union_publicly_readable`
- `interaction.no_concrete_store_imports`
- `interaction.pointer_cleanup_coordinator_only`
- `interaction.no_stale_terminal_commit`
- `load.prepares_before_interrupt`
- `load.success_interrupts_before_install`

## Exit gate

- pencil preview and commit tests green
- marker preview and commit tests green
- pencil and marker previews share `CanvasStrokePreview` points, color,
  thickness, and opacity facts through concrete variants
- `CanvasPendingLineStartPreview` exposes start, timestamp, color, and
  thickness facts; `CanvasLinePreview` exposes start, end, color, and thickness
- line commit tests green
- draw commits emit typed action payloads only after atomic install
- draw previews repaint overlay only
- draw previews publish `state.revisions.preview` without document revision
- stale terminal samples do not commit
- draw and line cleanup-capable machines consume the existing coordinator seam
  instead of owning shared preview/session cleanup policy
- coordinator outcomes preserve non-owned pending line state on
  `interactive=false`, clear line-owned pending state, and classify overlay or
  no-preview cleanup without action or text-request emission
- loadDocument failure preserves pending draw/line state where the contract requires it
- loadDocument success clears active draw/line gesture state.

## Risks and trade-offs

- Draw tools share pointer/session infrastructure with move but have different
  preview repaint targets. Keep draw preview overlay-only.
- Line pending state is not the same as an active routed pointer session, which
  matters later for `interactive=false` surface behavior.

## Why this phase belongs here

Draw tools need edit commits, geometry, overlay frame support, and the pointer
session foundation from selection/move. They are smaller and safer to prove
before adding eraser deletion and text hit request behavior.
