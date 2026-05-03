# Change Contract

## 1. Change Mandate

Compress the accepted interaction family by retiring the mixed
`SceneControllerInteractionAccess` context bag, replacing runtime-to-move
preview leakage with a narrow read seam, and landing the interaction family in
the locked target shape without changing the supported public interaction API.

## 2. Change Boundary

### Included in the Change

- retire `SceneControllerInteractionAccess` and
  `SceneControllerInteractionContext` from
  `lib/src/interactive/internal/scene_controller_interaction_access.dart`
- wire `SceneControllerInteractionOwner` directly to its explicit
  dependencies instead of a shared access bag
- introduce one narrow internal move-preview read seam for
  `previewDeltaForNode(...)` and `captureFramePreview()`, owned by the move
  subsystem and consumed by composition-root wiring only
- remove `InteractiveRuntime.debugMoveSession` and any runtime-bridge preview
  wrappers that exist only to reach the move subsystem through a broad owner
- replace `sceneControllerInternalInteractionAccessForTest(...)` with
  dedicated internal readers for the specific test-owned needs that remain
- update composition-root wiring, guardrails, sandbox fixtures, architecture
  tests, target-map evidence, and interaction-family docs so the checked-in
  form matches the compressed interaction-family target
- refresh `ARCHITECTURE.md`,
  `docs/target_architecture/families/interaction_runtime.md`,
  `docs/target_architecture/overview.md`, and `tool/invariant_registry.dart`
  when the new local form lands
- add this step to `PLAN.md` and update both files together when the step
  closes

### Not Included in the Change

- no store-family cleanup or `SceneStoreController` slimming
- no split of `SceneControllerCommitRuntime` or committed mutation access
  owners
- no public API reduction or supported capability thinning for
  `SceneControllerInteraction`
- no new top-level owner family or package-boundary redesign
- no separate pointer-session redesign outside the interaction-family
  compression cut
- no draw-subsystem redesign beyond the minimum adoption edits needed by the
  new preview read seam
- no schema/version, barrel export, or supported import-surface change
- no follow-up phase-2 store contract from
  `docs/adr/0002_post_target_optimization_scope.md`

## 3. Surrounding Code Review

### Inspected Artifacts

- `PLAN.md` - the active plan index is closed through step 18, so this change
  must add a new dedicated step document instead of extending a finished
  contract
- `docs/adr/0002_post_target_optimization_scope.md` - phase 2 is explicitly
  ordered as interaction-family compression first, then optional store-facade
  cleanup after remeasurement
- `docs/target_architecture/overview.md` - after step 18 the only remaining
  `locked, needs slimming` families are `Interaction runtime` and
  `Store and commit path`
- `docs/target_architecture/families/interaction_runtime.md` - the family is
  already locked at the top level but still names bridge/core breadth and
  thin-wrapper debt as the remaining local cleanup
- `docs/target_architecture/families/composition_root_and_facade.md` - the
  composition family is already `locked`, and its rule text still stays valid;
  only its committed evidence points to
  `SceneControllerInteractionContext` and runtime-owned preview wrappers, so
  the evidence artifacts must move with this compression step without opening
  a separate composition-family rewrite
- `docs/target_architecture/evidence/composition_root_trace.json` and
  `docs/target_architecture/evidence/composition_root_trace.md` - the checked-
  in graph trace still records `SceneControllerInteractionContext`,
  `SceneControllerInteractionRuntimeMutationApi.captureFramePreview`,
  `SceneControllerInteractionRuntimeMutationApi.previewDeltaForNode`, and
  `InteractiveRuntime.get debugMoveSession`
- `lib/src/interactive/scene_controller_interaction.dart` -
  `SceneControllerInteractionOwner` currently reads as a broad public facade
  over one mixed `_access` bag that interleaves runtime state, config state,
  selection policy, and owner listenability
- `lib/src/interactive/internal/scene_controller_interaction_access.dart` -
  `SceneControllerInteractionContext` currently bundles `snapshot`, `config`,
  `runtime`, selection-clearing policy, and `Listenable` forwarding into one
  context object
- `lib/src/interactive/internal/scene_controller_interaction_runtime.dart` -
  the runtime bridge already owns schedulers, event dispatch, mutation
  boundary wiring, pointer-session lifecycle, and two broad extension
  surfaces; it also exposes preview readback by reaching through
  `runtime.debugMoveSession`
- `lib/src/interactive/internal/interactive_runtime.dart` -
  `InteractiveRuntime` is the compact core candidate, but it currently leaks
  `InteractiveMoveSession` through `debugMoveSession` and still carries
  multiple pure-forwarder public/session dispatch wrappers
- `lib/src/interactive/internal/interactive_move_session.dart` - the move
  subsystem already owns `movePreviewDeltaForNode(...)` and
  `captureFramePreview()`, so it is the correct home for a narrow preview read
  seam
- `lib/src/interactive/internal/scene_controller_graph.dart` - the
  composition root currently constructs `SceneControllerInteractionContext`,
  routes scene-view preview capture through `interactionRuntime`, and exposes
  `readInteractionAccessForTest` through internal access registration
