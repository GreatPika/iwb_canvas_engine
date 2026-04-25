# Change Contract

## 1. Change Mandate

Finish the target architecture by narrowing `SceneStoreController` to the
committed store facade it already claims to be, retiring the public
command-owner fields from that facade, and locking the store family without
touching the write kernel.

## 2. Change Boundary

### Included in the Change

- retire the public `commands`, `move`, and `draw` owner fields from
  `SceneStoreController`
- migrate production mutation-adapter code away from
  `SceneStoreController.commands` / `.draw` and onto direct command-runner
  injection with the existing `SceneCommands`, `MoveCommands`, and
  `DrawCommands` owners
- migrate controller command tests, controller guardrail fixtures, and any
  remaining tool scaffolds away from `SceneStoreController.commands` /
  `.move` / `.draw`
- keep `SceneStoreControllerSpatialAccess`,
  `SceneStoreControllerCommittedSceneReplacementAccess`, revision getters,
  snapshot materialization, signals, repaint, write entrypoints, and the debug
  getter as the remaining committed-store facade surface
- update controller-side guardrails, controller contract tests, and
  target-map docs so the store family moves from `locked, needs slimming` to
  `locked`
- add this step to `PLAN.md` and update both files together when the step
  closes

### Not Included in the Change

- no split or redesign of `SceneControllerCommitRuntime`
- no split of `TxnContext`, `SceneWriter`, or the commit plan / execution path
- no public API review of `SceneWriteTxn` or other supported package surfaces
- no change to replace-scene sequencing ownership in
  `SceneStoreControllerCommittedMutationAccess`
- no interaction-family, view-family, or mutation-gateway redesign
- no new top-level architecture family or package-boundary change
- no schema/version, barrel export, or supported import-surface change

## 3. Surrounding Code Review

### Inspected Artifacts

- `PLAN.md` - the active plan index is closed through step 19, so the
  remaining architecture work must land as a new dedicated step
- `docs/adr/0002_post_target_optimization_scope.md` - after interaction-family
  compression the only default remaining phase-2 follow-up is store-facade
  cleanup if remeasurement still justifies it
- `docs/target_architecture/overview.md` - after step 19 the only family still
  marked `locked, needs slimming` is `Store and commit path`
- `docs/target_architecture/families/store_and_commit_path.md` - the family
  target already says `SceneStoreController` remains the committed store facade
  while `SceneControllerCommitRuntime` remains the write kernel, and it names
  `SceneStoreController` as the remaining local slimming target
- `ARCHITECTURE.md` - the current checked-in architecture already describes
  `SceneStoreController` as the committed store boundary for snapshot
  materialization, write entrypoints, selected-node view, spatial query
  helpers, and revision counters; it does not name command-owner fields as
  part of that accepted role, so it does not require a wording update for this
  step
- `lib/src/controller/scene_store_controller.dart` - the current facade still
  mixes snapshot caching, revision getters, write entrypoints, public command
  owners (`commands`, `move`, `draw`), a debug getter, the sealed spatial
  helper extension, and the sealed replace-scene helper extension
- `lib/src/controller/scene_controller_commit_runtime.dart` - the write kernel
  remains one coherent owner for transactional execution, commit planning,
  post-commit lifecycle, repaint dispatch, buffered signals, and spatial-index
  cache ownership
- `lib/src/controller/scene_controller_committed_mutation_access.dart` - the
  interaction-side adapter is broad by supported method surface, but its
  production implementation currently reaches many mutations through
  `_storeController.commands` and `_storeController.draw`
- `lib/src/controller/commands/scene_commands.dart` - `SceneCommands` already
  takes only a `SceneCommandRunner`, so it does not require ownership by
  `SceneStoreController`
- `lib/src/controller/commands/move_commands.dart` - `MoveCommands` is a small
  stateless command owner over a write runner and has no production `lib/src`
  usage through the store facade
- `lib/src/controller/commands/draw_commands.dart` - `DrawCommands` already
  takes only a `DrawCommandRunner`, so it also does not require ownership by
  `SceneStoreController`
- `lib/src/controller/scene_controller_commit_debug.dart` - the debug getter
  already returns a narrow `SceneStoreControllerDebugAccess` projection rather
  than exposing commit-runtime internals directly
- `tool/invariant_registry.dart` -
  `INV-ENG-CONTROLLER-COMMIT-RUNTIME-BOUNDARY`,
  `INV-ENG-COMMITTED-READ-SIDE-HERMETICITY`, and
  `INV-ENG-COMMITTED-STORE-METADATA-CONTRACT` already govern this family
  without needing new ids or wording changes for this cut
