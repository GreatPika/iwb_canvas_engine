# Change Contract

## 1. Change Mandate

Make the composition root own the full interactive controller assembly and
teardown lifecycle by moving store construction and root-local forwarding into
one internal graph handle, leaving `SceneController` as a thin public facade.

## 2. Change Boundary

### Included in the Change

- replace the `SceneControllerGraph` record plus the root-local
  `sceneControllerGraph*` helper bag with one internal
  `SceneControllerGraphHandle` returned by `createSceneControllerGraph`
- move `SceneStoreController` construction from `SceneController` into
  `createSceneControllerGraph` / `_assembleSceneControllerGraph`
- move coordinated teardown after facade-side dispose preflight,
  internal-access unregister, stream access, preview-delta access, and
  root-local public-side-effect delegation behind `SceneControllerGraphHandle`
- slim `SceneController` so it keeps only the public facade surface:
  public capability owners, committed-read getters, overlay-preview getters,
  stream getters, `sceneControllerViewRuntimeOf`, and one guarded delegated
  `dispose()`
- update structural architecture proof and interactive guardrails so future
  regressions catch facade-owned store construction, direct teardown fan-out,
  or a reintroduced top-level helper bag
- refresh `ARCHITECTURE.md`, the composition target-family docs, and the
  committed composition-root evidence once the new local form lands
- update `PLAN.md` and this step document together when the step closes

### Not Included in the Change

- no mutation-gateway narrowing or committed-write path redesign
- no interaction-family compression beyond the composition cut required to keep
  assembly and teardown in the right owner
- no store-facade cleanup inside `SceneStoreController` beyond moving its
  construction site
- no public API, export-surface, or runtime-contract behavior change for
  package callers
- no pointer-session ownership change, runtime-host swap change, or render-seam
  change
- no special-case relaxation of the resolved `SceneController` entrypoint
  guard; `dispose()` must continue to satisfy the existing guarded block-body
  rule from the public facade
- no ADR update; `docs/adr/0001_target_engine_architecture.md` already locks
  the accepted top-level owner split
- no `README.md`, `API_GUIDE.md`, or `CHANGELOG.md` update because this step
  changes internal checked-in architecture, not public package behavior

## 3. Surrounding Code Review

### Inspected Artifacts

- `PLAN.md` - the active plan index requires one dedicated execution contract
  per new step
- `docs/adr/0001_target_engine_architecture.md` - the accepted target keeps
  `SceneController` thin and keeps one internal composition root centered on
  `createSceneControllerGraph`
- `docs/adr/0002_post_target_optimization_scope.md` - the remaining first-wave
  primary cuts are composition/facade compression and mutation-gateway
  narrowing; phase 2 is still gated behind those cuts
- `docs/target_architecture/overview.md` - the composition family is currently
  `locked, needs slimming`, while the render-seam family is already `locked`
- `docs/target_architecture/families/composition_root_and_facade.md` - the
  target rules already lock `createSceneControllerGraph` as the internal
  composition-root entrypoint and say assembly/disposal wiring belongs under
  the root rather than the facade
- `docs/target_architecture/evidence/composition_root_trace.json` and
  `docs/target_architecture/evidence/composition_root_trace.md` - the committed
  evidence already shows downstream runtime assembly under
  `createSceneControllerGraph`, but it does not include `SceneStoreController`
  construction because the facade still owns that step
- `lib/src/interactive/scene_controller.dart` - the facade still creates
  `SceneStoreController`, stores `_storeController`, and fans teardown out
  across store dispose, graph dispose, and internal-access detach
- `lib/src/interactive/internal/scene_controller_graph.dart` - the composition
  family already centers assembly under `createSceneControllerGraph`, but it
  still exposes a record carrier plus a top-level helper bag for streams,
  preview-delta access, public-side-effect delegation, dispose status, and
  teardown
- `lib/src/interactive/internal/scene_controller_internal_access.dart` - the
  internal-access seam is already a dedicated owner; the current split problem
  is who coordinates register/unregister, not where the seam lives
- `lib/src/interactive/internal/scene_controller_scene_view_runtime.dart` -
  this file is the closest valid precedent for the successor form: one named
  internal owner over assembled sub-owners and lifecycle, rather than a record
  plus top-level helper functions
- `lib/src/interactive/internal/scene_controller_interaction_access.dart` -
  `SceneControllerInteractionContext` still needs the public facade as its
  `Listenable` owner, so the composition cut must not move public
  `ChangeNotifier` ownership out of `SceneController`
- `lib/src/controller/scene_store_controller.dart` - committed store ownership
  stays here even after the construction site moves
- `lib/src/controller/scene_controller_commit_runtime.dart` and
  `lib/src/controller/scene_controller_commit_write_runner.dart` - store
  disposal is order-sensitive because `SceneControllerCommitWriteRunner.dispose`
  throws during active write; teardown order is therefore an architectural
  constraint, not implementation trivia
- `test/interactive/core/scene_controller_architecture_boundary_test.dart` -
  current structural proof already locks canonical graph assembly and the
  existing runtime/view split, but it does not yet reject facade-owned store
  construction or facade-owned teardown fan-out
- `test/interactive/core/scene_controller_interaction_contract_test.dart` -
  current behavioral proof already locks internal-access registration and the
  `sceneControllerViewRuntimeOf` bridge into the view/runtime seam
