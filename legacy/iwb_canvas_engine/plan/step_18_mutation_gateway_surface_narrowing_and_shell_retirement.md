# Change Contract

## 1. Change Mandate

Make the mutation gateway the direct interactive write surface by retiring the
routing-only mutation shells, wiring public owners and runtime-owned mutation
entrypoints straight to `SceneControllerMutationBoundary`, and keeping
replace-scene sequencing on the controller-owned committed mutation seam.

## 2. Change Boundary

### Included in the Change

- retire `SceneControllerSceneMutations`,
  `SceneControllerSelectionMutations`, and `InteractiveSelectionActions`
  from `lib/src/interactive/internal/**`
- wire `SceneControllerSceneOwner`, `SceneControllerSelectionOwner`, and the
  runtime-owned transform/delete/clear mutation entrypoints directly to
  `SceneControllerMutationBoundary`
- move active-gesture exclusivity preflight and
  `interruptForExternalMutation(...)` sequencing onto the direct caller that
  owns each mutation trigger once the routing-only shells are gone
- remove graph/runtime assembly that constructs the retired mutation shells
- update architecture proof, guardrails, sandbox fixtures, and target-map
  evidence so future regressions catch shell reintroduction or direct caller
  bypasses around `SceneControllerMutationBoundary`
- refresh `ARCHITECTURE.md`,
  `docs/target_architecture/families/mutation_gateway.md`,
  `docs/target_architecture/families/store_and_commit_path.md`,
  `docs/target_architecture/families/interaction_runtime.md`,
  `docs/target_architecture/overview.md`, and `tool/invariant_registry.dart`
  once the new local form lands
- update `PLAN.md` and this step document together when the step closes

### Not Included in the Change

- no store-family redesign or `SceneStoreController` slimming
- no split of `SceneControllerCommittedMutationAccess` or
  `SceneStoreControllerCommittedMutationAccess` beyond the minimum adoption
  edits required by the direct-routing cut
- no move of replace-scene sequencing out of
  `SceneControllerCommittedMutationAccess`
- no interaction-family compression beyond removing the retired mutation shells
- no render, view, pointer-session, or composition-root redesign
- no public API, supported import surface, schema/version, or barrel export
  change
- no phase-2 Change Contract from
  `docs/adr/0002_post_target_optimization_scope.md`

## 3. Surrounding Code Review

### Inspected Artifacts

- `PLAN.md` - the active plan index is fully closed through step 17, so this
  change must add a new dedicated step document instead of reopening an old
  contract
- `docs/adr/0001_target_engine_architecture.md` - the accepted target keeps
  one interaction-owned committed-write gateway and does not authorize moving
  committed writes into public capability owners
- `docs/adr/0002_post_target_optimization_scope.md` - phase 2 is gated on
  `mutation-gateway narrowing`, so the next step must finish that first-wave
  cut before interaction-family or store-family follow-up work
- `docs/target_architecture/overview.md` - the mutation gateway family is
  still `locked, needs slimming`, while composition and render seam are already
  `locked`
- `docs/target_architecture/families/mutation_gateway.md` - the family already
  locks `SceneControllerMutationBoundary` as the only interaction-owned
  committed-write bridge, but the current checked-in local form still keeps
  scene-side, selection-side, and interaction-side routing shells in front of
  it
- `docs/target_architecture/families/interaction_runtime.md` - current
  mechanical evidence still references
  `InteractiveSelectionActions.commitMoveSelection`, so shell retirement will
  require refreshed evidence before the target map can stay current
- `docs/target_architecture/families/store_and_commit_path.md` - current
  mechanical evidence for replace-scene still starts at
  `SceneControllerSceneMutations.replaceScene`, so public-shell retirement will
  leave stale store-family evidence unless this family doc and its evidence are
  refreshed in the same contract
- `lib/src/interactive/scene_controller_scene.dart` - each public scene
  mutation currently does public-side-effect guarding, then delegates into the
  internal `SceneControllerSceneMutations` shell
- `lib/src/interactive/scene_controller_selection.dart` - each public selection
  mutation currently does public-side-effect guarding, then delegates into the
  internal `SceneControllerSelectionMutations` shell
- `lib/src/interactive/internal/scene_controller_scene_mutations.dart` - this
  file is an 84-line routing shell that owns gesture-exclusivity preflight and
  `replaceScene` / `setCameraOffset` interrupt choreography, but every
  committed write still ends at `SceneControllerMutationBoundary`
- `lib/src/interactive/internal/scene_controller_selection_mutations.dart` -
  this file is a 52-line routing shell that only guards and forwards selection
  mutations into `SceneControllerMutationBoundary`
- `lib/src/interactive/internal/interactive_selection_actions.dart` - this
  file is a 34-line pure-forwarder shell over `SceneControllerMutationBoundary`
  for runtime-owned transform/delete/clear helpers
- `lib/src/interactive/internal/scene_controller_interaction_runtime.dart` -
  the runtime currently stores `selectionActions`, constructs it in
  `_createSelectionActions(...)`, and already wires move/draw callbacks
  directly to `SceneControllerMutationBoundary` through `_createInteractiveRuntime(...)`
- `lib/src/interactive/internal/scene_controller_graph.dart` - graph assembly
  still constructs `SceneControllerSceneMutations` and
  `SceneControllerSelectionMutations`, then injects those routing shells into
  the public capability owners
- `lib/src/interactive/internal/scene_controller_mutation_boundary.dart` -
  the gateway remains the authoritative interactive write owner; it already
  owns commit scheduling, action projection, move-commit request construction,
  and replace-scene callback forwarding to committed mutation access
- `lib/src/controller/scene_controller_committed_mutation_access.dart` - the
  controller-side adapter is broad, but it remains the owner of the sealed
  replace-scene sequencing path and is guarded separately by controller-side
  prepared-replace rules
- `tool/src/guardrails/rules/controller/prepared_replace_boundary_rules.dart` -
  controller guardrails lock the committed mutation access surface and the
  replace-scene boundary, so opportunistic store-family redesign here would mix
  owner families
- `tool/src/guardrails/rules/interactive/interactive_mutation_owner_guard_rules.dart` -
  the current machine-enforced owner policy still requires
  `SceneControllerSceneMutations` and `SceneControllerSelectionMutations` to
  exist as the canonical mutation-owner classes, so this step must migrate that
  proof to the direct public owners before the shell files can retire
