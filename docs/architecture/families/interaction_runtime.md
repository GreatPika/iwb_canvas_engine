# Interaction Runtime

## Purpose

This family defines where ephemeral interaction state lives and how it reaches
public capability surfaces, pointer sessions, and the mutation gateway without
becoming a second committed-scene owner.

The checked-in code keeps one interaction family with an explicit public owner,
an ephemeral runtime core, a narrow move-preview read seam, and direct callback
wiring into a separate mutation gateway.

## Target Rules

- `SceneControllerInteractionRuntime` remains the interaction-family bridge for
  public-side-effect safety, notify scheduling, pointer-session registry,
  runtime-owned mutation entrypoints, gateway wiring, and the narrow
  `movePreviewRead` bridge consumed by composition-root wiring only.
- `InteractiveRuntime` remains the ephemeral runtime core for gesture, move,
  and draw orchestration, and it must not expose `InteractiveMoveSession`.
- `SceneControllerInteractionOwner` remains the supported public interaction
  facade, but it takes explicit constructor dependencies instead of a shared
  access/context bag.
- `InteractiveMovePreviewRead` remains the only internal move-preview read seam
  for `previewDeltaForNode(...)` and `captureFramePreview()`.
- `SceneControllerPointerSession` remains the pointer-session adapter between
  the view-facing runtime boundary and the interaction family.
- `SceneControllerMutationBoundary` remains outside the interaction core and
  stays the only committed-write bridge.
- Runtime-owned move/draw/selection callbacks may wire directly to
  `SceneControllerMutationBoundary`; do not reintroduce a routing helper
  between those callbacks and the boundary.

## Owners

- Public capability/config seam:
  `lib/src/interactive/scene_controller_interaction.dart` and
  `lib/src/interactive/internal/scene_controller_interaction_config.dart`
- Interaction bridge:
  `lib/src/interactive/internal/scene_controller_interaction_runtime.dart`
- Pointer-session adapter:
  `lib/src/interactive/internal/scene_controller_pointer_session.dart` and
  `lib/src/interactive/internal/pointer_session_token.dart`
- Ephemeral runtime core:
  `lib/src/interactive/internal/interactive_runtime.dart` and
  `lib/src/interactive/internal/interactive_runtime_callbacks.dart`
- Move-preview read seam:
  `lib/src/interactive/internal/interactive_move_preview_read.dart` and
  `lib/src/interactive/internal/interactive_move_session.dart`
- Local subsystem anchors:
  `lib/src/interactive/internal/interactive_draw_coordinator.dart`

## Forbidden Shapes

- Do not let the interaction family hold committed scene state directly.
- Do not reintroduce `SceneControllerInteractionAccess` or
  `SceneControllerInteractionContext`.
- Do not let `InteractiveRuntime` or
  `SceneControllerInteractionRuntime` re-expose `InteractiveMoveSession` or
  runtime-owned move-preview wrapper shells.
- Do not move pointer-session ownership into the view shell.
- Do not turn bridge/core breadth into an implied new top-level family without
  a separate accepted owner-boundary decision.
- Do not let interaction-owned writes bypass `SceneControllerMutationBoundary`.
- Do not reintroduce a runtime-owned routing shell between live interaction
  callbacks and `SceneControllerMutationBoundary`.

## Mechanical Evidence

- `dart run tool/lsp_find_thin_wrappers.dart lib/src/interactive --classification=pure-forwarder`
- `dart run tool/lsp_trace_flow.dart lib/src/interactive/internal/scene_controller_interaction_runtime.dart _createInteractiveRuntime --depth=4`
- `dart run tool/lsp_trace_symbol.dart lib/src/interactive/internal/scene_controller_interaction_runtime.dart _createInteractiveRuntime --direction=outgoing --depth=4 --json-out=docs/architecture/evidence/commit_move_selection_flow.json --mermaid-out=docs/architecture/evidence/commit_move_selection_flow.md`
  Evidence:
  [commit_move_selection_flow.json](../evidence/commit_move_selection_flow.json),
  [commit_move_selection_flow.md](../evidence/commit_move_selection_flow.md)

## Proof Links

- Proof family: [public entrypoint and signature proof](../../proof_architecture/families/public_entrypoint_and_signature_proof.md)
- Proof family: [guardrail runner and artifact model](../../proof_architecture/families/guardrail_runner_and_artifact_model.md)
- Guardrail: `dart run tool/check_guardrails.dart`
- Import boundaries: `dart run tool/check_import_boundaries.dart`
- Invariant: `INV-G-LAYER-DAG`

## Status

- `locked`
- The checked-in family now matches the accepted local form: explicit public
  owner dependencies, a move-owned preview read seam, and no runtime move-
  session leak.

## Update Triggers

- Refresh this family when its listed owners, evidence commands, or linked proof surfaces change.