- `test/interactive/core/scene_controller_public_listener_contract_test.dart` -
  current behavioral proof already locks the public listener surface across the
  normal split repaint channels, and is the correct neighboring proof surface
  for a new failed-`dispose()` guard that must prove the public notifier stays
  alive after a rejected dispose attempt
- `test/interactive/core/scene_controller_interactive_dispose_fail_fast_test.dart`
  - current behavioral proof already locks idempotent facade dispose, active
  write fail-fast, and internal-access unregistration after successful dispose
- `tool/src/guardrails/rules/interactive/interactive_architecture_boundary_facade_rules.dart`
  - current guardrails already require canonical graph initialization and a
  thin facade, but they do not yet reject direct facade ownership of
  `SceneStoreController` or direct teardown fan-out
- `tool/src/guardrails/rules/interactive/interactive_architecture_boundary_graph_rules.dart`
  - current graph guardrails already require assembly of capability owners,
  view runtime, and internal access under `scene_controller_graph.dart`, but
  they do not yet require store construction to live there
- `tool/src/guardrails/rules/interactive/resolved_entrypoint_guard_rules.dart`
  - current resolved guardrails require each public `SceneController`
  entrypoint, including `dispose()`, to remain a facade-owned block body
  guarded by `_ensurePublicSideEffectAllowed(...)`, so the target thin-facade
  form must keep dispose preflight at the public boundary instead of moving it
  behind a guardrail special-case or an unguarded direct graph call
- `test/tool/guardrails/interactive_api/architecture_boundary/view_and_graph_cases.dart`
  and `test/tool/guardrails/interactive_api/architecture_boundary/facade_and_boundary_cases.dart`
  - existing guardrail cases already model canonical graph assembly and thin
  facade constraints, and are the correct place to add store/lifecycle
  regressions for this cut
- `test/tool/guardrails/guardrails_interactive_resolved_entrypoint_guard_tool_test.dart`
  - existing tool proof already locks the public guarded-entrypoint form for
  `SceneController`, so the composition cut must preserve that shape while
  slimming teardown fan-out
- `test/tool/support/guardrails_sandbox_support.dart` - the shared interactive
  scaffold still needs to model the canonical composition shape that tool
  guardrails assert
- `ARCHITECTURE.md` - the checked-in architecture still says `SceneController`
  owns both a `SceneStoreController` and an assembled controller graph, which
  must change when the root becomes the sole assembly owner
- `tool/invariant_registry.dart` - the interactive architecture invariant still
  points at the correct proof surface, but its wording can be tightened once
  the composition family reaches the thinner local form
- `dart run tool/lsp_trace_symbol.dart lib/src/interactive/scene_controller.dart SceneController.dispose --direction=outgoing --depth=3 --json`
  - shows the facade still owns teardown fan-out to
  `_ensurePublicSideEffectAllowed`, `SceneStoreController.dispose()`,
  `disposeSceneControllerGraph(...)`, and
  `detachSceneControllerGraphInternalAccess(...)`
- `dart run tool/lsp_trace_symbol.dart lib/src/interactive/internal/scene_controller_graph.dart createSceneControllerGraph --direction=outgoing --depth=3 --json`
  - shows the graph file already owns downstream assembly of interaction
  runtime, view runtime, capability owners, and internal access registration
- `dart run tool/lsp_trace_symbol.dart lib/src/interactive/internal/scene_controller_graph.dart sceneControllerGraphActions --direction=outgoing --depth=3 --json`
  plus the same probe for `sceneControllerGraphEditTextRequests`,
  `sceneControllerGraphPreviewDeltaResolver`,
  `sceneControllerGraphEnsurePublicSideEffectAllowed`,
  `sceneControllerGraphIsDisposed`, and
  `detachSceneControllerGraphInternalAccess`
  - together show that the current root-local helper surface is mostly
  delegation and lifecycle coordination rather than durable domain ownership
- `dart run tool/lsp_find_boundary_bypasses.dart lib/src/interactive/internal/interactive_selection_actions.dart InteractiveSelectionActions --must-pass=SceneControllerMutationBoundary --depth=4 --json`
  - returned `[]`, confirming that the mutation family already holds its
  architectural boundary and is not the next top-level cut to take first

### Current Entry Path

- construction:
  `SceneController(...)` ->
  `SceneStoreController(...)` ->
  `createSceneControllerGraph(SceneControllerGraphRequest(...))` ->
  `_assembleSceneControllerGraph(...)` ->
  `SceneControllerSceneViewRuntime` /
  `createSceneControllerInteractionRuntime(...)` /
  `SceneControllerInteractionOwner` /
  `SceneControllerSelectionOwner` /
  `SceneControllerSceneOwner` ->
  `registerSceneControllerInternalAccess(...)`
- public view bridge:
  `SceneViewInteractive.build()` ->
  `sceneControllerViewRuntimeOf(controller)` ->
  `controller._graph.sceneViewRuntime`
- teardown:
  `SceneController.dispose()` ->
  `_ensurePublicSideEffectAllowed('dispose', allowAfterDispose: true)` ->
  `sceneControllerGraphIsDisposed(...)` ->
  `SceneStoreController.dispose()` ->
  `SceneControllerCommitRuntime.dispose()` ->
  `SceneControllerCommitWriteRunner.dispose()` ->
  `disposeSceneControllerGraph(...)` ->
  `SceneControllerInteractionRuntime.dispose()` /
  `SceneControllerSceneViewRuntime.dispose()` ->
  `detachSceneControllerGraphInternalAccess(...)`

### Current Owner