- `lib/src/interactive/internal/scene_controller_internal_access.dart` - the
  internal test seam currently stores a broad
  `SceneControllerInteractionAccess Function()` alongside narrower debug/test
  hooks
- `lib/src/interactive/internal/scene_controller_scene_view_runtime.dart` -
  view-runtime assembly only needs `captureFramePreview()` and not the full
  interaction access bag or a move-session leak
- `tool/src/guardrails/rules/interactive/interactive_architecture_boundary_rules.dart`
  - the interactive architecture rule still requires
  `SceneControllerInteractionContext` as a live owner and therefore must
  migrate before the file can retire
- `test/tool/support/guardrails_sandbox_support.dart` - sandbox fixtures still
  define `SceneControllerInteractionAccess` /
  `SceneControllerInteractionContext`, so fixture support must move before the
  production file retires
- `test/tool/guardrails/interactive_api/architecture_boundary/view_and_graph_cases.dart`
  - negative structural scenarios still import
  `scene_controller_interaction_access.dart` and construct
  `SceneControllerInteractionContext(...)`
- `test/interactive/core/scene_controller_interaction_contract_test.dart` -
  this suite already locks pointer-session lifecycle and runtime-owned entry
  behavior, and it currently reaches runtime internals through
  `sceneControllerInternalInteractionAccessForTest(...).runtime`
- `test/interactive/core/scene_controller_interactive_basics_test.dart` - this
  suite already locks active-gesture lifecycle and one internal committed
  snapshot read, both of which currently pass through the broad interaction
  access bag
- `test/interactive/core/scene_controller_mutation_boundary_test.dart` - this
  suite uses the internal runtime test seam and therefore must migrate to the
  dedicated successor reader before the bag can retire
- `test/interactive/core/interactive_move_session_test.dart` - this suite
  already characterizes move preview behavior at the move-session owner
  boundary and is the natural guard suite for the new narrow preview read seam
- `test/interactive/core/scene_controller_architecture_boundary_test.dart` -
  the structural architecture proof currently guards the split facade/root/view
  form but does not yet forbid a reintroduced interaction access bag or a
  move-session leak through runtime
- `test/tool/guardrails/guardrails_interactive_api_tool_test.dart` - the
  interactive guardrail suite must become the machine-enforced successor proof
  for both the retired access bag and the retired debug move-session leak
- `test/tool/target_architecture_map_tool_test.dart` - the top-level target
  map already expects exactly five owner families and the shared status
  vocabulary, so this step should only move `Interaction runtime` from
  `locked, needs slimming` to `locked`
- `tool/invariant_registry.dart` -
  `INV-ENG-INTERACTIVE-ARCHITECTURE-BOUNDARY` and
  `INV-ENG-INTERACTIVE-POINTER-SESSION-LIFECYCLE` already name the structural
  and behavior constraints this step must preserve
- `dart run tool/lsp_trace_flow.dart lib/src/interactive/scene_controller_interaction.dart SceneControllerInteractionOwner.handlePointer --depth=5`
  - confirms the public pointer entry is already a thin facade route:
  `SceneControllerInteractionOwner -> SceneControllerInteractionAccess.get runtime -> SceneControllerInteractionRuntime.handlePublicPointer`
- `dart run tool/lsp_trace_flow.dart lib/src/interactive/scene_controller_interaction.dart SceneControllerInteractionOwner.setMode --depth=5`
  - confirms the mixed access bag is not just syntactic sugar: one public
  method fans into runtime guard, runtime interrupt, config mutation, draw-mode
  selection policy, and notify scheduling through the same bag
- `dart run tool/lsp_find_boundary_bypasses.dart lib/src/interactive/scene_controller_interaction.dart SceneControllerInteractionOwner --must-pass=SceneControllerInteractionRuntime --depth=4`
  - shows that the public interaction surface currently spans runtime and
  config access instead of reading as one compressed facade over explicit
  dependencies
- `dart run tool/lsp_trace_symbol.dart lib/src/interactive/internal/scene_controller_interaction_runtime.dart _createInteractiveRuntime --direction=outgoing --depth=4`
  - confirms the runtime center is still
  `SceneControllerInteractionRuntime -> InteractiveRuntime -> InteractiveMoveSession / InteractiveDrawCoordinator`,
  with broad callback fan-out from one bridge owner
- `dart run tool/lsp_find_thin_wrappers.dart lib/src/interactive --classification=pure-forwarder`
  - reports pure-forwarder candidates for
  `InteractiveRuntime.handlePublicPointer`,
  `InteractiveRuntime.handlePointerFromSession`,
  `InteractiveRuntime.handlePublicDoubleTap`,
  `InteractiveRuntime.handleDoubleTapFromSession`,
  `InteractiveMoveSession.movePreviewDeltaForNode`, and
  `SceneControllerInteractionOwner.addListener/removeListener`, confirming
  interaction-family shim debt remains inside the checked-in family