- `tool/src/guardrails/rules/interactive/interactive_architecture_boundary_mutation_runtime_rules.dart` -
  the current runtime guardrail explicitly requires
  `_createSelectionActions(...)` and `InteractiveSelectionActions`, so the
  runtime slice must replace that structural proof with direct runtime-to-
  boundary checks in the same slice that deletes the shell
- `tool/src/guardrails/rules/interactive/interactive_architecture_boundary_mutation_shell_rules.dart` -
  the current architecture-boundary rule file is dedicated to proving the three
  routing shells stay thin wrappers, which means its responsibility must be
  retained through Slice 1 for the still-live public shells and retired only
  after Slice 2 deletes the last remaining public shell files
- `tool/src/guardrails/rules/interactive/mutation_boundary_rules.dart` -
  the interactive guardrail rule aggregates mutation-owner, runtime-boundary,
  shell-boundary, and committed-read callback checks under
  `INV-ENG-INTERACTIVE-MUTATION-BOUNDARY`, so this contract must update the
  actual contributing rule surfaces rather than relying on prose-only doc
  changes
- `test/controller/core/scene_controller_committed_mutation_access_test.dart` -
  this test already locks the adapter as a thin committed mutation bridge and
  proves `replaceScene(...)` ownership stays on committed mutation access
- `test/interactive/core/scene_controller_mutation_boundary_test.dart` - this
  suite locks boundary-owned scene/selection/draw writes, action projection,
  move-commit behavior, and replace-scene side effects
- `test/interactive/core/scene_controller_interactive_single_pointer_policy_test.dart`
  - this suite locks active-gesture exclusivity across public scene and
  selection mutations, including the deny-listed mutation set that currently
  flows through the routing shells
- `test/interactive/core/scene_controller_interactive_basics_test.dart` - this
  suite locks `setCameraOffset(...)` and `replaceScene(...)` special preflight
  behavior and the no-op cases that must survive shell retirement
- `test/interactive/core/scene_controller_interactive_actions_effects_test.dart`
  - this suite locks transform/delete/clear action effects that currently flow
  through `InteractiveSelectionActions`
- `test/interactive/core/scene_controller_architecture_boundary_test.dart` -
  architecture proof currently locks the high-level split, but it does not yet
  forbid the three routing shells as retired residual seams
- `test/tool/guardrails/guardrails_interactive_api_tool_test.dart` plus
  `test/tool/guardrails/interactive_api/**` - negative structural scenarios
  currently require the routing shells and will need direct-route successor
  coverage before the shells can be deleted safely
- `test/tool/support/guardrails_sandbox_support.dart` - shared interactive
  sandbox fixtures still generate the routing-shell topology, so fixture
  support must migrate before the production files can retire
- `tool/invariant_registry.dart` - the mutation boundary invariant still says
  scene/selection shells stay routing-only, so invariant wording must change
  when those shells are retired
- `tool/invariant_registry.dart` - `INV-ENG-INTERACTIVE-PUBLIC-MUTATION-EXCLUSIVITY`,
  `INV-ENG-INTERACTIVE-ARCHITECTURE-BOUNDARY`, and
  `INV-ENG-INTERACTIVE-MUTATION-BOUNDARY` already name the three behavior /
  structure constraints this step must preserve, so the contract can pin its
  proof obligations to existing machine-readable invariant ids instead of
  inventing a new enforcement surface
- `docs/target_architecture/evidence/replace_scene_write_flow.json` and
  `docs/target_architecture/evidence/replace_scene_write_flow.md` - current
  checked-in replace-scene evidence starts at the shell that Slice 2 deletes,
  so these artifacts must move to the direct public-owner route before the
  mutation-family and store-family docs can remain current
- `dart run tool/lsp_trace_flow.dart lib/src/interactive/scene_controller_scene.dart SceneControllerSceneOwner.addNode --depth=4`
  - confirms the current public scene write path is
  `SceneControllerSceneOwner -> SceneControllerSceneMutations -> SceneControllerMutationBoundary -> SceneControllerCommittedMutationAccess`
- `dart run tool/lsp_trace_flow.dart lib/src/interactive/scene_controller_selection.dart SceneControllerSelectionOwner.setSelection --depth=4`
  - confirms the current public selection write path is
  `SceneControllerSelectionOwner -> SceneControllerSelectionMutations -> SceneControllerMutationBoundary -> SceneControllerCommittedMutationAccess`
- `dart run tool/lsp_trace_symbol.dart lib/src/interactive/internal/scene_controller_interaction_runtime.dart _createInteractiveRuntime --direction=outgoing --depth=3 --json`
  - confirms the runtime already wires move/draw callbacks directly to
  `SceneControllerMutationBoundary`, so shell retirement can keep the dominant
  direct-boundary wiring form inside the runtime path
- `dart run tool/lsp_find_thin_wrappers.dart lib/src/interactive --classification=pure-forwarder`
  - reports `InteractiveSelectionActions` as a pure forwarder and confirms
  local wrapper debt still exists in the checked-in interaction family
- `dcm calculate-metrics lib/src/interactive/internal/scene_controller_mutation_boundary.dart lib/src/controller/scene_controller_committed_mutation_access.dart lib/src/interactive/internal/scene_controller_scene_mutations.dart lib/src/interactive/internal/scene_controller_selection_mutations.dart lib/src/interactive/internal/interactive_selection_actions.dart`
  - confirms the hot spot is not hidden complexity in the routing shells; the
  shells are tiny routing files, while the stable owners remain
  `SceneControllerMutationBoundary` and the controller-side adapter

### Current Entry Path

- public scene writes:
  `SceneController.scene.*` ->
  `SceneControllerSceneOwner.*` ->
  `SceneControllerSceneMutations.*` ->
  `SceneControllerMutationBoundary.*` ->
  `SceneControllerCommittedMutationAccess.*`
- public selection writes:
  `SceneController.selection.*` ->
  `SceneControllerSelectionOwner.*` ->
  `SceneControllerSelectionMutations.*` ->
  `SceneControllerMutationBoundary.*` ->
  `SceneControllerCommittedMutationAccess.*`
- runtime-owned transform/delete/clear helpers:
  `SceneControllerInteractionRuntimeMutationApi.*` ->
  `InteractiveSelectionActions.*` ->
  `SceneControllerMutationBoundary.*`