- interactive composition-family ownership is currently split between
  `lib/src/interactive/scene_controller.dart` as the public facade and
  `lib/src/interactive/internal/scene_controller_graph.dart` as the internal
  assembly owner
- `SceneStoreController` remains the committed-state owner in
  `lib/src/controller/scene_store_controller.dart`, but the current assembly
  site for that owner is still in the facade instead of the composition root
- internal access remains a dedicated seam in
  `lib/src/interactive/internal/scene_controller_internal_access.dart`, but
  its lifecycle coordination is still split between facade and graph helpers

### Adjacent Abstractions

- `lib/src/interactive/internal/scene_controller_scene_view_runtime.dart` -
  adjacent runtime boundary that already demonstrates a coherent internal owner
  over assembled sub-owners and lifecycle
- `lib/src/interactive/internal/scene_controller_interaction_access.dart` -
  adjacent public-to-runtime seam that still depends on `SceneController` as a
  `Listenable`
- `lib/src/controller/scene_store_controller.dart` - adjacent committed-store
  owner that must keep its own responsibilities even after the composition root
  becomes its constructor
- `lib/src/interactive/scene_controller_interaction.dart`,
  `lib/src/interactive/scene_controller_selection.dart`, and
  `lib/src/interactive/scene_controller_scene.dart` - adjacent capability
  owners that must remain assembled dependencies rather than become new roots

### Existing Tests

- `test/interactive/core/scene_controller_architecture_boundary_test.dart` -
  locks canonical graph assembly, view/runtime boundaries, and the absence of
  deleted residual seams
- `test/interactive/core/scene_controller_interaction_contract_test.dart` -
  locks internal-access registration, `sceneControllerViewRuntimeOf`, and
  pointer-session bridge behavior
- `test/interactive/core/scene_controller_public_listener_contract_test.dart` -
  locks public-listener behavior across split repaint channels and is the right
  file for the guard test that proves failed `dispose()` does not partially
  kill the public notifier surface
- `test/interactive/core/scene_controller_interactive_dispose_fail_fast_test.dart`
  - locks idempotent facade dispose, internal-access unregister, and active
  write fail-fast
- `test/tool/guardrails/guardrails_interactive_api_tool_test.dart` -
  locks interactive guardrails through negative structural scenarios
- `test/tool/target_architecture_map_tool_test.dart` - locks target-map section
  shape and committed evidence references

### Analogous Implementation Path

- `lib/src/interactive/internal/scene_controller_scene_view_runtime.dart` -
  the closest checked-in precedent for the desired form: one internal owner
  stores assembled sub-owners, exposes narrow getters/methods, and owns its
  lifecycle without spilling that wiring into the public facade

### Governing Repository Rules

- `AGENTS.md` - repository-specific decisions must prefer checked-in code and
  mechanically enforced local rules over prose-only reminders
- `AGENTS.md` - important stable constraints should become structural tests,
  guardrails, or tooling where feasible
- `AGENTS.md` - use `$change-contract` when adding a new step to `PLAN.md`
- `docs/adr/0001_target_engine_architecture.md` - `SceneController` remains a
  thin public facade and one internal composition root assembles the runtime
  center
- `docs/target_architecture/families/composition_root_and_facade.md` - the
  composition root owns assembly and disposal wiring only; the facade must not
  remain a peer assembly owner
- `test/interactive/core/scene_controller_architecture_boundary_test.dart` -
  `lib/src/interactive/internal/scene_controller_facade_assembly.dart` must
  stay absent, so this step cannot solve the cut by inventing a second assembly
  file

### Rejected Misleading Local Patterns

- take mutation-gateway narrowing first - wrong next cut because the current
  boundary-bypass probe already shows the write path remains centered on
  `SceneControllerMutationBoundary`
- leave store construction in the facade and move only teardown - wrong level
  because the facade would still remain a peer assembly owner
- create a second assembly file such as
  `lib/src/interactive/internal/scene_controller_facade_assembly.dart` - wrong
  file boundary because the checked-in architecture proof already guards
  against reintroducing that seam
- move store construction or teardown into `SceneControllerInteractionRuntime`
  or `SceneControllerSceneViewRuntime` - wrong owner because those are
  assembled dependencies, not the composition root
- keep the record carrier and helper bag while only renaming helpers - wrong
  seam because lifecycle ownership would remain structurally implicit
- move `ChangeNotifier` ownership off `SceneController` - wrong public boundary
  because `SceneControllerInteractionContext` and pointer sessions still depend
  on the facade as the public listenable owner

## 4. Architecture

### 4A. Locked Architectural Form

#### Problem Ownership Level

- the interactive composition-family seam between the public `SceneController`
  facade and the internal assembly/disposal owner for the runtime center

#### Selected Architectural Form

- keep `createSceneControllerGraph` in
  `lib/src/interactive/internal/scene_controller_graph.dart` as the sole
  composition-root entrypoint for the interactive controller path
- replace the `SceneControllerGraph` record and root-local `sceneControllerGraph*`
  helper bag with one named internal owner:
  `SceneControllerGraphHandle`
- `SceneControllerGraphHandle` owns:
  `SceneStoreController`,
  `SceneControllerInteractionRuntime`,
  `SceneControllerInteractionAccess`,
  `SceneControllerInteraction`,
  `SceneControllerSelection`,
  `SceneControllerScene`,
  `SceneViewRuntime`,
  internal-access registration/unregistration coordination,
  and the narrow forwarding surface still needed by the facade