- `tool/src/guardrails/rules/controller/write_only_mutation_rules.dart` - the
  controller API guardrails currently seal `SceneStoreController` public
  members and still allow `field:commands`, `field:move`, and `field:draw`
  while separately sealing `SceneStoreControllerSpatialAccess`
- `tool/src/guardrails/rules/controller/prepared_replace_boundary_rules.dart`
  - prepared-replace guardrails also currently allow the three command-owner
  fields on `SceneStoreController` and separately seal
  `writeReplaceScene(...)` ownership
- `test/controller/core/scene_controller_commit_runtime_contract_test.dart` -
  this suite already locks the intended boundary: `SceneStoreController`
  delegates write work into `SceneControllerCommitRuntime` and does not re-own
  commit planning or post-commit helpers
- `test/controller/core/scene_controller_committed_mutation_access_test.dart`
  - this suite locks the adapter as a thin committed mutation bridge and keeps
  replace-scene sequencing on committed mutation access
- `test/controller/core/scene_controller_commit_effects_test.dart` - this
  suite still contains a live `controller.commands` consumer, so it must
  migrate before the facade fields can retire
- `test/controller/core/scene_controller_spatial_candidate_resolution_test.dart`
  - this suite locks the sealed committed-read helper surface that must remain
  on `SceneStoreControllerSpatialAccess`
- `test/controller/commands/scene_commands_test.dart`,
  `test/controller/commands/move_commands_test.dart`, and
  `test/controller/commands/draw_commands_test.dart` - these suites already
  characterize the command owners themselves, but they currently consume them
  through `SceneStoreController.commands` / `.move` / `.draw`
- `test/tool/guardrails/guardrails_controller_api_tool_test.dart` - this suite
  locks the controller API surface, prepared-replace boundary, and sealed
  spatial-access helper surface, so it must become the structural successor
  proof for command-owner retirement on `SceneStoreController`
- `test/tool/support/guardrails_sandbox_support.dart` and
  `test/tool/support/guardrail_fixture_writer.dart` - tool scaffolds still
  model the current store-controller surface and therefore must migrate before
  the facade fields can retire
- `test/tool/guardrails/interactive_api/architecture_boundary/runtime_and_draw_ownership_cases.dart`
  and
  `test/tool/guardrails/interactive_api/architecture_boundary/facade_and_boundary_cases.dart`
  - interactive negative scenarios still reference `storeController.commands`
  and `storeController.draw`, so they must be rewritten to the successor
  command-owner path instead of silently breaking on a removed facade field
- `dcm calculate-metrics lib/src/controller/scene_store_controller.dart lib/src/controller/scene_controller_commit_runtime.dart lib/src/controller/scene_controller_committed_mutation_access.dart --reporter=console`
  - remeasurement after step 19 still leaves the store family as the only hot
  family:
  `SceneStoreController` 16 methods / coupling 14,
  `SceneControllerCommitRuntime` 15 methods / coupling 17,
  `SceneStoreControllerCommittedMutationAccess` 27 methods / response set 51,
  and `SceneControllerCommittedMutationAccess` 25 methods
- `dart run tool/lsp_find_boundary_bypasses.dart lib/src/controller/scene_store_controller.dart SceneStoreController --must-pass=SceneControllerCommitRuntime --depth=4`
  - confirms `SceneStoreController` still exposes read/debug metadata that does
  not pass through the write kernel, which is expected for a store facade but
  also shows why the facade must stay narrow and not absorb additional owner
  roles
- `dart run tool/lsp_find_boundary_bypasses.dart lib/src/controller/scene_controller_committed_mutation_access.dart SceneStoreControllerCommittedMutationAccess --must-pass=SceneStoreController --depth=4`
  - confirms many adapter paths still fan directly into `SceneCommands`,
  `DrawCommands`, `SceneWriter`, and related write plumbing instead of using
  `SceneStoreController` as a meaningful owner boundary
- `dart run tool/lsp_find_thin_wrappers.dart lib/src/controller --classification=pure-forwarder`
  - reports 62 controller-side pure-forwarder candidates, including many in
  `SceneStoreControllerCommittedMutationAccess`, `SceneStoreController`, and
  writer-facing command layers
- `dart run tool/lsp_trace_flow.dart lib/src/controller/scene_store_controller.dart SceneStoreController.writeWithSceneWriter --depth=4`
  - confirms the committed write entrypoint already has the right ownership:
  `SceneStoreController -> SceneControllerCommitRuntime.writeWithSceneWriter`