- `dcm calculate-metrics lib/src/interactive/scene_controller_interaction.dart lib/src/interactive/internal/scene_controller_interaction_access.dart lib/src/interactive/internal/scene_controller_interaction_runtime.dart lib/src/interactive/internal/interactive_runtime.dart lib/src/interactive/internal/interactive_move_session.dart lib/src/interactive/internal/scene_controller_graph.dart lib/src/interactive/internal/scene_controller_internal_access.dart --reporter=console`
  - remeasurement still points at the same family hot spots:
  `SceneControllerInteractionOwner` 42 methods / weighted complexity 79,
  `InteractiveRuntime` 37 methods / response set 53,
  `InteractiveMoveSession` 22 methods / response set 43, and
  both graph/runtime files still high on imports and surface breadth

### Current Entry Path

- public interaction capability path:
  `SceneController.interaction.*` ->
  `SceneControllerInteractionOwner.*` ->
  `SceneControllerInteractionAccess.{runtime|config|clearSelectionState|hasSelection|clearSelectionOnDrawModeEnter}`
- preview and internal readback path:
  `createSceneControllerGraph(...)` ->
  `SceneControllerSceneViewRuntime(captureFramePreview: ...)` /
  `SceneControllerInternalAccessRegistration(previewDeltaForNode: ..., readInteractionAccessForTest: ...)` ->
  `SceneControllerInteractionRuntime.previewDeltaForNode / captureFramePreview` ->
  `InteractiveRuntime.debugMoveSession` ->
  `InteractiveMoveSession`
- core interaction assembly path:
  `createSceneControllerInteractionRuntime(...)` ->
  `_createInteractiveRuntime(...)` ->
  `InteractiveRuntime(...)` ->
  `InteractiveMoveSession(...)` and `InteractiveDrawCoordinator(...)`

### Current Owner

- interaction-family ownership is currently spread across:
  `SceneControllerInteractionOwner`,
  `SceneControllerInteractionContext`,
  `SceneControllerInteractionRuntime`,
  `InteractiveRuntime`,
  `InteractiveMoveSession`, and the composition-root/internal-access wiring
  that carries the mixed read seams outward

### Adjacent Abstractions

- `lib/src/interactive/internal/scene_controller_interaction_config.dart` -
  the cohesive config owner that should remain separate from the runtime bridge
- `lib/src/interactive/internal/scene_controller_scene_view_runtime.dart` -
  the adjacent controller-owned read boundary that should receive only the
  narrow preview seam it actually needs
- `lib/src/interactive/internal/scene_controller_internal_access.dart` -
  the adjacent internal test seam that should expose dedicated helpers instead
  of a bag-type owner mirror
- `lib/src/interactive/internal/scene_controller_pointer_session.dart` -
  the pointer-session adapter that remains part of the same family but is not
  the primary compression target for this step
- `lib/src/interactive/scene_controller_scene.dart` and
  `lib/src/interactive/scene_controller_selection.dart` - adjacent public
  capability owners that already use explicit dependencies and therefore show
  the local direct-constructor form this step should follow

### Existing Tests

- `test/interactive/core/scene_controller_interaction_contract_test.dart` -
  runtime/session contract proof and internal interaction runtime access
- `test/interactive/core/scene_controller_interactive_basics_test.dart` -
  active-gesture lifecycle and internal committed snapshot proof
- `test/interactive/core/scene_controller_mutation_boundary_test.dart` -
  internal runtime mutation-entrypoint proof
- `test/interactive/core/interactive_move_session_test.dart` -
  move preview and move-session behavior characterization
- `test/interactive/core/scene_controller_architecture_boundary_test.dart` -
  structural split proof for facade/root/view ownership
- `test/tool/guardrails/guardrails_interactive_api_tool_test.dart` -
  machine-enforced interactive architecture regression suite
- `test/tool/target_architecture_map_tool_test.dart` - owner-family status and
  target-map structure proof

### Analogous Implementation Path

- `lib/src/interactive/scene_controller_scene.dart` and
  `lib/src/interactive/scene_controller_selection.dart` - these are the
  closest checked-in public capability owners that already take explicit
  constructor dependencies instead of a mixed context bag, so they are the
  local precedent for retiring `SceneControllerInteractionContext`

### Governing Repository Rules

- `AGENTS.md` - fix the owning architectural seam instead of leaving mixed
  access policy spread across callers
- `AGENTS.md` - architecture changes must update repository-local proof and
  source-of-truth documents, not only chat explanations
- `docs/adr/0002_post_target_optimization_scope.md` - interaction-family
  compression is the default next wave and must finish before any optional
  store cleanup is planned
- `docs/target_architecture/README.md` - target-map evidence must come from
  repository-local probe commands, not hand-written flow descriptions
- `docs/target_architecture/families/interaction_runtime.md` - the bridge/core
  family stays one accepted owner family and should slim internally instead of
  becoming another top-level redesign
- `tool/invariant_registry.dart` -
  `INV-ENG-INTERACTIVE-ARCHITECTURE-BOUNDARY` and
  `INV-ENG-INTERACTIVE-POINTER-SESSION-LIFECYCLE` govern the structural and
  behavior constraints in this area
- repository verification rules - final verification must use
  `dart run tool/run_verification_preset.dart run --preset=required_code_change`
  rather than plain `dart test`

### Rejected Misleading Local Patterns