- `SceneControllerGraphRequest` remains the canonical request object, but it
  changes from carrying a prebuilt store and facade-derived committed-read
  closures to carrying the public constructor inputs and facade hooks that the
  root legitimately needs:
  `owner`,
  `notifyListeners`,
  `initialSnapshot`,
  `pointerSettings`,
  `dragStartSlop`,
  `clearSelectionOnDrawModeEnter`,
  `moveCommitDeltaResolver`,
  and `textFontFamilyByDefault`
- `SceneController` stores only `_graph: SceneControllerGraphHandle` and
  delegates committed reads, overlay-preview reads, capability owners, streams,
  preview-delta access, and `dispose()` through that handle
- `SceneController.dispose()` remains a facade-owned guarded block body:
  it calls `_ensurePublicSideEffectAllowed('dispose', allowAfterDispose: true)`,
  delegates teardown to `_graph.dispose()`, and calls `super.dispose()` only
  after the first successful graph-owned teardown; it must not re-expand into
  facade-owned teardown fan-out
- `SceneController` remains the public `ChangeNotifier` facade and is still the
  `Listenable` owner passed into interaction access and pointer-session hosting;
  the handle does not replace the public notifier
- `SceneControllerGraphHandle.dispose()` owns coordinated teardown and must
  preserve the current safety order:
  idempotence check first after facade preflight,
  `SceneStoreController.dispose()` second,
  interactive runtime and view-runtime teardown third,
  internal-access unregister last

#### Owning Layer or Module

- public facade:
  `lib/src/interactive/scene_controller.dart`
- internal composition root and graph handle:
  `lib/src/interactive/internal/scene_controller_graph.dart`
- root-local internal-access seam:
  `lib/src/interactive/internal/scene_controller_internal_access.dart`
- unchanged assembled runtime dependencies:
  `lib/src/controller/scene_store_controller.dart`,
  `lib/src/interactive/internal/scene_controller_interaction_runtime.dart`,
  and `lib/src/interactive/internal/scene_controller_scene_view_runtime.dart`

#### Dependency Direction

- no layer-DAG change is introduced; `interactive/**` keeps its existing
  dependencies on `controller/**`, `core/**`, and `contract/**`
- `SceneController` keeps its dependency on
  `internal/scene_controller_graph.dart` and `../contract/scene_view_runtime.dart`,
  but it loses direct ownership of store construction and direct teardown
  helpers
- `scene_controller_graph.dart` becomes the only interactive file allowed to
  construct `SceneStoreController` for the public controller path
- `SceneControllerGraphHandle` may depend on the existing interactive runtime,
  capability owners, view runtime, and internal-access seam, but those owners
  remain downstream dependencies rather than peers of the facade

#### State and Data Ownership

- committed scene state remains owned by `SceneStoreController` and the
  controller write kernel
- public notification ownership remains with `SceneController` as the public
  `ChangeNotifier`
- interaction runtime, pointer-session state, and view-runtime state ownership
  stay with their existing owners
- `SceneControllerGraphHandle` owns only assembly, lifecycle coordination, and
  the narrow forwarding surface that still belongs under the composition root
- internal-access registration data remains owned by
  `scene_controller_internal_access.dart`; only the coordination point moves

#### Entry and Exit Boundaries

- assembly entry:
  `SceneController(...)` ->
  `createSceneControllerGraph(SceneControllerGraphRequest(...))`
- facade exits:
  `SceneController.snapshot`,
  `selectedNodeIds`,
  `controllerEpoch`,
  overlay-preview getters,
  `interaction`,
  `selection`,
  `scene`,
  `actions`,
  `editTextRequests`,
  and `previewDeltaResolver` all delegate through `_graph`
- view exit:
  `sceneControllerViewRuntimeOf(controller)` remains the only top-level bridge
  from the public facade into `SceneViewRuntime`
- teardown exit:
  `SceneController.dispose()` ->
  `_ensurePublicSideEffectAllowed('dispose', allowAfterDispose: true)` ->
  `_graph.dispose()` ->
  `super.dispose()` only after successful first teardown, with no facade-owned
  fan-out across store/runtime/internal-access cleanup

#### Permitted Extension Seam

- any new composition-family forwarding or lifecycle API must extend
  `SceneControllerGraphHandle`, not a new `sceneControllerGraph*` top-level
  function and not a new facade-owned state field
- `sceneControllerViewRuntimeOf` remains the only permitted top-level bridge on
  `scene_controller.dart` for the view shell
- any new internal-access registration helper must stay under
  `scene_controller_graph.dart` and `scene_controller_internal_access.dart`,
  not reappear in the facade

#### Rejected Alternatives

- leave store construction in the facade and move only dispose fan-out - rejected
  because the facade would still remain a peer assembly owner
- create a new assembly file such as
  `lib/src/interactive/internal/scene_controller_facade_assembly.dart` -
  rejected because the checked-in architecture proof explicitly guards that
  file as absent
- move store creation or teardown into `SceneControllerInteractionRuntime` or
  `SceneControllerSceneViewRuntime` - rejected because those are assembled
  dependencies, not the composition root
- keep the record carrier plus helper bag and add more facade-local proxies -
  rejected because lifecycle ownership would remain implicit and structurally
  hard to guard

#### Why This Level Is Correct

- the hot spot is already localized in `scene_controller.dart` and
  `scene_controller_graph.dart`, so the fix belongs in the composition family
  rather than another layer or owner family
- the current mutation-family probes already show correct write-boundary
  ownership, so moving to mutation-gateway narrowing first would not address
  the remaining top-level composition gap