- `dart run tool/lsp_trace_flow.dart lib/src/controller/scene_controller_committed_mutation_access.dart SceneStoreControllerCommittedMutationAccess.addNode --depth=5`
  - confirms the adapter path already relies on the command owner itself:
  `SceneStoreControllerCommittedMutationAccess.addNode -> SceneCommands.writeAddNode -> SceneWriter.writeNodeInsert`
- `rg -n "\\.commands\\.|\\.move\\.|\\.draw\\." lib/src`
  - confirms that in production code the command-owner fields are only consumed
  by `scene_controller_committed_mutation_access.dart`; no other `lib/src`
  owner actually needs them from the store facade
- `rg -n "queryHitTestCandidates\\(|queryPaintCandidates\\(|resolveSpatialCandidateSnapshot\\(|resolveSnapshotNodeById\\(|writeReplaceScene\\(" lib/src`
  - confirms the sealed spatial-access helpers remain live production
  dependencies for interactive hit-test/paint staging, while
  `writeReplaceScene(...)` remains a dedicated helper on the committed-store
  boundary

### Current Entry Path

- committed write entry:
  `SceneStoreController.write*` ->
  `SceneControllerCommitRuntime.write*` ->
  commit plan / execution / post-commit lifecycle
- interaction-side mutation adapter:
  `SceneStoreControllerCommittedMutationAccess.*` ->
  `_storeController.commands` / `_storeController.draw` / `write*` /
  `writeWithSceneWriter*`
- committed spatial/read helpers:
  interaction/view owners ->
  `SceneStoreControllerSpatialAccess.*` ->
  `SceneControllerCommitRuntime.spatialIndexCache` or committed snapshot
  materialization

### Current Owner

- store-family ownership is currently split across:
  `SceneStoreController`,
  `SceneControllerCommitRuntime`,
  `SceneStoreControllerSpatialAccess`,
  `SceneStoreControllerCommittedSceneReplacementAccess`, and
  `SceneStoreControllerCommittedMutationAccess`
- the unwanted extra role on the facade is public ownership of
  `SceneCommands`, `MoveCommands`, and `DrawCommands`

### Adjacent Abstractions

- `lib/src/controller/commands/scene_commands.dart` - stateless scene/selection
  command owner over a write runner
- `lib/src/controller/commands/move_commands.dart` - stateless move command
  owner over a write runner
- `lib/src/controller/commands/draw_commands.dart` - stateless draw command
  owner over a write runner
- `lib/src/controller/scene_controller_commit_runtime.dart` - the adjacent
  write kernel that must remain the owner of commit execution
- `lib/src/controller/scene_writer.dart` - internal write owner consumed by
  both the command classes and the write kernel
- `lib/src/controller/scene_controller_commit_debug.dart` - adjacent debug seam
  that may stay projected through `SceneStoreController.debug`

### Existing Tests

- `test/controller/core/scene_controller_commit_runtime_contract_test.dart` -
  locks the intended thin-facade / write-kernel boundary
- `test/controller/core/scene_controller_committed_mutation_access_test.dart`
  - locks adapter behavior and replace-scene ownership
- `test/controller/core/scene_controller_commit_effects_test.dart` - locks
  commit-side change-set and selection effects while currently consuming the
  retiring `controller.commands` helper
- `test/controller/core/scene_controller_spatial_candidate_resolution_test.dart`
  - locks the sealed spatial/read helper surface
- `test/controller/commands/scene_commands_test.dart` - command-owner behavior
  characterization
- `test/controller/commands/move_commands_test.dart` - move command-owner
  behavior characterization
- `test/controller/commands/draw_commands_test.dart` - draw command-owner
  behavior characterization
- `test/tool/guardrails/guardrails_controller_api_tool_test.dart` - machine
  structural proof for controller API surface and sealed helper boundaries
- `test/tool/guardrails/guardrails_interactive_api_tool_test.dart` -
  structural proof for interactive-side negative cases that currently model the
  old command-owner access path
- `test/tool/target_architecture_map_tool_test.dart` - target-map status proof

### Analogous Implementation Path

- `lib/src/controller/commands/scene_commands.dart`,
  `lib/src/controller/commands/move_commands.dart`, and
  `lib/src/controller/commands/draw_commands.dart` - the command owners already
  use direct runner injection instead of store-facade ownership, so they are
  the closest checked-in precedent for the successor seam this step needs:
  direct command-owner construction around `writeWithSceneWriter`, not public
  storage on `SceneStoreController`

### Governing Repository Rules

- `AGENTS.md` - prefer the smallest owner-side change that removes the mixed
  responsibility instead of adding another wrapper layer
- `AGENTS.md` - recurring boundary constraints must live in repository-local
  tests or tooling, not only in prose