- move/draw runtime callbacks:
  `_createInteractiveRuntime(...)` ->
  `InteractiveRuntimeCallbacks.*` ->
  `SceneControllerMutationBoundary.*`

### Current Owner

- interactive mutation-family ownership is currently split between:
  `SceneControllerSceneOwner`,
  `SceneControllerSelectionOwner`,
  `SceneControllerSceneMutations`,
  `SceneControllerSelectionMutations`,
  `InteractiveSelectionActions`,
  `SceneControllerInteractionRuntime`, and
  `SceneControllerMutationBoundary`
- controller-side committed mutation ownership remains in
  `SceneControllerCommittedMutationAccess` /
  `SceneStoreControllerCommittedMutationAccess`

### Adjacent Abstractions

- `lib/src/interactive/internal/scene_controller_graph.dart` - the assembly
  owner that currently decides where public owners, runtime callbacks, and the
  mutation boundary meet
- `lib/src/interactive/internal/scene_controller_interaction_runtime.dart` -
  runtime bridge that already owns move/draw callback wiring and should remain
  the owner of runtime-triggered mutation entrypoints
- `lib/src/interactive/scene_controller_scene.dart` and
  `lib/src/interactive/scene_controller_selection.dart` - public capability
  owners adjacent to the retired shells and therefore the correct direct-call
  successors
- `lib/src/interactive/interaction_eligibility_policy.dart` - shared pure
  selection/move eligibility helper that the mutation boundary already uses and
  must stay outside controller/store ownership
- `lib/src/controller/scene_controller_committed_mutation_access.dart` -
  adjacent controller-owned seam that must keep replace-scene sequencing and
  must not become the next architecture cut opportunistically

### Existing Tests

- `test/interactive/core/scene_controller_mutation_boundary_test.dart` -
  boundary-owned behavioral proof for scene/selection/draw writes and
  replace-scene side effects
- `test/interactive/core/scene_controller_interactive_single_pointer_policy_test.dart`
  - active-gesture exclusivity proof for public scene/selection entrypoints
- `test/interactive/core/scene_controller_interactive_basics_test.dart` -
  public scene mutation characterization, including `setCameraOffset(...)` and
  `replaceScene(...)` special cases
- `test/interactive/core/scene_controller_interactive_actions_effects_test.dart`
  - runtime-owned transform/delete/clear action characterization
- `test/interactive/core/scene_controller_interaction_contract_test.dart` -
  interaction/runtime contract proof around internal access and request seams
- `test/controller/core/scene_controller_committed_mutation_access_test.dart` -
  controller-side adapter characterization and replace-scene owner proof
- `test/interactive/core/scene_controller_architecture_boundary_test.dart` -
  structural split proof for the interactive runtime center
- `test/tool/guardrails/guardrails_interactive_api_tool_test.dart` -
  guardrail regression suite for interactive structural drift
- `test/tool/target_architecture_map_tool_test.dart` - target-map structure and
  family-status proof
- `test/tool/public_capability_owner_contract_tool_test.dart` - public barrel
  consumer proof that capability owners remain usable after internal rewiring

### Analogous Implementation Path

- `lib/src/interactive/internal/scene_controller_interaction_runtime.dart` -
  `_createInteractiveRuntime(...)` already wires move/draw callbacks directly
  to `SceneControllerMutationBoundary`, so it is the closest checked-in
  precedent for this contract's successor seam: direct caller -> boundary
  without an extra routing shell

### Governing Repository Rules

- `AGENTS.md` - fix the root owner boundary instead of leaving duplicated logic
  in downstream call sites
- `AGENTS.md` - use `$change-contract` when adding a new step to `PLAN.md`
- `AGENTS.md` - important stable constraints must become repository-local tests
  or tooling, not chat-only guidance
- `docs/adr/0001_target_engine_architecture.md` - committed writes from
  interaction paths must still pass through one mutation gateway
- `docs/adr/0002_post_target_optimization_scope.md` - no phase-2 contract
  before `mutation-gateway narrowing` completes
- `tool/invariant_registry.dart` - the mutation boundary invariant and the
  public mutation exclusivity invariant govern this area
- repository verification rules - final verification must use
  `dart run tool/run_verification_preset.dart run --preset=required_code_change`
  rather than plain `dart test`

### Rejected Misleading Local Patterns

- split `SceneControllerCommittedMutationAccess` now as the main goal - wrong
  owner family because the controller-side adapter is guarded by prepared
  replace-scene rules and belongs to the store family follow-up, not this
  interactive-side narrowing cut
- move committed writes into `SceneControllerSceneOwner`,
  `SceneControllerSelectionOwner`, or `SceneControllerInteractionRuntime` -
  wrong owner because `SceneControllerMutationBoundary` would stop being the
  sole interaction-owned committed-write bridge
- keep the three routing shells and only rename or regroup them - wrong seam
  because the extra routing layer would remain in front of the canonical
  boundary after the target cut claims it was narrowed
- move `replaceScene(...)` sequencing into the interactive boundary - wrong
  owner because controller-side prepared replace-scene rules and tests already
  lock that sequencing in committed mutation access
- route runtime-owned selection/draw writes directly to
  `SceneStoreController`, `SceneCommands`, `DrawCommands`, or `SceneWriter` -
  wrong seam because it bypasses the mutation boundary and weakens the checked
  interactive architecture invariant
- invent a new mutation service bag or second gateway root - wrong level
  because ADR 0001 already accepts one gateway owner, not another top-level
  owner split

## 4. Architecture

### 4A. Locked Architectural Form

#### Problem Ownership Level

- the interactive-side mutation gateway surface between direct mutation
  callers and the canonical committed-write boundary

#### Selected Architectural Form

- keep `SceneControllerMutationBoundary` as the only interaction-owned owner
  that performs committed scene/selection/draw writes and write-side action
  projection
- retire `SceneControllerSceneMutations`,
  `SceneControllerSelectionMutations`, and `InteractiveSelectionActions`
  instead of replacing them with successor routing shells