- keep `SceneControllerInteractionAccess` and only drop a few fields - wrong
  seam because the mixed context bag would remain the public-owner dependency
  form after the step claims the family was compressed
- keep `InteractiveRuntime.debugMoveSession` and only rename it - wrong seam
  because the bridge/core boundary would still leak the move subsystem through
  a broad runtime owner
- move preview read ownership into `SceneControllerSceneViewRuntime` or the
  view shell - wrong owner because preview state still belongs to the
  interaction family, not the view adapter
- thin the public `SceneControllerInteraction` API as the default fix - wrong
  level because ADR 0002 explicitly treats supported public capability breadth
  as a separate API-review track, not this internal compression step
- start with `SceneStoreController` or `SceneControllerCommitRuntime` cleanup -
  wrong family because the current machine signals and accepted ADR order still
  point to interaction-family compression first

## 4. Architecture

### 4A. Locked Architectural Form

#### Problem Ownership Level

- one local compression cut inside the already accepted interaction family

#### Selected Architectural Form

- `SceneControllerInteractionOwner` remains the supported public interaction
  facade, but it no longer depends on a shared access/context bag; it takes
  explicit constructor dependencies for owner listenability,
  `SceneControllerInteractionConfig`, `SceneControllerInteractionRuntime`, and
  the draw-mode selection-clearing policy callbacks/flag it actually owns
- `SceneControllerInteractionRuntime` remains the interaction-family bridge for
  public-side-effect safety, notify scheduling, event streams, pointer-session
  lifecycle, external-mutation coordination, and runtime-owned mutation
  entrypoints; it may expose a narrow `movePreviewRead` bridge for composition-
  root wiring, but it must not leak `InteractiveMoveSession`
- `InteractiveRuntime` remains the compact interaction core for gesture
  orchestration and preview state; it no longer exposes
  `InteractiveMoveSession` as a debug/read escape hatch
- `InteractiveMoveSession` owns move preview readback and becomes the owner of
  one narrow internal seam file:
  `lib/src/interactive/internal/interactive_move_preview_read.dart`
- `SceneControllerSceneViewRuntime` and
  `SceneControllerInternalAccessRegistration` consume only the narrow preview
  and test-read seams that the composition root wires to them; they must not
  depend on `SceneControllerInteractionContext`, `InteractiveRuntime`, or
  `InteractiveMoveSession` directly

#### Owning Layer or Module

- production ownership stays in `lib/src/interactive/**` with composition-root
  wiring in `lib/src/interactive/internal/scene_controller_graph.dart`; no
  responsibility moves into controller/store or the view shell

#### Dependency Direction

- public interaction facade ->
  `SceneControllerInteractionConfig` +
  `SceneControllerInteractionRuntime` +
  explicit selection-policy callbacks/flag
- composition root ->
  `SceneControllerInteractionRuntime` +
  `InteractiveMovePreviewRead` +
  dedicated internal runtime/snapshot readers
- runtime bridge ->
  `InteractiveRuntime` +
  `SceneControllerMutationBoundary` +
  pointer-session owners +
  schedulers/events
- move preview read exits outward only through
  `InteractiveMovePreviewRead`; no other consumer may depend on
  `InteractiveMoveSession`

#### State and Data Ownership

- interaction config state remains in
  `SceneControllerInteractionConfig`
- gesture, move preview, and draw preview state remain in
  `InteractiveRuntime` and its internal subsystems
- move preview capture and per-node preview delta remain owned by
  `InteractiveMoveSession`
- committed snapshot ownership remains with `SceneStoreController`; internal
  tests that still need a committed snapshot get it through a dedicated reader,
  not through an interaction access bag

#### Entry and Exit Boundaries

- public capability entry remains `SceneControllerInteractionOwner`
- runtime pointer/session entry remains
  `SceneControllerInteractionRuntime` /
  `SceneControllerPointerSession`
- view-runtime preview exit becomes the narrow
  `InteractiveMovePreviewRead` seam
- internal test exits become dedicated helpers in
  `scene_controller_internal_access.dart`, not
  `sceneControllerInternalInteractionAccessForTest(...)`

#### Permitted Extension Seam

- one new internal seam file is permitted:
  `lib/src/interactive/internal/interactive_move_preview_read.dart`
- `scene_controller_internal_access.dart` may gain dedicated runtime/snapshot
  test readers, but it must not introduce another aggregate owner bag
- `lib/src/interactive/internal/scene_controller_interaction_access.dart`
  must retire instead of being renamed or repurposed

#### Rejected Alternatives

- keep a smaller `SceneControllerInteractionAccess` bag - wrong dependency form
  because the public interaction facade would still hide mixed ownership behind
  one context object
- leave `captureFramePreview()` and `previewDeltaForNode(...)` on the runtime
  bridge while only removing `debugMoveSession` - wrong local form because the
  preview read path would still look bridge-owned instead of move-subsystem-
  owned
- split pointer-session lifecycle into its own architecture contract now -
  wrong level because ADR 0002 treats it as secondary debt inside the same
  family, not the next independent cut
- combine interaction compression with store-facade cleanup - wrong scope
  because it would mix the primary and optional phase-2 families into one
  execution contract

