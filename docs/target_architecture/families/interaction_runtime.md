# Interaction Runtime

## Purpose

This family defines where ephemeral interaction state lives and how it reaches
public capability surfaces, pointer sessions, and the mutation gateway without
becoming a second committed-scene owner.

The checked-in code already keeps one interaction family with a bridge owner,
an ephemeral runtime core, and direct callback wiring into a separate mutation
gateway.

## Target Rules

- `SceneControllerInteractionRuntime` remains the interaction-family bridge for
  public-side-effect safety, notify scheduling, pointer-session registry,
  runtime-owned mutation entrypoints, and gateway wiring.
- `InteractiveRuntime` remains the ephemeral runtime core for gesture, move,
  and draw orchestration.
- `SceneControllerPointerSession` remains the pointer-session adapter between
  the view-facing runtime boundary and the interaction family.
- `SceneControllerMutationBoundary` remains outside the interaction core and
  stays the only committed-write bridge.
- Runtime-owned move/draw/selection callbacks may wire directly to
  `SceneControllerMutationBoundary`; do not reintroduce a routing helper
  between those callbacks and the boundary.

## Owners

- Public capability/config seam:
  `lib/src/interactive/scene_controller_interaction.dart`,
  `lib/src/interactive/internal/scene_controller_interaction_access.dart`, and
  `lib/src/interactive/internal/scene_controller_interaction_config.dart`
- Interaction bridge:
  `lib/src/interactive/internal/scene_controller_interaction_runtime.dart`
- Pointer-session adapter:
  `lib/src/interactive/internal/scene_controller_pointer_session.dart` and
  `lib/src/interactive/internal/pointer_session_token.dart`
- Ephemeral runtime core:
  `lib/src/interactive/internal/interactive_runtime.dart` and
  `lib/src/interactive/internal/interactive_runtime_callbacks.dart`
- Local subsystem anchors:
  `lib/src/interactive/internal/interactive_move_session.dart` and
  `lib/src/interactive/internal/interactive_draw_coordinator.dart`

## Forbidden Shapes

- Do not let the interaction family hold committed scene state directly.
- Do not move pointer-session ownership into the view shell.
- Do not turn bridge/core breadth into an implied new top-level family without
  a separate accepted owner-boundary decision.
- Do not let interaction-owned writes bypass `SceneControllerMutationBoundary`.
- Do not reintroduce a runtime-owned routing shell between live interaction
  callbacks and `SceneControllerMutationBoundary`.

## Mechanical Evidence

- `dart run tool/lsp_find_thin_wrappers.dart lib/src/interactive --classification=pure-forwarder`
- `dart run tool/lsp_trace_flow.dart lib/src/interactive/internal/scene_controller_interaction_runtime.dart _createInteractiveRuntime --depth=4`
- `dart run tool/lsp_trace_symbol.dart lib/src/interactive/internal/scene_controller_interaction_runtime.dart _createInteractiveRuntime --direction=outgoing --depth=4 --json-out=docs/target_architecture/evidence/commit_move_selection_flow.json --mermaid-out=docs/target_architecture/evidence/commit_move_selection_flow.md`
  Evidence:
  [commit_move_selection_flow.json](../evidence/commit_move_selection_flow.json),
  [commit_move_selection_flow.md](../evidence/commit_move_selection_flow.md)

## Status

- `locked, needs slimming`
- The family boundary is stable, but bridge/core breadth and thin-wrapper debt
  remain local cleanup targets inside the same accepted family.
