# Composition Root And Facade

## Purpose

This family defines who assembles the runtime center and which public owner is
allowed to expose that assembled graph to package callers.

The checked-in code keeps one public `SceneController` facade and centers the
assembly path in `createSceneControllerGraph`.

## Target Rules

- `SceneController` remains the supported public interactive facade.
- `createSceneControllerGraph` remains the internal composition-root entrypoint
  that assembles runtime owners and capability owners.
- Assembled runtime dependencies such as `SceneStoreController`,
  `SceneControllerInteractionRuntime`, and `SceneControllerSceneViewRuntime`
  stay dependencies of the root, not peer public roots.
- The composition root stays responsible for assembly and disposal wiring only;
  domain behavior remains with the owners it connects.

## Owners

- Public facade:
  `lib/src/interactive/scene_controller.dart`
- Composition root and root-local helpers:
  `lib/src/interactive/internal/scene_controller_graph.dart`
- Internal access seam:
  `lib/src/interactive/internal/scene_controller_internal_access.dart`
- Assembled capability owners:
  `lib/src/interactive/scene_controller_interaction.dart`,
  `lib/src/interactive/scene_controller_selection.dart`, and
  `lib/src/interactive/scene_controller_scene.dart`
- Assembled runtime dependencies owned by other families:
  `lib/src/controller/scene_store_controller.dart`,
  `lib/src/interactive/internal/scene_controller_interaction_runtime.dart`, and
  `lib/src/interactive/internal/scene_controller_scene_view_runtime.dart`

## Forbidden Shapes

- Do not let `SceneController` become a peer assembly owner alongside the
  internal composition root.
- Do not treat capability owners as separate roots or let them absorb runtime
  assembly responsibilities.
- Do not turn the composition root into a new domain-logic bucket; it may wire
  owners together, but it must not own their behavior.

## Mechanical Evidence

- `dart run tool/lsp_trace_symbol.dart lib/src/interactive/internal/scene_controller_graph.dart createSceneControllerGraph --direction=outgoing --depth=3 --json-out=docs/target_architecture/evidence/composition_root_trace.json --mermaid-out=docs/target_architecture/evidence/composition_root_trace.md`
  Evidence:
  [composition_root_trace.json](../evidence/composition_root_trace.json),
  [composition_root_trace.md](../evidence/composition_root_trace.md)

## Status

- `locked, needs slimming`
- Checked-in code already centers assembly in `createSceneControllerGraph`, but
  the facade and root-local helper surface are still broader than the intended
  steady-state shape.