- `docs/adr/0002_post_target_optimization_scope.md` - the remaining default
  phase-2 work after interaction compression is store-facade cleanup, not
  commit-runtime redesign
- `tool/invariant_registry.dart` -
  `INV-ENG-CONTROLLER-COMMIT-RUNTIME-BOUNDARY`,
  `INV-ENG-COMMITTED-READ-SIDE-HERMETICITY`, and
  `INV-ENG-COMMITTED-STORE-METADATA-CONTRACT` govern this area
- `AGENTS.md` / project verification instructions - final verification must use
  `dart run tool/run_verification_preset.dart run --preset=required_code_change`
  rather than plain `dart test`

### Rejected Misleading Local Patterns

- split `SceneControllerCommitRuntime` now - wrong owner because the checked-in
  write kernel still reads as one coherent owner and ADR 0002 explicitly says
  store-facade cleanup should come first
- leave `commands`, `move`, and `draw` on `SceneStoreController` and only mark
  the family `locked` - wrong result because the facade would still own
  command-owner roles that the current architecture docs do not assign to it
- move spatial query helpers or `writeReplaceScene(...)` off the store facade
  in this step - wrong seam because those helpers are already separately sealed
  and are still live dependencies of the interaction/view or prepared-replace
  paths
- shrink `SceneControllerCommittedMutationAccess` by deleting supported methods
  - wrong level because its public adapter surface is already sealed by
  controller guardrails and tests; the owner problem here is where command
  owners live, not whether the adapter should keep its API
- move command logic into `SceneStoreController` or `SceneControllerCommitRuntime`
  - wrong owner because the command classes are already the dedicated owners
  for that behavior and only need a write runner

## 4. Architecture

### 4A. Locked Architectural Form

#### Problem Ownership Level

- one local slimming cut inside the already accepted store family

#### Selected Architectural Form

- `SceneStoreController` remains the committed store facade for snapshot
  materialization, revision metadata, selected-node view, signals, repaint,
  debug projection, transactional write entrypoints, and the sealed
  `SceneStoreControllerSpatialAccess` /
  `SceneStoreControllerCommittedSceneReplacementAccess` helper surfaces
- `SceneStoreController` no longer owns or exposes `SceneCommands`,
  `MoveCommands`, or `DrawCommands` as public fields
- `SceneStoreControllerCommittedMutationAccess` remains the interaction-side
  adapter, but it privately owns the `SceneCommands` and `DrawCommands`
  instances it needs by constructing them directly from
  `SceneStoreController.writeWithSceneWriter`
- `MoveCommands` remains an existing command owner, but it is no longer a
  `SceneStoreController` field; tests and any future controller-local callers
  construct it directly from a write runner when they genuinely need that owner
- `SceneControllerCommitRuntime` remains the write kernel and is not split,
  widened, or used as a command-owner bag

#### Owning Layer or Module

- all production ownership stays inside `lib/src/controller/**`; no
  responsibility moves into interaction, view, or contract layers

#### Dependency Direction

- `SceneStoreController` ->
  `SceneControllerCommitRuntime` for write execution and post-commit behavior
- `SceneStoreControllerCommittedMutationAccess` ->
  `SceneStoreController.writeWithSceneWriter` ->
  privately owned `SceneCommands` / `DrawCommands`
- interactive/view consumers ->
  `SceneStoreControllerSpatialAccess` and committed read getters only
- prepared replace-scene path ->
  `SceneStoreControllerCommittedSceneReplacementAccess` and
  `SceneControllerCommittedMutationAccess.replaceScene` only

#### State and Data Ownership

- committed scene state remains in `SceneStore`
- commit execution, buffered signals, repaint coordination, and spatial-index
  cache remain in `SceneControllerCommitRuntime`
- command owners remain stateless wrappers over a write runner; they do not
  become new state owners
- debug state remains in `SceneControllerCommitDebugState` and continues to be
  projected through the narrow `SceneStoreControllerDebugAccess` getter

#### Entry and Exit Boundaries

- committed facade entry remains `SceneStoreController`
- interaction-side write adapter entry remains
  `SceneControllerCommittedMutationAccess` /
  `SceneStoreControllerCommittedMutationAccess`
- spatial/read helper exit remains `SceneStoreControllerSpatialAccess`
- replace-scene convenience exit remains
  `SceneStoreControllerCommittedSceneReplacementAccess`

#### Permitted Extension Seam

- no new production owner file is required for this step
- direct command-owner construction with `writeWithSceneWriter` is the
  permitted successor seam for retiring `SceneStoreController.commands`,
  `.move`, and `.draw`