- make the direct callers depend on the boundary itself:
  - `SceneControllerSceneOwner` performs public-side-effect guarding and the
    direct public scene-entry preflight before calling
    `SceneControllerMutationBoundary`
  - `SceneControllerSelectionOwner` performs public-side-effect guarding and the
    direct public selection-entry preflight before calling
    `SceneControllerMutationBoundary`
  - `SceneControllerInteractionRuntimeMutationApi` performs runtime-owned
    transform/delete/clear routing directly to
    `SceneControllerMutationBoundary`
- keep `SceneControllerInteractionRuntime` as the owner of runtime-driven
  mutation entrypoints and callback wiring; it no longer owns a
  `selectionActions` intermediary
- keep `SceneControllerCommittedMutationAccess` /
  `SceneStoreControllerCommittedMutationAccess` as the controller-owned bridge
  into store/write-kernel behavior, including replace-scene sequencing

#### Owning Layer or Module

- direct interactive callers:
  `lib/src/interactive/scene_controller_scene.dart`,
  `lib/src/interactive/scene_controller_selection.dart`,
  `lib/src/interactive/internal/scene_controller_interaction_runtime.dart`, and
  `lib/src/interactive/internal/scene_controller_graph.dart`
- canonical interactive write owner:
  `lib/src/interactive/internal/scene_controller_mutation_boundary.dart`
- controller-side committed mutation seam that remains in place:
  `lib/src/controller/scene_controller_committed_mutation_access.dart`

#### Dependency Direction

- public scene/selection owners ->
  `SceneControllerMutationBoundary` ->
  `SceneControllerCommittedMutationAccess` ->
  `SceneStoreController`
- runtime-owned transform/delete/clear entrypoints ->
  `SceneControllerMutationBoundary` ->
  `SceneControllerCommittedMutationAccess`
- `createSceneControllerGraph(...)` and
  `createSceneControllerInteractionRuntime(...)` assemble those direct routes;
  they do not reconstruct a successor shell layer

#### State and Data Ownership

- `SceneControllerMutationBoundary` owns interactive committed-write execution,
  commit scheduling, clear/delete action projection, and move-commit request
  construction
- direct callers own only caller-local policy:
  public-side-effect guarding,
  active-gesture exclusivity preflight, and
  `interruptForExternalMutation(...)` sequencing where that trigger already
  belongs to the caller
- `SceneControllerCommittedMutationAccess` owns controller-side replace-scene
  sequencing and store/write-kernel bridging; that state does not move into the
  interactive layer in this step

#### Entry and Exit Boundaries

- public entry boundary:
  `SceneControllerSceneOwner.*` and `SceneControllerSelectionOwner.*`
- runtime entry boundary:
  `SceneControllerInteractionRuntimeMutationApi.*` and
  `_createInteractiveRuntime(...)` callback wiring
- committed-write exit boundary:
  `SceneControllerMutationBoundary.*` ->
  `SceneControllerCommittedMutationAccess.*`
- prepared replace-scene exit boundary:
  `SceneControllerCommittedMutationAccess.replaceScene(...)`

#### Permitted Extension Seam

- future interactive mutation entrypoints may call
  `SceneControllerMutationBoundary` directly only when the caller owns the
  trigger and the required preflight locally
- future controller/store follow-up work may revisit
  `SceneControllerCommittedMutationAccess`, but only under a separate
  store-family contract after this step closes
- no new intermediate routing class may be introduced between direct callers
  and `SceneControllerMutationBoundary`

#### Rejected Alternatives

- keep the internal mutation shells as the long-term local form - rejected
  because the direct caller already owns the trigger-specific preflight and the
  extra shell layer only obscures the canonical gateway
- move mutation-boundary logic into the public owners or runtime bridge -
  rejected because that would create multiple interaction-owned committed-write
  owners
- split controller-side mutation access in the same step - rejected because it
  crosses into the controller/store family and conflicts with ADR 0002 gating

#### Why This Level Is Correct

- the checked-in probes show the root remaining drift is on the interactive
  side of the gateway surface, not in the top-level composition cut that step
  17 already closed
- the controller-side adapter is already guarded by dedicated replace-scene
  rules and tests, so re-cutting it here would mix families and broaden the
  change surface without fixing the local wrapper debt first
- the direct-caller form is already the dominant local shape in the runtime
  path because `_createInteractiveRuntime(...)` wires move/draw callbacks
  straight to `SceneControllerMutationBoundary`

## 5. Locked Decisions

1. `SceneControllerSceneMutations`,
   `SceneControllerSelectionMutations`, and `InteractiveSelectionActions`
   are retired in this step; there is no successor routing-shell owner.
2. `SceneControllerSceneOwner` and `SceneControllerSelectionOwner` keep
   public-side-effect purity guarding and become the direct owners of public
   mutation preflight before they call `SceneControllerMutationBoundary`.
3. `SceneControllerInteractionRuntimeMutationApi` keeps runtime-owned
   clear/transform/delete helper methods, but those methods call
   `SceneControllerMutationBoundary` directly and no longer bounce through
   `InteractiveSelectionActions`.
4. `createSceneControllerGraph(...)` and
   `createSceneControllerInteractionRuntime(...)` stop constructing the retired
   shells and instead wire direct owner-to-boundary dependencies.
5. `SceneControllerCommittedMutationAccess` stays in place for this step; any
   remaining controller-side slimming is explicitly deferred to a later
   store-family follow-up.
6. `lib/src/controller/scene_controller_committed_mutation_access.dart` is not
   an intended edit target for this step; if implementation uncovers a required
   change there beyond compile-through adoption, the contract must be revised
   before execution continues.
7. `replaceScene(...)` remains the special case where the direct caller owns
   interrupt timing, but committed mutation access still owns prepared replace
   sequencing.
8. The mutation-gateway family moves from `locked, needs slimming` to `locked`
   only after the retired shells are gone, the direct routes are mechanically
   proven, and the target-map evidence no longer points at deleted files.

## 6. Result Requirements

1. No routing-only mutation shell remains under `lib/src/interactive/internal/`
   for public scene writes, public selection writes, or runtime-owned
   transform/delete/clear writes.
2. Every interactive committed scene/selection/draw write still crosses
   `SceneControllerMutationBoundary` before it reaches controller-owned
   committed mutation access.
3. Public scene and selection behavior remains unchanged, including
   public-side-effect guarding and active-gesture exclusivity.
4. `setCameraOffset(...)` and `replaceScene(...)` keep their current special
   preflight semantics after the shell layer is removed.
