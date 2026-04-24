# Mutation Gateway

## Purpose

This family defines which owner may translate interaction-side mutation intent
into committed writes.

The checked-in code keeps one committed-write gateway in
`SceneControllerMutationBoundary` and routes scene-side mutation wrappers
through that boundary.

## Target Rules

- `SceneControllerMutationBoundary` remains the only interaction-owned owner
  that performs committed writes.
- `SceneControllerCommittedMutationAccess` remains the adapter seam from the
  gateway into the committed store/write path.
- Scene-side and selection-side wrappers stay thin callers of the gateway; they
  do not become competing write owners.
- Gesture lifetime, preview lifetime, and view hosting remain outside the
  gateway.

## Owners

- Gateway core:
  `lib/src/interactive/internal/scene_controller_mutation_boundary.dart`
- Committed-mutation access seam:
  `lib/src/controller/scene_controller_committed_mutation_access.dart`
- Scene-side and selection-side wrappers:
  `lib/src/interactive/internal/scene_controller_scene_mutations.dart` and
  `lib/src/interactive/internal/scene_controller_selection_mutations.dart`
- Interaction-side selection helper:
  `lib/src/interactive/internal/interactive_selection_actions.dart`

## Forbidden Shapes

- Do not let scene-side wrappers, selection-side wrappers, or interaction
  helpers bypass `SceneControllerMutationBoundary` to reach committed writes
  directly.
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
- `dart run tool/lsp_find_thin_wrappers.dart lib/src/interactive --classification=pure-forwarder`

## Status

- `locked, needs slimming`
- The gateway boundary is stable, but the gateway core and committed-mutation
  adapter remain broader than the intended steady-state shape.