- `SceneControllerSceneViewRuntime` already demonstrates the dominant local
  repository form for this kind of cut: one named internal owner over assembled
  sub-owners and lifecycle rather than a record plus top-level helper bag

## 5. Locked Decisions

1. The successor seam is fixed as `SceneControllerGraphHandle`, and
   `createSceneControllerGraph` returns that type. The current
   `SceneControllerGraph` record typedef is retired in this step.
2. `SceneControllerGraphRequest` keeps the public constructor inputs and facade
   hooks, but it no longer accepts a prebuilt `SceneStoreController` or
   facade-derived committed-read closures.
3. `SceneController` keeps `sceneControllerViewRuntimeOf` and the public
   capability getters (`interaction`, `selection`, `scene`), but it does not
   keep a peer `_storeController` field after this step.
4. `SceneController.dispose()` remains the public guarded entrypoint for
   dispose and may only perform facade preflight, one delegated call into
   `SceneControllerGraphHandle.dispose()`, and conditional `super.dispose()`;
   it must not regain direct teardown fan-out or depend on a guardrail
   special-case.
5. `SceneControllerGraphHandle.dispose()` must preserve current dispose
   semantics:
   idempotent success after prior dispose,
   fail-fast during active committed write,
   no partial interactive teardown when store dispose rejects,
   and internal-access unregister only after successful teardown.
6. `scene_controller_graph.dart` remains the only file allowed to coordinate
   `registerSceneControllerInternalAccess(...)` and
   `unregisterSceneControllerInternalAccess(...)` for the public controller
   path.
7. The composition family moves from `locked, needs slimming` to `locked` only
   after the refreshed `composition_root_trace` shows store construction under
   `createSceneControllerGraph` and the facade no longer owns store or direct
   teardown wiring.

## 6. Result Requirements

1. `SceneController` has no `_storeController` field and no direct calls to
   `SceneStoreController(...)`, `disposeSceneControllerGraph(...)`, or
   `detachSceneControllerGraphInternalAccess(...)`.
2. `createSceneControllerGraph` constructs the store and returns one
   `SceneControllerGraphHandle` that owns the assembled controller lifecycle.
3. Public behavior remains unchanged:
   `SceneController.dispose()` stays idempotent,
   `dispose()` still fails fast during active write without partially tearing
   down the controller,
   internal access remains unavailable after successful dispose,
   and `dispose()` remains a facade-guarded public entrypoint rather than an
   unguarded direct graph call.
4. `sceneControllerViewRuntimeOf` continues to return the assembled
   `SceneViewRuntime`, and the interaction contract tests still observe the same
   pointer-session and internal-access behavior.
5. No checked-in production, guardrail, or source-of-truth file still models
   `SceneController` as a peer owner of both the store and the controller
   graph after this step closes.
6. `ARCHITECTURE.md`, the composition target-family docs, and the committed
   composition evidence all describe the landed local form rather than the
   pre-cut split ownership.

## 7. Execution Order and Gates

### Required Order

- first, lock the current behavior with the existing interaction-contract and
  dispose-fail-fast suites, then extend structural proof so the target facade
  and graph shape is mechanically checkable
- second, introduce `SceneControllerGraphHandle` and migrate facade-owned
  forwarding surface to it so lifecycle and delegation are no longer expressed
  through top-level helper functions
- third, move store construction and coordinated teardown into the graph handle
  while preserving facade-owned dispose preflight and retiring the facade-owned
  store field plus direct teardown fan-out
- fourth, refresh source-of-truth docs, committed evidence, and step tracking
  once the final local form is already green

### Successor Seam and Retirement Gates

- `SceneControllerGraphHandle` succeeds the `SceneControllerGraph` record plus
  these top-level helpers:
  `sceneControllerGraphActions(...)`,
  `sceneControllerGraphEditTextRequests(...)`,
  `sceneControllerGraphPreviewDeltaResolver(...)`,
  `sceneControllerGraphEnsurePublicSideEffectAllowed(...)`,
  `sceneControllerGraphIsDisposed(...)`,
  `disposeSceneControllerGraph(...)`, and
  `detachSceneControllerGraphInternalAccess(...)`
- the helper bag must not be deleted until the facade, architecture-boundary
  test, `test/tool/support/guardrails_sandbox_support.dart`,
  `test/tool/guardrails/interactive_api/architecture_boundary/view_and_graph_cases.dart`,
  and
  `test/tool/guardrails/interactive_api/architecture_boundary/facade_and_boundary_cases.dart`
  all consume the handle-based composition shape
- facade-owned store construction must not be deleted until
  `SceneController.dispose()` still satisfies the resolved public-entrypoint
  guard shape and `SceneControllerGraphHandle.dispose()` proves the existing
  active-write fail-fast behavior and idempotent dispose behavior
- `docs/target_architecture/overview.md`,
  `docs/target_architecture/families/composition_root_and_facade.md`, and
  `docs/target_architecture/evidence/composition_root_trace.*` update only
  after the code path and structural proof are final

### Deferred Broad Verification

- reserve `dart run tool/check_guardrails.dart` for the final gate because it
  aggregates the full guardrail surface
- reserve the Section 11 `required_code_change` preset command for the final
  gate after code, docs, evidence, and plan artifacts have all landed

## 8. File Map

### Implementation Files