5. `replaceScene(...)` sequencing remains controller-owned and does not move out
   of committed mutation access.
6. Architecture tests, guardrails, and target-map proof fail if a deleted shell
   returns or if direct callers bypass `SceneControllerMutationBoundary`.

## 7. Execution Order and Gates

### Required Order

- first lock the runtime-side direct-route successor form by retiring
  `InteractiveSelectionActions` and updating the structural proof surface that
  currently names it
- then retire the public scene and selection mutation shells so public owners
  become the only remaining direct callers above the boundary
- then retire the now-obsolete shell-specific guardrail file only after the
  runtime shell is gone and the public scene/selection shells are also gone
- then refresh invariant wording, architecture docs, target-map docs, and
  all affected evidence artifacts, including replace-scene store-family proof,
  after the production routes and guardrails have settled
- reserve the broad `required_code_change` preset for the final gate after the
  retired shell files, guardrails, fixtures, docs, and evidence all agree on
  the same local form

### Successor Seam and Retirement Gates

- successor seam:
  direct caller routes in
  `lib/src/interactive/scene_controller_scene.dart`,
  `lib/src/interactive/scene_controller_selection.dart`, and
  `lib/src/interactive/internal/scene_controller_interaction_runtime.dart`
  over `SceneControllerMutationBoundary`
- shell retirement gate:
  all production references, sandbox fixtures, architecture-boundary guardrail
  cases, mutation-owner guard cases, and architecture tests must stop naming
  `SceneControllerSceneMutations`,
  `SceneControllerSelectionMutations`, and
  `InteractiveSelectionActions` before the files are deleted and listed as
  retired residual seams
- target-map update gate:
  `docs/target_architecture/families/mutation_gateway.md`,
  `docs/target_architecture/families/store_and_commit_path.md`,
  `docs/target_architecture/families/interaction_runtime.md`, and
  `docs/target_architecture/overview.md` may move to the new local form only
  after committed evidence artifacts point at live direct routes instead of the
  deleted shell files
- replace-scene gate:
  `test/controller/core/scene_controller_committed_mutation_access_test.dart`
  and controller prepared-replace guardrails must stay green before any
  mutation-family doc claims the narrowing cut is complete

### Deferred Broad Verification

- `dart run tool/run_verification_preset.dart run --preset=required_code_change`
  is deferred to the final gate because it is the broadest integrated proof of
  the direct-route form plus retired-shell docs and guardrails

## 8. File Map

### Implementation Files

- `PLAN.md`
- `plan/step_18_mutation_gateway_surface_narrowing_and_shell_retirement.md`
- `lib/src/interactive/scene_controller_scene.dart`
- `lib/src/interactive/scene_controller_selection.dart`
- `lib/src/interactive/internal/scene_controller_interaction_runtime.dart`
- `lib/src/interactive/internal/scene_controller_graph.dart`
- `lib/src/interactive/internal/scene_controller_mutation_boundary.dart`
- retired:
  `lib/src/interactive/internal/scene_controller_scene_mutations.dart`
- retired:
  `lib/src/interactive/internal/scene_controller_selection_mutations.dart`
- retired:
  `lib/src/interactive/internal/interactive_selection_actions.dart`
- `ARCHITECTURE.md`
- `docs/target_architecture/overview.md`
- `docs/target_architecture/families/mutation_gateway.md`
- `docs/target_architecture/families/store_and_commit_path.md`
- `docs/target_architecture/families/interaction_runtime.md`
- `docs/target_architecture/evidence/add_node_write_flow.json`
- `docs/target_architecture/evidence/add_node_write_flow.md`
- `docs/target_architecture/evidence/commit_move_selection_flow.json`
- `docs/target_architecture/evidence/commit_move_selection_flow.md`
- `docs/target_architecture/evidence/replace_scene_write_flow.json`
- `docs/target_architecture/evidence/replace_scene_write_flow.md`
- `tool/invariant_registry.dart`
- `tool/src/guardrails/rules/interactive/mutation_boundary_rules.dart`
- `tool/src/guardrails/rules/interactive/interactive_architecture_boundary_rules.dart`
- `tool/src/guardrails/rules/interactive/interactive_architecture_boundary_mutation_rules.dart`
- `tool/src/guardrails/rules/interactive/interactive_architecture_boundary_mutation_runtime_rules.dart`
- `tool/src/guardrails/rules/interactive/interactive_mutation_owner_guard_rules.dart`
- `tool/src/guardrails/rules/interactive/committed_read_callback_rules.dart`
- `tool/src/guardrails/rules/interactive/interactive_architecture_boundary_mutation_shell_rules.dart`

### Test Files

- `test/interactive/core/scene_controller_mutation_boundary_test.dart`
- `test/interactive/core/scene_controller_interaction_contract_test.dart`
- `test/interactive/core/scene_controller_interactive_actions_effects_test.dart`
- `test/interactive/core/scene_controller_interactive_basics_test.dart`
- `test/interactive/core/scene_controller_interactive_single_pointer_policy_test.dart`
- `test/interactive/core/scene_controller_architecture_boundary_test.dart`
- `test/controller/core/scene_controller_committed_mutation_access_test.dart`
- `test/tool/guardrails/guardrails_interactive_api_tool_test.dart`
- `test/tool/guardrails/interactive_api/architecture_boundary/facade_and_boundary_cases.dart`
- `test/tool/guardrails/interactive_api/architecture_boundary/runtime_session_contract_cases.dart`
- `test/tool/guardrails/interactive_api/architecture_boundary/view_and_graph_cases.dart`
- `test/tool/guardrails/interactive_api/architecture_boundary/pointer_host_and_public_shell_cases.dart`
- `test/tool/guardrails/interactive_api/mutation_boundary/owner_guard_cases.dart`
- `test/tool/public_capability_owner_contract_tool_test.dart`
- `test/tool/target_architecture_map_tool_test.dart`

### Fixtures and Supporting Data

- `test/tool/support/guardrails_sandbox_support.dart`

### Registry, Inventory, and Workflow Files

- `tool/invariant_registry.dart`
- `docs/target_architecture/evidence/add_node_write_flow.json`
- `docs/target_architecture/evidence/add_node_write_flow.md`
- `docs/target_architecture/evidence/commit_move_selection_flow.json`
- `docs/target_architecture/evidence/commit_move_selection_flow.md`
- `docs/target_architecture/evidence/replace_scene_write_flow.json`
- `docs/target_architecture/evidence/replace_scene_write_flow.md`