#### Why This Level Is Correct

- ADR 0002 already fixes the next wave as one interaction-family compression
  effort, not a new top-level redesign
- the current machine traces show that the unresolved debt is local to the
  interaction family: one mixed public-owner dependency form, one broad runtime
  bridge, and one preview leak from the move subsystem through runtime
- the move subsystem already owns the preview operations that leak outward, so
  a narrow read seam at that owner is smaller and more coherent than another
  bridge/helper layer

## 5. Locked Decisions

1. The successor internal test seam is a set of dedicated helpers in
   `scene_controller_internal_access.dart`, including runtime and committed
   snapshot readers; the broad
   `sceneControllerInternalInteractionAccessForTest(...)` helper retires in
   this step instead of surviving as a compatibility shell.
2. The successor preview seam is `InteractiveMovePreviewRead` in
   `lib/src/interactive/internal/interactive_move_preview_read.dart`, and both
   `captureFramePreview()` and `previewDeltaForNode(...)` migrate to that seam
   before `debugMoveSession` and runtime-owned preview wrappers retire.
3. `SceneControllerInteractionOwner` keeps the same supported public API
   surface and behavior; this contract is a structural compression step, not a
   public interaction capability change.
4. `docs/target_architecture/families/interaction_runtime.md` and
   `docs/target_architecture/overview.md` move the interaction family from
   `locked, needs slimming` to `locked` only after the code, guardrails,
   evidence artifacts, and structural tests all match the compressed form.

## 6. Result Requirements

1. No checked-in production, test, tool, or evidence artifact still depends on
   `SceneControllerInteractionAccess`,
   `SceneControllerInteractionContext`, or
   `sceneControllerInternalInteractionAccessForTest(...)`.
2. No checked-in production code exposes `InteractiveMoveSession` through
   `InteractiveRuntime.debugMoveSession` or an equivalent renamed bridge leak.
3. `SceneControllerInteractionOwner` reads as an explicit public facade over
   config/runtime plus the narrow selection-clearing policy hooks it actually
   owns.
4. View-runtime preview capture and internal test readback use only the narrow
   successor seams wired by the composition root.
5. The interaction-family target map is current and marks `Interaction runtime`
   as `locked`; `Store and commit path` remains the only family still marked
   `locked, needs slimming`.

## 7. Execution Order and Gates

### Required Order

- land the successor preview and dedicated internal test read seams first, and
  migrate graph/view/test consumers to them before retiring any mixed bag or
  debug-move-session path
- retire the mixed public-owner access bag only after the successor test seam,
  guardrail fixtures, and architecture rules no longer rely on it
- update the interaction-family docs and family-status vocabulary only after
  both retirements are complete and mechanically verified

### Successor Seam and Retirement Gates

- `InteractiveMovePreviewRead` succeeds the current runtime-owned preview
  route; `InteractiveRuntime.debugMoveSession` and any runtime-owned preview
  wrapper methods may retire only after
  `scene_controller_graph.dart`,
  `scene_controller_scene_view_runtime.dart`,
  `scene_controller_internal_access.dart`, and the committed evidence artifacts
  consume the new seam
- dedicated internal runtime/snapshot readers succeed
  `sceneControllerInternalInteractionAccessForTest(...)`; the bag helper may
  retire only after all interactive tests and guardrail sandboxes stop reading
  `.runtime` / `.snapshot` through the broad helper
- direct constructor dependencies on `SceneControllerInteractionOwner` succeed
  `SceneControllerInteractionContext`; the access/context file may retire only
  after architecture guardrails and negative fixture cases stop importing or
  constructing it

### Deferred Broad Verification

- `dart run tool/run_verification_preset.dart run --preset=required_code_change --changed-paths-file=-`
  - reserve for the final gate after all slices land
- `dart run tool/run_tool_tests.dart test/tool/guardrails/guardrails_interactive_api_tool_test.dart`
  - reserve as a final broad tool-suite rerun after the guardrail surface and
  fixture support stabilize

## 8. File Map

### Implementation Files

- `PLAN.md`
- `plan/step_19_interaction_family_compression_and_narrow_read_seams.md`
- `ARCHITECTURE.md`
- `docs/target_architecture/families/interaction_runtime.md`
- `docs/target_architecture/overview.md`
- `lib/src/interactive/scene_controller_interaction.dart`
- `lib/src/interactive/internal/scene_controller_interaction_access.dart`
- `lib/src/interactive/internal/scene_controller_interaction_runtime.dart`
- `lib/src/interactive/internal/interactive_runtime.dart`
- `lib/src/interactive/internal/interactive_move_session.dart`
- `lib/src/interactive/internal/interactive_move_preview_read.dart`
- `lib/src/interactive/internal/scene_controller_graph.dart`
- `lib/src/interactive/internal/scene_controller_internal_access.dart`
- `lib/src/interactive/internal/scene_controller_scene_view_runtime.dart`

### Test Files

