# Composition Root And Facade

## Purpose

This family defines who assembles the runtime center and which public owner is
allowed to expose that assembled graph to package callers.

The checked-in code keeps one public `SceneController` facade and centers the
assembly and teardown path in `createSceneControllerGraph` and
`SceneControllerGraphHandle`.

## Target Rules

- `SceneController` remains the supported public interactive facade.
- `createSceneControllerGraph` remains the internal composition-root entrypoint
  that assembles runtime owners and capability owners.
- `SceneControllerGraphHandle` owns the assembled controller lifecycle,
  including `SceneStoreController` construction, runtime teardown, view-runtime
  teardown, and internal-access unregistration.
- Assembled runtime dependencies such as `SceneStoreController`,
  `SceneControllerInteractionRuntime`, and `SceneControllerSceneViewRuntime`
  stay dependencies of the root, not peer public roots.
- The composition root stays responsible for assembly and disposal wiring only;
  domain behavior remains with the owners it connects.

## Owners

- Public facade:
  `lib/src/interactive/scene_controller.dart`
- Composition root and lifecycle handle:
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
- Do not let `SceneController` construct `SceneStoreController` or directly fan
  teardown out across store, runtime, view-runtime, or internal-access owners.
- Do not reintroduce a top-level `sceneControllerGraph*` helper bag; extend
  `SceneControllerGraphHandle` for composition-family forwarding.
- Do not treat capability owners as separate roots or let them absorb runtime
  assembly responsibilities.
- Do not turn the composition root into a new domain-logic bucket; it may wire
  owners together, but it must not own their behavior.

## Mechanical Evidence

- `dart run tool/lsp_trace_symbol.dart lib/src/interactive/internal/scene_controller_graph.dart createSceneControllerGraph --direction=outgoing --depth=3 --json-out=docs/architecture/evidence/composition_root_trace.json --mermaid-out=docs/architecture/evidence/composition_root_trace.md`
  Evidence:
  [composition_root_trace.json](../evidence/composition_root_trace.json),
  [composition_root_trace.md](../evidence/composition_root_trace.md)
- `flutter test --no-pub test/controller test/interactive`

## Proof Links

- Proof family: [public entrypoint and signature proof](../../proof_architecture/families/public_entrypoint_and_signature_proof.md)
- Proof family: [guardrail runner and artifact model](../../proof_architecture/families/guardrail_runner_and_artifact_model.md)
- Guardrail: `dart run tool/check_guardrails.dart`
- Import boundaries: `dart run tool/check_import_boundaries.dart`
- Invariant: `INV-G-LAYER-DAG`
- Invariant: `INV-ENG-CONTROLLER-NO-FULL-VIEW-RENDER-STATE`
- Invariant: `INV-ENG-CONTROLLER-COMMIT-RUNTIME-BOUNDARY`
- Invariant: `INV-ENG-INTERACTIVE-ARCHITECTURE-BOUNDARY`
- Invariant: `INV-ENG-VIEW-POINTER-SEMANTICS-BOUNDARY`
- Invariant: `INV-ENG-VIEW-RENDER-READ-STATE-BOUNDARY`

## Status

- `locked`
- Checked-in code centers assembly, store construction, facade forwarding, and
  coordinated teardown in `SceneControllerGraphHandle`; `SceneController`
  remains the thin public facade.

## Update Triggers

- Refresh this family when its listed owners, evidence commands, or linked proof surfaces change.