- test helpers or tool scaffolds may add small local builder functions when
  needed, but must not introduce a new public facade bag for the retired
  fields

#### Rejected Alternatives

- keep the retired fields as deprecated compatibility shells - wrong
  architecture because the store facade would remain broader than its accepted
  owner role
- move command-owner behavior into the commit runtime - wrong ownership because
  it would blur the kernel boundary with command semantics
- create a new public `SceneStoreControllerCommandsAccess` facade - wrong seam
  because the command owners already exist and already accept the minimal
  dependency they need
- treat the store family as still needing another step after this one - wrong
  target because this cut removes the last remaining local mismatch named by
  ADR 0002 and the current target map

#### Why This Level Is Correct

- the store family is the only remaining `locked, needs slimming` family after
  step 19
- production usage inventory shows the command-owner fields are not a shared
  facade requirement: in `lib/src` they are consumed only by the committed
  mutation adapter
- the command-owner classes are already independently coherent and already take
  only a write runner, so direct runner injection is the smallest owner-side
  cut that removes the extra store-facade role
- the write kernel and sealed spatial/replace seams already have machine
  protection and do not need redesign in the same step

## 5. Locked Decisions

1. The successor seam for retiring `SceneStoreController.commands`,
   `.move`, and `.draw` is direct command-owner construction around
   `SceneStoreController.writeWithSceneWriter`; this step does not introduce a
   new facade or wrapper file.
2. `SceneStoreControllerCommittedMutationAccess` becomes the only production
   owner that keeps command-owner instances for interaction-triggered mutation
   methods.
3. `SceneStoreControllerSpatialAccess`,
   `SceneStoreControllerCommittedSceneReplacementAccess`, and
   `SceneStoreController.debug` stay live; they are not retirement targets in
   this step.
4. `docs/target_architecture/families/store_and_commit_path.md` and
   `docs/target_architecture/overview.md` move the store family from
   `locked, needs slimming` to `locked` only after the retired facade fields,
   controller guardrails, and command/test adoption all land together.

## 6. Result Requirements

1. No production `SceneStoreController` public surface still exposes
   `commands`, `move`, or `draw`.
2. No `lib/src` production code reaches `SceneCommands`, `MoveCommands`, or
   `DrawCommands` through `SceneStoreController` fields.
3. `SceneStoreControllerCommittedMutationAccess` keeps the same supported
   adapter behavior and replace-scene ownership while no longer depending on
   `SceneStoreController.commands` / `.draw`.
4. `SceneStoreControllerSpatialAccess`,
   `SceneStoreControllerCommittedSceneReplacementAccess`, revision getters,
   snapshot reads, `signals`, `requestRepaint`, write entrypoints, and debug
   projection remain the checked-in store-facade surface.
5. The target map is fully closed: `overview.md` contains no remaining
   `locked, needs slimming` family rows.

## 7. Execution Order and Gates

### Required Order

- land the direct command-runner successor path in the committed mutation
  adapter and the controller-side tests that still consume the retiring fields
  before retiring the facade fields
- retire `SceneStoreController.commands` / `.move` / `.draw` only after
  controller tests, tool scaffolds, and interactive negative fixtures no longer
  consume them
- move the store family to `locked` only after controller API guardrails,
  target-map docs, and fixture support all match the retired-field shape

### Successor Seam and Retirement Gates

- direct `SceneCommands` / `MoveCommands` / `DrawCommands` construction around
  `writeWithSceneWriter` succeeds the `SceneStoreController.commands` /
  `.move` / `.draw` fields; the fields may retire only after
  `scene_controller_committed_mutation_access.dart`,
  `test/controller/commands/**`,
  `test/controller/core/scene_controller_commit_effects_test.dart`,
  `test/tool/support/**`, and the interactive negative guardrail cases no
  longer consume them
- `SceneStoreControllerSpatialAccess` and
  `SceneStoreControllerCommittedSceneReplacementAccess` remain live sealed
  surfaces; controller guardrails for those seams must stay green before the
  family can be marked `locked`

### Deferred Broad Verification

- `dart run tool/run_verification_preset.dart run --preset=required_code_change --changed-paths-file=-`
  - reserve for the final gate after all slices land
- `dart run tool/run_tool_tests.dart test/tool/guardrails/guardrails_controller_api_tool_test.dart`
  - reserve as a final broad controller-guardrail rerun after the facade field
  retirement and fixture migration stabilize
- `dart run tool/run_tool_tests.dart test/tool/guardrails/guardrails_interactive_api_tool_test.dart`
  - reserve as a final broad interactive-guardrail rerun after the interactive
  negative fixtures stop depending on the retired fields