- `test/interactive/core/scene_controller_interaction_contract_test.dart`
- `test/interactive/core/scene_controller_interactive_basics_test.dart`
- `test/interactive/core/scene_controller_mutation_boundary_test.dart`
- `test/interactive/core/interactive_move_session_test.dart`
- `test/interactive/core/scene_controller_architecture_boundary_test.dart`
- `test/tool/guardrails/guardrails_interactive_api_tool_test.dart`
- `test/tool/guardrails/interactive_api/architecture_boundary/view_and_graph_cases.dart`
- `test/tool/target_architecture_map_tool_test.dart`

### Fixtures and Supporting Data

- `test/tool/support/guardrails_sandbox_support.dart`
- `docs/target_architecture/evidence/composition_root_trace.json`
- `docs/target_architecture/evidence/composition_root_trace.md`
- `docs/target_architecture/evidence/commit_move_selection_flow.json`
- `docs/target_architecture/evidence/commit_move_selection_flow.md`

### Registry, Inventory, and Workflow Files

- `tool/invariant_registry.dart`
- `tool/src/guardrails/rules/interactive/interactive_architecture_boundary_rules.dart`

### Analysis Area

- `lib/src/interactive/**`
- `test/interactive/core/**`
- `test/tool/guardrails/interactive_api/**`
- `docs/target_architecture/**`

## 9. Implementation Rules

### Protected Invariants

- `INV-ENG-INTERACTIVE-ARCHITECTURE-BOUNDARY`
- `INV-ENG-INTERACTIVE-POINTER-SESSION-LIFECYCLE`
- `INV-ENG-INTERACTIVE-PUBLIC-MUTATION-EXCLUSIVITY`

### Required Proof

- behavioral proof:
  keep public interaction behavior, pointer-session lifecycle, move preview
  behavior, runtime mutation entry behavior, and committed snapshot reads green
  while the internal seam form changes
- structural proof:
  make reintroduction of `SceneControllerInteractionContext`,
  `sceneControllerInternalInteractionAccessForTest(...)`, or
  `InteractiveRuntime.debugMoveSession` mechanically visible through
  architecture tests, interactive guardrails, and refreshed machine-generated
  target-map evidence; Slice 1 must add executable negative proof that the
  migrated graph/view/internal-test path no longer depends on
  `readInteractionAccessForTest` /
  `sceneControllerInternalInteractionAccessForTest(...)` and no longer routes
  preview wiring through `InteractiveRuntime.debugMoveSession`; repository-wide
  absence of `InteractiveRuntime.debugMoveSession` is a Slice 3 proof
- for bug fixes, regressions, false positives, false negatives, and
  invariant-enforcement gaps: one failing reproducer first, plus 1 to 3 guard
  tests for neighboring branches of the same contract
- for refactors: existing locking tests must be named or missing
  characterization tests must be added before structural edits, plus 1 to 3
  guard tests for neighboring branches when needed

### Allowed Change Surface

- only the interaction-family files, composition-root wiring, internal test
  seam, architecture proof, target-map evidence, and docs listed in section 8
- one new production seam file:
  `lib/src/interactive/internal/interactive_move_preview_read.dart`
- narrow helper additions in `scene_controller_internal_access.dart` only when
  they replace the retiring broad helper and keep the same test-owned
  semantics

### Forbidden Moves

- do not add a new replacement context bag or umbrella owner to stand in for
  `SceneControllerInteractionAccess`
- do not preserve `InteractiveRuntime.debugMoveSession` under a different name
  or through a broad equivalent getter
- do not move preview-state ownership into the view shell,
  `SceneControllerSceneViewRuntime`, or `SceneControllerInteractionOwner`
- do not mix store-family cleanup, commit-runtime changes, or public API
  thinning into this step
- do not change target-map family counts or add a sixth family
- do not mark the interaction family `locked` before guardrails, tests, docs,
  and evidence artifacts all match the compressed form

## 10. Vertical Slices

### Slice 1. [x] Narrow Preview And Test Read Seams

#### Slice Contract

Land the successor read seams first by introducing a narrow move-preview read
owner, migrating composition-root consumers and internal test readers to it,
and replacing the broad internal interaction-access helper with dedicated
runtime/snapshot readers while behavior stays unchanged.

#### Change

- add `InteractiveMovePreviewRead` in
  `lib/src/interactive/internal/interactive_move_preview_read.dart`
- make the move subsystem own that seam and wire the composition root to use it
  for `captureFramePreview()` and `previewDeltaForNode(...)`
- add dedicated runtime and committed snapshot readers in
  `scene_controller_internal_access.dart` and migrate interactive tests away
  from `sceneControllerInternalInteractionAccessForTest(...)`
- extend `test/interactive/core/scene_controller_architecture_boundary_test.dart`
  with explicit negative assertions for the migrated read path so the graph,
  internal-access registration, and composition-root preview wiring fail
  mechanically if `readInteractionAccessForTest` /
  `sceneControllerInternalInteractionAccessForTest(...)` remain, or if preview
  wiring still reaches `InteractiveRuntime.debugMoveSession`
- refresh the composition-root evidence artifacts so they prove the new read
  path instead of the old runtime/debug-move-session route

#### Behavioral Verification