### Analysis Area

- `lib/src/interactive/**` mutation-family callers and boundary
- `tool/src/guardrails/rules/interactive/**`
- `test/tool/guardrails/interactive_api/**`
- `docs/target_architecture/**`

## 9. Implementation Rules

### Protected Invariants

- `INV-ENG-INTERACTIVE-MUTATION-BOUNDARY`
- `INV-ENG-INTERACTIVE-PUBLIC-MUTATION-EXCLUSIVITY`
- `INV-ENG-INTERACTIVE-ARCHITECTURE-BOUNDARY`
- controller prepared replace-scene boundary hermeticity for
  `SceneControllerCommittedMutationAccess.replaceScene(...)`

### Required Proof

- behavioral proof:
  `flutter test test/interactive/core/scene_controller_interactive_actions_effects_test.dart`,
  `flutter test test/interactive/core/scene_controller_interactive_single_pointer_policy_test.dart`,
  `flutter test test/interactive/core/scene_controller_interactive_basics_test.dart`,
  `flutter test test/interactive/core/scene_controller_interaction_contract_test.dart`,
  `flutter test test/interactive/core/scene_controller_mutation_boundary_test.dart`,
  and
  `flutter test test/controller/core/scene_controller_committed_mutation_access_test.dart`
- structural proof:
  `flutter test test/interactive/core/scene_controller_architecture_boundary_test.dart`,
  `dart run tool/run_tool_tests.dart test/tool/guardrails/guardrails_interactive_api_tool_test.dart`,
  and
  `dart run tool/run_tool_tests.dart test/tool/target_architecture_map_tool_test.dart`
- for refactors:
  existing locking tests named above must stay green or gain the minimum new
  characterization/guard cases before structural edits broaden the changed
  surface

### Allowed Change Surface

- direct-caller rewiring in the public scene/selection owners and runtime
  mutation API
- graph/runtime assembly changes required to stop constructing the retired
  shells
- minimum boundary-owner helper adjustments required to keep the direct routes
  legible without changing owner family
- direct-route guardrail migrations inside
  `interactive_mutation_owner_guard_rules.dart`,
  `committed_read_callback_rules.dart`,
  `interactive_architecture_boundary_mutation_runtime_rules.dart`, and
  `interactive_architecture_boundary_mutation_rules.dart` that replace shell-
  existence / thin-wrapper checks with direct-caller-to-boundary checks
- deferred retirement of
  `interactive_architecture_boundary_mutation_shell_rules.dart` only after all
  three shell files are gone and successor structural proof is active for the
  direct runtime and public-owner routes
- guardrails, sandbox fixtures, architecture tests, invariants, docs, and
  evidence required to lock the retired-shell form mechanically

### Forbidden Moves

- do not route any public or runtime mutation directly to
  `SceneStoreController`, `SceneCommands`, `DrawCommands`, `SceneWriter`, or
  `SceneControllerCommitRuntime`
- do not create a successor mutation shell, helper bag, or second gateway root
- do not move replace-scene sequencing out of
  `SceneControllerCommittedMutationAccess`
- do not broaden `committed_read_callback_rules.dart` beyond the minimum
  mutation-owner proof migration needed to replace
  `SceneControllerSceneMutations` and `SceneControllerSelectionMutations` with
  the surviving direct public owners
- do not classify controller-side adapter/store work as part of this step
- do not change public API, exports, schema/version, or app-visible behavior
  intentionally

## 10. Vertical Slices

### Slice 1. [x] Retire Runtime Selection Routing Shell

#### Slice Contract

`SceneControllerInteractionRuntimeMutationApi` becomes the direct owner of the
runtime-side transform/delete/clear route into `SceneControllerMutationBoundary`
and no longer assembles or stores `InteractiveSelectionActions`.

#### Change

- delete `lib/src/interactive/internal/interactive_selection_actions.dart`
- remove `selectionActions` from
  `SceneControllerInteractionRuntime` and from
  `createSceneControllerInteractionRuntime(...)`
- remove `_createSelectionActions(...)`
- make runtime-owned helpers such as `clearSceneSelectionState(...)`,
  `rotateSelection(...)`, `flipSelection*`, and `deleteSelection(...)` call
  `SceneControllerMutationBoundary` directly
- update architecture-boundary guardrails and sandbox fixtures so they reject a
  reintroduced `InteractiveSelectionActions` shell and instead require the
  direct runtime-to-boundary route

#### Behavioral Verification

- `flutter test test/interactive/core/scene_controller_interactive_actions_effects_test.dart`
- `flutter test test/interactive/core/scene_controller_interaction_contract_test.dart`

#### Structural Verification

- `flutter test test/interactive/core/scene_controller_architecture_boundary_test.dart`
- `dart run tool/run_tool_tests.dart test/tool/guardrails/guardrails_interactive_api_tool_test.dart`

#### Fixtures Used

- `test/tool/support/guardrails_sandbox_support.dart`
- `test/tool/guardrails/interactive_api/architecture_boundary/runtime_session_contract_cases.dart`
- `test/tool/guardrails/interactive_api/architecture_boundary/pointer_host_and_public_shell_cases.dart`

#### Positive Scenarios

- runtime-owned clear/transform/delete helpers still emit the same committed
  actions and listener effects
- internal interaction/runtime contract behavior remains unchanged after the
  shell is removed

#### Negative Scenarios

- guardrails fail if `SceneControllerInteractionRuntime` reconstructs
  `InteractiveSelectionActions`
- guardrails fail if runtime-owned mutation helpers bypass
  `SceneControllerMutationBoundary`
- guardrails still fail if `SceneControllerSceneMutations` or
  `SceneControllerSelectionMutations` stop being thin public shells before
  Slice 2 retires them

#### Closure Evidence

- `lib/src/interactive/internal/scene_controller_interaction_runtime.dart`
  no longer contains `selectionActions` or `_createSelectionActions(...)`
- `lib/src/interactive/internal/interactive_selection_actions.dart` is absent
- `tool/src/guardrails/rules/interactive/interactive_architecture_boundary_mutation_shell_rules.dart`
  still exists and still protects the two surviving public shell files

### Slice 2. [x] Retire Public Scene And Selection Mutation Shells