## 8. File Map

### Implementation Files

- `PLAN.md`
- `plan/step_20_store_facade_narrowing_and_command_owner_retirement.md`
- `docs/target_architecture/families/store_and_commit_path.md`
- `docs/target_architecture/overview.md`
- `lib/src/controller/scene_store_controller.dart`
- `lib/src/controller/scene_controller_committed_mutation_access.dart`

### Test Files

- `test/controller/core/scene_controller_commit_runtime_contract_test.dart`
- `test/controller/core/scene_controller_committed_mutation_access_test.dart`
- `test/controller/core/scene_controller_commit_effects_test.dart`
- `test/controller/core/scene_controller_spatial_candidate_resolution_test.dart`
- `test/controller/commands/scene_commands_test.dart`
- `test/controller/commands/move_commands_test.dart`
- `test/controller/commands/draw_commands_test.dart`
- `test/tool/guardrails/guardrails_controller_api_tool_test.dart`
- `test/tool/guardrails/guardrails_interactive_api_tool_test.dart`
- `test/tool/guardrails/interactive_api/architecture_boundary/runtime_and_draw_ownership_cases.dart`
- `test/tool/guardrails/interactive_api/architecture_boundary/facade_and_boundary_cases.dart`
- `test/tool/guardrails/guardrails_fixture_manifest_support_tool_test.dart`
- `test/tool/target_architecture_map_tool_test.dart`

### Fixtures and Supporting Data

- `test/tool/support/guardrails_sandbox_support.dart`
- `test/tool/support/guardrail_fixture_writer.dart`

### Registry, Inventory, and Workflow Files

- `tool/src/guardrails/rules/controller/write_only_mutation_rules.dart`
- `tool/src/guardrails/rules/controller/prepared_replace_boundary_rules.dart`

### Analysis Area

- `lib/src/controller/**`
- `test/controller/**`
- `test/tool/guardrails/**`
- `docs/target_architecture/**`

## 9. Implementation Rules

### Protected Invariants

- `INV-ENG-CONTROLLER-COMMIT-RUNTIME-BOUNDARY`
- `INV-ENG-COMMITTED-READ-SIDE-HERMETICITY`
- `INV-ENG-COMMITTED-STORE-METADATA-CONTRACT`

### Required Proof

- behavioral proof:
  keep committed mutation adapter behavior, command-owner behavior, sealed
  spatial helper behavior, and replace-scene ownership green while the facade
  surface narrows
- structural proof:
  make reintroduction of `SceneStoreController.commands`,
  `SceneStoreController.move`, or `SceneStoreController.draw` mechanically
  visible through controller API guardrails, controller contract tests, and
  updated interactive negative fixtures
- for bug fixes, regressions, false positives, false negatives, and
  invariant-enforcement gaps: one failing reproducer first, plus 1 to 3 guard
  tests for neighboring branches of the same contract
- for refactors: existing locking tests must be named or missing
  characterization tests must be added before structural edits, plus 1 to 3
  guard tests for neighboring branches when needed

### Allowed Change Surface

- only the store-family files, command-owner adoption sites, controller
  guardrails, fixture support, target-map docs, and tests listed in section 8
- no new production facade owner or wrapper layer for the retired fields
- small local builder helpers in tests/tool scaffolds are allowed only when
  they replace direct `controller.commands` / `.move` / `.draw` access

### Forbidden Moves

- do not split or widen `SceneControllerCommitRuntime`
- do not move command-owner logic into `SceneStoreController`
- do not remove or relocate `SceneStoreControllerSpatialAccess` or
  `SceneStoreControllerCommittedSceneReplacementAccess`
- do not change `SceneControllerCommittedMutationAccess` public method surface
  as part of this step
- do not mark the store family `locked` while the retired facade fields remain
  in production code or live fixture support

## 10. Vertical Slices

### Slice 1. [x] Adopt Direct Command-Runner Ownership

#### Slice Contract

Land the successor command-owner path first by migrating the committed mutation
adapter and the controller-side tests that still consume the retiring facade
fields to direct command-owner construction over `writeWithSceneWriter`, while
behavior stays unchanged and the old facade fields still exist temporarily.

#### Change

- make `SceneStoreControllerCommittedMutationAccess` construct and use its own
  `SceneCommands` and `DrawCommands` instances from
  `SceneStoreController.writeWithSceneWriter`
- migrate `scene_commands_test.dart`, `move_commands_test.dart`, and
  `draw_commands_test.dart`, plus
  `scene_controller_commit_effects_test.dart`, off
  `controller.commands` / `.move` / `.draw` toward direct command-owner
  construction
