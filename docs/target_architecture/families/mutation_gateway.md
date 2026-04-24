# Mutation Gateway

## Purpose

This family defines which owner may translate interaction-side mutation intent
into committed writes.

The checked-in code keeps one committed-write gateway in
`SceneControllerMutationBoundary`, and direct public/runtime mutation callers
route straight into that boundary.

## Target Rules

- `SceneControllerMutationBoundary` remains the only interaction-owned owner
  that performs committed writes.
- `SceneControllerCommittedMutationAccess` remains the adapter seam from the
  gateway into the committed store/write path.
- `SceneControllerSceneOwner`, `SceneControllerSelectionOwner`, and runtime-
  owned mutation entrypoints may call the gateway directly, but they do not
  become competing write owners.
- Gesture lifetime, preview lifetime, and view hosting remain outside the
  gateway.

## Owners

- Gateway core:
  `lib/src/interactive/internal/scene_controller_mutation_boundary.dart`
- Committed-mutation access seam:
  `lib/src/controller/scene_controller_committed_mutation_access.dart`
- Direct public mutation owners:
  `lib/src/interactive/scene_controller_scene.dart` and
  `lib/src/interactive/scene_controller_selection.dart`
- Runtime-owned direct mutation callers:
  `lib/src/interactive/internal/scene_controller_interaction_runtime.dart`

## Forbidden Shapes

- Do not let direct public owners or runtime-owned mutation callers bypass
  `SceneControllerMutationBoundary` to reach committed writes directly.
- Do not reintroduce a routing-only mutation shell between direct callers and
  `SceneControllerMutationBoundary`.
- Do not let `SceneControllerCommittedMutationAccess` grow into a second
  interaction-owned gateway.
- Do not move gesture orchestration, preview state, or view-hosting behavior
  into the gateway.

## Mechanical Evidence

- `dart run tool/lsp_trace_symbol.dart lib/src/interactive/scene_controller_scene.dart SceneControllerSceneOwner.addNode --direction=outgoing --depth=5 --json-out=docs/target_architecture/evidence/add_node_write_flow.json --mermaid-out=docs/target_architecture/evidence/add_node_write_flow.md`
  Evidence:
  [add_node_write_flow.json](../evidence/add_node_write_flow.json),
  [add_node_write_flow.md](../evidence/add_node_write_flow.md)
- `dart run tool/lsp_find_boundary_bypasses.dart lib/src/interactive/scene_controller_scene.dart SceneControllerSceneOwner --must-pass=SceneControllerMutationBoundary --depth=5`
- `dart run tool/lsp_find_boundary_bypasses.dart lib/src/interactive/scene_controller_selection.dart SceneControllerSelectionOwner --must-pass=SceneControllerMutationBoundary --depth=5`
- `dart run tool/lsp_find_thin_wrappers.dart lib/src/interactive --classification=pure-forwarder`

## Status

- `locked`
- The checked-in local form now matches the accepted direct-route target:
  direct public/runtime callers cross `SceneControllerMutationBoundary`
  without a routing-shell layer, while committed mutation access remains the
  controller-owned downstream seam.