- `PLAN.md`
- `plan/step_17_complete_composition_root_ownership_and_facade_slimming.md`
- `lib/src/interactive/scene_controller.dart`
- `lib/src/interactive/internal/scene_controller_graph.dart`
- `lib/src/interactive/internal/scene_controller_internal_access.dart`
- `tool/src/guardrails/rules/interactive/interactive_architecture_boundary_facade_rules.dart`
- `tool/src/guardrails/rules/interactive/interactive_architecture_boundary_graph_rules.dart`
- `ARCHITECTURE.md`
- `docs/target_architecture/overview.md`
- `docs/target_architecture/families/composition_root_and_facade.md`

### Test Files

- `test/interactive/core/scene_controller_architecture_boundary_test.dart`
- `test/interactive/core/scene_controller_interaction_contract_test.dart`
- `test/interactive/core/scene_controller_public_listener_contract_test.dart`
- `test/interactive/core/scene_controller_interactive_dispose_fail_fast_test.dart`
- `test/tool/guardrails/guardrails_interactive_resolved_entrypoint_guard_tool_test.dart`
- `test/tool/guardrails/guardrails_interactive_api_tool_test.dart`
- `test/tool/guardrails/interactive_api/architecture_boundary/view_and_graph_cases.dart`
- `test/tool/guardrails/interactive_api/architecture_boundary/facade_and_boundary_cases.dart`
- `test/tool/target_architecture_map_tool_test.dart`

### Fixtures and Supporting Data

- `test/tool/support/guardrails_sandbox_support.dart`
- `docs/target_architecture/evidence/composition_root_trace.json`
- `docs/target_architecture/evidence/composition_root_trace.md`

### Registry, Inventory, and Workflow Files

- `tool/invariant_registry.dart`
- `tool/run_tool_tests.dart`
- `tool/check_guardrails.dart`
- `tool/check_invariant_coverage.dart`
- `tool/run_verification_preset.dart`

### Analysis Area

- `lib/src/interactive/**`
- `docs/target_architecture/**`
- `test/interactive/core/**`
- `test/tool/guardrails/**`
- `tool/src/guardrails/rules/interactive/**`

## 9. Implementation Rules

### Protected Invariants

- `SceneController` remains the public `ChangeNotifier` facade and the only
  supported public interactive root
- `createSceneControllerGraph` remains the sole composition-root entrypoint for
  the public controller path
- committed scene state remains owned by `SceneStoreController` and the commit
  runtime; only the construction site moves
- `sceneControllerViewRuntimeOf` remains the only top-level view bridge from
  the public facade into the assembled runtime boundary
- `SceneController.dispose()` remains a public facade guard point that satisfies
  the resolved `_ensurePublicSideEffectAllowed(...)` entrypoint rule while
  delegating teardown ownership to the graph handle
- successful dispose unregisters internal access, while failed dispose during
  active write leaves the controller usable

### Required Proof

- behavioral proof:
  `test/interactive/core/scene_controller_interaction_contract_test.dart`,
  `test/interactive/core/scene_controller_public_listener_contract_test.dart`,
  and
  `test/interactive/core/scene_controller_interactive_dispose_fail_fast_test.dart`
  must stay green across the composition cut
- structural proof:
  `test/interactive/core/scene_controller_architecture_boundary_test.dart`,
  `test/tool/guardrails/guardrails_interactive_resolved_entrypoint_guard_tool_test.dart`,
  `test/tool/guardrails/guardrails_interactive_api_tool_test.dart`,
  `test/tool/target_architecture_map_tool_test.dart`, and
  `dart run tool/check_invariant_coverage.dart`
  must make future drift in facade/store/root ownership mechanically visible
- for refactors: keep the existing locking tests above green or extend them
  before widening the structural edit set

### Allowed Change Surface

- change only the files listed in Section 8
- introduce at most one new internal handle type:
  `SceneControllerGraphHandle` inside
  `lib/src/interactive/internal/scene_controller_graph.dart`
- keep the composition-family cut inside the existing facade/root files; do not
  create a second assembly file or a new public API seam

### Forbidden Moves

- no new file such as
  `lib/src/interactive/internal/scene_controller_facade_assembly.dart`
- no move of public `ChangeNotifier` ownership out of `SceneController`
- no teardown order that disposes interactive runtime or unregisters internal
  access before store-dispose preflight
- no unguarded public `dispose()` that calls `_graph.dispose()` directly from
  the facade without `_ensurePublicSideEffectAllowed(...)`
- no guardrail special-case that makes delegated `dispose()` legal by relaxing
  the existing resolved public-entrypoint contract instead of preserving the
  guarded facade shape
- no new `sceneControllerGraph*` top-level helper bag after
  `SceneControllerGraphHandle` lands
- no mutation-family or store-family cleanup unrelated to the ownership move

### Optional: Allowed Forms That Are Not Violations

- `sceneControllerViewRuntimeOf` may remain as a top-level bridge on
  `scene_controller.dart`
- `SceneControllerGraphHandle` may expose assembled owners and narrow accessors
  through fields or getters as long as lifecycle ownership stays inside the
  handle

## 10. Vertical Slices

### Slice 1. [ ] Introduce `SceneControllerGraphHandle` for Facade Delegation

#### Slice Contract

Replace the record carrier and facade-facing helper bag with one internal graph
handle so the composition family has one explicit lifecycle/delegation owner
before store ownership moves.

#### Change

- add `SceneControllerGraphHandle` to
  `lib/src/interactive/internal/scene_controller_graph.dart`
- migrate facade-owned stream access, preview-delta access, public-side-effect
  delegation, disposed-state checks, and runtime access from top-level
  `sceneControllerGraph*` functions to handle members