- `flutter test test/interactive/core/interactive_move_session_test.dart`
- `flutter test test/interactive/core/scene_controller_interaction_contract_test.dart`
- `flutter test test/interactive/core/scene_controller_interactive_basics_test.dart`
- `flutter test test/interactive/core/scene_controller_mutation_boundary_test.dart`

#### Structural Verification

- `dart run tool/lsp_trace_symbol.dart lib/src/interactive/internal/scene_controller_graph.dart createSceneControllerGraph --direction=outgoing --depth=3 --json-out=docs/target_architecture/evidence/composition_root_trace.json --mermaid-out=docs/target_architecture/evidence/composition_root_trace.md`
- `flutter test test/interactive/core/scene_controller_architecture_boundary_test.dart`
- `rg -n "readInteractionAccessForTest|sceneControllerInternalInteractionAccessForTest" lib/src/interactive/internal/scene_controller_graph.dart lib/src/interactive/internal/scene_controller_internal_access.dart test/interactive/core docs/target_architecture/evidence/composition_root_trace.json docs/target_architecture/evidence/composition_root_trace.md`
- `rg -n "debugMoveSession" lib/src/interactive/internal/scene_controller_graph.dart lib/src/interactive/internal/scene_controller_scene_view_runtime.dart lib/src/interactive/internal/scene_controller_internal_access.dart test/interactive/core docs/target_architecture/evidence/composition_root_trace.json docs/target_architecture/evidence/composition_root_trace.md`

#### Fixtures Used

- `docs/target_architecture/evidence/composition_root_trace.json`
- `docs/target_architecture/evidence/composition_root_trace.md`

#### Positive Scenarios

- frame-preview capture still reaches the move preview owner through the
  composition root without changing public behavior
- interactive tests can still read runtime state and the committed snapshot
  through dedicated internal helpers

#### Negative Scenarios

- no slice-local test, fixture, or evidence artifact still depends on the
  broad `sceneControllerInternalInteractionAccessForTest(...)` helper
- no migrated graph/view/internal-test path reaches the move subsystem through
  `debugMoveSession`
- the architecture test fails if `scene_controller_graph.dart` keeps
  `readInteractionAccessForTest` in internal-access registration after the
  dedicated readers land

#### Closure Evidence

- `scene_controller_internal_access.dart` exposes only dedicated readers for
  the migrated test needs
- `composition_root_trace.*` no longer records
  `InteractiveRuntime.get debugMoveSession`
- repository search over the migrated graph/view/internal-test path and the
  refreshed `composition_root_trace.*` finds no remaining
  `readInteractionAccessForTest` /
  `sceneControllerInternalInteractionAccessForTest(...)`

### Slice 2. [x] Retire Interaction Access Context Bag

#### Slice Contract

Retire `SceneControllerInteractionAccess` /
`SceneControllerInteractionContext` by wiring the public interaction owner to
explicit dependencies and migrating the interactive architecture proof and
sandbox fixtures to the direct-constructor form.

#### Change

- rewrite `SceneControllerInteractionOwner` to take explicit constructor
  dependencies instead of `SceneControllerInteractionAccess`
- remove production construction and use of `SceneControllerInteractionContext`
- retire `lib/src/interactive/internal/scene_controller_interaction_access.dart`
- update interactive guardrails, sandbox support, and the graph/view fixture
  cases so the access/context file is treated as a retired residual seam

#### Behavioral Verification

- `flutter test test/interactive/core/scene_controller_interaction_contract_test.dart`
- `flutter test test/interactive/core/scene_controller_interactive_basics_test.dart`
- `flutter test test/interactive/core/scene_controller_mutation_boundary_test.dart`

#### Structural Verification

- `dart run tool/run_tool_tests.dart test/tool/guardrails/guardrails_interactive_api_tool_test.dart`
- `flutter test test/interactive/core/scene_controller_architecture_boundary_test.dart`

#### Fixtures Used

- `test/tool/support/guardrails_sandbox_support.dart`
- `test/tool/guardrails/interactive_api/architecture_boundary/view_and_graph_cases.dart`

#### Positive Scenarios

- public interaction entrypoints still keep the same public behavior after the
  mixed access bag disappears
- guardrail fixtures can model the direct-constructor public owner shape

#### Negative Scenarios

- interactive architecture guardrails fail if
  `SceneControllerInteractionContext` is reintroduced
- no production or fixture file still imports
  `scene_controller_interaction_access.dart`

#### Closure Evidence

- `interactive_architecture_boundary_rules.dart` treats
  `scene_controller_interaction_access.dart` as a retired seam instead of a
  required live owner
- repository search over `lib/**`, `test/**`, and `tool/**` finds no remaining
  references to `SceneControllerInteractionContext`

### Slice 3. [x] Lock The Interaction Family Target Map

#### Slice Contract

Finish the compression cut by removing the runtime-owned move-session leak,
refreshing the interaction-family evidence/docs, and moving the target-map
status from `locked, needs slimming` to `locked`.

#### Change

- remove `InteractiveRuntime.debugMoveSession` and any runtime-owned preview
  wrappers that became obsolete once the narrow preview seam landed
- refresh the interaction-family evidence artifacts generated from
  `_createInteractiveRuntime(...)`