- keep `SceneStoreController` fields in place for now so remaining fixtures can
  migrate in the next slice without breaking the repository mid-step

#### Behavioral Verification

- `flutter test test/controller/core/scene_controller_committed_mutation_access_test.dart`
- `flutter test test/controller/core/scene_controller_commit_effects_test.dart`
- `flutter test test/controller/commands/scene_commands_test.dart`
- `flutter test test/controller/commands/move_commands_test.dart`
- `flutter test test/controller/commands/draw_commands_test.dart`

#### Structural Verification

- `dart run tool/lsp_trace_flow.dart lib/src/controller/scene_controller_committed_mutation_access.dart SceneStoreControllerCommittedMutationAccess.addNode --depth=5`
- `rg -n "_storeController\\.(commands|move|draw)|controller\\.(commands|move|draw)" lib/src/controller/scene_controller_committed_mutation_access.dart test/controller/commands test/controller/core/scene_controller_commit_effects_test.dart`

#### Fixtures Used

- none

#### Positive Scenarios

- the committed mutation adapter still routes add/selection/draw mutations
  through the same command owners and writer path
- command-owner tests still characterize `SceneCommands`, `MoveCommands`, and
  `DrawCommands` directly after the store-facade dependency is removed from the
  tests

#### Negative Scenarios

- the migrated adapter path no longer depends on `_storeController.commands` or
  `_storeController.draw`
- the migrated controller command tests no longer depend on
  `controller.commands`, `controller.move`, or `controller.draw`
- the migrated commit-effects characterization no longer depends on
  `controller.commands`

#### Closure Evidence

- repository search over
  `lib/src/controller/scene_controller_committed_mutation_access.dart` and
  `test/controller/commands/**` plus
  `test/controller/core/scene_controller_commit_effects_test.dart` finds no
  remaining retired-field references

### Slice 2. [x] Retire Store Facade Command Fields

#### Slice Contract

Retire `SceneStoreController.commands`, `.move`, and `.draw`, and migrate the
remaining guardrail fixtures and scaffolds to the direct command-owner path so
the store facade surface becomes structurally narrow.

#### Change

- remove `commands`, `move`, and `draw` from `SceneStoreController`
- update controller API guardrails and prepared-replace guardrails to reject
  those fields on the store facade
- migrate `test/tool/support/guardrails_sandbox_support.dart`,
  `test/tool/support/guardrail_fixture_writer.dart`, and the interactive
  negative cases away from `storeController.commands` / `.draw`

#### Behavioral Verification

- `flutter test test/controller/core/scene_controller_commit_runtime_contract_test.dart`
- `flutter test test/controller/core/scene_controller_committed_mutation_access_test.dart`
- `flutter test test/controller/core/scene_controller_commit_effects_test.dart`
- `flutter test test/controller/core/scene_controller_spatial_candidate_resolution_test.dart`

#### Structural Verification

- `dart run tool/run_tool_tests.dart test/tool/guardrails/guardrails_controller_api_tool_test.dart`
- `dart run tool/run_tool_tests.dart test/tool/guardrails/guardrails_interactive_api_tool_test.dart`
- `dart run tool/run_tool_tests.dart test/tool/guardrails/guardrails_fixture_manifest_support_tool_test.dart`

#### Fixtures Used

- `test/tool/support/guardrails_sandbox_support.dart`
- `test/tool/support/guardrail_fixture_writer.dart`
- `test/tool/guardrails/interactive_api/architecture_boundary/runtime_and_draw_ownership_cases.dart`
- `test/tool/guardrails/interactive_api/architecture_boundary/facade_and_boundary_cases.dart`

#### Positive Scenarios

- the store facade still keeps its sealed spatial helper, replace-scene
  helper, revision, snapshot, signal, debug, and write-entry surfaces
- controller and interactive guardrail fixtures still model the intended
  architecture after the retired fields disappear

#### Negative Scenarios

- controller API guardrails fail if `SceneStoreController` reintroduces
  `commands`, `move`, or `draw`
- interactive negative fixtures no longer depend on the retired facade fields
  to express their forbidden store-write patterns

#### Closure Evidence

- `SceneStoreController` no longer declares public `commands`, `move`, or
  `draw` fields
- controller guardrail rules no longer list those fields on the sealed
  `SceneStoreController` public surface

### Slice 3. [x] Lock The Store Family Target Map

#### Slice Contract

Finish the last architecture cut by updating the store-family docs and status
vocabulary so the target map reflects the now-locked store facade shape.

#### Change