- update `SceneController` to use `_graph: SceneControllerGraphHandle` and
  consume the new handle members instead of the top-level helper bag
- retire the superseded top-level helper functions that this slice migrates
- extend the architecture-boundary proof and targeted guardrail scenarios so
  future regressions catch a return to the helper-bag form

#### Behavioral Verification

- `flutter test test/interactive/core/scene_controller_interaction_contract_test.dart`
- `flutter test test/interactive/core/scene_controller_interactive_dispose_fail_fast_test.dart`

#### Structural Verification

- `flutter test test/interactive/core/scene_controller_architecture_boundary_test.dart`
- `dart run tool/run_tool_tests.dart test/tool/guardrails/guardrails_interactive_resolved_entrypoint_guard_tool_test.dart`
- `dart run tool/run_tool_tests.dart test/tool/guardrails/guardrails_interactive_api_tool_test.dart`

#### Fixtures Used

- `test/tool/support/guardrails_sandbox_support.dart`

#### Positive Scenarios

- `sceneControllerViewRuntimeOf(controller)` still returns the assembled
  `SceneViewRuntime`
- `controller.actions`, `controller.editTextRequests`, and
  `controller.previewDeltaResolver` continue to behave exactly as before while
  reading through the handle
- dispose fail-fast and internal-access behavior stay unchanged while the
  forwarding surface moves

#### Negative Scenarios

- the facade no longer depends on a top-level helper bag for streams,
  preview-delta access, or dispose-state checks
- `test/tool/support/guardrails_sandbox_support.dart`,
  `test/tool/guardrails/interactive_api/architecture_boundary/view_and_graph_cases.dart`,
  and
  `test/tool/guardrails/interactive_api/architecture_boundary/facade_and_boundary_cases.dart`
  cannot keep the retired helper-bag shape once the handle-based seam lands
- the composition family cannot regress to a record carrier plus delegated
  helper functions without failing the architecture-boundary proof

#### Closure Evidence

- `SceneControllerGraphHandle` becomes the one internal owner of the
  composition family's remaining forwarding surface, and the public facade no
  longer depends on top-level graph helper functions for that behavior

### Slice 2. [ ] Move Store Construction and Teardown Into the Composition Root

#### Slice Contract

Make `createSceneControllerGraph` the sole assembly owner by constructing the
store there and making `SceneControllerGraphHandle.dispose()` own the full
controller teardown order.

#### Change

- remove the facade-owned `_storeController` field from
  `lib/src/interactive/scene_controller.dart`
- change `SceneControllerGraphRequest` so it carries construction inputs rather
  than a prebuilt store and facade-derived committed-read closures
- construct `SceneStoreController` inside
  `createSceneControllerGraph` / `_assembleSceneControllerGraph`
- move coordinated teardown into `SceneControllerGraphHandle.dispose()` with
  the locked order:
  idempotence check after facade preflight,
  `SceneStoreController.dispose()`,
  runtime teardown,
  internal-access unregister
- add a neighboring guard test in
  `test/interactive/core/scene_controller_public_listener_contract_test.dart`
  that fails if a rejected `dispose()` during active write partially kills the
  public listener surface before the controller remains usable again
- update facade and graph guardrails so the facade can no longer own store
  construction or direct teardown fan-out

#### Behavioral Verification

- `flutter test test/interactive/core/scene_controller_interaction_contract_test.dart`
- `flutter test test/interactive/core/scene_controller_public_listener_contract_test.dart`
- `flutter test test/interactive/core/scene_controller_interactive_dispose_fail_fast_test.dart`

#### Structural Verification

- `flutter test test/interactive/core/scene_controller_architecture_boundary_test.dart`
- `dart run tool/run_tool_tests.dart test/tool/guardrails/guardrails_interactive_resolved_entrypoint_guard_tool_test.dart`
- `dart run tool/run_tool_tests.dart test/tool/guardrails/guardrails_interactive_api_tool_test.dart`

#### Fixtures Used

- `test/tool/support/guardrails_sandbox_support.dart`

#### Positive Scenarios

- `SceneController.dispose()` remains idempotent on the public facade
- `SceneController.dispose()` remains a facade-owned guarded block body while
  delegating teardown coordination to `SceneControllerGraphHandle`
- `dispose()` during active write still fails fast before any partial
  interactive teardown
- a rejected `dispose()` during active write leaves the public listener surface
  alive, so later successful writes still notify `SceneController` listeners
- successful dispose still unregisters internal access and deactivates the
  runtime-owned seams

#### Negative Scenarios

- `SceneController` can no longer construct `SceneStoreController` directly
- `SceneController` can no longer call
  `disposeSceneControllerGraph(...)` or
  `detachSceneControllerGraphInternalAccess(...)` directly
- `scene_controller_graph.dart` becomes the only interactive file allowed to
  construct the store for the public controller path
- `SceneController.dispose()` cannot become an unguarded one-line
  `_graph.dispose()` delegate and cannot require a resolved-entrypoint guard
  special-case to stay legal
- a failed `dispose()` must not partially call `super.dispose()` or otherwise
  kill the public notifier surface before the controller remains usable again

#### Closure Evidence

- the composition root becomes the sole assembly and teardown owner for the
  public controller path, while the facade keeps only its public delegation
  surface

### Slice 3. [ ] Sync Architecture and Target Map to the Locked Composition Form

#### Slice Contract