- update `ARCHITECTURE.md`,
  `docs/target_architecture/families/interaction_runtime.md`,
  `docs/target_architecture/overview.md`, and `tool/invariant_registry.dart`
  so the checked-in source of truth matches the compressed family

#### Behavioral Verification

- `flutter test test/interactive/core/interactive_move_session_test.dart`
- `flutter test test/interactive/core/scene_controller_interaction_contract_test.dart`
- `flutter test test/interactive/core/scene_controller_mutation_boundary_test.dart`

#### Structural Verification

- `dart run tool/lsp_trace_symbol.dart lib/src/interactive/internal/scene_controller_interaction_runtime.dart _createInteractiveRuntime --direction=outgoing --depth=4 --json-out=docs/target_architecture/evidence/commit_move_selection_flow.json --mermaid-out=docs/target_architecture/evidence/commit_move_selection_flow.md`
- `dart run tool/run_tool_tests.dart test/tool/target_architecture_map_tool_test.dart`
- `rg -n "debugMoveSession" lib test tool docs/target_architecture`

#### Fixtures Used

- `docs/target_architecture/evidence/commit_move_selection_flow.json`
- `docs/target_architecture/evidence/commit_move_selection_flow.md`

#### Positive Scenarios

- the runtime-center evidence still shows one interaction family with a bridge
  and compact core after the preview leak disappears
- the target map reports the interaction family as `locked`

#### Negative Scenarios

- no checked-in production code exposes `debugMoveSession` or an equivalent
  move-session getter on runtime
- the top-level map does not change family count or store-family status

#### Closure Evidence

- repository search over `lib/**`, `test/**`, `tool/**`, and
  `docs/target_architecture/**` finds no remaining `debugMoveSession`
  references
- `docs/target_architecture/overview.md` marks `Interaction runtime` as
  `locked`

## 11. Final Verification

- `flutter test test/interactive/core/interactive_move_session_test.dart`
- `flutter test test/interactive/core/scene_controller_interaction_contract_test.dart`
- `flutter test test/interactive/core/scene_controller_interactive_basics_test.dart`
- `flutter test test/interactive/core/scene_controller_mutation_boundary_test.dart`
- `flutter test test/interactive/core/scene_controller_architecture_boundary_test.dart`
- `dart run tool/run_tool_tests.dart test/tool/guardrails/guardrails_interactive_api_tool_test.dart`
- `dart run tool/run_tool_tests.dart test/tool/target_architecture_map_tool_test.dart`
- `printf '%s\n' 'PLAN.md' 'plan/step_19_interaction_family_compression_and_narrow_read_seams.md' 'ARCHITECTURE.md' 'docs/target_architecture/families/interaction_runtime.md' 'docs/target_architecture/overview.md' 'docs/target_architecture/evidence/composition_root_trace.json' 'docs/target_architecture/evidence/composition_root_trace.md' 'docs/target_architecture/evidence/commit_move_selection_flow.json' 'docs/target_architecture/evidence/commit_move_selection_flow.md' 'lib/src/interactive/scene_controller_interaction.dart' 'lib/src/interactive/internal/scene_controller_interaction_access.dart' 'lib/src/interactive/internal/scene_controller_interaction_runtime.dart' 'lib/src/interactive/internal/interactive_runtime.dart' 'lib/src/interactive/internal/interactive_move_session.dart' 'lib/src/interactive/internal/interactive_move_preview_read.dart' 'lib/src/interactive/internal/scene_controller_graph.dart' 'lib/src/interactive/internal/scene_controller_internal_access.dart' 'lib/src/interactive/internal/scene_controller_scene_view_runtime.dart' 'test/interactive/core/scene_controller_interaction_contract_test.dart' 'test/interactive/core/scene_controller_interactive_basics_test.dart' 'test/interactive/core/scene_controller_mutation_boundary_test.dart' 'test/interactive/core/interactive_move_session_test.dart' 'test/interactive/core/scene_controller_architecture_boundary_test.dart' 'test/tool/guardrails/guardrails_interactive_api_tool_test.dart' 'test/tool/guardrails/interactive_api/architecture_boundary/view_and_graph_cases.dart' 'test/tool/support/guardrails_sandbox_support.dart' 'test/tool/target_architecture_map_tool_test.dart' 'tool/invariant_registry.dart' 'tool/src/guardrails/rules/interactive/interactive_architecture_boundary_rules.dart' | dart run tool/run_verification_preset.dart run --preset=required_code_change --changed-paths-file=-`

## 12. Acceptance Criteria

- the interaction-family code no longer contains
  `SceneControllerInteractionAccess`,
  `SceneControllerInteractionContext`,
  `sceneControllerInternalInteractionAccessForTest(...)`, or
  `InteractiveRuntime.debugMoveSession`
- public interaction behavior, pointer-session lifecycle, runtime-owned
  mutation behavior, and move-preview behavior stay green under the targeted
  test suites
- interactive guardrails fail on a reintroduced access/context bag or a new
  move-session leak through runtime
- target-map evidence and docs are current, and `Interaction runtime` is
  `locked` while `Store and commit path` remains the only family still marked
  `locked, needs slimming`