#### Slice Contract

`SceneControllerSceneOwner` and `SceneControllerSelectionOwner` become the only
remaining public mutation callers above `SceneControllerMutationBoundary`,
owning their direct preflight and interrupt sequencing without the internal
scene/selection mutation shells.

#### Change

- delete `lib/src/interactive/internal/scene_controller_scene_mutations.dart`
- delete `lib/src/interactive/internal/scene_controller_selection_mutations.dart`
- change `SceneControllerSceneOwner` to depend directly on
  `SceneControllerInteractionRuntime` and `SceneControllerMutationBoundary`
  rather than an intermediate shell
- change `SceneControllerSelectionOwner` to depend directly on
  `SceneControllerInteractionRuntime` and `SceneControllerMutationBoundary`
  rather than an intermediate shell
- move the existing gesture-exclusivity preflight and the
  `setCameraOffset(...)` / `replaceScene(...)` interrupt choreography onto the
  direct public owners
- update graph assembly, mutation-owner guard rules, and sandbox fixtures so
  the public owners become the mechanically enforced direct callers
- migrate `mutationOwnerGuardSpecs` in
  `tool/src/guardrails/rules/interactive/committed_read_callback_rules.dart`
  from the retired shell classes to the surviving direct public owners in the
  same slice that deletes the shell files
- retire
  `tool/src/guardrails/rules/interactive/interactive_architecture_boundary_mutation_shell_rules.dart`
  only in this slice, after the public shell checks have been replaced by
  successor direct-owner proof in
  `committed_read_callback_rules.dart`,
  `interactive_mutation_owner_guard_rules.dart` and
  `interactive_architecture_boundary_mutation_rules.dart`

#### Behavioral Verification

- `flutter test test/interactive/core/scene_controller_interactive_single_pointer_policy_test.dart`
- `flutter test test/interactive/core/scene_controller_interactive_basics_test.dart`
- `dart run tool/run_tool_tests.dart test/tool/public_capability_owner_contract_tool_test.dart`

#### Structural Verification

- `flutter test test/interactive/core/scene_controller_architecture_boundary_test.dart`
- `dart run tool/run_tool_tests.dart test/tool/guardrails/guardrails_interactive_api_tool_test.dart`

#### Fixtures Used

- `test/tool/support/guardrails_sandbox_support.dart`
- `test/tool/guardrails/interactive_api/architecture_boundary/facade_and_boundary_cases.dart`
- `test/tool/guardrails/interactive_api/architecture_boundary/view_and_graph_cases.dart`
- `test/tool/guardrails/interactive_api/mutation_boundary/owner_guard_cases.dart`

#### Positive Scenarios

- public scene/selection mutations still reject active gestures and still work
  after the gesture ends
- `setCameraOffset(...)` and `replaceScene(...)` preserve their current special
  preflight semantics
- public barrel consumers still use `controller.scene` and
  `controller.selection` normally

#### Negative Scenarios

- guardrails fail if public owners call controller/store write APIs directly
- guardrails fail if retired scene/selection mutation shell files return
- guardrails fail if the shell-rule file is deleted before direct public-owner
  successor proof is active
- guardrails fail if `mutationOwnerGuardSpecs` still point at the retired shell
  files after Slice 2

#### Closure Evidence

- graph assembly no longer constructs
  `SceneControllerSceneMutations` or `SceneControllerSelectionMutations`
- direct public owner routes in
  `scene_controller_scene.dart` and `scene_controller_selection.dart`
  terminate at `SceneControllerMutationBoundary`
- `tool/src/guardrails/rules/interactive/committed_read_callback_rules.dart`
  points `mutationOwnerGuardSpecs` at the surviving direct public owners rather
  than the retired shell files
- `tool/src/guardrails/rules/interactive/interactive_architecture_boundary_mutation_shell_rules.dart`
  is absent only after its public-shell checks have been replaced by direct
  public-owner proof

### Slice 3. [x] Refresh Mutation-Family Proof And Mark The Family Locked

#### Slice Contract

The checked-in architecture docs, target map, invariant wording, and committed
evidence reflect the retired-shell direct-route form so the mutation gateway
family can move from `locked, needs slimming` to `locked` without stale owner
claims.

#### Change

- update `ARCHITECTURE.md` so the current-state architecture names the direct
  caller routes and no longer describes the retired shell layer
- update `docs/target_architecture/overview.md` and
  `docs/target_architecture/families/mutation_gateway.md` to the locked
  direct-route local form
- update `docs/target_architecture/families/store_and_commit_path.md` so its
  replace-scene evidence starts at the surviving direct public owner rather
  than the retired shell
- update `docs/target_architecture/families/interaction_runtime.md` so its
  mechanical evidence no longer points at the deleted shell file
- regenerate:
  `docs/target_architecture/evidence/add_node_write_flow.json`,
  `docs/target_architecture/evidence/add_node_write_flow.md`,
  `docs/target_architecture/evidence/commit_move_selection_flow.json`, and
  `docs/target_architecture/evidence/commit_move_selection_flow.md`,
  `docs/target_architecture/evidence/replace_scene_write_flow.json`, and
  `docs/target_architecture/evidence/replace_scene_write_flow.md`
  using checked-in probes only
- update `tool/invariant_registry.dart` and
  `test/tool/target_architecture_map_tool_test.dart` to the landed local form

#### Behavioral Verification

- `flutter test test/interactive/core/scene_controller_mutation_boundary_test.dart`
- `flutter test test/controller/core/scene_controller_committed_mutation_access_test.dart`

#### Structural Verification

- `flutter test test/interactive/core/scene_controller_architecture_boundary_test.dart`
- `dart run tool/run_tool_tests.dart test/tool/guardrails/guardrails_interactive_api_tool_test.dart`
- `dart run tool/run_tool_tests.dart test/tool/target_architecture_map_tool_test.dart`

#### Fixtures Used

- `docs/target_architecture/evidence/add_node_write_flow.json`
- `docs/target_architecture/evidence/add_node_write_flow.md`
- `docs/target_architecture/evidence/commit_move_selection_flow.json`
- `docs/target_architecture/evidence/commit_move_selection_flow.md`
- `docs/target_architecture/evidence/replace_scene_write_flow.json`
- `docs/target_architecture/evidence/replace_scene_write_flow.md`

#### Positive Scenarios