Refresh the checked-in architecture, target-family status, and committed
evidence so the repository describes the landed composition form instead of the
pre-cut split ownership.

#### Change

- regenerate
  `docs/target_architecture/evidence/composition_root_trace.json` and
  `docs/target_architecture/evidence/composition_root_trace.md`
  from the checked-in LSP trace so the committed evidence includes
  `SceneStoreController` construction under `createSceneControllerGraph`
- update `docs/target_architecture/overview.md` and
  `docs/target_architecture/families/composition_root_and_facade.md` from
  `locked, needs slimming` to the landed locked local form
- update `ARCHITECTURE.md` so `SceneController` no longer owns both a
  `SceneStoreController` and an assembled controller graph
- tighten `tool/invariant_registry.dart` wording if needed so the interactive
  architecture invariant points at the final composition proof surface
- update `PLAN.md` and this step document checkbox state when the step closes

#### Behavioral Verification

- `flutter test test/interactive/core/scene_controller_public_listener_contract_test.dart`
- `flutter test test/interactive/core/scene_controller_interaction_contract_test.dart`
- `flutter test test/interactive/core/scene_controller_interactive_dispose_fail_fast_test.dart`

#### Structural Verification

- `flutter test test/interactive/core/scene_controller_architecture_boundary_test.dart`
- `dart run tool/run_tool_tests.dart test/tool/target_architecture_map_tool_test.dart`
- `dart run tool/check_invariant_coverage.dart`

#### Fixtures Used

- `docs/target_architecture/evidence/composition_root_trace.json`
- `docs/target_architecture/evidence/composition_root_trace.md`

#### Positive Scenarios

- the committed target-map evidence now shows store construction under the
  composition root
- checked-in architecture text describes one thin public facade over one
  composition-root-owned lifecycle handle
- the composition family status is `locked` in the target map

#### Negative Scenarios

- no architecture or target-map text still describes `SceneController` as the
  owner of both the store and the assembled graph
- no target-map status still reports the composition family as
  `locked, needs slimming` after the code and evidence land

#### Closure Evidence

- source-of-truth docs, committed evidence, and invariant coverage all match
  the implemented composition cut

## 11. Final Verification

- `flutter test test/interactive/core/scene_controller_interaction_contract_test.dart`
- `flutter test test/interactive/core/scene_controller_public_listener_contract_test.dart`
- `flutter test test/interactive/core/scene_controller_interactive_dispose_fail_fast_test.dart`
- `flutter test test/interactive/core/scene_controller_architecture_boundary_test.dart`
- `dart run tool/run_tool_tests.dart test/tool/guardrails/guardrails_interactive_resolved_entrypoint_guard_tool_test.dart`
- `dart run tool/run_tool_tests.dart test/tool/guardrails/guardrails_interactive_api_tool_test.dart`
- `dart run tool/run_tool_tests.dart test/tool/target_architecture_map_tool_test.dart`
- `dart run tool/check_guardrails.dart`
- `dart run tool/check_invariant_coverage.dart`
- `printf '%s\n' 'PLAN.md' 'plan/step_17_complete_composition_root_ownership_and_facade_slimming.md' 'lib/src/interactive/scene_controller.dart' 'lib/src/interactive/internal/scene_controller_graph.dart' 'lib/src/interactive/internal/scene_controller_internal_access.dart' 'test/interactive/core/scene_controller_architecture_boundary_test.dart' 'test/interactive/core/scene_controller_interaction_contract_test.dart' 'test/interactive/core/scene_controller_public_listener_contract_test.dart' 'test/interactive/core/scene_controller_interactive_dispose_fail_fast_test.dart' 'test/tool/guardrails/guardrails_interactive_api_tool_test.dart' 'test/tool/guardrails/interactive_api/architecture_boundary/view_and_graph_cases.dart' 'test/tool/guardrails/interactive_api/architecture_boundary/facade_and_boundary_cases.dart' 'test/tool/support/guardrails_sandbox_support.dart' 'test/tool/target_architecture_map_tool_test.dart' 'tool/src/guardrails/rules/interactive/interactive_architecture_boundary_facade_rules.dart' 'tool/src/guardrails/rules/interactive/interactive_architecture_boundary_graph_rules.dart' 'tool/invariant_registry.dart' 'ARCHITECTURE.md' 'docs/target_architecture/overview.md' 'docs/target_architecture/families/composition_root_and_facade.md' 'docs/target_architecture/evidence/composition_root_trace.json' 'docs/target_architecture/evidence/composition_root_trace.md' | dart run tool/run_verification_preset.dart run --preset=required_code_change --changed-paths-file=-`

## 12. Acceptance Criteria

- `SceneController` no longer constructs `SceneStoreController` or coordinates
  teardown fan-out directly
- `createSceneControllerGraph` returns `SceneControllerGraphHandle`, constructs
  the store, and owns the full public controller lifecycle
- existing interaction-contract and dispose-fail-fast behavior remain green,
  including idempotent dispose, active-write fail-fast, public-listener
  survival after rejected dispose, and internal-access unregister after
  successful dispose
- `SceneController.dispose()` stays a facade-guarded public entrypoint while
  delegating teardown ownership to `SceneControllerGraphHandle`, with no direct
  facade teardown fan-out and no resolved-guard special-case
- architecture-boundary proof and interactive guardrails reject facade-owned
  store construction, direct teardown fan-out, and a reintroduced helper bag
- `ARCHITECTURE.md`, the composition target-family docs, and the committed
  `composition_root_trace` evidence all describe the landed locked local form