- update `docs/target_architecture/families/store_and_commit_path.md` and
  `docs/target_architecture/overview.md` so the store family becomes `locked`
  and the top-level map no longer contains any `locked, needs slimming` rows

#### Behavioral Verification

- `flutter test test/controller/core/scene_controller_commit_runtime_contract_test.dart`
- `flutter test test/controller/core/scene_controller_spatial_candidate_resolution_test.dart`

#### Structural Verification

- `dart run tool/run_tool_tests.dart test/tool/target_architecture_map_tool_test.dart`
- `rg -n "locked, needs slimming" docs/target_architecture/overview.md docs/target_architecture/families/store_and_commit_path.md`

#### Fixtures Used

- none

#### Positive Scenarios

- the target map now reports all five owner families as `locked`
- the store-family docs match the narrowed checked-in facade

#### Negative Scenarios

- no target-map document still says the store family needs slimming
- no target-map document still treats command-owner fields as part of the
  accepted store-facade shape

#### Closure Evidence

- `docs/target_architecture/overview.md` contains no `locked, needs slimming`
  row
- `docs/target_architecture/families/store_and_commit_path.md` marks the store
  family `locked`

## 11. Final Verification

- `flutter test test/controller/core/scene_controller_commit_runtime_contract_test.dart`
- `flutter test test/controller/core/scene_controller_committed_mutation_access_test.dart`
- `flutter test test/controller/core/scene_controller_commit_effects_test.dart`
- `flutter test test/controller/core/scene_controller_spatial_candidate_resolution_test.dart`
- `flutter test test/controller/commands/scene_commands_test.dart`
- `flutter test test/controller/commands/move_commands_test.dart`
- `flutter test test/controller/commands/draw_commands_test.dart`
- `dart run tool/run_tool_tests.dart test/tool/guardrails/guardrails_controller_api_tool_test.dart`
- `dart run tool/run_tool_tests.dart test/tool/guardrails/guardrails_interactive_api_tool_test.dart`
- `dart run tool/run_tool_tests.dart test/tool/guardrails/guardrails_fixture_manifest_support_tool_test.dart`
- `dart run tool/run_tool_tests.dart test/tool/target_architecture_map_tool_test.dart`
- `printf '%s\n' 'PLAN.md' 'plan/step_20_store_facade_narrowing_and_command_owner_retirement.md' 'docs/target_architecture/families/store_and_commit_path.md' 'docs/target_architecture/overview.md' 'lib/src/controller/scene_store_controller.dart' 'lib/src/controller/scene_controller_committed_mutation_access.dart' 'test/controller/core/scene_controller_commit_runtime_contract_test.dart' 'test/controller/core/scene_controller_committed_mutation_access_test.dart' 'test/controller/core/scene_controller_commit_effects_test.dart' 'test/controller/core/scene_controller_spatial_candidate_resolution_test.dart' 'test/controller/commands/scene_commands_test.dart' 'test/controller/commands/move_commands_test.dart' 'test/controller/commands/draw_commands_test.dart' 'test/tool/guardrails/guardrails_controller_api_tool_test.dart' 'test/tool/guardrails/guardrails_interactive_api_tool_test.dart' 'test/tool/guardrails/interactive_api/architecture_boundary/runtime_and_draw_ownership_cases.dart' 'test/tool/guardrails/interactive_api/architecture_boundary/facade_and_boundary_cases.dart' 'test/tool/guardrails/guardrails_fixture_manifest_support_tool_test.dart' 'test/tool/support/guardrails_sandbox_support.dart' 'test/tool/support/guardrail_fixture_writer.dart' 'test/tool/target_architecture_map_tool_test.dart' 'tool/src/guardrails/rules/controller/write_only_mutation_rules.dart' 'tool/src/guardrails/rules/controller/prepared_replace_boundary_rules.dart' | dart run tool/run_verification_preset.dart run --preset=required_code_change --changed-paths-file=-`

## 12. Acceptance Criteria

- `SceneStoreController` no longer exposes public `commands`, `move`, or
  `draw` fields
- no production `lib/src` path reaches command owners through
  `SceneStoreController` fields
- committed mutation adapter behavior, command-owner behavior, sealed spatial
  helper behavior, and replace-scene ownership remain green under the named
  tests
- `SceneStoreController` still exposes `signals`, `requestRepaint`,
  snapshot/revision reads, sealed spatial helpers, and the prepared
  replace-scene helper after command-owner retirement
- controller and interactive guardrails fail on reintroduced command-owner
  fields on `SceneStoreController`
- `docs/target_architecture/overview.md` shows all five families as `locked`
  and no remaining `locked, needs slimming` rows