- the add-node write flow shows the public scene owner crossing directly into
  `SceneControllerMutationBoundary` without a retired shell hop
- the interaction-family evidence points at a live runtime wiring surface
  instead of the deleted `InteractiveSelectionActions` file
- the replace-scene write flow shows the direct public owner crossing into
  `SceneControllerMutationBoundary` and then into
  `SceneControllerCommittedMutationAccess` without a retired shell hop

#### Negative Scenarios

- target-map structural tests fail if mutation-family docs keep the old
  `locked, needs slimming` status after the direct-route proof lands
- target-map structural tests fail if family docs or evidence still reference
  deleted shell files
- docs/evidence review fails if store-family replace-scene proof still points
  at `SceneControllerSceneMutations.replaceScene`

#### Closure Evidence

- `docs/target_architecture/overview.md` marks the mutation gateway family
  `locked`
- committed evidence artifacts reference only live direct-route files

## 11. Final Verification

- `flutter test test/interactive/core/scene_controller_interactive_actions_effects_test.dart`
- `flutter test test/interactive/core/scene_controller_interactive_single_pointer_policy_test.dart`
- `flutter test test/interactive/core/scene_controller_interactive_basics_test.dart`
- `flutter test test/interactive/core/scene_controller_interaction_contract_test.dart`
- `flutter test test/interactive/core/scene_controller_mutation_boundary_test.dart`
- `flutter test test/controller/core/scene_controller_committed_mutation_access_test.dart`
- `flutter test test/interactive/core/scene_controller_architecture_boundary_test.dart`
- `dart run tool/run_tool_tests.dart test/tool/public_capability_owner_contract_tool_test.dart`
- `dart run tool/run_tool_tests.dart test/tool/guardrails/guardrails_interactive_api_tool_test.dart`
- `dart run tool/run_tool_tests.dart test/tool/target_architecture_map_tool_test.dart`
- `dcm calculate-metrics lib/src/interactive/scene_controller_scene.dart lib/src/interactive/scene_controller_selection.dart lib/src/interactive/internal/scene_controller_interaction_runtime.dart lib/src/interactive/internal/scene_controller_mutation_boundary.dart`
- `printf '%s\n' 'PLAN.md' 'plan/step_18_mutation_gateway_surface_narrowing_and_shell_retirement.md' 'ARCHITECTURE.md' 'docs/target_architecture/overview.md' 'docs/target_architecture/families/mutation_gateway.md' 'docs/target_architecture/families/store_and_commit_path.md' 'docs/target_architecture/families/interaction_runtime.md' 'docs/target_architecture/evidence/add_node_write_flow.json' 'docs/target_architecture/evidence/add_node_write_flow.md' 'docs/target_architecture/evidence/commit_move_selection_flow.json' 'docs/target_architecture/evidence/commit_move_selection_flow.md' 'docs/target_architecture/evidence/replace_scene_write_flow.json' 'docs/target_architecture/evidence/replace_scene_write_flow.md' 'lib/src/interactive/scene_controller_scene.dart' 'lib/src/interactive/scene_controller_selection.dart' 'lib/src/interactive/internal/scene_controller_interaction_runtime.dart' 'lib/src/interactive/internal/scene_controller_graph.dart' 'lib/src/interactive/internal/scene_controller_mutation_boundary.dart' 'lib/src/interactive/internal/scene_controller_scene_mutations.dart' 'lib/src/interactive/internal/scene_controller_selection_mutations.dart' 'lib/src/interactive/internal/interactive_selection_actions.dart' 'test/interactive/core/scene_controller_mutation_boundary_test.dart' 'test/interactive/core/scene_controller_interaction_contract_test.dart' 'test/interactive/core/scene_controller_interactive_actions_effects_test.dart' 'test/interactive/core/scene_controller_interactive_basics_test.dart' 'test/interactive/core/scene_controller_interactive_single_pointer_policy_test.dart' 'test/interactive/core/scene_controller_architecture_boundary_test.dart' 'test/controller/core/scene_controller_committed_mutation_access_test.dart' 'test/tool/public_capability_owner_contract_tool_test.dart' 'test/tool/guardrails/guardrails_interactive_api_tool_test.dart' 'test/tool/guardrails/interactive_api/architecture_boundary/facade_and_boundary_cases.dart' 'test/tool/guardrails/interactive_api/architecture_boundary/runtime_session_contract_cases.dart' 'test/tool/guardrails/interactive_api/architecture_boundary/view_and_graph_cases.dart' 'test/tool/guardrails/interactive_api/architecture_boundary/pointer_host_and_public_shell_cases.dart' 'test/tool/guardrails/interactive_api/mutation_boundary/owner_guard_cases.dart' 'test/tool/support/guardrails_sandbox_support.dart' 'test/tool/target_architecture_map_tool_test.dart' 'tool/invariant_registry.dart' 'tool/src/guardrails/rules/interactive/mutation_boundary_rules.dart' 'tool/src/guardrails/rules/interactive/interactive_architecture_boundary_rules.dart' 'tool/src/guardrails/rules/interactive/interactive_architecture_boundary_mutation_rules.dart' 'tool/src/guardrails/rules/interactive/interactive_architecture_boundary_mutation_runtime_rules.dart' 'tool/src/guardrails/rules/interactive/interactive_architecture_boundary_mutation_shell_rules.dart' 'tool/src/guardrails/rules/interactive/interactive_mutation_owner_guard_rules.dart' 'tool/src/guardrails/rules/interactive/committed_read_callback_rules.dart' | dart run tool/run_verification_preset.dart run --preset=required_code_change --changed-paths-file=-`

## 12. Acceptance Criteria

- `SceneControllerSceneMutations`,
  `SceneControllerSelectionMutations`, and `InteractiveSelectionActions`
  are absent from `lib/src/interactive/internal/**`
- public scene and selection owners route directly to
  `SceneControllerMutationBoundary` with the correct preflight behavior
- runtime-owned transform/delete/clear helpers route directly to
  `SceneControllerMutationBoundary`
- no interactive caller bypasses `SceneControllerMutationBoundary` to reach
  controller/store write APIs
- `replaceScene(...)` sequencing still belongs to
  `SceneControllerCommittedMutationAccess`
- mutation-family architecture proof, guardrails, invariant wording, and
  target-map evidence all describe the same direct-route local form
